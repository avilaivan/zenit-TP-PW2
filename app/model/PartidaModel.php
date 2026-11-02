<?php

namespace app\model;

use MyDatabase;

/**
 * Historial de partidas individuales.
 */
class PartidaModel
{
    public function __construct(private MyDatabase $db)
    {
    }

    public function crear(int $usuarioId): int
    {
        $this->db->execute('INSERT INTO partida (usuario_id) VALUES (?)', [$usuarioId]);
        return $this->db->lastInsertId();
    }

    public function cerrar(int $id, string $resultado, int $puntos, string $letras, int $respondidas, int $correctas): void
    {
        $this->db->execute(
            'UPDATE partida
             SET resultado = ?, puntos = ?, letras = ?, respondidas = ?, correctas = ?, terminada = ?
             WHERE id = ?',
            [$resultado, $puntos, $letras, $respondidas, $correctas, date('Y-m-d H:i:s'), $id]
        );
    }

    /** Últimas partidas terminadas (para el perfil). */
    public function ultimas(int $usuarioId, int $cantidad = 5): array
    {
        $cantidad = max(1, min(20, $cantidad)); // LIMIT no acepta parámetros en todas las versiones
        return $this->db->queryAll(
            "SELECT * FROM partida WHERE usuario_id = ? AND resultado <> 'en_curso'
             ORDER BY id DESC LIMIT $cantidad",
            [$usuarioId]
        );
    }
}
