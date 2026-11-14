using CapaEntidad;
using CapaNegocio;
using CapaPresentacion.Infraestructura;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CapaPresentacion.Controllers;

/// <summary>Punto de venta: cada venta descuenta los insumos según la receta y las adiciones.</summary>
// Yesenia Quejada Rojas - Claude — 19/10/2026: el domiciliario solo usa la pantalla de domicilios.
[Authorize(Roles = Claves.Local)]
public class VentaController : Controller
{
    private readonly CN_Venta _negocio = new();

    public IActionResult Index() => View();
    public IActionResult Historial() => View();

    [HttpGet] public JsonResult Catalogo() => Json(new CN_Producto().Catalogo(User.IdSede()));

    /// <summary>Pedido completo para editarlo desde la pantalla de venta.</summary>
    [HttpGet]
    public JsonResult Obtener(int id) => Json(_negocio.Ticket(id, User.IdSede(), false));

    // Yesenia Quejada Rojas - Claude — 30/10/2026: chulito de Facturas para marcar que el pago de Rappi entró.
    [HttpPost]
    public JsonResult ConfirmarPago(int id, bool confirmado) => Json(_negocio.ConfirmarPago(User.IdSede(), User.Id(), id, confirmado));

    [HttpPost]
    public JsonResult Anular(int id, string? motivo) => Json(_negocio.Anular(User.IdSede(), id, User.Id(), User.EsAdmin(), motivo));

    /// <summary>Cliente frecuente por teléfono (nombre y última dirección).</summary>
    [HttpGet]
    public JsonResult Cliente(string? telefono) => Json(_negocio.Cliente(telefono));

    [HttpGet]
    public JsonResult Listar(DateTime inicio, DateTime fin) => Json(_negocio.Listar(User.IdSede(), inicio, fin));

    [HttpPost]
    public JsonResult Registrar([FromBody] NuevaVenta venta) => Json(_negocio.Registrar(User.IdSede(), User.Id(), venta));

    // Yesenia Quejada Rojas - Claude — 29/10/2026: pedidos que los clientes envían desde la carta digital de su mesa.
    [HttpGet]
    public JsonResult PedidosCarta() => Json(new CN_PedidoCarta().Listar(User.IdSede()));

    /// <summary>CONFIRMADO al pasarlo a la pantalla, CERRADO al cobrarlo (con la venta) o RECHAZADO.</summary>
    [HttpPost]
    public JsonResult AtenderPedidoCarta(int id, string estado, int? idVenta) =>
        Json(new CN_PedidoCarta().Atender(User.IdSede(), id, estado, User.Id(), idVenta));

    // Yesenia Quejada Rojas - Claude — 30/10/2026: pedidos "Por cobrar" compartidos entre la tablet y el computador de la sede.
    [HttpGet]
    public JsonResult Espera() => Json(new CN_PedidoEspera().Listar(User.IdSede()));

    [HttpPost]
    public JsonResult Apartar([FromBody] PedidoEspera pedido) => Json(new CN_PedidoEspera().Guardar(User.IdSede(), User.Id(), pedido));

    [HttpPost]
    public JsonResult QuitarEspera(int id) => Json(new CN_PedidoEspera().Eliminar(User.IdSede(), id));

    /// <summary>Mesas activas de la sede para elegirlas en el pedido y para el panel "Mesas ahora".</summary>
    [HttpGet]
    public JsonResult Mesas() => Json(new CN_Mesa().Listar(User.IdSede()).Where(m => m.Activo).Select(m => new { m.IdMesa, m.Nombre }));

    /// <summary>Siguiente número del día para el nombre por defecto ("Pedido 7"), igual en todos los equipos de la sede.</summary>
    [HttpPost]
    public JsonResult NumeroPedido() => Json(new CN_PedidoEspera().Consecutivo(User.IdSede()));

    /// <summary>Ticket del cliente; con comanda=true sale la comanda de cocina (sin precios).</summary>
    public IActionResult Ticket(int id, bool comanda = false)
    {
        var t = _negocio.Ticket(id, User.IdSede(), User.EsAdmin());
        ViewData["Comanda"] = comanda;
        return t == null ? NotFound() : View(t);
    }

