-- ============================================================
-- TaskUp — Migración v1.0 → v1.1 : Soft delete de tareas
-- Ejecutar sobre una base que ya tiene taskup_schema.sql v1.0
-- (si recreas todo desde taskup_schema.sql, NO necesitas este archivo)
-- ============================================================

-- 1. Columna deleted_at (NULL = vigente, NOT NULL = eliminada suavemente)
ALTER TABLE daily_tasks
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_daily_tasks_deleted ON daily_tasks(deleted_at);

-- 2. Reemplazar fun_eliminar_tarea (ahora soft delete + motivo opcional)
--    y agregar fun_restaurar_tarea.
--    Copia y ejecuta del archivo taskup_schema.sql v1.1 los bloques:
--      - fun_eliminar_tarea   (líneas ~632-676)
--      - fun_restaurar_tarea  (líneas ~678-706)
--      - fun_abrir_bitacora / fun_listar_tareas_dia / fun_stats_dia /
--        fun_completar_tarea / fun_actualizar_estado_tarea /
--        fun_actualizar_tarea / fun_guardar_nota / fun_buscar_archivo
--        (todos ahora filtran deleted_at IS NULL)
--    o simplemente vuelve a ejecutar todo el taskup_schema.sql sobre la BD
--    con: DROP TABLE IF EXISTS ...  (los CREATE OR REPLACE FUNCTION se
--    actualizan solos, solo falta el ALTER TABLE de arriba).

-- 3. Verificación rápida
-- SELECT id, descripcion, deleted_at FROM daily_tasks ORDER BY id DESC LIMIT 10;
