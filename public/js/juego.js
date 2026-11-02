/* ════════════════════════════════════════════════════════════
   ZENIT · Juego individual (cliente)

   Este archivo SOLO dibuja y anima. Las reglas (vidas, letras,
   respuesta correcta, probabilidad de la Z) se deciden en el
   servidor (JuegoService.php). Acá se pide el estado con fetch()
   y se muestra la pantalla que corresponde a cada "fase":

     girar → pregunta → (resultado de ronda) → premio → … → fin
   ════════════════════════════════════════════════════════════ */
(function () {
    'use strict';

    const raiz = document.getElementById('juego');
    if (!raiz) return;

    const BASE = raiz.dataset.base;
    const ESPERA_FEEDBACK = 1400;   // ms mostrando si acertaste antes de seguir
    const DURACION_RULETA = 5200;   // ms de la animación de la ruleta

    const $ = (id) => document.getElementById(id);

    // Estado que llega del servidor + datos de la pregunta en pantalla
    let estado = null;
    let reloj = null;           // setInterval del temporizador
    let respondiendo = false;   // evita doble click
    let ultimaRonda = null;     // preguntas de la ronda que terminó (para reportarlas)
    let modalDeOrigen = null;   // modal al que se vuelve después de reportar

    // ════════════════════════════════════════════════
    //  Comunicación con el servidor
    // ════════════════════════════════════════════════

    async function api(accion, datos = {}) {
        const respuesta = await fetch(`${BASE}/juego/${accion}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(datos),
        });
        const json = await respuesta.json().catch(() => ({ ok: false, error: 'Respuesta inválida del servidor.' }));

        if (respuesta.status === 401) {
            window.location.href = `${BASE}/login`;
            throw new Error(json.error);
        }
        if (!json.ok) {
            throw new Error(json.error || 'Error inesperado.');
        }
        return json;
    }

    /** Si algo falla (ej: dos pestañas abiertas), se re-sincroniza con el servidor. */
    async function sincronizar(error) {
        console.warn('[ZENIT]', error.message);
        const json = await api('estado');
        aplicarEstado(json.estado);
    }

    // ════════════════════════════════════════════════
    //  Arranque
    // ════════════════════════════════════════════════

    async function iniciar() {
        mostrarPantalla('cargando');
        try {
            let json = await api('estado');
            if (!json.estado || json.estado.fase === 'fin') {
                json = await api('iniciar');
            }
            aplicarEstado(json.estado);
        } catch (e) {
            $('juego').querySelector('.cargando').textContent = 'No se pudo cargar la partida: ' + e.message;
        }
    }

    async function nuevaPartida() {
        mostrarPantalla('cargando');
        const json = await api('iniciar');
        aplicarEstado(json.estado);
    }

    /** Dibuja el HUD y abre la pantalla de la fase actual. */
    function aplicarEstado(nuevo) {
        estado = nuevo;
        dibujarHud();

        switch (estado.fase) {
            case 'girar':    prepararRuleta(); break;
            case 'pregunta': cargarPregunta(); break;
            case 'premio':   abrirPremio(); break;
            case 'fin':      mostrarFin(); break;
        }
    }

    // ════════════════════════════════════════════════
    //  HUD: vidas, letras, puntos, progreso y chance de Z
    // ════════════════════════════════════════════════

    function dibujarHud(vidaPerdida = false) {
        // Corazones: siempre se ven al menos 3 (los vacíos son vidas perdidas)
        const totalCorazones = Math.max(3, estado.vidas);
        $('hud-vidas').innerHTML = Array.from({ length: totalCorazones }, (_, i) => {
            const lleno = i < estado.vidas;
            const perdido = vidaPerdida && i === estado.vidas;
            return `<span class="corazon ${lleno ? '' : 'corazon-vacio'} ${perdido ? 'corazon-perdido' : ''}">❤</span>`;
        }).join('');

        $('hud-letras').innerHTML = estado.letras
            .map((l) => `<span class="letra ${l.obtenida ? 'letra-obtenida' : ''}">${l.letra}</span>`)
            .join('');

        $('hud-puntos').textContent = estado.puntos.toLocaleString('es-AR');
        $('hud-z').textContent = `${estado.prob_z.toLocaleString('es-AR')}%`;

        $('hud-pasos').innerHTML = Array.from({ length: estado.rondas_para_letra }, (_, i) =>
            `<span class="paso ${i < estado.rondas_superadas ? 'paso-ok' : ''}"></span>`
        ).join('');
        $('hud-progreso-texto').textContent = estado.rondas_superadas >= estado.rondas_para_letra
            ? '¡Ronda de letra lista!'
            : 'Rondas para la próxima letra';
    }

    function mostrarPantalla(nombre) {
        raiz.querySelectorAll('.pantalla').forEach((p) => {
            p.classList.toggle('visible', p.dataset.pantalla === nombre);
        });
    }

    // ════════════════════════════════════════════════
    //  Ruleta (apertura de caja de derecha a izquierda)
    // ════════════════════════════════════════════════

    function htmlItem(item) {
        const clase = item.especial ? `item-${item.especial}` : '';
        return `<div class="item ${clase}" style="--c:${item.color}">
                    <span class="item-emoji">${item.emoji}</span>
                    <span class="item-nombre">${item.nombre}</span>
                </div>`;
    }

    function prepararRuleta() {
        mostrarPantalla('girar');
        const tira = $('ruleta-tira');
        const listoParaLetra = estado.rondas_superadas >= estado.rondas_para_letra;

        $('ruleta-titulo').textContent = listoParaLetra ? '✦ Ronda de letra desbloqueada' : 'Girá la ruleta';
        $('ruleta-resultado').innerHTML = '&nbsp;';
        $('btn-girar').disabled = false;
        $('btn-girar').textContent = listoParaLetra ? 'Ir por la letra' : 'Girar';

        // Tira "de muestra" quieta mientras se espera el giro
        if (!tira.children.length || tira.dataset.usada === '1') {
            tira.style.transition = 'none';
            tira.style.transform = 'translateX(0)';
            tira.innerHTML = CATEGORIAS_MUESTRA.concat(CATEGORIAS_MUESTRA).map(htmlItem).join('');
            tira.dataset.usada = '0';
        }
    }

    async function girar() {
        const boton = $('btn-girar');
        boton.disabled = true;

        let json;
        try {
            json = await api('girar');
        } catch (e) {
            return sincronizar(e);
        }

        const tira = $('ruleta-tira');
        tira.style.transition = 'none';
        tira.style.transform = 'translateX(0)';
        tira.innerHTML = json.tira.map(htmlItem).join('');
        tira.dataset.usada = '1';

        // Cuánto hay que mover la tira para que el ganador quede bajo el marcador
        const item = tira.children[json.posicion];
        const ventana = $('ruleta').clientWidth;
        const azar = (Math.random() - 0.5) * item.offsetWidth * 0.6; // no siempre en el centro exacto
        const destino = item.offsetLeft + item.offsetWidth / 2 - ventana / 2 + azar;

        void tira.offsetWidth; // fuerza el reflow para que la transición arranque desde 0
        tira.style.transition = `transform ${DURACION_RULETA}ms cubic-bezier(.08, .62, .12, 1)`;
        tira.style.transform = `translateX(${-destino}px)`;

        await esperar(DURACION_RULETA + 150);
        item.classList.add('item-ganador');
        anunciarResultado(json.resultado);

        await esperar(1300);
        aplicarEstado(json.estado);
    }

    function anunciarResultado(resultado) {
        const texto = $('ruleta-resultado');
        texto.style.color = resultado.color;
        if (resultado.especial === 'z') {
            texto.textContent = '¡Categoría Z!';
            $('ruleta').classList.add('destello-z');
            setTimeout(() => $('ruleta').classList.remove('destello-z'), 1300);
        } else if (resultado.especial === 'letra') {
            texto.textContent = '✦ Ronda de letra';
        } else {
            texto.innerHTML = `${resultado.emoji} `;
            texto.append(resultado.nombre);
        }
    }

    // ════════════════════════════════════════════════
    //  Pregunta con temporizador
    // ════════════════════════════════════════════════

    async function cargarPregunta() {
        let json;
        try {
            json = await api('pregunta');
        } catch (e) {
            return sincronizar(e);
        }
        estado = json.estado;
        dibujarPregunta(json);
        mostrarPantalla('pregunta');
        arrancarReloj(json.tiempo_total, json.tiempo_restante);
        respondiendo = false;
    }

    function dibujarPregunta(datos) {
        const ronda = estado.ronda;
        const cat = datos.categoria;
        raiz.style.setProperty('--cat', cat.color);

        $('pregunta-categoria').innerHTML = `${cat.emoji} `;
        $('pregunta-categoria').append(cat.nombre);
        $('pregunta-ronda').textContent = ronda.tipo === 'letra'
            ? `✦ Ronda de letra ${estado.proxima_letra} · ${ronda.numero}/${ronda.total} · acertá ${estado.minimo_aciertos_letra} de ${ronda.total}`
            : `Pregunta ${ronda.numero}/${ronda.total} · necesitás ${estado.minimo_aciertos} correctas`;

        // Puntitos de la ronda: verdes los acertados (el servidor sólo informa el total)
        $('ronda-puntos').innerHTML = Array.from({ length: ronda.total }, (_, i) => {
            let clase = '';
            if (i < ronda.numero - 1) clase = i < ronda.aciertos ? 'ronda-punto-ok' : 'ronda-punto-mal';
            if (i === ronda.numero - 1) clase = 'ronda-punto-actual';
            return `<span class="ronda-punto ${clase}"></span>`;
        }).join('');

        $('pregunta-texto').textContent = datos.enunciado;

        const opciones = $('opciones');
        opciones.innerHTML = '';
        datos.opciones.forEach((op) => {
            const boton = document.createElement('button');
            boton.type = 'button';
            boton.className = 'opcion';
            boton.dataset.id = op.id;
            boton.innerHTML = `<span class="opcion-letra">${op.letra}</span><span></span>`;
            boton.lastChild.textContent = op.texto; // textContent: nunca se inyecta HTML
            boton.addEventListener('click', () => responder(op.id));
            opciones.appendChild(boton);
        });
    }

    function arrancarReloj(total, restante) {
        clearInterval(reloj);
        const arco = $('reloj-arco');
        const numero = $('reloj-numero');
        const circunferencia = 119.4; // 2·π·19
        const fin = Date.now() + restante * 1000;

        const pintar = () => {
            const quedan = Math.max(0, (fin - Date.now()) / 1000);
            numero.textContent = Math.ceil(quedan);
            arco.style.strokeDashoffset = circunferencia * (1 - quedan / total);
            $('reloj').classList.toggle('reloj-urgente', quedan <= 5);
            if (quedan <= 0) {
                clearInterval(reloj);
                responder(null); // se acabó el tiempo
            }
        };
        pintar();
        reloj = setInterval(pintar, 200);
    }

    async function responder(opcionId) {
        if (respondiendo) return;
        respondiendo = true;
        clearInterval(reloj);

        const botones = Array.from($('opciones').children);
        botones.forEach((b) => (b.disabled = true));

        let json;
        try {
            json = await api('responder', { opcion_id: opcionId });
        } catch (e) {
            return sincronizar(e);
        }

        // Pintar correcta / incorrecta
        botones.forEach((b) => {
            const id = Number(b.dataset.id);
            if (id === json.opcion_correcta) b.classList.add('opcion-correcta');
            else if (id === opcionId) b.classList.add('opcion-incorrecta');
            else b.classList.add('opcion-apagada');
        });
        if (json.fuera_de_tiempo || opcionId === null) {
            $('pregunta-ronda').textContent = '⏱ ¡Se acabó el tiempo!';
        }

        const vidaPerdida = json.resumen_ronda && json.resumen_ronda.vida_perdida;
        estado = json.estado;
        dibujarHud(vidaPerdida);

        await esperar(ESPERA_FEEDBACK);

        if (json.resumen_ronda) {
            ultimaRonda = { preguntas: json.resumen_ronda.preguntas, reportada: false };
            mostrarResumenRonda(json.resumen_ronda);
        } else {
            cargarPregunta();
        }
    }

    // ════════════════════════════════════════════════
    //  Resultado de la ronda
    // ════════════════════════════════════════════════

    function mostrarResumenRonda(r) {
        // Ronda de letra ganada: directo a elegir premio
        if (r.premio) {
            return aplicarEstado(estado);
        }

        let icono, titulo, detalle;
        if (r.tipo === 'categoria' && r.superada) {
            icono = '✅';
            titulo = '¡Ronda superada!';
            detalle = `Acertaste ${r.aciertos} de ${r.total}.`;
            if (r.letra_desbloqueada) detalle += ' ✦ Desbloqueaste una ronda de letra.';
        } else if (r.tipo === 'categoria') {
            icono = '💔';
            titulo = 'Perdiste una vida';
            detalle = `Acertaste ${r.aciertos} de ${r.total}. Necesitabas ${estado.minimo_aciertos}.`;
        } else {
            icono = '✦';
            titulo = 'Se escapó la letra';
            detalle = `Acertaste ${r.aciertos} de ${r.total}: para ganarla necesitabas ${estado.minimo_aciertos_letra}.`;
        }

        if (estado.fase === 'fin') {
            detalle += ' Te quedaste sin vidas.';
        }

        $('ronda-icono').textContent = icono;
        $('ronda-titulo').textContent = titulo;
        $('ronda-detalle').textContent = detalle;
        $('btn-continuar').textContent = estado.fase === 'fin' ? 'Ver resultado' : 'Continuar';
        prepararLinkReporte();
        $('modal-ronda').hidden = false;
    }

    // ════════════════════════════════════════════════
    //  Premio: letra o corazón
    // ════════════════════════════════════════════════

    function abrirPremio() {
        const porZ = estado.origen_premio === 'z';
        $('premio-sobretitulo').textContent = porZ ? 'Categoría Z · pura suerte' : 'Ronda de letra superada';
        $('premio-titulo').textContent = porZ ? '¡Te tocó la Z!' : 'Elegí tu premio';
        $('premio-letra').textContent = estado.proxima_letra;
        $('premio-vida').disabled = !estado.puede_elegir_vida;
        $('premio-vida-texto').textContent = estado.puede_elegir_vida
            ? 'Para aguantar más'
            : `Ya tenés el máximo (${estado.vidas_maximas})`;
        // Si el premio viene de la categoría Z no hubo preguntas: no hay nada que reportar.
        $('reporte-desde-premio').hidden = porZ || !ultimaRonda;
        prepararLinkReporte();
        $('modal-premio').hidden = false;
    }

    async function elegirPremio(eleccion) {
        $('modal-premio').hidden = true;
        try {
            const json = await api('premio', { eleccion });
            aplicarEstado(json.estado);
        } catch (e) {
            sincronizar(e);
        }
    }

    // ════════════════════════════════════════════════
    //  Reportar un problema (solo al terminar una ronda)
    // ════════════════════════════════════════════════

    function prepararLinkReporte() {
        const enviado = ultimaRonda && ultimaRonda.reportada;
        raiz.querySelectorAll('[data-abrir-reporte]').forEach((link) => {
            link.disabled = !ultimaRonda || enviado;
            link.textContent = enviado ? '✓ Reporte enviado. ¡Gracias!' : '⚠ Reportar un problema';
        });
    }

    function abrirReporte(link) {
        if (!ultimaRonda || ultimaRonda.reportada) return;
        modalDeOrigen = link.closest('.modal');
        modalDeOrigen.hidden = true;

        // Las preguntas de la ronda numeradas 1, 2, 3 para tildar las que tienen problemas
        const lista = $('reporte-preguntas');
        lista.innerHTML = '';
        ultimaRonda.preguntas.forEach((p) => {
            const item = document.createElement('label');
            item.className = 'reporte-pregunta';
            item.style.setProperty('--c', p.color);
            item.innerHTML = `<input type="checkbox" value="${p.numero}"><span class="reporte-numero">${p.numero}</span>`
                + '<span class="reporte-texto"><small></small><b></b></span>';
            item.querySelector('small').textContent = p.categoria;
            item.querySelector('b').textContent = p.enunciado;
            lista.appendChild(item);
        });
        $('form-reporte').reset();
        $('reporte-error').hidden = true;
        $('modal-reporte').hidden = false;
    }

    function cerrarReporte() {
        $('modal-reporte').hidden = true;
        if (modalDeOrigen) modalDeOrigen.hidden = false;
        prepararLinkReporte();
    }

    async function enviarReporte(e) {
        e.preventDefault();
        const form = $('form-reporte');
        const preguntas = [...form.querySelectorAll('.reporte-pregunta input:checked')].map((c) => Number(c.value));
        const motivo = (form.querySelector('input[name=motivo]:checked') || {}).value;
        const error = $('reporte-error');

        if (!preguntas.length) { error.textContent = 'Tildá al menos una pregunta.'; error.hidden = false; return; }
        if (!motivo) { error.textContent = 'Elegí un motivo.'; error.hidden = false; return; }

        $('reporte-enviar').disabled = true;
        try {
            await api('reportar', { preguntas, motivo, detalle: $('reporte-detalle').value });
            ultimaRonda.reportada = true;
            cerrarReporte();
        } catch (err) {
            error.textContent = err.message;
            error.hidden = false;
        } finally {
            $('reporte-enviar').disabled = false;
        }
    }

    // ════════════════════════════════════════════════
    //  Fin de partida
    // ════════════════════════════════════════════════

    function mostrarFin() {
        const gano = estado.resultado === 'victoria';
        const fin = $('fin');
        fin.classList.toggle('fin-victoria', gano);
        fin.classList.toggle('fin-derrota', !gano);

        $('fin-sobretitulo').textContent = gano ? 'Llegaste a tu zenit' : 'Fin de la partida';
        $('fin-titulo').textContent = gano ? '¡ZENIT!' : 'Sin vidas';
        $('fin-letras').innerHTML = $('hud-letras').innerHTML;
        $('fin-puntos').textContent = estado.puntos.toLocaleString('es-AR');
        $('fin-correctas').textContent = `${estado.correctas}/${estado.respondidas}`;
        $('fin-cant-letras').textContent = `${estado.cantidad_letras}/5`;
        mostrarPantalla('fin');
    }

    // ════════════════════════════════════════════════
    //  Utilidades y eventos
    // ════════════════════════════════════════════════

    function esperar(ms) {
        return new Promise((r) => setTimeout(r, ms));
    }

    // Ítems de muestra de la ruleta (antes del primer giro), leídos del HTML
    const CATEGORIAS_MUESTRA = JSON.parse(raiz.dataset.categorias || '[]');

    $('btn-girar').addEventListener('click', girar);
    $('btn-nueva').addEventListener('click', nuevaPartida);
    $('btn-continuar').addEventListener('click', () => {
        $('modal-ronda').hidden = true;
        aplicarEstado(estado);
    });
    raiz.querySelectorAll('[data-abrir-reporte]').forEach((link) => link.addEventListener('click', () => abrirReporte(link)));
    $('reporte-cancelar').addEventListener('click', cerrarReporte);
    $('form-reporte').addEventListener('submit', enviarReporte);
    raiz.querySelectorAll('.premio').forEach((boton) => {
        boton.addEventListener('click', () => elegirPremio(boton.dataset.eleccion));
    });

    iniciar();
})();
