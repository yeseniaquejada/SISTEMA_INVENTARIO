(async function () {
    const tbody = document.querySelector('#tabla tbody');
    const form = document.getElementById('formulario');
    const modal = new bootstrap.Modal(document.getElementById('modal'));
    const cboInsumo = document.getElementById('cboInsumo');
    const txtCantidad = document.getElementById('txtCantidad');
    const tablaReceta = document.getElementById('tablaReceta');
    let productos = [], insumos = [], receta = [];

    insumos = (await api.get('/Insumo/Listar')).filter(i => i.activo);
    llenarSelect(cboInsumo, insumos.map(i => ({ ...i, texto: `${i.nombre} (${i.unidadMedida})` })), 'idInsumo', 'texto', 'Seleccione un insumo...');

    async function cargar() {
        productos = await api.get('/Producto/Listar');
        renderTabla(tbody, productos, p => `<tr>
            <td>${esc(p.nombre)}</td><td class="text-end">${moneda(p.precio)}</td>
            <td class="text-center">${p.totalInsumos}</td><td>${badgeActivo(p.activo)}</td>
            <td class="text-end text-nowrap">
                <button class="btn btn-sm btn-outline-primary" data-editar="${p.idProducto}"><i class="bi bi-pencil"></i></button>
                <button class="btn btn-sm btn-outline-danger" data-eliminar="${p.idProducto}"><i class="bi bi-trash"></i></button>
            </td></tr>`, 5);
    }

    function pintarReceta() {
        renderTabla(tablaReceta, receta, (r, i) => `<tr>
            <td>${esc(r.insumo)}</td><td class="text-end">${num(r.cantidad)} ${esc(r.unidadMedida)}</td>
            <td class="text-end"><button type="button" class="btn btn-sm btn-link text-danger" data-quitar="${i}"><i class="bi bi-x-lg"></i></button></td>
            </tr>`, 3);
    }

    async function abrir(p) {
        llenarForm(form, p ?? { idProducto: 0, activo: true });
        receta = p ? await api.get(`/Producto/Receta?id=${p.idProducto}`) : [];
        document.querySelector('#modal .modal-title').textContent = p ? 'Editar producto' : 'Nuevo producto';
        pintarReceta();
        modal.show();
    }

    document.getElementById('btnAgregar').addEventListener('click', () => {
        const id = Number(cboInsumo.value), cantidad = Number(txtCantidad.value);
        if (!id || !(cantidad > 0)) return alerta('Seleccione un insumo y una cantidad válida', 'warning');
        const ins = insumos.find(i => i.idInsumo === id);
        const existente = receta.find(r => r.idInsumo === id);
        if (existente) existente.cantidad = cantidad;
        else receta.push({ idInsumo: id, insumo: ins.nombre, unidadMedida: ins.unidadMedida, cantidad });
        txtCantidad.value = '';
        pintarReceta();
    });

    tablaReceta.addEventListener('click', ev => {
        const btn = ev.target.closest('[data-quitar]');
        if (btn) { receta.splice(Number(btn.dataset.quitar), 1); pintarReceta(); }
    });

    tbody.addEventListener('click', async ev => {
        const btn = ev.target.closest('button');
        if (!btn) return;
        try {
            if (btn.dataset.editar) await abrir(productos.find(p => String(p.idProducto) === btn.dataset.editar));
            if (btn.dataset.eliminar && confirm('¿Desea eliminar este producto?')) {
                const r = await api.post(`/Producto/Eliminar?id=${btn.dataset.eliminar}`);
                if (r.resultado) { alerta('Producto eliminado'); cargar(); } else alerta(r.mensaje, 'warning');
            }
        } catch (e) { errorAlerta(e); }
    });

    document.getElementById('btnNuevo').addEventListener('click', () => abrir(null).catch(errorAlerta));
    document.getElementById('btnGuardar').addEventListener('click', async () => {
        if (!form.reportValidity()) return;
        try {
            const r = await api.post('/Producto/Guardar', { ...leerForm(form), receta });
            if (r.resultado) { modal.hide(); alerta('Producto guardado'); cargar(); } else alerta(r.mensaje, 'warning');
        } catch (e) { errorAlerta(e); }
    });

    filtroTabla(document.getElementById('buscar'), tbody);
    await cargar();
})().catch(errorAlerta);
