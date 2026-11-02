<?php

namespace app\service;

/**
 * Nivel de ranking del 1 a la Z (estilo nivel de cuenta de Steam).
 *
 * No depende de cuánto jugaste solamente: para subir hay que tener
 * una cantidad mínima de respuestas CORRECTAS y un % de acierto mínimo.
 *  - Nivel 1: jugaste al menos una pregunta.
 *  - Nivel 5: ya sos muy bueno.
 *  - Nivel Z: el tope absoluto.
 * Para ajustar la dificultad alcanza con editar la tabla NIVELES.
 */
class NivelService
{
    /** [código, correctas mínimas, % de acierto mínimo, color de marca] */
    private const NIVELES = [
        ['1', 0,    0,  'blanco'],
        ['2', 20,   35, 'verde'],
        ['3', 50,   40, 'verde'],
        ['4', 100,  45, 'amarillo'],
        ['5', 200,  50, 'amarillo'],
        ['6', 350,  55, 'amarillo'],
        ['7', 500,  60, 'naranja'],
        ['8', 750,  65, 'naranja'],
        ['9', 1000, 70, 'rojo'],
        ['Z', 1500, 75, 'z'],
    ];

    public function calcular(int $respondidas, int $correctas): array
    {
        if ($respondidas === 0) {
            return [
                'codigo' => '–', 'color' => 'gris', 'es_z' => false, 'sin_nivel' => true,
                'progreso' => 0, 'siguiente' => 'Jugá tu primera partida para obtener el nivel 1',
            ];
        }

        $acierto = self::porcentaje($correctas, $respondidas);
        $indice = 0;
        foreach (self::NIVELES as $i => [$codigo, $minCorrectas, $minAcierto]) {
            if ($correctas >= $minCorrectas && $acierto >= $minAcierto) {
                $indice = $i;
            }
        }

        [$codigo, , , $color] = self::NIVELES[$indice];
        return [
            'codigo' => $codigo,
            'color' => $color,
            'es_z' => $codigo === 'Z',
            'sin_nivel' => false,
        ] + $this->progresoAlSiguiente($indice, $correctas, $acierto);
    }

    public static function porcentaje(int $parte, int $total): int
    {
        return $total > 0 ? (int) round($parte * 100 / $total) : 0;
    }

    /** Qué falta para el próximo nivel (texto + barra de progreso 0-100). */
    private function progresoAlSiguiente(int $indice, int $correctas, int $acierto): array
    {
        if (!isset(self::NIVELES[$indice + 1])) {
            return ['progreso' => 100, 'siguiente' => 'Llegaste a tu zenit: nivel máximo'];
        }

        [$codigo, $minCorrectas, $minAcierto] = self::NIVELES[$indice + 1];
        $faltan = max(0, $minCorrectas - $correctas);
        $partes = [];
        if ($faltan > 0) {
            $partes[] = "$faltan correctas más";
        }
        if ($acierto < $minAcierto) {
            $partes[] = "$minAcierto% de acierto";
        }

        return [
            'progreso' => min(100, self::porcentaje($correctas, max(1, $minCorrectas))),
            'siguiente' => "Nivel $codigo: " . implode(' y ', $partes ?: ['¡ya casi!']),
        ];
    }
}
