(async function () {
    try {
        const d = await api.get('/Home/Dashboard');
        document.getElementById('kpiVentas').textContent = moneda(d.ventasHoy);
        document.getElementById('kpiPedidos').textContent = d.pedidosHoy;
        document.getElementById('kpiValor').textContent = moneda(d.valorInventario);
        document.getElementById('kpiBajo').textContent = `${d.insumosBajoStock} de ${d.totalInsumos}`;
        renderTabla(document.getElementById('tablaAlertas'), d.alertas, i => `<tr>
            <td>${esc(i.codigo)}</td><td>${esc(i.nombre)}</td>
            <td class="text-end stock-bajo">${num(i.stock)} ${esc(i.unidadMedida)}</td>
            <td class="text-end">${num(i.stockMinimo)} ${esc(i.unidadMedida)}</td></tr>`, 4);
    } catch (e) { errorAlerta(e); }
})();
