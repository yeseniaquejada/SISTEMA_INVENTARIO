using System.Security.Claims;
using CapaEntidad;
using CapaNegocio;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CapaPresentacion.Controllers;

public abstract class BaseController : Controller
{
    protected int IdUsuario => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
}

/// <summary>Entradas (compras), salidas y mermas de bodega, y el kardex.</summary>
[Authorize(Roles = "ADMINISTRADOR")]
public class MovimientoController : BaseController
{
    private readonly CN_Movimiento _negocio = new();

    public IActionResult Index() => View();

    [HttpGet]
    public JsonResult Listar(DateTime inicio, DateTime fin, int idInsumo = 0) => Json(_negocio.Listar(inicio, fin, idInsumo));

    [HttpPost]
    public JsonResult Registrar([FromBody] Movimiento obj)
    {
        obj.IdUsuario = IdUsuario;
        return Json(_negocio.Registrar(obj));
    }
}

/// <summary>Punto de venta: cada venta descuenta los insumos según la receta.</summary>
public class VentaController : BaseController
{
    private readonly CN_Venta _negocio = new();

    public IActionResult Index() => View();
    public IActionResult Historial() => View();

    [HttpGet]
    public JsonResult Productos() => Json(new CN_Producto().Listar().Where(p => p.Activo));

    [HttpGet]
    public JsonResult Listar(DateTime inicio, DateTime fin) => Json(_negocio.Listar(inicio, fin));

    [HttpPost]
    public JsonResult Registrar([FromBody] List<DetalleVenta> detalle) => Json(_negocio.Registrar(IdUsuario, detalle));
}
