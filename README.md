# ZENIT · Llegá a tu zenit

Juego de preguntas y respuestas — **Programación Web 2 · UNLaM**.
PHP + MySQL con MVC propio (sin frameworks) y vistas Mustache. Responsive: la misma web funciona en celular y escritorio.

## Primera entrega (alcance)

| Incluido | En mantenimiento (más adelante) |
|---|---|
| Registro (nombre completo, usuario, email, contraseña, año, sexo, país/ciudad con mapa) + **código de 6 dígitos al mail** | Ranking |
| Login con usuario o email | Panel de rol (editor / admin) |
| Perfil estilo Steam: foto, ubicación con mapa, nivel **1 → Z**, elo, % por categoría, QR | ZENIT+ |
| Menú ⋮: editar perfil (nombre completo y foto con recorte circular; usuario y email no se cambian), contraseña con código al mail, cerrar sesión, eliminar cuenta con código al mail | Juego online entre jugadores |
| Juego **individual (offline)**: ruleta, vidas, letras Z·E·N·I·T, categoría Z | Trampitas |
| 8 categorías × 10 preguntas (**6 opciones**, por tiempo) | |

## Cómo se juega

1. **Jugar** → la ruleta (estilo apertura de caja) pasa las categorías de derecha a izquierda.
2. Si sale una **categoría**: 3 preguntas de esa categoría. Hay que acertar **mínimo 2**; si no, perdés **1 vida** (empezás con 3).
3. Cada **3 rondas superadas** se desbloquea una **ronda de letra**: 3 preguntas de 3 categorías distintas. Si acertás **2 de 3**, elegís **una letra o un corazón**.
4. La **categoría Z** sale muy pocas veces (1,5 %, sube +0,1 % por cada acierto, tope 5 %). Si te toca, vas directo a elegir letra o corazón.
5. Ganás al juntar **Z·E·N·I·T**. Perdés al quedarte sin vidas. Las categorías nunca se eliminan.

Todas las reglas numéricas están en `app/service/ReglasJuego.php`; los niveles 1–Z en `app/service/NivelService.php`.

## Instalación local (XAMPP)

1. El proyecto va en `C:\xampp\htdocs\ZENIT-TPW2` (cualquier nombre de carpeta funciona).
2. En phpMyAdmin creá la base `zenit`, entrá a ella → **Importar** → `app/sql/zenit.sql` (tablas, preguntas y un usuario de prueba).
3. Copiar `config/config.example.ini` como `config/config.ini`, revisar la base y **completar el mail** (ver abajo).
4. Abrir **http://localhost/ZENIT-TPW2/**

Usuario de prueba: **demo** / **zenit1234**

> Requisitos: Apache con `mod_rewrite` (viene activo en XAMPP) y PHP 8.0 o superior.

### Mails (Gmail)

Los códigos (registro, cambio de contraseña, baja de cuenta) y los avisos llegan por mail con el logo de ZENIT.

0. Usá una **cuenta de Gmail propia de ZENIT** (no tu mail personal): es el remitente que ven todos los jugadores.
1. En esa cuenta de Google activá la **verificación en 2 pasos**.
2. Creá una **contraseña de aplicación** en https://myaccount.google.com/apppasswords (16 letras).
3. En `config/config.ini` completá `smtp_usuario` y `mail_remitente` con tu Gmail, y `smtp_clave` con esa contraseña.
4. Probalo desde la carpeta del proyecto:
   ```
   C:\xampp\php\php.exe herramientas\probar_mail.php tucorreo@gmail.com
   ```

**Si da error de TLS/certificados en XAMPP:** descargá `cacert.pem` de https://curl.se/ca/cacert.pem,
guardalo en `C:\xampp\php\extras\ssl\cacert.pem` y en `C:\xampp\php\php.ini` poné
`openssl.cafile="C:\xampp\php\extras\ssl\cacert.pem"`. Reiniciá Apache.
(Último recurso, solo en tu PC: `smtp_verificar_ssl = 0` en config.ini.)

### Carpeta `media`

Logo, favicon, fondos y emoji de cada categoría se cambian sin tocar código.
Ver `media/LEEME.md`.

## Deploy (GitHub → InfinityFree)

Cada `git push` a `main` sube la web a InfinityFree por FTP (`.github/workflows/deploy.yml`).

1. En GitHub → **Settings → Secrets and variables → Actions** cargá `FTP_SERVER` (`ftpupload.net`), `FTP_USERNAME` (`if0_…`) y `FTP_PASSWORD` (contraseña de la cuenta de hosting).
2. En InfinityFree creá una base MySQL, entrá con su phpMyAdmin y importá `app/sql/zenit.sql`.
3. Con el File Manager creá `htdocs/config/config.ini` (copiá `config.example.ini`) con los datos de esa base. Ese archivo nunca se sube desde GitHub.

## Estructura

```
index.php              Front controller (todas las URLs pasan por acá)
.htaccess              URLs limpias y bloqueo de carpetas internas
app/
  Configuration.php    Contenedor de dependencias (arma cada objeto)
  controller/          Reciben la petición y eligen la vista / JSON
  model/               Consultas SQL (siempre preparadas)
  service/             Reglas de negocio (juego, niveles, verificación…)
  view/                Plantillas Mustache (layout + páginas)
  sql/zenit.sql        Base de datos completa
helper/                Router, Request, Session, Url, MyDatabase, mailers…
public/                CSS, JS y fotos subidas
media/                 Logo, favicon, fondos y emojis de categorías (editable)
herramientas/          probar_mail.php (prueba del SMTP por consola)
config/                config.ini (no se sube a Git)
vendor/mustache        Motor de plantillas
```

### Principios SOLID aplicados

- **S** — cada clase tiene una sola responsabilidad (`ValidadorRegistro`, `FotoPerfilService`, `RuletaService`, `NivelService`…).
- **O** — los niveles y reglas se cambian editando tablas/constantes, sin tocar la lógica.
- **L / I** — `MailerInterface` con dos implementaciones intercambiables (`SmtpMailer`, `LogMailer`); `CorreoService` arma los mails sin saber cómo se envían.
- **D** — los controllers reciben sus dependencias por constructor desde `Configuration`; nadie hace `new` de lo que usa.

### Seguridad

- Toda la lógica y validación está en el servidor. La respuesta correcta **nunca** se manda al navegador antes de responder; el reloj también se controla en el servidor.
- Contraseñas con `password_hash()`, consultas preparadas con PDO, cookie de sesión `HttpOnly` + `SameSite=Lax`.
- Las fotos se validan por su contenido real, se normalizan a 512×512 y se guardan con nombre aleatorio.
- Los códigos por mail tienen propósito (registro / contraseña / baja), vencen a los 15 minutos y se bloquean tras 5 intentos.

### Librerías externas (por CDN, a consultar con la cátedra)

- Google Fonts (Inter) · Leaflet + OpenStreetMap/CARTO (mapa) · Nominatim y Photon (búsqueda de ciudades) · qrcodejs (QR del perfil).
