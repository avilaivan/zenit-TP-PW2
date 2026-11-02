/* ════════════════════════════════════════════════════════════
   ZENIT · Perfil
   - Menú ⋮ (editar perfil, contraseña, cerrar sesión, eliminar cuenta).
   - QR que lleva al perfil público (librería qrcodejs).
   - Botón para copiar el enlace.
   - Mapa con la ubicación del jugador (Leaflet + OpenStreetMap).
   ════════════════════════════════════════════════════════════ */
(function () {
    'use strict';

    // ── Menú de tres puntos ───────────────────────────
    const menu = document.querySelector('[data-menu]');
    if (menu) {
        const boton = menu.querySelector('[data-menu-boton]');
        const lista = menu.querySelector('[data-menu-lista]');
        const abrir = (abierto) => {
            lista.hidden = !abierto;
            boton.setAttribute('aria-expanded', String(abierto));
        };
        boton.addEventListener('click', (e) => { e.stopPropagation(); abrir(lista.hidden); });
        document.addEventListener('click', (e) => { if (!menu.contains(e.target)) abrir(false); });
        document.addEventListener('keydown', (e) => { if (e.key === 'Escape') abrir(false); });
    }

    // ── Banderas: si la imagen no carga (sin internet), se muestra el emoji ──
    document.querySelectorAll('img.bandera').forEach((img) => {
        const aEmoji = () => {
            const span = document.createElement('span');
            span.className = 'bandera-emoji';
            span.textContent = img.alt;
            img.replaceWith(span);
        };
        if (img.complete && img.naturalWidth === 0) aEmoji();
        else img.addEventListener('error', aEmoji);
    });

    // ── Mapa de la ubicación ──────────────────────────
    const caja = document.getElementById('mapa-perfil');
    if (caja) {
        const sinMapa = (texto) => { caja.classList.add('mapa-sin-conexion'); caja.textContent = texto; };

        const mostrar = (lat, lon) => {
            const mapa = L.map(caja, { scrollWheelZoom: false, zoomControl: true }).setView([lat, lon], 10);
            L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
                maxZoom: 18,
                attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
            }).addTo(mapa);
            const icono = L.divIcon({ className: 'marcador-zenit', html: '<span></span>', iconSize: [18, 18] });
            L.marker([lat, lon], { icon: icono, keyboard: false }).addTo(mapa);
        };

        if (!window.L) {
            sinMapa('El mapa no cargó (¿sin internet?).');
        } else if (caja.dataset.lat && caja.dataset.lon) {
            mostrar(parseFloat(caja.dataset.lat), parseFloat(caja.dataset.lon));
        } else {
            // No marcó el mapa al registrarse: se busca la ciudad por nombre (Nominatim)
            fetch('https://nominatim.openstreetmap.org/search?format=json&limit=1&q=' + encodeURIComponent(caja.dataset.buscar))
                .then((r) => r.json())
                .then((res) => (res[0] ? mostrar(parseFloat(res[0].lat), parseFloat(res[0].lon)) : sinMapa('No encontramos la ciudad en el mapa.')))
                .catch(() => sinMapa('El mapa no cargó (¿sin internet?).'));
        }
    }

    // ── QR ────────────────────────────────────────────
    const qr = document.getElementById('qr');
    if (qr) {
        if (typeof QRCode !== 'undefined') {
            new QRCode(qr, {
                text: qr.dataset.url,
                width: 260,
                height: 260,
                colorDark: '#121417',
                colorLight: '#F2F3F5',
                correctLevel: QRCode.CorrectLevel.M,
            });
            qr.removeAttribute('title'); // qrcodejs pone la URL como tooltip
        } else {
            // Respaldo si el CDN de la librería no cargó: imagen generada por api.qrserver.com
            const img = document.createElement('img');
            img.alt = 'Código QR del perfil';
            img.src = 'https://api.qrserver.com/v1/create-qr-code/?size=260x260&margin=0&data='
                + encodeURIComponent(qr.dataset.url);
            img.onerror = () => { qr.classList.add('qr-sin-conexion'); qr.textContent = 'QR no disponible sin conexión'; };
            qr.appendChild(img);
        }
    }

    // ── Copiar enlace ─────────────────────────────────
    const copiar = document.getElementById('btn-copiar');
    if (copiar) {
        copiar.addEventListener('click', async function () {
            try {
                await navigator.clipboard.writeText(copiar.dataset.url);
                copiar.textContent = '¡Copiado!';
            } catch (e) {
                window.prompt('Copiá el enlace:', copiar.dataset.url);
            }
            setTimeout(() => (copiar.textContent = 'Copiar enlace'), 2000);
        });
    }
})();
