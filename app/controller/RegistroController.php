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
        $nombreCompleto = trim(Request::post('nombre_completo', ''));
        $anioNacimiento = Request::post('anio_nacimiento', '');
        $sexo = Request::post('sexo', '');
        $pais = trim(Request::post('pais', ''));
        $ciudad = trim(Request::post('ciudad', ''));
        $email = trim(Request::post('email', ''));
        $password = Request::post('password', '');
        $confirmarPassword = Request::post('confirmar_password', '');
        $nombreUsuario = trim(Request::post('nombre_usuario', ''));

        $latitud = Request::post('latitud', '');
        $longitud = Request::post('longitud', '');

        // Validar campos obligatorios
        if (
            $nombreCompleto === '' ||
            $anioNacimiento === '' ||
            $sexo === '' ||
            $pais === '' ||
            $ciudad === '' ||
            $email === '' ||
            $password === '' ||
            $confirmarPassword === '' ||
            $nombreUsuario === ''
        ) {
            $this->mostrarError("Todos los campos son obligatorios.");
            return;
        }

        // Validar año de nacimiento
        if (
            !ctype_digit((string) $anioNacimiento) ||
            (int) $anioNacimiento < 1900 ||
            (int) $anioNacimiento > (int) date('Y')
        ) {
            $this->mostrarError("Ingresá un año de nacimiento válido.");
            return;
        }

        // Validar sexo
        $sexosPermitidos = [
            'femenino',
            'masculino',
            'otro',
            'no_informar'
        ];

        if (!in_array($sexo, $sexosPermitidos, true)) {
            $this->mostrarError("Seleccioná una opción de sexo válida.");
            return;
        }

        // Validar email
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $this->mostrarError("Ingresá un email válido.");
            return;
        }

        // Validar contraseña
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

        // Validar nombre de usuario
        if (strlen($nombreUsuario) > 50) {
            $this->mostrarError(
                "El nombre de usuario no puede superar los 50 caracteres."
            );
            return;
        }

        if ($this->model->existeEmail($email)) {
            $this->mostrarError("Ese email ya está registrado.");
            return;
        }

        if ($this->model->existeNombreUsuario($nombreUsuario)) {
            $this->mostrarError(
                "Ese nombre de usuario ya está ocupado."
            );
            return;
        }

        if ($latitud === '' || $longitud === '') {
            $this->mostrarError(
                "Tenés que seleccionar tu ubicación en el mapa."
            );
            return;
        }

        if (
            ($latitud !== null && !is_numeric($latitud)) ||
            ($longitud !== null && !is_numeric($longitud))
        ) {
            $this->mostrarError("Las coordenadas no son válidas.");
            return;
        }

        if (
            ($latitud === null) !== ($longitud === null) ||
            ($latitud !== null &&
                ((float) $latitud < -90 || (float) $latitud > 90)) ||
            ($longitud !== null &&
                ((float) $longitud < -180 || (float) $longitud > 180))
        ) {
            $this->mostrarError("Las coordenadas no son válidas.");
            return;
        }

        // Validar que se haya subido una foto
        if (
            !isset($_FILES['foto_perfil']) ||
            $_FILES['foto_perfil']['error'] !== UPLOAD_ERR_OK
        ) {
            $this->mostrarError("Tenés que subir una foto de perfil válida.");
            return;
        }

        $foto = $_FILES['foto_perfil'];

        // Límite de 2 MB
        if ($foto['size'] > 2 * 1024 * 1024) {
            $this->mostrarError("La foto no puede superar los 2 MB.");
            return;
        }

        // Comprobar el tipo real del archivo
        $finfo = new \finfo(FILEINFO_MIME_TYPE);
        $tipo = $finfo->file($foto['tmp_name']);

        $tiposPermitidos = [
            'image/jpeg' => 'jpg',
            'image/png' => 'png',
            'image/webp' => 'webp'
        ];

        if (!isset($tiposPermitidos[$tipo])) {
            $this->mostrarError(
                "La foto debe ser JPG, PNG o WEBP."
            );
            return;
        }

        // Crear la carpeta de perfiles si todavía no existe
        $directorio = __DIR__ . '/../../uploads/perfiles/';

        if (
            !is_dir($directorio) &&
            !mkdir($directorio, 0755, true)
        ) {
            $this->mostrarError(
                "No se pudo preparar la carpeta para la foto."
            );
            return;
        }

        // Generar un nombre aleatorio para no usar el nombre original
        $nombreArchivo = bin2hex(random_bytes(16))
            . '.' . $tiposPermitidos[$tipo];

        if (!move_uploaded_file(
            $foto['tmp_name'],
            $directorio . $nombreArchivo
        )) {
            $this->mostrarError("No se pudo guardar la foto.");
            return;
        }

        $datos = [
            'nombre_usuario' => $nombreUsuario,
            'email' => $email,
            'password' => $password,
            'nombre_completo' => $nombreCompleto,
            'anio_nacimiento' => (int) $anioNacimiento,
            'sexo' => $sexo,
            'pais' => $pais,
            'ciudad' => $ciudad,
            'latitud' => $latitud,
            'longitud' => $longitud,
            'foto_perfil' => 'uploads/perfiles/' . $nombreArchivo
        ];

        $this->model->registrar($datos);

        Redirect::to('/?registro=ok');
    }

    private function mostrarError($mensaje)
    {
        $this->render->renderiza("registro", [
            "error" => $mensaje
        ]);
    }
}
