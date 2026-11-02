<?php
/**
 * Autoloader del proyecto (sin Composer).
 *
 * - Clases con namespace (app\controller\HomeController) → la ruta
 *   del namespace coincide con la carpeta: app/controller/HomeController.php
 * - Clases globales (Router, Request, Url...) → viven en helper/.
 */
spl_autoload_register(function (string $clase): void {
    $ruta = str_replace('\\', '/', $clase) . '.php';

    $conNamespace = __DIR__ . '/../' . $ruta;
    if (file_exists($conNamespace)) {
        require_once $conNamespace;
        return;
    }

    $helper = __DIR__ . '/' . $ruta;
    if (file_exists($helper)) {
        require_once $helper;
    }
});
