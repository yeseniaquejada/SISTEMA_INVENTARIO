using System.Diagnostics;
using CapaNegocio;
using CapaPresentacion.Infraestructura;
using CapaPresentacion.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CapaPresentacion.Controllers;

public class HomeController : Controller
{
    public IActionResult Index() => View();

    [HttpGet]
    public JsonResult Dashboard() => Json(new CN_Dashboard().Obtener(User.IdSede()));

    [AllowAnonymous]
    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error() =>
        View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
}
