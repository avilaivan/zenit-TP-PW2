<?php

namespace app\controller;

use app\model\UsuarioModel;
use app\service\VerificacionService;
use MustacheRender;
use Redirect;
use Request;
use Session;

/**
 * Inicio y cierre de sesión.
 */
class LoginController
{
    public function __construct(
        private MustacheRender $render,
        private UsuarioModel $usuarios,
        private VerificacionService $verificacion
    ) {
    }

    public function show(): void
    {
        if (Session::estaLogueado()) {
            Redirect::to('');
        }
        $this->render->renderiza('login', ['pantalla_auth' => true]);
    }

    public function login(): void
    {
        $usuarioOEmail = Request::texto('usuario');
        $password = (string) Request::post('password', '');
        $usuario = $usuarioOEmail !== '' ? $this->usuarios->buscarParaLogin($usuarioOEmail) : null;

        if ($usuario === null || !password_verify($password, $usuario['password'])) {
            $this->render->renderiza('login', [
                'pantalla_auth' => true,
                'error' => 'Usuario o contraseña incorrectos.',
                'usuario' => $usuarioOEmail,
            ]);
            return;
        }

        // Cuenta sin verificar: le mandamos un código nuevo y lo llevamos a validarlo.
        if (!(int) $usuario['activo']) {
            Session::set('verificar_id', (int) $usuario['id']);
            Session::set('ultimo_envio', time());
            $enviado = $this->verificacion->enviar($usuario, VerificacionService::REGISTRO);
            Session::flash(
                $enviado ? 'info' : 'error',
                $enviado ? 'Tu cuenta todavía no está verificada. Te mandamos un código nuevo al mail.'
                         : 'Tu cuenta no está verificada y no pudimos enviar el mail. Probá reenviar el código.'
            );
            Redirect::to('registro/verificar');
        }

        Session::iniciar($usuario);
        Redirect::to(Session::tomarDestino()); // ej: tocó JUGAR sin cuenta → vuelve al juego
    }

    public function logout(): void
    {
        Session::cerrar();
        Redirect::to(''); // vuelve al lobby público
    }
}
