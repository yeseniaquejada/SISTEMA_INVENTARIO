using System.Security.Claims;
using CapaEntidad;
using CapaNegocio;
using CapaPresentacion.Infraestructura;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CapaPresentacion.Controllers;

public class AccesoController : Controller
{
    [AllowAnonymous, HttpGet]
    public IActionResult Login()
    {
        if (User.Identity?.IsAuthenticated == true) return RedirectToAction("Index", "Home");
        return View(new CN_Configuracion().Obtener());
    }

    [AllowAnonymous, HttpPost]
    public async Task<IActionResult> Login(string usuario, string clave, string? returnUrl, bool recordar = false)
    {
        var u = new CN_Usuario().Autenticar(usuario, clave);
        if (u == null)
        {
            ViewBag.Error = "Usuario o contraseña incorrectos";
            return View(new CN_Configuracion().Obtener());
        }

        await IniciarSesion(u.IdUsuario, u.NombreCompleto, u.Rol, u.IdSede, u.Sede, recordar);
        if (!string.IsNullOrEmpty(returnUrl) && Url.IsLocalUrl(returnUrl)) return Redirect(returnUrl);
        return RedirectToAction("Index", "Home");
    }

    // Yesenia Quejada Rojas - Claude — 13/11/2026: "Recordarme en este equipo". La clave no se guarda: queda una cookie cifrada
    // y persistente (sobrevive a cerrar el navegador) por DiasRecordar días, que se renueva sola con el uso. "Salir" la borra.
    private const int DiasRecordar = 30;

    private Task IniciarSesion(int id, string nombre, string rol, int idSede, string sede, bool recordar)
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, id.ToString()),
            new(ClaimTypes.Name, nombre),
            new(ClaimTypes.Role, rol),
            new(Claves.IdSede, idSede.ToString()),
            new(Claves.Sede, sede)
        };
        var identidad = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
        var propiedades = new AuthenticationProperties { IsPersistent = recordar };
        if (recordar) propiedades.ExpiresUtc = DateTimeOffset.UtcNow.AddDays(DiasRecordar);
        return HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, new ClaimsPrincipal(identidad), propiedades);
    }

    /// <summary>El administrador puede trabajar sobre cualquier sede.</summary>
    [HttpPost, Authorize(Roles = Claves.Admin)]
    public async Task<IActionResult> CambiarSede(int idSede, string? volver)
    {
        var sede = new CN_Sede().Listar().FirstOrDefault(s => s.IdSede == idSede && s.Activo);
        if (sede != null)
        {
            // Al cambiar de sede se conserva el "Recordarme" que tenía la sesión.
            var actual = await HttpContext.AuthenticateAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            await IniciarSesion(User.Id(), User.Identity!.Name!, Claves.Admin, sede.IdSede, sede.Nombre, actual.Properties?.IsPersistent == true);
        }
        return !string.IsNullOrEmpty(volver) && Url.IsLocalUrl(volver) ? Redirect(volver) : RedirectToAction("Index", "Home");
    }

    [HttpGet]
    public JsonResult Sedes() => Json(new CN_Sede().Listar().Where(s => s.Activo));

    [HttpPost]
    public async Task<IActionResult> Salir()
    {
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        return RedirectToAction("Login");
    }

    public IActionResult MiClave() => View();

    [HttpPost]
    public JsonResult CambiarClave([FromBody] CambioClave c) =>
        Json(new CN_Usuario().CambiarClave(User.Id(), c.Actual, c.Nueva, c.Confirmacion));

    public record CambioClave(string Actual, string Nueva, string Confirmacion);

    [AllowAnonymous]
    public IActionResult Denegado() => View();
}
