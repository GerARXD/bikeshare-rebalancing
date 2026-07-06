# Plataforma de Rebalanceo Predictivo de Bike-Share

**Proyecto insignia de portafolio — Gerald Argueta**
Documento de especificación y plan de construcción · **v2.0**

> **Nota para quien lo implemente (humano o Claude Code):** este documento es la fuente
> de verdad del proyecto. Describe el problema, el modelo de datos, la lógica de negocio,
> el stack y el plan por fases. Está escrito para poder entregarse a un agente de código
> y construir el sistema fase por fase sin ambigüedad. Cuando un detalle sea decisión de
> diseño abierta, está marcado como **[Decisión]**.

---

## 0. Resumen ejecutivo

Plataforma que **pronostica la demanda de bicis compartidas por zona y recomienda cómo
redistribuir las bicis** (rebalanceo) para que los usuarios siempre puedan **rentar Y
devolver**. Usa datos reales del sistema Citi Bike (Nueva York / Jersey City / Hoboken):
un feed en vivo (GBFS) y el histórico de viajes en CSV.

- **Meta profesional:** portafolio que consiga entrevistas para un puesto remoto de datos
  (EE. UU. / LatAm) trabajando desde Guatemala como contratista. Apunta a sectores
  accesibles (analítica de operaciones, data engineering, BI).
- **Qué demuestra:** pipeline batch + streaming, pronóstico de series de tiempo, lógica de
  inventario/operaciones (transbordo), despliegue de un producto vivo y comunicación de
  negocio. El paquete completo, no solo un modelo.

---

## 1. El problema

Cada estación de bicis es un **inventario de dos lados** con capacidad fija:

```
bicis disponibles  +  espacios libres (docks vacíos)  =  capacidad de la estación
```

Por lo tanto hay **dos formas de fallar al usuario**:

1. **Sin bicis** (`num_bikes_available = 0`) → no se puede **rentar**.
2. **Sin espacios** (`num_docks_available = 0`, estación llena) → no se puede **devolver**.

Las dos fallas están **acopladas**: meter bicis a una estación le quita espacios; quitarlas
la acerca al vacío. A lo largo del día, las estaciones **oscilan** entre ambos extremos
(zonas residenciales se vacían en la mañana y se llenan en la tarde; los distritos de
oficinas, al revés).

**Diferencia clave con una tienda:** aquí el número total de bicis es ~fijo en el corto
plazo. No se "reabastece" desde un proveedor (el inventario no crece): se **redistribuye**
lo existente entre estaciones. Es un problema de **transbordo / balanceo entre ubicaciones**
(transshipment), más sofisticado que un punto de reorden simple.

**La elegancia:** un solo movimiento de camión resuelve dos fallas — vacía una estación
llena (libera espacios) y llena una vacía (da stock).

### Pregunta de negocio que responde la plataforma

> *"¿Qué zonas se van a quedar sin bicis (o sin espacios) y a qué hora, y cuántas bicis hay
> que mover y a dónde para evitarlo?"*

- **Usuario:** equipo de operaciones / planificación de rebalanceo del operador.
- **Decisión que facilita:** a qué zonas mandar camiones, cuándo, y cuántas bicis mover.

---

## 2. Hechos del dominio (contexto real, ya verificado)

- Citi Bike es un sistema **con anclaje (docked)**, ~2,200–2,300 estaciones **fijas** y
  ~35,000 bicis, en Manhattan, Brooklyn, Queens, el Bronx, Hoboken y Jersey City.
- Es un sistema de estaciones fijas: las bicis se recogen y devuelven en docks, **no** se
  dejan en cualquier lugar. → El modelo de `stations` con lat/lon/capacity fijos es correcto.
- **Dos tipos de bici** en los mismos docks: clásica y eléctrica. Se cuentan por separado en
  el feed (`num_ebikes_available`). La demanda se inclina fuertemente a las **eléctricas**.
- **Carga de e-bikes = cuello de botella:** la mayoría de los docks NO cargan; el operador
  intercambia baterías manualmente. Una e-bike con batería baja figura "disponible" pero es
  poco útil. (Relevante para V2.)
- El **rebalanceo** es una operación real, constante y costosa para el operador (equipos 24/7
  y hasta un programa de incentivos a usuarios, "Bike Angels").
