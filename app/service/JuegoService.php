<?php

namespace app\service;

use app\model\CategoriaModel;
use app\model\EstadisticaModel;
use app\model\PartidaModel;
use app\model\PreguntaModel;
use DomainException;

/**
 * Lógica del modo individual (offline) de ZENIT.
 *
 * Flujo de la partida (fases):
 *
 *   GIRAR ──► la ruleta saca:
 *     · una categoría     → PREGUNTA ×3 → si acierta 2+ supera la ronda; si no, pierde 1 vida
 *     · ronda de LETRA    → (tras 3 rondas superadas) 3 preguntas de 3 categorías distintas;
 *                           si acierta 2 de 3 → PREMIO
 *     · la categoría Z    → (muy rara) PREMIO directo, sin preguntas
 *   PREMIO ──► elige 1 letra de ZENIT o 1 corazón ──► GIRAR
 *   FIN ──► sin vidas (derrota) o con las 5 letras Z-E-N-I-T (victoria)
 *
 * Las categorías nunca se eliminan del sorteo.
 */
class JuegoService
{
    public const FASE_GIRAR = 'girar';
    public const FASE_PREGUNTA = 'pregunta';
    public const FASE_PREMIO = 'premio';
    public const FASE_FIN = 'fin';

    private const LETRAS_OPCION = ['A', 'B', 'C', 'D', 'E', 'F'];

    public function __construct(
        private EstadoJuego $almacen,
        private RuletaService $ruleta,
        private CategoriaModel $categorias,
        private PreguntaModel $preguntas,
        private EstadisticaModel $estadisticas,
        private PartidaModel $partidas
    ) {
    }

    // ════════════════════════════════════════════════
    //  Acciones públicas (cada una = un endpoint)
    // ════════════════════════════════════════════════

    /** Estado actual para dibujar la pantalla (null si no hay partida). */
    public function estado(int $usuarioId): ?array
    {
        $estado = $this->cargar($usuarioId);
        return $estado ? $this->publico($estado) : null;
    }

    public function iniciar(int $usuarioId): array
    {
        $this->abandonar($usuarioId); // una partida a medias cuenta como derrota
        $estado = EstadoJuego::nuevo($this->partidas->crear($usuarioId), $usuarioId);
        $this->almacen->guardar($estado);
        return $this->publico($estado);
    }

    public function girar(int $usuarioId): array
    {
        $estado = $this->exigirFase($usuarioId, self::FASE_GIRAR);
        $categorias = $this->categorias->todas();

        if ($estado['rondas_superadas'] >= ReglasJuego::RONDAS_PARA_LETRA) {
            $ganador = RuletaService::ITEM_LETRA;
            $estado['ronda'] = $this->rondaDeLetra($estado, $categorias);
            $estado['fase'] = self::FASE_PREGUNTA;
        } elseif ($this->ruleta->saleZ($estado['prob_z'])) {
            // ¡Categoría Z! Te ahorra las 3 rondas: premio directo.
            $ganador = RuletaService::ITEM_Z;
            $estado['prob_z'] = ReglasJuego::PROB_Z_BASE;
            $estado['rondas_superadas'] = 0;
            $estado['origen_premio'] = 'z';
            $estado['fase'] = self::FASE_PREMIO;
        } else {
            $categoria = $this->ruleta->categoriaAlAzar($categorias);
            $ganador = RuletaService::paraTira($categoria);
            $estado['ronda'] = $this->rondaDeCategoria($estado, $categoria);
            $estado['fase'] = self::FASE_PREGUNTA;
        }

        $this->almacen->guardar($estado);
        return [
            'tira' => $this->ruleta->armarTira($categorias, $ganador),
            'posicion' => RuletaService::POSICION_GANADOR,
            'resultado' => $ganador,
            'estado' => $this->publico($estado),
        ];
    }

