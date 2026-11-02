<?php
/**
 * Envoltorio de $_SESSION: usuario logueado y mensajes "flash"
 * (se muestran una sola vez después de un redirect).
 */
class Session
{
    // ── Usuario logueado ──────────────────────────────

    public static function iniciar(array $usuario): void
    {
        session_regenerate_id(true);
        $_SESSION['usuario_id'] = (int) $usuario['id'];
    }

    public static function usuarioId(): ?int
    {
        return isset($_SESSION['usuario_id']) ? (int) $_SESSION['usuario_id'] : null;
    }

    public static function estaLogueado(): bool
    {
        return self::usuarioId() !== null;
    }

    /**
     * Corta la ejecución y manda al login si no hay sesión.
     * Recuerda la página pedida para volver ahí después de entrar
     * (ej: tocó JUGAR sin cuenta → login → juego).
     */
    public static function requerirLogin(string $mensaje = 'Iniciá sesión o creá una cuenta para continuar.'): int
    {
        $id = self::usuarioId();
        if ($id === null) {
            if (!Request::esPost()) { // un formulario a medias no se repite después del login
                self::set('volver', self::rutaActual());
            }
            self::flash('info', $mensaje);
            Redirect::to('login');
        }
        return $id;
    }

    /** Ruta a la que hay que volver después del login ('' = lobby). Se usa una sola vez. */
    public static function tomarDestino(): string
    {
        $destino = (string) self::get('volver', '');
        self::borrar('volver');
        return $destino;
    }

    /** Ruta pedida, relativa al proyecto (ej: "juego" o "perfil/ver?u=demo"). */
    private static function rutaActual(): string
    {
        $uri = $_SERVER['REQUEST_URI'] ?? '/';
        $base = Url::base();
        if ($base !== '' && str_starts_with($uri, $base)) {
            $uri = substr($uri, strlen($base));
        }
        return ltrim($uri, '/'); // Redirect::to siempre la antepone a la URL base: no se puede salir del sitio
    }

    public static function cerrar(): void
    {
        $_SESSION = [];
        session_destroy();
    }

    // ── Valores genéricos ─────────────────────────────

    public static function set(string $clave, $valor): void
    {
        $_SESSION[$clave] = $valor;
    }

    public static function get(string $clave, $porDefecto = null)
    {
        return $_SESSION[$clave] ?? $porDefecto;
    }

    public static function borrar(string $clave): void
    {
        unset($_SESSION[$clave]);
    }

    // ── Mensajes flash ────────────────────────────────

    /** @param string $tipo "ok" | "error" | "info" */
    public static function flash(string $tipo, string $mensaje): void
    {
        $_SESSION['flash'] = ['tipo' => $tipo, 'mensaje' => $mensaje];
    }

    public static function tomarFlash(): ?array
    {
        $flash = $_SESSION['flash'] ?? null;
        unset($_SESSION['flash']);
        return $flash;
    }
}
