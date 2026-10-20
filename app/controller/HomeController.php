<?php

namespace app\controller;

use Request;

class HomeController
{

    private $render;

    public function __construct($render)
    {
        $this->render = $render;
    }

    public function show()
    {
        //$this->render->renderiza("home", []);
        echo "Hola";
    }

}
