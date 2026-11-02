<?php

namespace app\controller;

use app\model\UsuarioModel;
use app\service\JuegoService;
use app\service\PerfilService;
use MustacheRender;
use Session;

/**
 * Lobby: un único botón grande de JUGAR sobre el fondo de categorías.
 * Es la puerta de entrada y se ve SIN iniciar sesión: el login se pide
 * recién al tocar JUGAR (o al entrar a Perfil, Ranking, etc.).
 */
class HomeController
{
    public function __construct(
        private MustacheRender $render,
        private UsuarioModel $usuarios,
        private PerfilService $perfiles,
        private JuegoService $juego
    ) {
    }

    public function show(): void
    {
        $usuarioId = Session::usuarioId();
        $usuario = $usuarioId !== null ? $this->usuarios->buscarPorId($usuarioId) : null;
        $estado = $usuario ? $this->juego->estado($usuarioId) : null;

        $this->render->renderiza('home', [
            'nav_jugar' => true,
            'fondo_home' => true, // fondo con las categorías (el resto usa el espacio vacío)
            'jugador' => $usuario ? $this->perfiles->resumen($usuario) : null,
            'visitante' => $usuario === null,
            'partida_en_curso' => $estado !== null && $estado['fase'] !== JuegoService::FASE_FIN,
        ]);
    }
}