    /** Pregunta actual SIN la respuesta correcta. Arranca el reloj la primera vez. */
    public function pregunta(int $usuarioId): array
    {
        $estado = $this->exigirFase($usuarioId, self::FASE_PREGUNTA);
        $ronda = &$estado['ronda'];
        $pregunta = $this->preguntaEnCurso($estado);

        if ($ronda['orden'] === null) {
            $ids = array_column($pregunta['opciones'], 'id');
            shuffle($ids); // las opciones salen mezcladas
            $ronda['orden'] = $ids;
        }
        if ($ronda['inicio'] === null) {
            $ronda['inicio'] = microtime(true);
        }
        $orden = $ronda['orden'];
        $transcurrido = microtime(true) - $ronda['inicio'];
        unset($ronda); // cortar la referencia antes de guardar
        $categoria = $this->categorias->buscar((int) $pregunta['categoria_id']);
        $this->almacen->guardar($estado);

        $textos = array_column($pregunta['opciones'], 'texto', 'id');
        $opciones = [];
        foreach ($orden as $i => $id) {
            $opciones[] = ['id' => (int) $id, 'letra' => self::LETRAS_OPCION[$i], 'texto' => $textos[$id]];
        }

        return [
            'enunciado' => $pregunta['enunciado'],
            'categoria' => RuletaService::paraTira($categoria),
            'opciones' => $opciones,
            'tiempo_total' => ReglasJuego::SEGUNDOS_POR_PREGUNTA,
            'tiempo_restante' => max(0, ReglasJuego::SEGUNDOS_POR_PREGUNTA - $transcurrido),
            'estado' => $this->publico($estado),
        ];
    }

    /** @param int|null $opcionId null = se acabó el tiempo */
    public function responder(int $usuarioId, ?int $opcionId): array
    {
        $estado = $this->exigirFase($usuarioId, self::FASE_PREGUNTA);
        $ronda = &$estado['ronda'];
        if ($ronda['inicio'] === null) {
            throw new DomainException('Primero hay que pedir la pregunta.');
        }

        $pregunta = $this->preguntaEnCurso($estado);
        $idCorrecta = $this->idOpcionCorrecta($pregunta);
        $fueraDeTiempo = microtime(true) - $ronda['inicio']
            > ReglasJuego::SEGUNDOS_POR_PREGUNTA + ReglasJuego::SEGUNDOS_DE_GRACIA;
        $acerto = !$fueraDeTiempo && $opcionId === $idCorrecta;

        $this->registrarRespuesta($estado, (int) $pregunta['categoria_id'], $acerto);

        // Avanzar a la siguiente pregunta de la ronda
        $ronda['indice']++;
        $ronda['inicio'] = null;
        $ronda['orden'] = null;
        unset($ronda); // cortar la referencia antes de reemplazar la ronda

        $resumen = null;
        if ($estado['ronda']['indice'] >= count($estado['ronda']['preguntas'])) {
            $resumen = $this->cerrarRonda($estado);
        }

        $this->almacen->guardar($estado);
        return [
            'correcta' => $acerto,
            'fuera_de_tiempo' => $fueraDeTiempo,
            'opcion_correcta' => $idCorrecta,
            'resumen_ronda' => $resumen,
            'estado' => $this->publico($estado),
        ];
    }

    /** @param string $eleccion "letra" | "vida" */
    public function elegirPremio(int $usuarioId, string $eleccion): array
    {
        $estado = $this->exigirFase($usuarioId, self::FASE_PREMIO);

        if ($eleccion === 'letra') {
            $estado['letras'] .= ReglasJuego::PALABRA[strlen($estado['letras'])];
            $this->sumarPuntos($estado, ReglasJuego::PUNTOS_LETRA);
        } elseif ($eleccion === 'vida' && $estado['vidas'] < ReglasJuego::VIDAS_MAXIMAS) {
            $estado['vidas']++;
        } else {
            throw new DomainException('Elección de premio inválida.');
        }

        $estado['origen_premio'] = null;
        $estado['fase'] = self::FASE_GIRAR;
        if ($estado['letras'] === ReglasJuego::PALABRA) {
            $this->finalizar($estado, 'victoria');
        }

        $this->almacen->guardar($estado);
        return ['estado' => $this->publico($estado)];
    }

    /** Termina la partida en curso (cuenta como derrota) y limpia la sesión. */
    public function abandonar(int $usuarioId): void
    {
        $estado = $this->cargar($usuarioId);
        if ($estado && $estado['fase'] !== self::FASE_FIN) {
            $this->finalizar($estado, 'derrota');
        }
        $this->almacen->borrar();
    }

    // ════════════════════════════════════════════════
    //  Rondas
    // ════════════════════════════════════════════════

    private function rondaDeCategoria(array &$estado, array $categoria): array
    {
        $ids = $this->elegirPreguntas($estado, (int) $categoria['id'], ReglasJuego::PREGUNTAS_POR_RONDA);
        return self::nuevaRonda('categoria', RuletaService::paraTira($categoria), $ids);
    }

