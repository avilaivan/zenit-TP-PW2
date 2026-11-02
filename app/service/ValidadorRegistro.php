<?php

namespace app\service;

use app\model\UsuarioModel;

/**
 * Validaciones de cuenta (registro y edición de perfil).
 * Toda la validación se hace en el servidor, como pide el TP.
 */
class ValidadorRegistro
{
    public const SEXOS = ['masculino', 'femenino', 'no_informa'];

    public function __construct(
        private UsuarioModel $usuarios,
        private PaisService $paises
    ) {
    }

    /**
     * @param array $d datos del formulario (el país se corrige al nombre oficial de la lista)
     * @return string|null mensaje del primer error, o null si está todo bien.
     */
    public function validar(array &$d): ?string
    {
        foreach (['nombre_completo', 'nombre_usuario', 'email', 'password', 'anio_nacimiento', 'sexo', 'pais', 'ciudad'] as $campo) {
            if (($d[$campo] ?? '') === '') {
                return 'Completá todos los campos.';
            }
        }

        if ($error = self::validarNombreCompleto($d['nombre_completo'])) {
            return $error;
        }
        if ($error = $this->validarNombreUsuario($d['nombre_usuario'])) {
            return $error;
        }
        if (!filter_var($d['email'], FILTER_VALIDATE_EMAIL)) {
            return 'Ingresá un email válido.';
        }
        if ($this->usuarios->existeEmail($d['email'])) {
            return 'Ese email ya está registrado.';
        }
        if ($error = self::validarPassword($d['password'], $d['confirmar_password'] ?? '')) {
            return $error;
        }

        $anio = (int) $d['anio_nacimiento'];
        if (!ctype_digit((string) $d['anio_nacimiento']) || $anio < 1900 || $anio > (int) date('Y')) {
            return 'Ingresá un año de nacimiento válido.';
        }
        if (!in_array($d['sexo'], self::SEXOS, true)) {
            return 'Elegí una opción de sexo válida.';
        }
        return $this->validarUbicacion($d);
    }

    /** Nombre y apellido: no es único, solo se controla el largo y que tenga letras. */
    public static function validarNombreCompleto(string $nombre): ?string
    {
        $largo = mb_strlen($nombre);
        if ($largo < 3 || $largo > 150 || !preg_match('/\p{L}/u', $nombre)) {
            return 'Ingresá tu nombre completo (entre 3 y 150 caracteres).';
        }
        return null;
    }

    /** Formato y unicidad del usuario (se elige una sola vez, al registrarse). */
    public function validarNombreUsuario(string $nombre): ?string
    {
        if (!preg_match('/^[A-Za-z0-9_.]{3,20}$/', $nombre)) {
            return 'El usuario debe tener entre 3 y 20 caracteres (letras, números, punto o guion bajo).';
        }
        if ($this->usuarios->existeNombreUsuario($nombre)) {
            return 'Ese nombre de usuario ya está ocupado.';
        }
        return null;
    }

    public static function validarPassword(string $password, string $repetida): ?string
    {
        if (strlen($password) < 8) {
            return 'La contraseña debe tener al menos 8 caracteres.';
        }
        if ($password !== $repetida) {
            return 'Las contraseñas no coinciden.';
        }
        return null;
    }

    /**
     * País (de la lista oficial) y ciudad obligatorios; las coordenadas del mapa
     * son opcionales pero deben tener sentido. Deja el país con su nombre oficial.
     */
    public function validarUbicacion(array &$d): ?string
    {
        if (($d['pais'] ?? '') === '' || ($d['ciudad'] ?? '') === '') {
            return 'Completá país y ciudad.';
        }
        $pais = $this->paises->nombreValido($d['pais']);
        if ($pais === null) {
            return 'Elegí un país de la lista.';
        }
        $d['pais'] = $pais;
        if (mb_strlen($d['ciudad']) > 80) {
            return 'El nombre de la ciudad es demasiado largo.';
        }

        $lat = $d['latitud'] ?? null;
        $lon = $d['longitud'] ?? null;
        if ($lat === null && $lon === null) {
            return null;
        }
        if (!is_numeric($lat) || !is_numeric($lon) || abs((float) $lat) > 90 || abs((float) $lon) > 180) {
            return 'La ubicación del mapa no es válida.';
        }
        return null;
    }
}