    // Yesenia Quejada Rojas - Claude — 30/10/2026: factura o comanda de un pedido que aún no se cobra ("Cobrar después"), para
    // mandarlo a cocina o entregárselo al domiciliario con el pago "POR COBRAR". No guarda nada: solo arma el ticket con lo que
    // hay en pantalla; los totales se recalculan aquí con las líneas recibidas.
    [HttpPost]
    public IActionResult Borrador([FromForm] string datos, bool comanda = false)
    {
        Ticket? t;
        try { t = System.Text.Json.JsonSerializer.Deserialize<Ticket>(datos, new System.Text.Json.JsonSerializerOptions(System.Text.Json.JsonSerializerDefaults.Web)); }
        catch (System.Text.Json.JsonException) { return BadRequest(); }
        if (t == null || t.Lineas.Count == 0 || t.Lineas.Count > 100 || t.Lineas.Any(l => l.Cantidad <= 0 || l.Subtotal < 0)) return BadRequest();
        var v = t.Venta;
        v.IdVenta = 0;
        v.Anulada = false;
        v.MetodoPago = "POR_COBRAR";
        v.CostoDomicilio = v.TipoPedido == "DOMICILIO" ? Math.Max(0, v.CostoDomicilio) : 0;
        // Yesenia Quejada Rojas - Claude — 31/10/2026: cajas de empaque que llegan del navegador, acotadas a 0–99 como en la venta.
        v.Cajas = Math.Clamp(v.Cajas, 0, 99);
        v.Subtotal = t.Lineas.Sum(l => l.Subtotal);
        v.Total = v.Subtotal + v.CostoDomicilio;
        v.Usuario = User.Identity?.Name ?? "";
        v.Sede = User.Sede();
        v.SedeDireccion = "";
        t.Configuracion = new CN_Configuracion().Obtener();
        ViewData["Comanda"] = comanda;
        return View("Ticket", t);
    }

    [HttpGet]
    public IActionResult Exportar(DateTime inicio, DateTime fin) =>
        Excel.Archivo("ventas-" + User.Sede(), "Ventas", _negocio.Listar(User.IdSede(), inicio, fin),
            ("N°", v => v.IdVenta), ("Fecha", v => v.Fecha), ("Tipo", v => v.TipoPedido), ("Cliente", v => v.ClienteNombre),
            ("Detalle", v => v.Detalle), ("Pago", v => v.MetodoPago), ("Cajas", v => v.Cajas), ("Total", v => v.Total), ("Usuario", v => v.Usuario),
            ("Estado", v => v.Anulada ? "ANULADA: " + v.MotivoAnulacion : "Válida"));
}

/// <summary>Pantalla de cocina: comandas en cola, en preparación y listas.</summary>
[Authorize(Roles = Claves.Local)]
public class CocinaController : Controller
{
    private readonly CN_Venta _negocio = new();
    public IActionResult Index() => View();

    [HttpGet] public JsonResult Listar() => Json(_negocio.Cocina(User.IdSede()));

    [HttpPost]
    public JsonResult Estado(int id, string estado) => Json(_negocio.EstadoCocina(User.IdSede(), id, estado));
}

public class DomicilioController : Controller
{
    private readonly CN_Venta _negocio = new();
    public IActionResult Index() => View();

    [HttpGet]
    public JsonResult Listar(bool soloPendientes = true) => Json(_negocio.Domicilios(User.IdSede(), soloPendientes));

    [HttpPost]
    public JsonResult Estado(int id, string estado, string? repartidor) => Json(_negocio.CambiarEstado(User.IdSede(), id, estado, repartidor));

    [HttpGet] public JsonResult Repartidores() => Json(_negocio.Repartidores(User.IdSede()));
}

[Authorize(Roles = Claves.Local)]
public class CajaController : Controller
{
    private readonly CN_Caja _negocio = new();
    public IActionResult Index() => View();

    [HttpGet] public JsonResult Movimientos(int idCaja) => Json(new CN_ControlOperacion().Movimientos(User.IdSede(), idCaja));
    [HttpPost] public JsonResult RegistrarMovimiento([FromBody] MovimientoCaja obj) => Json(new CN_ControlOperacion().Registrar(User.IdSede(),User.Id(),User.EsAdmin(),obj));
    [HttpPost, Authorize(Roles=Claves.Admin)] public JsonResult EditarMovimiento([FromBody] MovimientoCaja obj) => Json(new CN_ControlOperacion().Editar(User.IdSede(),User.Id(),obj));
    [HttpPost, Authorize(Roles=Claves.Admin)] public JsonResult AnularMovimiento(int id,string? motivo) => Json(new CN_ControlOperacion().Anular(User.IdSede(),User.Id(),id,motivo));
    [HttpGet] public JsonResult Actual() => Json(_negocio.Actual(User.IdSede()));
    [HttpGet] public JsonResult Historial() => Json(_negocio.Historial(User.IdSede()));
    [HttpPost] public JsonResult Abrir(decimal baseInicial, decimal fondoNegocio = 0) => Json(_negocio.Abrir(User.IdSede(), User.Id(), baseInicial, fondoNegocio));
    // Yesenia Quejada Rojas - Claude — 04/11/2026: corregir la base de caja de la caja abierta; solo el administrador (igual que editar movimientos).
    [HttpPost, Authorize(Roles=Claves.Admin)] public JsonResult EditarBase(decimal baseInicial) => Json(_negocio.EditarBase(User.IdSede(), User.Id(), baseInicial));
    [HttpGet] public JsonResult FondoSugerido() => Json(_negocio.FondoSugerido(User.IdSede()));

