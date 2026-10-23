<?php

namespace app\controller;

use Redirect;

class HomeController
{
    private $render;

    public function __construct($render)
    {
        $this->render = $render;
    }

    public function show()
    {
        if (!isset($_SESSION['usuario_id'])) {
            Redirect::to('/');
            return;
        }

        $datos = [
            'nombre_usuario' => $_SESSION['usuario'],
            'email' => $_SESSION['usuario_email'],
            'puntaje' => 0
        ];

        $this->render->renderiza('home', $datos);
    }
}

