<?php

namespace app\controller;

use MustacheRender;
use Session;

/**
 * Secciones que se harán más adelante (Ranking, Panel de rol, ZENIT+).
 * A propósito no muestran ninguna información: solo "EN MANTENIMIENTO".
 */
class MantenimientoController
{
    public function __construct(
        private MustacheRender $render,
        private string $titulo,
        private string $claveMenu // para marcar activa la pestaña del menú
    ) {
    }

    public function show(): void
    {
        Session::requerirLogin();
        $this->render->renderiza('mantenimiento', [
            'titulo' => $this->titulo,
            $this->claveMenu => true,
        ]);
    }
}
