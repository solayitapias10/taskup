-- ============================================================
-- TaskUp — Schema SQL v1.0
-- Stack: PostgreSQL 16
-- Patrón: fat-database, PL/pgSQL → JSONB {ok, mensaje, data}
-- ============================================================


-- ============================================================
-- TABLAS
-- ============================================================

-- Catálogo de tipos de tarea
CREATE TABLE task_types (
    id         SERIAL       PRIMARY KEY,
    nombre     VARCHAR(100) NOT NULL,
    color      CHAR(7)      NOT NULL DEFAULT '#7C3AED',
    icono      VARCHAR(50)  NOT NULL DEFAULT 'ti-tag',
    activo     BOOLEAN      NOT NULL DEFAULT TRUE,   -- aparece en los selects de tareas
    visible    BOOLEAN      NOT NULL DEFAULT TRUE,   -- FALSE = eliminado (soft delete)
    created_at TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Plantillas de tareas recurrentes (fijas del día)
CREATE TABLE daily_templates (
    id          SERIAL       PRIMARY KEY,
    nombre      VARCHAR(150) NOT NULL,
    descripcion TEXT,
    tipo_id     INTEGER      REFERENCES task_types(id) ON DELETE SET NULL,
    orden       SMALLINT     NOT NULL DEFAULT 0,
    activo      BOOLEAN      NOT NULL DEFAULT TRUE,  -- se generan en la bitácora del día
    visible     BOOLEAN      NOT NULL DEFAULT TRUE,  -- FALSE = eliminada (soft delete)
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Bitácora diaria — una fila por día
CREATE TABLE daily_logs (
    id         SERIAL    PRIMARY KEY,
    fecha      DATE      NOT NULL UNIQUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Tareas del día: fijas (template_id NOT NULL) o ad-hoc (template_id NULL)
CREATE TABLE daily_tasks (
    id              SERIAL      PRIMARY KEY,
    daily_log_id    INTEGER     NOT NULL REFERENCES daily_logs(id) ON DELETE CASCADE,
    template_id     INTEGER     REFERENCES daily_templates(id) ON DELETE SET NULL,
    numero_guia     VARCHAR(50),
    tipo_id         INTEGER     REFERENCES task_types(id) ON DELETE SET NULL,
    descripcion     TEXT        NOT NULL,
    estado          VARCHAR(15) NOT NULL DEFAULT 'pendiente'
                    CHECK (estado IN ('pendiente', 'en_gestion', 'resuelto')),
    prioridad       VARCHAR(5)  NOT NULL DEFAULT 'media'
                    CHECK (prioridad IN ('baja', 'media', 'alta')),
    completado      BOOLEAN     NOT NULL DEFAULT FALSE,
    fecha_limite    DATE,
    hora_completado TIMESTAMP,
    notas           TEXT,
    deleted_at      TIMESTAMP,                          -- soft delete (NULL = vigente)
    created_at      TIMESTAMP   NOT NULL DEFAULT NOW()
);

-- Historial de cambios por tarea
CREATE TABLE task_logs (
    id          SERIAL    PRIMARY KEY,
    task_id     INTEGER   NOT NULL REFERENCES daily_tasks(id) ON DELETE CASCADE,
    descripcion TEXT      NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW()
);


-- ============================================================
-- ÍNDICES
-- ============================================================
CREATE INDEX idx_daily_tasks_log    ON daily_tasks(daily_log_id);
CREATE INDEX idx_daily_tasks_tipo   ON daily_tasks(tipo_id);
CREATE INDEX idx_daily_tasks_estado ON daily_tasks(estado);
CREATE INDEX idx_daily_logs_fecha   ON daily_logs(fecha);
CREATE INDEX idx_task_logs_task     ON task_logs(task_id);
CREATE INDEX idx_daily_tasks_deleted ON daily_tasks(deleted_at);


-- ============================================================
-- DATOS SEMILLA
-- ============================================================

INSERT INTO task_types (nombre, color, icono) VALUES
    ('Guía pendiente de entrega',  '#2563EB', 'ti-package'),
    ('Guía sin planillar',          '#D97706', 'ti-clipboard-list'),
    ('Queja / Reclamación',         '#DC2626', 'ti-alert-circle'),
    ('Consulta de cliente',         '#F59E0B', 'ti-message-circle'),
    ('Seguimiento de novedad',      '#7C3AED', 'ti-search'),
    ('Faltante',                    '#EC4899', 'ti-package-off'),
    ('Recuperación de cartaporte',  '#059669', 'ti-file-check');

-- Las plantillas referencian los tipos por posición del INSERT anterior
INSERT INTO daily_templates (nombre, descripcion, tipo_id, orden) VALUES
    ('Revisar guías sin planillar',
        'Verificar guías que llegaron sin planillar en el turno', 2, 1),
    ('Consolidar cartaportes cumplidos',
        'Revisar y consolidar cartaportes del día',              7, 2),
    ('Verificar faltantes del día',
        'Revisar el listado de faltantes y hacer seguimiento',   6, 3),
    ('Revisar novedades pendientes',
        'Verificar novedades abiertas de días anteriores',       5, 4);


-- ============================================================
-- FUNCIONES — TASK TYPES
-- ============================================================

-- Listar todos los tipos de tarea
CREATE OR REPLACE FUNCTION fun_listar_task_types()
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_data JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id',     id,
            'nombre', nombre,
            'color',  color,
            'icono',   icono,
            'activo',  activo,
            'visible', visible
        ) ORDER BY nombre
    ) INTO v_data
    FROM task_types;

    RETURN jsonb_build_object('ok', TRUE, 'data', COALESCE(v_data, '[]'::JSONB));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Insertar tipo de tarea
CREATE OR REPLACE FUNCTION fun_insert_task_type(
    p_nombre VARCHAR(100),
    p_color  CHAR(7),
    p_icono  VARCHAR(50)
)
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_id INTEGER;
BEGIN
    IF LENGTH(TRIM(p_nombre)) = 0 THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'El nombre es requerido.');
    END IF;

    INSERT INTO task_types (nombre, color, icono)
    VALUES (TRIM(p_nombre), p_color, p_icono)
    RETURNING id INTO v_id;

    RETURN jsonb_build_object('ok', TRUE, 'mensaje', 'Tipo creado.',
        'data', jsonb_build_object('id', v_id));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Actualizar tipo de tarea
