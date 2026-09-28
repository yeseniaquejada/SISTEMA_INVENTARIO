(async function () {
    const $ = id => document.getElementById(id);
    const tbody = document.querySelector('#tabla tbody');
    const form = $('formulario');
    const modal = new bootstrap.Modal($('modal'));
    let productos = [], insumos = [], categorias = [], modificadores = [], receta = [], actual = null;

    [insumos, categorias, modificadores] = await Promise.all([api.get('/Insumo/Listar'), api.get('/CategoriaMenu/Listar'), api.get('/Modificador/Listar')]);
    insumos = insumos.filter(i => i.activo);
    llenarSelect($('cboInsumo'), insumos.map(i => ({ ...i, t: `${i.nombre} (${i.unidadMedida})` })), 'idInsumo', 't', 'Seleccione un insumo...');
    llenarSelect($('cboCategoria'), categorias, 'idCategoriaMenu', 'nombre', 'Seleccione...');
    $('listaModificadores').innerHTML = modificadores.filter(m => m.activo).map(m => `
        <label class="form-check border rounded px-2 py-1 d-flex justify-content-between align-items-center gap-2">
            <span><input class="form-check-input me-2" type="checkbox" value="${m.idModificador}">${esc(m.nombre)}</span>
            <small class="text-muted">${m.precio ? '+' + moneda(m.precio) : 'Gratis'}</small>
        </label>`).join('') || '<span class="text-muted small">No hay adiciones. Créelas en Mantenimiento.</span>';

    const foto = p => p.imagenUrl
        ? `<img src="${esc(p.imagenUrl)}" alt="" style="width:56px;height:42px;object-fit:cover;border-radius:6px">`
        : `<div style="width:56px;height:42px;border-radius:6px;display:grid;place-items:center;background:#f6e3da;font-size:1.3rem">${esc(p.icono)}</div>`;
    const margen = (precio, costo) => precio > 0 ? Math.round((precio - costo) / precio * 100) : 0;

    async function cargar() {
        productos = await api.get('/Producto/Listar');
        renderTabla(tbody, productos, p => `<tr>
            <td>${foto(p)}</td><td class="fw-semibold">${esc(p.nombre)}<div class="small text-muted">${p.totalInsumos} insumos</div></td>
            <td>${esc(p.icono)} ${esc(p.categoriaMenu)}</td><td class="text-end">${moneda(p.precio)}</td>
            <td class="text-end">${moneda(p.costo)}</td>
            <td class="text-end"><span class="badge ${margen(p.precio, p.costo) < 40 ? 'text-bg-warning' : 'text-bg-success'}">${margen(p.precio, p.costo)} %</span></td>
            <td>${badgeActivo(p.activo)}</td>
            <td class="text-end text-nowrap">
                <button class="btn btn-sm btn-outline-primary" data-editar="${p.idProducto}"><i class="bi bi-pencil"></i></button>
                <button class="btn btn-sm btn-outline-danger" data-eliminar="${p.idProducto}"><i class="bi bi-trash"></i></button>
            </td></tr>`, 8);
    }

    function costoReceta() { return receta.reduce((s, r) => s + r.cantidad * r.costoUnitario, 0); }
    function pintarMargen() {
        const precio = Number($('txtPrecio').value) || 0, costo = costoReceta();
        $('lblMargen').innerHTML = `Costo: <b>${moneda(costo)}</b> · Ganancia: <b>${moneda(precio - costo)}</b> (${margen(precio, costo)} %)`;
    }
    function pintarReceta() {
        renderTabla($('tablaReceta'), receta, (r, i) => `<tr>
            <td>${esc(r.insumo)}</td><td class="text-end">${num(r.cantidad)} ${esc(r.unidadMedida)}</td>
            <td class="text-end">${moneda(r.cantidad * r.costoUnitario)}</td>
            <td class="text-end"><button type="button" class="btn btn-sm btn-link text-danger p-0" data-quitar="${i}"><i class="bi bi-x-lg"></i></button></td>
            </tr>`, 4);
        pintarMargen();
    }
    function pintarFoto(url, icono) {
        $('imgProducto').hidden = !url; if (url) $('imgProducto').src = url;
        $('sinFoto').hidden = !!url; $('sinFoto').textContent = icono || '🍽️';
    }

    async function abrir(p) {
        actual = p;
        llenarForm(form, p ?? { idProducto: 0, activo: true, idCategoriaMenu: categorias[0]?.idCategoriaMenu ?? 0 });
        const det = p ? await api.get(`/Producto/Detalle?id=${p.idProducto}`) : { receta: [], modificadores: [] };
        receta = det.receta;
        document.querySelectorAll('#listaModificadores input').forEach(c => c.checked = det.modificadores.includes(Number(c.value)));
        document.querySelector('#modal .modal-title').textContent = p ? 'Editar producto' : 'Nuevo producto';
        pintarFoto(p?.imagenUrl, p?.icono);
        $('archivoFoto').value = '';
        $('archivoFoto').disabled = !p; $('btnQuitarFoto').hidden = !p?.imagenUrl;
        $('ayudaFoto').textContent = p ? 'JPG o PNG, máximo 3 MB.' : 'Guarde el producto para poder subir la foto.';
        pintarReceta();
        modal.show();
    }

    $('txtPrecio').addEventListener('input', pintarMargen);
    $('btnAgregar').addEventListener('click', () => {
        const id = Number($('cboInsumo').value), cantidad = Number($('txtCantidad').value);
        if (!id || !(cantidad > 0)) return alerta('Seleccione un insumo y una cantidad válida', 'warning');
        const ins = insumos.find(i => i.idInsumo === id);
        const existente = receta.find(r => r.idInsumo === id);
        if (existente) existente.cantidad = cantidad;
        else receta.push({ idInsumo: id, insumo: ins.nombre, unidadMedida: ins.unidadMedida, cantidad, costoUnitario: ins.costoUnitario });
        $('txtCantidad').value = '';
        pintarReceta();
    });
    $('tablaReceta').addEventListener('click', ev => {
        const b = ev.target.closest('[data-quitar]');
        if (b) { receta.splice(Number(b.dataset.quitar), 1); pintarReceta(); }
    });

    $('archivoFoto').addEventListener('change', async ev => {
        const archivo = ev.target.files[0]; if (!archivo || !actual) return;
        const datos = new FormData(); datos.append('archivo', archivo);
        try {
            const r = await fetch(`/Producto/SubirImagen?id=${actual.idProducto}`, { method: 'POST', body: datos, headers: { 'RequestVerificationToken': token() } }).then(x => x.json());
            if (!r.resultado) return alerta(r.mensaje, 'warning');
            actual.imagenUrl = r.url; pintarFoto(r.url); $('btnQuitarFoto').hidden = false;
            alerta('Foto actualizada'); cargar();
        } catch (e) { errorAlerta(e); }
    });
    $('btnQuitarFoto').addEventListener('click', async () => {
        if (!actual) return;
        const r = await api.post(`/Producto/QuitarImagen?id=${actual.idProducto}`);
        if (r.resultado) { actual.imagenUrl = ''; pintarFoto('', actual.icono); $('btnQuitarFoto').hidden = true; cargar(); }
    });

    tbody.addEventListener('click', async ev => {
        const b = ev.target.closest('button'); if (!b) return;
        try {
            if (b.dataset.editar) await abrir(productos.find(p => String(p.idProducto) === b.dataset.editar));
            if (b.dataset.eliminar && confirm('¿Desea eliminar este producto?')) {
                const r = await api.post(`/Producto/Eliminar?id=${b.dataset.eliminar}`);
                if (r.resultado) { alerta('Producto eliminado'); cargar(); } else alerta(r.mensaje, 'warning');
            }
        } catch (e) { errorAlerta(e); }
    });

    $('btnNuevo').addEventListener('click', () => abrir(null).catch(errorAlerta));
    $('btnGuardar').addEventListener('click', async () => {
        if (!form.reportValidity()) return;
        const mods = [...document.querySelectorAll('#listaModificadores input:checked')].map(c => Number(c.value));
        try {
            const r = await api.post('/Producto/Guardar', { ...leerForm(form), receta, modificadores: mods });
            if (!r.resultado) return alerta(r.mensaje, 'warning');
            alerta('Producto guardado');
            await cargar();
            if (!actual) await abrir(productos.find(p => p.idProducto === r.id)); // para poder subir la foto
            else modal.hide();
        } catch (e) { errorAlerta(e); }
    });

    filtroTabla($('buscar'), tbody);
    await cargar();
})().catch(errorAlerta);
