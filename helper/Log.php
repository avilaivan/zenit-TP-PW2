<?php
/**
 * Log simple a archivo: log/AAAA-MM-DD.log
 */
class Log
{
    public static function info(string $mensaje): void
    {
        self::escribir('info', $mensaje);
    }

    public static function error(string $mensaje): void
    {
        self::escribir('error', $mensaje);
    }

    /** Escribe en un archivo propio (ej: correos.log para los mails de prueba). */
    public static function enArchivo(string $archivo, string $mensaje): void
    {
        file_put_contents(self::carpeta() . '/' . $archivo, $mensaje . "\n", FILE_APPEND | LOCK_EX);
    }

    private static function escribir(string $nivel, string $mensaje): void
    {
        $linea = sprintf("[%s] [%s] %s", date('H:i:s'), strtoupper($nivel), $mensaje);
        self::enArchivo(date('Y-m-d') . '.log', $linea);
    }

    private static function carpeta(): string
    {
        $carpeta = __DIR__ . '/../log';
        if (!is_dir($carpeta)) {
            mkdir($carpeta, 0755, true);
        }
        return $carpeta;
    }
}
