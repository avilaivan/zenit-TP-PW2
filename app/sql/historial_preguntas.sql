-- ════════════════════════════════════════════════════════════
-- ZENIT · Historial de preguntas vistas por jugador
-- Para una base que YA está funcionando (XAMPP o InfinityFree):
--   phpMyAdmin → entrá a tu base → Importar → este archivo.
-- Solo crea una tabla nueva: NO borra ni cambia nada. Se puede importar
-- más de una vez. Importalo ANTES de subir el código que la usa.
-- ════════════════════════════════════════════════════════════

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
