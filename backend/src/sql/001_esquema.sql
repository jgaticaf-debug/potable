-- Esquema central de Potable.
--
-- Traduccion del modelo entidad-relacion del documento. Las diferencias
-- frente al esquema local de SQLite son deliberadas:
--   * usuarios.clave_hash existe solo aqui, nunca viaja al dispositivo
--   * los valores medidos usan NUMERIC y no punto flotante, porque se
--     contrastan contra un limite normativo y el redondeo importa
--   * no existe la tabla preferencias: es almacenamiento del telefono

BEGIN;

CREATE TABLE organizaciones (
    id      BIGSERIAL PRIMARY KEY,
    nombre  TEXT        NOT NULL,
    nit     TEXT        NOT NULL,
    activa  BOOLEAN     NOT NULL DEFAULT TRUE,
    creado  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TYPE rol_usuario AS ENUM ('operario', 'calidad', 'administrador');

CREATE TABLE usuarios (
    id              BIGSERIAL PRIMARY KEY,
    organizacion_id BIGINT      NOT NULL REFERENCES organizaciones (id),
    nombre          TEXT        NOT NULL,
    correo          TEXT        NOT NULL UNIQUE,
    clave_hash      TEXT        NOT NULL,
    rol             rol_usuario NOT NULL DEFAULT 'operario',
    activo          BOOLEAN     NOT NULL DEFAULT TRUE,
    creado          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE zonas (
    id              BIGSERIAL PRIMARY KEY,
    organizacion_id BIGINT      NOT NULL REFERENCES organizaciones (id),
    nombre          TEXT        NOT NULL,
    descripcion     TEXT        NOT NULL DEFAULT '',
    activa          BOOLEAN     NOT NULL DEFAULT TRUE,
    creado          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT zonas_nombre_unico UNIQUE (organizacion_id, nombre)
);

CREATE TYPE tipo_punto AS ENUM (
    'pozo', 'tanque', 'linea', 'tratamiento', 'consumo'
);

CREATE TABLE puntos (
    id              BIGSERIAL PRIMARY KEY,
    organizacion_id BIGINT      NOT NULL REFERENCES organizaciones (id),
    zona_id         BIGINT      NOT NULL REFERENCES zonas (id),
    nombre          TEXT        NOT NULL,
    tipo            tipo_punto  NOT NULL DEFAULT 'pozo',
    instrumentado   BOOLEAN     NOT NULL DEFAULT FALSE,
    latitud         NUMERIC(9, 6),
    longitud        NUMERIC(9, 6),
    creado          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE dispositivos (
    id                 BIGSERIAL PRIMARY KEY,
    punto_id           BIGINT NOT NULL REFERENCES puntos (id) ON DELETE CASCADE,
    identificador      TEXT   NOT NULL UNIQUE,
    tipo_sensor        TEXT   NOT NULL,
    ultima_calibracion DATE   NOT NULL
);

CREATE TYPE via_captura AS ENUM ('sensor', 'manual');

CREATE TABLE parametros (
    id            BIGSERIAL PRIMARY KEY,
    nombre        TEXT        NOT NULL,
    unidad        TEXT        NOT NULL,
    via_captura   via_captura NOT NULL DEFAULT 'manual',
    limite_min    NUMERIC(10, 4),
    limite_max    NUMERIC(10, 4),
    alerta_min    NUMERIC(10, 4),
    alerta_max    NUMERIC(10, 4),
    critico       BOOLEAN     NOT NULL DEFAULT FALSE,
    version_norma TEXT        NOT NULL DEFAULT 'COGUANOR NTG 29001',
    descripcion   TEXT        NOT NULL DEFAULT '',
    CONSTRAINT parametros_rango CHECK (
        limite_min IS NULL OR limite_max IS NULL OR limite_min <= limite_max
    )
);

CREATE TYPE clasificacion AS ENUM ('apto', 'riesgo', 'incumplimiento');

CREATE TABLE muestras (
    id                     BIGSERIAL PRIMARY KEY,
    punto_id               BIGINT        NOT NULL REFERENCES puntos (id),
    usuario_id             BIGINT        NOT NULL REFERENCES usuarios (id),
    parametro_limitante_id BIGINT        REFERENCES parametros (id),

    -- fecha_hora: cuando se tomo la muestra en el punto
    -- creado_en:  cuando quedo registrada en el dispositivo
    -- recibido_en: cuando llego a este servidor
    fecha_hora             TIMESTAMPTZ   NOT NULL,
    creado_en              TIMESTAMPTZ   NOT NULL,
    recibido_en            TIMESTAMPTZ   NOT NULL DEFAULT now(),

    latitud_captura        NUMERIC(9, 6),
    longitud_captura       NUMERIC(9, 6),
    clasificacion_global   clasificacion NOT NULL,
    observaciones          TEXT          NOT NULL DEFAULT '',

    -- Identificador que la muestra tenia en el telefono. Junto con el
    -- usuario evita duplicar una muestra si el envio se reintenta.
    id_local               BIGINT,
    CONSTRAINT muestras_sin_duplicar UNIQUE (usuario_id, id_local)
);

CREATE TABLE mediciones (
    id            BIGSERIAL PRIMARY KEY,
    muestra_id    BIGINT        NOT NULL REFERENCES muestras (id) ON DELETE CASCADE,
    parametro_id  BIGINT        NOT NULL REFERENCES parametros (id),
    valor         NUMERIC(12, 4) NOT NULL,
    origen        via_captura   NOT NULL DEFAULT 'manual',
    clasificacion clasificacion NOT NULL,
    CONSTRAINT mediciones_una_por_parametro UNIQUE (muestra_id, parametro_id)
);

CREATE TABLE alertas (
    id         BIGSERIAL PRIMARY KEY,
    muestra_id BIGINT        NOT NULL REFERENCES muestras (id) ON DELETE CASCADE,
    punto_id   BIGINT        NOT NULL REFERENCES puntos (id),
    tipo       clasificacion NOT NULL,
    detalle    TEXT          NOT NULL,
    fecha      TIMESTAMPTZ   NOT NULL,
    atendida   BOOLEAN       NOT NULL DEFAULT FALSE,
    atendida_por BIGINT      REFERENCES usuarios (id),
    atendida_en  TIMESTAMPTZ
);

-- Bitacora inmutable. Solo admite INSERT: ninguna ruta la edita ni la borra.
-- usuario_id no es llave foranea a proposito, para que dar de baja a una
-- persona no destruya su rastro. El nombre y el rol se copian al momento
-- del hecho por la misma razon.
CREATE TABLE auditoria (
    id             BIGSERIAL PRIMARY KEY,
    fecha          TIMESTAMPTZ NOT NULL DEFAULT now(),
    usuario_id     BIGINT      NOT NULL,
    usuario_nombre TEXT        NOT NULL,
    rol            TEXT        NOT NULL,
    accion         TEXT        NOT NULL,
    entidad_id     BIGINT,
    detalle        TEXT        NOT NULL DEFAULT '',
    origen_ip      TEXT
);

CREATE INDEX idx_usuarios_org        ON usuarios (organizacion_id);
CREATE INDEX idx_zonas_org           ON zonas (organizacion_id);
CREATE INDEX idx_puntos_zona         ON puntos (zona_id);
CREATE INDEX idx_dispositivos_punto  ON dispositivos (punto_id);
CREATE INDEX idx_muestras_punto      ON muestras (punto_id);
CREATE INDEX idx_muestras_fecha      ON muestras (fecha_hora DESC);
CREATE INDEX idx_muestras_usuario    ON muestras (usuario_id);
CREATE INDEX idx_mediciones_muestra  ON mediciones (muestra_id);
CREATE INDEX idx_alertas_atendida    ON alertas (atendida);
CREATE INDEX idx_alertas_punto       ON alertas (punto_id);
CREATE INDEX idx_auditoria_fecha     ON auditoria (fecha DESC);
CREATE INDEX idx_auditoria_usuario   ON auditoria (usuario_id);

COMMIT;
