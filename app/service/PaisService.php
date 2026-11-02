<?php

namespace app\service;

/**
 * Lista de países (public/data/paises.json, la misma que usa el autocompletado)
 * y su bandera.
 *
 * Las banderas se muestran como imagen (flagcdn.com) porque Windows no
 * dibuja los emojis de banderas; el emoji queda como texto alternativo.
 */
class PaisService
{
    private ?array $paises = null;

    /** Devuelve el nombre oficial de la lista ("argentina" → "Argentina") o null si no existe. */
    public function nombreValido(string $nombre): ?string
    {
        $pais = $this->buscar($nombre);
        return $pais['nombre'] ?? null;
    }

    /** ['codigo' => 'ar', 'emoji' => '🇦🇷', 'imagen' => 'https://flagcdn.com/…'] o null. */
    public function bandera(string $nombre): ?array
    {
        $pais = $this->buscar($nombre);
        if ($pais === null) {
            return null;
        }
        $codigo = $pais['codigo'];
        return [
            'codigo' => $codigo,
            'emoji' => self::emoji($codigo),
            'imagen' => "https://flagcdn.com/w40/$codigo.png",
        ];
    }

    /** "ar" → 🇦🇷 (cada letra se convierte en un "indicador regional" Unicode). */
    public static function emoji(string $codigo): string
    {
        $emoji = '';
        foreach (str_split(strtoupper($codigo)) as $letra) {
            $emoji .= mb_chr(0x1F1E6 + ord($letra) - ord('A'), 'UTF-8');
        }
        return $emoji;
    }

    // ── Privados ──────────────────────────────────────

    private function buscar(string $nombre): ?array
    {
        $clave = self::normalizar($nombre);
        foreach ($this->lista() as $pais) {
            if (self::normalizar($pais['nombre']) === $clave) {
                return $pais;
            }
        }
        return null;
    }

    private function lista(): array
    {
        if ($this->paises === null) {
            $archivo = dirname(__DIR__, 2) . '/public/data/paises.json';
            $this->paises = json_decode((string) file_get_contents($archivo), true) ?: [];
        }
        return $this->paises;
    }

    /** "  Perú " → "peru" (sin acentos ni mayúsculas, para comparar). */
    private static function normalizar(string $texto): string
    {
        $texto = mb_strtolower(trim($texto), 'UTF-8');
        return strtr($texto, ['á' => 'a', 'é' => 'e', 'í' => 'i', 'ó' => 'o', 'ú' => 'u', 'ü' => 'u', 'ñ' => 'n']);
    }
}
