<?php

namespace app\controller;

use app\model\UsuarioModel;
use app\service\CorreoService;
use app\service\FotoPerfilService;
use app\service\PerfilService;
use app\service\ValidadorRegistro;
use app\service\VerificacionService;
use InvalidArgumentException;
use Json;
use MustacheRender;
use Redirect;
use Request;
use Session;
use Url;

/**
 * Perfil del jugador (estilo Steam) + edición de la cuenta.
 *
 *  /perfil                        → mi perfil (menú ⋮ con las opciones)
 *  /perfil/ver?u=xxx              → perfil público (a donde apunta el QR)
 *  /perfil/editar                 → editar nombre completo, foto y contraseña (usuario y email son fijos)
 *  /perfil/guardar                → guarda el nombre completo
 *  /perfil/foto                   → sube la foto ya recortada (fetch → JSON)
 *  /perfil/password               → paso 1: valida y manda código al mail
 *  /perfil/confirmarPassword      → paso 2: código → cambia la contraseña
 *  /perfil/cancelarPassword       → descarta el cambio pendiente
 *  /perfil/eliminar               → pantalla de baja de cuenta
 *  /perfil/solicitarEliminacion   → manda el código de baja al mail
 *  /perfil/confirmarEliminacion   → código → elimina la cuenta
 *
 * El email nunca se puede cambiar.
 */
class PerfilController
{
    public function __construct(
        private MustacheRender $render,
        private UsuarioModel $usuarios,
        private PerfilService $perfiles,
        private FotoPerfilService $fotos,
        private VerificacionService $verificacion,
        private CorreoService $correo
    ) {
    }

    // ════════════════════════════════════════════════
    //  Ver perfiles
    // ════════════════════════════════════════════════

    public function show(): void
    {
        $usuario = $this->usuarioLogueado();
        $this->render->renderiza('perfil', [
            'nav_perfil' => true,
            'es_propio' => true,
            'perfil' => $this->perfiles->completo($usuario),
        ]);
    }

    public function ver(): void
    {
        $usuario = $this->usuarios->buscarPorNombreUsuario((string) Request::get('u', ''));

        if ($usuario === null || !(int) $usuario['activo']) {
            Session::flash('error', 'Ese jugador no existe.');
            Redirect::to('');
        }
        if ((int) $usuario['id'] === Session::usuarioId()) {
            Redirect::to('perfil');
        }
        $this->render->renderiza('perfil', [
            'es_propio' => false,
            'perfil' => $this->perfiles->completo($usuario),
        ]);
    }

    // ════════════════════════════════════════════════
    //  Editar perfil: usuario, ubicación y foto
    // ════════════════════════════════════════════════

    public function editar(): void
    {
        $usuario = $this->usuarioLogueado();
        $this->render->renderiza('editarPerfil', [
            'nav_perfil' => true,
            'yo_perfil' => $this->perfiles->resumen($usuario),
            'form' => [
                'nombre_completo' => $usuario['nombre_completo'] ?? '',
                'nombre_usuario' => $usuario['nombre_usuario'],
                'email' => $usuario['email'],
            ],
            'password_pendiente' => Session::get('password_pendiente') !== null,
        ]);
    }

    public function guardar(): void
    {
        $usuario = $this->usuarioLogueado();
        // Solo el nombre completo: usuario y email no se pueden cambiar.
        $nombre = preg_replace('/\s+/u', ' ', Request::texto('nombre_completo'));
        $error = ValidadorRegistro::validarNombreCompleto($nombre);

        if ($error !== null) {
            Session::flash('error', $error);
        } else {
            $this->usuarios->actualizarNombreCompleto((int) $usuario['id'], $nombre);
            Session::flash('ok', 'Perfil actualizado.');
        }
        Redirect::to('perfil/editar');
    }

    /** Recibe la foto ya recortada por el editor (fetch) y responde JSON. */
    public function foto(): void
    {
        $id = Session::usuarioId();
        if ($id === null) {
            Json::error('Tu sesión expiró.', 401);
        }
        $usuario = $this->usuarios->buscarPorId($id);

        try {
            $ruta = $this->fotos->guardar(Request::archivo('foto_perfil'));
            $this->usuarios->actualizarFoto($id, $ruta);
            $this->fotos->borrar($usuario['foto_perfil']); // la anterior ya no se usa
            Json::responder(['ok' => true, 'foto' => Url::to($ruta)]);
        } catch (InvalidArgumentException $e) {
            Json::error($e->getMessage());
        }
    }

