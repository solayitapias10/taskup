<?php
// Tareas fijas — plantillas que se generan automáticamente cada día en la bitácora
$todas      = db_call('fun_listar_templates_todas')['data'] ?? [];
$templates  = array_values(array_filter($todas, fn($t) => $t['visible']));
$eliminadas = array_values(array_filter($todas, fn($t) => !$t['visible']));
$tipos     = array_values(array_filter(db_call('fun_listar_task_types')['data'] ?? [], fn($t) => $t['activo'] && $t['visible']));
?>

<div class="top-bar">
  <div>
    <div class="top-title">Tareas fijas del día</div>
    <div class="top-date">Plantillas que se generan solas al abrir la bitácora · <?= count($templates) ?> plantillas</div>
  </div>
  <button class="btn-new" id="btnNuevoTpl"><i class="ti ti-plus"></i> Nueva plantilla</button>
</div>

<div class="tasks-block">
  <?php foreach ($templates as $tpl): ?>
    <div class="task-row cfg-row <?= $tpl['activo'] ? '' : 'inactive' ?>" data-id="<?= (int)$tpl['id'] ?>"
         data-nombre="<?= e($tpl['nombre']) ?>" data-descripcion="<?= e($tpl['descripcion'] ?? '') ?>"
         data-tipo="<?= (int)($tpl['tipo_id'] ?? 0) ?>" data-orden="<?= (int)$tpl['orden'] ?>">
      <span class="tpl-order">#<?= (int)$tpl['orden'] ?></span>
      <div class="type-dot" style="background:<?= e($tpl['tipo_color'] ?? '#999') ?>" title="<?= e($tpl['tipo_nombre'] ?? '') ?>"></div>
      <div class="task-desc"><?= e($tpl['nombre']) ?>
        <?php if (!empty($tpl['descripcion'])): ?><span class="tpl-desc">— <?= e($tpl['descripcion']) ?></span><?php endif; ?>
      </div>
      <span class="tag-src"><?= e($tpl['tipo_nombre'] ?? 'Sin tipo') ?></span>
      <div class="chip <?= $tpl['activo'] ? 'resuelto' : 'pendiente' ?>"><?= $tpl['activo'] ? 'Activa' : 'Inactiva' ?></div>
      <div class="menu-wrap">
        <div class="task-menu" data-act="menu">⋯</div>
        <div class="menu">
          <button data-act="editar_tpl">Editar</button>
          <button data-act="toggle_tpl"><?= $tpl['activo'] ? 'Desactivar' : 'Activar' ?></button>
          <button data-act="eliminar_tpl" class="danger">Eliminar</button>
        </div>
      </div>
    </div>
  <?php endforeach; ?>
  <?php if (!$templates): ?><div class="empty">No hay plantillas. Crea la primera con el botón “Nueva plantilla”.</div><?php endif; ?>
</div>

<?php if ($eliminadas): ?>
<div class="divider"></div>
<div class="tasks-block">
  <div class="section-title">Plantillas eliminadas <span class="badge"><?= count($eliminadas) ?></span></div>
  <?php foreach ($eliminadas as $tpl): ?>
    <div class="task-row cfg-row inactive" data-id="<?= (int)$tpl['id'] ?>">
      <div class="type-dot" style="background:<?= e($tpl['tipo_color'] ?? '#999') ?>"></div>
      <div class="task-desc"><?= e($tpl['nombre']) ?></div>
      <div class="chip pendiente">Eliminada</div>
      <button class="btn-ghost" data-act="restaurar_tpl">Restaurar</button>
    </div>
  <?php endforeach; ?>
</div>
<?php endif; ?>

<!-- Modal plantilla (crear/editar) -->
<div class="modal-bg" id="mTpl" hidden>
  <div class="modal">
    <h3 id="pTitulo">Nueva plantilla</h3>
    <input type="hidden" id="pId">
    <label>Nombre<input id="pNombre" placeholder="Ej: Revisar guías sin planillar" autocomplete="off"></label>
    <label>Descripción (opcional)<textarea id="pDesc" rows="2" placeholder="Qué incluye esta tarea fija..."></textarea></label>
    <div class="row2">
      <label>Tipo
        <select id="pTipo">
          <option value="">Sin tipo</option>
          <?php foreach ($tipos as $tp): ?><option value="<?= $tp['id'] ?>"><?= e($tp['nombre']) ?></option><?php endforeach; ?>
        </select>
      </label>
      <label>Orden <input type="number" id="pOrden" min="0" max="99" value="0"></label>
    </div>
    <div class="modal-actions">
      <button class="btn-ghost" data-close>Cancelar</button>
      <button class="btn-new" id="pGuardar">Guardar</button>
    </div>
  </div>
</div>

<script src="assets/config.js"></script>
