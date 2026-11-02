<?php

namespace app\model;

use MyDatabase;

/**
 * Reportes de preguntas hechos por los jugadores.
 */
class ReporteModel
{
    public function __construct(private MyDatabase $db)
    {
    }

    public function crear(int $preguntaId, int $usuarioId, string $motivo, ?string $detalle): void
    {
        $this->db->execute(
            'INSERT INTO reporte (pregunta_id, usuario_id, motivo, detalle) VALUES (?, ?, ?, ?)',
            [$preguntaId, $usuarioId, $motivo, $detalle]
        );
    }
}
