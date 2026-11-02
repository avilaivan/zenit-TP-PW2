<?php

namespace app\controller;

use app\model\UsuarioModel;
use app\service\ValidadorRegistro;
use app\service\VerificacionService;
use MustacheRender;
use Redirect;
use Request;
use Session;

/**
 * Registro de cuenta + verificación por código enviado al mail.
 *
 * Campos: nombre completo, usuario, email, contraseña (×2), año de nacimiento, sexo, país y ciudad (mapa).
 * La foto de perfil se carga después, desde el perfil.
 *
 *  /registro            → formulario
 *  /registro/registrar  → crea la cuenta inactiva y manda el código
 *  /registro/verificar  → pantalla para ingresar el código
 *  /registro/confirmar  → valida el código y activa la cuenta
 *  /registro/reenviar   → manda un código nuevo
 */
class RegistroController
{
    private const ESPERA_REENVIO = 45; // segundos entre reenvíos

    public function __construct(
        private MustacheRender $render,
        private UsuarioModel $usuarios,
        private ValidadorRegistro $validador,
        private VerificacionService $verificacion
    ) {
    }

    public function show(): void
    {
        if (Session::estaLogueado()) {
            Redirect::to('');
        }
        // "form" no puede ir vacío: en Mustache un array vacío oculta la sección.
        $this->render->renderiza('registro', ['pantalla_auth' => true, 'form' => ['nuevo' => true]]);
    }

    public function registrar(): void
    {
        $datos = $this->leerFormulario();

        $error = $this->validador->validar($datos);
        if ($error !== null) {
            $this->mostrarFormularioConError($error, $datos);
            return;
        }

        $id = $this->usuarios->crear($datos);
        $this->enviarCodigo($this->usuarios->buscarPorId($id));
        Redirect::to('registro/verificar');
    }

    public function verificar(): void
    {
        $usuario = $this->usuarioPendiente();
        $this->render->renderiza('verificar', [
            'pantalla_auth' => true,
            'email_oculto' => self::ocultarEmail($usuario['email']),
            'minutos' => VerificacionService::VIGENCIA_MINUTOS,
        ]);
    }

    public function confirmar(): void
    {
        $usuario = $this->usuarioPendiente();
        $codigo = preg_replace('/\D/', '', Request::texto('codigo'));
        $resultado = $this->verificacion->verificar($usuario, $codigo, VerificacionService::REGISTRO);

        if ($resultado !== VerificacionService::OK) {
            Session::flash('error', VerificacionService::MENSAJES[$resultado]);
            Redirect::to('registro/verificar');
        }

        $this->usuarios->activar((int) $usuario['id']);
        Session::borrar('verificar_id');
        Session::iniciar($usuario);
        Session::flash('ok', '¡Cuenta verificada! Bienvenido a ZENIT, ' . $usuario['nombre_usuario'] . '.');
        Redirect::to(Session::tomarDestino());
    }

    public function reenviar(): void
    {
        $usuario = $this->usuarioPendiente();
        $espera = self::ESPERA_REENVIO - (time() - (int) Session::get('ultimo_envio', 0));

        if ($espera > 0) {
            Session::flash('error', "Esperá $espera segundos para pedir otro código.");
        } elseif ($this->enviarCodigo($usuario)) {
            Session::flash('ok', 'Te mandamos un código nuevo.');
        }
        Redirect::to('registro/verificar');
    }

    // ── Privados ──────────────────────────────────────

    private function leerFormulario(): array
    {
        $latitud = Request::texto('latitud');
        $longitud = Request::texto('longitud');
        return [
            'nombre_completo' => preg_replace('/\s+/u', ' ', Request::texto('nombre_completo')),
            'nombre_usuario' => Request::texto('nombre_usuario'),
            'email' => strtolower(Request::texto('email')),
            'password' => (string) Request::post('password', ''),
            'confirmar_password' => (string) Request::post('confirmar_password', ''),
            'anio_nacimiento' => Request::texto('anio_nacimiento'),
            'sexo' => Request::texto('sexo'),
            'pais' => Request::texto('pais'),
            'ciudad' => Request::texto('ciudad'),
            'latitud' => $latitud !== '' ? $latitud : null,
            'longitud' => $longitud !== '' ? $longitud : null,
        ];
    }

    /** Manda el código y deja al usuario "pendiente de verificar" en la sesión. */
    private function enviarCodigo(array $usuario): bool
    {
        Session::set('verificar_id', (int) $usuario['id']);
        Session::set('ultimo_envio', time());

        $enviado = $this->verificacion->enviar($usuario, VerificacionService::REGISTRO);
        if (!$enviado) {
            Session::flash('error', 'No pudimos enviar el mail. Probá "Reenviar código" en unos minutos.');
        }
        return $enviado;
    }

    /** Usuario que está en proceso de verificación (o vuelve al login). */
    private function usuarioPendiente(): array
    {
        $id = Session::get('verificar_id');
        $usuario = $id ? $this->usuarios->buscarPorId((int) $id) : null;

        if ($usuario === null || (int) $usuario['activo'] === 1) {
            Session::borrar('verificar_id');
            Redirect::to('login');
        }
        return $usuario;
    }

    /** "valentin@gmail.com" → "va•••••@gmail.com" */
    private static function ocultarEmail(string $email): string
    {
        [$nombre, $dominio] = explode('@', $email) + [1 => ''];
        return substr($nombre, 0, 2) . str_repeat('•', max(3, strlen($nombre) - 2)) . '@' . $dominio;
    }

    private function mostrarFormularioConError(string $error, array $datos): void
    {
        unset($datos['password'], $datos['confirmar_password']); // nunca se devuelven
        $datos['sexo_' . $datos['sexo']] = true;                  // para re-seleccionar el <select>
        $this->render->renderiza('registro', ['pantalla_auth' => true, 'error' => $error, 'form' => $datos]);
    }
}
