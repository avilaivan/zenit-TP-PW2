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

        return $this->database->queryOnePrepared(
                $sql,
                [$email]
            ) !== null;
    }

    public function existeNombreUsuario($nombreUsuario)
    {
        $sql = "SELECT id FROM usuarios WHERE nombre_usuario = ?";

        return $this->database->queryOnePrepared(
                $sql,
                [$nombreUsuario]
            ) !== null;
    }

    public function registrar($nombreUsuario, $email, $password)
    {
        $passwordHash = password_hash(
            $password,
            PASSWORD_DEFAULT
        );

        $sql = "INSERT INTO usuarios
                (nombre_usuario, email, password)
                VALUES (?, ?, ?)";

        return $this->database->executePrepared(
            $sql,
            [$nombreUsuario, $email, $passwordHash]
        );
    }
}
