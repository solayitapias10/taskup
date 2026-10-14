<?php
// Todas las tareas — vista de hoy con filtros por estado/tipo, orden y búsqueda
$hoy = date('Y-m-d');
$ab = db_call('fun_abrir_bitacora', [$hoy], ['::date']);
if (!$ab['ok']) { echo '<div class="alert">Error: ' . e($ab['mensaje'] ?? '') . '</div>'; return; }
$logId = $ab['data']['log_id'];

$dia   = db_call('fun_listar_tareas_dia', [$hoy], ['::date'])['data'] ?? ['fijas' => [], 'adhoc' => []];
$tipos = array_values(array_filter(db_call('fun_listar_task_types')['data'] ?? [], fn($t) => $t['activo'] && $t['visible']));

$fijo   = $_GET['fijo'] ?? 'todos';                 // fijos | adhoc | todos
$estado = $_GET['estado'] ?? 'todos';               // pendiente | en_gestion | resuelto | todos
$tipo   = (int)($_GET['tipo'] ?? 0);
$q      = trim($_GET['q'] ?? '');
$orden  = $_GET['orden'] ?? 'creacion';             // creacion | prioridad | estado

$lbl    = ['pendiente' => 'Pendiente', 'en_gestion' => 'En gestión', 'resuelto' => 'Resuelto'];
$prioOr = ['alta' => 0, 'media' => 1, 'baja' => 2];
$estOr  = ['pendiente' => 0, 'en_gestion' => 1, 'resuelto' => 2];

$tareas = [];
foreach ($dia['fijas'] as $t)  { $t['_adhoc'] = false; $tareas[] = $t; }
foreach ($dia['adhoc'] as $t)  { $t['_adhoc'] = true;  $tareas[] = $t; }

$tareas = array_values(array_filter($tareas, function ($t) use ($fijo, $estado, $tipo, $q) {
    if ($fijo === 'fijos'  &&  $t['_adhoc']) return false;
    if ($fijo === 'adhoc'  && !$t['_adhoc']) return false;
    if ($estado !== 'todos' && $t['estado'] !== $estado) return false;
    if ($tipo && (int)$t['tipo_id'] !== $tipo) return false;
    if ($q !== '' && stripos($t['descripcion'] . ' ' . ($t['numero_guia'] ?? ''), $q) === false) return false;
    return true;
}));

usort($tareas, function ($a, $b) use ($orden, $prioOr, $estOr) {
    return match ($orden) {
        'prioridad' => ($prioOr[$a['prioridad']] ?? 1) <=> ($prioOr[$b['prioridad']] ?? 1),
        'estado'    => ($estOr[$a['estado']] ?? 0) <=> ($estOr[$b['estado']] ?? 0),
        default     => $a['id'] <=> $b['id'],
    };
});

$nPend = count(array_filter($tareas, fn($t) => $t['estado'] === 'pendiente'));
$nGest = count(array_filter($tareas, fn($t) => $t['estado'] === 'en_gestion'));
$nRes  = count(array_filter($tareas, fn($t) => $t['estado'] === 'resuelto'));
?>

<div class="top-bar">
  <div>
    <div class="top-title">Todas las tareas</div>
    <div class="top-date">Tareas de hoy, <?= e(date('d/m/Y')) ?> · <?= count($tareas) ?> visibles</div>
  </div>
  <button class="btn-new" id="btnNueva"><i class="ti ti-plus"></i> Nueva tarea</button>
</div>

<div class="stats">
  <div class="stat"><div class="stat-label">Visibles</div><div class="stat-num purple"><?= count($tareas) ?></div></div>
  <div class="stat"><div class="stat-label">Pendientes</div><div class="stat-num orange"><?= $nPend ?></div></div>
  <div class="stat"><div class="stat-label">En gestión</div><div class="stat-num blue"><?= $nGest ?></div></div>
  <div class="stat"><div class="stat-label">Resueltas</div><div class="stat-num green"><?= $nRes ?></div></div>
