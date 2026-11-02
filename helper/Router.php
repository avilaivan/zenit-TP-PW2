<?php
/**
 * Router: traduce /controller/metodo en una llamada real.
 *
 * El controller se obtiene desde Configuration con un método fábrica
 * "get{Nombre}Controller()". Así el Router no sabe cómo se construye
 * cada controller (inversión de dependencias).
 */
class Router
{
    private object $configuration;
    private string $controllerPorDefecto;
    private string $metodoPorDefecto;

    public function __construct(object $configuration, string $controllerPorDefecto, string $metodoPorDefecto)
    {
        $this->configuration = $configuration;
        $this->controllerPorDefecto = $controllerPorDefecto;
        $this->metodoPorDefecto = $metodoPorDefecto;
    }

    public function dispatch(string $nombreController, string $metodo): void
    {
        $controller = $this->obtenerController($nombreController);
        $metodo = $this->esMetodoPublico($controller, $metodo) ? $metodo : $this->metodoPorDefecto;
        $controller->{$metodo}();
    }

    private function obtenerController(string $nombre): object
    {
        $fabrica = 'get' . ucfirst(strtolower($nombre)) . 'Controller';

        if (!method_exists($this->configuration, $fabrica)) {
            $fabrica = 'get' . ucfirst($this->controllerPorDefecto) . 'Controller';
        }
        return $this->configuration->{$fabrica}();
    }

    /** Solo se pueden invocar métodos públicos que no sean "mágicos" (__construct, etc.). */
    private function esMetodoPublico(object $controller, string $metodo): bool
    {
        if ($metodo === '' || str_starts_with($metodo, '__') || !method_exists($controller, $metodo)) {
            return false;
        }
        return (new ReflectionMethod($controller, $metodo))->isPublic();
    }
}
