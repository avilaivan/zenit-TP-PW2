<?php
/**
 * ZENIT · Reinicia la base de datos desde app/sql/zenit.sql.
 *
 * Uso (desde la carpeta del proyecto, en la consola de XAMPP o PhpStorm):
 *     C:\xampp\php\php.exe herramientas\reiniciar_base.php
 *
 * ¡OJO! Borra TODAS las tablas (cuentas, partidas, reportes) y las vuelve a
 * crear con la estructura nueva, las preguntas y el usuario demo / zenit1234.
 * Es lo mismo que importar zenit.sql desde phpMyAdmin.
 */
if (PHP_SAPI !== 'cli') {
    exit('Este script se corre desde la consola.');
}

chdir(dirname(__DIR__));
$config = parse_ini_file('config/config.ini');

echo "Esto borra todas las cuentas y partidas de la base \"{$config['db_name']}\". ¿Seguir? (s/n): ";
if (strtolower(trim((string) fgets(STDIN))) !== 's') {
    exit("Cancelado.\n");
}

try {
    $pdo = new PDO("mysql:host={$config['db_host']};charset=utf8mb4", $config['db_user'], $config['db_pass'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    ]);
    // Crea la base si no existe (en XAMPP) y la selecciona antes de importar
    $base = str_replace('`', '', $config['db_name']);
    $pdo->exec("CREATE DATABASE IF NOT EXISTS `$base` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
    $pdo->exec("USE `$base`");
    $pdo->exec(file_get_contents('app/sql/zenit.sql'));
    echo "Listo: base reiniciada. Entrá con demo / zenit1234 o creá una cuenta nueva.\n";
} catch (PDOException $e) {
    echo "No se pudo reiniciar la base: " . $e->getMessage() . "\n";
    echo "¿Está prendido MySQL en el panel de XAMPP?\n";
}
