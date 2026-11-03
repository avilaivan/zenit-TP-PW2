<?php

namespace app\model;

use MyDatabase;

/**
 * Qué preguntas ya vio cada jugador (entre TODAS sus partidas).
 *
 * Sirve para no repetir: a un jugador no le vuelve a tocar una pregunta
 * de una categoría hasta haber visto todas las demás de esa categoría.
 * Cuando las vio todas, se borra su historial de esa categoría y empieza
 * un ciclo nuevo.
 */
class PreguntaVistaModel
{
    public function __construct(private MyDatabase $db)
    {
    }

    /** Ids de las preguntas de la categoría que el jugador ya vio. */
    public function deCategoria(int $usuarioId, int $categoriaId): array
    {
        $filas = $this->db->queryAll(
            'SELECT pv.pregunta_id
             FROM pregunta_vista pv
             JOIN pregunta p ON p.id = pv.pregunta_id
             WHERE pv.usuario_id = ? AND p.categoria_id = ?',
            [$usuarioId, $categoriaId]
        );
        return array_map(fn($fila) => (int) $fila['pregunta_id'], $filas);
    }

    /** Anota preguntas como vistas (si ya estaban, no hace nada). */
    public function marcar(int $usuarioId, array $preguntaIds): void
    {
        // "orden" crece siempre (milisegundos): sirve para saber cuáles vio último.
        $orden = (int) (microtime(true) * 1000);
        foreach (array_values($preguntaIds) as $i => $preguntaId) {
            $existe = $this->db->queryOne(
                'SELECT 1 FROM pregunta_vista WHERE usuario_id = ? AND pregunta_id = ?',
                [$usuarioId, $preguntaId]
            );
            if ($existe === null) {
                $this->db->execute(
                    'INSERT INTO pregunta_vista (usuario_id, pregunta_id, orden) VALUES (?, ?, ?)',
                    [$usuarioId, $preguntaId, $orden + $i]
                );
            }
        }
    }

    /**
     * Ciclo completo: vuelve a habilitar las preguntas de la categoría para el jugador,
     * menos las últimas que vio (así no le sale una que acaba de responder).
     * @return int[] ids de las que se conservan como vistas
     */
    public function reiniciarCategoria(int $usuarioId, int $categoriaId, int $conservarRecientes): array
    {
        $recientes = array_map(fn($fila) => (int) $fila['pregunta_id'], $this->db->queryAll(
            "SELECT pv.pregunta_id
             FROM pregunta_vista pv
             JOIN pregunta p ON p.id = pv.pregunta_id
             WHERE pv.usuario_id = ? AND p.categoria_id = ?
             ORDER BY pv.orden DESC
             LIMIT $conservarRecientes",
            [$usuarioId, $categoriaId]
        ));

        $sql = 'DELETE FROM pregunta_vista
                WHERE usuario_id = ? AND pregunta_id IN (SELECT id FROM pregunta WHERE categoria_id = ?)';
        $parametros = [$usuarioId, $categoriaId];
        if ($recientes !== []) {
            $sql .= ' AND pregunta_id NOT IN (' . implode(',', array_fill(0, count($recientes), '?')) . ')';
            $parametros = array_merge($parametros, $recientes);
        }
        $this->db->execute($sql, $parametros);
        return $recientes;
    }
}
