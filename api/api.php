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

switch ($act) {
    case 'toggle':
        $r = db_call('fun_completar_tarea', [(int)$in['id']], ['::int']); break;
    case 'estado':
        $r = db_call('fun_actualizar_estado_tarea', [(int)$in['id'], $in['estado'] ?? ''], ['::int', '::varchar']); break;
    case 'crear':
        $r = db_call('fun_insert_tarea_adhoc',
            [(int)$in['log_id'], (int)$in['tipo_id'], $in['descripcion'] ?? '', $nul('numero_guia'),
             $in['prioridad'] ?? 'media', $nul('fecha_limite')],
            ['::int', '::int', '::text', '::varchar', '::varchar', '::date']); break;
    case 'nota':
        $r = db_call('fun_guardar_nota', [(int)$in['id'], $in['nota'] ?? ''], ['::int', '::text']); break;
    case 'eliminar':
        $r = db_call('fun_eliminar_tarea', [(int)$in['id']], ['::int']); break;
    case 'historial':
        $r = db_call('fun_historial_tarea', [(int)$in['id']], ['::int']); break;
    default:
        $r = ['ok' => false, 'mensaje' => 'Acción desconocida.'];
}
echo json_encode($r, JSON_UNESCAPED_UNICODE);