CREATE OR REPLACE FUNCTION fun_update_task_type(
    p_id     INTEGER,
    p_nombre VARCHAR(100),
    p_color  CHAR(7),
    p_icono  VARCHAR(50)
)
RETURNS JSONB
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE task_types
    SET nombre = TRIM(p_nombre), color = p_color, icono = p_icono
    WHERE id = p_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'Tipo no encontrado.');
    END IF;

    RETURN jsonb_build_object('ok', TRUE, 'mensaje', 'Tipo actualizado.');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Eliminar tipo — SOFT DELETE: desactiva + oculta (no borra físicamente;
-- las tareas que lo usan conservan su referencia histórica)
CREATE OR REPLACE FUNCTION fun_eliminar_tipo(p_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_en_uso INTEGER;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM task_types WHERE id = p_id) THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'Tipo no encontrado.');
    END IF;

    -- Si está en uso, no se elimina: queda inactivo y oculto
    SELECT COUNT(*) INTO v_en_uso
    FROM daily_tasks
    WHERE tipo_id = p_id AND deleted_at IS NULL;

    UPDATE task_types SET activo = FALSE, visible = FALSE WHERE id = p_id;

    RETURN jsonb_build_object('ok', TRUE, 'mensaje',
        CASE WHEN v_en_uso > 0
             THEN 'Tipo ocultado (en uso en ' || v_en_uso || ' tarea(s); las tareas conservan su tipo).'
             ELSE 'Tipo eliminado.'
        END);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Activar / desactivar tipo
CREATE OR REPLACE FUNCTION fun_toggle_task_type(p_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_activo BOOLEAN;
BEGIN
    UPDATE task_types SET activo = NOT activo, visible = TRUE WHERE id = p_id
    RETURNING activo INTO v_activo;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'Tipo no encontrado.');
    END IF;

    RETURN jsonb_build_object('ok', TRUE,
        'mensaje', CASE WHEN v_activo THEN 'Tipo activado.' ELSE 'Tipo desactivado.' END,
        'data', jsonb_build_object('activo', v_activo));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;


-- ============================================================
-- FUNCIONES — DAILY TEMPLATES
-- ============================================================

