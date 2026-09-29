/* ==========================================================
   Utilidades compartidas por todas las páginas
   ========================================================== */

const token = () => document.querySelector('input[name="__RequestVerificationToken"]')?.value ?? '';

const api = {
    async get(url) {
        const r = await fetch(url, { headers: { 'Accept': 'application/json' } });
        if (!r.ok) throw new Error(`Error ${r.status} al consultar ${url}`);
        return r.json();
    },
    async post(url, datos) {
        const r = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'RequestVerificationToken': token() },
            body: datos === undefined ? null : JSON.stringify(datos)
        });
        if (!r.ok) throw new Error(`Error ${r.status} al enviar a ${url}`);
        return r.json();
    }
};

function esc(texto) {
    return String(texto ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

const moneda = n => (window.APP?.moneda ?? '$') + ' ' + Number(n ?? 0).toLocaleString('es-CO', { maximumFractionDigits: 0 });
const num = n => Number(n ?? 0).toLocaleString('es-CO', { maximumFractionDigits: 3 });
const hoy = () => new Date().toLocaleDateString('en-CA'); // yyyy-mm-dd

function alerta(mensaje, tipo = 'success') {
    const div = document.createElement('div');
    div.className = `toast align-items-center text-bg-${tipo} border-0`;
    div.innerHTML = `<div class="d-flex"><div class="toast-body">${esc(mensaje)}</div>
        <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button></div>`;
    document.getElementById('contenedorAlertas').appendChild(div);
    const t = new bootstrap.Toast(div, { delay: 4000 });
    div.addEventListener('hidden.bs.toast', () => div.remove());
    t.show();
}

const errorAlerta = e => alerta(e.message || 'Ocurrió un error', 'danger');

const badgeActivo = activo => activo
    ? '<span class="badge text-bg-success">Activo</span>'
    : '<span class="badge text-bg-secondary">Inactivo</span>';

/* Pinta filas en un <tbody>; filaFn devuelve el HTML de cada <tr> */
function renderTabla(tbody, lista, filaFn, columnas) {
    tbody.innerHTML = lista.length
        ? lista.map(filaFn).join('')
        : `<tr><td colspan="${columnas}" class="text-center text-muted">Sin registros</td></tr>`;
}

/* Filtro de texto sobre las filas de una tabla */
function filtroTabla(input, tbody) {
    input.addEventListener('input', () => {
        const q = input.value.toLowerCase();
        tbody.querySelectorAll('tr').forEach(tr => tr.hidden = !tr.textContent.toLowerCase().includes(q));
    });
}

/* Lee un formulario a objeto. Tipos por atributo data-tipo: numero | bool */
function leerForm(form) {
    const obj = {};
    form.querySelectorAll('[name]').forEach(el => {
        const tipo = el.dataset.tipo;
        if (el.type === 'checkbox') obj[el.name] = el.checked;
        else if (tipo === 'numero') obj[el.name] = el.value === '' ? 0 : Number(el.value);
        else if (tipo === 'bool') obj[el.name] = el.value === 'true';
        else obj[el.name] = el.value.trim();
    });
    return obj;
}

function llenarForm(form, obj) {
    form.reset();
    form.querySelectorAll('[name]').forEach(el => {
        const v = obj?.[el.name];
        if (v === undefined || v === null) return;
        if (el.type === 'checkbox') el.checked = !!v;
        else el.value = String(v);
    });
}

/* Llena un <select> con opciones */
function llenarSelect(select, lista, valor, texto, primera = 'Seleccione...') {
    select.innerHTML = (primera ? `<option value="0">${esc(primera)}</option>` : '') +
        lista.map(x => `<option value="${x[valor]}">${esc(x[texto])}</option>`).join('');
}

/* ----------------------------------------------------------
   Mantenimiento genérico (listar / crear / editar / eliminar)
   opciones: { base, id, columnas, fila(obj), nuevo() }
   Requiere en la vista: #tabla tbody, #buscar, #modal con #formulario, #btnNuevo, #btnGuardar
   ---------------------------------------------------------- */
function Mantenimiento(op) {
    const tbody = document.querySelector('#tabla tbody');
    const form = document.getElementById('formulario');
    const modal = new bootstrap.Modal(document.getElementById('modal'));
    const titulo = document.querySelector('#modal .modal-title');
    let datos = [];

    async function cargar() {
        try {
            datos = await api.get(`${op.base}/Listar`);
            renderTabla(tbody, datos, obj => `<tr>${op.fila(obj)}
                <td class="text-end text-nowrap">
                    <button class="btn btn-sm btn-outline-primary" data-editar="${obj[op.id]}" title="Editar"><i class="bi bi-pencil"></i></button>
                    ${op.sinEliminar ? '' : `<button class="btn btn-sm btn-outline-danger" data-eliminar="${obj[op.id]}" title="Eliminar"><i class="bi bi-trash"></i></button>`}
                </td></tr>`, op.columnas);
        } catch (e) { errorAlerta(e); }
    }

    function abrir(obj) {
        llenarForm(form, obj ?? op.nuevo());
        titulo.textContent = obj ? 'Editar' : 'Nuevo';
        op.alAbrir?.(obj, form);
        modal.show();
    }

    tbody.addEventListener('click', async ev => {
        const btn = ev.target.closest('button');
        if (!btn) return;
        if (btn.dataset.editar) abrir(datos.find(x => String(x[op.id]) === btn.dataset.editar));
        if (btn.dataset.eliminar && confirm('¿Desea eliminar este registro?')) {
            try {
                const r = await api.post(`${op.base}/Eliminar?id=${btn.dataset.eliminar}`);
                if (r.resultado) { alerta('Registro eliminado'); cargar(); } else alerta(r.mensaje, 'warning');
            } catch (e) { errorAlerta(e); }
        }
    });

    document.getElementById('btnNuevo').addEventListener('click', () => abrir(null));
    document.getElementById('btnGuardar').addEventListener('click', async () => {
        if (!form.reportValidity()) return;
        try {
            const datos = leerForm(form);
            const r = await api.post(`${op.base}/Guardar`, op.preparar ? op.preparar(datos) : datos);
            if (r.resultado) { modal.hide(); alerta('Guardado correctamente'); cargar(); }
            else alerta(r.mensaje, 'warning');
        } catch (e) { errorAlerta(e); }
    });

    filtroTabla(document.getElementById('buscar'), tbody);
    cargar();
    return { cargar };
}

/* Selector de sede del administrador en la barra superior */
(async function () {
    const cbo = document.getElementById('cboSedeNav');
    if (!cbo) return;
    try {
        const sedes = await api.get('/Acceso/Sedes');
        if (sedes.length < 2) { cbo.closest('form').hidden = true; return; }
        cbo.innerHTML = sedes.map(s => `<option value="${s.idSede}">${esc(s.nombre)}</option>`).join('');
        cbo.value = cbo.dataset.actual;
        cbo.addEventListener('change', () => cbo.form.submit());
    } catch (e) { /* sin selector */ }
})();

const fechaHace = dias => { const d = new Date(); d.setDate(d.getDate() - dias); return d.toLocaleDateString('en-CA'); };
const etiquetaPago = { EFECTIVO: 'Efectivo', TARJETA: 'Tarjeta', TRANSFERENCIA: 'Transferencia' };
const etiquetaPedido = { MESA: 'En mesa', LLEVAR: 'Para llevar', DOMICILIO: 'Domicilio' };
const etiquetaEstado = { PENDIENTE: 'Pendiente', EN_CAMINO: 'En camino', ENTREGADO: 'Entregado' };
const etiquetaCocina = { PENDIENTE: 'En cola', PREPARANDO: 'Preparando', LISTO: 'Listo', ENTREGADO: 'Entregado' };
const claseCocina = { PENDIENTE: 'text-bg-secondary', PREPARANDO: 'text-bg-warning', LISTO: 'text-bg-success', ENTREGADO: 'text-bg-light' };

/* Segundos a mm:ss (o h:mm:ss) */
function mmss(seg) {
    seg = Math.max(0, Math.round(seg));
    const h = Math.floor(seg / 3600), m = Math.floor(seg % 3600 / 60), s = seg % 60;
    return (h ? h + ':' + String(m).padStart(2, '0') : m) + ':' + String(s).padStart(2, '0');
}

/* Pide el motivo y anula un pedido (devuelve los insumos). Devuelve true si se anuló. */
async function anularPedido(id) {
    const motivo = prompt(`Motivo para anular el pedido N° ${id}:`);
    if (motivo === null) return false;
    if (!motivo.trim()) { alerta('Indique el motivo de la anulación', 'warning'); return false; }
    try {
        const r = await api.post(`/Venta/Anular?id=${id}&motivo=${encodeURIComponent(motivo.trim())}`);
        if (r.resultado) { alerta(`Pedido N° ${id} anulado. Los insumos volvieron al inventario.`); return true; }
        alerta(r.mensaje, 'warning');
    } catch (e) { errorAlerta(e); }
    return false;
}
