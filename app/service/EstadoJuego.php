<?php

namespace app\service;

/**
 * Guarda el estado de la partida en curso en la sesión del servidor.
 *
 * Al estar en el servidor, el jugador no puede "tocar" sus vidas, letras
 * ni ver la respuesta correcta desde el navegador. Si recarga la página,
 * la partida sigue donde estaba.
 */
class EstadoJuego
{
    private const CLAVE = 'zenit_partida';

    public function obtener(): ?array
    {
        return $_SESSION[self::CLAVE] ?? null;
    }

    public function guardar(array $estado): void
    {
        $_SESSION[self::CLAVE] = $estado;
    }

    public function borrar(): void
    {
        unset($_SESSION[self::CLAVE]);
    }

    /** Estado inicial de una partida nueva. */
    public static function nuevo(int $partidaId, int $usuarioId): array
    {
        return [
            'partida_id' => $partidaId,
            'usuario_id' => $usuarioId,
            'fase' => JuegoService::FASE_GIRAR,
            'vidas' => ReglasJuego::VIDAS_INICIALES,
            'letras' => '',                 // ej: "ZEN"
            'puntos' => 0,
            'respondidas' => 0,
            'correctas' => 0,
            'prob_z' => ReglasJuego::PROB_Z_BASE,
            'rondas_superadas' => 0,        // contador hacia la ronda de letra
            'origen_premio' => null,        // "letra" | "z"
            'resultado' => null,            // "victoria" | "derrota"
            'vistas' => [],                 // ids de preguntas ya usadas en esta partida
            'ronda' => null,                // ronda en juego (ver JuegoService::nuevaRonda)
            'ultima_ronda' => null,         // preguntas de la ronda terminada (las que se pueden reportar)
        ];
    }
}
