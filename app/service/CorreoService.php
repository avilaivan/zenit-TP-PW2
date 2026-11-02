<?php

namespace app\service;

use MailerInterface;

/**
 * Todos los mails de ZENIT, con el logo de la marca incrustado.
 *
 *  - código de verificación (registro, cambio de contraseña, baja de cuenta)
 *  - aviso de contraseña cambiada
 *  - aviso de cuenta eliminada
 */
class CorreoService
{
    /** Textos del mail de código según para qué se pidió. */
    private const MOTIVOS = [
        'registro' => ['¡Bienvenido a ZENIT!', 'Este es tu código para activar la cuenta:'],
        'password' => ['Cambio de contraseña', 'Pediste cambiar tu contraseña. Confirmalo con este código:'],
        'eliminar' => ['Eliminar tu cuenta', 'Pediste eliminar tu cuenta. Si estás seguro, ingresá este código:'],
    ];

    public function __construct(
        private MailerInterface $mailer,
        private MediaService $media
    ) {
    }

    public function codigo(array $usuario, string $codigo, string $proposito, int $minutos): bool
    {
        [$titulo, $intro] = self::MOTIVOS[$proposito];
        $cuerpo = '<p style="margin:0 0 6px">' . $intro . '</p>'
            . '<p style="font-size:38px;font-weight:900;letter-spacing:10px;color:#89F900;margin:22px 0">' . $codigo . '</p>'
            . '<p style="color:#9AA0A6;margin:0">Vence en ' . $minutos . ' minutos. Si no fuiste vos, ignorá este mail.</p>';

        return $this->enviar($usuario, "Tu código ZENIT: $codigo", $titulo, $cuerpo);
    }

    public function passwordCambiada(array $usuario): bool
    {
        $cuerpo = '<p style="margin:0 0 12px">Tu contraseña ha sido cambiada correctamente.</p>'
            . '<p style="color:#9AA0A6;margin:0">Si no fuiste vos, recuperá tu cuenta cuanto antes.</p>';
        return $this->enviar($usuario, 'Tu contraseña ha sido cambiada', 'Contraseña actualizada', $cuerpo);
    }

    public function cuentaEliminada(array $usuario): bool
    {
        $cuerpo = '<p style="margin:0 0 12px">Tu cuenta ha sido eliminada junto con tus estadísticas y partidas.</p>'
            . '<p style="color:#9AA0A6;margin:0">Gracias por jugar. Cuando quieras, podés volver a registrarte.</p>';
        return $this->enviar($usuario, 'Tu cuenta ha sido eliminada', 'Cuenta eliminada', $cuerpo);
    }

    // ── Plantilla común ───────────────────────────────

    private function enviar(array $usuario, string $asunto, string $titulo, string $cuerpo): bool
    {
        $html = $this->plantilla(htmlspecialchars($usuario['nombre_usuario']), $titulo, $cuerpo);
        return $this->mailer->enviar($usuario['email'], $asunto, $html, ['logo' => $this->media->archivoLogo()]);
    }

    /** HTML con tablas y estilos en línea: es lo que mejor se ve en Gmail/Outlook. */
    private function plantilla(string $nombre, string $titulo, string $cuerpo): string
    {
        $anio = date('Y');
        return <<<HTML
        <!DOCTYPE html>
        <html lang="es"><body style="margin:0;padding:0;background:#0B0C0E">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#0B0C0E;padding:32px 12px">
          <tr><td align="center">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;background:#121417;border:1px solid #2A2E34;border-radius:18px;font-family:Arial,Helvetica,sans-serif;color:#F2F3F5">
              <tr><td style="padding:30px 32px 6px">
                <img src="cid:logo" alt="ZENIT" width="150" style="display:block;width:150px;height:auto;border:0">
              </td></tr>
              <tr><td style="height:4px;padding:0 32px"><div style="height:3px;width:64px;background:#89F900;border-radius:3px"></div></td></tr>
              <tr><td style="padding:22px 32px 30px;font-size:15px;line-height:1.55">
                <h1 style="margin:0 0 14px;font-size:22px;font-style:italic;font-weight:900;text-transform:uppercase">{$titulo}</h1>
                <p style="margin:0 0 14px">Hola <b>{$nombre}</b>,</p>
                {$cuerpo}
              </td></tr>
              <tr><td style="padding:16px 32px;border-top:1px solid #2A2E34;color:#6B7178;font-size:12px">
                ZENIT · Llegá a tu zenit · {$anio}
              </td></tr>
            </table>
          </td></tr>
        </table>
        </body></html>
        HTML;
    }
}
