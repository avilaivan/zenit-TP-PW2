<?php

namespace app\model;

class LoginModel
{
    private $database;

    public function __construct($database)
    {
        $this->database = $database;
    }

    public function autenticar($email, $password)
    {
        $sql = "SELECT id, nombre_usuario, email, password
                FROM usuarios
                WHERE email = ?";

        $usuario = $this->database->queryOnePrepared(
            $sql,
            [$email]
        );

        if ($usuario === null) {
            return null;
        }

        if (!password_verify($password, $usuario['password'])) {
            return null;
        }

        unset($usuario['password']);

        return $usuario;
    }
}