-- Listar plantillas visibles con datos del tipo asociado
CREATE OR REPLACE FUNCTION fun_listar_templates()
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_data JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id',          dt.id,
            'nombre',      dt.nombre,
            'descripcion', dt.descripcion,
            'tipo_id',     dt.tipo_id,
            'tipo_nombre', tt.nombre,
            'tipo_color',  tt.color,
            'tipo_icono',  tt.icono,
            'orden',       dt.orden,
            'activo',      dt.activo,
            'visible',     dt.visible
        ) ORDER BY dt.orden, dt.nombre
    ) INTO v_data
    FROM daily_templates dt
    LEFT JOIN task_types tt ON tt.id = dt.tipo_id
    WHERE dt.visible = TRUE;

    RETURN jsonb_build_object('ok', TRUE, 'data', COALESCE(v_data, '[]'::JSONB));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Listar TODAS las plantillas (incluidas las eliminadas por soft delete)
CREATE OR REPLACE FUNCTION fun_listar_templates_todas()
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_data JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id',          dt.id,
            'nombre',      dt.nombre,
            'descripcion', dt.descripcion,
            'tipo_id',     dt.tipo_id,
            'tipo_nombre', tt.nombre,
            'tipo_color',  tt.color,
            'tipo_icono',  tt.icono,
            'orden',       dt.orden,
            'activo',      dt.activo,
            'visible',     dt.visible
        ) ORDER BY dt.visible DESC, dt.orden, dt.nombre
    ) INTO v_data
    FROM daily_templates dt
    LEFT JOIN task_types tt ON tt.id = dt.tipo_id;

    RETURN jsonb_build_object('ok', TRUE, 'data', COALESCE(v_data, '[]'::JSONB));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Insertar plantilla
CREATE OR REPLACE FUNCTION fun_insert_template(
    p_nombre      VARCHAR(150),
    p_descripcion TEXT,
    p_tipo_id     INTEGER,
    p_orden       SMALLINT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_id INTEGER;
BEGIN
    IF LENGTH(TRIM(p_nombre)) = 0 THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'El nombre es requerido.');
    END IF;

    INSERT INTO daily_templates (nombre, descripcion, tipo_id, orden)
    VALUES (TRIM(p_nombre), p_descripcion, p_tipo_id, p_orden)
    RETURNING id INTO v_id;

    -- Generar la tarea fija en la bitácora de HOY al instante
    PERFORM fun_abrir_bitacora(CURRENT_DATE);

    RETURN jsonb_build_object('ok', TRUE, 'mensaje', 'Plantilla creada (tarea fijada para hoy).',
        'data', jsonb_build_object('id', v_id));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Actualizar plantilla + propagar los cambios a las tareas ya generadas
CREATE OR REPLACE FUNCTION fun_update_template(
    p_id          INTEGER,
    p_nombre      VARCHAR(150),
    p_descripcion TEXT,
    p_tipo_id     INTEGER,
    p_orden       SMALLINT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_sync JSONB;
BEGIN
    UPDATE daily_templates
    SET nombre      = TRIM(p_nombre),
        descripcion = p_descripcion,
        tipo_id     = p_tipo_id,
        orden       = p_orden
    WHERE id = p_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'Plantilla no encontrada.');
    END IF;

    -- Propagar a las instancias existentes (hoy + días anteriores)
    v_sync := fun_sincronizar_template(p_id);

    RETURN jsonb_build_object('ok', TRUE, 'mensaje',
        'Plantilla actualizada. ' || COALESCE(v_sync->>'mensaje', ''),
        'data', jsonb_build_object('sincronizado', v_sync));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Eliminar plantilla — SOFT DELETE: se oculta y deja de generarse en la bitácora.
-- SIEMPRE oculta también las tareas ya generadas por esa plantilla (hoy y días
-- anteriores) con soft delete, para que no queden "fantasmas" en el dashboard.
-- p_eliminar_tareas queda por compatibilidad; puedes pasar FALSE si quieres
-- conservarlas como registro histórico.
CREATE OR REPLACE FUNCTION fun_eliminar_template(
    p_id               INTEGER,
    p_eliminar_tareas  BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_tareas INTEGER := 0;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM daily_templates WHERE id = p_id) THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'Plantilla no encontrada.');
    END IF;

    -- Ocultar la plantilla (ya no aparece ni se genera en nuevos días)
    UPDATE daily_templates SET visible = FALSE, activo = FALSE WHERE id = p_id;

    -- Soft-delete de las instancias generadas por esta plantilla (hoy y días
    -- anteriores). Por defecto SIEMPRE se ocultan; pasa p_eliminar_tareas=FALSE
    -- solo si quieres conservarlas como registro histórico.
    IF p_eliminar_tareas IS NULL OR p_eliminar_tareas THEN
        UPDATE daily_tasks SET deleted_at = NOW()
        WHERE template_id = p_id
          AND deleted_at IS NULL;

        GET DIAGNOSTICS v_tareas = ROW_COUNT;
    END IF;

    RETURN jsonb_build_object('ok', TRUE, 'mensaje',
        'Plantilla eliminada.' ||
        CASE WHEN v_tareas > 0
             THEN ' Se ocultaron ' || v_tareas || ' tarea(s) pendientes de la bitácora.'
             ELSE '' END);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Restaurar plantilla eliminada (vuelve a ser visible y activa)
