<?php
/**
 * ZENIT · Front controller.
 *
 * Todas las peticiones pasan por acá (ver .htaccess).
 * 1. Configura la sesión de forma segura.
 * 2. Arma el contenedor de dependencias (Configuration).
 * 3. Le pide al Router que ejecute controller/método.
 */

use app\Configuration;

session_set_cookie_params([
    'httponly' => true,   // JS no puede leer la cookie de sesión
    'samesite' => 'Lax',  // protege los POST contra CSRF básico
]);
session_start();

require_once __DIR__ . '/app/Configuration.php';

$configuration = new Configuration();
$router = $configuration->getRouter();

$router->dispatch(
    Request::get('controller', 'home'),
    Request::get('method', 'show')
);
