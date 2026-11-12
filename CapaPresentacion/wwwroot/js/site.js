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

// Yesenia Quejada Rojas - Claude — 19/10/2026: espacio que no se parte, para que el "$" no quede en una línea y el valor en otra.
const moneda = n => (window.APP?.moneda ?? '$') + ' ' + Number(n ?? 0).toLocaleString('es-CO', { maximumFractionDigits: 0 });
const num = n => Number(n ?? 0).toLocaleString('es-CO', { maximumFractionDigits: 3 });
// Yesenia Quejada Rojas - Claude — 31/10/2026: "hoy" es la fecha de la base de datos (la que llevan las ventas), no la del PC. Pasada la medianoche
// de Colombia el PC ya está en el día siguiente, pero la base de datos va horas atrás, y los filtros de "hoy" daban 0.
const hoy = () => window.APP?.hoy ?? new Date().toLocaleDateString('en-CA'); // yyyy-mm-dd
// Primer día de lo que se está trabajando: el día en que se abrió la caja que sigue abierta (si no hay caja abierta, es hoy). Los filtros de "Hoy"
// van de inicioDia() a hoy(), así que después de la medianoche siguen mostrando el día en curso hasta que se cierre la caja.
const inicioDia = () => window.APP?.inicioDia ?? hoy();

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
        : `<tr><td colspan="${columnas}" class="text-center"><div class="table-empty"><i class="bi bi-inbox"></i><span>Sin registros por ahora</span></div></td></tr>`;
    etiquetarTabla(tbody);
}

/* Yesenia Quejada Rojas - Claude — 28/10/2026: en el celular las filas se muestran como tarjetas (una debajo de otra) en vez de
   obligar a desplazarse de lado; cada celda lleva el título de su columna. Ver .table-apilada en tema.css. */
