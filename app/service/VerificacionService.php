<?php

namespace app\service;

use app\model\UsuarioModel;

/**
 * Códigos de 6 dígitos enviados por mail.
 * Cada código tiene un propósito: "registro", "password" o "eliminar",
 * y solo sirve para eso (un código de registro no borra la cuenta).
 */
class VerificacionService
{
    public const VIGENCIA_MINUTOS = 15;
    public const MAX_INTENTOS = 5;

    public const REGISTRO = 'registro';
    public const PASSWORD = 'password';
    public const ELIMINAR = 'eliminar';

    // Resultados posibles de verificar()
    public const OK = 'ok';
    public const INCORRECTO = 'incorrecto';
    public const EXPIRADO = 'expirado';
    public const BLOQUEADO = 'bloqueado';

    public const MENSAJES = [
        self::INCORRECTO => 'El código no es correcto. Revisalo e intentá de nuevo.',
        self::EXPIRADO => 'El código venció o no existe. Pedí uno nuevo.',
        self::BLOQUEADO => 'Demasiados intentos. Pedí un código nuevo.',
    ];

    public function __construct(
        private UsuarioModel $usuarios,
        private CorreoService $correo
    ) {
    }

    /**
     * Genera un código nuevo, lo guarda y lo manda por mail.
     * @return bool true si el mail salió.
     */
    public function enviar(array $usuario, string $proposito): bool
    {
        $codigo = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
        $expira = date('Y-m-d H:i:s', time() + self::VIGENCIA_MINUTOS * 60);
        $this->usuarios->guardarCodigo((int) $usuario['id'], $codigo, $proposito, $expira);

        return $this->correo->codigo($usuario, $codigo, $proposito, self::VIGENCIA_MINUTOS);
    }

    /** Valida el código; si es correcto lo consume (no se puede reutilizar). */
    public function verificar(array $usuario, string $codigo, string $proposito): string
    {
        if ((int) $usuario['codigo_intentos'] >= self::MAX_INTENTOS) {
            return self::BLOQUEADO;
        }
        if ($usuario['codigo_proposito'] !== $proposito
            || empty($usuario['codigo_expira'])
            || strtotime($usuario['codigo_expira']) < time()) {
            return self::EXPIRADO;
        }
        if (!hash_equals((string) $usuario['codigo_verificacion'], $codigo)) {
            $this->usuarios->sumarIntentoFallido((int) $usuario['id']);
            return self::INCORRECTO;
        }

        $this->usuarios->limpiarCodigo((int) $usuario['id']);
        return self::OK;
    }
}
