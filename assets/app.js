// TaskUp — interacción del dashboard
const $ = (s, r = document) => r.querySelector(s);

async function api(action, data = {}) {
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

function toast(msg) {
  const t = $('#toast');
  t.textContent = msg; t.classList.add('show');
  setTimeout(() => t.classList.remove('show'), 2200);
}

async function run(action, data, okMsg) {
  const r = await api(action, data);
  if (!r.ok) { toast(r.mensaje || 'Error.'); return r; }
  if (okMsg) toast(okMsg);
  return r;
}

const openModal  = id => { $(id).hidden = false; };
const closeModals = () => document.querySelectorAll('.modal-bg').forEach(m => m.hidden = true);

let currentTask = null;

// ---- Delegación de eventos sobre filas ----
document.addEventListener('click', async (ev) => {
  // cerrar menús abiertos
  if (!ev.target.closest('.menu-wrap')) document.querySelectorAll('.menu.open').forEach(m => m.classList.remove('open'));

  if (ev.target.matches('[data-close]') || ev.target.classList.contains('modal-bg')) return closeModals();

  const el  = ev.target.closest('[data-act]');
  if (!el) return;
  const row = el.closest('.task-row');
  const id  = row ? Number(row.dataset.id) : null;

  switch (el.dataset.act) {
    case 'toggle': {
      el.classList.toggle('done');
      const r = await run('toggle', { id });
      if (r.ok) location.reload(); else el.classList.toggle('done');
      break;
    }
    case 'menu':
      document.querySelectorAll('.menu.open').forEach(m => m.classList.remove('open'));
      el.nextElementSibling.classList.toggle('open');
      break;
    case 'estado': {
      const r = await run('estado', { id, estado: el.dataset.estado });
      if (r.ok) location.reload();
      break;
    }
    case 'eliminar': {
      if (!confirm('¿Eliminar esta tarea?')) break;
      const r = await run('eliminar', { id });
      if (r.ok) location.reload();
      break;
    }
    case 'detalle': {
      currentTask = id;
      $('#dTitulo').textContent = row.dataset.desc;
      $('#dNota').value = row.dataset.nota || '';
      $('#dHist').innerHTML = '';
      openModal('#mDetalle');
      const r = await api('historial', { id });
      if (r.ok) {
        $('#dHist').innerHTML = r.data.map(h =>
          `<div><span>${h.created_at}</span>${h.descripcion.replace(/</g, '&lt;')}</div>`).join('') || '<div>Sin historial.</div>';
      }
      break;
    }
  }
});

// ---- Nueva tarea ----
['#btnNueva', '#btnAdd'].forEach(s => $(s)?.addEventListener('click', () => {
  openModal('#mNueva'); $('#nGuia').focus();
}));

$('#nGuardar')?.addEventListener('click', async () => {
  const descripcion = $('#nDesc').value.trim();
  if (!descripcion) return toast('La descripción es requerida.');
  const r = await run('crear', {
    log_id: window.TASKUP.logId,
    tipo_id: $('#nTipo').value,
    numero_guia: $('#nGuia').value,
    descripcion,
    prioridad: $('#nPrio').value,
    fecha_limite: $('#nLim').value
  });
  if (r.ok) location.reload();
});

// ---- Guardar nota ----
$('#dGuardar')?.addEventListener('click', async () => {
  const nota = $('#dNota').value.trim();
  if (!nota) return toast('Escribe una nota.');
  const r = await run('nota', { id: currentTask, nota });
  if (r.ok) location.reload();
});

document.addEventListener('keydown', e => { if (e.key === 'Escape') closeModals(); });
