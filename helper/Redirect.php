<?php
/**
 * Redirecciones internas (siempre relativas a la carpeta del proyecto).
 */
class Redirect
{
    public static function to(string $ruta = ''): void
    {
        header('Location: ' . Url::to($ruta));
        exit();
    }
}