CREATE OR REPLACE FUNCTION fun_restaurar_template(p_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM daily_templates WHERE id = p_id) THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'Plantilla no encontrada.');
    END IF;

    UPDATE daily_templates SET visible = TRUE, activo = TRUE WHERE id = p_id;

    -- Reactivar: restaurar las instancias que se ocultaron junto con la plantilla
    UPDATE daily_tasks SET deleted_at = NULL
    WHERE template_id = p_id AND deleted_at IS NOT NULL;

    -- Y generar de inmediato la tarea fija en la bitácora de HOY
    PERFORM fun_abrir_bitacora(CURRENT_DATE);

    RETURN jsonb_build_object('ok', TRUE, 'mensaje', 'Plantilla restaurada.');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Activar / desactivar plantilla
CREATE OR REPLACE FUNCTION fun_toggle_template(p_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_activo BOOLEAN;
BEGIN
    UPDATE daily_templates SET activo = NOT activo, visible = TRUE WHERE id = p_id
    RETURNING activo INTO v_activo;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'Plantilla no encontrada.');
    END IF;

    -- Al reactivarla: restaurar sus instancias borradas suavemente y propagar sus datos.
    -- Al desactivarla: ocultar también sus tareas de la bitácora (hoy y días anteriores),
    -- para que "desactivar" se refleje de inmediato en el dashboard.
    IF v_activo THEN
        UPDATE daily_tasks SET deleted_at = NULL
        WHERE template_id = p_id AND deleted_at IS NOT NULL;

        PERFORM fun_sincronizar_template(p_id);
        PERFORM fun_abrir_bitacora(CURRENT_DATE);
    ELSE
        UPDATE daily_tasks SET deleted_at = NOW()
        WHERE template_id = p_id AND deleted_at IS NULL;
    END IF;

    RETURN jsonb_build_object('ok', TRUE,
        'mensaje', CASE WHEN v_activo THEN 'Plantilla activada.' ELSE 'Plantilla desactivada.' END,
        'data', jsonb_build_object('activo', v_activo));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;


-- ============================================================
-- FUNCIONES — BITÁCORA (núcleo del sistema)
-- ============================================================

