<?php
// Tipos de tarea — catálogo con color e icono (CRUD vía funciones almacenadas)
$todos  = db_call('fun_listar_task_types')['data'] ?? [];
$tipos    = array_values(array_filter($todos, fn($t) => $t['visible']));
$ocultos  = array_values(array_filter($todos, fn($t) => !$t['visible']));

$iconos = ['ti-tag', 'ti-package', 'ti-clipboard-list', 'ti-alert-circle', 'ti-message-circle',
           'ti-search', 'ti-package-off', 'ti-file-check', 'ti-truck', 'ti-phone', 'ti-mail', 'ti-bell'];
?>

<div class="top-bar">
  <div>
    <div class="top-title">Tipos de tarea</div>
    <div class="top-date">Categorías con color e ícono para clasificar tus tareas · <?= count($tipos) ?> tipos</div>
  </div>
  <button class="btn-new" id="btnNuevoTipo"><i class="ti ti-plus"></i> Nuevo tipo</button>
</div>

<div class="tasks-block">
  <?php foreach ($tipos as $tp): ?>
    <div class="task-row cfg-row <?= $tp['activo'] ? '' : 'inactive' ?>" data-id="<?= (int)$tp['id'] ?>"
         data-nombre="<?= e($tp['nombre']) ?>" data-color="<?= e($tp['color']) ?>" data-icono="<?= e($tp['icono']) ?>">
      <div class="type-dot big" style="background:<?= e($tp['color']) ?>"></div>
      <i class="ti <?= e($tp['icono']) ?> cfg-ico" style="color:<?= e($tp['color']) ?>"></i>
      <div class="task-desc"><?= e($tp['nombre']) ?></div>
      <span class="tag-src"><?= e(trim($tp['color'])) ?></span>
      <div class="chip <?= $tp['activo'] ? 'resuelto' : 'pendiente' ?>"><?= $tp['activo'] ? 'Activo' : 'Inactivo' ?></div>
      <div class="menu-wrap">
        <div class="task-menu" data-act="menu">⋯</div>
        <div class="menu">
          <button data-act="editar_tipo">Editar</button>
          <button data-act="toggle_tipo"><?= $tp['activo'] ? 'Desactivar' : 'Activar' ?></button>
          <button data-act="eliminar_tipo" class="danger">Eliminar</button>
        </div>
      </div>
    </div>
  <?php endforeach; ?>
  <?php if (!$tipos): ?><div class="empty">No hay tipos creados todavía.</div><?php endif; ?>
</div>

<?php if ($ocultos): ?>
<div class="divider"></div>
<div class="tasks-block">
  <div class="section-title">Tipos eliminados <span class="badge"><?= count($ocultos) ?></span></div>
  <?php foreach ($ocultos as $tp): ?>
    <div class="task-row cfg-row inactive" data-id="<?= (int)$tp['id'] ?>">
      <div class="type-dot big" style="background:<?= e($tp['color']) ?>"></div>
      <div class="task-desc"><?= e($tp['nombre']) ?></div>
      <div class="chip pendiente">Eliminado</div>
      <button class="btn-ghost" data-act="restaurar_tipo">Restaurar</button>
    </div>
  <?php endforeach; ?>
</div>
<?php endif; ?>

<!-- Modal tipo (crear/editar) -->
<div class="modal-bg" id="mTipo" hidden>
  <div class="modal">
    <h3 id="tTitulo">Nuevo tipo</h3>
    <input type="hidden" id="tId">
    <label>Nombre<input id="tNombre" placeholder="Ej: Guía pendiente de entrega" autocomplete="off"></label>
    <div class="row2">
      <label>Color<input type="color" id="tColor" value="#7C3AED"></label>
      <label>Ícono
        <select id="tIcono">
          <?php foreach ($iconos as $ic): ?>
            <option value="<?= $ic ?>"><?= str_replace('ti-', '', $ic) ?></option>
          <?php endforeach; ?>
        </select>
      </label>
    </div>
    <div class="modal-actions">
      <button class="btn-ghost" data-close>Cancelar</button>
      <button class="btn-new" id="tGuardar">Guardar</button>
    </div>
  </div>
</div>

<script src="assets/config.js"></script>