function etiquetarTabla(tbody) {
    const tabla = tbody.closest('table');
    if (!tabla || tabla.classList.contains('sin-apilar')) return;
    const titulos = [...tabla.querySelectorAll('thead th')].map(th => th.textContent.trim());
    tabla.classList.add('table-apilada');
    tbody.querySelectorAll('tr').forEach(tr => [...tr.cells].forEach((td, i) => {
        if (td.colSpan === 1 && titulos[i] && !td.dataset.label) td.dataset.label = titulos[i];
    }));
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
            op.alCargar?.(datos);
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
                if (r.resultado) { alerta('Registro eliminado'); cargar(); }
                else {
                    // Yesenia Quejada Rojas - Claude — 28/10/2026: si no se puede borrar porque ya tiene uso, se ofrece desactivarlo
                    // en el mismo paso (se guarda igual que al editar, solo con Activo = no).
                    const obj = datos.find(x => String(x[op.id]) === btn.dataset.eliminar);
                    if (obj?.activo && /puede desactivarl/i.test(r.mensaje ?? '') && confirm(`${r.mensaje}\n\n¿Desea desactivarlo ahora?`)) {
                        llenarForm(form, obj);
                        const datosForm = { ...leerForm(form), activo: false };
                        const g = await api.post(`${op.base}/Guardar`, op.preparar ? op.preparar(datosForm) : datosForm);
                        if (g.resultado) { alerta('Registro desactivado'); cargar(); } else alerta(g.mensaje, 'warning');
                    } else alerta(r.mensaje, 'warning');
                }
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

// fechaHace(0) es el inicio del día en curso (la caja abierta); con más días, la fecha de hoy menos esos días.
const fechaHace = dias => { if (dias === 0) return inicioDia(); const d = new Date(hoy() + 'T12:00:00'); d.setDate(d.getDate() - dias); return d.toLocaleDateString('en-CA'); };
const etiquetaPago = { EFECTIVO: 'Efectivo', TARJETA: 'Tarjeta', TRANSFERENCIA: 'Transferencia', RAPPI: 'Rappi' };
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

/* Yesenia Quejada Rojas - Claude — 30/10/2026. Campos de dinero (input[data-moneda]): mientras se escribe se ven con "$" y puntos de
   miles ("$ 12.500"; decimales con coma si el campo los admite). Para el resto del código el campo sigue entregando el número
   limpio en .value ("12500"), así no cambia cómo se leen ni cómo se guardan. */
function campoMoneda(el) {
    if (el.dataset.monedaListo) return;
    el.dataset.monedaListo = '1';
    const nativo = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value');
    const decimales = el.step && Number(el.step) < 1 ? 2 : 0;
    const mostrar = (entero, frac, conComa) => entero === '' && !conComa ? ''
        : (window.APP?.moneda ?? '$') + ' ' + Number(entero || 0).toLocaleString('es-CO') + (conComa ? ',' + frac : '');
    // Lo que el usuario ve/escribe ("$ 12.500,5"): el punto es de miles y la coma de decimales.
    const desdeTexto = t => {
        const limpio = String(t).replace(/[^\d,]/g, '');
        const i = limpio.indexOf(',');
        const entero = (i < 0 ? limpio : limpio.slice(0, i)).replace(/^0+(?=\d)/, '');
        const frac = i < 0 || !decimales ? '' : limpio.slice(i + 1).replace(/,/g, '').slice(0, decimales);
        return { entero, frac, conComa: i >= 0 && decimales > 0 };
    };
    el.type = 'text';
    el.inputMode = decimales ? 'decimal' : 'numeric';
    el.autocomplete = 'off';
    Object.defineProperty(el, 'value', {
        configurable: true,
        get() {
            const p = desdeTexto(nativo.get.call(el));
            if (p.entero === '' && !p.frac) return '';
            return p.frac ? `${Number(p.entero || 0)}.${p.frac}` : String(Number(p.entero || 0));
        },
        set(v) {
            const s = String(v ?? '').trim();
            if (/^-?\d+(\.\d+)?$/.test(s)) {   // número que llega del código (punto decimal)
                const [e, f = ''] = s.split('.');
                const frac = decimales ? f.slice(0, decimales).replace(/0+$/, '') : '';
                nativo.set.call(el, mostrar(e, frac, !!frac));
            } else {
                const p = desdeTexto(s);
                nativo.set.call(el, mostrar(p.entero, p.frac, p.conComa));
            }
        }
    });
    el.addEventListener('input', () => {
        const antes = nativo.get.call(el), desdeFin = antes.length - (el.selectionStart ?? antes.length);
        const p = desdeTexto(antes);
        const nuevo = mostrar(p.entero, p.frac, p.conComa);
        nativo.set.call(el, nuevo);
        const pos = Math.max(0, nuevo.length - desdeFin);
        try { el.setSelectionRange(pos, pos); } catch { /* sin cursor */ }
    });
    el.value = nativo.get.call(el);
}
(function () {
    const aplicar = raiz => raiz.querySelectorAll?.('input[data-moneda]').forEach(campoMoneda);
    const iniciar = () => {
        aplicar(document);
        new MutationObserver(cambios => cambios.forEach(c => c.addedNodes.forEach(n => {
            if (n.nodeType !== 1) return;
            if (n.matches('input[data-moneda]')) campoMoneda(n); else aplicar(n);
        }))).observe(document.body, { childList: true, subtree: true });
    };
    document.readyState === 'loading' ? document.addEventListener('DOMContentLoaded', iniciar) : iniciar();
})();

/* Yesenia Quejada Rojas - Claude — 30/10/2026. Actualización automática: cada minuto (y al volver a la pestaña) se pregunta la versión
   publicada; si cambió, la página se recarga sola cuando no hay nada a medio escribir ni un cuadro abierto. Si están escribiendo,
   aparece un aviso con "Actualizar". En Vender el pedido en pantalla vuelve solo después de recargar. */
(function () {
    const actual = window.APP?.version;
    if (!actual) return;
    let avisado = false;
    const ocupado = () => !!document.querySelector('.modal.show, .offcanvas.show, .dropdown-menu.show')
        || [...document.querySelectorAll('form input:not([type=hidden]):not([type=search]), form textarea')].some(i => i.value && i.value !== i.defaultValue)
        || (document.activeElement && document.activeElement.matches('input, textarea') && document.activeElement.value);
    function aviso() {
        if (avisado) return;
        avisado = true;
        const d = document.createElement('div');
        d.className = 'alert alert-info d-flex align-items-center gap-2 shadow position-fixed bottom-0 start-50 translate-middle-x mb-3';
        d.style.zIndex = 2000;
        d.setAttribute('role', 'status');
        d.innerHTML = '<i class="bi bi-arrow-repeat"></i> Hay una versión nueva del sistema. <button type="button" class="btn btn-sm btn-marca">Actualizar</button>';
        d.querySelector('button').addEventListener('click', () => location.reload());
        document.body.appendChild(d);
    }
    async function revisar() {
        try {
            const v = (await (await fetch('/version', { cache: 'no-store' })).text()).trim();
            if (!v || v === actual) return;
            if (ocupado()) aviso(); else location.reload();
        } catch { /* sin conexión: se revisa en el próximo minuto */ }
    }
    setInterval(revisar, 60000);
    document.addEventListener('visibilitychange', () => { if (!document.hidden) revisar(); });
})();
