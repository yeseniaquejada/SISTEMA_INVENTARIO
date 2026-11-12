/* Yesenia Quejada Rojas - Claude — 29/10/2026. Botón con ojo en cada campo de contraseña para ver lo que se escribe
   (iniciar sesión, cambiar contraseña y usuarios). Se agrega solo a todos los input type="password" de la página. */
(function () {
    function ponerOjo(campo) {
        if (campo.dataset.ojo) return;
        campo.dataset.ojo = '1';
        const caja = document.createElement('div');
        caja.className = 'campo-clave';
        campo.parentNode.insertBefore(caja, campo);
        caja.appendChild(campo);
        const boton = document.createElement('button');
        boton.type = 'button';
        boton.className = 'btn-ojo';
        boton.setAttribute('aria-label', 'Mostrar contraseña');
        boton.setAttribute('aria-pressed', 'false');
        boton.innerHTML = '<i class="bi bi-eye" aria-hidden="true"></i>';
        boton.addEventListener('click', () => {
            const ver = campo.type === 'password';
            campo.type = ver ? 'text' : 'password';
            boton.setAttribute('aria-pressed', String(ver));
            boton.setAttribute('aria-label', ver ? 'Ocultar contraseña' : 'Mostrar contraseña');
            boton.innerHTML = `<i class="bi ${ver ? 'bi-eye-slash' : 'bi-eye'}" aria-hidden="true"></i>`;
            campo.focus();
        });
        caja.appendChild(boton);
        // Al enviar o limpiar el formulario la contraseña vuelve a quedar oculta.
        campo.form?.addEventListener('reset', () => { if (campo.type === 'text') boton.click(); });
    }
    const iniciar = () => document.querySelectorAll('input[type="password"]').forEach(ponerOjo);
    document.readyState === 'loading' ? document.addEventListener('DOMContentLoaded', iniciar) : iniciar();
})();
