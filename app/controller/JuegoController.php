<?php

namespace app\controller;

use app\model\CategoriaModel;
use app\service\JuegoService;
use app\service\ReporteService;
use app\service\ReglasJuego;
use app\service\RuletaService;
use DomainException;
use Json;
use Log;
use MustacheRender;
use Request;
use Session;
use Throwable;

/**
 * Pantalla del juego individual + API JSON que usa public/js/juego.js.
 *
 *  GET  /juego            → pantalla
 *  POST /juego/estado     → estado actual (para retomar si se recarga)
 *  POST /juego/iniciar    → partida nueva
 *  POST /juego/girar      → gira la ruleta
 *  POST /juego/pregunta   → pregunta actual (sin la respuesta)
 *  POST /juego/responder  → {opcion_id}
 *  POST /juego/premio     → {eleccion: "letra" | "vida"}
 *  POST /juego/abandonar  → termina la partida
 *  POST /juego/reportar   → {preguntas: [1,3], motivo, detalle} (solo al terminar una ronda)
 */
class JuegoController
{
    public function __construct(
        private MustacheRender $render,
        private JuegoService $juego,
        private CategoriaModel $categorias,
        private ReporteService $reportes
    ) {
    }

    public function show(): void
    {
        Session::requerirLogin('Iniciá sesión o creá una cuenta para jugar.');
        $this->render->renderiza('juego', [
            'nav_jugar' => true,
            'modo_juego' => true,
            // Opciones del formulario "Reportar un problema"
            'motivos_reporte' => array_map(
                fn($clave, $texto) => ['clave' => $clave, 'texto' => $texto],
                array_keys(ReporteService::MOTIVOS),
                ReporteService::MOTIVOS
            ),
            // Ítems de muestra para la ruleta antes del primer giro
            'categorias_json' => json_encode(
                array_map([RuletaService::class, 'paraTira'], $this->categorias->todas()),
                JSON_UNESCAPED_UNICODE
            ),
            'reglas' => [
                'vidas' => ReglasJuego::VIDAS_INICIALES,
                'preguntas' => ReglasJuego::PREGUNTAS_POR_RONDA,
                'minimo' => ReglasJuego::MINIMO_ACIERTOS,
                'rondas_letra' => ReglasJuego::RONDAS_PARA_LETRA,
                'segundos' => ReglasJuego::SEGUNDOS_POR_PREGUNTA,
            ],
        ]);
    }

    public function estado(): void
    {
        $this->api(fn(int $id) => ['estado' => $this->juego->estado($id)]);
    }

    public function iniciar(): void
    {
        $this->api(fn(int $id) => ['estado' => $this->juego->iniciar($id)]);
    }

    public function girar(): void
    {
        $this->api(fn(int $id) => $this->juego->girar($id));
    }

    public function pregunta(): void
    {
        $this->api(fn(int $id) => $this->juego->pregunta($id));
    }

    public function responder(): void
    {
        $opcion = Request::json()['opcion_id'] ?? null;
        $this->api(fn(int $id) => $this->juego->responder($id, is_numeric($opcion) ? (int) $opcion : null));
    }

    public function premio(): void
    {
        $eleccion = (string) (Request::json()['eleccion'] ?? '');
        $this->api(fn(int $id) => $this->juego->elegirPremio($id, $eleccion));
    }

    public function reportar(): void
    {
        $datos = Request::json();
        $this->api(fn(int $id) => ['reportadas' => $this->reportes->reportar(
            $id,
            (array) ($datos['preguntas'] ?? []),
            (string) ($datos['motivo'] ?? ''),
            (string) ($datos['detalle'] ?? '')
        )]);
    }

    public function abandonar(): void
    {
        $this->api(function (int $id) {
            $this->juego->abandonar($id);
            return ['estado' => null];
        });
    }

    /**
     * Envoltorio común de la API: exige POST y sesión, y transforma
     * las excepciones en respuestas JSON con el código HTTP adecuado.
     */
    private function api(callable $accion): void
    {
        if (!Request::esPost()) {
            Json::error('Método no permitido.', 405);
        }
        $usuarioId = Session::usuarioId();
        if ($usuarioId === null) {
            Json::error('Tu sesión expiró. Volvé a iniciar sesión.', 401);
        }

        try {
            Json::responder(['ok' => true] + $accion($usuarioId));
        } catch (DomainException $e) {
            Json::error($e->getMessage(), 409);
        } catch (Throwable $e) {
            Log::error('Juego: ' . $e->getMessage() . ' en ' . $e->getFile() . ':' . $e->getLine());
            Json::error('Ocurrió un error inesperado.', 500);
        }
    }
}
