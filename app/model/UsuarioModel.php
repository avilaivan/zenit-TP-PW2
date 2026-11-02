<?php

namespace app\model;

use MyDatabase;

/**
 * Consultas sobre la tabla "usuario" (cuenta, códigos y perfil).
 * Las estadísticas de juego están en EstadisticaModel.
 */
class UsuarioModel
{
    public function __construct(private MyDatabase $db)
    {
    }

    // ── Búsquedas ─────────────────────────────────────

    public function buscarPorId(int $id): ?array
    {
        return $this->db->queryOne('SELECT * FROM usuario WHERE id = ?', [$id]);
    }

    /** El login acepta nombre de usuario o email. */
    public function buscarParaLogin(string $usuarioOEmail): ?array
    {
        return $this->db->queryOne(
            'SELECT * FROM usuario WHERE nombre_usuario = ? OR email = ?',
            [$usuarioOEmail, $usuarioOEmail]
        );
    }

    public function buscarPorNombreUsuario(string $nombreUsuario): ?array
    {
        return $this->db->queryOne('SELECT * FROM usuario WHERE nombre_usuario = ?', [$nombreUsuario]);
    }

    public function existeEmail(string $email): bool
    {
        return $this->db->queryOne('SELECT id FROM usuario WHERE email = ?', [$email]) !== null;
    }

    /** @param int|null $excepto id a ignorar (el propio usuario al editar su perfil) */
    public function existeNombreUsuario(string $nombreUsuario): bool
    {
        return $this->db->queryOne('SELECT id FROM usuario WHERE nombre_usuario = ?', [$nombreUsuario]) !== null;
    }

    // ── Alta y códigos ────────────────────────────────

    /** Crea la cuenta INACTIVA (se activa con el código del mail) y devuelve su id. */
    public function crear(array $datos): int
    {
        $this->db->execute(
            'INSERT INTO usuario
                (nombre_completo, nombre_usuario, email, password, anio_nacimiento, sexo, pais, ciudad, latitud, longitud, activo)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)',
            [
                $datos['nombre_completo'],
                $datos['nombre_usuario'],
                $datos['email'],
                password_hash($datos['password'], PASSWORD_DEFAULT),
                $datos['anio_nacimiento'],
                $datos['sexo'],
                $datos['pais'],
                $datos['ciudad'],
                $datos['latitud'],
                $datos['longitud'],
            ]
        );
        return $this->db->lastInsertId();
    }

    public function guardarCodigo(int $id, string $codigo, string $proposito, string $expira): void
    {
        $this->db->execute(
            'UPDATE usuario
             SET codigo_verificacion = ?, codigo_proposito = ?, codigo_expira = ?, codigo_intentos = 0
             WHERE id = ?',
            [$codigo, $proposito, $expira, $id]
        );
    }

    public function sumarIntentoFallido(int $id): void
    {
        $this->db->execute('UPDATE usuario SET codigo_intentos = codigo_intentos + 1 WHERE id = ?', [$id]);
    }

    public function limpiarCodigo(int $id): void
    {
        $this->db->execute(
            'UPDATE usuario
             SET codigo_verificacion = NULL, codigo_proposito = NULL, codigo_expira = NULL, codigo_intentos = 0
             WHERE id = ?',
            [$id]
        );
    }

    public function activar(int $id): void
    {
        $this->db->execute('UPDATE usuario SET activo = 1 WHERE id = ?', [$id]);
    }

    // ── Perfil ────────────────────────────────────────

    /** Datos editables desde "Editar perfil" (el email nunca cambia). */
    /** Lo único editable del perfil (además de foto y contraseña): usuario y email son fijos. */
    public function actualizarNombreCompleto(int $id, string $nombreCompleto): void
    {
        $this->db->execute('UPDATE usuario SET nombre_completo = ? WHERE id = ?', [$nombreCompleto, $id]);
    }

    public function actualizarFoto(int $id, string $ruta): void
    {
        $this->db->execute('UPDATE usuario SET foto_perfil = ? WHERE id = ?', [$ruta, $id]);
    }

    /** Recibe la contraseña YA hasheada (se hashea al pedir el cambio, antes del código). */
    public function actualizarPasswordHash(int $id, string $hash): void
    {
        $this->db->execute('UPDATE usuario SET password = ? WHERE id = ?', [$hash, $id]);
    }

    /** Borra la cuenta. Estadísticas y partidas se borran solas (ON DELETE CASCADE). */
    public function eliminar(int $id): void
    {
        $this->db->execute('DELETE FROM usuario WHERE id = ?', [$id]);
    }
}
