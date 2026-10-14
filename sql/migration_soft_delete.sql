-- ============================================================
-- TaskUp — Migración v1.0 → v1.2 : Soft delete completo
--   (tareas + tipos + plantillas, y sincronización plantilla→tareas)
-- Ejecutar sobre una base que ya tiene taskup_schema.sql v1.0
-- (si recreas todo desde taskup_schema.sql, NO necesitas este archivo)
-- ============================================================

-- 1. Columna deleted_at en tareas (NULL = vigente, NOT NULL = eliminada suavemente)
ALTER TABLE daily_tasks
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_daily_tasks_deleted ON daily_tasks(deleted_at);

-- 2. Columna visible en tipos y plantillas (FALSE = eliminado por soft delete)
ALTER TABLE task_types
    ADD COLUMN IF NOT EXISTS visible BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE daily_templates
    ADD COLUMN IF NOT EXISTS visible BOOLEAN NOT NULL DEFAULT TRUE;

-- 3. Reemplazar las funciones PL/pgSQL afectadas.
--    Copia y ejecuta del archivo taskup_schema.sql v1.2 los bloques:
--      - fun_eliminar_tarea / fun_restaurar_tarea
--      - fun_eliminar_tipo / fun_toggle_task_type / fun_listar_task_types
--      - fun_listar_templates / fun_listar_templates_todas
--      - fun_insert_template / fun_update_template / fun_toggle_template
--      - fun_eliminar_template / fun_restaurar_template
--      - fun_sincronizar_template  (nueva: propaga cambios de plantilla a tareas)
--      - fun_abrir_bitacora        (ahora sincroniza SIEMPRE: las plantillas
--        nuevas/activadas aparecen al instante en la bitácora de hoy)
--      - fun_listar_tareas_dia / fun_stats_dia / fun_completar_tarea /
--        fun_actualizar_estado_tarea / fun_actualizar_tarea /
--        fun_guardar_nota / fun_buscar_archivo (filtran deleted_at IS NULL)
--    Forma más simple: volver a ejecutar TODO taskup_schema.sql v1.2 con los
--    CREATE OR REPLACE FUNCTION (los ALTER TABLE de arriba ya agregan columnas).

-- 4. Verificación rápida
-- SELECT id, descripcion, deleted_at FROM daily_tasks ORDER BY id DESC LIMIT 10;
-- SELECT id, nombre, visible FROM task_types;
-- SELECT id, nombre, visible, activo FROM daily_templates;
