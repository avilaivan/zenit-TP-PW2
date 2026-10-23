<?php

namespace app\controller;

use Request;
use Redirect;

class RegistroController
{
    private $model;
    private $render;

    public function __construct($model, $render)
    {
        $this->model = $model;
        $this->render = $render;
    }

    public function show()
    {
        $this->render->renderiza("registro", []);
    }

    public function registrar()
    {
        $nombreUsuario = trim(Request::post('nombre_usuario', ''));
        $email = trim(Request::post('email', ''));
        $password = Request::post('password', '');
        $confirmarPassword = Request::post('confirmar_password', '');

        if (
            $nombreUsuario === '' ||
            $email === '' ||
            $password === '' ||
            $confirmarPassword === ''
        ) {
            $this->mostrarError("Todos los campos son obligatorios.");
            return;
        }

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $this->mostrarError("Ingresá un email válido.");
            return;
        }

        if (strlen($password) < 8) {
            $this->mostrarError(
                "La contraseña debe tener al menos 8 caracteres."
            );
            return;
        }

        if ($password !== $confirmarPassword) {
            $this->mostrarError("Las contraseñas no coinciden.");
            return;
        }

        if ($this->model->existeEmail($email)) {
            $this->mostrarError("Ese email ya está registrado.");
            return;
        }

        if ($this->model->existeNombreUsuario($nombreUsuario)) {
            $this->mostrarError("Ese nombre de usuario ya está ocupado.");
            return;
        }

        $this->model->registrar(
            $nombreUsuario,
            $email,
            $password
        );

        Redirect::to('/?registro=ok');
    }

    private function mostrarError($mensaje)
    {
        $this->render->renderiza("registro", [
            "error" => $mensaje
        ]);
    }
}