-- Abrir o recuperar la bitácora del día.
-- Si no existe: crea el daily_log e inserta las tareas fijas activas.
CREATE OR REPLACE FUNCTION fun_abrir_bitacora(
    p_fecha DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_log_id   INTEGER;
    v_es_nuevo BOOLEAN := FALSE;
BEGIN
    SELECT id INTO v_log_id FROM daily_logs WHERE fecha = p_fecha;

    IF NOT FOUND THEN
        INSERT INTO daily_logs (fecha) VALUES (p_fecha) RETURNING id INTO v_log_id;
        v_es_nuevo := TRUE;
    END IF;

    -- Sincronizar SIEMPRE: las plantillas nuevas/activadas que aún no tengan
    -- instancia en este día se generan al instante (no solo al crear la bitácora).
    INSERT INTO daily_tasks (daily_log_id, template_id, tipo_id, descripcion, estado, prioridad)
    SELECT
        v_log_id,
        dt.id,
        dt.tipo_id,
        dt.nombre,
        'pendiente',
        'media'
    FROM daily_templates dt
    WHERE dt.activo = TRUE
      AND dt.visible = TRUE
      AND NOT EXISTS (
          SELECT 1 FROM daily_tasks t2
          WHERE t2.daily_log_id = v_log_id
            AND t2.template_id  = dt.id
      )
    ORDER BY dt.orden, dt.nombre;

    -- Si la plantilla fue reactivada/restaurada y su instancia del día estaba
    -- oculta por soft delete, se trae de vuelta a la bitácora.
    UPDATE daily_tasks t
    SET deleted_at = NULL
    FROM daily_templates dt
    WHERE t.template_id = dt.id
      AND t.daily_log_id = v_log_id
      AND t.deleted_at IS NOT NULL
      AND dt.activo = TRUE
      AND dt.visible = TRUE;

    -- Mantener el texto/tipo sincronizado con la plantilla en las instancias vigentes
    UPDATE daily_tasks t
    SET descripcion = dt.nombre,
        tipo_id     = dt.tipo_id
    FROM daily_templates dt
    WHERE t.template_id = dt.id
      AND t.daily_log_id = v_log_id
      AND t.deleted_at IS NULL
      AND (t.descripcion IS DISTINCT FROM dt.nombre OR t.tipo_id IS DISTINCT FROM dt.tipo_id);

    RETURN jsonb_build_object(
        'ok',   TRUE,
        'data', jsonb_build_object('log_id', v_log_id, 'es_nuevo', v_es_nuevo)
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Propagar los cambios de una plantilla a sus instancias ya generadas
-- (hoy y días anteriores): nombre, descripción, tipo y orden.
CREATE OR REPLACE FUNCTION fun_sincronizar_template(p_template_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_afectadas INTEGER := 0;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM daily_templates WHERE id = p_template_id) THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'Plantilla no encontrada.');
    END IF;

    UPDATE daily_tasks t
    SET descripcion = dt.nombre,
        tipo_id     = dt.tipo_id,
        estado      = CASE WHEN t.completado THEN t.estado ELSE 'pendiente' END
    FROM daily_templates dt
    WHERE t.template_id = dt.id
      AND t.template_id = p_template_id
      AND t.deleted_at IS NULL;

    GET DIAGNOSTICS v_afectadas = ROW_COUNT;

    RETURN jsonb_build_object('ok', TRUE, 'mensaje',
        'Tareas actualizadas desde la plantilla: ' || v_afectadas,
        'data', jsonb_build_object('afectadas', v_afectadas));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Listar tareas del día separadas en fijas y ad-hoc
CREATE OR REPLACE FUNCTION fun_listar_tareas_dia(
    p_fecha DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_log_id INTEGER;
    v_fijas  JSONB;
    v_adhoc  JSONB;
BEGIN
    SELECT id INTO v_log_id FROM daily_logs WHERE fecha = p_fecha;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', TRUE, 'data', jsonb_build_object(
            'log_id', NULL,
            'fijas',  '[]'::JSONB,
            'adhoc',  '[]'::JSONB
        ));
    END IF;

    -- Tareas fijas ordenadas por el orden de la plantilla
    SELECT jsonb_agg(
        jsonb_build_object(
            'id',              t.id,
            'template_id',     t.template_id,
            'tipo_id',         t.tipo_id,
            'tipo_nombre',     tt.nombre,
            'tipo_color',      tt.color,
            'tipo_icono',      tt.icono,
            'descripcion',     t.descripcion,
            'estado',          t.estado,
            'prioridad',       t.prioridad,
            'completado',      t.completado,
            'hora_completado', TO_CHAR(t.hora_completado, 'HH24:MI'),
            'notas',           t.notas
        ) ORDER BY dm.orden, t.id
    ) INTO v_fijas
    FROM daily_tasks t
    LEFT JOIN task_types     tt ON tt.id = t.tipo_id
    LEFT JOIN daily_templates dm ON dm.id = t.template_id
    WHERE t.daily_log_id = v_log_id AND t.template_id IS NOT NULL
      AND t.deleted_at IS NULL;

    -- Tareas ad-hoc ordenadas por creación
    SELECT jsonb_agg(
        jsonb_build_object(
            'id',              t.id,
            'numero_guia',     t.numero_guia,
            'tipo_id',         t.tipo_id,
            'tipo_nombre',     tt.nombre,
            'tipo_color',      tt.color,
            'tipo_icono',      tt.icono,
            'descripcion',     t.descripcion,
            'estado',          t.estado,
            'prioridad',       t.prioridad,
            'completado',      t.completado,
            'fecha_limite',    TO_CHAR(t.fecha_limite, 'DD/MM/YYYY'),
            'hora_completado', TO_CHAR(t.hora_completado, 'HH24:MI'),
            'notas',           t.notas
        ) ORDER BY t.created_at
    ) INTO v_adhoc
    FROM daily_tasks t
    LEFT JOIN task_types tt ON tt.id = t.tipo_id
    WHERE t.daily_log_id = v_log_id AND t.template_id IS NULL
      AND t.deleted_at IS NULL;

    RETURN jsonb_build_object(
        'ok',   TRUE,
        'data', jsonb_build_object(
            'log_id', v_log_id,
            'fecha',  TO_CHAR(p_fecha, 'DD/MM/YYYY'),
            'fijas',  COALESCE(v_fijas, '[]'::JSONB),
            'adhoc',  COALESCE(v_adhoc, '[]'::JSONB)
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Estadísticas del día para los contadores del dashboard
CREATE OR REPLACE FUNCTION fun_stats_dia(
    p_fecha DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_log_id  INTEGER;
    v_total   INTEGER := 0;
    v_pend    INTEGER := 0;
    v_resuel  INTEGER := 0;
    v_vencid  INTEGER := 0;
BEGIN
    SELECT id INTO v_log_id FROM daily_logs WHERE fecha = p_fecha;

    IF FOUND THEN
        SELECT
            COUNT(*),
            COUNT(*) FILTER (WHERE completado = FALSE),
            COUNT(*) FILTER (WHERE completado = TRUE),
            COUNT(*) FILTER (WHERE completado = FALSE
                             AND fecha_limite IS NOT NULL
                             AND fecha_limite < CURRENT_DATE)
        INTO v_total, v_pend, v_resuel, v_vencid
        FROM daily_tasks
        WHERE daily_log_id = v_log_id
          AND deleted_at IS NULL;
    END IF;

    RETURN jsonb_build_object(
        'ok',   TRUE,
        'data', jsonb_build_object(
            'total',      v_total,
            'pendientes', v_pend,
            'resueltas',  v_resuel,
            'vencidas',   v_vencid
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Insertar tarea ad-hoc al día abierto
CREATE OR REPLACE FUNCTION fun_insert_tarea_adhoc(
    p_daily_log_id INTEGER,
    p_tipo_id      INTEGER,
    p_descripcion  TEXT,
    p_numero_guia  VARCHAR(50) DEFAULT NULL,
    p_prioridad    VARCHAR(5)  DEFAULT 'media',
    p_fecha_limite DATE        DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_id INTEGER;
BEGIN
    IF LENGTH(TRIM(p_descripcion)) = 0 THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'La descripción es requerida.');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM daily_logs WHERE id = p_daily_log_id) THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'Bitácora no encontrada.');
    END IF;

    INSERT INTO daily_tasks
        (daily_log_id, numero_guia, tipo_id, descripcion, prioridad, fecha_limite)
    VALUES
        (p_daily_log_id,
         NULLIF(TRIM(COALESCE(p_numero_guia, '')), ''),
         p_tipo_id,
         TRIM(p_descripcion),
         p_prioridad,
         p_fecha_limite)
    RETURNING id INTO v_id;

    INSERT INTO task_logs (task_id, descripcion) VALUES (v_id, 'Tarea creada.');

    RETURN jsonb_build_object('ok', TRUE, 'mensaje', 'Tarea creada.',
        'data', jsonb_build_object('id', v_id));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Toggle checkbox: completa o desmarca la tarea
CREATE OR REPLACE FUNCTION fun_completar_tarea(
    p_task_id INTEGER,
    p_notas   TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_actual BOOLEAN;
    v_nuevo  BOOLEAN;
BEGIN
    SELECT completado INTO v_actual FROM daily_tasks WHERE id = p_task_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'Tarea no encontrada.');
    END IF;

    v_nuevo := NOT v_actual;

    UPDATE daily_tasks
    SET completado      = v_nuevo,
        estado          = CASE WHEN v_nuevo THEN 'resuelto' ELSE 'pendiente' END,
        hora_completado = CASE WHEN v_nuevo THEN NOW() ELSE NULL END,
        notas           = COALESCE(p_notas, notas)
    WHERE id = p_task_id AND deleted_at IS NULL;

    INSERT INTO task_logs (task_id, descripcion)
    VALUES (p_task_id,
        CASE WHEN v_nuevo THEN 'Marcada como completada.' ELSE 'Desmarcada.' END);

    RETURN jsonb_build_object('ok', TRUE,
        'data', jsonb_build_object('completado', v_nuevo));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Cambiar estado de una tarea (chip de estado)
CREATE OR REPLACE FUNCTION fun_actualizar_estado_tarea(
    p_task_id INTEGER,
    p_estado  VARCHAR(15),
    p_notas   TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql AS $$
BEGIN
    IF p_estado NOT IN ('pendiente', 'en_gestion', 'resuelto') THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'Estado inválido.');
    END IF;

    UPDATE daily_tasks
    SET estado          = p_estado,
        completado      = (p_estado = 'resuelto'),
        hora_completado = CASE WHEN p_estado = 'resuelto' THEN NOW() ELSE NULL END,
        notas           = COALESCE(p_notas, notas)
    WHERE id = p_task_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'Tarea no encontrada.');
    END IF;

    INSERT INTO task_logs (task_id, descripcion)
    VALUES (p_task_id, 'Estado cambiado a: ' || p_estado || '.');

    RETURN jsonb_build_object('ok', TRUE, 'mensaje', 'Estado actualizado.');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Editar descripción, prioridad, notas y fecha límite de una tarea
CREATE OR REPLACE FUNCTION fun_actualizar_tarea(
    p_task_id      INTEGER,
    p_descripcion  TEXT,
    p_prioridad    VARCHAR(5),
    p_notas        TEXT DEFAULT NULL,
    p_fecha_limite DATE   DEFAULT NULL,
    p_tipo_id      INTEGER DEFAULT NULL,
    p_numero_guia  VARCHAR(50) DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_old_tipo INTEGER;
    v_tipo_nombre TEXT;
BEGIN
    SELECT tipo_id INTO v_old_tipo FROM daily_tasks WHERE id = p_task_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'Tarea no encontrada.');
    END IF;

    -- Validar que el tipo exista y esté vigente (si se envió)
    IF p_tipo_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM task_types WHERE id = p_tipo_id AND deleted_at IS NULL) THEN
            RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'El tipo de tarea seleccionado no existe o está eliminado.');
        END IF;
    END IF;

    UPDATE daily_tasks
    SET descripcion  = TRIM(p_descripcion),
        prioridad    = p_prioridad,
        notas        = p_notas,
        fecha_limite = p_fecha_limite,
        tipo_id      = COALESCE(p_tipo_id, tipo_id),
        numero_guia  = COALESCE(NULLIF(TRIM(COALESCE(p_numero_guia, '')), ''), numero_guia)
    WHERE id = p_task_id AND deleted_at IS NULL;

    -- Registrar el cambio de tipo en el historial
    IF p_tipo_id IS NOT NULL AND p_tipo_id IS DISTINCT FROM v_old_tipo THEN
        SELECT nombre INTO v_tipo_nombre FROM task_types WHERE id = p_tipo_id;
        INSERT INTO task_logs (task_id, descripcion)
        VALUES (p_task_id, 'Tipo cambiado a: ' || COALESCE(v_tipo_nombre, p_tipo_id::TEXT) || '.');
    END IF;

    INSERT INTO task_logs (task_id, descripcion) VALUES (p_task_id, 'Tarea editada.');

    RETURN jsonb_build_object('ok', TRUE, 'mensaje', 'Tarea actualizada.');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Eliminar tarea — SOFT DELETE: marca deleted_at, el registro queda intacto
