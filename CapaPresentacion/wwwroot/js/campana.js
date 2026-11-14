/* Yesenia Quejada Rojas - Claude — 31/10/2026. Campana de pedidos de la carta digital (ver Views/Shared/_Campana.cshtml).
   Consulta /Venta/PedidosCarta cada 15 segundos (los mismos pedidos de la pantalla Vender). Avisa cuando llega uno nuevo
   (campana que se sacude, aviso en pantalla, sonido opcional y el número en el título de la pestaña) y los lista en el orden
   en que llegaron: el primero es el que más lleva esperando. */
(function () {
    const $ = id => document.getElementById(id);
    const boton = $('btnCampana');
    if (!boton || typeof api === 'undefined') return;

    const cuenta = $('campanaCuenta'), icono = $('campanaIcono'), lista = $('campanaLista'), resumen = $('campanaResumen'), btnSonido = $('campanaSonido');
    const tituloBase = document.title;
    let pedidos = [], vistos = null, sonido = true, audio = null, ultimoAviso = 0, parpadeo = null;
    // Yesenia Quejada Rojas - Claude — 13/11/2026: el sonido viene activado; solo se apaga si la persona lo apagó en este equipo.
    try { sonido = localStorage.getItem('campana-sonido') !== '0'; } catch { /* sin almacenamiento: el sonido queda activado */ }
    const btnAvisos = $('campanaAvisos');
    const puedeNotificar = () => 'Notification' in window && Notification.permission === 'granted';

    const hace = seg => {
        const min = Math.floor(seg / 60);
        if (min < 1) return 'ahora mismo';
        if (min < 60) return `hace ${min} min`;
        return `hace ${Math.floor(min / 60)} h ${min % 60} min`;
    };
    const unidades = p => p.lineas.reduce((s, l) => s + l.cantidad, 0);

    function pintarSonido() {
        btnSonido.innerHTML = sonido ? '<i class="bi bi-volume-up"></i> Sonido activado' : '<i class="bi bi-volume-mute"></i> Sonido apagado';
        btnSonido.setAttribute('aria-pressed', sonido ? 'true' : 'false');
        // El botón de avisos del navegador solo sale mientras no se haya dado (ni negado) el permiso.
        if (btnAvisos) btnAvisos.hidden = !('Notification' in window) || Notification.permission !== 'default';
    }

    function pintar() {
        const nuevos = pedidos.filter(p => p.estado === 'PENDIENTE');
        cuenta.textContent = nuevos.length;
        cuenta.hidden = nuevos.length === 0;
        icono.className = nuevos.length ? 'bi bi-bell-fill' : 'bi bi-bell';
        boton.title = nuevos.length ? `${nuevos.length} pedido${nuevos.length === 1 ? '' : 's'} de la carta sin confirmar` : 'Pedidos de la carta digital';
        document.title = (nuevos.length ? `(${nuevos.length}) ` : '') + tituloBase;
        resumen.textContent = pedidos.length
            ? `${nuevos.length} sin confirmar · ${pedidos.length - nuevos.length} confirmado${pedidos.length - nuevos.length === 1 ? '' : 's'} por cobrar`
            : '';
        // En el orden en que llegaron: el que más lleva esperando va primero.
        const orden = pedidos.slice().sort((a, b) => b.segundos - a.segundos);
        lista.innerHTML = orden.length ? orden.map((p, i) => `
            <a class="campana-item" href="/Venta?carta=1" data-carta="${p.idPedidoCarta}" role="listitem">
                <span class="badge rounded-pill text-bg-secondary campana-numero" title="Orden de llegada">${i + 1}</span>
                <div class="flex-grow-1 min-w-0">
                    <div class="d-flex justify-content-between align-items-start gap-2">
                        <strong>${esc(destinoCarta(p))}</strong>
                        <span class="badge ${p.estado === 'PENDIENTE' ? 'text-bg-warning' : 'text-bg-info'}">${p.estado === 'PENDIENTE' ? 'Nuevo' : 'Confirmado'}</span>
                    </div>
                    <div class="small text-muted">${hace(p.segundos)} · ${unidades(p)} producto${unidades(p) === 1 ? '' : 's'} · ${moneda(p.total)}</div>
                    <div class="small">${p.lineas.slice(0, 2).map(l => `${l.cantidad} × ${esc(l.nombre)}`).join(', ')}${p.lineas.length > 2 ? ` y ${p.lineas.length - 2} más` : ''}</div>
                    ${p.nota ? `<div class="small fst-italic"><i class="bi bi-chat-left-text"></i> ${esc(p.nota)}</div>` : ''}
                </div>
            </a>`).join('')
            : '<div class="campana-vacio text-muted small"><i class="bi bi-bell-slash fs-4 d-block mb-1"></i>No hay pedidos de la carta.<br>Llegan aquí cuando un cliente pide desde el QR.</div>';
    }

    function sacudir() {
        icono.classList.remove('campana-sacude');
        void icono.offsetWidth;   // reinicia la animación si ya estaba corriendo
        icono.classList.add('campana-sacude');
    }

    // Dos tonos cortos. Los navegadores solo dejan sonar el audio después de que la persona toca la página; por eso el sonido
    // se prepara en el primer toque y, si todavía no se puede, el aviso sale igual sin sonido.
    function preparar() {
        try { audio = audio || new (window.AudioContext || window.webkitAudioContext)(); if (audio.state === 'suspended') audio.resume(); } catch { audio = null; }
    }
    function sonar() {
        if (!sonido) return;
        preparar();
        if (!audio || audio.state !== 'running') return;
        const t = audio.currentTime;
        [[880, 0], [1175, 0.2]].forEach(([frecuencia, retraso]) => {
            const o = audio.createOscillator(), g = audio.createGain();
            o.type = 'sine'; o.frequency.value = frecuencia;
            g.gain.setValueAtTime(0.0001, t + retraso);
            g.gain.exponentialRampToValueAtTime(0.25, t + retraso + 0.03);
            g.gain.exponentialRampToValueAtTime(0.0001, t + retraso + 0.32);
            o.connect(g); g.connect(audio.destination);
            o.start(t + retraso); o.stop(t + retraso + 0.35);
        });
    }
    document.addEventListener('pointerdown', () => { if (sonido) preparar(); });

    /* Yesenia Quejada Rojas - Claude — 13/11/2026. Avisos más fuertes:
       - Aviso del navegador (con permiso) cuando la pestaña no está a la vista o el navegador está minimizado.
       - El título de la pestaña parpadea "Nuevo pedido" mientras no se mire.
       - Mientras haya pedidos sin confirmar, la campana suena y se sacude otra vez cada minuto (recordatorio). */
    function notificar(llegaron) {
        if (!puedeNotificar() || !document.hidden) return;
        try {
            const n = new Notification(llegaron.length === 1 ? 'Nuevo pedido de la carta' : `${llegaron.length} pedidos nuevos de la carta`, {
                body: llegaron.map(p => `${destinoCarta(p)} · ${moneda(p.total)}`).join('\n'),
                tag: 'pedido-carta', renotify: true, icon: document.querySelector('link[rel="icon"]')?.href || undefined
            });
            n.onclick = () => { window.focus(); n.close(); };
        } catch { /* algunos celulares solo permiten avisos desde una app instalada */ }
    }
    function parpadearTitulo(activo) {
        clearInterval(parpadeo); parpadeo = null;
        if (!activo) return;
        let alterno = false;
        parpadeo = setInterval(() => {
            if (!document.hidden) { clearInterval(parpadeo); parpadeo = null; pintar(); return; }
            alterno = !alterno;
            document.title = alterno ? '🔔 Nuevo pedido' : tituloBase;
        }, 1000);
    }
    function avisarNuevos() {
        const nuevos = pedidos.filter(p => p.estado === 'PENDIENTE');
        // Solo los que llegaron desde la última consulta: al abrir la página no se avisa de lo que ya estaba.
        if (vistos) {
            const llegaron = nuevos.filter(p => !vistos.has(p.idPedidoCarta));
            if (llegaron.length) {
                sacudir(); sonar(); ultimoAviso = Date.now();
                notificar(llegaron);
                if (document.hidden) parpadearTitulo(true);
                // En Vender el aviso en pantalla ya lo da venta.js; aquí solo se evita repetirlo.
                if (!$('modalCarta')) llegaron.forEach(p => alerta(`Nuevo pedido de la carta: ${destinoCarta(p)}`, 'warning'));
            } else if (nuevos.length && Date.now() - ultimoAviso >= 60000) {
                sacudir(); sonar(); ultimoAviso = Date.now();
            }
        }
        vistos = new Set(nuevos.map(p => p.idPedidoCarta));
    }

    // Yesenia Quejada Rojas - Claude — 13/11/2026: ya no se deja de consultar con la pestaña oculta; así el aviso llega aunque
    // estén en otra pestaña (el navegador puede espaciar las consultas a una por minuto).
    async function cargar() {
        let datos;
        try { datos = await api.get('/Venta/PedidosCarta'); } catch { return; /* sin conexión o sesión vencida: se reintenta en el siguiente ciclo */ }
        if (!Array.isArray(datos)) return;
        pedidos = datos;
        pintar();
        avisarNuevos();
    }

    btnSonido.addEventListener('click', () => {
        sonido = !sonido;
        try { localStorage.setItem('campana-sonido', sonido ? '1' : '0'); } catch { /* se queda solo en esta página */ }
        pintarSonido();
        if (sonido) { preparar(); sonar(); }
    });
    btnAvisos?.addEventListener('click', async () => {
        try { await Notification.requestPermission(); } catch { /* navegador sin avisos */ }
        pintarSonido();
        if (puedeNotificar()) alerta('Listo: le avisaremos aunque esté en otra pestaña.', 'success');
    });
    // Al tocar un pedido: en Vender se abre la lista de la carta ahí mismo; en las demás páginas el enlace lleva a Vender con la lista abierta.
    lista.addEventListener('click', ev => {
        if (!ev.target.closest('[data-carta]')) return;
        const modal = $('modalCarta');
        if (!modal) return;
        ev.preventDefault();
        bootstrap.Dropdown.getOrCreateInstance(boton).hide();
        bootstrap.Modal.getOrCreateInstance(modal).show();
    });
    $('campanaVer').addEventListener('click', ev => {
        const modal = $('modalCarta');
        if (!modal) return;
        ev.preventDefault();
        bootstrap.Dropdown.getOrCreateInstance(boton).hide();
        bootstrap.Modal.getOrCreateInstance(modal).show();
    });
    boton.addEventListener('show.bs.dropdown', cargar);
    document.addEventListener('visibilitychange', () => { if (!document.hidden) cargar(); });

    pintarSonido();
    pintar();
    cargar();
    setInterval(cargar, 15000);
})();
