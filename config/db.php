<?php
// TaskUp — conexión PDO + helper para llamar funciones PL/pgSQL (patrón {ok, mensaje, data})
date_default_timezone_set('America/Bogota');

const DB_HOST = 'localhost';
const DB_PORT = '5432';
const DB_NAME = 'TaskUp.db';
const DB_USER = 'postgres';
const DB_PASS = '0621';

function db(): PDO {
    static $pdo = null;
    if ($pdo === null) {
        $dsn = sprintf('pgsql:host=%s;port=%s;dbname=%s', DB_HOST, DB_PORT, DB_NAME);
        $pdo = new PDO($dsn, DB_USER, DB_PASS, [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_EMULATE_PREPARES   => false,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);
    }
    return $pdo;
}

/**
 * Llama una función almacenada y devuelve el JSONB decodificado.
 * $casts: casts por posición, ej. ['::int', '::date'] (los vacíos se omiten).
 */
function db_call(string $fn, array $args = [], array $casts = []): array {
    if (!preg_match('/^fun_[a-z_]+$/', $fn)) {
        return ['ok' => false, 'mensaje' => 'Función no permitida.'];
    }
    $ph = [];
    foreach (array_keys($args) as $i) { $ph[] = '?' . ($casts[$i] ?? ''); }
    try {
        $st = db()->prepare("SELECT $fn(" . implode(',', $ph) . ") AS r");
        $st->execute(array_values($args));
        return json_decode($st->fetchColumn(), true) ?? ['ok' => false, 'mensaje' => 'Respuesta vacía.'];
    } catch (Throwable $e) {
        return ['ok' => false, 'mensaje' => $e->getMessage()];
    }
}
