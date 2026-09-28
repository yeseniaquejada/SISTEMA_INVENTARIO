using CapaEntidad;
using CapaNegocio;
using CapaPresentacion.Infraestructura;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CapaPresentacion.Controllers;

/// <summary>Punto de venta: cada venta descuenta los insumos según la receta y las adiciones.</summary>
public class VentaController : Controller
{
    private readonly CN_Venta _negocio = new();

    public IActionResult Index() => View();
    public IActionResult Historial() => View();

    [HttpGet] public JsonResult Catalogo() => Json(new CN_Producto().Catalogo());

    [HttpGet]
    public JsonResult Listar(DateTime inicio, DateTime fin) => Json(_negocio.Listar(User.IdSede(), inicio, fin));

    [HttpPost]
    public JsonResult Registrar([FromBody] NuevaVenta venta) => Json(_negocio.Registrar(User.IdSede(), User.Id(), venta));

    public IActionResult Ticket(int id)
    {
        var t = _negocio.Ticket(id, User.IdSede(), User.EsAdmin());
        return t == null ? NotFound() : View(t);
    }

    [HttpGet]
    public IActionResult Exportar(DateTime inicio, DateTime fin) =>
        Excel.Archivo("ventas-" + User.Sede(), "Ventas", _negocio.Listar(User.IdSede(), inicio, fin),
            ("N°", v => v.IdVenta), ("Fecha", v => v.Fecha), ("Tipo", v => v.TipoPedido), ("Cliente", v => v.ClienteNombre),
            ("Detalle", v => v.Detalle), ("Pago", v => v.MetodoPago), ("Total", v => v.Total), ("Usuario", v => v.Usuario));
}

public class DomicilioController : Controller
{
    private readonly CN_Venta _negocio = new();
    public IActionResult Index() => View();

    [HttpGet]
    public JsonResult Listar(bool soloPendientes = true) => Json(_negocio.Domicilios(User.IdSede(), soloPendientes));

    [HttpPost]
    public JsonResult Estado(int id, string estado) => Json(_negocio.CambiarEstado(User.IdSede(), id, estado));
}

public class CajaController : Controller
{
    private readonly CN_Caja _negocio = new();
    public IActionResult Index() => View();

    [HttpGet] public JsonResult Actual() => Json(_negocio.Actual(User.IdSede()));
    [HttpGet] public JsonResult Historial() => Json(_negocio.Historial(User.IdSede()));
    [HttpPost] public JsonResult Abrir(decimal baseInicial) => Json(_negocio.Abrir(User.IdSede(), User.Id(), baseInicial));

    [HttpPost]
    public JsonResult Cerrar(decimal efectivoContado, string? observacion) =>
        Json(_negocio.Cerrar(User.IdSede(), User.Id(), efectivoContado, observacion));
}

/// <summary>Entradas, salidas, mermas y kardex.</summary>
[Authorize(Roles = Claves.Admin)]
public class MovimientoController : Controller
{
    private readonly CN_Movimiento _negocio = new();
    public IActionResult Index() => View();

    [HttpGet]
    public JsonResult Listar(DateTime inicio, DateTime fin, int idInsumo = 0) => Json(_negocio.Listar(User.IdSede(), inicio, fin, idInsumo));

    [HttpPost]
    public JsonResult Registrar([FromBody] Movimiento obj)
    {
        obj.IdUsuario = User.Id();
        obj.IdSede = User.IdSede();
        return Json(_negocio.Registrar(obj));
    }

    [HttpGet]
    public IActionResult Exportar(DateTime inicio, DateTime fin, int idInsumo = 0) =>
        Excel.Archivo("kardex-" + User.Sede(), "Kardex", _negocio.Listar(User.IdSede(), inicio, fin, idInsumo),
            ("Fecha", m => m.Fecha), ("Insumo", m => m.Insumo), ("Tipo", m => m.Tipo), ("Cantidad", m => m.Cantidad),
            ("Unidad", m => m.UnidadMedida), ("Costo unitario", m => m.CostoUnitario), ("Stock antes", m => m.StockAnterior),
            ("Stock después", m => m.StockNuevo), ("Proveedor", m => m.Proveedor), ("Observación", m => m.Observacion),
            ("Usuario", m => m.Usuario));
}

[Authorize(Roles = Claves.Admin)]
public class ConteoController : Controller
{
    private readonly CN_Conteo _negocio = new();
    public IActionResult Index() => View();
    [HttpGet] public JsonResult Listar() => Json(_negocio.Listar(User.IdSede()));
    [HttpPost] public JsonResult Registrar([FromBody] Conteo obj) => Json(_negocio.Registrar(User.IdSede(), User.Id(), obj));
}

[Authorize(Roles = Claves.Admin)]
public class CompraController : Controller
{
    private readonly CN_Compra _negocio = new();
    public IActionResult Index() => View();
    [HttpGet] public JsonResult Sugerida() => Json(_negocio.Sugerida(User.IdSede()));

    [HttpGet]
    public IActionResult Exportar() =>
        Excel.Archivo("orden-compra-" + User.Sede(), "Orden de compra", _negocio.Sugerida(User.IdSede()),
            ("Proveedor", o => o.Proveedor), ("Teléfono", o => o.TelefonoProveedor), ("Código", o => o.Codigo),
            ("Insumo", o => o.Nombre), ("Unidad", o => o.UnidadMedida), ("Stock", o => o.Stock), ("Mínimo", o => o.StockMinimo),
            ("Cantidad a pedir", o => o.CantidadSugerida), ("Costo unitario", o => o.CostoUnitario), ("Costo estimado", o => o.CostoEstimado));
}

[Authorize(Roles = Claves.Admin)]
public class ReporteController : Controller
{
    public IActionResult Index() => View();

    [HttpGet]
    public JsonResult Datos(DateTime inicio, DateTime fin) => Json(new CN_Reporte().Obtener(User.IdSede(), inicio, fin));
}
