<?php
$hoy = date('Y-m-d');
$dias  = ['domingo','lunes','martes','miércoles','jueves','viernes','sábado'];
$meses = ['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
$fechaTxt = ucfirst($dias[date('w')]) . ', ' . date('j') . ' de ' . $meses[date('n') - 1] . ' de ' . date('Y');

// 1. Abrir bitácora (genera tareas fijas si es un día nuevo)
$ab = db_call('fun_abrir_bitacora', [$hoy], ['::date']);
if (!$ab['ok']) { echo '<div class="alert">Error: ' . e($ab['mensaje'] ?? '') . '</div>'; return; }
$logId = $ab['data']['log_id'];

// 2. Datos
$stats = db_call('fun_stats_dia', [$hoy], ['::date'])['data'] ?? ['total'=>0,'pendientes'=>0,'resueltas'=>0,'vencidas'=>0];
$dia   = db_call('fun_listar_tareas_dia', [$hoy], ['::date'])['data'] ?? ['fijas'=>[],'adhoc'=>[]];
$tipos = array_filter(db_call('fun_listar_task_types')['data'] ?? [], fn($t) => $t['activo']);

$estadoLbl = ['pendiente' => 'Pendiente', 'en_gestion' => 'En gestión', 'resuelto' => 'Resuelto'];

function render_task(array $t, array $lbl, bool $adhoc): void { ?>
  <div class="task-row" data-id="<?= $t['id'] ?>" data-adhoc="<?= $adhoc ? 1 : 0 ?>" data-desc="<?= e($t['descripcion']) ?>" data-nota="<?= e($t['notas'] ?? '') ?>" data-prio="<?= e($t['prioridad']) ?>" data-lim="<?= e($t['fecha_limite'] ?? '') ?>">
    <div class="cb <?= $t['completado'] ? 'done' : '' ?>" data-act="toggle" role="checkbox" aria-checked="<?= $t['completado'] ? 'true' : 'false' ?>"></div>
    <div class="type-dot" style="background:<?= e($t['tipo_color'] ?? '#999') ?>" title="<?= e($t['tipo_nombre'] ?? '') ?>"></div>
    <?php if ($adhoc && !empty($t['numero_guia'])): ?><div class="task-guide"><?= e($t['numero_guia']) ?></div><?php endif; ?>
    <div class="task-desc <?= $t['completado'] ? 'done-text' : '' ?>" data-act="detalle">
      <?= e($t['descripcion']) ?>
      <?php if (!empty($t['notas'])): ?><i class="ti ti-note note-ico" title="Tiene nota"></i><?php endif; ?>
    </div>
    <?php if (!empty($t['fecha_limite'])): ?><span class="due"><i class="ti ti-calendar"></i> <?= e($t['fecha_limite']) ?></span><?php endif; ?>
    <?php if ($t['completado'] && !empty($t['hora_completado'])): ?><span class="due"><?= e($t['hora_completado']) ?></span><?php endif; ?>
    <div class="chip <?= e($t['estado']) ?>"><?= e($lbl[$t['estado']] ?? $t['estado']) ?></div>
    <div class="menu-wrap">
      <div class="task-menu" data-act="menu">⋯</div>
      <div class="menu">
        <button data-act="estado" data-estado="pendiente">Pendiente</button>
        <button data-act="estado" data-estado="en_gestion">En gestión</button>
        <button data-act="estado" data-estado="resuelto">Resuelto</button>
        <button data-act="detalle">Nota / historial</button>
        <?php if ($adhoc): ?><button data-act="eliminar" class="danger">Eliminar</button><?php endif; ?>
      </div>
    </div>
  </div>
<?php } ?>

<div class="top-bar">
  <div>
    <div class="top-title">Bitácora del día</div>
    <div class="top-date"><?= e($fechaTxt) ?></div>
  </div>
  <button class="btn-new" id="btnNueva"><i class="ti ti-plus"></i> Nueva tarea</button>
</div>

<div class="stats">
  <div class="stat"><div class="stat-label">Total hoy</div><div class="stat-num purple"><?= (int)$stats['total'] ?></div></div>
  <div class="stat"><div class="stat-label">Pendientes</div><div class="stat-num orange"><?= (int)$stats['pendientes'] ?></div></div>
  <div class="stat"><div class="stat-label">Resueltas</div><div class="stat-num green"><?= (int)$stats['resueltas'] ?></div></div>
  <div class="stat"><div class="stat-label">Vencidas</div><div class="stat-num red"><?= (int)$stats['vencidas'] ?></div></div>
</div>

<div class="tasks-block">
  <div class="section-title">Tareas fijas del día <span class="badge"><?= count($dia['fijas']) ?></span></div>
  <?php foreach ($dia['fijas'] as $t) render_task($t, $estadoLbl, false); ?>
  <?php if (!$dia['fijas']): ?><div class="empty">No hay tareas fijas. Créalas en Configuración → Tareas fijas.</div><?php endif; ?>
</div>

<div class="divider"></div>

<div class="tasks-block">
  <div class="section-title">Tareas del día <span class="badge"><?= count($dia['adhoc']) ?></span></div>
  <?php foreach ($dia['adhoc'] as $t) render_task($t, $estadoLbl, true); ?>
  <div class="add-row" id="btnAdd"><i class="ti ti-plus"></i> Añadir tarea ad-hoc...</div>
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
