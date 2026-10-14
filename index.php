<?php
require_once __DIR__ . '/config/db.php';
$pages = ['dashboard'];           // se irán sumando: tasks, archive, templates, types
$p = $_GET['p'] ?? 'dashboard';
if (!in_array($p, $pages, true)) { $p = 'dashboard'; }

function e($s): string { return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); }

require __DIR__ . '/includes/header.php';
require __DIR__ . "/pages/$p.php";
require __DIR__ . '/includes/footer.php';
