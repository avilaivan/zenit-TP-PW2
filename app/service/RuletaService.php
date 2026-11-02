<?php

namespace app\service;

/**
 * Sorteo de la ruleta (estilo apertura de caja de CS2).
 *
 * El RESULTADO lo decide siempre el servidor. Además arma la "tira" de
 * ítems que el navegador anima de derecha a izquierda: el ganador queda
 * en la posición POSICION_GANADOR y el resto es relleno aleatorio.
 */
class RuletaService
{
    public const TOTAL_ITEMS = 48;
    public const POSICION_GANADOR = 40;

    // Ítems especiales (no son categorías de preguntas)
    public const ITEM_Z = ['id' => 'Z', 'nombre' => 'Categoría Z', 'emoji' => 'Z', 'color' => '#FF3B4F', 'especial' => 'z'];
    public const ITEM_LETRA = ['id' => 'LETRA', 'nombre' => 'Ronda de letra', 'emoji' => '✦', 'color' => '#F2F3F5', 'especial' => 'letra'];

    /** ¿Sale la categoría Z en este giro? */
    public function saleZ(float $probabilidad): bool
    {
        return mt_rand() / mt_getrandmax() < $probabilidad;
    }

    public function categoriaAlAzar(array $categorias): array
    {
        return $categorias[array_rand($categorias)];
    }

    /** N categorías distintas (para la ronda de letra: 1 pregunta de cada una). */
    public function categoriasDistintas(array $categorias, int $cantidad): array
    {
        shuffle($categorias);
        return array_slice($categorias, 0, $cantidad);
    }

    /**
     * Tira para la animación. Incluye alguna "Z" de relleno para generar
     * suspenso, pero nunca pegada al ganador (así no confunde).
     */
    public function armarTira(array $categorias, array $ganador): array
    {
        $tira = [];
        for ($i = 0; $i < self::TOTAL_ITEMS; $i++) {
            $lejosDelGanador = abs($i - self::POSICION_GANADOR) > 2;
            $tira[] = ($lejosDelGanador && mt_rand(1, 14) === 1)
                ? self::ITEM_Z
                : self::paraTira($this->categoriaAlAzar($categorias));
        }
        $tira[self::POSICION_GANADOR] = $ganador;
        return $tira;
    }

    /** Solo lo que necesita el navegador para dibujar el ítem. */
    public static function paraTira(array $categoria): array
    {
        return [
            'id' => (int) $categoria['id'],
            'nombre' => $categoria['nombre'],
            'emoji' => $categoria['emoji'],
            'color' => $categoria['color'],
            'especial' => null,
        ];
    }
}