</div>

<form class="filters" method="get">
  <input type="hidden" name="p" value="tasks">
  <div class="field"><span>Fuentes</span>
    <select name="fijo" data-autoform>
      <option value="todos" <?= $fijo === 'todos' ? 'selected' : '' ?>>Todas</option>
      <option value="fijos" <?= $fijo === 'fijos' ? 'selected' : '' ?>>Solo fijas</option>
      <option value="adhoc" <?= $fijo === 'adhoc' ? 'selected' : '' ?>>Solo ad-hoc</option>
    </select>
  </div>
  <div class="field"><span>Estado</span>
    <select name="estado" data-autoform>
      <option value="todos" <?= $estado === 'todos' ? 'selected' : '' ?>>Todos</option>
      <?php foreach ($lbl as $k => $v): ?><option value="<?= $k ?>" <?= $estado === $k ? 'selected' : '' ?>><?= $v ?></option><?php endforeach; ?>
    </select>
  </div>
  <div class="field"><span>Tipo</span>
    <select name="tipo" data-autoform>
      <option value="0">Todos</option>
      <?php foreach ($tipos as $tp): ?><option value="<?= $tp['id'] ?>" <?= $tipo === (int)$tp['id'] ? 'selected' : '' ?>><?= e($tp['nombre']) ?></option><?php endforeach; ?>
    </select>
  </div>
  <div class="field"><span>Ordenar por</span>
    <select name="orden" data-autoform>
      <option value="creacion" <?= $orden === 'creacion' ? 'selected' : '' ?>>Creación</option>
      <option value="prioridad" <?= $orden === 'prioridad' ? 'selected' : '' ?>>Prioridad</option>
      <option value="estado" <?= $orden === 'estado' ? 'selected' : '' ?>>Estado</option>
    </select>
  </div>
  <div class="field grow"><span>Buscar</span>
    <input type="search" name="q" value="<?= e($q) ?>" placeholder="Descripción o número de guía...">
  </div>
  <div class="field"><span>&nbsp;</span><button class="btn-new" type="submit"><i class="ti ti-filter"></i> Filtrar</button></div>
</form>

<div class="tasks-block">
  <?php if (!$tareas): ?>
    <div class="empty">No hay tareas que coincidan con los filtros.</div>
  <?php endif; ?>
  <?php foreach ($tareas as $t): ?>
    <div class="task-row" data-id="<?= $t['id'] ?>" data-adhoc="<?= $t['_adhoc'] ? 1 : 0 ?>" data-desc="<?= e($t['descripcion']) ?>" data-nota="<?= e($t['notas'] ?? '') ?>" data-prio="<?= e($t['prioridad']) ?>" data-lim="<?= e($t['fecha_limite'] ?? '') ?>" data-tipo="<?= e($t['tipo_id'] ?? '') ?>" data-guia="<?= e($t['numero_guia'] ?? '') ?>">
      <div class="cb <?= $t['completado'] ? 'done' : '' ?>" data-act="toggle" role="checkbox" aria-checked="<?= $t['completado'] ? 'true' : 'false' ?>"></div>
      <div class="type-dot" style="background:<?= e($t['tipo_color'] ?? '#999') ?>" title="<?= e($t['tipo_nombre'] ?? '') ?>"></div>
      <?php if (!empty($t['numero_guia'])): ?><div class="task-guide"><?= e($t['numero_guia']) ?></div><?php endif; ?>
      <div class="task-desc <?= $t['completado'] ? 'done-text' : '' ?>" data-act="detalle">
        <?= e($t['descripcion']) ?>
        <?php if (!empty($t['notas'])): ?><i class="ti ti-note note-ico" title="Tiene nota"></i><?php endif; ?>
      </div>
      <span class="prio <?= e($t['prioridad']) ?>"><?= e(ucfirst($t['prioridad'])) ?></span>
      <?php if (!empty($t['fecha_limite'])): ?><span class="due"><i class="ti ti-calendar"></i> <?= e($t['fecha_limite']) ?></span><?php endif; ?>
      <span class="tag-src"><?= $t['_adhoc'] ? 'Ad-hoc' : 'Fija' ?></span>
      <div class="chip <?= e($t['estado']) ?>"><?= e($lbl[$t['estado']] ?? $t['estado']) ?></div>
      <div class="menu-wrap">
        <div class="task-menu" data-act="menu">⋯</div>
        <div class="menu">
          <button data-act="estado" data-estado="pendiente">Pendiente</button>
          <button data-act="estado" data-estado="en_gestion">En gestión</button>
          <button data-act="estado" data-estado="resuelto">Resuelto</button>
          <button data-act="detalle">Nota / historial</button>
          <?php if ($t['_adhoc']): ?><button data-act="editar">Editar</button><?php endif; ?>
          <button data-act="eliminar" class="danger">Eliminar</button>
        </div>
      </div>
    </div>
  <?php endforeach; ?>
