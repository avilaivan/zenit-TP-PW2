<?php

namespace app\service;

use app\model\EstadisticaModel;
use app\model\PartidaModel;
use Url;

/**
 * Arma los datos "listos para mostrar" de un jugador:
 * avatar, nivel, elo, porcentajes y estadísticas por categoría.
 * Lo usan el perfil y la barra superior.
 */
class PerfilService
{
    public function __construct(
        private EstadisticaModel $estadisticas,
        private PartidaModel $partidas,
        private NivelService $niveles,
        private MediaService $media,
        private PaisService $paises
    ) {
    }

    /** Datos básicos (barra superior, chips de usuario). */
    public function resumen(array $usuario): array
    {
        $respondidas = (int) $usuario['respondidas'];
        $correctas = (int) $usuario['correctas'];

        return [
            'id' => (int) $usuario['id'],
            'nombre_usuario' => $usuario['nombre_usuario'],
            'nombre_completo' => $usuario['nombre_completo'] ?? '',
            'iniciales' => strtoupper(substr($usuario['nombre_usuario'], 0, 2)),
            'foto' => $usuario['foto_perfil'] ? Url::to($usuario['foto_perfil']) : null,
            'pais' => $usuario['pais'],
            'bandera' => $this->paises->bandera($usuario['pais']), // imagen + emoji de la bandera
            'ciudad' => $usuario['ciudad'],
            'elo' => number_format((int) $usuario['puntos'], 0, ',', '.'),
            'nivel' => $this->niveles->calcular($respondidas, $correctas),
        ];
    }

    /** Todo lo del perfil completo. */
    public function completo(array $usuario): array
    {
        $respondidas = (int) $usuario['respondidas'];
        $correctas = (int) $usuario['correctas'];

        return $this->resumen($usuario) + [
            'miembro_desde' => date('m/Y', strtotime($usuario['creado'] ?? 'now')),
            'respondidas' => $respondidas,
            'correctas' => $correctas,
            'acierto' => NivelService::porcentaje($correctas, $respondidas),
            'partidas_jugadas' => (int) $usuario['partidas_jugadas'],
            'partidas_ganadas' => (int) $usuario['partidas_ganadas'],
            'categorias' => $this->categorias((int) $usuario['id']),
            'historial' => $this->historial((int) $usuario['id']),
            'mapa' => self::puntoMapa($usuario),
            'url_publica' => Url::absoluta('perfil/ver?u=' . rawurlencode($usuario['nombre_usuario'])),
        ];
    }

    /**
     * Punto para el mapa del perfil. Las coordenadas se redondean a 2 decimales
     * (~1 km): el perfil es público y alcanza con mostrar la zona, no la casa.
     * Si no marcó el mapa al registrarse, se busca "ciudad, país" en el navegador.
     */
    private static function puntoMapa(array $usuario): array
    {
        $tieneCoordenadas = $usuario['latitud'] !== null && $usuario['longitud'] !== null;
        return [
            'lat' => $tieneCoordenadas ? round((float) $usuario['latitud'], 2) : '',
            'lon' => $tieneCoordenadas ? round((float) $usuario['longitud'], 2) : '',
            'buscar' => $usuario['ciudad'] . ', ' . $usuario['pais'],
        ];
    }

    private function categorias(int $usuarioId): array
    {
        return array_map(function (array $c) {
            $c['porcentaje'] = NivelService::porcentaje((int) $c['correctas'], (int) $c['respondidas']);
            return $c;
        }, $this->media->decorarCategorias($this->estadisticas->porCategoria($usuarioId)));
    }

    private function historial(int $usuarioId): array
    {
        return array_map(fn(array $p) => [
            'victoria' => $p['resultado'] === 'victoria',
            'letras' => $p['letras'] !== '' ? $p['letras'] : '—',
            'puntos' => (int) $p['puntos'],
            'aciertos' => $p['correctas'] . '/' . $p['respondidas'],
            'fecha' => date('d/m H:i', strtotime($p['terminada'] ?? $p['creada'])),
        ], $this->partidas->ultimas($usuarioId));
    }
}
