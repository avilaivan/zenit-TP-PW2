/* ════════════════════════════════════════════════════════════
   ZENIT · Selector de ubicación (registro y editar perfil)

   - Mapa (Leaflet): tocás un punto y se completan país y ciudad.
   - País: sugerencias con bandera mientras escribís ("ar" → Argentina,
     Armenia…), con la lista de public/data/paises.json.
   - Ciudad: sugerencias desde Photon (OpenStreetMap), filtradas por
     el país elegido. Al elegir una, el mapa se mueve hasta ahí.
   ════════════════════════════════════════════════════════════ */
(function () {
    'use strict';

    const BASE = document.body.dataset.base || '';
    let PAISES = []; // [[codigo, nombre], …] — se carga de public/data/paises.json
    const bandera = (codigo) => `https://flagcdn.com/w40/${codigo}.png`;
    const NOMINATIM = 'https://nominatim.openstreetmap.org';
    const PHOTON = 'https://photon.komoot.io/api/';
    const TIPOS_CIUDAD = ['city', 'town', 'village', 'municipality', 'suburb', 'hamlet'];

    /** "Bogotá " → "bogota" (para comparar sin acentos ni mayúsculas) */
    const normalizar = (texto) => (texto || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim();

    fetch(`${BASE}/public/data/paises.json`)
        .then((r) => r.json())
        .then((lista) => { PAISES = lista.map((p) => [p.codigo, p.nombre]); })
        .catch(() => { /* sin lista: igual se puede escribir y el servidor valida */ })
        .finally(() => document.querySelectorAll('[data-ubicacion]').forEach(iniciar));

    function iniciar(caja) {
        const campo = (selector) => caja.querySelector(selector);
        const pais = campo('[data-pais]');
        const ciudad = campo('[data-ciudad]');
        const lat = campo('[data-lat]');
        const lon = campo('[data-lon]');
        const estado = campo('[data-estado]');
        const contenedorMapa = campo('[data-mapa]');

        // ── Mapa ──────────────────────────────────────
        let mapa = null;
        let marcador = null;
        const icono = window.L && L.divIcon({ className: 'marcador-zenit', html: '<span></span>', iconSize: [18, 18] });

        if (window.L && contenedorMapa) {
            // Mapa del mundo entero (mosaicos libres de OpenStreetMap, sin API key)
            mapa = L.map(contenedorMapa, {
                minZoom: 1,
                maxZoom: 18,
                zoomSnap: 0.25,          // permite encuadrar el planeta completo
                worldCopyJump: true,
                maxBounds: [[-85, -540], [85, 540]],
                maxBoundsViscosity: 0.8,
            });
            L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
                maxZoom: 18,
                attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
            }).addTo(mapa);
            mapa.fitWorld();

            if (lat.value && lon.value) {
                ponerMarcador(parseFloat(lat.value), parseFloat(lon.value)); // se marca sin perder la vista del mundo
            }
            mapa.on('click', (e) => {
                ponerMarcador(e.latlng.lat, e.latlng.lng);
                lugarDesdeCoordenadas(e.latlng.lat, e.latlng.lng);
            });
            // Si el mapa estaba oculto al crearse, recalcula su tamaño
            setTimeout(() => { mapa.invalidateSize(); if (!marcador) mapa.fitWorld(); }, 300);
        } else if (contenedorMapa) {
            contenedorMapa.closest('.campo').hidden = true;
            estado.textContent = 'El mapa no cargó (¿sin internet?). Podés escribir país y ciudad.';
        }

        function ponerMarcador(latitud, longitud, zoom) {
            lat.value = latitud.toFixed(7);
            lon.value = longitud.toFixed(7);
            if (!mapa) return;
            if (marcador) marcador.setLatLng([latitud, longitud]);
            else marcador = L.marker([latitud, longitud], { icon: icono }).addTo(mapa);
            if (zoom) mapa.setView([latitud, longitud], zoom);
        }

        // ── Mapa → país y ciudad (geocodificación inversa) ──
        async function lugarDesdeCoordenadas(latitud, longitud) {
            estado.textContent = 'Buscando ciudad…';
            try {
                const url = `${NOMINATIM}/reverse?format=jsonv2&accept-language=es&zoom=10&lat=${latitud}&lon=${longitud}`;
                const d = (await (await fetch(url)).json()).address || {};
                if (!d.country) {
                    estado.textContent = 'Ahí no hay un país. Probá otro punto.';
                    return;
                }
                pais.value = nombrePais(d.country_code) || d.country;
                ciudad.value = d.city || d.town || d.village || d.municipality || d.county || d.state || '';
                estado.textContent = `📍 ${ciudad.value ? ciudad.value + ', ' : ''}${pais.value}`;
            } catch (e) {
                estado.textContent = 'No se pudo consultar el mapa. Escribí país y ciudad.';
            }
        }

        function nombrePais(codigo) {
            const fila = PAISES.find((p) => p[0] === (codigo || '').toLowerCase());
            return fila ? fila[1] : null;
        }

        function codigoPais() {
            const fila = PAISES.find((p) => normalizar(p[1]) === normalizar(pais.value));
            return fila ? fila[0] : null;
        }

        // ── Sugerencias de país (lista local) ─────────
        autocompletar(pais, 0, (texto) => {
            const q = normalizar(texto);
            if (!q) return [];
            const empiezan = PAISES.filter((p) => normalizar(p[1]).startsWith(q));
            const contienen = PAISES.filter((p) => !normalizar(p[1]).startsWith(q) && normalizar(p[1]).includes(q));
            return empiezan.concat(contienen).slice(0, 8).map((p) => ({ texto: p[1], codigo: p[0], bandera: bandera(p[0]) }));
        }, (item) => {
            pais.value = item.texto;
            ciudad.value = '';
            centrarEnPais(item.texto);
            ciudad.focus();
        });

        async function centrarEnPais(nombre) {
            if (!mapa) return;
            try {
                const url = `${NOMINATIM}/search?format=jsonv2&limit=1&accept-language=es&country=${encodeURIComponent(nombre)}`;
                const [lugar] = await (await fetch(url)).json();
                if (lugar) mapa.fitBounds([[lugar.boundingbox[0], lugar.boundingbox[2]], [lugar.boundingbox[1], lugar.boundingbox[3]]]);
            } catch (e) { /* no es grave */ }
        }

        // ── Sugerencias de ciudad (Photon, filtradas por país) ──
        autocompletar(ciudad, 300, async (texto) => {
            if (normalizar(texto).length < 2) return [];
            const codigo = codigoPais();
            const centro = mapa ? mapa.getCenter() : null;
            const params = new URLSearchParams({ q: texto, limit: 20, osm_tag: 'place' });
            if (centro) { params.set('lat', centro.lat); params.set('lon', centro.lng); }

            const datos = await (await fetch(`${PHOTON}?${params}`)).json();
            return datos.features
                .filter((f) => TIPOS_CIUDAD.includes(f.properties.osm_value))
                .filter((f) => !codigo || (f.properties.countrycode || '').toLowerCase() === codigo)
                .slice(0, 8)
                .map((f) => ({
                    texto: f.properties.name,
                    detalle: [f.properties.state, nombrePais(f.properties.countrycode) || f.properties.country].filter(Boolean).join(', '),
                    codigo: (f.properties.countrycode || '').toLowerCase(),
                    bandera: f.properties.countrycode ? bandera(f.properties.countrycode.toLowerCase()) : null,
                    lat: f.geometry.coordinates[1],
                    lon: f.geometry.coordinates[0],
                }));
        }, (item) => {
            ciudad.value = item.texto;
            if (!pais.value) pais.value = nombrePais(item.codigo) || '';
            ponerMarcador(item.lat, item.lon, 6);
            estado.textContent = `📍 ${item.texto}, ${pais.value}`;
        });
    }

    /**
     * Lista desplegable de sugerencias debajo de un input.
     * @param {HTMLInputElement} input
     * @param {number} espera   ms antes de buscar (para no consultar en cada tecla)
     * @param {Function} buscar texto → [{texto, detalle?}] (puede ser async)
     * @param {Function} elegir item elegido
     */
    function autocompletar(input, espera, buscar, elegir) {
        const lista = input.parentElement.querySelector('.sugerencias');
        let items = [];
        let marcado = -1;
        let temporizador = null;
        let consulta = 0;

        const cerrar = () => { lista.hidden = true; marcado = -1; };

        function dibujar() {
            lista.innerHTML = '';
            items.forEach((item, i) => {
                const li = document.createElement('li');
                li.setAttribute('role', 'option');
                li.className = (i === marcado ? 'marcado ' : '') + (item.bandera ? 'con-bandera' : '');
                li.innerHTML = (item.bandera ? `<img class="bandera" src="${item.bandera}" alt="">` : '')
                    + '<span class="sug-texto"><b></b><small></small></span>';
                li.querySelector('b').textContent = item.texto;
                li.querySelector('small').textContent = item.detalle || '';
                // mousedown (no click) para elegir antes de que el input pierda el foco
                li.addEventListener('mousedown', (e) => { e.preventDefault(); cerrar(); elegir(item); });
                lista.appendChild(li);
            });
            lista.hidden = items.length === 0;
        }

        input.addEventListener('input', () => {
            clearTimeout(temporizador);
            const numero = ++consulta;
            temporizador = setTimeout(async () => {
                try {
                    const resultado = await buscar(input.value);
                    if (numero !== consulta) return; // llegó una respuesta vieja
                    items = resultado;
                    marcado = -1;
                    dibujar();
                } catch (e) {
                    cerrar();
                }
            }, espera);
        });

        input.addEventListener('keydown', (e) => {
            if (lista.hidden) return;
            if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
                e.preventDefault();
                marcado = (marcado + (e.key === 'ArrowDown' ? 1 : -1) + items.length) % items.length;
                dibujar();
            } else if (e.key === 'Enter' && marcado >= 0) {
                e.preventDefault();
                const item = items[marcado];
                cerrar();
                elegir(item);
            } else if (e.key === 'Escape') {
                cerrar();
            }
        });

        input.addEventListener('blur', () => setTimeout(cerrar, 120));
    }
})();
