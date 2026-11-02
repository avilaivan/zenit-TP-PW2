<?php

namespace app\service;

use InvalidArgumentException;

/**
 * Valida y guarda la foto de perfil en public/uploads/perfiles/.
 *
 * El navegador ya la manda recortada (editor circular), pero igual se
 * normaliza en el servidor a un cuadrado de 512×512 en JPG, así todas
 * las fotos tienen la misma medida estándar.
 */
class FotoPerfilService
{
    public const LADO = 512;
    private const MAX_BYTES = 5 * 1024 * 1024; // 5 MB
    private const TIPOS = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
    private const CARPETA_PUBLICA = 'public/uploads/perfiles/';

    /**
     * @param array|null $archivo elemento de $_FILES
     * @return string ruta relativa guardada (ej: public/uploads/perfiles/abc.jpg)
     * @throws InvalidArgumentException si el archivo no es válido
     */
    public function guardar(?array $archivo): string
    {
        if ($archivo === null || $archivo['error'] === UPLOAD_ERR_NO_FILE) {
            throw new InvalidArgumentException('Elegí una imagen.');
        }
        if ($archivo['error'] !== UPLOAD_ERR_OK) {
            throw new InvalidArgumentException('No se pudo subir la foto. Probá con otra imagen.');
        }
        if ($archivo['size'] > self::MAX_BYTES) {
            throw new InvalidArgumentException('La foto no puede superar los 5 MB.');
        }

        // Se mira el contenido real del archivo, no la extensión que manda el navegador.
        $tipo = (new \finfo(FILEINFO_MIME_TYPE))->file($archivo['tmp_name']);
        if (!isset(self::TIPOS[$tipo])) {
            throw new InvalidArgumentException('La foto debe ser JPG, PNG o WEBP.');
        }

        $carpeta = dirname(__DIR__, 2) . '/' . self::CARPETA_PUBLICA;
        if (!is_dir($carpeta)) {
            mkdir($carpeta, 0755, true);
        }

        // Nombre aleatorio: nunca se usa el nombre original del archivo.
        $base = bin2hex(random_bytes(16));
        if ($this->normalizar($archivo['tmp_name'], $carpeta . $base . '.jpg')) {
            return self::CARPETA_PUBLICA . $base . '.jpg';
        }

        // Sin la extensión GD se guarda tal cual llegó (ya viene recortada del navegador).
        $nombre = $base . '.' . self::TIPOS[$tipo];
        if (!move_uploaded_file($archivo['tmp_name'], $carpeta . $nombre)) {
            throw new InvalidArgumentException('No se pudo guardar la foto.');
        }
        return self::CARPETA_PUBLICA . $nombre;
    }

    /** Borra del disco una foto anterior (al cambiarla o al eliminar la cuenta). */
    public function borrar(?string $ruta): void
    {
        if ($ruta && str_starts_with($ruta, self::CARPETA_PUBLICA)) {
            $archivo = dirname(__DIR__, 2) . '/' . $ruta;
            if (is_file($archivo)) {
                unlink($archivo);
            }
        }
    }

    /** Recorte cuadrado centrado + redimensión a 512×512 con GD. */
    private function normalizar(string $origen, string $destino): bool
    {
        if (!function_exists('imagecreatefromstring')) {
            return false;
        }
        $imagen = @imagecreatefromstring((string) file_get_contents($origen));
        if (!$imagen) {
            return false;
        }

        $ancho = imagesx($imagen);
        $alto = imagesy($imagen);
        $lado = min($ancho, $alto);
        $lienzo = imagecreatetruecolor(self::LADO, self::LADO);
        imagefill($lienzo, 0, 0, imagecolorallocate($lienzo, 18, 20, 23)); // fondo grafito si había transparencia
        imagecopyresampled(
            $lienzo, $imagen, 0, 0,
            intdiv($ancho - $lado, 2), intdiv($alto - $lado, 2),
            self::LADO, self::LADO, $lado, $lado
        );
        $ok = imagejpeg($lienzo, $destino, 88);
        imagedestroy($imagen);
        imagedestroy($lienzo);
        return $ok;
    }
}
