<?php
/**
 * Arma URLs teniendo en cuenta la carpeta donde está instalado el proyecto.
 *
 * En XAMPP:      http://localhost/ZENIT-TPW2/perfil  → base = "/ZENIT-TPW2"
 * En producción: https://zenit.example/perfil        → base = ""
 * Se calcula solo a partir de index.php, no hay que configurar nada.
 */
class Url
{
    public static function base(): string
    {
        $carpeta = str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? '/'));
        return rtrim($carpeta, '/');
    }

    /** Url::to('perfil/ver') → "/ZENIT-TPW2/perfil/ver" */
    public static function to(string $ruta = ''): string
    {
        return self::base() . '/' . ltrim($ruta, '/');
    }

    /** URL completa con dominio (la usa el QR del perfil). */
    public static function absoluta(string $ruta = ''): string
    {
        $https = !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off';
        $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
        return ($https ? 'https' : 'http') . '://' . $host . self::to($ruta);
    }
}
