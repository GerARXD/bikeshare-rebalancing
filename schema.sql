-- schema.sql
-- Esquema inicial de la base de datos para el proyecto BikeShare Rebalancing
-- Basado en la sección 3 del documento de especificación (Proyecto_Rebalanceo_BikeShare_v2.md)
-- Nota: los nombres de columna del CSV histórico varían según el año. Verificar contra
-- un archivo real de 2021+ antes de asumir estos nombres como definitivos en ingest_trips.py.

-- Estaciones (info fija: ubicación, capacidad)
CREATE TABLE IF NOT EXISTS stations (
    station_id      TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    lat             DOUBLE PRECISION NOT NULL,
    lon             DOUBLE PRECISION NOT NULL,
    capacity        INTEGER,
    zone_id         TEXT,               -- se llena en V2 (clustering espacial)
    updated_at      TIMESTAMP DEFAULT NOW()
);

-- Estado en vivo de cada estación (snapshot recurrente vía GBFS)
CREATE TABLE IF NOT EXISTS station_status (
    id                      SERIAL PRIMARY KEY,
    station_id              TEXT NOT NULL REFERENCES stations(station_id),
    num_bikes_available     INTEGER NOT NULL,
    num_ebikes_available    INTEGER,
    num_docks_available     INTEGER NOT NULL,
    is_renting              BOOLEAN,
    is_returning             BOOLEAN,
    recorded_at             TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_station_status_station_time
    ON station_status (station_id, recorded_at);

-- Histórico de viajes (carga mensual desde CSV)
CREATE TABLE IF NOT EXISTS trips (
    ride_id             TEXT PRIMARY KEY,
    rideable_type       TEXT,
    started_at          TIMESTAMP NOT NULL,
    ended_at            TIMESTAMP NOT NULL,
    start_station_id    TEXT REFERENCES stations(station_id),
    end_station_id      TEXT REFERENCES stations(station_id),
    member_casual       TEXT
);

CREATE INDEX IF NOT EXISTS idx_trips_start_station_time
    ON trips (start_station_id, started_at);
CREATE INDEX IF NOT EXISTS idx_trips_end_station_time
    ON trips (end_station_id, ended_at);
