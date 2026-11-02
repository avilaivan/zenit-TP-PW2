-- ════════════════════════════════════════════════════════════
-- ZENIT · Base de datos (MySQL / MariaDB de XAMPP)
-- 1. En phpMyAdmin, entrá primero a tu base (en XAMPP: creá "zenit";
--    en InfinityFree: la que creaste en el panel, ej. if0_12345678_zenit).
-- 2. Pestaña "Importar" → elegí este archivo → Continuar.
-- ¡OJO! Borra y vuelve a crear todas las tablas de esa base.
-- ════════════════════════════════════════════════════════════


SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS reporte, partida, usuario_categoria, opcion, pregunta, categoria, usuario;
SET FOREIGN_KEY_CHECKS = 1;

-- ── Usuarios ────────────────────────────────────────────────
-- nombre_usuario y email son ÚNICOS y no se pueden cambiar (con cualquiera de los dos se inicia sesión).
-- nombre_completo NO es único y se puede cambiar desde "Editar perfil".
-- activo = 0 hasta que se confirma el código enviado por mail.
CREATE TABLE usuario (
    id                   INT AUTO_INCREMENT PRIMARY KEY,
    nombre_completo      VARCHAR(150) NOT NULL,
    nombre_usuario       VARCHAR(20)  NOT NULL UNIQUE,
    email                VARCHAR(150) NOT NULL UNIQUE,
    password             VARCHAR(255) NOT NULL,
    anio_nacimiento      SMALLINT     NOT NULL,
    sexo                 ENUM('masculino','femenino','no_informa') NOT NULL,
    pais                 VARCHAR(80)  NOT NULL,
    ciudad               VARCHAR(80)  NOT NULL,
    latitud              DECIMAL(10,7) NULL,
    longitud             DECIMAL(10,7) NULL,
    foto_perfil          VARCHAR(255) NULL,
    rol                  ENUM('jugador','editor','admin') NOT NULL DEFAULT 'jugador',
    activo               TINYINT(1)   NOT NULL DEFAULT 0,
    -- Código de 6 dígitos enviado por mail (registro, cambio de contraseña o baja)
    codigo_verificacion  CHAR(6)      NULL,
    codigo_proposito     ENUM('registro','password','eliminar') NULL,
    codigo_expira        DATETIME     NULL,
    codigo_intentos      TINYINT      NOT NULL DEFAULT 0,
    -- Estadísticas acumuladas (el "elo" del perfil = puntos)
    puntos               INT NOT NULL DEFAULT 0,
    respondidas          INT NOT NULL DEFAULT 0,
    correctas            INT NOT NULL DEFAULT 0,
    partidas_jugadas     INT NOT NULL DEFAULT 0,
    partidas_ganadas     INT NOT NULL DEFAULT 0,
    creado               TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ── Categorías y preguntas ──────────────────────────────────
CREATE TABLE categoria (
    id          INT PRIMARY KEY,
    slug        VARCHAR(30)  NOT NULL UNIQUE,  -- nombre del ícono en media/categorias/
    nombre      VARCHAR(50)  NOT NULL,
    emoji       VARCHAR(8)   NOT NULL,
    color       CHAR(7)      NOT NULL,
    descripcion VARCHAR(120) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE pregunta (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    categoria_id INT NOT NULL,
    enunciado    VARCHAR(255) NOT NULL,
    activa       TINYINT(1) NOT NULL DEFAULT 1,
    FOREIGN KEY (categoria_id) REFERENCES categoria(id)
) ENGINE=InnoDB;

CREATE TABLE opcion (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    pregunta_id INT NOT NULL,
    texto       VARCHAR(150) NOT NULL,
    es_correcta TINYINT(1) NOT NULL DEFAULT 0,
    FOREIGN KEY (pregunta_id) REFERENCES pregunta(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── Estadística por categoría (para el % de acierto del perfil) ──
CREATE TABLE usuario_categoria (
    usuario_id   INT NOT NULL,
    categoria_id INT NOT NULL,
    respondidas  INT NOT NULL DEFAULT 0,
    correctas    INT NOT NULL DEFAULT 0,
    PRIMARY KEY (usuario_id, categoria_id),
    FOREIGN KEY (usuario_id)   REFERENCES usuario(id) ON DELETE CASCADE,
    FOREIGN KEY (categoria_id) REFERENCES categoria(id)
) ENGINE=InnoDB;

-- ── Partidas individuales (modo offline) ────────────────────
CREATE TABLE partida (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    usuario_id  INT NOT NULL,
    resultado   ENUM('en_curso','victoria','derrota') NOT NULL DEFAULT 'en_curso',
    puntos      INT NOT NULL DEFAULT 0,
    letras      VARCHAR(5) NOT NULL DEFAULT '',
    respondidas INT NOT NULL DEFAULT 0,
    correctas   INT NOT NULL DEFAULT 0,
    creada      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    terminada   DATETIME NULL,
    FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── Reportes de preguntas (se hacen al terminar una ronda) ──
-- Los revisará el editor/administrador en el panel (próxima entrega).
CREATE TABLE reporte (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    pregunta_id INT NOT NULL,
    usuario_id  INT NOT NULL,
    motivo      ENUM('ofensiva','respuesta_incorrecta','confusa','otro') NOT NULL,
    detalle     VARCHAR(500) NULL,
    estado      ENUM('pendiente','revisado','descartado') NOT NULL DEFAULT 'pendiente',
    creado      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pregunta_id) REFERENCES pregunta(id) ON DELETE CASCADE,
    FOREIGN KEY (usuario_id)  REFERENCES usuario(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── Datos: categorías ───────────────────────────────────────
INSERT INTO categoria (id, slug, nombre, emoji, color, descripcion) VALUES
(1, 'historia', 'Historia', '⏳', '#FFD400', 'Civilizaciones, guerras, personajes y fechas'),
(2, 'geografia', 'Geografía', '🌍', '#3A7BFF', 'Países, capitales, ríos y montañas'),
(3, 'ciencia', 'Ciencia', '🧪', '#89F900', 'Física, química, biología y espacio'),
(4, 'deportes', 'Deportes', '⚽', '#FF7A00', 'Fútbol, olimpíadas y récords'),
(5, 'arte-letras', 'Arte y Letras', '🎨', '#FF3B4F', 'Pintura, literatura y escultura'),
(6, 'entretenimiento', 'Entretenimiento', '🎬', '#7CC4FF', 'Cine, series, música y videojuegos'),
(7, 'matematica', 'Matemática', '➗', '#C9CED6', 'Cálculo mental, geometría y lógica'),
(8, 'tecnologia', 'Tecnología', '💻', '#B57BFF', 'Informática, internet y programación');

-- ── Datos: preguntas (10 por categoría, 6 opciones, la 1.ª es la correcta) ──

-- Historia
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (1, 1, '¿En qué año llegó Cristóbal Colón a América?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (1, '1492', 1), (1, '1500', 0), (1, '1488', 0), (1, '1510', 0), (1, '1453', 0), (1, '1521', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (2, 1, '¿Qué tratado dividió las tierras del Nuevo Mundo entre España y Portugal en 1494?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (2, 'Tratado de Tordesillas', 1), (2, 'Tratado de Zaragoza', 0), (2, 'Paz de Westfalia', 0), (2, 'Tratado de Utrecht', 0), (2, 'Tratado de Versalles', 0), (2, 'Tratado de París', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (3, 1, '¿En qué año se declaró la independencia de Argentina?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (3, '1816', 1), (3, '1810', 0), (3, '1820', 0), (3, '1853', 0), (3, '1806', 0), (3, '1830', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (4, 1, '¿Quién fue el primer emperador romano?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (4, 'Augusto', 1), (4, 'Julio César', 0), (4, 'Nerón', 0), (4, 'Calígula', 0), (4, 'Trajano', 0), (4, 'Constantino', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (5, 1, '¿En qué año cayó el Muro de Berlín?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (5, '1989', 1), (5, '1991', 0), (5, '1985', 0), (5, '1961', 0), (5, '1979', 0), (5, '1975', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (6, 1, '¿Qué civilización construyó Machu Picchu?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (6, 'Inca', 1), (6, 'Azteca', 0), (6, 'Maya', 0), (6, 'Olmeca', 0), (6, 'Tolteca', 0), (6, 'Mapuche', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (7, 1, '¿En qué año terminó la Segunda Guerra Mundial?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (7, '1945', 1), (7, '1944', 0), (7, '1939', 0), (7, '1946', 0), (7, '1918', 0), (7, '1950', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (8, 1, '¿Qué general lideró el Cruce de los Andes en 1817?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (8, 'José de San Martín', 1), (8, 'Manuel Belgrano', 0), (8, 'Martín Miguel de Güemes', 0), (8, 'Juan Manuel de Rosas', 0), (8, 'Domingo F. Sarmiento', 0), (8, 'Bartolomé Mitre', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (9, 1, '¿Qué revolución comenzó en 1789?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (9, 'Revolución Francesa', 1), (9, 'Revolución Rusa', 0), (9, 'Revolución Industrial', 0), (9, 'Revolución Mexicana', 0), (9, 'Revolución de Mayo', 0), (9, 'Revolución Gloriosa', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (10, 1, '¿Qué faraón tenía la tumba que Howard Carter descubrió casi intacta en 1922?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (10, 'Tutankamón', 1), (10, 'Ramsés II', 0), (10, 'Keops', 0), (10, 'Cleopatra', 0), (10, 'Akenatón', 0), (10, 'Seti I', 0);

-- Geografía
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (11, 2, '¿Cuál es la capital de Australia?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (11, 'Canberra', 1), (11, 'Sídney', 0), (11, 'Melbourne', 0), (11, 'Perth', 0), (11, 'Brisbane', 0), (11, 'Adelaida', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (12, 2, '¿Cuál es el río más caudaloso del mundo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (12, 'Amazonas', 1), (12, 'Nilo', 0), (12, 'Misisipi', 0), (12, 'Yangtsé', 0), (12, 'Paraná', 0), (12, 'Congo', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (13, 2, '¿Cuál es la montaña más alta de América?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (13, 'Aconcagua', 1), (13, 'Ojos del Salado', 0), (13, 'Chimborazo', 0), (13, 'Denali', 0), (13, 'Huascarán', 0), (13, 'Cotopaxi', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (14, 2, '¿Cuál es el país más grande del mundo por superficie?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (14, 'Rusia', 1), (14, 'Canadá', 0), (14, 'China', 0), (14, 'Estados Unidos', 0), (14, 'Brasil', 0), (14, 'Australia', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (15, 2, '¿Cuál es la capital de Canadá?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (15, 'Ottawa', 1), (15, 'Toronto', 0), (15, 'Montreal', 0), (15, 'Vancouver', 0), (15, 'Quebec', 0), (15, 'Calgary', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (16, 2, '¿Cuál es el océano más grande del planeta?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (16, 'Pacífico', 1), (16, 'Atlántico', 0), (16, 'Índico', 0), (16, 'Ártico', 0), (16, 'Antártico', 0), (16, 'Mediterráneo', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (17, 2, '¿En qué país están las pirámides de Giza?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (17, 'Egipto', 1), (17, 'México', 0), (17, 'Sudán', 0), (17, 'Perú', 0), (17, 'Irak', 0), (17, 'Jordania', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (18, 2, '¿Cuál es el desierto no polar más árido del mundo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (18, 'Atacama', 1), (18, 'Sahara', 0), (18, 'Gobi', 0), (18, 'Kalahari', 0), (18, 'Namib', 0), (18, 'Mojave', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (19, 2, '¿Qué país tiene forma de bota?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (19, 'Italia', 1), (19, 'Grecia', 0), (19, 'Portugal', 0), (19, 'Croacia', 0), (19, 'Chile', 0), (19, 'España', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (20, 2, '¿Cuál es la capital de Japón?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (20, 'Tokio', 1), (20, 'Osaka', 0), (20, 'Kioto', 0), (20, 'Seúl', 0), (20, 'Pekín', 0), (20, 'Hiroshima', 0);

-- Ciencia
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (21, 3, '¿Cuál es el símbolo químico del oro?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (21, 'Au', 1), (21, 'Ag', 0), (21, 'Or', 0), (21, 'Go', 0), (21, 'Fe', 0), (21, 'Ao', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (22, 3, '¿Cuál es el planeta más grande del sistema solar?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (22, 'Júpiter', 1), (22, 'Saturno', 0), (22, 'Neptuno', 0), (22, 'Tierra', 0), (22, 'Urano', 0), (22, 'Marte', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (23, 3, '¿Qué gas absorben las plantas para hacer la fotosíntesis?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (23, 'Dióxido de carbono', 1), (23, 'Oxígeno', 0), (23, 'Nitrógeno', 0), (23, 'Hidrógeno', 0), (23, 'Helio', 0), (23, 'Metano', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (24, 3, '¿Cuántos huesos tiene el cuerpo humano adulto?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (24, '206', 1), (24, '201', 0), (24, '212', 0), (24, '198', 0), (24, '230', 0), (24, '186', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (25, 3, '¿Cuál es la velocidad aproximada de la luz en el vacío?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (25, '300.000 km/s', 1), (25, '150.000 km/s', 0), (25, '30.000 km/s', 0), (25, '1.000.000 km/s', 0), (25, '3.000 km/s', 0), (25, '3.000.000 km/s', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (26, 3, '¿Cuál es la fórmula química del agua?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (26, 'H₂O', 1), (26, 'CO₂', 0), (26, 'O₂', 0), (26, 'H₂O₂', 0), (26, 'NaCl', 0), (26, 'HO₂', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (27, 3, '¿Quién formuló la teoría de la relatividad?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (27, 'Albert Einstein', 1), (27, 'Isaac Newton', 0), (27, 'Nikola Tesla', 0), (27, 'Galileo Galilei', 0), (27, 'Stephen Hawking', 0), (27, 'Marie Curie', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (28, 3, '¿Qué órgano bombea la sangre por el cuerpo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (28, 'Corazón', 1), (28, 'Hígado', 0), (28, 'Pulmón', 0), (28, 'Riñón', 0), (28, 'Cerebro', 0), (28, 'Estómago', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (29, 3, '¿Qué planeta es conocido como el «planeta rojo»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (29, 'Marte', 1), (29, 'Venus', 0), (29, 'Mercurio', 0), (29, 'Júpiter', 0), (29, 'Saturno', 0), (29, 'Neptuno', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (30, 3, '¿Qué partícula del átomo tiene carga negativa?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (30, 'Electrón', 1), (30, 'Protón', 0), (30, 'Neutrón', 0), (30, 'Fotón', 0), (30, 'Positrón', 0), (30, 'Neutrino', 0);

-- Deportes
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (31, 4, '¿Cuántos jugadores tiene un equipo de fútbol en la cancha?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (31, '11', 1), (31, '10', 0), (31, '9', 0), (31, '12', 0), (31, '7', 0), (31, '8', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (32, 4, '¿Qué selección ganó el Mundial de Fútbol 2022?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (32, 'Argentina', 1), (32, 'Francia', 0), (32, 'Brasil', 0), (32, 'Croacia', 0), (32, 'Alemania', 0), (32, 'España', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (33, 4, '¿Cada cuántos años se celebran los Juegos Olímpicos de verano?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (33, '4', 1), (33, '2', 0), (33, '3', 0), (33, '5', 0), (33, '6', 0), (33, '8', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (34, 4, '¿Cuántos puntos vale un triple en el básquet?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (34, '3', 1), (34, '2', 0), (34, '1', 0), (34, '4', 0), (34, '5', 0), (34, '6', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (35, 4, '¿En qué país se originó el rugby?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (35, 'Inglaterra', 1), (35, 'Nueva Zelanda', 0), (35, 'Francia', 0), (35, 'Sudáfrica', 0), (35, 'Australia', 0), (35, 'Escocia', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (36, 4, '¿Cuántos sets hay que ganar en un partido masculino de Grand Slam?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (36, '3', 1), (36, '2', 0), (36, '4', 0), (36, '5', 0), (36, '1', 0), (36, '6', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (37, 4, '¿Qué selección ganó más Copas del Mundo de fútbol masculino?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (37, 'Brasil', 1), (37, 'Alemania', 0), (37, 'Italia', 0), (37, 'Argentina', 0), (37, 'Uruguay', 0), (37, 'Francia', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (38, 4, '¿Cuánto mide una maratón?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (38, '42,195 km', 1), (38, '40 km', 0), (38, '21,097 km', 0), (38, '45 km', 0), (38, '50 km', 0), (38, '38,5 km', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (39, 4, '¿En qué deporte se destacó Michael Phelps?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (39, 'Natación', 1), (39, 'Atletismo', 0), (39, 'Ciclismo', 0), (39, 'Remo', 0), (39, 'Gimnasia', 0), (39, 'Tenis', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (40, 4, '¿De qué color es la camiseta del líder del Tour de Francia?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (40, 'Amarilla', 1), (40, 'Verde', 0), (40, 'Rosa', 0), (40, 'Blanca', 0), (40, 'Roja', 0), (40, 'Azul', 0);

-- Arte y Letras
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (41, 5, '¿Quién pintó la Mona Lisa?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (41, 'Leonardo da Vinci', 1), (41, 'Miguel Ángel', 0), (41, 'Rafael', 0), (41, 'Botticelli', 0), (41, 'Caravaggio', 0), (41, 'Tiziano', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (42, 5, '¿Quién escribió «Don Quijote de la Mancha»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (42, 'Miguel de Cervantes', 1), (42, 'Lope de Vega', 0), (42, 'Francisco de Quevedo', 0), (42, 'Luis de Góngora', 0), (42, 'Calderón de la Barca', 0), (42, 'Garcilaso de la Vega', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (43, 5, '¿Quién escribió «Cien años de soledad»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (43, 'Gabriel García Márquez', 1), (43, 'Mario Vargas Llosa', 0), (43, 'Julio Cortázar', 0), (43, 'Jorge Luis Borges', 0), (43, 'Pablo Neruda', 0), (43, 'Isabel Allende', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (44, 5, '¿Quién pintó «La noche estrellada»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (44, 'Vincent van Gogh', 1), (44, 'Claude Monet', 0), (44, 'Pablo Picasso', 0), (44, 'Salvador Dalí', 0), (44, 'Paul Cézanne', 0), (44, 'Paul Gauguin', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (45, 5, '¿Quién es el autor de «Martín Fierro»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (45, 'José Hernández', 1), (45, 'Domingo F. Sarmiento', 0), (45, 'Jorge Luis Borges', 0), (45, 'Leopoldo Lugones', 0), (45, 'Esteban Echeverría', 0), (45, 'Estanislao del Campo', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (46, 5, '¿Quién escribió «Romeo y Julieta»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (46, 'William Shakespeare', 1), (46, 'Miguel de Cervantes', 0), (46, 'Dante Alighieri', 0), (46, 'Molière', 0), (46, 'Goethe', 0), (46, 'Christopher Marlowe', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (47, 5, '¿Quién pintó el «Guernica»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (47, 'Pablo Picasso', 1), (47, 'Salvador Dalí', 0), (47, 'Joan Miró', 0), (47, 'Francisco de Goya', 0), (47, 'Diego Velázquez', 0), (47, 'Frida Kahlo', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (48, 5, '¿Quién esculpió el «David» de mármol de Florencia (1504)?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (48, 'Miguel Ángel', 1), (48, 'Donatello', 0), (48, 'Gian Lorenzo Bernini', 0), (48, 'Auguste Rodin', 0), (48, 'Leonardo da Vinci', 0), (48, 'Benvenuto Cellini', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (49, 5, '¿Qué escritor argentino escribió «Rayuela»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (49, 'Julio Cortázar', 1), (49, 'Jorge Luis Borges', 0), (49, 'Ernesto Sabato', 0), (49, 'Adolfo Bioy Casares', 0), (49, 'Ricardo Piglia', 0), (49, 'Manuel Puig', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (50, 5, '¿Qué poeta chileno ganó el Premio Nobel de Literatura en 1971?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (50, 'Pablo Neruda', 1), (50, 'Gabriela Mistral', 0), (50, 'Vicente Huidobro', 0), (50, 'Nicanor Parra', 0), (50, 'Gonzalo Rojas', 0), (50, 'Octavio Paz', 0);

-- Entretenimiento
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (51, 6, '¿Cómo se llama el protagonista de Super Mario Bros. que usa gorra roja?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (51, 'Mario', 1), (51, 'Luigi', 0), (51, 'Wario', 0), (51, 'Link', 0), (51, 'Sonic', 0), (51, 'Yoshi', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (52, 6, '¿Qué película de James Cameron de 1997 ganó 11 premios Oscar?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (52, 'Titanic', 1), (52, 'Avatar', 0), (52, 'Terminator 2', 0), (52, 'Aliens', 0), (52, 'True Lies', 0), (52, 'The Abyss', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (53, 6, '¿Cómo se llamaba la banda de Freddie Mercury?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (53, 'Queen', 1), (53, 'The Beatles', 0), (53, 'Led Zeppelin', 0), (53, 'Pink Floyd', 0), (53, 'The Rolling Stones', 0), (53, 'AC/DC', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (54, 6, '¿En qué serie aparece el profesor de química Walter White?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (54, 'Breaking Bad', 1), (54, 'Los Soprano', 0), (54, 'Dexter', 0), (54, 'Lost', 0), (54, 'Prison Break', 0), (54, 'House', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (55, 6, '¿Qué personaje dice «Yo soy tu padre» en Star Wars?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (55, 'Darth Vader', 1), (55, 'Obi-Wan Kenobi', 0), (55, 'Yoda', 0), (55, 'Palpatine', 0), (55, 'Han Solo', 0), (55, 'Luke Skywalker', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (56, 6, '¿Quién es el mago protagonista de la saga de J. K. Rowling?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (56, 'Harry Potter', 1), (56, 'Gandalf', 0), (56, 'Merlín', 0), (56, 'Frodo', 0), (56, 'Dumbledore', 0), (56, 'Percy Jackson', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (57, 6, '¿En qué videojuego aparecen los bloques y los creepers?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (57, 'Minecraft', 1), (57, 'Fortnite', 0), (57, 'Roblox', 0), (57, 'Terraria', 0), (57, 'Among Us', 0), (57, 'Stardew Valley', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (58, 6, '¿Cómo se llama el león protagonista de «El Rey León»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (58, 'Simba', 1), (58, 'Mufasa', 0), (58, 'Scar', 0), (58, 'Nala', 0), (58, 'Timón', 0), (58, 'Rafiki', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (59, 6, '¿Qué cantante es conocido como el «Rey del Pop»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (59, 'Michael Jackson', 1), (59, 'Elvis Presley', 0), (59, 'Prince', 0), (59, 'Madonna', 0), (59, 'Freddie Mercury', 0), (59, 'Justin Timberlake', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (60, 6, '¿En qué ciudad vive la familia Simpson?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (60, 'Springfield', 1), (60, 'Shelbyville', 0), (60, 'Quahog', 0), (60, 'South Park', 0), (60, 'Ciudad Gótica', 0), (60, 'Arlen', 0);

-- Matemática
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (61, 7, '¿Cuánto es 7 × 8?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (61, '56', 1), (61, '54', 0), (61, '48', 0), (61, '64', 0), (61, '58', 0), (61, '63', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (62, 7, '¿Cuál es la raíz cuadrada de 144?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (62, '12', 1), (62, '14', 0), (62, '11', 0), (62, '16', 0), (62, '13', 0), (62, '10', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (63, 7, '¿Cuánto es el 15 % de 200?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (63, '30', 1), (63, '15', 0), (63, '20', 0), (63, '25', 0), (63, '35', 0), (63, '40', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (64, 7, '¿Cuántos lados tiene un hexágono?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (64, '6', 1), (64, '5', 0), (64, '7', 0), (64, '8', 0), (64, '4', 0), (64, '9', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (65, 7, '¿Cuánto suman los ángulos interiores de un triángulo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (65, '180°', 1), (65, '90°', 0), (65, '360°', 0), (65, '270°', 0), (65, '120°', 0), (65, '200°', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (66, 7, 'Si 2x + 6 = 20, ¿cuánto vale x?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (66, '7', 1), (66, '6', 0), (66, '8', 0), (66, '13', 0), (66, '10', 0), (66, '14', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (67, 7, '¿Cuánto es 2 elevado a la 10?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (67, '1024', 1), (67, '512', 0), (67, '1000', 0), (67, '2048', 0), (67, '100', 0), (67, '4096', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (68, 7, '¿Cuál es el siguiente número primo después del 13?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (68, '17', 1), (68, '15', 0), (68, '19', 0), (68, '14', 0), (68, '16', 0), (68, '21', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (69, 7, '¿Cuánto es 3/4 expresado en decimal?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (69, '0,75', 1), (69, '0,34', 0), (69, '0,43', 0), (69, '0,7', 0), (69, '1,33', 0), (69, '0,25', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (70, 7, '¿Cuál es el valor aproximado de π (pi)?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (70, '3,1416', 1), (70, '3,1614', 0), (70, '2,7182', 0), (70, '1,6180', 0), (70, '3,4116', 0), (70, '3,0', 0);

-- Tecnología
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (71, 8, '¿Qué significa la sigla HTML?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (71, 'HyperText Markup Language', 1), (71, 'High Text Machine Language', 0), (71, 'Hyper Transfer Markup Logic', 0), (71, 'Home Tool Markup Language', 0), (71, 'HyperText Media Link', 0), (71, 'Hyper Tool Multi Language', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (72, 8, '¿Quién fundó Microsoft junto a Paul Allen?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (72, 'Bill Gates', 1), (72, 'Steve Jobs', 0), (72, 'Elon Musk', 0), (72, 'Mark Zuckerberg', 0), (72, 'Larry Page', 0), (72, 'Jeff Bezos', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (73, 8, '¿Cuántos bits tiene un byte?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (73, '8', 1), (73, '4', 0), (73, '16', 0), (73, '10', 0), (73, '2', 0), (73, '32', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (74, 8, '¿Qué empresa desarrolla el sistema operativo Android?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (74, 'Google', 1), (74, 'Apple', 0), (74, 'Microsoft', 0), (74, 'Samsung', 0), (74, 'Huawei', 0), (74, 'Nokia', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (75, 8, '¿Qué significa la sigla CPU?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (75, 'Unidad Central de Procesamiento', 1), (75, 'Unidad de Control Personal', 0), (75, 'Centro de Proceso Universal', 0), (75, 'Computadora Personal Unificada', 0), (75, 'Unidad de Carga de Programas', 0), (75, 'Central de Programas Unificados', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (76, 8, '¿Qué lenguaje de programación tiene una taza de café como logo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (76, 'Java', 1), (76, 'Python', 0), (76, 'C++', 0), (76, 'PHP', 0), (76, 'Ruby', 0), (76, 'JavaScript', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (77, 8, '¿Qué protocolo se usa para navegar páginas web de forma segura?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (77, 'HTTPS', 1), (77, 'FTP', 0), (77, 'SMTP', 0), (77, 'HTTP', 0), (77, 'SSH', 0), (77, 'POP3', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (78, 8, '¿En qué año se lanzó el primer iPhone?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (78, '2007', 1), (78, '2005', 0), (78, '2008', 0), (78, '2010', 0), (78, '2003', 0), (78, '2001', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (79, 8, '¿Qué significa la sigla SQL?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (79, 'Structured Query Language', 1), (79, 'Simple Question Language', 0), (79, 'System Quality Logic', 0), (79, 'Standard Query Link', 0), (79, 'Sequential Query Language', 0), (79, 'Server Query Language', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (80, 8, '¿Cuál de estas unidades representa más información?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (80, '1 terabyte', 1), (80, '1 gigabyte', 0), (80, '1 megabyte', 0), (80, '1 kilobyte', 0), (80, '1 byte', 0), (80, '1 megabit', 0);

-- ── Usuario de prueba (ya verificado) ───────────────────────
-- usuario: demo   ·   contraseña: zenit1234
INSERT INTO usuario (nombre_completo, nombre_usuario, email, password, anio_nacimiento, sexo, pais, ciudad, activo)
VALUES ('Jugador Demo', 'demo', 'demo@zenit.local', '$2y$10$oAKyEPvEIBXY4D1ce3PiL.b68XSNUd7ebYcuWPSA3DaANhhQCTpVq', 2000, 'no_informa', 'Argentina', 'Buenos Aires', 1);