    // ════════════════════════════════════════════════
    //  Cambiar contraseña (contraseña actual + código por mail)
    // ════════════════════════════════════════════════

    public function password(): void
    {
        $usuario = $this->usuarioLogueado();
        $nueva = (string) Request::post('password_nueva', '');

        if (!password_verify((string) Request::post('password_actual', ''), $usuario['password'])) {
            Session::flash('error', 'La contraseña actual no es correcta.');
        } elseif ($error = ValidadorRegistro::validarPassword($nueva, (string) Request::post('password_repetir', ''))) {
            Session::flash('error', $error);
        } elseif (!$this->verificacion->enviar($usuario, VerificacionService::PASSWORD)) {
            Session::flash('error', 'No pudimos enviar el código a tu mail. Intentá de nuevo en unos minutos.');
        } else {
            // Se guarda hasheada en la sesión hasta que confirme el código.
            Session::set('password_pendiente', password_hash($nueva, PASSWORD_DEFAULT));
            Session::flash('ok', 'Te mandamos un código a tu mail para confirmar el cambio.');
        }
        Redirect::to('perfil/editar#password');
    }

    public function confirmarPassword(): void
    {
        $usuario = $this->usuarioLogueado();
        $hash = Session::get('password_pendiente');
        $codigo = preg_replace('/\D/', '', Request::texto('codigo'));
        $resultado = $hash ? $this->verificacion->verificar($usuario, $codigo, VerificacionService::PASSWORD)
                           : VerificacionService::EXPIRADO;

        if ($resultado !== VerificacionService::OK) {
            Session::flash('error', VerificacionService::MENSAJES[$resultado]);
        } else {
            $this->usuarios->actualizarPasswordHash((int) $usuario['id'], $hash);
            Session::borrar('password_pendiente');
            $this->correo->passwordCambiada($usuario);
            Session::flash('ok', 'Tu contraseña ha sido cambiada.');
        }
        Redirect::to('perfil/editar#password');
    }

    public function cancelarPassword(): void
    {
        $this->usuarioLogueado();
        Session::borrar('password_pendiente');
        Redirect::to('perfil/editar#password');
    }

    // ════════════════════════════════════════════════
    //  Eliminar cuenta (código por mail)
    // ════════════════════════════════════════════════

    public function eliminar(): void
    {
        $usuario = $this->usuarioLogueado();
        $this->render->renderiza('eliminarCuenta', [
            'nav_perfil' => true,
            'codigo_enviado' => Session::get('eliminar_pendiente') === true,
            'email' => $usuario['email'],
        ]);
    }

    public function solicitarEliminacion(): void
    {
        $usuario = $this->usuarioLogueado();
        if ($this->verificacion->enviar($usuario, VerificacionService::ELIMINAR)) {
            Session::set('eliminar_pendiente', true);
            Session::flash('ok', 'Te mandamos el código a tu mail.');
        } else {
            Session::flash('error', 'No pudimos enviar el código a tu mail. Intentá de nuevo en unos minutos.');
        }
        Redirect::to('perfil/eliminar');
    }

    public function confirmarEliminacion(): void
    {
        $usuario = $this->usuarioLogueado();
        $codigo = preg_replace('/\D/', '', Request::texto('codigo'));
        $resultado = $this->verificacion->verificar($usuario, $codigo, VerificacionService::ELIMINAR);

        if ($resultado !== VerificacionService::OK) {
            Session::flash('error', VerificacionService::MENSAJES[$resultado]);
            Redirect::to('perfil/eliminar');
        }

        $this->usuarios->eliminar((int) $usuario['id']);
        $this->fotos->borrar($usuario['foto_perfil']);
        $this->correo->cuentaEliminada($usuario);

        Session::cerrar();
        session_start(); // sesión nueva y vacía, solo para el mensaje
        Session::flash('info', 'Tu cuenta ha sido eliminada. ¡Gracias por jugar!');
        Redirect::to('');
    }

    // ── Auxiliar ──────────────────────────────────────

    private function usuarioLogueado(): array
    {
        $usuario = $this->usuarios->buscarPorId(Session::requerirLogin());
        if ($usuario === null) { // la cuenta ya no existe
            Session::cerrar();
            Redirect::to('login');
        }
        return $usuario;
    }
}
