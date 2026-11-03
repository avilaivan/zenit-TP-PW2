<?php

namespace app;

use app\controller\HomeController;
use app\controller\JuegoController;
use app\controller\LoginController;
use app\controller\MantenimientoController;
use app\controller\PerfilController;
use app\controller\RegistroController;
use app\model\CategoriaModel;
use app\model\EstadisticaModel;
use app\model\PartidaModel;
use app\model\PreguntaModel;
use app\model\PreguntaVistaModel;
use app\model\ReporteModel;
use app\model\UsuarioModel;
use app\service\CorreoService;
use app\service\EstadoJuego;
use app\service\FotoPerfilService;
use app\service\JuegoService;
use app\service\MediaService;
use app\service\NivelService;
use app\service\PaisService;
use app\service\PerfilService;
use app\service\ReporteService;
use app\service\RuletaService;
use app\service\ValidadorRegistro;
use app\service\VerificacionService;
use LogMailer;
use MailerInterface;
use MustacheRender;
use MyDatabase;
use Router;
use Session;
use SmtpMailer;
use Url;

require_once __DIR__ . '/../helper/Autoloader.php';

/**
 * Contenedor de dependencias: el ÚNICO lugar que sabe cómo se arma cada objeto.
 *
 * Los controllers y servicios reciben lo que necesitan por constructor
 * (inyección de dependencias), por eso son fáciles de leer y de cambiar.
 * El Router busca acá los métodos "get{Nombre}Controller()".
 */
class Configuration
{
    private array $config;
    private ?MyDatabase $database = null;
    private ?MediaService $media = null;

    public function __construct()
    {
        $archivo = __DIR__ . '/../config/config.ini';
        if (!file_exists($archivo)) {
            exit('Falta config/config.ini. Copiá config/config.example.ini y completalo.');
        }
        $this->config = parse_ini_file($archivo);
    }

    public function getRouter(): Router
    {
        return new Router($this, 'home', 'show');
    }

    // ════════════════════════════════════════════════
    //  Controllers (una URL /nombre → getNombreController)
    // ════════════════════════════════════════════════

    public function getHomeController(): HomeController
    {
        return new HomeController($this->getRender(), $this->getUsuarioModel(), $this->getPerfilService(),
            $this->getJuegoService());
    }

    public function getLoginController(): LoginController
    {
        return new LoginController($this->getRender(), $this->getUsuarioModel(), $this->getVerificacionService());
    }

    public function getRegistroController(): RegistroController
    {
        return new RegistroController($this->getRender(), $this->getUsuarioModel(),
            new ValidadorRegistro($this->getUsuarioModel(), new PaisService()), $this->getVerificacionService());
    }

    public function getPerfilController(): PerfilController
    {
        return new PerfilController($this->getRender(), $this->getUsuarioModel(), $this->getPerfilService(),
            new FotoPerfilService(), $this->getVerificacionService(), $this->getCorreoService());
    }

    public function getJuegoController(): JuegoController
    {
        return new JuegoController($this->getRender(), $this->getJuegoService(), $this->getCategoriaModel(),
            new ReporteService(new EstadoJuego(), new ReporteModel($this->getDatabase())));
    }

    // Secciones que por ahora solo muestran "EN MANTENIMIENTO"
    public function getRankingController(): MantenimientoController
    {
        return new MantenimientoController($this->getRender(), 'Ranking', 'nav_ranking');
    }

    public function getPanelController(): MantenimientoController
    {
        return new MantenimientoController($this->getRender(), 'Panel de rol', 'nav_panel');
    }

    public function getZenitplusController(): MantenimientoController
    {
        return new MantenimientoController($this->getRender(), 'ZENIT+', 'nav_zenitplus');
    }

    // ════════════════════════════════════════════════
    //  Servicios
    // ════════════════════════════════════════════════