- **Distancia caminable:** los usuarios caminan a estaciones vecinas; gran parte de los
  viajes empiezan/terminan a ~5 minutos a pie de su origen. → El desabastecimiento real se
  mide por **zona caminable**, no por estación suelta.

---

## 3. Conceptos del modelo

### 3.1 Demanda (de la tabla `trips`)

- **Salidas (outflow):** # de viajes que **inician** en una estación por hora → bajan el stock.
  `COUNT(*) GROUP BY start_station_id, hora`.
- **Llegadas (inflow):** # de viajes que **terminan** en una estación por hora → suben el stock.
  `COUNT(*) GROUP BY end_station_id, hora`.

Se pronostican **ambas** series, porque se necesitan las dos para saber si una estación/zona
se dirige hacia 0 bicis o hacia 0 espacios.

### 3.2 Estado (de la tabla `station_status`, en vivo)

`num_bikes_available`, `num_ebikes_available`, `num_docks_available`. Es la "fotografía" real
del inventario en cada instante; se acumula con cada snapshot del ingest en vivo.

### 3.3 Zonas caminables

Agrupar estaciones en **zonas** por proximidad (clustering espacial sobre lat/lon, p. ej.
DBSCAN o k-means; radio objetivo ~300–500 m / ~5 min a pie). El desabastecimiento se evalúa
a nivel de zona: una zona está **sin bicis** si **ninguna** estación de la zona tiene bici
disponible; **sin espacios** si ninguna tiene dock libre.

### 3.4 Lógica de inventario de dos lados

- **Stock proyectado(t)** = stock actual + llegadas pronosticadas − salidas pronosticadas,
  acotado a `[0, capacidad]`.
- **Inventario de seguridad (dos extremos):** un colchón inferior (bicis) y uno superior
  (espacios), cada uno ≈ `Z × σ × √(lead time)`, donde `σ` es el error del pronóstico y `Z`
  el factor del nivel de servicio.
- **Punto de reorden / disparo de rebalanceo:** cuando el stock proyectado va a salir de la
  **banda sana** `[colchón_inferior, capacidad − colchón_superior]` antes de la siguiente
  ventana de servicio.
- **Recomendación:** cantidad de bicis a mover y **emparejamiento** zona-origen (llena) →
  zona-destino (vacía).

---

## 4. KPIs

### 4.1 Técnicos (rigor del pronóstico)

- MAPE, RMSE, MAE de las series de salidas y llegadas.
- Comparación contra un **baseline ingenuo** (p. ej. "misma hora de la semana pasada").

### 4.2 De negocio / operación (lo que convence)

- **Nivel de servicio de dos lados:** % del tiempo que una zona permite **rentar Y devolver**.
- **Riesgo de quiebre por zona/hora:** probabilidad de quedarse sin bicis y sin espacios.
- **Bicis-hora perdidas:** demanda no atendida por falta de bici o de espacio.
- **Movimientos de rebalanceo sugeridos** y su efecto proyectado en el nivel de servicio.
- **Eficiencia operativa:** nivel de servicio logrado por # de movimientos de camión.

**Regla:** cada número técnico se acompaña de su traducción operativa / en costo.

---

## 5. Alcance: V1 vs V2 (los matices)

### V1 — "El cerebro vivo" (meta: terminarlo y desplegarlo)

Objetivo: pipeline completo, funcional y desplegado, sobre un alcance acotado.

- **Datos:** una **zona pequeña y manejable** (p. ej. **Hoboken** ~30 estaciones, o Jersey
  City). **[Decisión]** elegir la zona en la Fase 1 según tamaño del CSV.
- **Tipos de bici:** "bicis" **genéricas** (total disponible). Sin separar e-bike/clásica aún.
- **Demanda:** pronóstico de salidas y llegadas por **estación** y por hora.
- **Modelos:** baseline ingenuo → serie de tiempo clásica (ARIMA/Prophet) → ML
  (XGBoost/LightGBM) con feature engineering (lags, hora, día de semana, estacionalidad).
- **Inventario:** lógica de dos lados (banda sana, colchones, disparo de rebalanceo) a nivel
  de estación.
- **Producto:** dashboard Streamlit con 3 pantallas (ver §7) + slider de nivel de servicio.
- **Flujo:** ingesta en vivo (GBFS) cada pocos minutos vía GitHub Actions + carga mensual del
  histórico (CSV).
- **Despliegue:** Streamlit Community Cloud / Hugging Face. Demo en vivo enlazada al sitio.

