/* Punto de venta: tarjetas de productos (más vendidos primero), salsas y adiciones,
   pedidos en espera, edición de pedidos dentro del tiempo permitido y comandas en proceso. */
(function () {
    const $ = id => document.getElementById(id);
    const modalProducto = new bootstrap.Modal($('modalProducto'));
    const modalListo = new bootstrap.Modal($('modalListo'));
    const ORDEN_GRUPOS = ['Salsas', 'Adiciones', 'Preferencias'];
    const CLAVE_ESPERA = 'pos-espera';

    let productos = [], modificadores = [], categoria = 0, top = new Map();
    let pedido = [];            // { clave, idProducto, nombre, precio, cantidad, notas, mods:[{idModificador,nombre,precio,grupo}] }
    let actual = null, cantidad = 1;
    let tipo = 'MESA', pago = 'EFECTIVO', cajaAbierta = true;
    let edicion = null;         // { idVenta, vence (ms) } cuando se edita un pedido ya cobrado

    const precioLinea = l => (l.precio + l.mods.reduce((s, m) => s + m.precio, 0)) * l.cantidad;
    const subtotal = () => pedido.reduce((s, l) => s + precioLinea(l), 0);
    const envio = () => tipo === 'DOMICILIO' ? Number($('txtCostoDomicilio').value || 0) : 0;
    const total = () => subtotal() + envio();
    const enPedido = idProducto => pedido.filter(l => l.idProducto === idProducto).reduce((s, l) => s + l.cantidad, 0);

    /* ---------- Catálogo ---------- */
    async function cargar() {
        try {
            const [cat, caja] = await Promise.all([api.get('/Venta/Catalogo'), api.get('/Caja/Actual')]);
            productos = cat.productos;       // ya vienen ordenados: más vendidos primero
            modificadores = cat.modificadores;
            top = new Map(productos.filter(p => p.vendidos > 0).slice(0, 5).map((p, i) => [p.idProducto, i + 1]));
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
        $('categorias').innerHTML = [{ id: 0, nombre: 'Más vendidos', icono: '🔥' }, ...cats].map(c =>
            `<button class="btn btn-sm ${c.id === categoria ? 'btn-marca' : 'btn-outline-secondary bg-white'}" data-cat="${c.id}">${esc(c.icono)} ${esc(c.nombre)}</button>`).join('');
    }

    function filtrados() {
        const q = $('txtBuscar').value.trim().toLowerCase();
        return productos.filter(p => (!categoria || p.idCategoriaMenu === categoria) &&
            (!q || (p.nombre + ' ' + p.descripcion + ' ' + p.categoriaMenu).toLowerCase().includes(q)));
    }

    function etiquetaStock(p) {
        if (p.disponibles === null || p.disponibles === undefined) return '';
        const quedan = p.disponibles - enPedido(p.idProducto);
        if (quedan <= 0) return '<span class="producto-stock agotado">Agotado</span>';
        if (quedan <= 5) return `<span class="producto-stock">Quedan ${quedan}</span>`;
        return '';
    }

    function pintarProductos() {
        const lista = filtrados();
        $('productos').innerHTML = lista.length ? lista.map(p => {
            const rank = top.get(p.idProducto);
            const agotado = p.disponibles !== null && p.disponibles !== undefined && p.disponibles - enPedido(p.idProducto) <= 0;
            const tieneMods = modificadores.some(m => m.idProducto === p.idProducto);
            return `<div class="producto-card ${agotado ? 'agotado' : ''}" data-id="${p.idProducto}" role="button" tabindex="0">
                ${p.imagenUrl ? `<img class="producto-foto" src="${esc(p.imagenUrl)}" alt="" loading="lazy" />`
                              : `<div class="producto-foto sin-foto">${esc(p.icono || '🍽️')}</div>`}
                ${rank ? `<span class="producto-top" title="${p.vendidos} vendidos en 30 días">🔥 Top ${rank}</span>` : ''}
                ${tieneMods ? `<button class="producto-rapido" data-rapido="${p.idProducto}" title="Agregar 1 sin opciones"><i class="bi bi-plus-lg"></i></button>` : ''}
                <div class="producto-info">
                    <span class="producto-nombre">${esc(p.nombre)}</span>
                    ${p.descripcion ? `<small class="producto-desc">${esc(p.descripcion)}</small>` : ''}
                    <span class="d-flex justify-content-between align-items-center">
                        <span class="producto-precio">${moneda(p.precio)}</span>${etiquetaStock(p)}
                    </span>
                </div>
            </div>`;
        }).join('') : '<p class="text-muted">No hay productos que coincidan.</p>';
    }

    $('categorias').addEventListener('click', ev => {
        const b = ev.target.closest('[data-cat]');
        if (!b) return;
        categoria = Number(b.dataset.cat);
        pintarCategorias();
        pintarProductos();
    });
    $('txtBuscar').addEventListener('input', pintarProductos);
    $('txtBuscar').addEventListener('keydown', ev => {
        if (ev.key === 'Enter') { const p = filtrados()[0]; if (p) abrirProducto(p); }
        if (ev.key === 'Escape') { $('txtBuscar').value = ''; pintarProductos(); }
    });

    /* ---------- Modal de salsas y adiciones ---------- */
    $('productos').addEventListener('click', ev => {
        const rapido = ev.target.closest('[data-rapido]');
        if (rapido) { agregar(productos.find(p => p.idProducto === Number(rapido.dataset.rapido)), 1, '', []); return; }
        const card = ev.target.closest('[data-id]');
        if (card) abrirProducto(productos.find(p => p.idProducto === Number(card.dataset.id)), ev.shiftKey);
    });
    $('productos').addEventListener('keydown', ev => {
        if (ev.key === 'Enter' && ev.target.matches('[data-id]')) ev.target.click();
    });

    function abrirProducto(p, forzar = false) {
        actual = p;
        const mods = modificadores.filter(m => m.idProducto === p.idProducto);
        if (!mods.length && !forzar) { agregar(p, 1, '', []); return; } // sin opciones: directo al pedido
        cantidad = 1;
        $('tituloProducto').textContent = `${p.nombre} · ${moneda(p.precio)}`;
        $('txtNotas').value = '';
        $('lblCantidad').textContent = 1;
        const grupos = [...new Set(mods.map(m => m.grupo))]
            .sort((a, b) => (ORDEN_GRUPOS.indexOf(a) + 1 || 99) - (ORDEN_GRUPOS.indexOf(b) + 1 || 99) || a.localeCompare(b));
        $('modificadores').innerHTML = mods.length ? grupos.map(g => {
            const items = mods.filter(m => m.grupo === g);
            const chips = items.every(m => !m.precio);   // opciones gratis (salsas, preferencias) como botones
            return `<div class="mb-3"><div class="fw-semibold mb-2">${esc(g)}${g === 'Salsas' ? ' <small class="text-muted fw-normal">(elija las que quiera)</small>' : ''}</div>
                ${chips ? `<div class="d-flex flex-wrap gap-2">${items.map(m => `
                    <input type="checkbox" class="btn-check" id="mod${m.idModificador}" value="${m.idModificador}" autocomplete="off" />
                    <label class="btn btn-sm btn-outline-marca rounded-pill" for="mod${m.idModificador}">${esc(m.nombre)}</label>`).join('')}</div>`
                : `<div class="d-grid gap-2">${items.map(m => `
                    <label class="form-check border rounded p-2 ps-5 d-flex justify-content-between mb-0">
                        <span><input type="checkbox" class="form-check-input" value="${m.idModificador}" /> ${esc(m.nombre)}</span>
                        <span class="text-muted">${m.precio ? '+ ' + moneda(m.precio) : ''}</span>
                    </label>`).join('')}</div>`}
            </div>`;
        }).join('') : '<p class="text-muted small mb-0">Este producto no tiene adiciones.</p>';
        modalProducto.show();
    }
    $('modalProducto').addEventListener('shown.bs.modal', () => $('btnAgregarPedido').focus());
    $('btnMenos').addEventListener('click', () => { cantidad = Math.max(1, cantidad - 1); $('lblCantidad').textContent = cantidad; });
    $('btnMas').addEventListener('click', () => { cantidad++; $('lblCantidad').textContent = cantidad; });
    $('btnAgregarPedido').addEventListener('click', () => {
        const ids = [...$('modificadores').querySelectorAll('input:checked')].map(i => Number(i.value));
        const mods = modificadores.filter(m => m.idProducto === actual.idProducto && ids.includes(m.idModificador));
        agregar(actual, cantidad, $('txtNotas').value.trim(), mods);
        modalProducto.hide();
    });

    function agregar(p, cant, notas, mods) {
        const clave = JSON.stringify([p.idProducto, notas, mods.map(m => m.idModificador).sort()]);
        const existente = pedido.find(l => l.clave === clave);
        if (existente) existente.cantidad += cant;
        else pedido.push({ clave, idProducto: p.idProducto, nombre: p.nombre, precio: p.precio, cantidad: cant, notas, mods });
        if (p.disponibles !== null && p.disponibles !== undefined && enPedido(p.idProducto) > p.disponibles)
            alerta(`Ojo: con el inventario actual solo alcanzan ${p.disponibles} de ${p.nombre}`, 'warning');
        pintarPedido();
        pintarProductos();
    }

    /* ---------- Pedido ---------- */
    function pintarPedido() {
        $('lineas').innerHTML = pedido.length ? pedido.map((l, i) => `
            <div class="linea d-flex gap-2 py-2 border-bottom">
                <div class="flex-grow-1">
                    <div class="fw-semibold">${esc(l.nombre)}</div>
                    ${l.mods.length ? `<small class="d-block">${l.mods.map(m => (m.precio ? '+ ' : '') + esc(m.nombre)).join(' · ')}</small>` : ''}
                    ${l.notas ? `<small class="d-block fst-italic">“${esc(l.notas)}”</small>` : ''}
                    <div class="btn-group btn-group-sm mt-1">
                        <button class="btn btn-outline-secondary" data-menos="${i}"><i class="bi bi-dash"></i></button>
                        <span class="btn btn-light disabled">${l.cantidad}</span>
                        <button class="btn btn-outline-secondary" data-mas="${i}"><i class="bi bi-plus"></i></button>
                    </div>
                </div>
                <div class="text-end">
                    <div class="fw-semibold">${moneda(precioLinea(l))}</div>
                    <button class="btn btn-sm btn-link text-danger p-0" data-quitar="${i}" title="Quitar"><i class="bi bi-trash"></i></button>
                </div>
            </div>`).join('')
            : '<p class="text-muted text-center my-4"><i class="bi bi-hand-index"></i> Toque un producto para agregarlo</p>';
        totales();
    }

    $('lineas').addEventListener('click', ev => {
        const b = ev.target.closest('button');
        if (!b) return;
        if (b.dataset.mas) pedido[b.dataset.mas].cantidad++;
        if (b.dataset.menos) { const l = pedido[b.dataset.menos]; if (--l.cantidad <= 0) pedido.splice(b.dataset.menos, 1); }
        if (b.dataset.quitar) pedido.splice(b.dataset.quitar, 1);
        pintarPedido();
        pintarProductos();
    });
    $('btnVaciar').addEventListener('click', () => { if (!pedido.length || confirm('¿Vaciar el pedido?')) limpiar(); });

    function totales() {
        const t = total();
        $('lblSubtotal').textContent = moneda(subtotal());
        $('lblEnvio').textContent = moneda(envio());
        $('filaEnvio').hidden = tipo !== 'DOMICILIO';
        $('lblTotal').textContent = moneda(t);
        const recibido = Number($('txtRecibido').value || 0);
        $('lblCambio').textContent = moneda(Math.max(0, recibido - t));
        $('lblCambio').classList.toggle('text-danger', recibido > 0 && recibido < t);
        // Atajos de billetes según el total
        const billetes = [...new Set([t, ...[10000, 20000, 50000, 100000].map(b => Math.ceil(t / b) * b)])].filter(v => v > 0).slice(0, 4);
        $('billetes').innerHTML = billetes.map(v => `<button type="button" class="btn btn-sm btn-light border" data-billete="${v}">${moneda(v)}</button>`).join('');
        const vencida = edicion && Date.now() >= edicion.vence;
        $('btnCobrar').disabled = !pedido.length || !cajaAbierta || vencida;
        $('btnPonerEspera').disabled = !pedido.length || !!edicion;
    }
    $('billetes').addEventListener('click', ev => {
        const b = ev.target.closest('[data-billete]');
        if (b) { $('txtRecibido').value = b.dataset.billete; totales(); }
    });
    $('txtRecibido').addEventListener('input', totales);
    $('txtCostoDomicilio').addEventListener('input', totales);

    function segmentado(grupo, alCambiar) {
        grupo.addEventListener('click', ev => {
            const b = ev.target.closest('[data-valor]');
            if (b) seleccionar(grupo, b.dataset.valor, alCambiar);
        });
    }
    function seleccionar(grupo, valor, alCambiar) {
        grupo.querySelectorAll('.btn').forEach(x => x.classList.toggle('active', x.dataset.valor === valor));
        alCambiar(valor);
    }
    const alCambiarTipo = v => {
        tipo = v;
        $('datosCliente').hidden = v !== 'DOMICILIO';
        $('datosNombre').hidden = v === 'DOMICILIO';
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
        const recibido = pago === 'EFECTIVO' ? Number($('txtRecibido').value || t) : t;
        if (pago === 'EFECTIVO' && recibido < t) { alerta('El valor recibido es menor al total', 'warning'); return; }
        const venta = {
            idVenta: edicion?.idVenta ?? 0,
            tipoPedido: tipo,
            clienteNombre: tipo === 'DOMICILIO' ? $('txtCliente').value.trim() : $('txtNombreMesa').value.trim(),
            clienteTelefono: tipo === 'DOMICILIO' ? $('txtTelefono').value.trim() : '',
            direccion: tipo === 'DOMICILIO' ? $('txtDireccion').value.trim() : '',
            costoDomicilio: envio(),
            metodoPago: pago,
            montoRecibido: recibido,
            lineas: pedido.map(l => ({ idProducto: l.idProducto, cantidad: l.cantidad, notas: l.notas, modificadores: l.mods.map(m => m.idModificador) }))
        };
        $('btnCobrar').disabled = true;
        try {
            const r = await api.post('/Venta/Registrar', venta);
            if (!r.resultado) { alerta(r.mensaje, 'warning'); totales(); return; }
            $('lblListoTitulo').textContent = edicion ? 'Pedido actualizado' : 'Venta registrada';
            $('lblListoTotal').textContent = `Pedido N° ${r.id} · ${moneda(t)}`;
            $('lblListoCambio').textContent = pago === 'EFECTIVO' ? `Cambio: ${moneda(recibido - t)}` : etiquetaPago[pago];
            $('lnkTicket').href = `/Venta/Ticket/${r.id}`;
            $('lnkComanda').href = `/Venta/Ticket/${r.id}?comanda=true`;
            if (edicion) { history.replaceState(null, '', '/Venta'); salirEdicion(); }
            limpiar();
            cargar();   // refresca más vendidos y disponibilidad
            cargarComandas();
            modalListo.show();
        } catch (e) { errorAlerta(e); totales(); }
    }
    $('btnCobrar').addEventListener('click', cobrar);

    function limpiar() {
        pedido = [];
        ['txtCliente', 'txtTelefono', 'txtDireccion', 'txtCostoDomicilio', 'txtRecibido', 'txtNombreMesa', 'txtBuscar'].forEach(id => $(id).value = '');
        $('lblClienteFrecuente').hidden = true;
        seleccionar($('tipoPedido'), 'MESA', alCambiarTipo);
        seleccionar($('metodoPago'), 'EFECTIVO', alCambiarPago);
        pintarProductos();
        pintarPedido();
    }

    /* ---------- Pedidos en espera (se guardan en este equipo) ---------- */
    function leerEspera() { try { return JSON.parse(localStorage.getItem(CLAVE_ESPERA) || '[]'); } catch { return []; } }
    function guardarEspera(lista) { try { localStorage.setItem(CLAVE_ESPERA, JSON.stringify(lista)); } catch { /* sin almacenamiento */ } }
    function pintarEspera() {
        const lista = leerEspera();
        $('lblEspera').textContent = lista.length;
        $('listaEspera').innerHTML = lista.length ? lista.map(e => `
            <li><div class="dropdown-item d-flex justify-content-between align-items-center gap-3">
                <a href="#" class="text-reset text-decoration-none" data-retomar="${e.id}">
                    <strong>${esc(e.nombre || etiquetaPedido[e.tipo])}</strong><br>
                    <small class="text-muted">${e.hora} · ${e.pedido.reduce((s, l) => s + l.cantidad, 0)} productos</small></a>
                <button class="btn btn-sm btn-link text-danger" data-descartar="${e.id}" title="Descartar"><i class="bi bi-x-lg"></i></button>
            </div></li>`).join('') : '<li><span class="dropdown-item-text text-muted small">No hay pedidos en espera</span></li>';
    }
    $('btnPonerEspera').addEventListener('click', () => {
        if (!pedido.length) return;
        const nombre = tipo === 'DOMICILIO' ? $('txtCliente').value.trim() : $('txtNombreMesa').value.trim();
        const lista = leerEspera();
        lista.push({
            id: Date.now(), nombre, tipo, pedido, hora: new Date().toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit' }),
            cliente: $('txtCliente').value, telefono: $('txtTelefono').value, direccion: $('txtDireccion').value, envio: $('txtCostoDomicilio').value
        });
        guardarEspera(lista);
        limpiar();
        pintarEspera();
        alerta(`Pedido ${nombre ? 'de ' + nombre + ' ' : ''}guardado en espera`, 'info');
    });
    $('listaEspera').addEventListener('click', ev => {
        const r = ev.target.closest('[data-retomar]'), d = ev.target.closest('[data-descartar]');
        if (!r && !d) return;
        ev.preventDefault();
        const lista = leerEspera();
        const id = Number((r || d).dataset.retomar || (r || d).dataset.descartar);
        const e = lista.find(x => x.id === id);
        if (r && e) {
            if (pedido.length && !confirm('Hay un pedido en pantalla. ¿Reemplazarlo?')) return;
            limpiar();
            pedido = e.pedido;
            seleccionar($('tipoPedido'), e.tipo, alCambiarTipo);
            $('txtNombreMesa').value = e.tipo === 'DOMICILIO' ? '' : e.nombre;
            $('txtCliente').value = e.cliente || ''; $('txtTelefono').value = e.telefono || '';
            $('txtDireccion').value = e.direccion || ''; $('txtCostoDomicilio').value = e.envio || '';
            pintarPedido(); pintarProductos();
        }
        if (d && !confirm('¿Descartar este pedido en espera?')) return;
        guardarEspera(lista.filter(x => x.id !== id));
        pintarEspera();
    });

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
            pedido.push({ clave: JSON.stringify([p.idProducto, l.notas, mods.map(m => m.idModificador).sort()]),
                idProducto: p.idProducto, nombre: p.nombre, precio: p.precio, cantidad: l.cantidad, notas: l.notas, mods });
        }
        seleccionar($('tipoPedido'), v.tipoPedido, alCambiarTipo);
        seleccionar($('metodoPago'), v.metodoPago, alCambiarPago);
        if (v.tipoPedido === 'DOMICILIO') {
            $('txtCliente').value = v.clienteNombre; $('txtTelefono').value = v.clienteTelefono;
            $('txtDireccion').value = v.direccion; $('txtCostoDomicilio').value = v.costoDomicilio;
        } else $('txtNombreMesa').value = v.clienteNombre;
        if (v.metodoPago === 'EFECTIVO') $('txtRecibido').value = v.montoRecibido;
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

    pintarEspera();
    cargar();
    cargarComandas();
    setInterval(cargarComandas, 20000);
})();
