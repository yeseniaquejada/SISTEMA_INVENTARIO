/* Punto de venta: tarjetas de productos, adiciones, tipo de pedido y forma de pago */
(function () {
    const $ = id => document.getElementById(id);
    const modalProducto = new bootstrap.Modal($('modalProducto'));
    const modalListo = new bootstrap.Modal($('modalListo'));

    let productos = [], modificadores = [], categoria = 0;
    let pedido = [];            // { idProducto, nombre, precio, cantidad, notas, mods:[{idModificador,nombre,precio}] }
    let actual = null, cantidad = 1;
    let tipo = 'MESA', pago = 'EFECTIVO', cajaAbierta = true;

    const precioLinea = l => (l.precio + l.mods.reduce((s, m) => s + m.precio, 0)) * l.cantidad;
    const subtotal = () => pedido.reduce((s, l) => s + precioLinea(l), 0);
    const envio = () => tipo === 'DOMICILIO' ? Number($('txtCostoDomicilio').value || 0) : 0;
    const total = () => subtotal() + envio();

    /* ---------- Catálogo ---------- */
    async function cargar() {
        try {
            const [cat, caja] = await Promise.all([api.get('/Venta/Catalogo'), api.get('/Caja/Actual')]);
            productos = cat.productos;
            modificadores = cat.modificadores;
            cajaAbierta = !!caja;
            $('avisoCaja').hidden = cajaAbierta;
            pintarCategorias();
            pintarProductos();
            pintarPedido();
        } catch (e) { errorAlerta(e); }
    }

    function pintarCategorias() {
        const cats = [];
        productos.forEach(p => { if (!cats.some(c => c.id === p.idCategoriaMenu)) cats.push({ id: p.idCategoriaMenu, nombre: p.categoriaMenu, icono: p.icono }); });
        $('categorias').innerHTML = [{ id: 0, nombre: 'Todo', icono: '⭐' }, ...cats].map(c =>
            `<button class="btn btn-sm ${c.id === categoria ? 'btn-marca' : 'btn-outline-secondary bg-white'}" data-cat="${c.id}">${esc(c.icono)} ${esc(c.nombre)}</button>`).join('');
    }

    function pintarProductos() {
        const q = $('txtBuscar').value.trim().toLowerCase();
        const lista = productos.filter(p => (!categoria || p.idCategoriaMenu === categoria) &&
            (!q || (p.nombre + ' ' + p.descripcion).toLowerCase().includes(q)));
        $('productos').innerHTML = lista.length ? lista.map(p => `
            <button class="producto-card" data-id="${p.idProducto}">
                ${p.imagenUrl ? `<img class="producto-foto" src="${esc(p.imagenUrl)}" alt="" loading="lazy" />`
                              : `<div class="producto-foto sin-foto">${esc(p.icono || '🍽️')}</div>`}
                <div class="producto-info">
                    <span class="producto-nombre">${esc(p.nombre)}</span>
                    ${p.descripcion ? `<small class="producto-desc">${esc(p.descripcion)}</small>` : ''}
                    <span class="producto-precio">${moneda(p.precio)}</span>
                </div>
            </button>`).join('')
            : '<p class="text-muted">No hay productos que coincidan.</p>';
    }

    $('categorias').addEventListener('click', ev => {
        const b = ev.target.closest('[data-cat]');
        if (!b) return;
        categoria = Number(b.dataset.cat);
        pintarCategorias();
        pintarProductos();
    });
    $('txtBuscar').addEventListener('input', pintarProductos);

    /* ---------- Modal de adiciones ---------- */
    $('productos').addEventListener('click', ev => {
        const card = ev.target.closest('[data-id]');
        if (!card) return;
        actual = productos.find(p => p.idProducto === Number(card.dataset.id));
        const mods = modificadores.filter(m => m.idProducto === actual.idProducto);
        if (!mods.length && !ev.shiftKey) { agregar(actual, 1, '', []); return; } // sin adiciones: directo al pedido
        cantidad = 1;
        $('tituloProducto').textContent = `${actual.nombre} · ${moneda(actual.precio)}`;
        $('txtNotas').value = '';
        $('lblCantidad').textContent = 1;
        $('modificadores').innerHTML = mods.length ? mods.map(m => `
            <label class="form-check border rounded p-2 ps-5 d-flex justify-content-between">
                <span><input type="checkbox" class="form-check-input" value="${m.idModificador}" /> ${esc(m.nombre)}</span>
                <span class="text-muted">${m.precio ? '+ ' + moneda(m.precio) : ''}</span>
            </label>`).join('') : '<p class="text-muted small mb-0">Este producto no tiene adiciones.</p>';
        modalProducto.show();
    });
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
        pintarPedido();
    }

    /* ---------- Pedido ---------- */
    function pintarPedido() {
        $('lineas').innerHTML = pedido.length ? pedido.map((l, i) => `
            <div class="linea d-flex gap-2 py-2 border-bottom">
                <div class="flex-grow-1">
                    <div class="fw-semibold">${esc(l.nombre)}</div>
                    ${l.mods.map(m => `<small class="d-block">+ ${esc(m.nombre)}</small>`).join('')}
                    ${l.notas ? `<small class="d-block fst-italic">“${esc(l.notas)}”</small>` : ''}
                    <div class="btn-group btn-group-sm mt-1">
                        <button class="btn btn-outline-secondary" data-menos="${i}"><i class="bi bi-dash"></i></button>
                        <span class="btn btn-light disabled">${l.cantidad}</span>
                        <button class="btn btn-outline-secondary" data-mas="${i}"><i class="bi bi-plus"></i></button>
                    </div>
                </div>
                <div class="text-end">
                    <div class="fw-semibold">${moneda(precioLinea(l))}</div>
                    <button class="btn btn-sm btn-link text-danger p-0" data-quitar="${i}"><i class="bi bi-trash"></i></button>
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
        $('btnCobrar').disabled = !pedido.length || !cajaAbierta;
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
            if (!b) return;
            grupo.querySelectorAll('.btn').forEach(x => x.classList.toggle('active', x === b));
            alCambiar(b.dataset.valor);
        });
    }
    segmentado($('tipoPedido'), v => {
        tipo = v;
        $('datosCliente').hidden = v !== 'DOMICILIO';
        $('datosNombre').hidden = v === 'DOMICILIO';
        totales();
    });
    segmentado($('metodoPago'), v => { pago = v; $('datosEfectivo').hidden = v !== 'EFECTIVO'; totales(); });

    /* ---------- Cobrar ---------- */
    $('btnCobrar').addEventListener('click', async () => {
        const t = total();
        const recibido = pago === 'EFECTIVO' ? Number($('txtRecibido').value || t) : t;
        if (pago === 'EFECTIVO' && recibido < t) { alerta('El valor recibido es menor al total', 'warning'); return; }
        const venta = {
            tipoPedido: tipo,
            clienteNombre: tipo === 'DOMICILIO' ? $('txtCliente').value.trim() : $('txtNombreMesa').value.trim(),
            clienteTelefono: $('txtTelefono').value.trim(),
            direccion: $('txtDireccion').value.trim(),
            costoDomicilio: envio(),
            metodoPago: pago,
            montoRecibido: recibido,
            lineas: pedido.map(l => ({ idProducto: l.idProducto, cantidad: l.cantidad, notas: l.notas, modificadores: l.mods.map(m => m.idModificador) }))
        };
        $('btnCobrar').disabled = true;
        try {
            const r = await api.post('/Venta/Registrar', venta);
            if (!r.resultado) { alerta(r.mensaje, 'warning'); totales(); return; }
            $('lblListoTotal').textContent = `Pedido N° ${r.id} · ${moneda(t)}`;
            $('lblListoCambio').textContent = pago === 'EFECTIVO' ? `Cambio: ${moneda(recibido - t)}` : etiquetaPago[pago];
            $('lnkTicket').href = `/Venta/Ticket/${r.id}`;
            limpiar();
            modalListo.show();
        } catch (e) { errorAlerta(e); totales(); }
    });

    function limpiar() {
        pedido = [];
        ['txtCliente', 'txtTelefono', 'txtDireccion', 'txtCostoDomicilio', 'txtRecibido', 'txtNombreMesa', 'txtBuscar'].forEach(id => $(id).value = '');
        pintarProductos();
        pintarPedido();
    }

    cargar();
})();