</div>

<!-- Modal nueva tarea -->
<div class="modal-bg" id="mNueva" hidden>
  <div class="modal">
    <h3>Nueva tarea</h3>
    <label>Número de guía (opcional)<input id="nGuia" placeholder="ENV-0000000" autocomplete="off"></label>
    <label>Tipo
      <select id="nTipo">
        <?php foreach ($tipos as $tp): ?><option value="<?= $tp['id'] ?>"><?= e($tp['nombre']) ?></option><?php endforeach; ?>
      </select>
    </label>
    <label>Descripción<textarea id="nDesc" rows="3" placeholder="¿Qué hay que hacer o recordar?"></textarea></label>
    <div class="row2">
      <label>Prioridad
        <select id="nPrio"><option value="baja">Baja</option><option value="media" selected>Media</option><option value="alta">Alta</option></select>
      </label>
      <label>Fecha límite<input type="date" id="nLim"></label>
    </div>
    <div class="modal-actions">
      <button class="btn-ghost" data-close>Cancelar</button>
      <button class="btn-new" id="nGuardar">Guardar</button>
    </div>
  </div>
</div>

<!-- Modal detalle -->
<div class="modal-bg" id="mDetalle" hidden>
  <div class="modal">
    <h3 id="dTitulo">Detalle</h3>
    <div id="dEditWrap">
      <label>Editar descripción<textarea id="dDescEdit" rows="2"></textarea></label>
      <div class="row2" style="margin-bottom:12px">
        <label>Tipo
          <select id="dTipoEdit">
            <?php foreach ($tipos as $tp): ?><option value="<?= $tp['id'] ?>"><?= e($tp['nombre']) ?></option><?php endforeach; ?>
          </select>
        </label>
        <label>Número de guía<input id="dGuiaEdit" placeholder="ENV-0000000" autocomplete="off"></label>
      </div>
      <div class="row2" style="margin-bottom:12px">
        <label>Prioridad
          <select id="dPrioEdit"><option value="baja">Baja</option><option value="media">Media</option><option value="alta">Alta</option></select>
        </label>
        <label>Fecha límite<input type="date" id="dLimEdit"></label>
      </div>
      <div class="modal-actions" style="margin:0 0 14px">
        <button class="btn-new" id="dEditar"><i class="ti ti-pencil"></i> Guardar cambios</button>
      </div>
    </div>
    <label>Nota<textarea id="dNota" rows="3" placeholder="Observaciones / seguimiento"></textarea></label>
    <div class="modal-actions" style="margin:0 0 12px">
      <button class="btn-new" id="dGuardar">Guardar nota</button>
    </div>
    <div class="section-title">Historial</div>
    <div id="dHist" class="hist"></div>
    <div class="modal-actions"><button class="btn-ghost" data-close>Cerrar</button></div>
  </div>
</div>

<script>window.TASKUP = { logId: <?= (int)$logId ?> };</script>
<script src="assets/config.js"></script>
