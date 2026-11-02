/* ════════════════════════════════════════════════════════════
   ZENIT · Editor de foto de perfil (recorte circular)

   Estilo Instagram/Steam: elegís cualquier imagen, la movés y la
   acercás dentro de un círculo, y se guarda un cuadrado estándar de
   512×512 px. El recorte se hace en el navegador con <canvas> y el
   servidor igual vuelve a validar y normalizar la imagen.
   ════════════════════════════════════════════════════════════ */
(function () {
    'use strict';

    const LADO_FINAL = 512;
    const $ = (id) => document.getElementById(id);

    const modal = $('editor-foto');
    const archivo = $('foto-archivo');
    if (!modal || !archivo) return;

    const area = $('editor-area');
    const imagen = $('editor-imagen');
    const zoom = $('editor-zoom');
    const error = $('editor-error');
    const BASE = document.body.dataset.base;

    // Estado del recorte: posición (x, y) de la esquina de la imagen y escala
    let escalaBase = 1;   // la escala mínima para cubrir el círculo
    let escala = 1;
    let x = 0;
    let y = 0;
    const punteros = new Map(); // dedos / mouse activos (para arrastrar y pellizcar)
    let distanciaInicial = 0;
    let zoomInicial = 1;

    // ── Abrir el editor al elegir archivo ─────────────
    archivo.addEventListener('change', () => {
        const elegido = archivo.files[0];
        if (!elegido) return;
        if (!/^image\/(jpeg|png|webp)$/.test(elegido.type)) {
            alert('Elegí una imagen JPG, PNG o WEBP.');
            return;
        }
        imagen.onload = prepararImagen;
        imagen.src = URL.createObjectURL(elegido);
        error.hidden = true;
        modal.hidden = false;
    });

    function lado() {
        return area.clientWidth;
    }

    function prepararImagen() {
        escalaBase = Math.max(lado() / imagen.naturalWidth, lado() / imagen.naturalHeight);
        zoom.value = 1;
        escala = escalaBase;
        // centrada
        x = (lado() - imagen.naturalWidth * escala) / 2;
        y = (lado() - imagen.naturalHeight * escala) / 2;
        dibujar();
    }

    /** Evita que queden huecos: la imagen siempre cubre todo el círculo. */
    function limitar() {
        const ancho = imagen.naturalWidth * escala;
        const alto = imagen.naturalHeight * escala;
        x = Math.min(0, Math.max(lado() - ancho, x));
        y = Math.min(0, Math.max(lado() - alto, y));
    }

    function dibujar() {
        limitar();
        imagen.style.transform = `translate(${x}px, ${y}px) scale(${escala})`;
    }

    /** Cambia el zoom manteniendo fijo el punto (cx, cy) del área. */
    function aplicarZoom(nuevoZoom, cx = lado() / 2, cy = lado() / 2) {
        nuevoZoom = Math.min(4, Math.max(1, nuevoZoom));
        const nuevaEscala = escalaBase * nuevoZoom;
        x = cx - (cx - x) * (nuevaEscala / escala);
        y = cy - (cy - y) * (nuevaEscala / escala);
        escala = nuevaEscala;
        zoom.value = nuevoZoom;
        dibujar();
    }

    zoom.addEventListener('input', () => aplicarZoom(parseFloat(zoom.value)));

    area.addEventListener('wheel', (e) => {
        e.preventDefault();
        const r = area.getBoundingClientRect();
        aplicarZoom(parseFloat(zoom.value) * (e.deltaY < 0 ? 1.08 : 0.93), e.clientX - r.left, e.clientY - r.top);
    }, { passive: false });

    // ── Arrastrar (mouse o dedo) y pellizcar (dos dedos) ──
    area.addEventListener('pointerdown', (e) => {
        area.setPointerCapture(e.pointerId);
        punteros.set(e.pointerId, { x: e.clientX, y: e.clientY });
        if (punteros.size === 2) {
            distanciaInicial = distancia();
            zoomInicial = parseFloat(zoom.value);
        }
    });

    area.addEventListener('pointermove', (e) => {
        const anterior = punteros.get(e.pointerId);
        if (!anterior) return;
        punteros.set(e.pointerId, { x: e.clientX, y: e.clientY });

        if (punteros.size === 1) {
            x += e.clientX - anterior.x;
            y += e.clientY - anterior.y;
            dibujar();
        } else if (punteros.size === 2 && distanciaInicial > 0) {
            aplicarZoom(zoomInicial * distancia() / distanciaInicial);
        }
    });

    const soltar = (e) => { punteros.delete(e.pointerId); distanciaInicial = 0; };
    area.addEventListener('pointerup', soltar);
    area.addEventListener('pointercancel', soltar);

    function distancia() {
        const [a, b] = [...punteros.values()];
        return Math.hypot(a.x - b.x, a.y - b.y);
    }

    // ── Guardar: recorte en canvas → subida ──────────
    $('editor-cancelar').addEventListener('click', cerrar);

    $('editor-guardar').addEventListener('click', async () => {
        const boton = $('editor-guardar');
        boton.disabled = true;
        boton.textContent = 'Guardando…';

        const canvas = document.createElement('canvas');
        canvas.width = canvas.height = LADO_FINAL;
        const ctx = canvas.getContext('2d');
        ctx.fillStyle = '#121417';
        ctx.fillRect(0, 0, LADO_FINAL, LADO_FINAL);
        // Parte de la imagen original que se ve dentro del área
        ctx.drawImage(imagen, -x / escala, -y / escala, lado() / escala, lado() / escala, 0, 0, LADO_FINAL, LADO_FINAL);

        try {
            const blob = await new Promise((ok) => canvas.toBlob(ok, 'image/jpeg', 0.92));
            const datos = new FormData();
            datos.append('foto_perfil', blob, 'avatar.jpg');
            const respuesta = await fetch(`${BASE}/perfil/foto`, { method: 'POST', body: datos });
            const json = await respuesta.json();
            if (!json.ok) throw new Error(json.error);

            // Actualizar todas las fotos visibles del usuario
            document.querySelectorAll('#avatar-actual .avatar, .chip-usuario .avatar').forEach((avatar) => {
                avatar.innerHTML = `<img src="${json.foto}" alt="Tu foto">`;
            });
            cerrar();
        } catch (e) {
            error.textContent = e.message || 'No se pudo guardar la foto.';
            error.hidden = false;
        } finally {
            boton.disabled = false;
            boton.textContent = 'Guardar foto';
        }
    });

    function cerrar() {
        modal.hidden = true;
        archivo.value = '';
        if (imagen.src) URL.revokeObjectURL(imagen.src);
    }
})();
