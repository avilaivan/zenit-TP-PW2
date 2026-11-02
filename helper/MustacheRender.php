<?php
/**
 * Renderiza vistas Mustache dentro del layout (header + vista + footer).
 *
 * Los datos "globales" que necesita el layout (URL base, usuario del menú,
 * mensaje flash) los inyecta quien construye el render (Configuration),
 * así las vistas no dependen de la sesión directamente.
 */
require_once __DIR__ . '/../vendor/mustache/Mustache/Autoloader.php';
Mustache_Autoloader::register(__DIR__ . '/../vendor/mustache');

class MustacheRender
{
    private Mustache_Engine $mustache;

    /** @var callable Devuelve los datos globales del layout. */
    private $datosGlobales;

    public function __construct(callable $datosGlobales)
    {
        $carpetaVistas = dirname(__DIR__) . '/app/view';
        $this->mustache = new Mustache_Engine([
            'loader' => new Mustache_Loader_FilesystemLoader($carpetaVistas, ['extension' => '.mustache']),
            'partials_loader' => new Mustache_Loader_FilesystemLoader($carpetaVistas, ['extension' => '.mustache']),
        ]);
        $this->datosGlobales = $datosGlobales;
    }

    /**
     * @param string $vista  nombre del archivo sin "View.mustache" (ej: "perfil")
     * @param array  $datos  datos propios de la vista
     */
    public function renderiza(string $vista, array $datos = []): void
    {
        $datos = array_merge(($this->datosGlobales)(), $datos);

        echo $this->mustache->render('layout/header', $datos);
        echo $this->mustache->render($vista . 'View', $datos);
        echo $this->mustache->render('layout/footer', $datos);
    }
}
