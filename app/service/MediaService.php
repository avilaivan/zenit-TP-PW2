<?php

namespace app\service;

use Url;

/**
 * Lee la carpeta media/ (logo, favicon, fondos y emoji de cada categoría).
 * Así se pueden cambiar imágenes y emojis sin tocar código ni la base de datos.
 */
class MediaService
{
    private string $raiz;
    private ?array $emojis = null; // caché de categorias.ini

    public function __construct()
    {
        $this->raiz = dirname(__DIR__, 2) . '/media/';
    }

    public function logo(): string
    {
        return $this->url('logo/zenit-logo.png');
    }

    public function favicon(): string
    {
        return $this->url('logo/favicon.png');
    }

    public function appleTouchIcon(): string
    {
        return $this->url('logo/apple-touch-icon.png');
    }

    /** Fondo de página: "home" (lobby, con las categorías) o "espacio" (el resto). */
    public function fondo(string $nombre): string
    {
        return $this->url("fondos/$nombre.jpg");
    }

    /** Ruta en disco del logo (para incrustarlo en los mails). */
    public function archivoLogo(): string
    {
        return $this->raiz . 'logo/zenit-logo.png';
    }

    /** Agrega a la categoría su emoji (de categorias.ini). */
    public function decorarCategoria(array $categoria): array
    {
        $slug = $categoria['slug'] ?? '';
        $categoria['emoji'] = $this->emojis()[$slug] ?? ($categoria['emoji'] ?? '❔');
        return $categoria;
    }

    public function decorarCategorias(array $categorias): array
    {
        return array_map([$this, 'decorarCategoria'], $categorias);
    }

    // ── Privados ──────────────────────────────────────

    private function emojis(): array
    {
        if ($this->emojis === null) {
            $archivo = $this->raiz . 'categorias/categorias.ini';
            $this->emojis = file_exists($archivo) ? (parse_ini_file($archivo) ?: []) : [];
        }
        return $this->emojis;
    }

    /** URL pública con "?v=fecha" para que el navegador tome los cambios al instante. */
    private function url(string $relativa): string
    {
        $archivo = $this->raiz . $relativa;
        $version = file_exists($archivo) ? filemtime($archivo) : 0;
        return Url::to('media/' . $relativa) . '?v=' . $version;
    }
}
