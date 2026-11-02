<?php
/**
 * Acceso simple a los datos de la petición.
 */
class Request
{
    public static function get(string $clave, $porDefecto = null)
    {
        return $_GET[$clave] ?? $porDefecto;
    }

    public static function post(string $clave, $porDefecto = null)
    {
        return $_POST[$clave] ?? $porDefecto;
    }

    /** Texto recortado desde POST (atajo muy usado en formularios). */
    public static function texto(string $clave): string
    {
        return trim((string) self::post($clave, ''));
    }

    public static function esPost(): bool
    {
        return ($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST';
    }

    /** Cuerpo JSON enviado con fetch() desde el juego. */
    public static function json(): array
    {
        $datos = json_decode(file_get_contents('php://input') ?: '', true);
        return is_array($datos) ? $datos : [];
    }

    public static function archivo(string $clave): ?array
    {
        return $_FILES[$clave] ?? null;
    }
}
