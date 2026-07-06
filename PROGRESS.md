# Progreso del Proyecto — BikeShare Rebalanceo

> Actualizar este archivo al terminar cada sesión de trabajo con Claude Code.
> Al iniciar una sesión nueva, decir: "Lee PROGRESS.md, continuamos con la fase que toca."

---

## Fase 1 — Fundamentos de datos 🟡 EN PROGRESO

- [ ] 1a. Esquema (`schema.sql`) + conexión (`db.py`) + ingesta en vivo (`ingest_live.py`)
- [ ] 1b. Elegir zona de V1 (Hoboken vs Jersey City) + construir `ingest_trips.py`
- [ ] 1c. EDA inicial (`notebooks/exploration.ipynb`)

**Qué hacer en la próxima sesión:**
Empezar por 1a: crear el esquema de base de datos según §3 del documento de especificación
(tablas `stations`, `station_status`, `trips`), conectar con Neon/Supabase, y armar
`ingest_live.py` para el feed GBFS.

**Decisiones tomadas:** (ninguna todavía)

**Entregable de la fase:** base de datos poblada (estaciones + estado + viajes) y scripts
reproducibles.

---

## Fase 2 — Demanda y features ⏳ PENDIENTE

- [ ] `features.py`: series de salidas/llegadas por estación y hora + lags + estacionalidad

---

## Fase 3 — Pronóstico ⏳ PENDIENTE

- [ ] `forecast.py`: baseline → ARIMA/Prophet → XGBoost/LightGBM + validación walk-forward

---

## Fase 4 — Inventario de dos lados ⏳ PENDIENTE

- [ ] `inventory.py`: stock proyectado, banda sana, colchones, recomendación de rebalanceo

---

## Fase 5 — Dashboard ⏳ PENDIENTE

- [ ] `app/streamlit_app.py`: 3 pantallas + slider de nivel de servicio

---

## Fase 6 — Flujo y despliegue ⏳ PENDIENTE

- [ ] GitHub Actions (ingesta en vivo + histórico mensual)
- [ ] Despliegue en Streamlit Cloud / Hugging Face

---

## Fase 7 — Presentación ⏳ PENDIENTE

- [ ] README con historia de negocio, capturas, link a demo