    private function getJuegoService(): JuegoService
    {
        return new JuegoService(new EstadoJuego(), new RuletaService(), $this->getCategoriaModel(),
            new PreguntaModel($this->getDatabase()), $this->getEstadisticaModel(),
            new PartidaModel($this->getDatabase()), new PreguntaVistaModel($this->getDatabase()));
    }

    private function getPerfilService(): PerfilService
    {
        return new PerfilService($this->getEstadisticaModel(), new PartidaModel($this->getDatabase()),
            new NivelService(), $this->getMedia(), new PaisService());
    }

    private function getVerificacionService(): VerificacionService
    {
        return new VerificacionService($this->getUsuarioModel(), $this->getCorreoService());
    }

    private function getCorreoService(): CorreoService
    {
        return new CorreoService($this->getMailer(), $this->getMedia());
    }

    /** Lee la carpeta media/ (logo, favicon, íconos de categorías). */
    private function getMedia(): MediaService
    {
        return $this->media ??= new MediaService();
    }

    /** "smtp" envía mails de verdad (por defecto); "log" los escribe en log/correos.log (solo pruebas). */
    private function getMailer(): MailerInterface
    {
        if (($this->config['mail_modo'] ?? 'smtp') === 'log') {
            return new LogMailer();
        }
        return new SmtpMailer(
            $this->config['smtp_host'],
            (int) $this->config['smtp_puerto'],
            $this->config['smtp_usuario'],
            $this->config['smtp_clave'],
            $this->config['mail_remitente'],
            $this->config['mail_nombre'] ?? 'ZENIT',
            $this->config['smtp_seguridad'] ?? 'tls',
            (bool) ($this->config['smtp_verificar_ssl'] ?? true)
        );
    }

    // ════════════════════════════════════════════════
    //  Modelos, base de datos y vistas
    // ════════════════════════════════════════════════

    private function getUsuarioModel(): UsuarioModel
    {
        return new UsuarioModel($this->getDatabase());
    }

    private function getCategoriaModel(): CategoriaModel
    {
        return new CategoriaModel($this->getDatabase(), $this->getMedia());
    }

    private function getEstadisticaModel(): EstadisticaModel
    {
        return new EstadisticaModel($this->getDatabase());
    }

    /** Una sola conexión por petición. */
    private function getDatabase(): MyDatabase
    {
        return $this->database ??= new MyDatabase(
            $this->config['db_host'],
            $this->config['db_user'],
            $this->config['db_pass'],
            $this->config['db_name']
        );
    }

    /** Fecha del último cambio en public/css y public/js (sirve de número de versión). */
    private function versionArchivos(): int
    {
        $archivos = glob(dirname(__DIR__) . '/public/{css,js}/*.{css,js}', GLOB_BRACE) ?: [];
        return $archivos ? max(array_map('filemtime', $archivos)) : 0;
    }

    /** El layout recibe siempre la URL base, logo, usuario logueado y mensaje flash. */
    private function getRender(): MustacheRender
    {
        return new MustacheRender(function (): array {
            $usuario = Session::estaLogueado() ? $this->getUsuarioModel()->buscarPorId(Session::usuarioId()) : null;
            return [
                'base' => Url::base(),
                'v' => $this->versionArchivos(), // ?v= en CSS/JS: el navegador nunca usa una versión vieja
                // Fondo de la página: el lobby usa el de las categorías; el resto, el espacio vacío
                'fondo_home_url' => $this->getMedia()->fondo('home'),
                'fondo_espacio_url' => $this->getMedia()->fondo('espacio'),
                'logo' => $this->getMedia()->logo(),
                'favicon' => $this->getMedia()->favicon(),
                'apple_icon' => $this->getMedia()->appleTouchIcon(),
                // Emojis para el panel de marca del login/registro
                'categorias_marca' => $usuario ? [] : $this->getCategoriaModel()->todas(),
                'logueado' => $usuario !== null,
                'yo' => $usuario ? $this->getPerfilService()->resumen($usuario) : null,
                'flash' => Session::tomarFlash(),
                'anio' => date('Y'),
            ];
        });
    }
}
