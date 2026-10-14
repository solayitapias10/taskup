<?php
// TaskUp — endpoint único. Cada acción = 1 función almacenada.
require_once __DIR__ . '/../config/db.php';
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['ok' => false, 'mensaje' => 'Método no permitido.']); exit;
}

$in  = json_decode(file_get_contents('php://input'), true) ?? $_POST;
$act = $in['action'] ?? '';
$nul = fn($k) => (isset($in[$k]) && trim((string)$in[$k]) !== '') ? trim((string)$in[$k]) : null;
$int = fn($v) => ($v === null || $v === '') ? null : (int)$v;

switch ($act) {
    // ---- Tareas ----
    case 'toggle':
        $r = db_call('fun_completar_tarea', [(int)$in['id'], $nul('nota')], ['::int', '::text']); break;
    case 'estado':
        $r = db_call('fun_actualizar_estado_tarea', [(int)$in['id'], $in['estado'] ?? '', $nul('notas')], ['::int', '::varchar', '::text']); break;
    case 'crear':
        $r = db_call('fun_insert_tarea_adhoc',
            [(int)$in['log_id'], (int)$in['tipo_id'], $in['descripcion'] ?? '', $nul('numero_guia'),
             $in['prioridad'] ?? 'media', $nul('fecha_limite')],
            ['::int', '::int', '::text', '::varchar', '::varchar', '::date']); break;
    case 'editar':
        $r = db_call('fun_actualizar_tarea',
            [(int)$in['id'], $in['descripcion'] ?? '', $in['prioridad'] ?? 'media',
             $nul('notas'), $nul('fecha_limite')],
            ['::int', '::text', '::varchar', '::text', '::date']); break;
    case 'nota':
        $r = db_call('fun_guardar_nota', [(int)$in['id'], $in['nota'] ?? ''], ['::int', '::text']); break;
    case 'eliminar':
        $r = db_call('fun_eliminar_tarea', [(int)$in['id'], $nul('motivo')], ['::int', '::text']); break;
    case 'restaurar':
        $r = db_call('fun_restaurar_tarea', [(int)$in['id']], ['::int']); break;
    case 'historial':
        $r = db_call('fun_historial_tarea', [(int)$in['id']], ['::int']); break;

    // ---- Archivo ----
    case 'buscar_archivo':
        $r = db_call('fun_buscar_archivo',
            [$nul('termino'), $nul('desde'), $nul('hasta')],
            ['::text', '::date', '::date']); break;

    // ---- Tipos de tarea ----
    case 'listar_tipos':
        $r = db_call('fun_listar_task_types'); break;
    case 'crear_tipo':
        $r = db_call('fun_insert_task_type',
            [$in['nombre'] ?? '', $in['color'] ?? '#7C3AED', $in['icono'] ?? 'ti-tag'],
            ['::varchar', '::varchar', '::varchar']); break;
    case 'editar_tipo':
        $r = db_call('fun_update_task_type',
            [(int)$in['id'], $in['nombre'] ?? '', $in['color'] ?? '#7C3AED', $in['icono'] ?? 'ti-tag'],
            ['::int', '::varchar', '::varchar', '::varchar']); break;
    case 'toggle_tipo':
        $r = db_call('fun_toggle_task_type', [(int)$in['id']], ['::int']); break;

    // ---- Plantillas (tareas fijas) ----
    case 'listar_templates':
        $r = db_call('fun_listar_templates'); break;
    case 'crear_template':
        $r = db_call('fun_insert_template',
            [$in['nombre'] ?? '', $nul('descripcion'), $int($nul('tipo_id')), (int)($in['orden'] ?? 0)],
            ['::varchar', '::text', '::int', '::smallint']); break;
    case 'editar_template':
        $r = db_call('fun_update_template',
            [(int)$in['id'], $in['nombre'] ?? '', $nul('descripcion'), $int($nul('tipo_id')), (int)($in['orden'] ?? 0)],
            ['::int', '::varchar', '::text', '::int', '::smallint']); break;
    case 'toggle_template':
        $r = db_call('fun_toggle_template', [(int)$in['id']], ['::int']); break;

    default:
        $r = ['ok' => false, 'mensaje' => 'Acción desconocida.'];
}
echo json_encode($r, JSON_UNESCAPED_UNICODE);
