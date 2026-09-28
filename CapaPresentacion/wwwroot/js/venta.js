(async function () {
    const grid = document.getElementById('gridProductos');
    const tablaPedido = document.getElementById('tablaPedido');
    const btnCobrar = document.getElementById('btnCobrar');
    let productos = [], pedido = [];

    function pintarProductos(filtro = '') {
        const lista = productos.filter(p => p.nombre.toLowerCase().includes(filtro.toLowerCase()));
        grid.innerHTML = lista.map(p => `
            <div class="col-6 col-md-4 col-xl-3">
                <button class="btn btn-light border w-100 producto-btn shadow-sm" data-id="${p.idProducto}">
                    <div class="fw-semibold">${esc(p.nombre)}</div>
                    <div class="text-danger">${moneda(p.precio)}</div>
                </button>
            </div>`).join('') || '<div class="text-muted">No hay productos</div>';
    }

    function pintarPedido() {
        renderTabla(tablaPedido, pedido, (d, i) => `<tr>
            <td>${esc(d.nombre)}</td>
            <td class="text-center text-nowrap">
                <button class="btn btn-sm btn-link p-0" data-menos="${i}"><i class="bi bi-dash-circle"></i></button>
                ${d.cantidad}
                <button class="btn btn-sm btn-link p-0" data-mas="${i}"><i class="bi bi-plus-circle"></i></button>
            </td>
            <td class="text-end">${moneda(d.precio * d.cantidad)}</td>
            <td><button class="btn btn-sm btn-link text-danger p-0" data-quitar="${i}"><i class="bi bi-x-lg"></i></button></td>
            </tr>`, 4);
        document.getElementById('lblTotal').textContent = moneda(pedido.reduce((s, d) => s + d.precio * d.cantidad, 0));
    }

    grid.addEventListener('click', ev => {
        const btn = ev.target.closest('[data-id]');
        if (!btn) return;
        const p = productos.find(x => String(x.idProducto) === btn.dataset.id);
        const item = pedido.find(d => d.idProducto === p.idProducto);
        if (item) item.cantidad++; else pedido.push({ idProducto: p.idProducto, nombre: p.nombre, precio: p.precio, cantidad: 1 });
        pintarPedido();
    });

    tablaPedido.addEventListener('click', ev => {
        const btn = ev.target.closest('button');
        if (!btn) return;
        if (btn.dataset.mas) pedido[btn.dataset.mas].cantidad++;
        if (btn.dataset.menos && --pedido[btn.dataset.menos].cantidad === 0) pedido.splice(btn.dataset.menos, 1);
        if (btn.dataset.quitar) pedido.splice(btn.dataset.quitar, 1);
        pintarPedido();
    });

    document.getElementById('buscar').addEventListener('input', ev => pintarProductos(ev.target.value));
    document.getElementById('btnLimpiar').addEventListener('click', () => { pedido = []; pintarPedido(); });

    btnCobrar.addEventListener('click', async () => {
        if (!pedido.length) return alerta('Agregue productos al pedido', 'warning');
        btnCobrar.disabled = true;
        try {
            const r = await api.post('/Venta/Registrar', pedido.map(d => ({ idProducto: d.idProducto, cantidad: d.cantidad })));
            if (!r.resultado) return alerta(r.mensaje, 'warning');
            alerta(`Venta #${r.id} registrada`);
            pedido = [];
            pintarPedido();
        } catch (e) { errorAlerta(e); }
        finally { btnCobrar.disabled = false; }
    });

    productos = await api.get('/Venta/Productos');
    pintarProductos();
    pintarPedido();
})().catch(errorAlerta);
