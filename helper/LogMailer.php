<?php
/**
 * "Envía" mails escribiéndolos en log/correos.log.
 * Solo para pruebas sin conexión (mail_modo = "log" en config.ini).
 */
class LogMailer implements MailerInterface
{
    public function enviar(string $para, string $asunto, string $html, array $imagenes = []): bool
    {
        $texto = trim(preg_replace('/\s+/', ' ', strip_tags($html)));
        Log::enArchivo('correos.log', sprintf("──── %s\nPara: %s\nAsunto: %s\n%s\n", date('Y-m-d H:i:s'), $para, $asunto, $texto));
        return true;
    }
}
