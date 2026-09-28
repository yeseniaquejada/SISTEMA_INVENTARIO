(async function () {
    const form = document.getElementById('formulario');
    const cboTipo = document.getElementById('cboTipo');
    const cboInsumo = document.getElementById('cboInsumo');
    const lblStock = document.getElementById('lblStock');
    const colores = { ENTRADA: 'success', SALIDA: 'primary', MERMA: 'warning', VENTA: 'danger', 'AJUSTE+': 'info', 'AJUSTE-': 'secondary' };
    let insumos = [];

    document.getElementById('txtInicio').value = hoy();
    document.getElementById('txtFin').value = hoy();

    async function cargarInsumos() {
        const actual = cboInsumo.value;
        insumos = (await api.get('/Insumo/Listar')).filter(i => i.activo);
        llenarSelect(cboInsumo, insumos, 'idInsumo', 'nombre');
        llenarSelect(document.getElementById('cboFiltroInsumo'), insumos, 'idInsumo', 'nombre', 'Todos');
        cboInsumo.value = actual || '0';
        mostrarStock();
    }

    function mostrarStock() {
        const i = insumos.find(x => String(x.idInsumo) === cboInsumo.value);
        lblStock.textContent = i ? `Stock actual: ${num(i.stock)} ${i.unidadMedida}` : '';
        if (i && cboTipo.value === 'ENTRADA') form.costoUnitario.value = i.costoUnitario;
    }

    function ajustarTipo() {
        document.querySelectorAll('.solo-entrada').forEach(el => el.hidden = cboTipo.value !== 'ENTRADA');
        mostrarStock();
    }

    async function cargarKardex() {
        const inicio = document.getElementById('txtInicio').value, fin = document.getElementById('txtFin').value;
        const idInsumo = document.getElementById('cboFiltroInsumo').value || 0;
        const lista = await api.get(`/Movimiento/Listar?inicio=${inicio}&fin=${fin}&idInsumo=${idInsumo}`);
        renderTabla(document.getElementById('tablaKardex'), lista, m => `<tr>
            <td class="text-nowrap">${esc(m.fecha)}</td><td>${esc(m.insumo)}</td>
            <td><span class="badge text-bg-${colores[m.tipo]}">${m.tipo}</span></td>
            <td class="text-end">${num(m.cantidad)} ${esc(m.unidadMedida)}</td>
            <td class="text-end">${num(m.stockAnterior)}</td><td class="text-end">${num(m.stockNuevo)}</td>
            <td>${esc(m.proveedor || m.observacion)}${m.fechaVencimiento ? `<br><small class="text-muted">Vence ${esc(m.fechaVencimiento.substring(0, 10))}</small>` : ''}</td><td>${esc(m.usuario)}</td></tr>`, 8);
    }

    cboTipo.addEventListener('change', ajustarTipo);
    cboInsumo.addEventListener('change', mostrarStock);
    document.getElementById('btnBuscar').addEventListener('click', () => cargarKardex().catch(errorAlerta));
    document.getElementById('btnExcel').addEventListener('click', () => {
        const q = new URLSearchParams({ inicio: document.getElementById('txtInicio').value, fin: document.getElementById('txtFin').value,
            idInsumo: document.getElementById('cboFiltroInsumo').value || 0 });
        location.href = `/Movimiento/Exportar?${q}`;
    });

    document.getElementById('btnRegistrar').addEventListener('click', async () => {
        if (!form.reportValidity()) return;
        try {
            const datos = leerForm(form);
            datos.fechaVencimiento = datos.fechaVencimiento || null;
            const r = await api.post('/Movimiento/Registrar', datos);
            if (!r.resultado) return alerta(r.mensaje, 'warning');
            alerta('Movimiento registrado');
            form.cantidad.value = ''; form.observacion.value = ''; form.fechaVencimiento.value = '';
            await cargarInsumos();
            await cargarKardex();
        } catch (e) { errorAlerta(e); }
    });

    const proveedores = (await api.get('/Proveedor/Listar')).filter(p => p.activo);
    llenarSelect(document.getElementById('cboProveedor'), proveedores, 'idProveedor', 'razonSocial', 'Sin proveedor');
    await cargarInsumos();
    ajustarTipo();
    await cargarKardex();
})().catch(errorAlerta);
