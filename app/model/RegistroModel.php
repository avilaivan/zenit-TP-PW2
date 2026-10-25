<?php

namespace app\model;

class RegistroModel
{
    private $database;

    public function __construct($database)
    {
        $this->database = $database;
    }

    public function existeEmail($email)
    {
        $sql = "SELECT id FROM usuarios WHERE email = ?";
        return $this->database->queryOnePrepared($sql, [$email]) !== null;
    }

    public function existeNombreUsuario($nombreUsuario)
    {
        $sql = "SELECT id FROM usuarios WHERE nombre_usuario = ?";
        return $this->database->queryOnePrepared($sql, [$nombreUsuario]) !== null;
    }

    public function registrar($datos)
    {
        $passwordHash = password_hash($datos['password'], PASSWORD_DEFAULT);

        $sql = "INSERT INTO usuarios
                (nombre_usuario, email, password, nombre_completo,
                 anio_nacimiento, sexo, pais, ciudad, latitud,
                 longitud, foto_perfil)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

        $parametros = [
            $datos['nombre_usuario'],
            $datos['email'],
            $passwordHash,
            $datos['nombre_completo'],
            $datos['anio_nacimiento'],
            $datos['sexo'],
            $datos['pais'],
            $datos['ciudad'],
            $datos['latitud'],
            $datos['longitud'],
            $datos['foto_perfil']
        ];

        return $this->database->executePrepared($sql, $parametros);
    }
}