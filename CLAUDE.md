# CLAUDE.md — Contexto del Proyecto BikeShare Rebalancing

> Este archivo lo lee Claude Code automáticamente en cada sesión dentro de esta carpeta.
> El detalle completo del proyecto está en `Proyecto_Rebalanceo_BikeShare_v2.md` — este
> archivo es un resumen operativo para trabajar, no reemplaza esa fuente de verdad.

## 🟢 Estado actual del proyecto

**Ver `PROGRESS.md` para la fase exacta en la que estamos y qué sigue.**

## Qué es este proyecto (resumen)

Plataforma que pronostica demanda de bicis compartidas por zona/estación y recomienda
cómo redistribuir bicis (rebalanceo) usando datos reales de Citi Bike (GBFS en vivo +
histórico de viajes en CSV). Proyecto de portafolio para conseguir trabajo remoto en datos.

Documento completo de especificación: `Proyecto_Rebalanceo_BikeShare_v2.md` (en la raíz).
Ahí están: el problema de negocio, los conceptos del modelo, KPIs, alcance V1/V2, stack,
arquitectura, y el plan de 7 fases. **Cuando tengas dudas de diseño, revisa ese documento
primero.**

## Stack técnico (no te desvíes de esto sin avisar)

- Python (pandas, NumPy, scikit-learn, statsmodels/Prophet, XGBoost/LightGBM)
- PostgreSQL (Neon/Supabase free tier) — SQLite solo para pruebas locales
- Streamlit para el dashboard (V1)
- GitHub Actions para orquestación (cron de ingesta)
- NO usar servicios de nube de pago (AWS, BigQuery) en V1

## Estructura del repo

```
BikeMVP/
├── CLAUDE.md
├── PROGRESS.md
├── Proyecto_Rebalanceo_BikeShare_v2.md
├── README.md
├── requirements.txt
├── .env.example
├── schema.sql
├── .github/workflows/
├── src/
│   ├── db.py
│   ├── ingest_live.py
│   ├── ingest_trips.py
│   ├── features.py
│   ├── forecast.py
│   ├── inventory.py
│   ├── zones.py          (V2)
│   └── config.py
├── app/
│   └── streamlit_app.py
└── notebooks/
    └── exploration.ipynb
```

## Reglas de trabajo (IMPORTANTE)

1. **Trabajamos fase por fase.** No adelantes código de fases futuras sin que se pida
   explícitamente. Revisa `PROGRESS.md` antes de empezar cualquier tarea.
2. **Antes de escribir código, da un plan breve** de qué archivos vas a tocar y qué
   función cumple cada cambio. Espera confirmación si el cambio es grande.
3. **No inventes:**
   - Nombres de columnas de la base de datos → revisa `schema.sql` real, no lo recuerdes
     de memoria de otra sesión.
   - Campos de las APIs externas (GBFS, CSV de Citi Bike) → si no estás seguro del
     formato exacto, haz una llamada de prueba (`curl` o script rápido) y muestra el
     JSON/CSV real antes de escribir el parser.
   - Nombres/parámetros de funciones de librerías (Prophet, XGBoost, statsmodels) → si
     hay duda, dilo explícitamente y verifica con la versión instalada
     (`pip show <paquete>`) en vez de asumir una API que "recuerdas".
4. **Al terminar una fase o sub-tarea**, actualiza `PROGRESS.md` con: qué se hizo, qué
   decisiones se tomaron (marca las abiertas del doc de especificación como resueltas),
   y qué sigue.
5. **Explica las decisiones clave en 2-4 líneas** al terminar cada tarea — el usuario
   necesita poder explicar cada elección en una entrevista técnica.
6. **Commits pequeños y descriptivos** por entregable de fase, no un commit gigante al final.

## Fuentes de datos (referencia rápida)

- **GBFS en vivo:** auto-descubrimiento en `https://gbfs.citibikenyc.com/gbfs/gbfs.json`
- **Histórico CSV:** bucket S3, listado en `https://s3.amazonaws.com/tripdata/`
  (página: `https://citibikenyc.com/system-data`). Usar archivos 2021+ (formato moderno).
  Prefijo `JC-` = Jersey City (archivos pequeños, buenos para pruebas).

## Zona elegida para V1

**[Pendiente de decidir en Fase 1b]** — se elige comparando tamaño/volumen real de los
CSV de Hoboken vs Jersey City. Ver sección 5 del documento de especificación.
