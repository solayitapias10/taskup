-- TaskUp — Migración: permitir cambiar el TIPO de tarea al editar (fun_actualizar_tarea)
-- Ejecutar sobre una base existente:  psql -U postgres -d taskup -f sql\migration_tipo_en_edicion.sql

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