-- Aplica a cualquier tarea (fija o ad-hoc). No borra físicamente nada.
CREATE OR REPLACE FUNCTION fun_eliminar_tarea(
    p_task_id INTEGER,
    p_motivo  TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_deleted_at TIMESTAMP;
    v_msg        TEXT;
BEGIN
    SELECT deleted_at INTO v_deleted_at
    FROM daily_tasks
    WHERE id = p_task_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'Tarea no encontrada.');
    END IF;

    IF v_deleted_at IS NOT NULL THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'La tarea ya estaba eliminada.');
    END IF;

    UPDATE daily_tasks
    SET deleted_at = NOW()
    WHERE id = p_task_id
    RETURNING deleted_at INTO v_deleted_at;

    -- Registrar la acción en el historial de la tarea
    INSERT INTO task_logs (task_id, descripcion)
    VALUES (p_task_id,
        'Tarea eliminada (soft delete): ' || TO_CHAR(v_deleted_at, 'DD/MM/YYYY HH24:MI')
        || CASE WHEN NULLIF(TRIM(COALESCE(p_motivo, '')), '') IS NULL
                THEN '' ELSE ' — Motivo: ' || TRIM(p_motivo) END);

    v_msg := 'Tarea eliminada.';

    RETURN jsonb_build_object('ok', TRUE, 'mensaje', v_msg,
        'data', jsonb_build_object('id', p_task_id, 'deleted_at',
                                   TO_CHAR(v_deleted_at, 'DD/MM/YYYY HH24:MI')));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Restaurar una tarea eliminada con soft delete
