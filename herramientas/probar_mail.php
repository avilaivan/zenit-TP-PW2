<?php
/**
 * ZENIT · Prueba del envío de mails.
 *
 * Uso (desde la carpeta del proyecto, en la consola de XAMPP o PhpStorm):
 *     C:\xampp\php\php.exe herramientas\probar_mail.php tucorreo@gmail.com
 *
 * Usa la misma configuración que la web (config/config.ini) y manda
 * un mail de prueba con el logo. Si falla, muestra el motivo exacto.
 */
if (PHP_SAPI !== 'cli') {
    exit('Este script se corre desde la consola.');
}

chdir(dirname(__DIR__));
require_once 'helper/Autoloader.php';

$destino = $argv[1] ?? '';
if (!filter_var($destino, FILTER_VALIDATE_EMAIL)) {
    exit("Uso: php herramientas/probar_mail.php tucorreo@gmail.com\n");
}

$config = parse_ini_file('config/config.ini');
if (($config['mail_modo'] ?? '') !== 'smtp') {
    exit("mail_modo no es \"smtp\" en config/config.ini\n");
}
if (!extension_loaded('openssl')) {
    exit("Falta la extensión openssl de PHP (activala en php.ini: extension=openssl)\n");
}

$mailer = new SmtpMailer(
    $config['smtp_host'],
    (int) $config['smtp_puerto'],
    $config['smtp_usuario'],
    $config['smtp_clave'],
    $config['mail_remitente'],
    $config['mail_nombre'] ?? 'ZENIT',
    $config['smtp_seguridad'] ?? 'tls',
    (bool) ($config['smtp_verificar_ssl'] ?? true)
);

$correo = new app\service\CorreoService($mailer, new app\service\MediaService());
echo "Enviando a $destino ...\n";

if ($correo->codigo(['nombre_usuario' => 'prueba', 'email' => $destino], '123456', 'registro', 15)) {
    echo "✔ Enviado. Revisá la bandeja de entrada (y spam).\n";
} else {
    echo "✘ No se pudo enviar: {$mailer->ultimoError}\n";
    if (str_contains($mailer->ultimoError, 'TLS')) {
        echo "  → Ver README, sección Mails (certificados en XAMPP).\n";
    }
    if (str_contains($mailer->ultimoError, '535')) {
        echo "  → Usuario o contraseña de aplicación incorrectos.\n";
    }
}