### V2 — "La estrategia de distribución" (mejoras que elevan el proyecto)

Cada una es opcional e incremental; se añaden sin rehacer V1.

1. **Zonas caminables:** clustering espacial de estaciones; desabastecimiento y rebalanceo a
   nivel de **zona** en vez de estación. (Implementa la idea del radio caminable.)
2. **E-bike vs clásica:** tratar cada tipo como un "producto" distinto, con su propia demanda
   (la eléctrica domina). Modela la **sustitución** parcial ("modo clásico").
3. **Carga de e-bikes:** incorporar estado de batería / estaciones electrificadas como
   restricción (una e-bike descargada no cuenta como disponible útil).
4. **Optimización de transbordo:** en vez de reglas por estación, resolver el emparejamiento
   origen→destino como un problema de optimización (minimizar movimientos sujeto a nivel de
   servicio objetivo).
5. **Frontend de producto:** Next.js/React en Vercel + backend FastAPI (el modelo en Python),
   para comunicar "entrego software end-to-end", no solo prototipos.
6. **Escalar a toda la red:** de una zona a todo NYC, apoyándose en las zonas del punto 1.

---

## 6. Stack técnico

| Pieza | Elección | Por qué |
|---|---|---|
| Lenguaje | **Python** | Estándar; ya lo dominas. |
| Modelado | pandas, NumPy, scikit-learn, statsmodels/Prophet, XGBoost/LightGBM | Series de tiempo + ML. |
| Clustering (V2) | scikit-learn (DBSCAN / k-means), geopy/haversine | Zonas caminables. |
| Base de datos | **PostgreSQL** (Neon o Supabase, free tier) | SQL real; SQLite para pruebas locales. |
| App / UI (V1) | **Streamlit** | Dashboard en Python puro; despliegue gratis. |
| Frontend (V2) | Next.js/React en **Vercel** + FastAPI | Producto "de verdad". |
| Despliegue app (V1) | **Streamlit Community Cloud** / **Hugging Face Spaces** | Gratis, link público. |
| Orquestación | **GitHub Actions** (cron) | Ingesta en vivo (minutos) + histórico (mensual). |
| Repo | **GitHub** | El portafolio real; README con historia de negocio. |

**Nube de pago (AWS/BigQuery): NO en V1.** Los free tiers sobran. Posible v3.

**Por qué Streamlit y no Vercel en V1:** Streamlit es un servidor persistente (WebSockets) que
no encaja con el modelo serverless de Vercel. Vercel entra en V2 con la arquitectura
frontend/backend separada.

---

## 7. Arquitectura

```
                 ┌─────────────────────────────┐
   GBFS (vivo) ──▶  ingest_live.py  (cada ~min) │
                 │                              ├──▶  PostgreSQL
   CSV histórico ▶  ingest_trips.py (mensual)   │        │
                 └─────────────────────────────┘        │
                                                         ▼
                         features.py ─▶ forecast.py ─▶ inventory.py
                                                         │
                                                         ▼
                                          app/streamlit_app.py (3 pantallas)
                                                         ▲
                          GitHub Actions (cron) orquesta ingesta y reentrenamiento
```

### Estructura del repositorio

```
bikeshare-rebalancing/
├── README.md                  # historia de negocio + cómo correr + link a la demo
├── requirements.txt
├── .env.example
├── schema.sql                 # esquema de la base de datos
├── .github/workflows/
│   ├── ingest_live.yml        # cron cada ~5 min: snapshot del estado
│   └── ingest_trips.yml       # cron mensual: descarga y carga el histórico
├── src/
│   ├── db.py                  # conexión a PostgreSQL
│   ├── ingest_live.py         # ingesta GBFS (estado en vivo)  [HECHO en Fase 1]
│   ├── ingest_trips.py        # carga del histórico de viajes (CSV)
│   ├── features.py            # demanda por estación/hora + features
│   ├── forecast.py            # modelos + métricas (baseline → clásico → ML)
│   ├── inventory.py           # lógica de dos lados + recomendación de rebalanceo
│   ├── zones.py               # (V2) clustering espacial en zonas caminables
│   └── config.py              # zona/ciudad activa, parámetros (lead time, nivel servicio)
├── app/
│   └── streamlit_app.py       # dashboard (3 pantallas)
└── notebooks/
    └── exploration.ipynb      # EDA inicial
```

---

## 8. Las tres pantallas del dashboard (V1)