    /** 3 preguntas de 3 categorías distintas (1 de cada una). */
    private function rondaDeLetra(array &$estado, array $categorias): array
    {
        $ids = [];
        foreach ($this->ruleta->categoriasDistintas($categorias, ReglasJuego::PREGUNTAS_POR_RONDA) as $categoria) {
            $ids[] = $this->elegirPreguntas($estado, (int) $categoria['id'], 1)[0];
        }
        return self::nuevaRonda('letra', null, $ids);
    }

    private static function nuevaRonda(string $tipo, ?array $categoria, array $preguntas): array
    {
        return [
            'tipo' => $tipo,
            'categoria' => $categoria,
            'preguntas' => $preguntas,
            'indice' => 0,
            'aciertos' => 0,
            'inicio' => null, // momento en que se mostró la pregunta (reloj del servidor)
            'orden' => null,  // orden mezclado de las opciones
        ];
    }

    /** Evalúa la ronda terminada y devuelve un resumen para mostrar. */
    private function cerrarRonda(array &$estado): array
    {
        $ronda = $estado['ronda'];
        $total = count($ronda['preguntas']);
        $resumen = ['tipo' => $ronda['tipo'], 'aciertos' => $ronda['aciertos'], 'total' => $total,
                    'vida_perdida' => false, 'letra_desbloqueada' => false, 'premio' => false];

        if ($ronda['tipo'] === 'categoria') {
            $resumen['superada'] = $ronda['aciertos'] >= ReglasJuego::MINIMO_ACIERTOS;
            if ($resumen['superada']) {
                $estado['rondas_superadas']++;
                $this->sumarPuntos($estado, ReglasJuego::PUNTOS_RONDA_SUPERADA);
                $resumen['letra_desbloqueada'] = $estado['rondas_superadas'] >= ReglasJuego::RONDAS_PARA_LETRA;
            } else {
                $estado['vidas']--;
                $resumen['vida_perdida'] = true;
            }
        } else {
            // Ronda de letra: alcanza con 2 de 3. Pase lo que pase, el contador vuelve a 0.
            $resumen['superada'] = $ronda['aciertos'] >= ReglasJuego::MINIMO_ACIERTOS_LETRA;
            $estado['rondas_superadas'] = 0;
            if ($resumen['superada']) {
                $estado['origen_premio'] = 'letra';
                $estado['fase'] = self::FASE_PREMIO;
                $resumen['premio'] = true;
            }
        }

        // Se guardan las preguntas de esta ronda: son las únicas que se pueden reportar ahora.
        $estado['ultima_ronda'] = ['preguntas' => $ronda['preguntas'], 'reportada' => false];
        $resumen['preguntas'] = $this->preguntasParaReporte($ronda['preguntas']);

        $estado['ronda'] = null;
        if ($estado['vidas'] <= 0) {
            $this->finalizar($estado, 'derrota');
        } elseif ($estado['fase'] !== self::FASE_PREMIO) {
            $estado['fase'] = self::FASE_GIRAR;
        }
        return $resumen;
    }

    /** Enunciado y categoría de cada pregunta de la ronda (para elegir cuál reportar). */
    private function preguntasParaReporte(array $ids): array
    {
        $lista = [];
        foreach ($ids as $i => $id) {
            $pregunta = $this->preguntas->buscarConOpciones($id);
            $categoria = $this->categorias->buscar((int) $pregunta['categoria_id']);
            $lista[] = [
                'numero' => $i + 1,
                'enunciado' => $pregunta['enunciado'],
                'categoria' => $categoria['nombre'],
                'color' => $categoria['color'],
            ];
        }
        return $lista;
    }

    /** Elige preguntas no vistas en esta partida (si se agotan, se reinicia esa categoría). */
    private function elegirPreguntas(array &$estado, int $categoriaId, int $cantidad): array
    {
        $todas = $this->preguntas->idsPorCategoria($categoriaId);
        $disponibles = array_values(array_diff($todas, $estado['vistas']));

        if (count($disponibles) < $cantidad) {
            $estado['vistas'] = array_values(array_diff($estado['vistas'], $todas));
            $disponibles = $todas;
        }
        shuffle($disponibles);
        $elegidas = array_slice($disponibles, 0, $cantidad);
        if ($elegidas === []) {
            throw new DomainException('No hay preguntas cargadas para esta categoría.');
        }

        $estado['vistas'] = array_merge($estado['vistas'], $elegidas);
        return $elegidas;
    }

    // ════════════════════════════════════════════════
    //  Puntos, estadísticas y fin de partida
    // ════════════════════════════════════════════════

