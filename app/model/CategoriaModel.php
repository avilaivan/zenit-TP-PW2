<?php

namespace app\model;

use app\service\MediaService;
use MyDatabase;

/**
 * Categorías de preguntas.
 * Nombre y color salen de la base; el emoji de media/categorias/categorias.ini.
 */
class CategoriaModel
{
    public function __construct(
        private MyDatabase $db,
        private MediaService $media
    ) {
    }

    public function todas(): array
    {
        return $this->media->decorarCategorias($this->db->queryAll('SELECT * FROM categoria ORDER BY id'));
    }

    public function buscar(int $id): ?array
    {
        $categoria = $this->db->queryOne('SELECT * FROM categoria WHERE id = ?', [$id]);
        return $categoria ? $this->media->decorarCategoria($categoria) : null;
    }
}
