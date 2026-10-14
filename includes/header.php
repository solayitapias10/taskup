<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>TaskUp</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@3.42.0/dist/tabler-icons.min.css">
<link rel="stylesheet" href="assets/style.css">
</head>
<body>
<aside class="sidebar">
  <div class="logo">Task<span>Up</span></div>
  <a class="nav-item <?= $p === 'dashboard' ? 'active' : '' ?>" href="index.php?p=dashboard"><i class="ti ti-layout-dashboard"></i> Bitácora del día</a>
  <a class="nav-item disabled"><i class="ti ti-checklist"></i> Todas las tareas</a>
  <a class="nav-item disabled"><i class="ti ti-archive"></i> Archivo</a>
  <div class="nav-section">Configuración</div>
  <a class="nav-item disabled"><i class="ti ti-repeat"></i> Tareas fijas</a>
  <a class="nav-item disabled"><i class="ti ti-tags"></i> Tipos</a>
  <div style="flex:1"></div>
  <div class="nav-item"><i class="ti ti-user-circle"></i> Solayi</div>
</aside>
<main class="main">