    private function registrarRespuesta(array &$estado, int $categoriaId, bool $acerto): void
    {
        $estado['respondidas']++;
        $this->estadisticas->registrarRespuesta($estado['usuario_id'], $categoriaId, $acerto);

        if ($acerto) {
            $estado['correctas']++;
            $estado['ronda']['aciertos']++;
            $estado['prob_z'] = min(ReglasJuego::PROB_Z_MAXIMA, $estado['prob_z'] + ReglasJuego::PROB_Z_POR_ACIERTO);
            $this->sumarPuntos($estado, ReglasJuego::PUNTOS_ACIERTO);
        }
    }

    /** Los puntos se guardan al instante: si se corta la luz, no se pierden. */
    private function sumarPuntos(array &$estado, int $puntos): void
    {
        $estado['puntos'] += $puntos;
        $this->estadisticas->sumarPuntos($estado['usuario_id'], $puntos);
    }

    private function finalizar(array &$estado, string $resultado): void
    {
        if ($resultado === 'victoria') {
            $this->sumarPuntos($estado, ReglasJuego::PUNTOS_VICTORIA);
        }
        $estado['fase'] = self::FASE_FIN;
        $estado['resultado'] = $resultado;
        $estado['ronda'] = null;

        $this->partidas->cerrar(
            $estado['partida_id'],
            $resultado,
            $estado['puntos'],
            $estado['letras'],
            $estado['respondidas'],
            $estado['correctas']
        );
        $this->estadisticas->registrarPartidaTerminada($estado['usuario_id'], $resultado === 'victoria');
    }

    // ════════════════════════════════════════════════
    //  Auxiliares
    // ════════════════════════════════════════════════

    /** Estado de la sesión, solo si pertenece a este usuario. */
    private function cargar(int $usuarioId): ?array
    {
        $estado = $this->almacen->obtener();
        return ($estado && $estado['usuario_id'] === $usuarioId) ? $estado : null;
    }

    private function exigirFase(int $usuarioId, string $fase): array
    {
        $estado = $this->cargar($usuarioId);
        if ($estado === null || $estado['fase'] !== $fase) {
            throw new DomainException('Acción no válida en este momento de la partida.');
        }
        return $estado;
    }

    private function preguntaEnCurso(array $estado): array
    {
        $ronda = $estado['ronda'];
        $pregunta = $this->preguntas->buscarConOpciones($ronda['preguntas'][$ronda['indice']]);
        if ($pregunta === null) {
            throw new DomainException('La pregunta ya no existe.');
        }
        return $pregunta;
    }

    private function idOpcionCorrecta(array $pregunta): int
    {
        foreach ($pregunta['opciones'] as $opcion) {
            if ((int) $opcion['es_correcta'] === 1) {
                return (int) $opcion['id'];
            }
        }
        throw new DomainException('La pregunta no tiene respuesta correcta cargada.');
    }

    /** Lo que ve el navegador: nunca incluye respuestas ni ids de preguntas. */
    private function publico(array $estado): array
    {
        $letras = [];
        foreach (str_split(ReglasJuego::PALABRA) as $i => $letra) {
            $letras[] = ['letra' => $letra, 'obtenida' => $i < strlen($estado['letras'])];
        }

        $ronda = $estado['ronda'];
        return [
            'fase' => $estado['fase'],
            'vidas' => $estado['vidas'],
            'vidas_maximas' => ReglasJuego::VIDAS_MAXIMAS,
            'letras' => $letras,
            'cantidad_letras' => strlen($estado['letras']),
            'proxima_letra' => ReglasJuego::PALABRA[strlen($estado['letras'])] ?? null,
            'puntos' => $estado['puntos'],
            'respondidas' => $estado['respondidas'],
            'correctas' => $estado['correctas'],
            'prob_z' => round($estado['prob_z'] * 100, 1),
            'rondas_superadas' => $estado['rondas_superadas'],
            'rondas_para_letra' => ReglasJuego::RONDAS_PARA_LETRA,
            'minimo_aciertos' => ReglasJuego::MINIMO_ACIERTOS,
            'minimo_aciertos_letra' => ReglasJuego::MINIMO_ACIERTOS_LETRA,
            'origen_premio' => $estado['origen_premio'],
            'puede_elegir_vida' => $estado['vidas'] < ReglasJuego::VIDAS_MAXIMAS,
            'resultado' => $estado['resultado'],
            'ronda' => $ronda === null ? null : [
                'tipo' => $ronda['tipo'],
                'categoria' => $ronda['categoria'],
                'numero' => $ronda['indice'] + 1,
                'total' => count($ronda['preguntas']),
                'aciertos' => $ronda['aciertos'],
            ],
        ];
    }
}
