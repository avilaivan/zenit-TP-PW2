-- Base de datos del ejemplo "Partido Despedida de Messi"
-- Importar completa antes de correr los PHP

CREATE DATABASE IF NOT EXISTS my_database CHARACTER SET utf8mb4;
USE my_database;


CREATE TABLE usuarios (
                          id INT AUTO_INCREMENT PRIMARY KEY,
                          nombre_usuario VARCHAR(50) NOT NULL,
                          email VARCHAR(150) NOT NULL UNIQUE,
                          password VARCHAR(255) NOT NULL,
                          fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

/*
INSERT INTO usuarios (nombre_usuario, password) VALUES
('facu', MD5('1234'));*/


