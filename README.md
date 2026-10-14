# TaskUp 📋

Sistema personal de bitácora diaria de pendientes para el trabajo en RQC (reexpedidor de envíos).
Todas las operaciones pasan por **procedimientos/funciones almacenadas** en PostgreSQL (patrón *fat database*, igual que SIGP): PHP solo hace de puente.

## Stack
- **Backend:** PHP 8+ (sin framework) + PDO `pgsql`
- **Base de datos:** PostgreSQL — 19 funciones `fun_*` que devuelven JSONB `{ok, mensaje, data}`
- **Frontend:** HTML + CSS + JS vanilla (estilo ClickUp: sidebar, chips de estado, puntos de color por tipo)

## Módulos
| Página | Ruta | Descripción |
|---|---|---|
| Bitácora del día | `index.php?p=dashboard` | Tareas fijas autogeneradas + ad-hoc, stats, checkbox, estados, notas, historial |
| Todas las tareas | `index.php?p=tasks` | Lista con filtros (fuente, estado, tipo, orden, búsqueda) |
| Archivo | `index.php?p=archive` | Búsqueda de tareas resueltas por guía/término y rango de fechas |
| Tareas fijas | `index.php?p=templates` | CRUD de plantillas diarias (activar/desactivar, orden, tipo) |
| Tipos | `index.php?p=types` | CRUD de tipos de tarea (nombre, color, ícono) |

## Modelo de datos
- `task_types` — catálogo de tipos (7 sembrados: guía pendiente, sin planillar, queja, consulta, novedad, faltante, cartaporte)
- `daily_templates` — plantillas de tareas recurrentes
- `daily_logs` — una fila por día (la bitácora)
- `daily_tasks` — instancias del día: fijas (`template_id NOT NULL`) o ad-hoc (`template_id NULL`, con `numero_guia`)
- `task_logs` — historial de cambios por tarea

Al abrir el dashboard, `fun_abrir_bitacora` crea el log del día y genera las tareas fijas activas automáticamente.

## Instalación
```bash
createdb TaskUp.db
psql -d TaskUp.db -f sql/taskup_schema.sql   # tablas + seed + 19 funciones
# ajustar credenciales en config/db.php (DB_HOST/PORT/NAME/USER/PASS)
php -S localhost:8000                          # abrir http://localhost:8000
```

## API
Endpoint único `api/api.php` (POST JSON `{action, ...params}`). Cada acción mapea a una función almacenada:
`toggle · estado · crear · editar · nota · eliminar · historial · buscar_archivo · listar_tipos · crear_tipo · editar_tipo · toggle_tipo · listar_templates · crear_template · editar_template · toggle_template`

Reglas de negocio en PL/pgSQL: las tareas fijas no se pueden eliminar ni editar (solo completar); toda acción queda registrada en `task_logs`.
