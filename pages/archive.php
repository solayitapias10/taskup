<?php
// Archivo — tareas resueltas de días anteriores (búsqueda por guía, término o rango de fechas)
$termino = trim($_GET['q'] ?? '');
$desde   = trim($_GET['desde'] ?? '');
$hasta   = trim($_GET['hasta'] ?? '');

$res = db_call('fun_buscar_archivo',
    [$termino !== '' ? $termino : null,
     $desde  !== '' ? $desde  : null,
     $hasta  !== '' ? $hasta  : null],
    ['::text', '::date', '::date']);

$resultados = $res['ok'] ? ($res['data'] ?? []) : [];
if (!$res['ok']) { $error = $res['mensaje'] ?? 'Error al consultar el archivo.'; }

$hayBusqueda = $termino !== '' || $desde !== '' || $hasta !== '';

// Etiqueta visible del tipo (misma que dashboard)
if (!function_exists('tipo_badge')) {
  function tipo_badge(?string $nombre, ?string $color): string {
    if ($nombre === null || $nombre === '') return '';
    $corto = mb_strtolower(trim(explode('/', $nombre)[0]));
    $mapa = [
      'guía pendiente de entrega' => 'Guía pendiente',
      'guía sin planillar'        => 'Sin planillar',
      'queja / reclamación'       => 'Queja',
      'consulta de cliente'       => 'Consulta',
      'seguimiento de novedad'    => 'Novedad',
      'faltante'                  => 'Faltante',
      'recuperación de cartaporte'=> 'Cartaporte',
    ];
    $txt = $mapa[$corto] ?? mb_substr($nombre, 0, 22);
    // Color normalizado (por si la BD lo guarda con espacios o formato CHAR(7))
    $hex = preg_match('/^#?([0-9a-fA-F]{6})$/', trim((string)$color), $m) ? '#' . $m[1] : '#7C3AED';
    return '<span class="tag-tipo" style="--tc:' . $hex . '"><span class="dot"></span>' . e($txt) . '</span>';
  }
}
?>

<div class="top-bar">
  <div>
    <div class="top-title">Archivo</div>
    <div class="top-date">Historial de tareas resueltas · <?= count($resultados) ?> resultado<?= count($resultados) === 1 ? '' : 's' ?></div>
  </div>
</div>

<?php if (!empty($error)): ?>
  <div class="alert"><?= e($error) ?></div>
<?php endif; ?>

<form class="filters" method="get">
  <input type="hidden" name="p" value="archive">
  <div class="field grow"><span>Buscar</span>
    <input type="search" name="q" value="<?= e($termino) ?>" placeholder="Descripción o número de guía...">
  </div>
  <div class="field"><span>Desde</span>
    <input type="date" name="desde" value="<?= e($desde) ?>">
  </div>
  <div class="field"><span>Hasta</span>
    <input type="date" name="hasta" value="<?= e($hasta) ?>">
  </div>
  <div class="field"><span>&nbsp;</span><button class="btn-new" type="submit"><i class="ti ti-search"></i> Buscar</button></div>
  <?php if ($hayBusqueda): ?>
    <div class="field"><span>&nbsp;</span><a class="btn-ghost" href="index.php?p=archive"><i class="ti ti-x"></i> Limpiar</a></div>
  <?php endif; ?>
</form>

<div class="tasks-block">
  <?php if (!$hayBusqueda): ?>
    <div class="empty">Escribe un término (guía o descripción) o un rango de fechas para buscar en el archivo.</div>
  <?php elseif (!$resultados): ?>
    <div class="empty">No se encontraron tareas resueltas que coincidan.</div>
  <?php endif; ?>

  <?php foreach ($resultados as $t): ?>
    <div class="task-row archived">
      <div class="cb done" title="Resuelta"></div>
      <?= tipo_badge($t['tipo_nombre'] ?? null, $t['tipo_color'] ?? null) ?>
      <?php if (!empty($t['numero_guia'])): ?><div class="task-guide"><?= e($t['numero_guia']) ?></div><?php endif; ?>
      <div class="task-desc"><?= e($t['descripcion']) ?>
        <?php if (!empty($t['notas'])): ?><i class="ti ti-note note-ico" title="<?= e($t['notas']) ?>"></i><?php endif; ?>
      </div>
      <span class="tag-src"><?= e($t['fecha']) ?></span>
      <?php if (!empty($t['hora_completado'])): ?><span class="due"><i class="ti ti-clock"></i> <?= e($t['hora_completado']) ?></span><?php endif; ?>
      <div class="chip resuelto">Resuelto</div>
    </div>
  <?php endforeach; ?>
</div>
