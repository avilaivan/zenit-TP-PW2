<?php

namespace app\controller;

use Redirect;
use Request;

class LoginController
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
        $this->render->renderiza("login", [
            "registro_exitoso" => Request::get('registro') === 'ok',
            "login_error" => Request::get('login_error') === '1'
        ]);
    }

    public function login()
    {
        $email = trim(Request::post('email', ''));
        $password = Request::post('password', '');

        if ($email === '' || $password === '') {
            Redirect::to('/?login_error=1');
        }

        $usuario = $this->model->autenticar(
            $email,
            $password
        );

        if ($usuario === null) {
            Redirect::to('/?login_error=1');
        }

        session_regenerate_id(true);

        $_SESSION['usuario_id'] = $usuario['id'];
        $_SESSION['usuario'] = $usuario['nombre_usuario'];
        $_SESSION['usuario_email'] = $usuario['email'];

        Redirect::to('/home/show');
    }

    public function logout()
    {
        $_SESSION = [];
        session_destroy();

        Redirect::to('/');
    }
}

