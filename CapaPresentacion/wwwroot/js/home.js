(async function () {
    const $ = id => document.getElementById(id);
    try {
        const d = await api.get('/Home/Dashboard');
        $('kpiVentas').textContent = moneda(d.ventasHoy);
        $('kpiPedidos').textContent = d.pedidosHoy;
        $('kpiDomicilios').textContent = d.domiciliosPendientes;
        $('kpiValor').textContent = moneda(d.valorInventario);
        $('kpiBajo').textContent = `${d.insumosBajoStock} de ${d.totalInsumos}`;
        $('estadoCaja').innerHTML = d.cajaAbierta
            ? '<a href="/Caja" class="btn btn-outline-success"><i class="bi bi-unlock"></i> Caja abierta</a>'
            : '<a href="/Caja" class="btn btn-outline-warning"><i class="bi bi-lock"></i> Caja cerrada</a>';
        renderTabla($('tablaAlertas'), d.alertas, i => `<tr>
            <td>${esc(i.codigo)}</td><td>${esc(i.nombre)}</td>
            <td class="text-end stock-bajo">${num(i.stock)} ${esc(i.unidadMedida)}</td>
            <td class="text-end">${num(i.stockMinimo)} ${esc(i.unidadMedida)}</td></tr>`, 4);
        renderTabla($('tablaVencimientos'), d.vencimientos, l => `<tr>
            <td>${esc(l.nombre)}</td><td class="text-end">${num(l.cantidadDisponible)} ${esc(l.unidadMedida)}</td>
            <td><span class="badge ${l.diasRestantes <= 0 ? 'text-bg-danger' : 'text-bg-warning'}">${l.diasRestantes < 0 ? 'Vencido' : l.diasRestantes === 0 ? 'Hoy' : `En ${l.diasRestantes} días`}</span>
                <small class="text-muted">${esc(l.fechaVencimiento)}</small></td></tr>`, 3);
    } catch (e) { errorAlerta(e); }
})();
