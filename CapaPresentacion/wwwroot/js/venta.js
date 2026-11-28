/* Punto de venta: tarjetas de productos (más vendidos primero), salsas y adiciones, ingredientes que se quitan,
   pedidos por cobrar, edición de pedidos dentro del tiempo permitido y comandas en proceso. */
(function () {
    const $ = id => document.getElementById(id);
    const modalProducto = new bootstrap.Modal($('modalProducto'));
    const modalListo = new bootstrap.Modal($('modalListo'));
    // Yesenia Quejada Rojas - Claude — 30/10/2026: las adiciones van de primeras en el cuadro de cada producto.
    // Yesenia Quejada Rojas - Claude — 02/11/2026: ahora van primero las salsas (lo que más se pide) y después las adiciones. Solo en Vender; la carta pública no cambia.
    const ORDEN_GRUPOS = ['Salsas', 'Adiciones', 'Preferencias', 'Vasos'];
    const GRUPOS_UNICOS = ['Vasos'];   // grupos donde solo se marca una opción
    const CLAVE_ESPERA = 'pos-espera';
    const TACTIL = matchMedia('(hover: none), (pointer: coarse)').matches;
    /* Yesenia Quejada Rojas - Claude — 19/10/2026. Colores de las pastillas de salsas para reconocerlas rápido sin fotos.
       Yesenia Quejada Rojas - Claude — 01/11/2026. Ahora cada salsa toma el color y un ícono de SU sabor (tomate rojo, mostaza amarilla, piña, maíz,
       ajo...); la lista de abajo solo es la reserva de colores para las salsas nuevas que no se reconocen por el nombre. */
    const COLORES_SALSA = ['#8e24aa', '#00897b', '#1e88e5', '#546e7a', '#6d4c41', '#d81b60'];
    const SABORES_SALSA = [   // [palabra del nombre (sin tildes), color, ícono]; la primera que coincide gana (chipotle antes que mayonesa)
        [/chipotle/, '#e0662c', '🌶️'], [/picante|aji|jalape|rocoto/, '#e8470c', '🌶️'], [/tomate|ketchup|catsup/, '#e53935', '🍅'],
        [/bbq|barbac/, '#8d4b25', '🍖'], [/mostaza/, '#e3a900', '🌭'], [/pina/, '#f5d33f', '🍍'], [/maiz/, '#f6b800', '🌽'],
        [/ajo/, '#e8dfc4', '🧄'], [/mayonesa|mayo/, '#f4ecd2', '🥚'], [/rosada|rosa/, '#ef6f9b', ''],
        [/cilantro|guasaca|verde|chimichurri/, '#3f9d46', '🌿'], [/queso|cheddar/, '#f7a823', '🧀'], [/miel/, '#e29b12', '🍯'],
        [/limon/, '#c3cf3a', '🍋'], [/aguacate|guacamole/, '#78a83a', '🥑'], [/tartara/, '#c4b27a', '🥒']
    ];
    // Ícono chiquito al lado de adiciones, vasos y de lo que se puede quitar ("Sin pepino"), para guiarse más fácil.
    const ICONOS_OPCION = [
        [/tocineta|bacon|chicharron/, '🥓'], [/queso|mozzarella|lonchita|filadelfia/, '🧀'], [/huevo/, '🥚'], [/maicito|maiz/, '🌽'], [/papa/, '🍟'],
        [/guacamole|aguacate/, '🥑'], [/ensalada|lechuga/, '🥬'], [/tomate|pico de gallo|hogao/, '🍅'], [/cebolla/, '🧅'], [/pepino|pepinillo/, '🥒'],
        [/pina/, '🍍'], [/limon/, '🍋'], [/salchicha|chorizo|butifarra/, '🌭'], [/vaso/, '🥤'], [/platano|maduro|patacon/, '🍌'], [/cilantro|perejil/, '🌿'], [/ajo/, '🧄'],
        [/caja/, '📦'], [/bolsa/, '🛍️'], [/servilleta/, '🧻'], [/cuchillo|tenedor/, '🍴'], [/plato/, '🍽️'], [/porta /, '🥡']
    ];
    const EMPAQUE = /caja|bolsa|servilleta|cuchillo|tenedor|porta |vaso|tapa|plato|papel|aluminio/;   // empaque y cubiertos: van al final de "Sin ..."
    const sinTildes = t => (t || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
    // Color claro (mayonesa, ajo, piña...): al elegirlo el texto va oscuro para que se lea.
    const esClaro = hex => {
        const [r, g, b] = [1, 3, 5].map(k => parseInt(hex.slice(k, k + 2), 16) / 255).map(c => c <= .03928 ? c / 12.92 : ((c + .055) / 1.055) ** 2.4);
        return .2126 * r + .7152 * g + .0722 * b > .3;
    };
    function saborSalsa(nombre, i) {
        const n = sinTildes(nombre), s = SABORES_SALSA.find(([re]) => re.test(n));
        const color = s ? s[1] : COLORES_SALSA[i % COLORES_SALSA.length];
        return { color, icono: s ? s[2] : '', claro: esClaro(color) };
    }
    // Lo que va entre paréntesis ("Papa ripio (bolsa)") no cuenta: "bolsa" no vuelve empaque a la papa.
    const sinParentesis = t => (t || '').replace(/\s*\(.*\)\s*$/, '');
    const iconoOpcion = nombre => {
        const n = sinTildes(sinParentesis(nombre)), x = ICONOS_OPCION.find(([re]) => re.test(n));
        return x ? `<span class="icono-opcion" aria-hidden="true">${x[1]}</span>` : '';
    };
    /* "Sin salsas" viaja a cocina dentro de las notas de la línea ("SIN SALSAS · bien asada"): no hay otro campo y así sale en la comanda y en
       la factura. Al editar un pedido ya cobrado se separa de nuevo. Las notas de la base de datos tienen máximo 150 caracteres. */
    const SIN_SALSAS = 'SIN SALSAS';
    const notasDe = l => [l.sinSalsas ? SIN_SALSAS : '', l.notas].filter(Boolean).join(' · ').slice(0, 150);
    function separarSinSalsas(notas) {
        const m = /^SIN SALSAS(?:\s*·\s*)?/i.exec(notas || '');
        return m ? { sinSalsas: true, notas: notas.slice(m[0].length).trim() } : { sinSalsas: false, notas: notas || '' };
    }

    let productos = [], modificadores = [], ingredientes = [], categoria = 0, top = new Map();
    let pedido = [];            // { clave, idProducto, nombre, precio, cantidad, notas, mods:[{idModificador,nombre,precio,grupo}], sin:[{idInsumo,nombre}] }
    let actual = null, cantidad = 1;
    let tipo = 'MESA', pago = 'EFECTIVO', cajaAbierta = true;
    let edicion = null;         // { idVenta, vence (ms) } cuando se edita un pedido ya cobrado
    let procesando = false;
    let origenCarta = null;     // id del pedido de la carta digital que está en pantalla (se cierra al cobrarlo)
    /* Yesenia Quejada Rojas - Claude — 31/10/2026. Cajas de empaque del pedido: se sugieren por producto (los que llevan "Caja de empaque"
       en la receta) y el cajero las ajusta con − / +. Mientras no las toque (cajasManual = null) siguen a los productos; al cerrar la
       caja se cuentan como "cajas gastadas". Es solo un conteo: no mueve el inventario (eso ya lo hace la receta). */
    const NOMBRE_CAJA = 'Caja de empaque';
    let productosConCaja = new Set(), cajasManual = null;

    const precioLinea = l => (l.precio + l.mods.reduce((s, m) => s + m.precio, 0)) * l.cantidad;
    const subtotal = () => pedido.reduce((s, l) => s + precioLinea(l), 0);
    const envio = () => tipo === 'DOMICILIO' ? Number($('txtCostoDomicilio').value || 0) : 0;
    const total = () => subtotal() + envio();
    const cajasSugeridasDe = lineas => lineas.reduce((s, l) => s + (productosConCaja.has(l.idProducto) ? l.cantidad : 0), 0);
    const cajasDe = (lineas, manual) => Math.min(99, manual ?? cajasSugeridasDe(lineas));
    const cajas = () => cajasDe(pedido, cajasManual);
    const textoCajas = n => `${n} ${n === 1 ? 'caja' : 'cajas'}`;
    // Yesenia Quejada Rojas - Claude — 01/11/2026: renglón rojo "Sin salsas, pepino" de una línea del pedido (vacío si no quitó nada).
    const textoSin = l => {
        const t = [...(l.sinSalsas ? ['salsas'] : []), ...(l.sin || []).map(s => nombreCorto(s.nombre))];
        return t.length ? `<small class="d-block text-danger">Sin ${t.map(x => esc(x)).join(', ')}</small>` : '';
    };
    // Si el número coincide con lo sugerido vuelve a seguir a los productos (no queda "ajustado" sin motivo).
    function fijarCajas(n) {
        n = Math.max(0, Math.min(99, n));
        cajasManual = n === cajasSugeridasDe(pedido) ? null : n;
    }
    const enPedido = idProducto => pedido.filter(l => l.idProducto === idProducto).reduce((s, l) => s + l.cantidad, 0);
    // "Queso mozzarella (tajada)" se muestra como "queso mozzarella" en "Sin ..."
    const nombreCorto = n => n.replace(/\s*\(.*\)\s*$/, '').toLowerCase();
    const opcionesDe = idProducto => ({
        mods: modificadores.filter(m => m.idProducto === idProducto),
        sin: ingredientes.filter(i => i.idProducto === idProducto)
    });

    /* ---------- Catálogo ---------- */
    async function cargar() {
        try {
            const [cat, caja] = await Promise.all([api.get('/Venta/Catalogo'), api.get('/Caja/Actual')]);
            productos = cat.productos;       // ya vienen ordenados: más vendidos primero
            // Yesenia Quejada Rojas - Claude — 30/10/2026: "Adiciones" (precio 0) va antes de los más vendidos y no cuenta en el top.
            productos.sort((a, b) => (a.precio === 0 ? 0 : 1) - (b.precio === 0 ? 0 : 1));
            modificadores = cat.modificadores;
            ingredientes = cat.ingredientes || [];
            // Yesenia Quejada Rojas - Claude — 28/11/2026: los ingredientes ya no traen empaques (solo los "Sin ..."); los productos con caja llegan aparte.
            productosConCaja = new Set(cat.productosConCaja ?? ingredientes.filter(i => i.nombre === NOMBRE_CAJA).map(i => i.idProducto));
            top = new Map(productos.filter(p => p.vendidos > 0 && p.precio > 0).slice(0, 5).map((p, i) => [p.idProducto, i + 1]));
            cajaAbierta = !!caja;
            $('avisoCaja').hidden = cajaAbierta;
            pintarCategorias();
            pintarProductos();
            pintarPedido();
            const id = Number(new URLSearchParams(location.search).get('editar'));
            if (id) await cargarEdicion(id);
        } catch (e) { errorAlerta(e); }
    }

    function pintarCategorias() {
        const cats = [];
        productos.forEach(p => { if (!cats.some(c => c.id === p.idCategoriaMenu)) cats.push({ id: p.idCategoriaMenu, nombre: p.categoriaMenu, icono: p.icono }); });
        cats.sort((a, b) => productos.findIndex(p => p.idCategoriaMenu === a.id) - productos.findIndex(p => p.idCategoriaMenu === b.id));
        // Yesenia Quejada Rojas - Claude — 30/10/2026: "Adiciones" (categoría de un solo producto de precio 0) va de primera y anclada:
        // queda fija a la izquierda aunque se desplacen las demás categorías.
        const esAnclada = c => { const ps = productos.filter(p => p.idCategoriaMenu === c.id); return ps.length === 1 && ps[0].precio === 0; };
        const ancladas = cats.filter(esAnclada);
        $('categorias').innerHTML = [...ancladas, { id: 0, nombre: 'Más vendidos', icono: '🔥' }, ...cats.filter(c => !esAnclada(c))].map(c =>
            `<button class="btn btn-sm ${c.id === categoria ? 'btn-marca' : 'btn-outline-secondary bg-white'}${ancladas.includes(c) ? ' cat-anclada' : ''}" data-cat="${c.id}">${esc(c.icono)} ${esc(c.nombre)}</button>`).join('');
    }

    function filtrados() {
        const q = $('txtBuscar').value.trim().toLowerCase();
        return productos.filter(p => (!categoria || p.idCategoriaMenu === categoria) &&
            (!q || (p.nombre + ' ' + p.descripcion + ' ' + p.categoriaMenu).toLowerCase().includes(q)));
    }

    // Yesenia Quejada Rojas - Claude — 30/10/2026: la venta ya no depende del inventario (se vende aunque falte), así que no se
    // muestran "Quedan N" ni "Agotado"; lo que falte queda anotado en el movimiento para revisar el inventario.
    function pintarProductos() {
        const lista = filtrados();
        $('productos').innerHTML = lista.length ? lista.map(p => {
            const rank = top.get(p.idProducto);
            const o = opcionesDe(p.idProducto);
            const tieneOpciones = o.mods.length || o.sin.length;
            return `<div class="producto-card" data-id="${p.idProducto}" role="button" tabindex="0">
                ${p.imagenUrl ? `<img class="producto-foto" src="${esc(p.imagenUrl)}" alt="" loading="lazy" />`
                              : `<div class="producto-foto sin-foto">${esc(p.icono || '🍽️')}</div>`}
                ${rank ? `<span class="producto-top" title="${p.vendidos} vendidos en 30 días">🔥 Top ${rank}</span>` : ''}
                ${tieneOpciones ? `<button class="producto-rapido" data-rapido="${p.idProducto}" title="${TACTIL ? 'Elegir salsas y adiciones' : 'Agregar 1 tal como viene'}" aria-label="${TACTIL ? 'Elegir salsas y adiciones de ' + esc(p.nombre) : 'Agregar 1 ' + esc(p.nombre) + ' tal como viene'}"><i class="bi bi-plus-lg"></i></button>` : ''}
                <div class="producto-info">
                    <span class="producto-nombre">${esc(p.nombre)}</span>
                    ${p.descripcion ? `<small class="producto-desc">${esc(p.descripcion)}</small>` : ''}
                    <span class="d-flex justify-content-between align-items-center">
                        <span class="producto-precio">${p.precio === 0 && tieneOpciones ? 'Elija las adiciones' : moneda(p.precio)}</span>
                    </span>
                </div>
            </div>`;
        }).join('') : '<div class="pos-empty"><i class="bi bi-grid"></i><strong>No hay productos para mostrar</strong><span>Prueba otra búsqueda o agrega productos desde Configuración.</span></div>';
    }

    $('categorias').addEventListener('click', ev => {
        const b = ev.target.closest('[data-cat]');
        if (!b) return;
        categoria = Number(b.dataset.cat);
        pintarCategorias();
        pintarProductos();
        // Yesenia Quejada Rojas - Claude — 30/10/2026: la categoría "Adiciones" tiene un solo producto de precio 0 que agrupa
        // todas las adiciones; al tocarla se abre de una su cuadro para elegirlas.
        const deCategoria = productos.filter(p => p.idCategoriaMenu === categoria);
        if (deCategoria.length === 1 && deCategoria[0].precio === 0) abrirProducto(deCategoria[0]);
    });
    $('txtBuscar').addEventListener('input', pintarProductos);
    $('txtBuscar').addEventListener('keydown', ev => {
        if (ev.key === 'Enter') { const p = filtrados()[0]; if (p) abrirProducto(p); }
        if (ev.key === 'Escape') { $('txtBuscar').value = ''; pintarProductos(); }
    });

    /* ---------- Modal de salsas, adiciones e ingredientes ---------- */
    $('productos').addEventListener('click', ev => {
        const rapido = ev.target.closest('[data-rapido]');
        // Yesenia Quejada Rojas - Claude — 30/10/2026: en pantallas táctiles (tablet) el + abre salsas y adiciones, porque es lo
        // que tocan para pedir; en computador sigue agregando 1 "tal como viene".
        if (rapido) { const p = productos.find(x => x.idProducto === Number(rapido.dataset.rapido)); if (TACTIL || p.precio === 0) abrirProducto(p); else agregar(p, 1, '', [], []); return; }
        const card = ev.target.closest('[data-id]');
        if (card) abrirProducto(productos.find(p => p.idProducto === Number(card.dataset.id)), ev.shiftKey);
    });
    $('productos').addEventListener('keydown', ev => {
        if (ev.key === 'Enter' && ev.target.matches('[data-id]')) ev.target.click();
    });

    /* Yesenia Quejada Rojas - Claude — 19/10/2026. Todas las opciones son pastillas que se tocan (sin fotos para que ocupe menos):
       salsas con su color, adiciones con su precio y, aparte, los ingredientes de la receta para pedir "Sin ...". */
    function abrirProducto(p, forzar = false) {
        actual = p;
        const { mods, sin } = opcionesDe(p.idProducto);
        if (!mods.length && !sin.length && !forzar) { agregar(p, 1, '', [], []); return; } // sin opciones: directo al pedido
        cantidad = 1;
        $('tituloProducto').textContent = p.precio ? `${p.nombre} · ${moneda(p.precio)}` : p.nombre;
        $('txtNotas').value = '';
        $('lblCantidad').textContent = 1;
        const grupos = [...new Set(mods.map(m => m.grupo))]
            .sort((a, b) => (ORDEN_GRUPOS.indexOf(a) + 1 || 99) - (ORDEN_GRUPOS.indexOf(b) + 1 || 99) || a.localeCompare(b));
        $('modificadores').innerHTML = grupos.map(g => {
            const items = mods.filter(m => m.grupo === g);
            const esSalsa = g.toLowerCase().startsWith('salsa');
            // Yesenia Quejada Rojas - Claude — 01/11/2026: en "Salsas" el primer botón es "Sin salsas" (excluye a las demás) y cada salsa lleva el
            // color y el ícono de su sabor; adiciones y vasos llevan su ícono. Todo más grande para leerlo en la tablet.
            return `<div class="mb-3"${GRUPOS_UNICOS.includes(g) ? ' data-unico' : ''}${esSalsa ? ' data-salsas' : ''}><div class="grupo-titulo fw-semibold mb-2">${esc(g)}${esSalsa ? ' <small class="text-muted fw-normal">toque una o varias</small>' : ''}</div>
                <div class="d-flex flex-wrap gap-2">${esSalsa ? `
                    <input type="checkbox" class="btn-check" id="sinSalsas" autocomplete="off" />
                    <label class="opcion-pastilla es-sin-salsas" for="sinSalsas"><i class="bi bi-slash-circle icono-opcion" aria-hidden="true"></i>Sin salsas</label>` : ''}${items.map((m, i) => {
                    const s = esSalsa ? saborSalsa(m.nombre, i) : null;
                    return `
                    <input type="checkbox" class="btn-check" id="mod${m.idModificador}" value="${m.idModificador}" autocomplete="off" />
                    <label class="opcion-pastilla ${esSalsa ? 'es-salsa' : ''}" for="mod${m.idModificador}" ${s ? `style="--color-opcion:${s.color};--texto-elegida:${s.claro ? '#1b1b1b' : '#fff'}"` : ''}>
                        <i class="bi bi-check-lg marca-elegida" aria-hidden="true"></i>${s ? (s.icono ? `<span class="icono-opcion" aria-hidden="true">${s.icono}</span>` : '<i class="bi bi-droplet-fill icono-opcion icono-gota" aria-hidden="true"></i>') : iconoOpcion(m.nombre)}${esc(m.nombre)}${m.precio ? ` <small class="precio-opcion">+${moneda(m.precio)}</small>` : ''}
                    </label>`; }).join('')}</div>
            </div>`;
        }).join('');
        // Yesenia Quejada Rojas - Claude — 13/11/2026: ya no se ofrece "Empaque y cubiertos" (sin caja, sin bolsa, sin servilleta...): solo ingredientes.
        const empaque = sin.filter(i => EMPAQUE.test(sinTildes(sinParentesis(i.nombre))));
        // Yesenia Quejada Rojas - Claude — 01/11/2026: primero lo que el cliente suele quitar (pepino, cebolla, tomate...) y al final, aparte, el empaque y los
        // cubiertos (caja, bolsa, servilleta...), que también se pueden quitar para no descontarlos del inventario.
        // Yesenia Quejada Rojas - Claude — 24/11/2026: todos los "Sin ..." llevan ícono (iconos-insumo.js; 🍽️ si no se reconoce) y van agrupados
        // (Pan y base, Carnes, Quesos, Verduras y frutas, Toppings...). La porción de salsas no se repite aquí cuando ya está el botón "Sin salsas".
        const conBotonSinSalsas = mods.some(m => m.grupo.toLowerCase().startsWith('salsa'));
        const quitables = sin.filter(i => !empaque.includes(i) && !(conBotonSinSalsas && IconosInsumo.de(i.nombre).grupo === 'Salsas'));
        const pastillaSin = i => `
            <input type="checkbox" class="btn-check" id="sin${i.idInsumo}" value="${i.idInsumo}" autocomplete="off" />
            <label class="opcion-pastilla es-quitar" for="sin${i.idInsumo}"><i class="bi bi-x-lg marca-elegida" aria-hidden="true"></i><span class="icono-opcion" aria-hidden="true">${IconosInsumo.de(i.nombre).icono}</span>Sin ${esc(nombreCorto(i.nombre))}</label>`;
        const gruposSin = IconosInsumo.agrupar(quitables);
        $('quitar').innerHTML = gruposSin.map(g => `
            <div class="grupo-quitar">${gruposSin.length > 1 ? `<div class="subgrupo-titulo">${g.icono} ${esc(g.grupo)}</div>` : ''}
                <div class="d-flex flex-wrap gap-2">${g.items.map(pastillaSin).join('')}</div>
            </div>`).join('');
        $('seccionQuitar').hidden = !quitables.length;
        actualizarOpciones();
        modalProducto.show();
    }
    function elegidas() {
        const ids = [...$('modificadores').querySelectorAll('input:checked:not(#sinSalsas)')].map(i => Number(i.value));
        const sinIds = [...$('quitar').querySelectorAll('input:checked')].map(i => Number(i.value));
        return {
            mods: modificadores.filter(m => m.idProducto === actual.idProducto && ids.includes(m.idModificador)),
            sin: ingredientes.filter(i => i.idProducto === actual.idProducto && sinIds.includes(i.idInsumo)),
            sinSalsas: !!$('sinSalsas')?.checked
        };
    }
    function actualizarOpciones() {
        const e = elegidas();
        const partes = [];
        if (e.mods.length) partes.push(`<strong>Con:</strong> ${e.mods.map(m => esc(m.nombre)).join(', ')}`);
        // Yesenia Quejada Rojas - Claude — 01/11/2026: "Sin salsas" entra en la lista de "Sin:" y le quita lugar a las notas (van juntas en 150 caracteres).
        const sinTxt = [...(e.sinSalsas ? ['salsas'] : []), ...e.sin.map(i => nombreCorto(i.nombre))];
        if (sinTxt.length) partes.push(`<strong class="text-danger">Sin:</strong> ${sinTxt.map(t => esc(t)).join(', ')}`);
        $('txtNotas').maxLength = 150 - (e.sinSalsas ? SIN_SALSAS.length + 3 : 0);
        $('resumenOpciones').innerHTML = partes.join(' · ');
        $('resumenOpciones').hidden = !partes.length;
        const importe = (actual.precio + e.mods.reduce((s, m) => s + m.precio, 0)) * cantidad;
        $('btnAgregarPedido').textContent = `${lineaEditando !== null ? 'Guardar' : 'Agregar'} ${cantidad} · ${moneda(importe)}`;
        $('btnMenos').disabled = cantidad <= 1;
    }
    // Yesenia Quejada Rojas - Claude — 30/10/2026: en "Vasos" se elige una sola opción (con vaso, con 2 vasos...); cada una
    // descuenta sus vasos del inventario sin cobrarlos.
    $('modificadores').addEventListener('change', ev => {
        const grupo = ev.target.closest('[data-unico]');
        if (grupo && ev.target.checked) grupo.querySelectorAll('input').forEach(i => { if (i !== ev.target) i.checked = false; });
        // Yesenia Quejada Rojas - Claude — 01/11/2026: "Sin salsas" y las salsas se excluyen entre sí.
        const salsas = ev.target.closest('[data-salsas]');
        if (salsas && ev.target.checked) {
            if (ev.target.id === 'sinSalsas') salsas.querySelectorAll('input:not(#sinSalsas)').forEach(i => { i.checked = false; });
            else if ($('sinSalsas')) $('sinSalsas').checked = false;
        }
        actualizarOpciones();
    });
    $('quitar').addEventListener('change', actualizarOpciones);
    $('modalProducto').addEventListener('shown.bs.modal', () => $('btnAgregarPedido').focus());
    $('btnMenos').addEventListener('click', () => { cantidad = Math.max(1, cantidad - 1); $('lblCantidad').textContent = cantidad; actualizarOpciones(); });
    $('btnMas').addEventListener('click', () => { cantidad++; $('lblCantidad').textContent = cantidad; actualizarOpciones(); });
    $('btnAgregarPedido').addEventListener('click', () => {
        const e = elegidas();
        // Yesenia Quejada Rojas - Claude — 30/10/2026: "Adiciones sueltas" vale 0; sin elegir ninguna no hay nada que vender.
        if (actual.precio === 0 && !e.mods.length) { alerta('Elija al menos una adición', 'warning'); return; }
        if (lineaEditando === null) agregar(actual, cantidad, $('txtNotas').value.trim(), e.mods, e.sin, e.sinSalsas);
        else {
            // Se reemplaza la línea en el mismo lugar (si queda igual a otra, se suman).
            const i = lineaEditando, total = pedido.length;
            pedido.splice(i, 1);
            agregar(actual, cantidad, $('txtNotas').value.trim(), e.mods, e.sin, e.sinSalsas);
            if (pedido.length === total) { pedido.splice(i, 0, pedido.pop()); pintarPedido(); }
        }
        modalProducto.hide();
    });

    /* Yesenia Quejada Rojas - Claude — 30/10/2026. Tocar el nombre de un producto del pedido abre su cuadro con lo que ya tenía
       (salsas, adiciones, "Sin ...", notas y cantidad) para cambiarlo sin borrarlo y volverlo a poner. */
    let lineaEditando = null;
    function editarLinea(i) {
        const l = pedido[i];
        if (!l) return;
        const p = productos.find(x => x.idProducto === l.idProducto) || { idProducto: l.idProducto, nombre: l.nombre, precio: l.precio };
        lineaEditando = i;
        abrirProducto(p, true);
        l.mods.forEach(m => { const x = $(`mod${m.idModificador}`); if (x) x.checked = true; });
        (l.sin || []).forEach(s => { const x = $(`sin${s.idInsumo}`); if (x) x.checked = true; });
        if (l.sinSalsas && $('sinSalsas')) $('sinSalsas').checked = true;
        $('txtNotas').value = l.notas || '';
        cantidad = l.cantidad;
        $('lblCantidad').textContent = cantidad;
        actualizarOpciones();
    }
    $('modalProducto').addEventListener('hidden.bs.modal', () => { lineaEditando = null; });

    // Yesenia Quejada Rojas - Claude — 01/11/2026: la clave separa las líneas con y sin "Sin salsas" (el dato solo se agrega cuando es verdadero,
    // así las claves guardadas antes no cambian).
    const claveLinea = (idProducto, notas, mods, sin, sinSalsas) =>
        JSON.stringify([idProducto, notas, mods.map(m => m.idModificador).sort(), sin.map(i => i.idInsumo).sort(), ...(sinSalsas ? [1] : [])]);
    function agregar(p, cant, notas, mods, sin, sinSalsas = false) {
        const clave = claveLinea(p.idProducto, notas, mods, sin, sinSalsas);
        const existente = pedido.find(l => l.clave === clave);
        if (existente) existente.cantidad += cant;
        else pedido.push({ clave, idProducto: p.idProducto, nombre: p.nombre, precio: p.precio, cantidad: cant, notas, mods, sin, sinSalsas });
        pintarPedido();
        pintarProductos();
    }

    /* ---------- Pedido ---------- */
    function pintarPedido() {
        const unidades = pedido.reduce((s, l) => s + l.cantidad, 0);
        // Yesenia Quejada Rojas - Claude — 30/10/2026: con productos, el conteo va en el encabezado y la línea se oculta para dar espacio.
        $('resumenPedido').textContent = unidades ? '' : 'Agrega un producto para comenzar';
        $('resumenPedido').hidden = !!unidades;
        $('lblUnidades').textContent = unidades;
        $('lblUnidades').hidden = !unidades;
        $('btnVaciar').disabled = !pedido.length || procesando;
        $('lineas').innerHTML = pedido.length ? pedido.map((l, i) => `
            <div class="linea d-flex gap-2 py-2 border-bottom">
                <div class="flex-grow-1">
                    <button type="button" class="btn btn-link p-0 fw-semibold text-start text-reset text-decoration-none" data-editar-linea="${i}" title="Cambiar salsas, adiciones o notas">${esc(l.nombre)} <i class="bi bi-pencil small text-muted" aria-hidden="true"></i></button>
                    ${l.mods.length ? `<small class="d-block">${l.mods.map(m => (m.precio ? '+ ' : '') + esc(m.nombre)).join(' · ')}</small>` : ''}
                    ${textoSin(l)}
                    ${l.notas ? `<small class="d-block fst-italic">“${esc(l.notas)}”</small>` : ''}
                    <div class="btn-group btn-group-sm mt-1">
                        <button class="btn btn-outline-secondary" data-menos="${i}" aria-label="Uno menos"><i class="bi bi-dash"></i></button>
                        <span class="btn btn-light disabled">${l.cantidad}</span>
                        <button class="btn btn-outline-secondary" data-mas="${i}" aria-label="Uno más"><i class="bi bi-plus"></i></button>
                    </div>
                </div>
                <div class="text-end">
                    <div class="fw-semibold text-nowrap">${moneda(precioLinea(l))}</div>
                    <button class="btn btn-sm btn-link text-danger p-0" data-quitar="${i}" title="Quitar" aria-label="Quitar ${esc(l.nombre)}"><i class="bi bi-trash"></i></button>
                </div>
            </div>`).join('')
            : '<p class="text-muted text-center my-4"><i class="bi bi-hand-index"></i> Toque un producto para agregarlo</p>';
        totales();
        sincronizarMesa();
        guardarPantalla();
    }

    $('lineas').addEventListener('click', ev => {
        const b = ev.target.closest('button');
        if (!b) return;
        if (b.dataset.editarLinea !== undefined) { editarLinea(Number(b.dataset.editarLinea)); return; }
        if (b.dataset.mas) pedido[b.dataset.mas].cantidad++;
        if (b.dataset.menos) { const l = pedido[b.dataset.menos]; if (--l.cantidad <= 0) pedido.splice(b.dataset.menos, 1); }
        if (b.dataset.quitar) pedido.splice(b.dataset.quitar, 1);
        pintarPedido();
        pintarProductos();
    });
    $('btnVaciar').addEventListener('click', () => { if (!pedido.length || confirm('¿Vaciar el pedido?')) limpiar(); });

    // Yesenia Quejada Rojas - Claude — 13/11/2026: parte pagada por transferencia (solo con "Efectivo"; 0 si está vacía).
    const transferencia = () => pago === 'EFECTIVO' ? Math.max(0, Number($('txtTransferencia').value || 0)) : 0;
    function totales() {
        const t = total();
        $('lblSubtotal').textContent = moneda(subtotal());
        $('lblEnvio').textContent = moneda(envio());
        $('filaEnvio').hidden = tipo !== 'DOMICILIO';
        $('filaSubtotal').hidden = tipo !== 'DOMICILIO';   // sin domicilio el subtotal es igual al total
        $('lblTotal').textContent = moneda(t);
        // Yesenia Quejada Rojas - Claude — 31/10/2026: cajas de empaque del pedido.
        const nCajas = cajas();
        $('lblCajas').textContent = nCajas;
        $('btnCajasMenos').disabled = nCajas <= 0;
        $('btnCajasMas').disabled = nCajas >= 99;
        $('lblCajasNota').textContent = cajasManual === null && nCajas ? '· según los productos' : cajasManual !== null ? '· ajustado' : '';
        $('btnCajasAuto').hidden = cajasManual === null;
        // Yesenia Quejada Rojas - Claude — 13/11/2026: pago mixto; el efectivo solo cubre lo que no se pagó por transferencia.
        const transf = transferencia(), te = t - transf;
        const recibido = Number($('txtRecibido').value || 0);
        const transfMal = transf > 0 && transf >= t;
        $('lblPorEfectivo').textContent = transf > 0 && !transfMal ? `En efectivo: ${moneda(te)}` : '';
        $('lblCambio').textContent = moneda(Math.max(0, recibido - te));
        $('lblCambio').classList.toggle('text-danger', recibido > 0 && recibido < te);
        // Atajos de billetes según lo que se paga en efectivo
        const billetes = [...new Set([te, ...[10000, 20000, 50000, 100000].map(b => Math.ceil(te / b) * b)])].filter(v => v > 0).slice(0, 4);
        $('billetes').innerHTML = billetes.map(v => `<button type="button" class="btn btn-sm btn-light border" data-billete="${v}">${moneda(v)}</button>`).join('');
        const vencida = edicion && Date.now() >= edicion.vence;
        const insuficiente = pago === 'EFECTIVO' && (transfMal || ($('txtRecibido').value !== '' && recibido < te));
        $('btnCobrar').disabled = !pedido.length || !cajaAbierta || vencida || insuficiente || procesando;
        $('lblCobrar').textContent = procesando ? 'Procesando…' : edicion ? 'Guardar cambios' : `Cobrar${pedido.length ? ' · ' + moneda(t) : ''}`;
        $('ayudaCobro').textContent = procesando ? 'Espera mientras registramos el pedido.'
            : !cajaAbierta ? 'Abre la caja para registrar la venta.'
            : vencida ? 'Terminó el tiempo para editar este pedido.'
            : !pedido.length ? ''
            : insuficiente && transfMal ? 'La parte en transferencia debe ser menor que el total (si pagó todo así, elija "Transf.").'
            : insuficiente ? `Faltan ${moneda(te - recibido)} para completar el pago.`
            : '';  // Yesenia Quejada Rojas - Claude — 19/10/2026: solo se muestra cuando algo impide cobrar, para que el pie ocupe menos.
        $('btnPonerEspera').disabled = !pedido.length || !!edicion;
    }
    $('billetes').addEventListener('click', ev => {
        const b = ev.target.closest('[data-billete]');
        if (b) { $('txtRecibido').value = b.dataset.billete; totales(); }
    });
    $('txtRecibido').addEventListener('input', totales);
    $('txtTransferencia').addEventListener('input', totales);
    $('txtCostoDomicilio').addEventListener('input', totales);
    // Yesenia Quejada Rojas - Claude — 31/10/2026: − / + de las cajas y "restablecer" (vuelve a contarlas según los productos).
    $('btnCajasMenos').addEventListener('click', () => { fijarCajas(cajas() - 1); totales(); guardarPantalla(); });
    $('btnCajasMas').addEventListener('click', () => { fijarCajas(cajas() + 1); totales(); guardarPantalla(); });
    $('btnCajasAuto').addEventListener('click', () => { cajasManual = null; totales(); guardarPantalla(); });

    function segmentado(grupo, alCambiar) {
        grupo.addEventListener('click', ev => {
            const b = ev.target.closest('[data-valor]');
            if (b) seleccionar(grupo, b.dataset.valor, alCambiar);
        });
    }
    function seleccionar(grupo, valor, alCambiar) {
        grupo.querySelectorAll('.btn').forEach(x => {
            x.classList.toggle('active', x.dataset.valor === valor);
            x.setAttribute('aria-pressed', String(x.dataset.valor === valor));
        });
        alCambiar(valor);
    }
    const alCambiarTipo = v => {
        tipo = v;
        $('datosCliente').hidden = v !== 'DOMICILIO';
        // Yesenia Quejada Rojas - Claude — 31/10/2026: los botones de las mesas solo salen en "Mesa"; en Llevar y Domicilio se suelta la mesa elegida.
        if (v !== 'MESA') $('txtNombreMesa').value = '';
        mostrarMesas();
        sincronizarMesa();
        if (v === 'DOMICILIO' && $('txtCostoDomicilio').value === '' && APP.costoDomicilio) $('txtCostoDomicilio').value = APP.costoDomicilio;
        totales();
    };
    const alCambiarPago = v => { pago = v; $('datosEfectivo').hidden = v !== 'EFECTIVO'; totales(); };
    segmentado($('tipoPedido'), alCambiarTipo);
    segmentado($('metodoPago'), alCambiarPago);

    /* ---------- Cliente frecuente (domicilios) ---------- */
    let esperaTel;
    $('txtTelefono').addEventListener('input', () => {
        clearTimeout(esperaTel);
        $('lblClienteFrecuente').hidden = true;
        const tel = $('txtTelefono').value.replace(/\D/g, '');
        if (tel.length < 7) return;
        esperaTel = setTimeout(async () => {
            try {
                const c = await api.get(`/Venta/Cliente?telefono=${encodeURIComponent(tel)}`);
                if (!c) return;
                if (!$('txtCliente').value.trim()) $('txtCliente').value = c.clienteNombre;
                if (!$('txtDireccion').value.trim()) $('txtDireccion').value = c.direccion;
                $('lblClienteFrecuente').innerHTML = `<i class="bi bi-star-fill"></i> Cliente frecuente: ${c.pedidos} pedido${c.pedidos === 1 ? '' : 's'}, el último el ${esc(c.ultimoPedido)}`;
                $('lblClienteFrecuente').hidden = false;
            } catch (e) { /* sin sugerencia */ }
        }, 400);
    });

    /* ---------- Cobrar o guardar cambios ---------- */
    async function cobrar() {
        if ($('btnCobrar').disabled) return;
        const t = total();
        const transf = transferencia(), te = t - transf;
        if (transf > 0 && transf >= t) { alerta('La parte en transferencia debe ser menor que el total', 'warning'); return; }
        const recibido = pago === 'EFECTIVO' ? Number($('txtRecibido').value || te) : t;
        if (pago === 'EFECTIVO' && recibido < te) { alerta('El valor recibido es menor al total', 'warning'); return; }
        const venta = {
            idVenta: edicion?.idVenta ?? 0,
            tipoPedido: tipo,
            clienteNombre: tipo === 'DOMICILIO' ? $('txtCliente').value.trim() : $('txtNombreMesa').value.trim(),
            clienteTelefono: tipo === 'DOMICILIO' ? $('txtTelefono').value.trim() : '',
            direccion: tipo === 'DOMICILIO' ? $('txtDireccion').value.trim() : '',
            costoDomicilio: envio(),
            metodoPago: pago,
            montoRecibido: recibido,
            montoTransferencia: transf,
            cajas: cajas(),   // Yesenia Quejada Rojas - Claude — 31/10/2026: cajas de empaque del pedido.
            lineas: pedido.map(l => ({ idProducto: l.idProducto, cantidad: l.cantidad, notas: notasDe(l),
                modificadores: l.mods.map(m => m.idModificador), quitados: (l.sin || []).map(s => s.idInsumo) }))
        };
        procesando = true;
        $('btnCobrar').setAttribute('aria-busy', 'true');
        totales();
        try {
            const r = await api.post('/Venta/Registrar', venta);
            if (!r.resultado) { alerta(r.mensaje, 'warning'); totales(); return; }
            $('lblListoTitulo').textContent = edicion ? 'Pedido actualizado' : 'Venta registrada';
            $('lblListoTotal').textContent = `Pedido N° ${r.id} · ${moneda(t)}`;
            $('lblListoCambio').textContent = pago === 'EFECTIVO' ? `Cambio: ${moneda(recibido - t)}` : etiquetaPago[pago];
            $('lnkTicket').href = `/Venta/Ticket/${r.id}`;
            $('lnkPdf').href = `/Venta/Ticket/${r.id}?pdf=1`;
            $('lnkComanda').href = `/Venta/Ticket/${r.id}?comanda=true`;
            $('lnkTicket').innerHTML = '<i class="bi bi-printer"></i> Imprimir ticket';
            $('lnkPdf').hidden = false;
            borradorListo = null;
            // Yesenia Quejada Rojas - Claude — 30/10/2026: el pedido retomado de "Por cobrar" sale de la lista solo cuando se cobra.
            if (esperaActual) api.post(`/Venta/QuitarEspera?id=${esperaActual}`).then(cargarEspera).catch(() => { /* queda en la lista */ });
            if (edicion) { history.replaceState(null, '', '/Venta'); salirEdicion(); }
            if (origenCarta) await cerrarPedidoCarta(origenCarta, r.id);
            limpiar();
            cargar();   // refresca más vendidos y disponibilidad
            cargarComandas();
            modalListo.show();
        } catch (e) { errorAlerta(e); }
        finally {
            procesando = false;
            $('btnCobrar').removeAttribute('aria-busy');
            pintarPedido();
        }
    }
    $('btnCobrar').addEventListener('click', cobrar);

    /* ---------- Impresión en la misma pantalla ----------
       Yesenia Quejada Rojas - Claude — 30/10/2026. El ticket se carga en un marco oculto y se imprime desde ahí, sin abrir otra
       pestaña. "vista=1" evita que el ticket se imprima solo y salga dos veces. Los pedidos sin cobrar se mandan con
       "datos" (POST) a /Venta/Borrador, que arma la cuenta con el pago "POR COBRAR" o la comanda sin guardar nada. */
    let borradorListo = null;   // pedido apartado que se muestra en el cuadro de "listo"
    function imprimirEnSitio(url, datos) {
        $('marcoImpresion')?.remove();
        const marco = document.createElement('iframe');
        marco.id = marco.name = 'marcoImpresion';
        marco.title = 'Impresión del ticket';
        marco.style.cssText = 'position:fixed;right:0;bottom:0;width:0;height:0;border:0';
        marco.addEventListener('load', () => {
            const doc = marco.contentDocument;
            if (!doc || marco.contentWindow.location.href === 'about:blank') return;
            if (!doc.getElementById('btnImprimir')) { alerta('No se pudo preparar la impresión. Intente de nuevo.', 'warning'); return; }
            setTimeout(() => { marco.contentWindow.focus(); marco.contentWindow.print(); }, 150);
        });
        document.body.appendChild(marco);
        const destino = url + (url.includes('?') ? '&' : '?') + 'vista=1';
        if (!datos) { marco.src = destino; return; }
        const form = document.createElement('form');
        form.method = 'post'; form.action = destino; form.target = marco.name; form.hidden = true;
        for (const [k, v] of [['datos', JSON.stringify(datos)], ['__RequestVerificationToken', token()]]) {
            const i = document.createElement('input'); i.type = 'hidden'; i.name = k; i.value = v; form.appendChild(i);
        }
        document.body.appendChild(form);
        form.submit();
        form.remove();
    }
    // Pedido sin cobrar en el formato del ticket (TicketLinea / Venta).
    const borrador = (lineas, d) => ({
        venta: { tipoPedido: d.tipo, clienteNombre: d.nombre || '', clienteTelefono: d.tipo === 'DOMICILIO' ? d.telefono || '' : '',
            direccion: d.tipo === 'DOMICILIO' ? d.direccion || '' : '', costoDomicilio: Number(d.envio || 0),
            fecha: new Date().toLocaleString('es-CO', { dateStyle: 'short', timeStyle: 'short' }),
            cajas: cajasDe(lineas, d.cajas) },   // Yesenia Quejada Rojas - Claude — 31/10/2026: la comanda dice si va con caja.
        lineas: lineas.map(l => ({ nombre: l.nombre, cantidad: l.cantidad, subtotal: precioLinea(l), notas: notasDe(l),
            adiciones: l.mods.map(m => m.nombre), sinIngredientes: (l.sin || []).map(s => nombreCorto(s.nombre)) }))
    });
    const datosPantalla = () => ({ tipo, nombre: nombrePedido(), telefono: $('txtTelefono').value.trim(),
        direccion: $('txtDireccion').value.trim(), envio: envio(), cajas: cajasManual });
    const imprimirBorrador = (datos, comanda) => imprimirEnSitio(`/Venta/Borrador${comanda ? '?comanda=true' : ''}`, datos);
    ['lnkTicket', 'lnkComanda'].forEach(id => $(id).addEventListener('click', ev => {
        ev.preventDefault();
        if (borradorListo) imprimirBorrador(borradorListo, id === 'lnkComanda');
        else imprimirEnSitio($(id).getAttribute('href'));
    }));
    ['btnComandaPedido', 'btnCuentaPedido'].forEach(id => $(id).addEventListener('click', async () => {
        if (!pedido.length) { alerta('Agregue productos al pedido', 'warning'); return; }
        imprimirBorrador(borrador(pedido, datosPantalla()), id === 'btnComandaPedido');
    }));

    /* ---------- Nombre del pedido ----------
       Yesenia Quejada Rojas - Claude — 31/10/2026. Se quitó el nombre del pedido y el "Pedido N" automático. Lo único que identifica
       al pedido es la mesa que eligen con los botones (queda como "Mesa X" en el campo oculto txtNombreMesa) o, en domicilio, el
       nombre del cliente. */
    const nombrePedido = () => $(tipo === 'DOMICILIO' ? 'txtCliente' : 'txtNombreMesa').value.trim();

    /* ---------- Pedido en pantalla ----------
       Yesenia Quejada Rojas - Claude — 30/10/2026. Lo que está en pantalla se guarda en este equipo a cada cambio y vuelve al
       recargar la página (no al editar un pedido ya cobrado). */
    const CLAVE_PANTALLA = 'pos-pantalla';
    const CAMPOS_PANTALLA = ['txtNombreMesa', 'txtCliente', 'txtTelefono', 'txtDireccion', 'txtCostoDomicilio'];
    let restaurando = false;
    function guardarPantalla() {
        if (restaurando || edicion) return;
        try {
            if (!pedido.length) { localStorage.removeItem(CLAVE_PANTALLA); return; }
            localStorage.setItem(CLAVE_PANTALLA, JSON.stringify({ pedido, tipo, esperaActual, carta: origenCarta, cajas: cajasManual,
                campos: Object.fromEntries(CAMPOS_PANTALLA.map(id => [id, $(id).value])) }));
        } catch { /* sin almacenamiento */ }
    }
    function restaurarPantalla() {
        if (new URLSearchParams(location.search).get('editar')) return;
        let d = null;
        try { d = JSON.parse(localStorage.getItem(CLAVE_PANTALLA) || 'null'); } catch { /* sin almacenamiento */ }
        if (!d || !Array.isArray(d.pedido) || !d.pedido.length) return;
        restaurando = true;
        pedido = d.pedido;
        cajasManual = Number.isInteger(d.cajas) ? d.cajas : null;   // Yesenia Quejada Rojas - Claude — 31/10/2026: vuelve el ajuste de cajas al recargar.
        CAMPOS_PANTALLA.forEach(id => $(id).value = d.campos?.[id] ?? '');
        // Yesenia Quejada Rojas - Claude — 31/10/2026: lo guardado con la versión anterior puede traer el "Pedido N" automático; ya no existe y se descarta.
        if (d.nombreAuto) ['txtNombreMesa', 'txtCliente'].forEach(id => { if ($(id).value === d.nombreAuto) $(id).value = ''; });
        esperaActual = d.esperaActual || null;
        seleccionar($('tipoPedido'), d.tipo || 'MESA', alCambiarTipo);
        marcarCarta(d.carta || null);
        restaurando = false;
        pintarPedido();
    }
    CAMPOS_PANTALLA.forEach(id => $(id).addEventListener('input', guardarPantalla));

    function limpiar() {
        pedido = [];
        cajasManual = null;
        esperaActual = null;
        ['txtCliente', 'txtTelefono', 'txtDireccion', 'txtCostoDomicilio', 'txtRecibido', 'txtTransferencia', 'txtNombreMesa', 'txtBuscar'].forEach(id => $(id).value = '');
        $('lblClienteFrecuente').hidden = true;
        marcarCarta(null);
        seleccionar($('tipoPedido'), 'MESA', alCambiarTipo);
        seleccionar($('metodoPago'), 'EFECTIVO', alCambiarPago);
        pintarProductos();
        pintarPedido();
    }

    /* ---------- Pedidos por cobrar ----------
       Yesenia Quejada Rojas - Claude — 19/10/2026. Guardar sin cobrar NO registra la venta, no la manda a cocina
       ni descuenta inventario: solo la aparta para cobrarla después desde "Por cobrar".
       Yesenia Quejada Rojas - Claude — 30/10/2026. Se guardan en el servidor (antes en el navegador), así lo que se aparta en la
       tablet aparece en el computador y al revés. La lista se refresca cada 15 s y al abrir "Por cobrar".
       Al retomarlo sigue en la lista (marcado "En pantalla") hasta cobrarlo o descartarlo; "Cobrar después" lo actualiza. */
    let espera = [];
    let esperaActual = null;    // id del pedido de "Por cobrar" que está en pantalla
    const aEntrada = x => {
        let d = {};
        try { d = JSON.parse(x.datos); } catch { /* datos dañados: se muestra vacío */ }
        // Yesenia Quejada Rojas - Claude — 31/10/2026: sin nombre el servidor guarda "Pedido"; aquí vuelve a quedar vacío y la tarjeta muestra el tipo.
        return { id: x.idPedidoEspera, nombre: x.nombre === 'Pedido' ? '' : x.nombre, tipo: x.tipoPedido, minutos: x.minutos, usuario: x.usuario,
            pedido: d.pedido || [], cliente: d.cliente || '', telefono: d.telefono || '', direccion: d.direccion || '',
            envio: d.envio || '', carta: d.carta || null,
            cajas: Number.isInteger(d.cajas) ? d.cajas : null };   // Yesenia Quejada Rojas - Claude — 31/10/2026: cajas ajustadas a mano (null = según los productos).
    };
    const apartar = e => api.post('/Venta/Apartar', { idPedidoEspera: e.idPedidoEspera || 0, nombre: e.nombre, tipoPedido: e.tipo,
        datos: JSON.stringify({ pedido: e.pedido, cliente: e.cliente, telefono: e.telefono, direccion: e.direccion, envio: e.envio, carta: e.carta, cajas: e.cajas }) });
    async function cargarEspera() {
        try { espera = (await api.get('/Venta/Espera')).map(aEntrada); pintarEspera(); }
        catch { /* sin conexión: se reintenta en el próximo ciclo */ }
    }
    // Lo que quedó apartado en el navegador con la versión anterior se sube una sola vez al servidor.
    async function subirEsperaLocal() {
        let viejos = [];
        try { viejos = JSON.parse(localStorage.getItem(CLAVE_ESPERA) || '[]'); } catch { /* sin almacenamiento */ }
        if (!viejos.length) return;
        for (const e of viejos) { try { await apartar(e); } catch { return; } }   // si falla se intenta en la próxima carga
        try { localStorage.removeItem(CLAVE_ESPERA); } catch { /* sin almacenamiento */ }
    }
    const haceCuanto = m => m < 1 ? 'recién' : m < 60 ? `hace ${m} min` : `hace ${Math.floor(m / 60)} h ${m % 60} min`;
    function pintarEspera() {
        $('lblEspera').textContent = espera.length;
        $('lblEspera').className = `badge rounded-pill ${espera.length ? 'text-bg-warning' : 'text-bg-secondary'}`;
        $('btnEspera').classList.toggle('borde-marca', espera.length > 0);
        // Yesenia Quejada Rojas - Claude — 30/10/2026: una tarjeta por pedido con sus productos (salsas, adiciones, "Sin ...", notas),
        // el total y los botones grandes, para reconocerlo de un vistazo.
        const totalDe = e => e.pedido.reduce((s, l) => s + precioLinea(l), 0) + (e.tipo === 'DOMICILIO' ? Number(e.envio || 0) : 0);
        $('listaEspera').innerHTML = espera.length ? espera.map(e => `
            <div class="espera-card ${e.id === esperaActual ? 'en-pantalla' : ''}">
                <div class="d-flex justify-content-between align-items-start gap-2">
                    <div><strong class="fs-6">${esc(e.nombre || etiquetaPedido[e.tipo])}</strong>${e.id === esperaActual ? ' <span class="badge text-bg-info">En pantalla</span>' : ''}
                        <div class="small text-muted">${esc(etiquetaPedido[e.tipo])} · ${haceCuanto(e.minutos)} · ${esc(e.usuario)}</div></div>
                    <strong class="text-marca text-nowrap fs-5">${moneda(totalDe(e))}</strong>
                </div>
                ${e.tipo === 'DOMICILIO' && (e.direccion || e.telefono) ? `<div class="small mt-1"><i class="bi bi-geo-alt"></i> ${esc(e.direccion)} ${e.telefono ? '· ' + esc(e.telefono) : ''}</div>` : ''}
                <ul class="espera-lineas">${e.pedido.map(l => `<li><span class="fw-semibold">${l.cantidad} × ${esc(l.nombre)}</span>
                    ${l.mods.length ? `<small class="d-block">${l.mods.map(m => esc(m.nombre)).join(' · ')}</small>` : ''}
                    ${textoSin(l)}
                    ${l.notas ? `<small class="d-block fst-italic">“${esc(l.notas)}”</small>` : ''}</li>`).join('')}</ul>
                ${cajasDe(e.pedido, e.cajas) ? `<div class="small mb-2"><i class="bi bi-box-seam"></i> Va con ${textoCajas(cajasDe(e.pedido, e.cajas))}</div>` : ''}
                <div class="d-flex flex-wrap gap-2 mt-auto">
                    <button class="btn btn-marca flex-grow-1" data-retomar="${e.id}"><i class="bi bi-box-arrow-in-down"></i> Abrir para cobrar</button>
                    <button class="btn btn-outline-marca" data-imprimir="${e.id}" data-tipo="comanda" title="Imprimir comanda"><i class="bi bi-fire"></i> Comanda</button>
                    <button class="btn btn-outline-secondary" data-imprimir="${e.id}" data-tipo="cuenta" title="Imprimir cuenta por cobrar"><i class="bi bi-receipt"></i> Cuenta</button>
                    <button class="btn btn-outline-danger" data-descartar="${e.id}" title="Descartar" aria-label="Descartar"><i class="bi bi-trash"></i></button>
                </div>
            </div>`).join('') : '<p class="text-muted text-center my-4">No hay pedidos por cobrar.<br>Use "Cobrar después" para apartar uno.</p>';
        pintarMesas();
    }
    $('btnPonerEspera').addEventListener('click', async () => {
        if (!pedido.length || $('btnPonerEspera').disabled) return;
        $('btnPonerEspera').disabled = true;
        try {
            const nombre = nombrePedido();   // Yesenia Quejada Rojas - Claude — 31/10/2026: "Mesa X" o el cliente del domicilio; puede ir vacío (el servidor guarda "Pedido").
            const etiqueta = nombre || etiquetaPedido[tipo];
            const datos = borrador(pedido, datosPantalla());
            const r = await apartar({ idPedidoEspera: esperaActual, nombre, tipo, pedido, cliente: $('txtCliente').value, telefono: $('txtTelefono').value,
                direccion: $('txtDireccion').value, envio: $('txtCostoDomicilio').value, carta: origenCarta, cajas: cajasManual });
            if (!r.resultado) { alerta(r.mensaje, 'warning'); return; }
            limpiar();
            cargarEspera();
            // Yesenia Quejada Rojas - Claude — 30/10/2026: al apartarlo se ofrece de una la cuenta "POR COBRAR" (para el domiciliario)
            // y la comanda, en el mismo cuadro que sale al cobrar.
            borradorListo = datos;
            $('lblListoTitulo').textContent = 'Pedido por cobrar';
            $('lblListoTotal').textContent = `${etiqueta} · ${moneda(datos.lineas.reduce((s, l) => s + l.subtotal, 0) + datos.venta.costoDomicilio)}`;
            $('lblListoCambio').textContent = 'Aún no está cobrado. Lo encuentra en "Por cobrar" en cualquier equipo.';
            $('lnkTicket').innerHTML = '<i class="bi bi-printer"></i> Imprimir cuenta (pago por cobrar)';
            $('lnkPdf').hidden = true;
            modalListo.show();
        } catch (e) { errorAlerta(e); }
        finally { totales(); }
    });
    $('modalEspera').addEventListener('show.bs.modal', cargarEspera);
    $('listaEspera').addEventListener('click', async ev => {
        const r = ev.target.closest('[data-retomar]'), d = ev.target.closest('[data-descartar]');
        const imp = ev.target.closest('[data-imprimir]');
        if (imp) {
            // Yesenia Quejada Rojas - Claude — 30/10/2026: comanda o cuenta de un pedido apartado sin tener que retomarlo.
            ev.preventDefault();
            const e = espera.find(x => x.id === Number(imp.dataset.imprimir));
            if (e) imprimirBorrador(borrador(e.pedido, { ...e, nombre: e.nombre || e.cliente }), imp.dataset.tipo === 'comanda');
            return;
        }
        if (!r && !d) return;
        ev.preventDefault();
        const id = Number((r || d).dataset.retomar || (r || d).dataset.descartar);
        const e = espera.find(x => x.id === id);
        if (!e) return;
        if (r && pedido.length && esperaActual !== id && !confirm('Hay un pedido en pantalla. ¿Reemplazarlo?')) return;
        if (d) {
            if (!confirm('¿Descartar este pedido por cobrar?')) return;
            try {
                const q = await api.post(`/Venta/QuitarEspera?id=${id}`);
                if (!q.resultado) alerta(q.mensaje, 'warning');
            } catch (err) { errorAlerta(err); return; }
            if (id === esperaActual) { esperaActual = null; guardarPantalla(); }
        }
        if (r) {
            limpiar();
            esperaActual = id;
            pedido = e.pedido;
            cajasManual = e.cajas;
            seleccionar($('tipoPedido'), e.tipo, alCambiarTipo);
            $('txtNombreMesa').value = e.tipo === 'MESA' && mesaDeNombre(e.nombre) !== null ? e.nombre : '';   // Yesenia Quejada Rojas - Claude — 31/10/2026: solo se conserva la mesa.
            $('txtCliente').value = e.cliente || ''; $('txtTelefono').value = e.telefono || '';
            $('txtDireccion').value = e.direccion || ''; $('txtCostoDomicilio').value = e.envio || '';
            marcarCarta(e.carta || null);
            pintarPedido(); pintarProductos();
            bootstrap.Modal.getOrCreateInstance($('modalEspera')).hide();
        }
        cargarEspera();
    });

    /* ---------- Pedidos de la carta digital ----------
       Yesenia Quejada Rojas - Claude — 29/10/2026. El cliente arma el carrito desde el QR de su mesa y el pedido llega aquí en
       espera. "Pasar al pedido" lo confirma (el cliente ve "Confirmado" en su celular) y lo carga en pantalla con los precios de
       hoy; al cobrarlo queda cerrado con su venta. Hasta cobrarlo no descuenta inventario ni va a cocina. */
    let cartaPendientes = [], cartaVistos = null;
    function marcarCarta(id, texto) {
        origenCarta = id;
        $('avisoCarta').hidden = !id;
        $('lblAvisoCarta').textContent = id ? (texto || `Pedido N° ${id} de la carta digital: se cierra al cobrarlo.`) : '';
    }
    async function cargarPedidosCarta() {
        try {
            cartaPendientes = await api.get('/Venta/PedidosCarta');
        } catch { return; /* se reintenta en el siguiente ciclo */ }
        const nuevos = cartaPendientes.filter(p => p.estado === 'PENDIENTE');
        $('lblCarta').textContent = nuevos.length;
        $('lblCarta').className = `badge rounded-pill ${nuevos.length ? 'text-bg-danger' : 'text-bg-secondary'}`;
        $('btnCarta').classList.toggle('borde-marca', nuevos.length > 0);
        // Aviso solo de los que llegaron desde la última consulta (no al abrir la página).
        if (cartaVistos) nuevos.filter(p => !cartaVistos.has(p.idPedidoCarta))
            .forEach(p => alerta(`Nuevo pedido de la carta: ${destinoCarta(p)}`, 'warning'));
        cartaVistos = new Set(nuevos.map(p => p.idPedidoCarta));
        // Yesenia Quejada Rojas - Claude — 30/10/2026: tarjetas como las de "Por cobrar" (productos, opciones, total y botones grandes).
        $('listaCarta').innerHTML = cartaPendientes.length ? cartaPendientes.map(p => `
            <div class="espera-card carta-card ${p.estado}">
                <div class="d-flex justify-content-between align-items-start gap-2">
                    <div><strong class="fs-6">${esc(destinoCarta(p))}</strong>
                        <div class="small text-muted">N° ${p.idPedidoCarta} · ${haceCuanto(Math.floor(p.segundos / 60))}</div>
                        ${p.tipoPedido === 'DOMICILIO' ? `<div class="small"><i class="bi bi-telephone"></i> ${esc(p.telefono)} · <i class="bi bi-geo-alt"></i> ${esc(p.direccion)}</div>` : ''}
                        <span class="badge ${p.estado === 'PENDIENTE' ? 'text-bg-warning' : 'text-bg-info'}">${p.estado === 'PENDIENTE' ? 'Sin confirmar' : 'Confirmado'}</span>${espera.some(e => e.carta === p.idPedidoCarta) ? ' <span class="badge text-bg-secondary">Ya está en Por cobrar</span>' : ''}</div>
                    <strong class="text-marca text-nowrap fs-5">${moneda(p.total)}</strong>
                </div>
                <ul class="espera-lineas">${p.lineas.map(l => `<li><span class="fw-semibold">${l.cantidad} × ${esc(l.nombre)}</span>
                    ${l.opciones ? `<small class="d-block">${esc(l.opciones)}</small>` : ''}
                    ${l.notas ? `<small class="d-block fst-italic">“${esc(l.notas)}”</small>` : ''}</li>`).join('')}</ul>
                ${p.nota ? `<div class="small"><i class="bi bi-chat-left-text"></i> ${esc(p.nota)}</div>` : ''}
                <div class="d-flex flex-wrap gap-2 mt-auto">
                    <button class="btn btn-marca flex-grow-1" data-carta-pasar="${p.idPedidoCarta}"><i class="bi bi-check2"></i> ${p.estado === 'PENDIENTE' ? 'Confirmar y pasar al pedido' : 'Pasar al pedido'}</button>
                    <button class="btn btn-outline-danger" data-carta-rechazar="${p.idPedidoCarta}" title="Rechazar" aria-label="Rechazar"><i class="bi bi-x-lg"></i> Rechazar</button>
                </div>
            </div>`).join('') : '<p class="text-muted text-center my-4">No hay pedidos de la carta digital.<br>Llegan aquí cuando un cliente pide desde el QR de su mesa.</p>';
        pintarMesas();
    }
    async function atenderCarta(id, estado, idVenta) {
        const r = await api.post(`/Venta/AtenderPedidoCarta?id=${id}&estado=${estado}${idVenta ? '&idVenta=' + idVenta : ''}`);
        if (!r.resultado) alerta(r.mensaje, 'warning');
        return r.resultado;
    }
    async function cerrarPedidoCarta(id, idVenta) {
        try { await atenderCarta(id, 'CERRADO', idVenta); } catch { /* la venta ya quedó; el pedido se puede cerrar luego */ }
        cargarPedidosCarta();
    }
    $('listaCarta').addEventListener('click', async ev => {
        const pasar = ev.target.closest('[data-carta-pasar]'), rechazar = ev.target.closest('[data-carta-rechazar]');
        if (!pasar && !rechazar) return;
        const id = Number((pasar || rechazar).dataset.cartaPasar || (rechazar && rechazar.dataset.cartaRechazar));
        const p = cartaPendientes.find(x => x.idPedidoCarta === id);
        if (!p) return;
        try {
            if (rechazar) {
                if (!confirm(`¿Rechazar el pedido N° ${p.idPedidoCarta} (${destinoCarta(p)})? El cliente verá que no fue aceptado.`)) return;
                if (await atenderCarta(id, 'RECHAZADO')) { if (origenCarta === id) limpiar(); alerta('Pedido rechazado', 'info'); }
                return cargarPedidosCarta();
            }
            if (edicion) { alerta('Termine o cancele la edición del pedido antes de pasar uno de la carta.', 'warning'); return; }
            if (pedido.length && !confirm('Hay un pedido en pantalla. ¿Reemplazarlo?')) return;
            if (p.estado === 'PENDIENTE' && !await atenderCarta(id, 'CONFIRMADO')) return cargarPedidosCarta();
            limpiar();
            for (const l of p.lineas) {
                const prod = productos.find(x => x.idProducto === l.idProducto);
                if (!prod) { alerta(`${l.nombre} ya no está activo y se quitó del pedido`, 'warning'); continue; }
                // Salsas, adiciones y "Sin ..." que eligió el cliente en la carta (los precios salen del catálogo de hoy).
                const mods = modificadores.filter(m => m.idProducto === prod.idProducto && (l.modificadores || []).includes(m.idModificador));
                const sin = ingredientes.filter(i => i.idProducto === prod.idProducto && (l.quitados || []).includes(i.idInsumo));
                agregar(prod, l.cantidad, l.notas || '', mods, sin);
            }
            // Yesenia Quejada Rojas - Claude — 13/11/2026: el pedido de la carta puede ser para mesa, para llevar o a domicilio.
            const tipoCarta = ['LLEVAR', 'DOMICILIO'].includes(p.tipoPedido) ? p.tipoPedido : 'MESA';
            seleccionar($('tipoPedido'), tipoCarta, alCambiarTipo);
            if (tipoCarta === 'DOMICILIO') {
                $('txtCliente').value = p.clienteNombre || ''; $('txtTelefono').value = p.telefono || ''; $('txtDireccion').value = p.direccion || '';
            } else $('txtNombreMesa').value = (tipoCarta === 'MESA' ? destinoCarta(p) : p.clienteNombre || '').slice(0, 100);
            sincronizarMesa();
            totales();
            marcarCarta(id, `Pedido N° ${id} de la carta (${destinoCarta(p)}). Ya trae salsas, adiciones y lo que no quiere; se cierra al cobrarlo.${p.nota ? ' Nota: ' + p.nota : ''}`);
            bootstrap.Modal.getOrCreateInstance($('modalCarta')).hide();
            cargarPedidosCarta();
        } catch (e) { errorAlerta(e); }
    });
    $('modalCarta').addEventListener('show.bs.modal', cargarPedidosCarta);

    /* ---------- Mesas ahora ----------
       Yesenia Quejada Rojas - Claude — 30/10/2026. Qué tiene cada mesa en este momento: pedidos por cobrar cuyo nombre empieza
       por "Mesa X" (los botones de mesa lo escriben así) y pedidos de la carta de esa mesa. Lo que no tiene mesa (llevar,
       domicilio, sin mesa) va en una cola, el más antiguo primero. Tocar un pedido lo abre en Vender. */
    let mesas = [];
    const mesaDeNombre = n => { const m = /^mesa\s+([^·]+?)\s*(·|$)/i.exec((n || '').trim()); return m ? m[1].trim().toLowerCase() : null; };
    /* Yesenia Quejada Rojas - Claude — 31/10/2026. La mesa del pedido se elige con botones (antes un desplegable) y solo en "Mesa".
       Tocar una la elige y escribe "Mesa X" en el campo oculto; tocarla otra vez la quita. Si el pedido trae algo más después de la
       mesa (el cliente de un pedido de la carta: "Mesa 3 · Juan") eso se conserva. */
    const mostrarMesas = () => { $('datosNombre').hidden = tipo !== 'MESA' || !mesas.length; };
    async function cargarMesas() {
        try { mesas = await api.get('/Venta/Mesas'); } catch { return; /* sin mesas: no salen los botones */ }
        $('mesaPedido').innerHTML = mesas.map(m =>
            `<button type="button" class="btn btn-outline-marca text-nowrap" data-valor="${esc(m.nombre)}" aria-pressed="false">Mesa ${esc(m.nombre)}</button>`).join('');
        mostrarMesas();
        sincronizarMesa();
        pintarMesas();
    }
    function sincronizarMesa() {
        const m = mesaDeNombre($('txtNombreMesa').value);
        $('mesaPedido').querySelectorAll('.btn').forEach(b => {
            const activa = m !== null && b.dataset.valor.toLowerCase() === m;
            b.classList.toggle('active', activa);
            b.setAttribute('aria-pressed', String(activa));
        });
    }
    $('mesaPedido').addEventListener('click', ev => {
        const b = ev.target.closest('[data-valor]');
        if (!b) return;
        const n = $('txtNombreMesa'), antes = mesaDeNombre(n.value);
        let resto = n.value.trim();
        if (antes !== null) resto = resto.split('·').slice(1).join('·').trim();
        const quitar = antes === b.dataset.valor.toLowerCase();
        n.value = quitar ? resto : `Mesa ${b.dataset.valor}${resto ? ' · ' + resto : ''}`;
        sincronizarMesa();
        guardarPantalla();
    });

    const cantidadDe = lineas => lineas.reduce((s, l) => s + l.cantidad, 0);
    function pintarMesas() {
        const porMesa = new Map(mesas.map(m => [m.nombre.toLowerCase(), []]));
        const sinMesa = [];
        // Un pedido de la carta que ya se apartó en "Por cobrar" se muestra una sola vez (como por cobrar).
        const enEspera = new Set(espera.map(e => e.carta).filter(Boolean));
        espera.forEach(e => {
            const item = { clase: 'espera', id: e.id, titulo: e.nombre || etiquetaPedido[e.tipo], minutos: e.minutos, enPantalla: e.id === esperaActual,
                detalle: `${e.tipo === 'MESA' ? 'Por cobrar' : etiquetaPedido[e.tipo] + ' · por cobrar'} · ${haceCuanto(e.minutos)} · ${cantidadDe(e.pedido)} productos`,
                total: e.pedido.reduce((s, l) => s + precioLinea(l), 0) + (e.tipo === 'DOMICILIO' ? Number(e.envio || 0) : 0) };
            const m = e.tipo === 'MESA' ? mesaDeNombre(e.nombre) : null;
            (m !== null && porMesa.has(m) ? porMesa.get(m) : sinMesa).push(item);
        });
        cartaPendientes.filter(p => !enEspera.has(p.idPedidoCarta)).forEach(p => {
            const item = { clase: 'carta', id: p.idPedidoCarta, titulo: `Carta${p.clienteNombre ? ' · ' + p.clienteNombre : ''}`, minutos: Math.floor(p.segundos / 60),
                detalle: `${p.estado === 'PENDIENTE' ? 'Sin confirmar' : 'Confirmado'} · ${haceCuanto(Math.floor(p.segundos / 60))} · ${cantidadDe(p.lineas)} productos`, total: p.total };
            const m = String(p.mesa || '').toLowerCase();
            (porMesa.has(m) ? porMesa.get(m) : sinMesa).push(item);
        });
        const ocupadas = [...porMesa.values()].filter(l => l.length).length;
        $('lblMesas').textContent = `${ocupadas}/${mesas.length}`;
        $('lblMesas').className = `badge rounded-pill ${ocupadas ? 'text-bg-warning' : 'text-bg-secondary'}`;
        const tarjeta = it => `<button type="button" class="mesa-item ${it.clase}" data-abrir="${it.clase}:${it.id}">
                <span class="d-flex justify-content-between gap-2"><span class="fw-semibold">${esc(it.titulo)}</span><span class="mesa-total">${moneda(it.total)}</span></span>
                ${it.enPantalla ? '<span class="badge text-bg-info">En pantalla</span>' : ''}
                <small class="d-block text-muted">${esc(it.detalle)}</small></button>`;
        $('gridMesas').innerHTML = mesas.length ? mesas.map(m => {
            const l = porMesa.get(m.nombre.toLowerCase());
            return `<div class="mesa-ahora ${l.length ? 'ocupada' : 'libre'}">
                <div class="d-flex justify-content-between align-items-center"><strong>Mesa ${esc(m.nombre)}</strong>
                    <span class="badge ${l.length ? 'text-bg-warning' : 'text-bg-success'}">${l.length ? moneda(l.reduce((s, x) => s + x.total, 0)) : 'Libre'}</span></div>
                ${l.map(tarjeta).join('')}</div>`;
        }).join('') : '<p class="text-muted small mb-0">No hay mesas activas. Créelas en Configuración › Mesas y carta digital.</p>';
        sinMesa.sort((a, b) => b.minutos - a.minutos);
        $('colaSinMesa').innerHTML = sinMesa.length
            ? sinMesa.map((it, i) => `<div class="d-flex gap-2 align-items-start"><span class="badge rounded-pill text-bg-secondary mt-2">${i + 1}</span><div class="flex-grow-1">${tarjeta(it)}</div></div>`).join('')
            : '<p class="text-muted small mb-0">No hay pedidos en cola.</p>';
    }
    // Abre el pedido con la misma acción de "Por cobrar" (retomar) o de "Carta" (pasar al pedido).
    $('panelMesas').addEventListener('click', ev => {
        const b = ev.target.closest('[data-abrir]');
        if (!b) return;
        const [clase, id] = b.dataset.abrir.split(':');
        const destino = clase === 'espera' ? $('listaEspera').querySelector(`[data-retomar="${id}"]`) : $('listaCarta').querySelector(`[data-carta-pasar="${id}"]`);
        if (!destino) { alerta('Ese pedido ya no está; se actualizó la lista.', 'info'); cargarEspera(); cargarPedidosCarta(); return; }
        bootstrap.Offcanvas.getOrCreateInstance($('panelMesas')).hide();
        destino.click();
    });
    $('panelMesas').addEventListener('show.bs.offcanvas', () => { cargarEspera(); cargarPedidosCarta(); if (!mesas.length) cargarMesas(); });

    /* ---------- Editar un pedido ya cobrado ---------- */
    async function cargarEdicion(id) {
        const t = await api.get(`/Venta/Obtener?id=${id}`);
        if (!t || t.venta.segundosEdicion <= 0) {
            alerta(`El pedido N° ${id} ya no se puede editar: pasó el tiempo permitido o cocina ya lo empezó.`, 'warning');
            history.replaceState(null, '', '/Venta');
            return;
        }
        const v = t.venta;
        limpiar();
        for (const l of t.lineas) {
            const p = productos.find(x => x.idProducto === l.idProducto);
            if (!p) { alerta(`${l.nombre} ya no está activo y se quitó del pedido`, 'warning'); continue; }
            const mods = modificadores.filter(m => m.idProducto === p.idProducto && l.modificadores.includes(m.idModificador));
            const sin = ingredientes.filter(i => i.idProducto === p.idProducto && (l.quitados || []).includes(i.idInsumo));
            // Yesenia Quejada Rojas - Claude — 01/11/2026: "SIN SALSAS" viene dentro de las notas guardadas; se separa para poder verlo y cambiarlo.
            const { sinSalsas, notas } = separarSinSalsas(l.notas);
            pedido.push({ clave: claveLinea(p.idProducto, notas, mods, sin, sinSalsas),
                idProducto: p.idProducto, nombre: p.nombre, precio: p.precio, cantidad: l.cantidad, notas, mods, sin, sinSalsas });
        }
        fijarCajas(v.cajas || 0);   // Yesenia Quejada Rojas - Claude — 31/10/2026: al editar se conservan las cajas con las que se cobró.
        seleccionar($('tipoPedido'), v.tipoPedido, alCambiarTipo);
        seleccionar($('metodoPago'), v.metodoPago, alCambiarPago);
        if (v.tipoPedido === 'DOMICILIO') {
            $('txtCliente').value = v.clienteNombre; $('txtTelefono').value = v.clienteTelefono;
            $('txtDireccion').value = v.direccion; $('txtCostoDomicilio').value = v.costoDomicilio;
        } else $('txtNombreMesa').value = v.clienteNombre;
        if (v.metodoPago === 'EFECTIVO') { $('txtRecibido').value = v.montoRecibido; $('txtTransferencia').value = v.montoTransferencia || ''; }
        edicion = { idVenta: v.idVenta, vence: Date.now() + v.segundosEdicion * 1000 };
        $('avisoEdicion').hidden = false;
        $('lblEdicionId').textContent = `N° ${v.idVenta}`;
        $('lblTituloPedido').textContent = `Pedido N° ${v.idVenta}`;
        $('lblCobrar').textContent = 'Guardar cambios';
        $('btnVaciar').hidden = true;
        pintarPedido(); pintarProductos();
        relojEdicion();
    }
    function relojEdicion() {
        if (!edicion) return;
        const seg = Math.max(0, Math.round((edicion.vence - Date.now()) / 1000));
        $('lblEdicionTiempo').textContent = seg > 0 ? `Quedan ${mmss(seg)} para guardar cambios.` : 'Se acabó el tiempo: ya no se puede modificar.';
        $('avisoEdicion').classList.toggle('alert-danger', seg <= 30);
        $('avisoEdicion').classList.toggle('alert-info', seg > 30);
        totales();
        if (seg > 0) setTimeout(relojEdicion, 1000);
    }
    function salirEdicion() {
        edicion = null;
        $('avisoEdicion').hidden = true;
        $('lblTituloPedido').textContent = 'Pedido';
        $('lblCobrar').textContent = 'Cobrar';
        $('btnVaciar').hidden = false;
    }

    /* ---------- Comandas en proceso ---------- */
    async function cargarComandas() {
        try {
            const lista = await api.get('/Cocina/Listar');
            $('lblComandas').textContent = lista.length;
            $('lblReglaEdicion').textContent = `Un pedido se puede editar o anular durante ${APP.minutosEdicion} min, mientras cocina no lo haya empezado.`;
            $('listaComandas').innerHTML = lista.length ? lista.map(c => `
                <div class="card comanda-mini ${c.estadoCocina}"><div class="card-body p-2">
                    <div class="d-flex justify-content-between">
                        <strong>N° ${c.idVenta} · ${esc(etiquetaPedido[c.tipoPedido])}${c.clienteNombre ? ' · ' + esc(c.clienteNombre) : ''}</strong>
                        <span class="badge ${claseCocina[c.estadoCocina]}">${esc(etiquetaCocina[c.estadoCocina])}</span>
                    </div>
                    <div class="small text-muted">${c.lineas.map(l => `${l.cantidad} x ${esc(l.nombre)}`).join(', ')}</div>
                    <div class="d-flex justify-content-between align-items-center mt-1">
                        <small><i class="bi bi-clock"></i> hace ${mmss(c.segundos)}</small>
                        <span class="d-flex gap-1">
                            ${c.segundosEdicion > 0
                                ? `<a class="btn btn-sm btn-outline-primary" href="/Venta?editar=${c.idVenta}"><i class="bi bi-pencil"></i> Editar (${mmss(c.segundosEdicion)})</a>`
                                : '<small class="text-muted"><i class="bi bi-lock"></i> Ya no se puede editar</small>'}
                            ${c.segundosEdicion > 0 || APP.esAdmin ? `<button class="btn btn-sm btn-outline-danger" data-anular="${c.idVenta}" title="Anular"><i class="bi bi-x-circle"></i></button>` : ''}
                        </span>
                    </div>
                </div></div>`).join('') : '<p class="text-muted">No hay pedidos en cocina.</p>';
        } catch (e) { /* se reintenta en el siguiente ciclo */ }
    }
    $('listaComandas').addEventListener('click', async ev => {
        const b = ev.target.closest('[data-anular]');
        if (b && await anularPedido(b.dataset.anular)) { cargarComandas(); cargar(); }
    });
    $('panelComandas').addEventListener('show.bs.offcanvas', cargarComandas);

    /* ---------- Atajos de teclado ---------- */
    document.addEventListener('keydown', ev => {
        if (ev.key === 'F2' || (ev.key === '/' && !ev.target.matches('input, textarea'))) { ev.preventDefault(); $('txtBuscar').focus(); $('txtBuscar').select(); }
        if (ev.key === 'F9') { ev.preventDefault(); cobrar(); }
    });

    restaurarPantalla();
    cargarMesas();
    subirEsperaLocal().then(cargarEspera); setInterval(cargarEspera, 15000);
    cargar();
    if(APP.mostrarCocina){ cargarComandas(); setInterval(cargarComandas, 20000); }
    cargarPedidosCarta(); setInterval(cargarPedidosCarta, 20000);
    // Yesenia Quejada Rojas - Claude — 31/10/2026: la campana del menú abre aquí la lista de pedidos de la carta (/Venta?carta=1).
    if (new URLSearchParams(location.search).has('carta')) bootstrap.Modal.getOrCreateInstance($('modalCarta')).show();
})();