CREATE OR REPLACE FUNCTION fun_restaurar_tarea(p_task_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_deleted_at TIMESTAMP;
BEGIN
    SELECT deleted_at INTO v_deleted_at
    FROM daily_tasks
    WHERE id = p_task_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'Tarea no encontrada.');
    END IF;

    IF v_deleted_at IS NULL THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'La tarea no está eliminada.');
    END IF;

    UPDATE daily_tasks SET deleted_at = NULL WHERE id = p_task_id;

    INSERT INTO task_logs (task_id, descripcion)
    VALUES (p_task_id, 'Tarea restaurada.');

    RETURN jsonb_build_object('ok', TRUE, 'mensaje', 'Tarea restaurada.');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Guardar o actualizar la nota de una tarea
CREATE OR REPLACE FUNCTION fun_guardar_nota(
    p_task_id INTEGER,
    p_nota    TEXT
)
RETURNS JSONB
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM daily_tasks WHERE id = p_task_id AND deleted_at IS NULL) THEN
        RETURN jsonb_build_object('ok', FALSE, 'mensaje', 'Tarea no encontrada.');
    END IF;

    UPDATE daily_tasks SET notas = TRIM(p_nota) WHERE id = p_task_id AND deleted_at IS NULL;

    INSERT INTO task_logs (task_id, descripcion)
    VALUES (p_task_id, 'Nota guardada: ' || TRIM(p_nota));

    RETURN jsonb_build_object('ok', TRUE, 'mensaje', 'Nota guardada.');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;

