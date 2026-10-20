using System.Diagnostics;
using CapaNegocio;
using CapaPresentacion.Infraestructura;
using CapaPresentacion.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CapaPresentacion.Controllers;

public class HomeController : Controller
{
    // Yesenia Quejada Rojas - Claude — 19/10/2026: el domiciliario entra directo a sus domicilios.
    public IActionResult Index() => User.EsDomiciliario() ? RedirectToAction("Index", "Domicilio") : View();

    [HttpGet, Authorize(Roles = Claves.Local)]
    public JsonResult Dashboard() => Json(new CN_Dashboard().Obtener(User.IdSede()));

    [AllowAnonymous]
    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error() =>
        View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
}
