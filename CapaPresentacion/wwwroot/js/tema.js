(() => {
    const clave = 'inventario.tema';
    const valido = valor => valor === 'claro' || valor === 'oscuro';
    let tema = 'oscuro';
    try { const guardado = localStorage.getItem(clave); if (valido(guardado)) tema = guardado; } catch { /* El selector funciona aunque el navegador no permita guardar preferencias. */ }
    const actualizar = valor => {
        tema = valor;
        document.documentElement.dataset.tema = tema;
        document.querySelectorAll('[data-cambiar-tema]').forEach(boton => {
            const claro = tema === 'claro';
            boton.setAttribute('aria-label', claro ? 'Cambiar a modo oscuro' : 'Cambiar a modo claro');
            boton.setAttribute('title', claro ? 'Cambiar a modo oscuro' : 'Cambiar a modo claro');
            boton.setAttribute('aria-pressed', String(!claro));
            boton.querySelector('[data-icono-tema]').className = claro ? 'bi bi-moon-stars' : 'bi bi-sun';
            boton.querySelector('[data-texto-tema]').textContent = claro ? 'Modo oscuro' : 'Modo claro';
        });
    };
    actualizar(tema); // Antes de pintar la página, evita un destello del tema anterior.
    document.addEventListener('DOMContentLoaded', () => actualizar(tema));
    document.addEventListener('click', evento => {
        if (!evento.target.closest('[data-cambiar-tema]')) return;
        actualizar(tema === 'claro' ? 'oscuro' : 'claro');
        try { localStorage.setItem(clave, tema); } catch { /* Preferencia válida solo durante esta página. */ }
    });
    window.addEventListener('storage', evento => {
        if (evento.key === clave || evento.key === null) actualizar(valido(evento.newValue) ? evento.newValue : 'oscuro');
    });
})();
