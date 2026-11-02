<?php

namespace app\model;

use MyDatabase;

/**
 * Estadísticas de juego del usuario: respuestas, puntos (elo),
 * partidas y porcentaje de acierto por categoría.
 */
class EstadisticaModel
{
    public function __construct(private MyDatabase $db)
    {
    }

    /** Suma una respuesta al total del usuario y a la categoría. */
    public function registrarRespuesta(int $usuarioId, int $categoriaId, bool $correcta): void
    {
        $this->actualizarTotales($usuarioId, $correcta);
        $this->actualizarCategoria($usuarioId, $categoriaId, $correcta);
    }

    public function sumarPuntos(int $usuarioId, int $puntos): void
    {
        $this->db->execute('UPDATE usuario SET puntos = puntos + ? WHERE id = ?', [$puntos, $usuarioId]);
    }

    public function registrarPartidaTerminada(int $usuarioId, bool $ganada): void
    {
        $this->db->execute(
            'UPDATE usuario SET partidas_jugadas = partidas_jugadas + 1, partidas_ganadas = partidas_ganadas + ?
             WHERE id = ?',
            [$ganada ? 1 : 0, $usuarioId]
        );
    }

    /** Todas las categorías con lo respondido por el usuario (0 si nunca jugó esa). */
    public function porCategoria(int $usuarioId): array
    {
        return $this->db->queryAll(
            'SELECT c.id, c.slug, c.nombre, c.emoji, c.color,
                    COALESCE(uc.respondidas, 0) AS respondidas,
                    COALESCE(uc.correctas, 0)   AS correctas
             FROM categoria c
             LEFT JOIN usuario_categoria uc ON uc.categoria_id = c.id AND uc.usuario_id = ?
             ORDER BY c.id',
            [$usuarioId]
        );
    }

    // ── Privados ──────────────────────────────────────

    private function actualizarTotales(int $usuarioId, bool $correcta): void
    {
        $this->db->execute(
            'UPDATE usuario SET respondidas = respondidas + 1, correctas = correctas + ? WHERE id = ?',
            [$correcta ? 1 : 0, $usuarioId]
        );
    }

    private function actualizarCategoria(int $usuarioId, int $categoriaId, bool $correcta): void
    {
        $existe = $this->db->queryOne(
            'SELECT usuario_id FROM usuario_categoria WHERE usuario_id = ? AND categoria_id = ?',
            [$usuarioId, $categoriaId]
        );

        if ($existe === null) {
            $this->db->execute(
                'INSERT INTO usuario_categoria (usuario_id, categoria_id, respondidas, correctas) VALUES (?, ?, 1, ?)',
                [$usuarioId, $categoriaId, $correcta ? 1 : 0]
            );
            return;
        }

        $this->db->execute(
            'UPDATE usuario_categoria SET respondidas = respondidas + 1, correctas = correctas + ?
             WHERE usuario_id = ? AND categoria_id = ?',
            [$correcta ? 1 : 0, $usuarioId, $categoriaId]
        );
    }
}