1. **Overview** — mapa de las estaciones de la zona; estado actual (bicis/espacios) y
   demanda histórica vs pronóstico con banda de confianza.
2. **Modelo** — comparación baseline vs clásico vs ML, con MAPE/RMSE/MAE visibles.
   Demuestra criterio: cuándo el ML gana y cuándo no.
3. **Decisiones** — por estación/zona: riesgo de quedarse sin bicis y sin espacios, hora
   estimada de la falla, y la recomendación de rebalanceo (cuántas mover, origen→destino).
   Incluye el **slider de nivel de servicio** (lean ↔ seguro) que recalcula los colchones
   y los movimientos en vivo.

---

## 9. Plan de construcción por fases

> Cada fase tiene un **entregable** verificable. Construir en orden.

### Fase 1 — Fundamentos de datos
- 1a. Esquema (`schema.sql`) + conexión (`db.py`) + ingesta en vivo (`ingest_live.py`). **[HECHO]**
- 1b. Elegir la zona de V1 y construir `ingest_trips.py`: descarga automática del CSV más
  reciente del bucket S3, descompresión y carga a `trips`.
- 1c. EDA inicial (`notebooks/exploration.ipynb`): volumen, estacionalidad, estaciones top.
- **Entregable:** base de datos poblada (estaciones + estado + viajes) y scripts reproducibles.

### Fase 2 — Demanda y features
- `features.py`: derivar series de **salidas** y **llegadas** por estación y hora; crear
  lags, hora del día, día de semana, indicadores de estacionalidad.
- **Entregable:** tabla/serie de demanda lista para modelar.

### Fase 3 — Pronóstico
- `forecast.py`: baseline → clásico (ARIMA/Prophet) → ML (XGBoost/LightGBM); validación
  temporal (walk-forward) y métricas contra baseline.
- **Entregable:** módulo de pronóstico con métricas honestas y `σ` del error.

### Fase 4 — Inventario de dos lados
- `inventory.py`: stock proyectado, banda sana, colchones (dos extremos), disparo de
  rebalanceo y recomendación de movimientos (cantidad + emparejamiento).
- **Entregable:** del pronóstico a la decisión operativa.

### Fase 5 — Dashboard
- `app/streamlit_app.py`: las 3 pantallas + slider de nivel de servicio.
- **Entregable:** app funcional en local.

### Fase 6 — Flujo y despliegue
- GitHub Actions: cron de ingesta en vivo (minutos) y de histórico (mensual).
- Despliegue en Streamlit Cloud / Hugging Face; link público.
- **Entregable:** demo en vivo, pipeline corriendo solo.

### Fase 7 — Presentación
- README con la historia de negocio, capturas y link a la demo.
- Enlazar demo + repo desde el sitio personal.
- **Entregable:** proyecto listo para mostrar a reclutadores.

### Fases V2 (opcionales, incrementales)
- `zones.py` (clustering) · e-bike vs clásica · carga/batería · optimización de transbordo ·
  frontend Next.js/Vercel + FastAPI · escalar a toda la red.

---

## 10. Fuentes de datos (referencia rápida)

- **Estado en vivo (GBFS):** auto-descubrimiento `https://gbfs.citibikenyc.com/gbfs/gbfs.json`
  → feeds `station_information` (estaciones) y `station_status` (bicis/espacios). Gratis, sin
  API key, ~tiempo real.
- **Histórico de viajes (CSV):** bucket S3. Listado XML en `https://s3.amazonaws.com/tripdata/`
  (página: `https://citibikenyc.com/system-data`). Un `.zip` por mes desde 2013.
  - Usar archivos **2021+** (formato moderno: `ride_id, rideable_type, started_at, ended_at,
    start_station_id/name, end_station_id/name, start/end_lat/lng, member_casual`).
  - Archivos con prefijo `JC-` = Jersey City (pequeños, ideales para pruebas).

---

## 11. Nota de integridad (uso de IA)

Construir esto con ayuda de IA (Claude Code, etc.) **no es fraude** si entiendes cada decisión
y puedes explicarla en una entrevista. Usa la IA como **tutor**: pídele que explique mientras
construye, no que esconda. Al terminar, deberías poder reconstruir y modificar el proyecto
solo. Test: si te preguntan *"¿por qué lo hiciste así?"* y sabes responder, es tuyo.

---

*Fin del documento · v2.0*
