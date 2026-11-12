using CapaEntidad;
using CapaNegocio;
using CapaPresentacion.Infraestructura;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CapaPresentacion.Controllers;

// Yesenia Quejada Rojas - Claude — 28/10/2026: carta digital pública. Se abre sin iniciar sesión (desde el QR de la mesa o un enlace)
// y solo muestra datos de venta (nombre, descripción, precio, foto, agotado); no expone costos ni inventario.
[AllowAnonymous]
public class CartaController : Controller
{
    // Yesenia Quejada Rojas - Claude — 29/10/2026: sin caché de 30 s porque la página ahora lleva el token antifalsificación del carrito.
    [HttpGet]
    public IActionResult Index(int sede = 1, int? mesa = null)
    {
        var carta = new CN_Carta().Obtener(sede, mesa);
        if (carta == null) return NotFound();
        // Yesenia Quejada Rojas - Claude — 30/10/2026: con el enlace general (sin QR de mesa) el cliente elige su mesa al enviar el pedido.
        if (carta.IdMesa == 0)
            ViewBag.Mesas = new CN_Mesa().Listar(sede).Where(m => m.Activo).ToList();
        return View(carta);
    }

    // Yesenia Quejada Rojas - Claude — 31/10/2026: QR general de la carta (sin mesa) para que el mesero lo muestre; el cliente elige su mesa al enviar el pedido.
    // Es pública como la carta: solo muestra el enlace de la carta, nada del sistema.
    [HttpGet]
    public IActionResult Qr() => View();

    /// <summary>El cliente envía el carrito desde el QR de su mesa; queda en espera hasta que el personal lo confirme.</summary>
    [HttpPost]
    public JsonResult Pedir([FromBody] PedidoCartaNuevo pedido) => Json(new CN_PedidoCarta().Registrar(pedido));

    /// <summary>Estado del pedido para el celular del cliente (se consulta con el código aleatorio que recibió al enviarlo).</summary>
    [HttpGet]
    public JsonResult Estado(Guid codigo) => Json(new CN_PedidoCarta().Estado(codigo));
}

/// <summary>Mesas del local y sus códigos QR para la carta.</summary>
[Authorize(Roles = Claves.Admin)]
public class MesaController : Controller
{
    private readonly CN_Mesa _negocio = new();
    public IActionResult Index() => View();
    [HttpGet] public JsonResult Listar() => Json(_negocio.Listar(User.IdSede()));
    [HttpPost] public JsonResult Guardar([FromBody] Mesa obj) => Json(_negocio.Guardar(User.IdSede(), obj));
    // Yesenia Quejada Rojas - Claude — 29/10/2026: las mesas no se eliminan (solo se desactivan) para que el QR impreso siga sirviendo.
}
