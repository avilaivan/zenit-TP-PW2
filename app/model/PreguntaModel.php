<?php

namespace app\model;

use MyDatabase;

/**
 * Preguntas y sus opciones.
 */
class PreguntaModel
{
    public function __construct(private MyDatabase $db)
    {
    }

    /** Ids de las preguntas activas de una categoría. */
    public function idsPorCategoria(int $categoriaId): array
    {
        $filas = $this->db->queryAll(
            'SELECT id FROM pregunta WHERE categoria_id = ? AND activa = 1',
            [$categoriaId]
        );
        return array_map(fn($fila) => (int) $fila['id'], $filas);
    }

    /**
     * Pregunta completa con sus opciones (incluye cuál es la correcta).
     * ¡Esto NO se manda tal cual al navegador! El servicio de juego lo filtra.
     */
    public function buscarConOpciones(int $id): ?array
    {
        $pregunta = $this->db->queryOne(
            'SELECT id, enunciado, categoria_id FROM pregunta WHERE id = ?',
            [$id]
        );
        if ($pregunta === null) {
            return null;
        }

        $pregunta['opciones'] = $this->db->queryAll(
            'SELECT id, texto, es_correcta FROM opcion WHERE pregunta_id = ? ORDER BY id',
            [$id]
        );
        return $pregunta;
    }
}