    // Yesenia Quejada Rojas - Claude — 11/11/2026: cajas de empaque para contarlas al cerrar (cajero y administrador). Lo contado se guarda como conteo de inventario.
    [HttpGet] public JsonResult CajasEmpaque() => Json(_negocio.CajasEmpaque(User.IdSede()).Select(i => new { i.IdInsumo, i.Nombre, i.Stock, i.UnidadMedida }));
    [HttpPost] public JsonResult ContarCajas([FromBody] List<ConteoItem> detalle) => Json(_negocio.ContarCajas(User.IdSede(), User.Id(), detalle));

    [HttpPost]
    public JsonResult Cerrar(decimal efectivoContado, string? observacion) =>
        Json(_negocio.Cerrar(User.IdSede(), User.Id(), efectivoContado, observacion));

    /// <summary>Reporte de cierre para imprimir en la impresora de tickets.</summary>
    public IActionResult Reporte(int id)
    {
        var r = _negocio.Reporte(User.IdSede(), id);
        return r == null ? NotFound() : View(r);
    }
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

    // Yesenia Quejada Rojas - Claude — 11/11/2026: insumos quitados de la lista de compras (p. ej. la bolsa ziploc) y botón para quitar o volver a incluir.
    [HttpGet] public JsonResult FueraDeLista() => Json(_negocio.FueraDeLista());
    [HttpPost] public JsonResult CambiarEnLista(int idInsumo, bool fuera) => Json(_negocio.CambiarEnLista(idInsumo, fuera));

    // Yesenia Quejada Rojas - Claude — 11/11/2026: lista de compras en tirilla para la impresora térmica. Por GET sale la lista sugerida
    // completa; por POST llegan los insumos marcados en pantalla con la cantidad que dejó el administrador ({ "idInsumo": cantidad }).
    [HttpGet]
    public IActionResult Tirilla() => VistaTirilla(null);

    [HttpPost, ActionName("Tirilla")]
    public IActionResult TirillaMarcada([FromForm] string datos)
    {
        Dictionary<int, decimal>? cantidades;
        try { cantidades = System.Text.Json.JsonSerializer.Deserialize<Dictionary<int, decimal>>(datos ?? ""); }
        catch (System.Text.Json.JsonException) { return BadRequest(); }
        if (cantidades == null || cantidades.Count > 500 || cantidades.Values.Any(c => c < 0 || c > 999999)) return BadRequest();
        return VistaTirilla(cantidades);
    }

    private IActionResult VistaTirilla(Dictionary<int, decimal>? cantidades) => View("Tirilla", new TirillaCompra
    {
        Items = _negocio.ParaTirilla(User.IdSede(), cantidades),
        Configuracion = new CN_Configuracion().Obtener(),
        Fecha = DateTime.UtcNow.AddHours(-5).ToString("dd/MM/yyyy h:mm tt", new System.Globalization.CultureInfo("es-CO")),
        Sede = User.Sede(),
        Usuario = User.Identity?.Name ?? ""
    });

    [HttpGet]
    public IActionResult Exportar() =>
        Excel.Archivo("orden-compra-" + User.Sede(), "Orden de compra", _negocio.Sugerida(User.IdSede()),
            ("Proveedor", o => o.Proveedor), ("Teléfono", o => o.TelefonoProveedor), ("Código", o => o.Codigo),
            ("Insumo", o => o.Nombre), ("Unidad", o => o.UnidadMedida), ("Stock", o => o.Stock), ("Mínimo", o => o.StockMinimo),
            ("Se gasta al día", o => o.ConsumoDia),
            ("Cantidad a pedir", o => o.CantidadSugerida), ("Costo unitario", o => o.CostoUnitario), ("Costo estimado", o => o.CostoEstimado));
}

[Authorize(Roles = Claves.Admin)]
public class ReporteController : Controller
{
    public IActionResult Index() => View();

    [HttpGet]
    public JsonResult Datos(DateTime inicio, DateTime fin) => Json(new CN_Reporte().Obtener(User.IdSede(), inicio, fin));

    // Yesenia Quejada Rojas - Claude — 19/10/2026: reemplaza "Auditoría y verificación" por quién hizo qué y cuándo.
    public IActionResult Actividad() => View();

    [HttpGet]
    public JsonResult ListarActividad(DateTime inicio, DateTime fin) => Json(new CN_Reporte().Actividad(User.IdSede(), inicio, fin));
}
