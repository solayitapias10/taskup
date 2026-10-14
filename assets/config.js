// TaskUp — CRUD de configuración (tipos y plantillas) + filtros auto-submit
const $cfg = (s, r = document) => r.querySelector(s);

async function apiCfg(action, data = {}) {
  try {
    const res = await fetch('api/api.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action, ...data })
    });
    return await res.json();
  } catch (e) {
    return { ok: false, mensaje: 'Error de conexión.' };
  }
}

function toastCfg(msg) {
  const t = $cfg('#toast');
  if (!t) return;
  t.textContent = msg; t.classList.add('show');
  setTimeout(() => t.classList.remove('show'), 2200);
}

document.addEventListener('click', async (ev) => {
  // cerrar menús abiertos al hacer click fuera
  if (!ev.target.closest('.menu-wrap')) document.querySelectorAll('.menu.open').forEach(m => m.classList.remove('open'));

  if (ev.target.matches('[data-close]') || ev.target.classList.contains('modal-bg')) {
    document.querySelectorAll('.modal-bg').forEach(m => m.hidden = true);
    return;
  }

  // ---------- TIPOS ----------
  if (ev.target.closest('#btnNuevoTipo')) {
    $cfg('#tId').value = '';
    $cfg('#tTitulo').textContent = 'Nuevo tipo';
    $cfg('#tNombre').value = ''; $cfg('#tColor').value = '#7C3AED'; $cfg('#tIcono').value = 'ti-tag';
    $cfg('#mTipo').hidden = false; $cfg('#tNombre').focus();
    return;
  }

  const elT = ev.target.closest('[data-act="editar_tipo"], [data-act="toggle_tipo"], [data-act="eliminar_tipo"], [data-act="restaurar_tipo"]');
  if (elT) {
    const row = elT.closest('.cfg-row');
    const id  = Number(row.dataset.id);
    if (elT.dataset.act === 'eliminar_tipo') {
      if (!confirm('¿Eliminar este tipo? (soft delete: las tareas que lo usan lo conservan; podrás restaurarlo)')) return;
      const r = await apiCfg('eliminar_tipo', { id });
      toastCfg(r.ok ? (r.mensaje || 'Eliminado.') : (r.mensaje || 'Error.'));
      if (r.ok) location.reload();
      return;
    }
    if (elT.dataset.act === 'restaurar_tipo') {
      const r = await apiCfg('toggle_tipo', { id });
      toastCfg(r.ok ? (r.mensaje || 'Restaurado.') : (r.mensaje || 'Error.'));
      if (r.ok) location.reload();
      return;
    }
    if (elT.dataset.act === 'toggle_tipo') {
      const r = await apiCfg('toggle_tipo', { id });
      toastCfg(r.ok ? (r.mensaje || 'Listo.') : (r.mensaje || 'Error.'));
      if (r.ok) location.reload();
    } else {
      $cfg('#tId').value = id;
      $cfg('#tTitulo').textContent = 'Editar tipo';
      $cfg('#tNombre').value = row.dataset.nombre;
      $cfg('#tColor').value = row.dataset.color.trim();
      $cfg('#tIcono').value = row.dataset.icono;
      $cfg('#mTipo').hidden = false;
    }
    return;
  }

  if (ev.target.closest('#tGuardar')) {
    const nombre = $cfg('#tNombre').value.trim();
    if (!nombre) return toastCfg('El nombre es requerido.');
    const id = $cfg('#tId').value;
    const payload = { id: id || undefined, nombre, color: $cfg('#tColor').value, icono: $cfg('#tIcono').value };
    const r = await apiCfg(id ? 'editar_tipo' : 'crear_tipo', payload);
    toastCfg(r.ok ? (r.mensaje || 'Guardado.') : (r.mensaje || 'Error.'));
    if (r.ok) location.reload();
    return;
  }

  // ---------- PLANTILLAS ----------
  if (ev.target.closest('#btnNuevoTpl')) {
    $cfg('#pId').value = '';
    $cfg('#pTitulo').textContent = 'Nueva plantilla';
    $cfg('#pNombre').value = ''; $cfg('#pDesc').value = ''; $cfg('#pTipo').value = ''; $cfg('#pOrden').value = '0';
    $cfg('#mTpl').hidden = false; $cfg('#pNombre').focus();
    return;
  }

  const elP = ev.target.closest('[data-act="editar_tpl"], [data-act="toggle_tpl"], [data-act="eliminar_tpl"], [data-act="restaurar_tpl"]');
  if (elP) {
    const row = elP.closest('.cfg-row');
    const id  = Number(row.dataset.id);
    if (elP.dataset.act === 'eliminar_tpl') {
      const limpiar = confirm('¿Eliminar esta plantilla fija?\n\nAceptar = ocultarla también de la bitácora de HOY.\nCancelar = solo eliminarla (las tareas ya generadas se conservan).');
      const r = await apiCfg('eliminar_template', { id, eliminar_tareas: limpiar });
      toastCfg(r.ok ? (r.mensaje || 'Eliminada.') : (r.mensaje || 'Error.'));
      if (r.ok) location.reload();
      return;
    }
    if (elP.dataset.act === 'restaurar_tpl') {
      const r = await apiCfg('restaurar_template', { id });
      toastCfg(r.ok ? (r.mensaje || 'Restaurada.') : (r.mensaje || 'Error.'));
      if (r.ok) location.reload();
      return;
    }
    if (elP.dataset.act === 'toggle_tpl') {
      const r = await apiCfg('toggle_template', { id });
      toastCfg(r.ok ? (r.mensaje || 'Listo.') : (r.mensaje || 'Error.'));
      if (r.ok) location.reload();
    } else {
      $cfg('#pId').value = id;
      $cfg('#pTitulo').textContent = 'Editar plantilla';
      $cfg('#pNombre').value = row.dataset.nombre;
      $cfg('#pDesc').value = row.dataset.descripcion || '';
      $cfg('#pTipo').value = row.dataset.tipo || '';
      $cfg('#pOrden').value = row.dataset.orden || '0';
      $cfg('#mTpl').hidden = false;
    }
    return;
  }

  if (ev.target.closest('#pGuardar')) {
    const nombre = $cfg('#pNombre').value.trim();
    if (!nombre) return toastCfg('El nombre es requerido.');
    const id = $cfg('#pId').value;
    const payload = {
      id: id || undefined, nombre,
      descripcion: $cfg('#pDesc').value.trim(),
      tipo_id: $cfg('#pTipo').value,
      orden: Number($cfg('#pOrden').value) || 0
    };
    const r = await apiCfg(id ? 'editar_template' : 'crear_template', payload);
    toastCfg(r.ok ? (r.mensaje || 'Guardado.') : (r.mensaje || 'Error.'));
    if (r.ok) location.reload();
    return;
  }
});

// ---------- Filtros con auto-aplicar (selects con data-autoform) ----------
document.querySelectorAll('select[data-autoform]').forEach(sel => {
  sel.addEventListener('change', () => sel.form?.submit());
});

document.addEventListener('keydown', e => {
  if (e.key === 'Escape') document.querySelectorAll('.modal-bg').forEach(m => m.hidden = true);
});
