<?php
/**
 * Respuestas JSON para los endpoints del juego (fetch desde JS).
 */
class Json
{
    public static function responder(array $datos, int $codigo = 200): void
    {
        http_response_code($codigo);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($datos, JSON_UNESCAPED_UNICODE);
        exit();
    }

    public static function error(string $mensaje, int $codigo = 400): void
    {
        self::responder(['ok' => false, 'error' => $mensaje], $codigo);
    }
}
