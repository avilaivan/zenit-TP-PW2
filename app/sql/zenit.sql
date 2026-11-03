-- ════════════════════════════════════════════════════════════
-- ZENIT · Base de datos (MySQL / MariaDB de XAMPP)
-- 1. En phpMyAdmin, entrá primero a tu base (en XAMPP: creá "zenit";
--    en InfinityFree: la que creaste en el panel, ej. if0_12345678_zenit).
-- 2. Pestaña "Importar" → elegí este archivo → Continuar.
-- ¡OJO! Borra y vuelve a crear todas las tablas de esa base.
-- ════════════════════════════════════════════════════════════


SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS pregunta_vista, reporte, partida, usuario_categoria, opcion, pregunta, categoria, usuario;
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Categorías y preguntas ──────────────────────────────────
CREATE TABLE categoria (
    id          INT PRIMARY KEY,
    slug        VARCHAR(30)  NOT NULL UNIQUE,  -- nombre del ícono en media/categorias/
    nombre      VARCHAR(50)  NOT NULL,
    emoji       VARCHAR(8)   NOT NULL,
    color       CHAR(7)      NOT NULL,
    descripcion VARCHAR(120) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE pregunta (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    categoria_id INT NOT NULL,
    enunciado    VARCHAR(255) NOT NULL,
    activa       TINYINT(1) NOT NULL DEFAULT 1,
    FOREIGN KEY (categoria_id) REFERENCES categoria(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE opcion (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    pregunta_id INT NOT NULL,
    texto       VARCHAR(150) NOT NULL,
    es_correcta TINYINT(1) NOT NULL DEFAULT 0,
    FOREIGN KEY (pregunta_id) REFERENCES pregunta(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Estadística por categoría (para el % de acierto del perfil) ──
CREATE TABLE usuario_categoria (
    usuario_id   INT NOT NULL,
    categoria_id INT NOT NULL,
    respondidas  INT NOT NULL DEFAULT 0,
    correctas    INT NOT NULL DEFAULT 0,
    PRIMARY KEY (usuario_id, categoria_id),
    FOREIGN KEY (usuario_id)   REFERENCES usuario(id) ON DELETE CASCADE,
    FOREIGN KEY (categoria_id) REFERENCES categoria(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Preguntas ya vistas por cada jugador (para no repetirlas) ──
-- Un jugador no vuelve a ver una pregunta de una categoría hasta haber visto
-- todas las demás de esa categoría; ahí se reinicia su historial de esa categoría.
CREATE TABLE IF NOT EXISTS pregunta_vista (
    usuario_id  INT NOT NULL,
    pregunta_id INT NOT NULL,
    orden       BIGINT NOT NULL DEFAULT 0,          -- crece con cada pregunta vista (ms)
    vista       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (usuario_id, pregunta_id),
    FOREIGN KEY (usuario_id)  REFERENCES usuario(id)  ON DELETE CASCADE,
    FOREIGN KEY (pregunta_id) REFERENCES pregunta(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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

-- ── Datos: preguntas (40 por categoría, 6 opciones, la 1.ª es la correcta) ──

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
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (11, 1, '¿En qué año comenzó la Primera Guerra Mundial?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (11, '1914', 1), (11, '1912', 0), (11, '1916', 0), (11, '1918', 0), (11, '1905', 0), (11, '1939', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (12, 1, '¿Qué fecha recuerda la Revolución de Mayo en Argentina?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (12, '25 de mayo de 1810', 1), (12, '9 de julio de 1816', 0), (12, '20 de junio de 1820', 0), (12, '25 de mayo de 1816', 0), (12, '17 de agosto de 1850', 0), (12, '12 de octubre de 1492', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (13, 1, '¿Quién creó la bandera argentina?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (13, 'Manuel Belgrano', 1), (13, 'José de San Martín', 0), (13, 'Domingo F. Sarmiento', 0), (13, 'Mariano Moreno', 0), (13, 'Cornelio Saavedra', 0), (13, 'Juan José Castelli', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (14, 1, '¿En qué ciudad se declaró la independencia argentina en 1816?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (14, 'San Miguel de Tucumán', 1), (14, 'Buenos Aires', 0), (14, 'Córdoba', 0), (14, 'Rosario', 0), (14, 'Mendoza', 0), (14, 'Salta', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (15, 1, '¿Qué imperio tenía su capital en Tenochtitlan?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (15, 'Azteca', 1), (15, 'Inca', 0), (15, 'Maya', 0), (15, 'Olmeca', 0), (15, 'Romano', 0), (15, 'Otomano', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (16, 1, '¿Quién fue el primer presidente de Estados Unidos?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (16, 'George Washington', 1), (16, 'Abraham Lincoln', 0), (16, 'Thomas Jefferson', 0), (16, 'John Adams', 0), (16, 'Benjamin Franklin', 0), (16, 'Theodore Roosevelt', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (17, 1, '¿En qué año llegó el ser humano a la Luna por primera vez?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (17, '1969', 1), (17, '1965', 0), (17, '1972', 0), (17, '1961', 0), (17, '1975', 0), (17, '1959', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (18, 1, '¿Qué transatlántico se hundió en 1912 tras chocar con un iceberg?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (18, 'Titanic', 1), (18, 'Lusitania', 0), (18, 'Britannic', 0), (18, 'Queen Mary', 0), (18, 'Mayflower', 0), (18, 'Santa María', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (19, 1, '¿Qué líder indio promovió la resistencia no violenta contra el dominio británico?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (19, 'Mahatma Gandhi', 1), (19, 'Jawaharlal Nehru', 0), (19, 'Indira Gandhi', 0), (19, 'Nelson Mandela', 0), (19, 'Martin Luther King', 0), (19, 'El dalái lama', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (20, 1, '¿Qué ciudad romana quedó sepultada por la erupción del Vesubio en el año 79?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (20, 'Pompeya', 1), (20, 'Roma', 0), (20, 'Atenas', 0), (20, 'Cartago', 0), (20, 'Troya', 0), (20, 'Esparta', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (21, 1, '¿Qué emperador francés fue derrotado en la batalla de Waterloo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (21, 'Napoleón Bonaparte', 1), (21, 'Luis XIV', 0), (21, 'Carlomagno', 0), (21, 'Luis XVI', 0), (21, 'Napoleón III', 0), (21, 'Robespierre', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (22, 1, '¿En qué año se disolvió la Unión Soviética?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (22, '1991', 1), (22, '1989', 0), (22, '1985', 0), (22, '1993', 0), (22, '1979', 0), (22, '1999', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (23, 1, '¿Qué civilización construyó las pirámides de Giza?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (23, 'Egipcia', 1), (23, 'Mesopotámica', 0), (23, 'Griega', 0), (23, 'Romana', 0), (23, 'Persa', 0), (23, 'Fenicia', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (24, 1, '¿Qué muralla se construyó para proteger a China de las invasiones del norte?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (24, 'La Gran Muralla', 1), (24, 'El Muro de Adriano', 0), (24, 'El Muro de Berlín', 0), (24, 'La Muralla de Ávila', 0), (24, 'El Muro de las Lamentaciones', 0), (24, 'La Muralla de Constantinopla', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (25, 1, '¿Quién fue el primer presidente negro de Sudáfrica?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (25, 'Nelson Mandela', 1), (25, 'Desmond Tutu', 0), (25, 'Kofi Annan', 0), (25, 'Jomo Kenyatta', 0), (25, 'Haile Selassie', 0), (25, 'Patrice Lumumba', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (26, 1, '¿En qué año ocurrió la Guerra de Malvinas?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (26, '1982', 1), (26, '1978', 0), (26, '1986', 0), (26, '1976', 0), (26, '1990', 0), (26, '1974', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (27, 1, '¿Qué período histórico siguió a la Edad Media?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (27, 'La Edad Moderna', 1), (27, 'La Edad Antigua', 0), (27, 'La Prehistoria', 0), (27, 'La Edad Contemporánea', 0), (27, 'La Edad de Bronce', 0), (27, 'La Edad de Hierro', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (28, 1, '¿Qué hecho marca, por convención, el inicio de la Edad Media?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (28, 'La caída del Imperio romano de Occidente', 1), (28, 'El descubrimiento de América', 0), (28, 'La Revolución Francesa', 0), (28, 'La invención de la imprenta', 0), (28, 'La caída de Constantinopla', 0), (28, 'La Revolución Industrial', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (29, 1, '¿Quién inventó la imprenta de tipos móviles en Europa hacia 1450?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (29, 'Johannes Gutenberg', 1), (29, 'Leonardo da Vinci', 0), (29, 'Galileo Galilei', 0), (29, 'Martín Lutero', 0), (29, 'Isaac Newton', 0), (29, 'Nicolás Copérnico', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (30, 1, '¿Qué presidente argentino es conocido como «el padre del aula»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (30, 'Domingo F. Sarmiento', 1), (30, 'Bartolomé Mitre', 0), (30, 'Julio A. Roca', 0), (30, 'Hipólito Yrigoyen', 0), (30, 'Bernardino Rivadavia', 0), (30, 'Nicolás Avellaneda', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (31, 1, '¿Qué ciudad de la antigua Grecia era famosa por su sociedad militar?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (31, 'Esparta', 1), (31, 'Atenas', 0), (31, 'Corinto', 0), (31, 'Tebas', 0), (31, 'Delfos', 0), (31, 'Olimpia', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (32, 1, '¿Qué reina de Egipto fue aliada de Julio César y de Marco Antonio?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (32, 'Cleopatra', 1), (32, 'Nefertiti', 0), (32, 'Hatshepsut', 0), (32, 'Isis', 0), (32, 'Berenice', 0), (32, 'Nefertari', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (33, 1, '¿Qué conquistador español derrotó al Imperio inca?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (33, 'Francisco Pizarro', 1), (33, 'Hernán Cortés', 0), (33, 'Pedro de Mendoza', 0), (33, 'Juan de Garay', 0), (33, 'Vasco Núñez de Balboa', 0), (33, 'Juan Díaz de Solís', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (34, 1, '¿Qué hecho de 1929 desató la Gran Depresión?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (34, 'La caída de la Bolsa de Nueva York', 1), (34, 'La Primera Guerra Mundial', 0), (34, 'La Revolución Rusa', 0), (34, 'La Guerra Civil Española', 0), (34, 'El Plan Marshall', 0), (34, 'La crisis del petróleo', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (35, 1, '¿Qué movimiento religioso inició Martín Lutero en 1517?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (35, 'La Reforma protestante', 1), (35, 'La Contrarreforma', 0), (35, 'El Cisma de Oriente', 0), (35, 'La Ilustración', 0), (35, 'El Renacimiento', 0), (35, 'Las Cruzadas', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (36, 1, '¿Quién fue el primer ser humano en viajar al espacio, en 1961?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (36, 'Yuri Gagarin', 1), (36, 'Neil Armstrong', 0), (36, 'Buzz Aldrin', 0), (36, 'John Glenn', 0), (36, 'Alan Shepard', 0), (36, 'Valentina Tereshkova', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (37, 1, '¿Qué expedición completó la primera vuelta al mundo, terminada en 1522?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (37, 'La de Magallanes y Elcano', 1), (37, 'La de Cristóbal Colón', 0), (37, 'La de Vasco da Gama', 0), (37, 'La de James Cook', 0), (37, 'La de Francis Drake', 0), (37, 'La de Américo Vespucio', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (38, 1, '¿En qué año se sancionó la Constitución Nacional argentina?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (38, '1853', 1), (38, '1816', 0), (38, '1810', 0), (38, '1880', 0), (38, '1826', 0), (38, '1949', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (39, 1, '¿Qué pueblo construyó la ciudad de Chichén Itzá?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (39, 'Maya', 1), (39, 'Azteca', 0), (39, 'Inca', 0), (39, 'Olmeca', 0), (39, 'Mapuche', 0), (39, 'Guaraní', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (40, 1, '¿Cómo se llamó el enfrentamiento entre Estados Unidos y la URSS sin combate directo entre ellos?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (40, 'Guerra Fría', 1), (40, 'Guerra de Corea', 0), (40, 'Guerra de Vietnam', 0), (40, 'Guerra de los Cien Años', 0), (40, 'Guerra del Golfo', 0), (40, 'Gran Guerra', 0);

-- Geografía
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (41, 2, '¿Cuál es la capital de Australia?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (41, 'Canberra', 1), (41, 'Sídney', 0), (41, 'Melbourne', 0), (41, 'Perth', 0), (41, 'Brisbane', 0), (41, 'Adelaida', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (42, 2, '¿Cuál es el río más caudaloso del mundo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (42, 'Amazonas', 1), (42, 'Nilo', 0), (42, 'Misisipi', 0), (42, 'Yangtsé', 0), (42, 'Paraná', 0), (42, 'Congo', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (43, 2, '¿Cuál es la montaña más alta de América?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (43, 'Aconcagua', 1), (43, 'Ojos del Salado', 0), (43, 'Chimborazo', 0), (43, 'Denali', 0), (43, 'Huascarán', 0), (43, 'Cotopaxi', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (44, 2, '¿Cuál es el país más grande del mundo por superficie?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (44, 'Rusia', 1), (44, 'Canadá', 0), (44, 'China', 0), (44, 'Estados Unidos', 0), (44, 'Brasil', 0), (44, 'Australia', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (45, 2, '¿Cuál es la capital de Canadá?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (45, 'Ottawa', 1), (45, 'Toronto', 0), (45, 'Montreal', 0), (45, 'Vancouver', 0), (45, 'Quebec', 0), (45, 'Calgary', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (46, 2, '¿Cuál es el océano más grande del planeta?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (46, 'Pacífico', 1), (46, 'Atlántico', 0), (46, 'Índico', 0), (46, 'Ártico', 0), (46, 'Antártico', 0), (46, 'Mediterráneo', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (47, 2, '¿En qué país están las pirámides de Giza?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (47, 'Egipto', 1), (47, 'México', 0), (47, 'Sudán', 0), (47, 'Perú', 0), (47, 'Irak', 0), (47, 'Jordania', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (48, 2, '¿Cuál es el desierto no polar más árido del mundo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (48, 'Atacama', 1), (48, 'Sahara', 0), (48, 'Gobi', 0), (48, 'Kalahari', 0), (48, 'Namib', 0), (48, 'Mojave', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (49, 2, '¿Qué país tiene forma de bota?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (49, 'Italia', 1), (49, 'Grecia', 0), (49, 'Portugal', 0), (49, 'Croacia', 0), (49, 'Chile', 0), (49, 'España', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (50, 2, '¿Cuál es la capital de Japón?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (50, 'Tokio', 1), (50, 'Osaka', 0), (50, 'Kioto', 0), (50, 'Seúl', 0), (50, 'Pekín', 0), (50, 'Hiroshima', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (51, 2, '¿Cuál es la capital de Brasil?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (51, 'Brasilia', 1), (51, 'Río de Janeiro', 0), (51, 'San Pablo', 0), (51, 'Salvador', 0), (51, 'Belo Horizonte', 0), (51, 'Recife', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (52, 2, '¿Cuál es la capital de Uruguay?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (52, 'Montevideo', 1), (52, 'Punta del Este', 0), (52, 'Colonia del Sacramento', 0), (52, 'Salto', 0), (52, 'Paysandú', 0), (52, 'Maldonado', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (53, 2, '¿Cuál es la capital de Chile?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (53, 'Santiago', 1), (53, 'Valparaíso', 0), (53, 'Concepción', 0), (53, 'Viña del Mar', 0), (53, 'Antofagasta', 0), (53, 'La Serena', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (54, 2, '¿En qué continente está Egipto?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (54, 'África', 1), (54, 'Asia', 0), (54, 'Europa', 0), (54, 'Oceanía', 0), (54, 'América', 0), (54, 'Antártida', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (55, 2, '¿Cuál es el país más poblado de Sudamérica?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (55, 'Brasil', 1), (55, 'Argentina', 0), (55, 'Colombia', 0), (55, 'Perú', 0), (55, 'Venezuela', 0), (55, 'Chile', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (56, 2, '¿Qué cordillera recorre todo el oeste de Sudamérica?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (56, 'Los Andes', 1), (56, 'El Himalaya', 0), (56, 'Los Alpes', 0), (56, 'Las Montañas Rocosas', 0), (56, 'Los Urales', 0), (56, 'Los Pirineos', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (57, 2, '¿Cuál es la montaña más alta del mundo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (57, 'El Everest', 1), (57, 'El K2', 0), (57, 'El Aconcagua', 0), (57, 'El Kilimanjaro', 0), (57, 'El Mont Blanc', 0), (57, 'El Makalu', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (58, 2, '¿Cuál es el desierto cálido más grande del mundo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (58, 'Sahara', 1), (58, 'Gobi', 0), (58, 'Atacama', 0), (58, 'Kalahari', 0), (58, 'Arábigo', 0), (58, 'Mojave', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (59, 2, '¿Cuál es la capital de Perú?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (59, 'Lima', 1), (59, 'Cusco', 0), (59, 'Arequipa', 0), (59, 'Trujillo', 0), (59, 'La Paz', 0), (59, 'Quito', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (60, 2, '¿Cuál es la capital de Colombia?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (60, 'Bogotá', 1), (60, 'Medellín', 0), (60, 'Cali', 0), (60, 'Cartagena', 0), (60, 'Barranquilla', 0), (60, 'Caracas', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (61, 2, '¿Cuál es la capital de Francia?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (61, 'París', 1), (61, 'Lyon', 0), (61, 'Marsella', 0), (61, 'Niza', 0), (61, 'Burdeos', 0), (61, 'Bruselas', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (62, 2, '¿Qué río atraviesa la ciudad de Londres?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (62, 'Támesis', 1), (62, 'Sena', 0), (62, 'Danubio', 0), (62, 'Rin', 0), (62, 'Tíber', 0), (62, 'Elba', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (63, 2, '¿Qué río atraviesa la ciudad de París?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (63, 'Sena', 1), (63, 'Támesis', 0), (63, 'Loira', 0), (63, 'Rin', 0), (63, 'Ródano', 0), (63, 'Danubio', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (64, 2, '¿En qué provincia argentina están las Cataratas del Iguazú?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (64, 'Misiones', 1), (64, 'Corrientes', 0), (64, 'Entre Ríos', 0), (64, 'Salta', 0), (64, 'Jujuy', 0), (64, 'Chaco', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (65, 2, '¿Cuál es la provincia más austral de Argentina?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (65, 'Tierra del Fuego', 1), (65, 'Santa Cruz', 0), (65, 'Chubut', 0), (65, 'Río Negro', 0), (65, 'Neuquén', 0), (65, 'La Pampa', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (66, 2, '¿Qué famoso glaciar se encuentra en el Parque Nacional Los Glaciares, en Santa Cruz?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (66, 'Perito Moreno', 1), (66, 'Aletsch', 0), (66, 'Vatnajökull', 0), (66, 'Hubbard', 0), (66, 'Mer de Glace', 0), (66, 'Glaciar Grey', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (67, 2, '¿Qué océano baña la costa de Argentina?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (67, 'Atlántico', 1), (67, 'Pacífico', 0), (67, 'Índico', 0), (67, 'Ártico', 0), (67, 'Mar Caribe', 0), (67, 'Mediterráneo', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (68, 2, '¿Cuál es el país más pequeño del mundo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (68, 'Ciudad del Vaticano', 1), (68, 'Mónaco', 0), (68, 'San Marino', 0), (68, 'Liechtenstein', 0), (68, 'Malta', 0), (68, 'Andorra', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (69, 2, '¿Cuál es la capital de Alemania?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (69, 'Berlín', 1), (69, 'Múnich', 0), (69, 'Hamburgo', 0), (69, 'Fráncfort', 0), (69, 'Bonn', 0), (69, 'Viena', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (70, 2, '¿Cuál es la capital de Egipto?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (70, 'El Cairo', 1), (70, 'Alejandría', 0), (70, 'Luxor', 0), (70, 'Giza', 0), (70, 'Asuán', 0), (70, 'Túnez', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (71, 2, '¿En qué país se encuentra el Taj Mahal?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (71, 'India', 1), (71, 'Pakistán', 0), (71, 'Nepal', 0), (71, 'Bangladés', 0), (71, 'Irán', 0), (71, 'Egipto', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (72, 2, '¿Qué país es conocido como «la tierra del sol naciente»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (72, 'Japón', 1), (72, 'China', 0), (72, 'Corea del Sur', 0), (72, 'Tailandia', 0), (72, 'Vietnam', 0), (72, 'Filipinas', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (73, 2, '¿Qué lago, compartido por Perú y Bolivia, es el lago navegable más alto del mundo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (73, 'Titicaca', 1), (73, 'Victoria', 0), (73, 'Baikal', 0), (73, 'Tanganica', 0), (73, 'Nahuel Huapi', 0), (73, 'Superior', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (74, 2, '¿Cuál es el lago más profundo del mundo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (74, 'Baikal', 1), (74, 'Titicaca', 0), (74, 'Tanganica', 0), (74, 'Superior', 0), (74, 'Victoria', 0), (74, 'Caspio', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (75, 2, '¿Qué paso marítimo separa Sudamérica de la Antártida?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (75, 'El pasaje de Drake', 1), (75, 'El estrecho de Gibraltar', 0), (75, 'El canal de Panamá', 0), (75, 'El estrecho de Bering', 0), (75, 'El canal de la Mancha', 0), (75, 'El estrecho de Ormuz', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (76, 2, '¿Qué canal une los océanos Atlántico y Pacífico en Centroamérica?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (76, 'El canal de Panamá', 1), (76, 'El canal de Suez', 0), (76, 'El canal de Kiel', 0), (76, 'El canal de Corinto', 0), (76, 'El canal de la Mancha', 0), (76, 'El canal Beagle', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (77, 2, '¿Cuál es la capital de Italia?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (77, 'Roma', 1), (77, 'Milán', 0), (77, 'Venecia', 0), (77, 'Florencia', 0), (77, 'Nápoles', 0), (77, 'Turín', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (78, 2, '¿Cuál es la capital de España?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (78, 'Madrid', 1), (78, 'Barcelona', 0), (78, 'Sevilla', 0), (78, 'Valencia', 0), (78, 'Bilbao', 0), (78, 'Lisboa', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (79, 2, '¿Qué línea imaginaria divide la Tierra en hemisferio norte y hemisferio sur?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (79, 'El ecuador', 1), (79, 'El meridiano de Greenwich', 0), (79, 'El trópico de Cáncer', 0), (79, 'El trópico de Capricornio', 0), (79, 'El círculo polar ártico', 0), (79, 'La línea internacional de cambio de fecha', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (80, 2, '¿Cuál es la capital de México?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (80, 'Ciudad de México', 1), (80, 'Guadalajara', 0), (80, 'Monterrey', 0), (80, 'Cancún', 0), (80, 'Puebla', 0), (80, 'Tijuana', 0);

-- Ciencia
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (81, 3, '¿Cuál es el símbolo químico del oro?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (81, 'Au', 1), (81, 'Ag', 0), (81, 'Or', 0), (81, 'Go', 0), (81, 'Fe', 0), (81, 'Ao', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (82, 3, '¿Cuál es el planeta más grande del sistema solar?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (82, 'Júpiter', 1), (82, 'Saturno', 0), (82, 'Neptuno', 0), (82, 'Tierra', 0), (82, 'Urano', 0), (82, 'Marte', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (83, 3, '¿Qué gas absorben las plantas para hacer la fotosíntesis?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (83, 'Dióxido de carbono', 1), (83, 'Oxígeno', 0), (83, 'Nitrógeno', 0), (83, 'Hidrógeno', 0), (83, 'Helio', 0), (83, 'Metano', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (84, 3, '¿Cuántos huesos tiene el cuerpo humano adulto?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (84, '206', 1), (84, '201', 0), (84, '212', 0), (84, '198', 0), (84, '230', 0), (84, '186', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (85, 3, '¿Cuál es la velocidad aproximada de la luz en el vacío?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (85, '300.000 km/s', 1), (85, '150.000 km/s', 0), (85, '30.000 km/s', 0), (85, '1.000.000 km/s', 0), (85, '3.000 km/s', 0), (85, '3.000.000 km/s', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (86, 3, '¿Cuál es la fórmula química del agua?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (86, 'H₂O', 1), (86, 'CO₂', 0), (86, 'O₂', 0), (86, 'H₂O₂', 0), (86, 'NaCl', 0), (86, 'HO₂', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (87, 3, '¿Quién formuló la teoría de la relatividad?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (87, 'Albert Einstein', 1), (87, 'Isaac Newton', 0), (87, 'Nikola Tesla', 0), (87, 'Galileo Galilei', 0), (87, 'Stephen Hawking', 0), (87, 'Marie Curie', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (88, 3, '¿Qué órgano bombea la sangre por el cuerpo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (88, 'Corazón', 1), (88, 'Hígado', 0), (88, 'Pulmón', 0), (88, 'Riñón', 0), (88, 'Cerebro', 0), (88, 'Estómago', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (89, 3, '¿Qué planeta es conocido como el «planeta rojo»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (89, 'Marte', 1), (89, 'Venus', 0), (89, 'Mercurio', 0), (89, 'Júpiter', 0), (89, 'Saturno', 0), (89, 'Neptuno', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (90, 3, '¿Qué partícula del átomo tiene carga negativa?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (90, 'Electrón', 1), (90, 'Protón', 0), (90, 'Neutrón', 0), (90, 'Fotón', 0), (90, 'Positrón', 0), (90, 'Neutrino', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (91, 3, '¿Cuál es el gas más abundante en la atmósfera terrestre?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (91, 'Nitrógeno', 1), (91, 'Oxígeno', 0), (91, 'Dióxido de carbono', 0), (91, 'Argón', 0), (91, 'Hidrógeno', 0), (91, 'Helio', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (92, 3, '¿Cuál es el planeta más cercano al Sol?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (92, 'Mercurio', 1), (92, 'Venus', 0), (92, 'Tierra', 0), (92, 'Marte', 0), (92, 'Júpiter', 0), (92, 'Neptuno', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (93, 3, '¿Cuántos planetas tiene el sistema solar?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (93, '8', 1), (93, '9', 0), (93, '7', 0), (93, '10', 0), (93, '12', 0), (93, '6', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (94, 3, '¿Cuál es el símbolo químico del sodio?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (94, 'Na', 1), (94, 'So', 0), (94, 'Sd', 0), (94, 'N', 0), (94, 'S', 0), (94, 'Sn', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (95, 3, '¿Cuál es el símbolo químico del hierro?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (95, 'Fe', 1), (95, 'Hi', 0), (95, 'Ir', 0), (95, 'F', 0), (95, 'He', 0), (95, 'H', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (96, 3, '¿A qué temperatura hierve el agua a nivel del mar?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (96, '100 °C', 1), (96, '90 °C', 0), (96, '80 °C', 0), (96, '120 °C', 0), (96, '212 °C', 0), (96, '50 °C', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (97, 3, '¿Qué órgano produce la insulina?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (97, 'Páncreas', 1), (97, 'Hígado', 0), (97, 'Riñón', 0), (97, 'Estómago', 0), (97, 'Bazo', 0), (97, 'Vesícula', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (98, 3, '¿Cuál es el órgano más grande del cuerpo humano?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (98, 'La piel', 1), (98, 'El hígado', 0), (98, 'El cerebro', 0), (98, 'El intestino', 0), (98, 'Los pulmones', 0), (98, 'El corazón', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (99, 3, '¿Qué científico propuso la teoría de la evolución por selección natural?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (99, 'Charles Darwin', 1), (99, 'Gregor Mendel', 0), (99, 'Louis Pasteur', 0), (99, 'Jean-Baptiste Lamarck', 0), (99, 'Isaac Newton', 0), (99, 'Alexander Fleming', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (100, 3, '¿Quién descubrió la penicilina en 1928?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (100, 'Alexander Fleming', 1), (100, 'Louis Pasteur', 0), (100, 'Marie Curie', 0), (100, 'Robert Koch', 0), (100, 'Edward Jenner', 0), (100, 'Joseph Lister', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (101, 3, '¿Qué parte de la célula contiene el material genético principal?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (101, 'El núcleo', 1), (101, 'La membrana', 0), (101, 'El ribosoma', 0), (101, 'El citoplasma', 0), (101, 'La vacuola', 0), (101, 'La pared celular', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (102, 3, '¿Cuál es la unidad de fuerza en el Sistema Internacional?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (102, 'Newton', 1), (102, 'Joule', 0), (102, 'Watt', 0), (102, 'Pascal', 0), (102, 'Kelvin', 0), (102, 'Amperio', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (103, 3, '¿Cuál es el número atómico del hidrógeno?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (103, '1', 1), (103, '2', 0), (103, '0', 0), (103, '3', 0), (103, '8', 0), (103, '6', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (104, 3, '¿Qué planeta tiene los anillos más visibles del sistema solar?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (104, 'Saturno', 1), (104, 'Júpiter', 0), (104, 'Urano', 0), (104, 'Neptuno', 0), (104, 'Marte', 0), (104, 'Venus', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (105, 3, '¿Cómo se llama la galaxia en la que está la Tierra?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (105, 'Vía Láctea', 1), (105, 'Andrómeda', 0), (105, 'Triángulo', 0), (105, 'Sombrero', 0), (105, 'Remolino', 0), (105, 'Gran Nube de Magallanes', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (106, 3, '¿Cuántos cromosomas tiene normalmente una célula humana?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (106, '46', 1), (106, '23', 0), (106, '44', 0), (106, '48', 0), (106, '42', 0), (106, '92', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (107, 3, '¿Qué grupo sanguíneo se considera donante universal?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (107, '0 negativo', 1), (107, 'AB positivo', 0), (107, 'A positivo', 0), (107, 'B negativo', 0), (107, 'AB negativo', 0), (107, '0 positivo', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (108, 3, '¿Qué vitamina produce el cuerpo al exponerse al sol?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (108, 'Vitamina D', 1), (108, 'Vitamina C', 0), (108, 'Vitamina A', 0), (108, 'Vitamina B12', 0), (108, 'Vitamina K', 0), (108, 'Vitamina E', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (109, 3, '¿Qué metal es líquido a temperatura ambiente?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (109, 'Mercurio', 1), (109, 'Plomo', 0), (109, 'Aluminio', 0), (109, 'Estaño', 0), (109, 'Zinc', 0), (109, 'Hierro', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (110, 3, '¿Qué científica ganó dos premios Nobel en ciencias distintas?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (110, 'Marie Curie', 1), (110, 'Rosalind Franklin', 0), (110, 'Ada Lovelace', 0), (110, 'Lise Meitner', 0), (110, 'Dorothy Hodgkin', 0), (110, 'Jane Goodall', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (111, 3, '¿Cuál es la estrella más cercana a la Tierra?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (111, 'El Sol', 1), (111, 'Próxima Centauri', 0), (111, 'Sirio', 0), (111, 'Betelgeuse', 0), (111, 'Polaris', 0), (111, 'Vega', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (112, 3, '¿Qué fuerza mantiene a los planetas en órbita alrededor del Sol?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (112, 'La gravedad', 1), (112, 'El magnetismo', 0), (112, 'La fricción', 0), (112, 'La fuerza nuclear débil', 0), (112, 'La fuerza centrífuga', 0), (112, 'La electricidad estática', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (113, 3, '¿Cómo se llama el paso de sólido a líquido?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (113, 'Fusión', 1), (113, 'Evaporación', 0), (113, 'Condensación', 0), (113, 'Sublimación', 0), (113, 'Solidificación', 0), (113, 'Ebullición', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (114, 3, '¿Cuál es el pH del agua pura a 25 °C?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (114, '7', 1), (114, '0', 0), (114, '14', 0), (114, '1', 0), (114, '10', 0), (114, '5', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (115, 3, '¿Cuál es el mamífero más grande del mundo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (115, 'La ballena azul', 1), (115, 'El elefante africano', 0), (115, 'El cachalote', 0), (115, 'La jirafa', 0), (115, 'El hipopótamo', 0), (115, 'La orca', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (116, 3, '¿Cuántas patas tiene una araña?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (116, '8', 1), (116, '6', 0), (116, '10', 0), (116, '4', 0), (116, '12', 0), (116, '7', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (117, 3, '¿Qué gas eliminamos al exhalar como desecho de la respiración?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (117, 'Dióxido de carbono', 1), (117, 'Oxígeno', 0), (117, 'Nitrógeno', 0), (117, 'Helio', 0), (117, 'Hidrógeno', 0), (117, 'Ozono', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (118, 3, '¿Quién formuló las leyes del movimiento y la ley de gravitación universal?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (118, 'Isaac Newton', 1), (118, 'Galileo Galilei', 0), (118, 'Albert Einstein', 0), (118, 'Johannes Kepler', 0), (118, 'Nicolás Copérnico', 0), (118, 'Nikola Tesla', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (119, 3, '¿Qué partícula del átomo no tiene carga eléctrica?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (119, 'Neutrón', 1), (119, 'Protón', 0), (119, 'Electrón', 0), (119, 'Positrón', 0), (119, 'Ion', 0), (119, 'Muon', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (120, 3, '¿Cuál es la capa de la atmósfera más cercana a la superficie terrestre?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (120, 'Troposfera', 1), (120, 'Estratosfera', 0), (120, 'Mesosfera', 0), (120, 'Termosfera', 0), (120, 'Exosfera', 0), (120, 'Ionosfera', 0);

-- Deportes
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (121, 4, '¿Cuántos jugadores tiene un equipo de fútbol en la cancha?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (121, '11', 1), (121, '10', 0), (121, '9', 0), (121, '12', 0), (121, '7', 0), (121, '8', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (122, 4, '¿Qué selección ganó el Mundial de Fútbol 2022?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (122, 'Argentina', 1), (122, 'Francia', 0), (122, 'Brasil', 0), (122, 'Croacia', 0), (122, 'Alemania', 0), (122, 'España', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (123, 4, '¿Cada cuántos años se celebran los Juegos Olímpicos de verano?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (123, '4', 1), (123, '2', 0), (123, '3', 0), (123, '5', 0), (123, '6', 0), (123, '8', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (124, 4, '¿Cuántos puntos vale un triple en el básquet?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (124, '3', 1), (124, '2', 0), (124, '1', 0), (124, '4', 0), (124, '5', 0), (124, '6', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (125, 4, '¿En qué país se originó el rugby?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (125, 'Inglaterra', 1), (125, 'Nueva Zelanda', 0), (125, 'Francia', 0), (125, 'Sudáfrica', 0), (125, 'Australia', 0), (125, 'Escocia', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (126, 4, '¿Cuántos sets hay que ganar en un partido masculino de Grand Slam?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (126, '3', 1), (126, '2', 0), (126, '4', 0), (126, '5', 0), (126, '1', 0), (126, '6', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (127, 4, '¿Qué selección ganó más Copas del Mundo de fútbol masculino?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (127, 'Brasil', 1), (127, 'Alemania', 0), (127, 'Italia', 0), (127, 'Argentina', 0), (127, 'Uruguay', 0), (127, 'Francia', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (128, 4, '¿Cuánto mide una maratón?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (128, '42,195 km', 1), (128, '40 km', 0), (128, '21,097 km', 0), (128, '45 km', 0), (128, '50 km', 0), (128, '38,5 km', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (129, 4, '¿En qué deporte se destacó Michael Phelps?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (129, 'Natación', 1), (129, 'Atletismo', 0), (129, 'Ciclismo', 0), (129, 'Remo', 0), (129, 'Gimnasia', 0), (129, 'Tenis', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (130, 4, '¿De qué color es la camiseta del líder del Tour de Francia?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (130, 'Amarilla', 1), (130, 'Verde', 0), (130, 'Rosa', 0), (130, 'Blanca', 0), (130, 'Roja', 0), (130, 'Azul', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (131, 4, '¿Cuántos jugadores tiene un equipo de básquet en la cancha?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (131, '5', 1), (131, '6', 0), (131, '7', 0), (131, '4', 0), (131, '11', 0), (131, '9', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (132, 4, '¿Cuántos jugadores tiene un equipo de vóley en la cancha?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (132, '6', 1), (132, '5', 0), (132, '7', 0), (132, '9', 0), (132, '11', 0), (132, '4', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (133, 4, '¿Cuánto dura un partido de fútbol profesional sin tiempo extra ni descuento?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (133, '90 minutos', 1), (133, '80 minutos', 0), (133, '100 minutos', 0), (133, '120 minutos', 0), (133, '70 minutos', 0), (133, '60 minutos', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (134, 4, '¿En qué país se jugó el primer Mundial de fútbol, en 1930?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (134, 'Uruguay', 1), (134, 'Brasil', 0), (134, 'Argentina', 0), (134, 'Italia', 0), (134, 'Francia', 0), (134, 'Inglaterra', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (135, 4, '¿Quién fue el capitán de Argentina en el Mundial 2022?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (135, 'Lionel Messi', 1), (135, 'Ángel Di María', 0), (135, 'Emiliano Martínez', 0), (135, 'Nicolás Otamendi', 0), (135, 'Rodrigo De Paul', 0), (135, 'Julián Álvarez', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (136, 4, '¿En qué año ganó Argentina su primer Mundial de fútbol?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (136, '1978', 1), (136, '1986', 0), (136, '1974', 0), (136, '1930', 0), (136, '1990', 0), (136, '2022', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (137, 4, '¿Quién marcó el gol conocido como «la mano de Dios» en México 86?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (137, 'Diego Maradona', 1), (137, 'Jorge Valdano', 0), (137, 'Jorge Burruchaga', 0), (137, 'Mario Kempes', 0), (137, 'Gabriel Batistuta', 0), (137, 'Daniel Passarella', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (138, 4, '¿En qué deporte se usa un disco llamado «puck»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (138, 'Hockey sobre hielo', 1), (138, 'Curling', 0), (138, 'Polo', 0), (138, 'Lacrosse', 0), (138, 'Hockey sobre césped', 0), (138, 'Bádminton', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (139, 4, '¿Cuántos puntos vale un try en el rugby de 15?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (139, '5', 1), (139, '3', 0), (139, '4', 0), (139, '6', 0), (139, '7', 0), (139, '2', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (140, 4, '¿En qué deporte se destacó Manu Ginóbili?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (140, 'Básquet', 1), (140, 'Tenis', 0), (140, 'Fútbol', 0), (140, 'Vóley', 0), (140, 'Rugby', 0), (140, 'Hockey', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (141, 4, '¿Qué tenista argentino ganó el US Open en 2009?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (141, 'Juan Martín del Potro', 1), (141, 'Guillermo Vilas', 0), (141, 'David Nalbandian', 0), (141, 'Gastón Gaudio', 0), (141, 'Diego Schwartzman', 0), (141, 'Juan Mónaco', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (142, 4, '¿En qué país se juega el torneo de tenis Roland Garros?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (142, 'Francia', 1), (142, 'Inglaterra', 0), (142, 'Estados Unidos', 0), (142, 'Australia', 0), (142, 'España', 0), (142, 'Italia', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (143, 4, '¿Sobre qué superficie se juega el torneo de Wimbledon?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (143, 'Césped', 1), (143, 'Polvo de ladrillo', 0), (143, 'Cemento', 0), (143, 'Madera', 0), (143, 'Moqueta', 0), (143, 'Arena', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (144, 4, '¿Cuántos anillos tiene la bandera olímpica?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (144, '5', 1), (144, '4', 0), (144, '6', 0), (144, '7', 0), (144, '3', 0), (144, '8', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (145, 4, '¿En qué ciudad se hicieron los Juegos Olímpicos de 2016?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (145, 'Río de Janeiro', 1), (145, 'Londres', 0), (145, 'Tokio', 0), (145, 'Pekín', 0), (145, 'Atenas', 0), (145, 'París', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (146, 4, '¿Qué apodo tiene la selección argentina de hockey femenino?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (146, 'Las Leonas', 1), (146, 'Las Panteras', 0), (146, 'Las Pumas', 0), (146, 'Las Lobas', 0), (146, 'Las Águilas', 0), (146, 'Las Tigresas', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (147, 4, '¿Qué apodo tiene la selección argentina de rugby?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (147, 'Los Pumas', 1), (147, 'Los Cóndores', 0), (147, 'Los Toros', 0), (147, 'Los Lobos', 0), (147, 'Los Halcones', 0), (147, 'Los Gauchos', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (148, 4, '¿Cuántos hoyos tiene un recorrido de golf completo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (148, '18', 1), (148, '9', 0), (148, '12', 0), (148, '20', 0), (148, '24', 0), (148, '16', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (149, 4, '¿En qué deporte se puede batear un «home run»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (149, 'Béisbol', 1), (149, 'Críquet', 0), (149, 'Golf', 0), (149, 'Rugby', 0), (149, 'Hockey', 0), (149, 'Polo', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (150, 4, '¿Qué piloto argentino ganó cinco campeonatos mundiales de Fórmula 1?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (150, 'Juan Manuel Fangio', 1), (150, 'Carlos Reutemann', 0), (150, 'José Froilán González', 0), (150, 'Franco Colapinto', 0), (150, 'Oscar Gálvez', 0), (150, 'Ayrton Senna', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (151, 4, '¿Cuánto mide de largo una pileta olímpica?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (151, '50 metros', 1), (151, '25 metros', 0), (151, '100 metros', 0), (151, '75 metros', 0), (151, '40 metros', 0), (151, '60 metros', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (152, 4, '¿Qué atleta jamaicano tiene el récord mundial de los 100 metros llanos (9,58 s)?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (152, 'Usain Bolt', 1), (152, 'Yohan Blake', 0), (152, 'Asafa Powell', 0), (152, 'Carl Lewis', 0), (152, 'Tyson Gay', 0), (152, 'Justin Gatlin', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (153, 4, '¿Cuántos jugadores tiene un equipo de rugby de 15 en la cancha?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (153, '15', 1), (153, '11', 0), (153, '13', 0), (153, '7', 0), (153, '12', 0), (153, '18', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (154, 4, '¿En qué deporte se compite por la Copa Davis?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (154, 'Tenis', 1), (154, 'Golf', 0), (154, 'Polo', 0), (154, 'Ciclismo', 0), (154, 'Básquet', 0), (154, 'Vóley', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (155, 4, '¿Qué club argentino es conocido como «el Xeneize»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (155, 'Boca Juniors', 1), (155, 'River Plate', 0), (155, 'Racing Club', 0), (155, 'Independiente', 0), (155, 'San Lorenzo', 0), (155, 'Vélez Sarsfield', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (156, 4, '¿Qué club argentino es conocido como «el Millonario»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (156, 'River Plate', 1), (156, 'Boca Juniors', 0), (156, 'Racing Club', 0), (156, 'Huracán', 0), (156, 'Estudiantes', 0), (156, 'Newell''s Old Boys', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (157, 4, '¿En qué juego se gana con un «jaque mate»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (157, 'Ajedrez', 1), (157, 'Damas', 0), (157, 'Póker', 0), (157, 'Go', 0), (157, 'Backgammon', 0), (157, 'Bridge', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (158, 4, '¿Cuántas piezas tiene cada jugador al empezar una partida de ajedrez?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (158, '16', 1), (158, '12', 0), (158, '18', 0), (158, '20', 0), (158, '14', 0), (158, '32', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (159, 4, '¿Qué selección ganó el primer Campeonato Sudamericano (hoy Copa América), en 1916?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (159, 'Uruguay', 1), (159, 'Argentina', 0), (159, 'Brasil', 0), (159, 'Chile', 0), (159, 'Paraguay', 0), (159, 'Perú', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (160, 4, '¿Qué deporte practicaba Luciana Aymar?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (160, 'Hockey sobre césped', 1), (160, 'Tenis', 0), (160, 'Vóley', 0), (160, 'Básquet', 0), (160, 'Natación', 0), (160, 'Atletismo', 0);

-- Arte y Letras
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (161, 5, '¿Quién pintó la Mona Lisa?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (161, 'Leonardo da Vinci', 1), (161, 'Miguel Ángel', 0), (161, 'Rafael', 0), (161, 'Botticelli', 0), (161, 'Caravaggio', 0), (161, 'Tiziano', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (162, 5, '¿Quién escribió «Don Quijote de la Mancha»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (162, 'Miguel de Cervantes', 1), (162, 'Lope de Vega', 0), (162, 'Francisco de Quevedo', 0), (162, 'Luis de Góngora', 0), (162, 'Calderón de la Barca', 0), (162, 'Garcilaso de la Vega', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (163, 5, '¿Quién escribió «Cien años de soledad»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (163, 'Gabriel García Márquez', 1), (163, 'Mario Vargas Llosa', 0), (163, 'Julio Cortázar', 0), (163, 'Jorge Luis Borges', 0), (163, 'Pablo Neruda', 0), (163, 'Isabel Allende', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (164, 5, '¿Quién pintó «La noche estrellada»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (164, 'Vincent van Gogh', 1), (164, 'Claude Monet', 0), (164, 'Pablo Picasso', 0), (164, 'Salvador Dalí', 0), (164, 'Paul Cézanne', 0), (164, 'Paul Gauguin', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (165, 5, '¿Quién es el autor de «Martín Fierro»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (165, 'José Hernández', 1), (165, 'Domingo F. Sarmiento', 0), (165, 'Jorge Luis Borges', 0), (165, 'Leopoldo Lugones', 0), (165, 'Esteban Echeverría', 0), (165, 'Estanislao del Campo', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (166, 5, '¿Quién escribió «Romeo y Julieta»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (166, 'William Shakespeare', 1), (166, 'Miguel de Cervantes', 0), (166, 'Dante Alighieri', 0), (166, 'Molière', 0), (166, 'Goethe', 0), (166, 'Christopher Marlowe', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (167, 5, '¿Quién pintó el «Guernica»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (167, 'Pablo Picasso', 1), (167, 'Salvador Dalí', 0), (167, 'Joan Miró', 0), (167, 'Francisco de Goya', 0), (167, 'Diego Velázquez', 0), (167, 'Frida Kahlo', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (168, 5, '¿Quién esculpió el «David» de mármol de Florencia (1504)?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (168, 'Miguel Ángel', 1), (168, 'Donatello', 0), (168, 'Gian Lorenzo Bernini', 0), (168, 'Auguste Rodin', 0), (168, 'Leonardo da Vinci', 0), (168, 'Benvenuto Cellini', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (169, 5, '¿Qué escritor argentino escribió «Rayuela»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (169, 'Julio Cortázar', 1), (169, 'Jorge Luis Borges', 0), (169, 'Ernesto Sabato', 0), (169, 'Adolfo Bioy Casares', 0), (169, 'Ricardo Piglia', 0), (169, 'Manuel Puig', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (170, 5, '¿Qué poeta chileno ganó el Premio Nobel de Literatura en 1971?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (170, 'Pablo Neruda', 1), (170, 'Gabriela Mistral', 0), (170, 'Vicente Huidobro', 0), (170, 'Nicanor Parra', 0), (170, 'Gonzalo Rojas', 0), (170, 'Octavio Paz', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (171, 5, '¿Quién escribió «El Aleph»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (171, 'Jorge Luis Borges', 1), (171, 'Julio Cortázar', 0), (171, 'Ernesto Sabato', 0), (171, 'Adolfo Bioy Casares', 0), (171, 'Leopoldo Lugones', 0), (171, 'Roberto Arlt', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (172, 5, '¿Quién escribió «El túnel»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (172, 'Ernesto Sabato', 1), (172, 'Jorge Luis Borges', 0), (172, 'Julio Cortázar', 0), (172, 'Manuel Puig', 0), (172, 'Roberto Arlt', 0), (172, 'Ricardo Güiraldes', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (173, 5, '¿Quién escribió «Don Segundo Sombra»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (173, 'Ricardo Güiraldes', 1), (173, 'José Hernández', 0), (173, 'Domingo F. Sarmiento', 0), (173, 'Esteban Echeverría', 0), (173, 'Leopoldo Lugones', 0), (173, 'Benito Lynch', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (174, 5, '¿Quién escribió «Facundo: civilización y barbarie»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (174, 'Domingo F. Sarmiento', 1), (174, 'Juan Bautista Alberdi', 0), (174, 'Bartolomé Mitre', 0), (174, 'Esteban Echeverría', 0), (174, 'José Hernández', 0), (174, 'José Mármol', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (175, 5, '¿Qué dibujante argentino creó a Mafalda?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (175, 'Quino', 1), (175, 'Roberto Fontanarrosa', 0), (175, 'Liniers', 0), (175, 'Caloi', 0), (175, 'Guillermo Divito', 0), (175, 'Landrú', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (176, 5, '¿A quién se le atribuye «La Odisea»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (176, 'Homero', 1), (176, 'Virgilio', 0), (176, 'Sófocles', 0), (176, 'Platón', 0), (176, 'Ovidio', 0), (176, 'Esopo', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (177, 5, '¿Quién escribió «La Divina Comedia»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (177, 'Dante Alighieri', 1), (177, 'Francesco Petrarca', 0), (177, 'Giovanni Boccaccio', 0), (177, 'Nicolás Maquiavelo', 0), (177, 'Virgilio', 0), (177, 'Homero', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (178, 5, '¿Quién pintó el techo de la Capilla Sixtina?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (178, 'Miguel Ángel', 1), (178, 'Rafael', 0), (178, 'Leonardo da Vinci', 0), (178, 'Sandro Botticelli', 0), (178, 'Caravaggio', 0), (178, 'Donatello', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (179, 5, '¿A qué movimiento artístico perteneció Salvador Dalí?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (179, 'Surrealismo', 1), (179, 'Cubismo', 0), (179, 'Impresionismo', 0), (179, 'Barroco', 0), (179, 'Expresionismo', 0), (179, 'Renacimiento', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (180, 5, '¿Qué pintor creó el cubismo junto a Georges Braque?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (180, 'Pablo Picasso', 1), (180, 'Salvador Dalí', 0), (180, 'Joan Miró', 0), (180, 'Claude Monet', 0), (180, 'Vincent van Gogh', 0), (180, 'Henri Matisse', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (181, 5, '¿Qué pintora mexicana es famosa por sus autorretratos y su ceja unida?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (181, 'Frida Kahlo', 1), (181, 'Remedios Varo', 0), (181, 'Tamara de Lempicka', 0), (181, 'Georgia O''Keeffe', 0), (181, 'Berthe Morisot', 0), (181, 'Leonora Carrington', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (182, 5, '¿Quién escribió la novela «1984»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (182, 'George Orwell', 1), (182, 'Aldous Huxley', 0), (182, 'Ray Bradbury', 0), (182, 'H. G. Wells', 0), (182, 'Julio Verne', 0), (182, 'Isaac Asimov', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (183, 5, '¿Quién escribió «El principito»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (183, 'Antoine de Saint-Exupéry', 1), (183, 'Julio Verne', 0), (183, 'Víctor Hugo', 0), (183, 'Albert Camus', 0), (183, 'Alejandro Dumas', 0), (183, 'Molière', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (184, 5, '¿Quién escribió «Los miserables»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (184, 'Víctor Hugo', 1), (184, 'Alejandro Dumas', 0), (184, 'Honoré de Balzac', 0), (184, 'Gustave Flaubert', 0), (184, 'Émile Zola', 0), (184, 'Stendhal', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (185, 5, '¿Quién escribió «Orgullo y prejuicio»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (185, 'Jane Austen', 1), (185, 'Charlotte Brontë', 0), (185, 'Emily Brontë', 0), (185, 'Virginia Woolf', 0), (185, 'Mary Shelley', 0), (185, 'Agatha Christie', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (186, 5, '¿Quién creó al detective Sherlock Holmes?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (186, 'Arthur Conan Doyle', 1), (186, 'Agatha Christie', 0), (186, 'Edgar Allan Poe', 0), (186, 'Charles Dickens', 0), (186, 'Raymond Chandler', 0), (186, 'G. K. Chesterton', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (187, 5, '¿Qué escritora creó al detective Hercule Poirot?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (187, 'Agatha Christie', 1), (187, 'Arthur Conan Doyle', 0), (187, 'P. D. James', 0), (187, 'Patricia Highsmith', 0), (187, 'Mary Shelley', 0), (187, 'J. K. Rowling', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (188, 5, '¿Quién escribió «Frankenstein»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (188, 'Mary Shelley', 1), (188, 'Bram Stoker', 0), (188, 'Edgar Allan Poe', 0), (188, 'Robert L. Stevenson', 0), (188, 'H. P. Lovecraft', 0), (188, 'Oscar Wilde', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (189, 5, '¿Quién escribió «Drácula»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (189, 'Bram Stoker', 1), (189, 'Mary Shelley', 0), (189, 'Edgar Allan Poe', 0), (189, 'Robert L. Stevenson', 0), (189, 'H. P. Lovecraft', 0), (189, 'Oscar Wilde', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (190, 5, '¿Quién pintó «El nacimiento de Venus»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (190, 'Sandro Botticelli', 1), (190, 'Rafael', 0), (190, 'Tiziano', 0), (190, 'Leonardo da Vinci', 0), (190, 'Miguel Ángel', 0), (190, 'Rubens', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (191, 5, '¿Quién pintó el mural «La última cena» en Milán?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (191, 'Leonardo da Vinci', 1), (191, 'Miguel Ángel', 0), (191, 'Rafael', 0), (191, 'Giotto', 0), (191, 'Caravaggio', 0), (191, 'Diego Velázquez', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (192, 5, '¿Qué pintor holandés pintó «La joven de la perla»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (192, 'Johannes Vermeer', 1), (192, 'Rembrandt', 0), (192, 'Vincent van Gogh', 0), (192, 'Rubens', 0), (192, 'Frans Hals', 0), (192, 'El Bosco', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (193, 5, '¿Quién pintó «Las Meninas» en 1656?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (193, 'Diego Velázquez', 1), (193, 'Francisco de Goya', 0), (193, 'El Greco', 0), (193, 'Bartolomé Murillo', 0), (193, 'Francisco de Zurbarán', 0), (193, 'Joaquín Sorolla', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (194, 5, '¿A qué movimiento artístico pertenece Claude Monet?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (194, 'Impresionismo', 1), (194, 'Cubismo', 0), (194, 'Surrealismo', 0), (194, 'Barroco', 0), (194, 'Romanticismo', 0), (194, 'Futurismo', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (195, 5, '¿Quién escribió «La casa de los espíritus»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (195, 'Isabel Allende', 1), (195, 'Gabriela Mistral', 0), (195, 'Laura Esquivel', 0), (195, 'Elena Poniatowska', 0), (195, 'Marcela Serrano', 0), (195, 'Gioconda Belli', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (196, 5, '¿Qué escritor peruano ganó el Premio Nobel de Literatura en 2010?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (196, 'Mario Vargas Llosa', 1), (196, 'Gabriel García Márquez', 0), (196, 'Octavio Paz', 0), (196, 'César Vallejo', 0), (196, 'Alfredo Bryce Echenique', 0), (196, 'José María Arguedas', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (197, 5, '¿Qué poeta chilena fue la primera persona latinoamericana en ganar el Nobel de Literatura, en 1945?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (197, 'Gabriela Mistral', 1), (197, 'Alfonsina Storni', 0), (197, 'Violeta Parra', 0), (197, 'Isabel Allende', 0), (197, 'Juana de Ibarbourou', 0), (197, 'Delmira Agustini', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (198, 5, '¿Quién escribió «Platero y yo»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (198, 'Juan Ramón Jiménez', 1), (198, 'Federico García Lorca', 0), (198, 'Antonio Machado', 0), (198, 'Miguel Hernández', 0), (198, 'Rafael Alberti', 0), (198, 'Gustavo Adolfo Bécquer', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (199, 5, '¿Quién escribió la obra de teatro «Bodas de sangre»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (199, 'Federico García Lorca', 1), (199, 'Juan Ramón Jiménez', 0), (199, 'Antonio Machado', 0), (199, 'Ramón del Valle-Inclán', 0), (199, 'Miguel de Unamuno', 0), (199, 'Pedro Calderón de la Barca', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (200, 5, '¿Qué escultor francés creó «El pensador»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (200, 'Auguste Rodin', 1), (200, 'Camille Claudel', 0), (200, 'Edgar Degas', 0), (200, 'Gian Lorenzo Bernini', 0), (200, 'Constantin Brancusi', 0), (200, 'Donatello', 0);

-- Entretenimiento
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (201, 6, '¿Cómo se llama el protagonista de Super Mario Bros. que usa gorra roja?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (201, 'Mario', 1), (201, 'Luigi', 0), (201, 'Wario', 0), (201, 'Link', 0), (201, 'Sonic', 0), (201, 'Yoshi', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (202, 6, '¿Qué película de James Cameron de 1997 ganó 11 premios Oscar?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (202, 'Titanic', 1), (202, 'Avatar', 0), (202, 'Terminator 2', 0), (202, 'Aliens', 0), (202, 'True Lies', 0), (202, 'The Abyss', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (203, 6, '¿Cómo se llamaba la banda de Freddie Mercury?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (203, 'Queen', 1), (203, 'The Beatles', 0), (203, 'Led Zeppelin', 0), (203, 'Pink Floyd', 0), (203, 'The Rolling Stones', 0), (203, 'AC/DC', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (204, 6, '¿En qué serie aparece el profesor de química Walter White?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (204, 'Breaking Bad', 1), (204, 'Los Soprano', 0), (204, 'Dexter', 0), (204, 'Lost', 0), (204, 'Prison Break', 0), (204, 'House', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (205, 6, '¿Qué personaje dice «Yo soy tu padre» en Star Wars?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (205, 'Darth Vader', 1), (205, 'Obi-Wan Kenobi', 0), (205, 'Yoda', 0), (205, 'Palpatine', 0), (205, 'Han Solo', 0), (205, 'Luke Skywalker', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (206, 6, '¿Quién es el mago protagonista de la saga de J. K. Rowling?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (206, 'Harry Potter', 1), (206, 'Gandalf', 0), (206, 'Merlín', 0), (206, 'Frodo', 0), (206, 'Dumbledore', 0), (206, 'Percy Jackson', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (207, 6, '¿En qué videojuego aparecen los bloques y los creepers?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (207, 'Minecraft', 1), (207, 'Fortnite', 0), (207, 'Roblox', 0), (207, 'Terraria', 0), (207, 'Among Us', 0), (207, 'Stardew Valley', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (208, 6, '¿Cómo se llama el león protagonista de «El Rey León»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (208, 'Simba', 1), (208, 'Mufasa', 0), (208, 'Scar', 0), (208, 'Nala', 0), (208, 'Timón', 0), (208, 'Rafiki', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (209, 6, '¿Qué cantante es conocido como el «Rey del Pop»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (209, 'Michael Jackson', 1), (209, 'Elvis Presley', 0), (209, 'Prince', 0), (209, 'Madonna', 0), (209, 'Freddie Mercury', 0), (209, 'Justin Timberlake', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (210, 6, '¿En qué ciudad vive la familia Simpson?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (210, 'Springfield', 1), (210, 'Shelbyville', 0), (210, 'Quahog', 0), (210, 'South Park', 0), (210, 'Ciudad Gótica', 0), (210, 'Arlen', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (211, 6, '¿Cómo se llama el muñeco vaquero de «Toy Story»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (211, 'Woody', 1), (211, 'Buzz Lightyear', 0), (211, 'Jessie', 0), (211, 'Rex', 0), (211, 'Hamm', 0), (211, 'Slinky', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (212, 6, '¿Qué superhéroe es en realidad Bruce Wayne?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (212, 'Batman', 1), (212, 'Superman', 0), (212, 'Spider-Man', 0), (212, 'Iron Man', 0), (212, 'Flash', 0), (212, 'Linterna Verde', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (213, 6, '¿Qué superhéroe es en realidad Peter Parker?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (213, 'Spider-Man', 1), (213, 'Batman', 0), (213, 'Iron Man', 0), (213, 'Capitán América', 0), (213, 'Hulk', 0), (213, 'Daredevil', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (214, 6, '¿Cómo se llama el ogro verde de DreamWorks que vive en un pantano?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (214, 'Shrek', 1), (214, 'Hulk', 0), (214, 'Fiona', 0), (214, 'Burro', 0), (214, 'Grinch', 0), (214, 'Gru', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (215, 6, '¿En qué serie aparecen Ross, Rachel, Monica y Joey?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (215, 'Friends', 1), (215, 'How I Met Your Mother', 0), (215, 'Seinfeld', 0), (215, 'The Office', 0), (215, 'The Big Bang Theory', 0), (215, 'Modern Family', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (216, 6, '¿Qué banda británica integraban John Lennon y Paul McCartney?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (216, 'The Beatles', 1), (216, 'The Rolling Stones', 0), (216, 'Queen', 0), (216, 'Pink Floyd', 0), (216, 'The Who', 0), (216, 'Oasis', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (217, 6, '¿Qué cantante grabó «Despacito» junto a Daddy Yankee?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (217, 'Luis Fonsi', 1), (217, 'Bad Bunny', 0), (217, 'J Balvin', 0), (217, 'Ozuna', 0), (217, 'Nicky Jam', 0), (217, 'Maluma', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (218, 6, '¿Qué banda lideraba el Indio Solari?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (218, 'Patricio Rey y sus Redonditos de Ricota', 1), (218, 'Soda Stereo', 0), (218, 'Los Fabulosos Cadillacs', 0), (218, 'Sumo', 0), (218, 'Divididos', 0), (218, 'Los Piojos', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (219, 6, '¿Quién fue el cantante y guitarrista de Soda Stereo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (219, 'Gustavo Cerati', 1), (219, 'Charly García', 0), (219, 'Luis Alberto Spinetta', 0), (219, 'Fito Páez', 0), (219, 'Andrés Calamaro', 0), (219, 'Ricardo Mollo', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (220, 6, '¿Qué película de Pixar tiene como protagonista a un pez payaso?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (220, 'Buscando a Nemo', 1), (220, 'Tiburón', 0), (220, 'La sirenita', 0), (220, 'El espantatiburones', 0), (220, 'Moana', 0), (220, 'Luca', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (221, 6, '¿Cómo se llama el hermano de Mario en los juegos de Nintendo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (221, 'Luigi', 1), (221, 'Wario', 0), (221, 'Toad', 0), (221, 'Bowser', 0), (221, 'Yoshi', 0), (221, 'Peach', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (222, 6, '¿Cómo se llama el erizo azul de SEGA?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (222, 'Sonic', 1), (222, 'Tails', 0), (222, 'Knuckles', 0), (222, 'Shadow', 0), (222, 'Crash', 0), (222, 'Spyro', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (223, 6, '¿Qué Pokémon es la mascota de la franquicia?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (223, 'Pikachu', 1), (223, 'Charmander', 0), (223, 'Bulbasaur', 0), (223, 'Squirtle', 0), (223, 'Eevee', 0), (223, 'Mewtwo', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (224, 6, '¿En qué saga Frodo debe destruir el Anillo Único?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (224, 'El Señor de los Anillos', 1), (224, 'Harry Potter', 0), (224, 'Las crónicas de Narnia', 0), (224, 'Juego de Tronos', 0), (224, 'Star Wars', 0), (224, 'Eragon', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (225, 6, '¿En qué serie se repite la frase «Se acerca el invierno»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (225, 'Juego de Tronos', 1), (225, 'Vikingos', 0), (225, 'The Witcher', 0), (225, 'The Walking Dead', 0), (225, 'Stranger Things', 0), (225, 'Lost', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (226, 6, '¿Qué serie de Netflix transcurre en el pueblo de Hawkins y el «Mundo del revés»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (226, 'Stranger Things', 1), (226, 'Dark', 0), (226, 'The OA', 0), (226, 'Lost', 0), (226, 'Black Mirror', 0), (226, 'The Umbrella Academy', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (227, 6, '¿Cómo se llama la princesa de «Frozen» que tiene poderes de hielo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (227, 'Elsa', 1), (227, 'Anna', 0), (227, 'Rapunzel', 0), (227, 'Ariel', 0), (227, 'Moana', 0), (227, 'Bella', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (228, 6, '¿Qué personaje dice «¡Hasta el infinito y más allá!»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (228, 'Buzz Lightyear', 1), (228, 'Woody', 0), (228, 'Wall-E', 0), (228, 'Mike Wazowski', 0), (228, 'Rayo McQueen', 0), (228, 'Nemo', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (229, 6, '¿Quién dirigió la película «Jurassic Park» (1993)?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (229, 'Steven Spielberg', 1), (229, 'George Lucas', 0), (229, 'James Cameron', 0), (229, 'Christopher Nolan', 0), (229, 'Ridley Scott', 0), (229, 'Peter Jackson', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (230, 6, '¿Qué película argentina ganó el Oscar a mejor película extranjera en la ceremonia de 2010?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (230, 'El secreto de sus ojos', 1), (230, 'La historia oficial', 0), (230, 'Relatos salvajes', 0), (230, 'Nueve reinas', 0), (230, 'El clan', 0), (230, 'Medianeras', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (231, 6, '¿Qué cantante es conocida como «la Reina del Pop»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (231, 'Madonna', 1), (231, 'Lady Gaga', 0), (231, 'Britney Spears', 0), (231, 'Beyoncé', 0), (231, 'Whitney Houston', 0), (231, 'Cher', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (232, 6, '¿Cómo se llama el pequeño robot protagonista de la película de Pixar de 2008?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (232, 'Wall-E', 1), (232, 'Eva', 0), (232, 'R2-D2', 0), (232, 'Baymax', 0), (232, 'Robbie', 0), (232, 'Optimus Prime', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (233, 6, '¿Qué videojuego «battle royale» se hizo famoso por sus construcciones y sus bailes?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (233, 'Fortnite', 1), (233, 'Minecraft', 0), (233, 'Among Us', 0), (233, 'Roblox', 0), (233, 'Free Fire', 0), (233, 'Tetris', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (234, 6, '¿Qué elefante de Disney vuela gracias a sus enormes orejas?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (234, 'Dumbo', 1), (234, 'Bambi', 0), (234, 'Pluto', 0), (234, 'Stitch', 0), (234, 'Simba', 0), (234, 'Goofy', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (235, 6, '¿Dónde vive Bob Esponja?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (235, 'En una piña bajo el mar', 1), (235, 'En una roca', 0), (235, 'En una cabeza de la isla de Pascua', 0), (235, 'En un barco hundido', 0), (235, 'En un coral', 0), (235, 'En un caracol gigante', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (236, 6, '¿Cómo se llama el colegio de magia de Harry Potter?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (236, 'Hogwarts', 1), (236, 'Durmstrang', 0), (236, 'Beauxbatons', 0), (236, 'Ilvermorny', 0), (236, 'Narnia', 0), (236, 'Mordor', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (237, 6, '¿Qué actor interpretó a Jack en «Titanic»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (237, 'Leonardo DiCaprio', 1), (237, 'Brad Pitt', 0), (237, 'Johnny Depp', 0), (237, 'Tom Cruise', 0), (237, 'Matt Damon', 0), (237, 'Keanu Reeves', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (238, 6, '¿Qué banda argentina canta «De música ligera»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (238, 'Soda Stereo', 1), (238, 'Patricio Rey y sus Redonditos de Ricota', 0), (238, 'Virus', 0), (238, 'Sumo', 0), (238, 'Los Enanitos Verdes', 0), (238, 'Babasónicos', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (239, 6, '¿Qué superhéroe de Marvel lleva un escudo con una estrella?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (239, 'Capitán América', 1), (239, 'Iron Man', 0), (239, 'Thor', 0), (239, 'Hulk', 0), (239, 'Pantera Negra', 0), (239, 'Ojo de Halcón', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (240, 6, '¿Cómo se llama el martillo de Thor?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (240, 'Mjolnir', 1), (240, 'Stormbreaker', 0), (240, 'Excalibur', 0), (240, 'Gungnir', 0), (240, 'Andúril', 0), (240, 'Aegis', 0);

-- Matemática
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (241, 7, '¿Cuánto es 7 × 8?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (241, '56', 1), (241, '54', 0), (241, '48', 0), (241, '64', 0), (241, '58', 0), (241, '63', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (242, 7, '¿Cuál es la raíz cuadrada de 144?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (242, '12', 1), (242, '14', 0), (242, '11', 0), (242, '16', 0), (242, '13', 0), (242, '10', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (243, 7, '¿Cuánto es el 15 % de 200?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (243, '30', 1), (243, '15', 0), (243, '20', 0), (243, '25', 0), (243, '35', 0), (243, '40', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (244, 7, '¿Cuántos lados tiene un hexágono?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (244, '6', 1), (244, '5', 0), (244, '7', 0), (244, '8', 0), (244, '4', 0), (244, '9', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (245, 7, '¿Cuánto suman los ángulos interiores de un triángulo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (245, '180°', 1), (245, '90°', 0), (245, '360°', 0), (245, '270°', 0), (245, '120°', 0), (245, '200°', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (246, 7, 'Si 2x + 6 = 20, ¿cuánto vale x?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (246, '7', 1), (246, '6', 0), (246, '8', 0), (246, '13', 0), (246, '10', 0), (246, '14', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (247, 7, '¿Cuánto es 2 elevado a la 10?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (247, '1024', 1), (247, '512', 0), (247, '1000', 0), (247, '2048', 0), (247, '100', 0), (247, '4096', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (248, 7, '¿Cuál es el siguiente número primo después del 13?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (248, '17', 1), (248, '15', 0), (248, '19', 0), (248, '14', 0), (248, '16', 0), (248, '21', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (249, 7, '¿Cuánto es 3/4 expresado en decimal?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (249, '0,75', 1), (249, '0,34', 0), (249, '0,43', 0), (249, '0,7', 0), (249, '1,33', 0), (249, '0,25', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (250, 7, '¿Cuál es el valor aproximado de π (pi)?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (250, '3,1416', 1), (250, '3,1614', 0), (250, '2,7182', 0), (250, '1,6180', 0), (250, '3,4116', 0), (250, '3,0', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (251, 7, '¿Cuánto es 9 × 7?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (251, '63', 1), (251, '56', 0), (251, '72', 0), (251, '64', 0), (251, '49', 0), (251, '81', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (252, 7, '¿Cuánto es 12 × 12?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (252, '144', 1), (252, '124', 0), (252, '122', 0), (252, '132', 0), (252, '154', 0), (252, '164', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (253, 7, '¿Cuánto es 1000 ÷ 8?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (253, '125', 1), (253, '120', 0), (253, '150', 0), (253, '115', 0), (253, '100', 0), (253, '80', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (254, 7, '¿Cuál es la raíz cuadrada de 81?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (254, '9', 1), (254, '8', 0), (254, '7', 0), (254, '18', 0), (254, '27', 0), (254, '11', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (255, 7, '¿Cuánto es el 25 % de 80?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (255, '20', 1), (255, '25', 0), (255, '15', 0), (255, '40', 0), (255, '8', 0), (255, '32', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (256, 7, '¿Cuántos lados tiene un octógono?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (256, '8', 1), (256, '6', 0), (256, '7', 0), (256, '10', 0), (256, '9', 0), (256, '12', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (257, 7, '¿Cuántos grados mide un ángulo recto?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (257, '90°', 1), (257, '45°', 0), (257, '180°', 0), (257, '60°', 0), (257, '120°', 0), (257, '360°', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (258, 7, '¿Cuánto suman los ángulos interiores de un cuadrilátero?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (258, '360°', 1), (258, '180°', 0), (258, '270°', 0), (258, '540°', 0), (258, '90°', 0), (258, '720°', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (259, 7, '¿Cuál es el área de un rectángulo de 6 cm por 4 cm?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (259, '24 cm²', 1), (259, '20 cm²', 0), (259, '10 cm²', 0), (259, '48 cm²', 0), (259, '12 cm²', 0), (259, '28 cm²', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (260, 7, '¿Cuál es el perímetro de un cuadrado de 5 cm de lado?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (260, '20 cm', 1), (260, '25 cm', 0), (260, '10 cm', 0), (260, '15 cm', 0), (260, '30 cm', 0), (260, '40 cm', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (261, 7, '¿Cuánto es 3 al cubo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (261, '27', 1), (261, '9', 0), (261, '6', 0), (261, '81', 0), (261, '18', 0), (261, '33', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (262, 7, '¿Cuánto es 15 − 3 × 4?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (262, '3', 1), (262, '48', 0), (262, '12', 0), (262, '0', 0), (262, '9', 0), (262, '6', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (263, 7, '¿Cuánto es (2 + 3) × 4?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (263, '20', 1), (263, '14', 0), (263, '24', 0), (263, '9', 0), (263, '45', 0), (263, '18', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (264, 7, '¿Qué número representa la letra L en números romanos?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (264, '50', 1), (264, '100', 0), (264, '500', 0), (264, '10', 0), (264, '5', 0), (264, '1000', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (265, 7, '¿Qué número es XIV en números romanos?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (265, '14', 1), (265, '16', 0), (265, '9', 0), (265, '11', 0), (265, '15', 0), (265, '19', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (266, 7, 'Si algo cuesta $800 y tiene un 10 % de descuento, ¿cuánto pagás?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (266, '$720', 1), (266, '$700', 0), (266, '$790', 0), (266, '$780', 0), (266, '$80', 0), (266, '$710', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (267, 7, '¿Cuántos minutos tiene un día?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (267, '1440', 1), (267, '1200', 0), (267, '1400', 0), (267, '3600', 0), (267, '720', 0), (267, '2400', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (268, 7, '¿Cuántos segundos tiene una hora?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (268, '3600', 1), (268, '360', 0), (268, '6000', 0), (268, '600', 0), (268, '1440', 0), (268, '3000', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (269, 7, '¿Cuál es el mínimo común múltiplo de 4 y 6?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (269, '12', 1), (269, '24', 0), (269, '2', 0), (269, '10', 0), (269, '6', 0), (269, '8', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (270, 7, '¿Cuál es el máximo común divisor de 18 y 24?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (270, '6', 1), (270, '3', 0), (270, '12', 0), (270, '2', 0), (270, '9', 0), (270, '4', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (271, 7, '¿Cuál es el promedio de 4, 8 y 12?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (271, '8', 1), (271, '6', 0), (271, '24', 0), (271, '10', 0), (271, '12', 0), (271, '7', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (272, 7, '¿Cuánto es 0,5 + 0,25?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (272, '0,75', 1), (272, '0,30', 0), (272, '0,525', 0), (272, '1', 0), (272, '0,7', 0), (272, '0,55', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (273, 7, '¿Qué fracción es igual a 0,2?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (273, '1/5', 1), (273, '1/2', 0), (273, '2/5', 0), (273, '1/20', 0), (273, '2/100', 0), (273, '1/4', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (274, 7, '¿Qué número sigue en la serie 2, 4, 8, 16, …?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (274, '32', 1), (274, '24', 0), (274, '18', 0), (274, '30', 0), (274, '20', 0), (274, '64', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (275, 7, '¿Qué número sigue en la serie de Fibonacci 1, 1, 2, 3, 5, 8, …?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (275, '13', 1), (275, '11', 0), (275, '12', 0), (275, '10', 0), (275, '16', 0), (275, '14', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (276, 7, '¿Cuántas caras tiene un cubo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (276, '6', 1), (276, '8', 0), (276, '4', 0), (276, '12', 0), (276, '5', 0), (276, '10', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (277, 7, '¿Cuántas aristas tiene un cubo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (277, '12', 1), (277, '8', 0), (277, '6', 0), (277, '10', 0), (277, '16', 0), (277, '24', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (278, 7, 'Si x − 7 = 15, ¿cuánto vale x?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (278, '22', 1), (278, '8', 0), (278, '21', 0), (278, '105', 0), (278, '7', 0), (278, '23', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (279, 7, '¿Cuánto es el 50 % del 50 % de 100?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (279, '25', 1), (279, '50', 0), (279, '0', 0), (279, '75', 0), (279, '10', 0), (279, '5', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (280, 7, '¿Cuál es el único número primo par?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (280, '2', 1), (280, '4', 0), (280, '0', 0), (280, '1', 0), (280, '6', 0), (280, '8', 0);

-- Tecnología
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (281, 8, '¿Qué significa la sigla HTML?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (281, 'HyperText Markup Language', 1), (281, 'High Text Machine Language', 0), (281, 'Hyper Transfer Markup Logic', 0), (281, 'Home Tool Markup Language', 0), (281, 'HyperText Media Link', 0), (281, 'Hyper Tool Multi Language', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (282, 8, '¿Quién fundó Microsoft junto a Paul Allen?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (282, 'Bill Gates', 1), (282, 'Steve Jobs', 0), (282, 'Elon Musk', 0), (282, 'Mark Zuckerberg', 0), (282, 'Larry Page', 0), (282, 'Jeff Bezos', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (283, 8, '¿Cuántos bits tiene un byte?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (283, '8', 1), (283, '4', 0), (283, '16', 0), (283, '10', 0), (283, '2', 0), (283, '32', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (284, 8, '¿Qué empresa desarrolla el sistema operativo Android?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (284, 'Google', 1), (284, 'Apple', 0), (284, 'Microsoft', 0), (284, 'Samsung', 0), (284, 'Huawei', 0), (284, 'Nokia', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (285, 8, '¿Qué significa la sigla CPU?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (285, 'Unidad Central de Procesamiento', 1), (285, 'Unidad de Control Personal', 0), (285, 'Centro de Proceso Universal', 0), (285, 'Computadora Personal Unificada', 0), (285, 'Unidad de Carga de Programas', 0), (285, 'Central de Programas Unificados', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (286, 8, '¿Qué lenguaje de programación tiene una taza de café como logo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (286, 'Java', 1), (286, 'Python', 0), (286, 'C++', 0), (286, 'PHP', 0), (286, 'Ruby', 0), (286, 'JavaScript', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (287, 8, '¿Qué protocolo se usa para navegar páginas web de forma segura?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (287, 'HTTPS', 1), (287, 'FTP', 0), (287, 'SMTP', 0), (287, 'HTTP', 0), (287, 'SSH', 0), (287, 'POP3', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (288, 8, '¿En qué año se lanzó el primer iPhone?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (288, '2007', 1), (288, '2005', 0), (288, '2008', 0), (288, '2010', 0), (288, '2003', 0), (288, '2001', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (289, 8, '¿Qué significa la sigla SQL?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (289, 'Structured Query Language', 1), (289, 'Simple Question Language', 0), (289, 'System Quality Logic', 0), (289, 'Standard Query Link', 0), (289, 'Sequential Query Language', 0), (289, 'Server Query Language', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (290, 8, '¿Cuál de estas unidades representa más información?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (290, '1 terabyte', 1), (290, '1 gigabyte', 0), (290, '1 megabyte', 0), (290, '1 kilobyte', 0), (290, '1 byte', 0), (290, '1 megabit', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (291, 8, '¿Qué significa la sigla «WWW»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (291, 'World Wide Web', 1), (291, 'World Web Wide', 0), (291, 'Wide World Web', 0), (291, 'Web World Wide', 0), (291, 'World Wireless Web', 0), (291, 'Wide Web Window', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (292, 8, '¿Quién es considerado el creador de la World Wide Web?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (292, 'Tim Berners-Lee', 1), (292, 'Bill Gates', 0), (292, 'Steve Jobs', 0), (292, 'Linus Torvalds', 0), (292, 'Mark Zuckerberg', 0), (292, 'Larry Page', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (293, 8, '¿Quién creó el núcleo del sistema operativo Linux?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (293, 'Linus Torvalds', 1), (293, 'Dennis Ritchie', 0), (293, 'Bill Gates', 0), (293, 'Steve Wozniak', 0), (293, 'Ken Thompson', 0), (293, 'Tim Berners-Lee', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (294, 8, '¿Qué empresa desarrolla el iPhone?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (294, 'Apple', 1), (294, 'Samsung', 0), (294, 'Google', 0), (294, 'Microsoft', 0), (294, 'Huawei', 0), (294, 'Motorola', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (295, 8, '¿Qué lenguaje se usa para darle estilos (colores, tamaños) a una página web?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (295, 'CSS', 1), (295, 'HTML', 0), (295, 'PHP', 0), (295, 'SQL', 0), (295, 'Python', 0), (295, 'Java', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (296, 8, '¿Qué significa la sigla «CSS»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (296, 'Cascading Style Sheets', 1), (296, 'Computer Style Sheets', 0), (296, 'Creative Style System', 0), (296, 'Colorful Style Sheets', 0), (296, 'Cascading Script Sheets', 0), (296, 'Code Style Syntax', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (297, 8, '¿Qué lenguaje se ejecuta en el navegador para que las páginas sean interactivas?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (297, 'JavaScript', 1), (297, 'PHP', 0), (297, 'SQL', 0), (297, 'C', 0), (297, 'Python', 0), (297, 'COBOL', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (298, 8, '¿En qué lenguaje está programado el servidor de ZENIT?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (298, 'PHP', 1), (298, 'Python', 0), (298, 'Java', 0), (298, 'C#', 0), (298, 'Ruby', 0), (298, 'Go', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (299, 8, '¿Qué significa la sigla «RAM»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (299, 'Random Access Memory', 1), (299, 'Read Access Memory', 0), (299, 'Rapid Access Module', 0), (299, 'Run Application Memory', 0), (299, 'Random Allocation Module', 0), (299, 'Read And Modify', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (300, 8, '¿Qué sistema de numeración usan las computadoras internamente?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (300, 'Binario', 1), (300, 'Decimal', 0), (300, 'Romano', 0), (300, 'Sexagesimal', 0), (300, 'Duodecimal', 0), (300, 'Maya', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (301, 8, '¿Qué número decimal representa 1010 en binario?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (301, '10', 1), (301, '8', 0), (301, '12', 0), (301, '5', 0), (301, '1010', 0), (301, '2', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (302, 8, '¿Qué significa la sigla «URL»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (302, 'Uniform Resource Locator', 1), (302, 'Universal Real Link', 0), (302, 'Unique Resource List', 0), (302, 'User Route Locator', 0), (302, 'Uniform Reference Link', 0), (302, 'Universal Resource Library', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (303, 8, '¿Qué significa «IP» en «dirección IP»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (303, 'Internet Protocol', 1), (303, 'Internal Port', 0), (303, 'Internet Provider', 0), (303, 'Information Packet', 0), (303, 'Intranet Point', 0), (303, 'Interface Program', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (304, 8, '¿Qué empresa creó el sistema operativo Windows?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (304, 'Microsoft', 1), (304, 'Apple', 0), (304, 'IBM', 0), (304, 'Google', 0), (304, 'Intel', 0), (304, 'Oracle', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (305, 8, '¿En qué año se fundó Google?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (305, '1998', 1), (305, '1995', 0), (305, '2001', 0), (305, '2004', 0), (305, '1990', 0), (305, '2008', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (306, 8, '¿Qué red social fundó Mark Zuckerberg en 2004?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (306, 'Facebook', 1), (306, 'Twitter', 0), (306, 'Instagram', 0), (306, 'MySpace', 0), (306, 'LinkedIn', 0), (306, 'Snapchat', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (307, 8, '¿Qué lenguaje de programación tiene dos serpientes en su logo?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (307, 'Python', 1), (307, 'Java', 0), (307, 'Ruby', 0), (307, 'PHP', 0), (307, 'Go', 0), (307, 'Rust', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (308, 8, '¿Qué significa la sigla «HTTP»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (308, 'HyperText Transfer Protocol', 1), (308, 'High Transfer Text Protocol', 0), (308, 'HyperText Transmission Program', 0), (308, 'Hyper Tool Transfer Protocol', 0), (308, 'Home Text Transfer Protocol', 0), (308, 'HyperLink Text Protocol', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (309, 8, '¿Qué componente se considera el «cerebro» de la computadora?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (309, 'El procesador', 1), (309, 'El disco rígido', 0), (309, 'La fuente de alimentación', 0), (309, 'El gabinete', 0), (309, 'El monitor', 0), (309, 'El teclado', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (310, 8, '¿Qué memoria se borra al apagar la computadora?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (310, 'La RAM', 1), (310, 'El disco SSD', 0), (310, 'El disco rígido', 0), (310, 'El pendrive', 0), (310, 'La tarjeta SD', 0), (310, 'El disco externo', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (311, 8, '¿Qué atajo de teclado copia lo seleccionado en Windows?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (311, 'Ctrl + C', 1), (311, 'Ctrl + V', 0), (311, 'Ctrl + X', 0), (311, 'Ctrl + Z', 0), (311, 'Ctrl + P', 0), (311, 'Ctrl + A', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (312, 8, '¿Qué atajo de teclado deshace la última acción en Windows?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (312, 'Ctrl + Z', 1), (312, 'Ctrl + Y', 0), (312, 'Ctrl + X', 0), (312, 'Ctrl + S', 0), (312, 'Ctrl + D', 0), (312, 'Alt + F4', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (313, 8, '¿Qué herramienta se usa para el control de versiones del código?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (313, 'Git', 1), (313, 'Excel', 0), (313, 'Photoshop', 0), (313, 'Zoom', 0), (313, 'Paint', 0), (313, 'Word', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (314, 8, '¿Qué plataforma para alojar repositorios Git pertenece a Microsoft?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (314, 'GitHub', 1), (314, 'GitLab', 0), (314, 'Bitbucket', 0), (314, 'SourceForge', 0), (314, 'Stack Overflow', 0), (314, 'npm', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (315, 8, '¿Qué significa la sigla «PDF»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (315, 'Portable Document Format', 1), (315, 'Printed Document File', 0), (315, 'Personal Data Format', 0), (315, 'Public Document File', 0), (315, 'Portable Data File', 0), (315, 'Page Description Format', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (316, 8, '¿Quién es considerada la primera programadora de la historia?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (316, 'Ada Lovelace', 1), (316, 'Grace Hopper', 0), (316, 'Margaret Hamilton', 0), (316, 'Hedy Lamarr', 0), (316, 'Marie Curie', 0), (316, 'Katherine Johnson', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (317, 8, '¿Qué matemático británico ayudó a descifrar la máquina Enigma y es considerado padre de la computación?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (317, 'Alan Turing', 1), (317, 'Charles Babbage', 0), (317, 'John von Neumann', 0), (317, 'George Boole', 0), (317, 'Claude Shannon', 0), (317, 'Isaac Newton', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (318, 8, '¿Qué significa la sigla «USB»?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (318, 'Universal Serial Bus', 1), (318, 'United System Bus', 0), (318, 'Universal System Board', 0), (318, 'Ultra Speed Bus', 0), (318, 'User Serial Bridge', 0), (318, 'Universal Storage Box', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (319, 8, '¿Qué tecnología inalámbrica se usa para conectar auriculares al celular?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (319, 'Bluetooth', 1), (319, 'Ethernet', 0), (319, 'HDMI', 0), (319, 'Fibra óptica', 0), (319, 'VGA', 0), (319, 'USB-C', 0);
INSERT INTO pregunta (id, categoria_id, enunciado) VALUES (320, 8, '¿Qué base de datos usa ZENIT?');
INSERT INTO opcion (pregunta_id, texto, es_correcta) VALUES (320, 'MySQL', 1), (320, 'MongoDB', 0), (320, 'Oracle', 0), (320, 'PostgreSQL', 0), (320, 'Firebase', 0), (320, 'Excel', 0);

-- ── Usuario de prueba (ya verificado) ───────────────────────
-- usuario: demo   ·   contraseña: zenit1234
INSERT INTO usuario (nombre_completo, nombre_usuario, email, password, anio_nacimiento, sexo, pais, ciudad, activo)
VALUES ('Jugador Demo', 'demo', 'demo@zenit.local', '$2y$10$g8lRd87zRRXBJgstGwq7U.88YuMblrm.0Y6QvCqRa1f/ZMvLA/Zre', 2000, 'no_informa', 'Argentina', 'Buenos Aires', 1);
