<?php
/**
 * Cliente SMTP mínimo, sin librerías externas.
 *
 * Funciona con Gmail (smtp.gmail.com, puerto 587 + TLS) usando una
 * "contraseña de aplicación". Requiere la extensión openssl de PHP
 * (viene activada en XAMPP).
 *
 * Conversación SMTP:
 *   EHLO → STARTTLS → EHLO → AUTH LOGIN → MAIL FROM → RCPT TO → DATA → QUIT
 *
 * Las imágenes (el logo) viajan dentro del mail como partes "inline"
 * (multipart/related), así se ven aunque el sitio esté en localhost.
 */
class SmtpMailer implements MailerInterface
{
    private const TIMEOUT = 20;

    /** @var resource|null */
    private $socket = null;

    /** Último error (para mostrarlo en el script de prueba). */
    public string $ultimoError = '';

    public function __construct(
        private string $host,
        private int $puerto,
        private string $usuario,
        private string $clave,
        private string $remitente,
        private string $nombreRemitente,
        private string $seguridad = 'tls',   // "tls" (587) o "ssl" (465)
        private bool $verificarCertificado = true
    ) {
    }

    public function enviar(string $para, string $asunto, string $html, array $imagenes = []): bool
    {
        try {
            $this->conectar();
            $this->autenticar();
            $this->comando("MAIL FROM:<{$this->remitente}>", [250]);
            $this->comando("RCPT TO:<{$para}>", [250, 251]);
            $this->comando('DATA', [354]);
            $this->comando($this->armarMensaje($para, $asunto, $html, $imagenes) . "\r\n.", [250]);
            $this->comando('QUIT', [221]);
            return true;
        } catch (RuntimeException $e) {
            $this->ultimoError = $e->getMessage();
            Log::error('SMTP: ' . $e->getMessage());
            return false;
        } finally {
            if (is_resource($this->socket)) {
                fclose($this->socket);
            }
            $this->socket = null;
        }
    }

    // ── Conexión ──────────────────────────────────────

    private function conectar(): void
    {
        $contexto = stream_context_create(['ssl' => [
            'verify_peer' => $this->verificarCertificado,
            'verify_peer_name' => $this->verificarCertificado,
            'allow_self_signed' => !$this->verificarCertificado,
        ]]);
        $protocolo = $this->seguridad === 'ssl' ? 'ssl://' : 'tcp://';

        $this->socket = @stream_socket_client(
            $protocolo . $this->host . ':' . $this->puerto,
            $codigoError,
            $mensajeError,
            self::TIMEOUT,
            STREAM_CLIENT_CONNECT,
            $contexto
        );
        if (!$this->socket) {
            throw new RuntimeException("No se pudo conectar a {$this->host}:{$this->puerto} ($mensajeError)");
        }
        stream_set_timeout($this->socket, self::TIMEOUT);

        $this->leerRespuesta([220]);
        $this->comando('EHLO zenit.local', [250]);

        if ($this->seguridad === 'tls') {
            $this->comando('STARTTLS', [220]);
            if (!@stream_socket_enable_crypto($this->socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
                throw new RuntimeException('No se pudo iniciar TLS (¿certificados de PHP? ver README → Mails).');
            }
            $this->comando('EHLO zenit.local', [250]);
        }
    }

    private function autenticar(): void
    {
        $this->comando('AUTH LOGIN', [334]);
        $this->comando(base64_encode($this->usuario), [334]);
        $this->comando(base64_encode($this->clave), [235]);
    }

    // ── Armado del mensaje (MIME) ─────────────────────

    private function armarMensaje(string $para, string $asunto, string $html, array $imagenes): string
    {
        $separador = 'zenit_' . bin2hex(random_bytes(8));
        $cabeceras = [
            'Date: ' . date('r'),
            'From: ' . $this->codificar($this->nombreRemitente) . " <{$this->remitente}>",
            "To: <{$para}>",
            'Subject: ' . $this->codificar($asunto),
            'Message-ID: <' . bin2hex(random_bytes(12)) . '@zenit.local>',
            'MIME-Version: 1.0',
            "Content-Type: multipart/related; boundary=\"$separador\"",
        ];

        $partes = [$this->parte('text/html; charset=UTF-8', $html)];
        foreach ($imagenes as $cid => $ruta) {
            if (is_file($ruta)) {
                $tipo = mime_content_type($ruta) ?: 'image/png';
                $partes[] = $this->parte($tipo, file_get_contents($ruta), [
                    "Content-ID: <$cid>",
                    'Content-Disposition: inline; filename="' . basename($ruta) . '"',
                ]);
            }
        }

        $cuerpo = '';
        foreach ($partes as $parte) {
            $cuerpo .= "--$separador\r\n$parte\r\n";
        }
        return implode("\r\n", $cabeceras) . "\r\n\r\n" . $cuerpo . "--$separador--";
    }

    /** Una parte MIME en base64 (líneas de 76 caracteres). */
    private function parte(string $tipo, string $contenido, array $extras = []): string
    {
        $cabeceras = array_merge(["Content-Type: $tipo", 'Content-Transfer-Encoding: base64'], $extras);
        return implode("\r\n", $cabeceras) . "\r\n\r\n" . rtrim(chunk_split(base64_encode($contenido)));
    }

    /** Texto con acentos en cabeceras (=?UTF-8?B?...?=). */
    private function codificar(string $texto): string
    {
        return '=?UTF-8?B?' . base64_encode($texto) . '?=';
    }

    // ── Lectura / escritura del socket ────────────────

    /** Envía una línea y verifica que el servidor responda con un código esperado. */
    private function comando(string $linea, array $codigosOk): string
    {
        fwrite($this->socket, $linea . "\r\n");
        return $this->leerRespuesta($codigosOk);
    }

    private function leerRespuesta(array $codigosOk): string
    {
        $respuesta = '';
        // Las respuestas multilínea tienen "250-..." y la última "250 ..."
        while (($linea = fgets($this->socket, 515)) !== false) {
            $respuesta .= $linea;
            if (isset($linea[3]) && $linea[3] === ' ') {
                break;
            }
        }
        $codigo = (int) substr($respuesta, 0, 3);
        if (!in_array($codigo, $codigosOk, true)) {
            throw new RuntimeException('El servidor respondió: ' . trim($respuesta ?: 'sin respuesta'));
        }
        return $respuesta;
    }
}
