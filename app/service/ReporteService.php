<?php

namespace app\service;

use app\model\ReporteModel;
use DomainException;

/**
 * Reporte de preguntas.
 *
 * Solo se puede reportar al TERMINAR una ronda (de categoría o de letra),
 * y solo las preguntas de esa ronda: el jugador elige cuáles (1, 2 y/o 3),
 * un motivo y, si quiere, escribe un comentario.
 */
class ReporteService
{
    public const MOTIVOS = [
        'ofensiva' => 'Me parece ofensiva',
        'respuesta_incorrecta' => 'La respuesta está mal',
        'confusa' => 'Está mal escrita o es confusa',
        'otro' => 'Otro problema',
    ];
    private const MAX_DETALLE = 500;

    public function __construct(
        private EstadoJuego $almacen,
        private ReporteModel $reportes
    ) {
    }

    /**
     * @param int[]  $numeros posiciones de las preguntas en la ronda (1, 2, 3)
     * @return int cantidad de preguntas reportadas
     */
    public function reportar(int $usuarioId, array $numeros, string $motivo, string $detalle): int
    {
        $estado = $this->almacen->obtener();
        $ronda = $estado['ultima_ronda'] ?? null;

        if (!$estado || $estado['usuario_id'] !== $usuarioId || $ronda === null) {
            throw new DomainException('Solo podés reportar al terminar una ronda.');
        }
        if ($ronda['reportada']) {
            throw new DomainException('Ya enviaste un reporte de esta ronda.');
        }
        if (!isset(self::MOTIVOS[$motivo])) {
            throw new DomainException('Elegí un motivo.');
        }

        $numeros = array_unique(array_map('intval', $numeros));
        $validos = array_filter($numeros, fn($n) => $n >= 1 && $n <= count($ronda['preguntas']));
        if ($validos === [] || count($validos) !== count($numeros)) {
            throw new DomainException('Elegí al menos una pregunta.');
        }

        $detalle = trim($detalle);
        $detalle = $detalle === '' ? null : mb_substr($detalle, 0, self::MAX_DETALLE);
        foreach ($validos as $numero) {
            $this->reportes->crear($ronda['preguntas'][$numero - 1], $usuarioId, $motivo, $detalle);
        }

        $estado['ultima_ronda']['reportada'] = true; // un reporte por ronda
        $this->almacen->guardar($estado);
        return count($validos);
    }
}