-- Obtener historial de cambios de una tarea
CREATE OR REPLACE FUNCTION fun_historial_tarea(p_task_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_data JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id',          id,
            'descripcion', descripcion,
            'created_at',  TO_CHAR(created_at, 'DD/MM/YYYY HH24:MI')
        ) ORDER BY created_at DESC
    ) INTO v_data
    FROM task_logs
    WHERE task_id = p_task_id;

    RETURN jsonb_build_object('ok', TRUE, 'data', COALESCE(v_data, '[]'::JSONB));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;


-- ============================================================
-- FUNCIONES — ARCHIVO
-- ============================================================

-- Buscar tareas resueltas en el historial
-- Filtra por término (descripción o número de guía), rango de fechas, o ambos
CREATE OR REPLACE FUNCTION fun_buscar_archivo(
    p_termino     TEXT DEFAULT NULL,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_data JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id',              t.id,
            'fecha',           TO_CHAR(l.fecha, 'DD/MM/YYYY'),
            'numero_guia',     t.numero_guia,
            'tipo_nombre',     tt.nombre,
            'tipo_color',      tt.color,
            'tipo_icono',      tt.icono,
            'descripcion',     t.descripcion,
            'estado',          t.estado,
            'hora_completado', TO_CHAR(t.hora_completado, 'DD/MM/YYYY HH24:MI'),
            'notas',           t.notas
        ) ORDER BY l.fecha DESC, t.id DESC
    ) INTO v_data
    FROM daily_tasks t
    JOIN  daily_logs   l  ON l.id  = t.daily_log_id
    LEFT JOIN task_types tt ON tt.id = t.tipo_id
    WHERE t.completado = TRUE
      AND t.deleted_at IS NULL
      AND (p_fecha_desde IS NULL OR l.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR l.fecha <= p_fecha_hasta)
      AND (
            p_termino IS NULL
            OR LOWER(t.descripcion)              LIKE '%' || LOWER(p_termino) || '%'
            OR LOWER(COALESCE(t.numero_guia, '')) LIKE '%' || LOWER(p_termino) || '%'
          )
    LIMIT 200;

    RETURN jsonb_build_object('ok', TRUE, 'data', COALESCE(v_data, '[]'::JSONB));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', FALSE, 'mensaje', SQLERRM);
END;
$$;
