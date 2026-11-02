<?php
/**
 * Contrato para enviar mails.
 *
 * Los servicios dependen de esta interfaz y no de una implementación
 * concreta (principio de inversión de dependencias): se puede usar
 * SmtpMailer (envío real) o LogMailer (pruebas) sin tocar el resto del código.
 */
interface MailerInterface
{
    /**
     * @param array $imagenes imágenes incrustadas: ['logo' => '/ruta/logo.png'].
     *                        En el HTML se usan como <img src="cid:logo">.
     * @return bool true si el mail se envió correctamente.
     */
    public function enviar(string $para, string $asunto, string $html, array $imagenes = []): bool;
}
