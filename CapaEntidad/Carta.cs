namespace CapaEntidad;

// Yesenia Quejada Rojas - Claude — 28/10/2026: mesas del local y carta digital pública (lo que ve el cliente al escanear el QR).
public class Mesa
{
    public int IdMesa { get; set; }
    public string Nombre { get; set; } = "";
    public int Puestos { get; set; } = 4;
    public bool Activo { get; set; } = true;
}

public class CartaPublica
{
    public Configuracion Configuracion { get; set; } = new();
    /// <summary>Sede de la carta (Yesenia Quejada Rojas - Claude — 13/11/2026: la necesitan los pedidos sin mesa).</summary>
    public int IdSede { get; set; }
    public string Sede { get; set; } = "";
    public string Direccion { get; set; } = "";
    public string Telefono { get; set; } = "";
    public string Mesa { get; set; } = "";
    /// <summary>Mesa del QR (0 si la carta se abrió sin mesa): solo con mesa se puede pedir desde el carrito.</summary>
    public int IdMesa { get; set; }
    public List<CartaProducto> Productos { get; set; } = new();
    public List<CartaAdicion> Adiciones { get; set; } = new();
    // Yesenia Quejada Rojas - Claude — 29/10/2026: salsas, adiciones y "Sin ..." de cada producto para elegirlos desde la carta.
    public List<CartaOpcion> Opciones { get; set; } = new();
    public List<CartaIngrediente> Ingredientes { get; set; } = new();
}

public class CartaOpcion
{
    public int IdProducto { get; set; }
    public int IdModificador { get; set; }
    public string Nombre { get; set; } = "";
    public decimal Precio { get; set; }
    public string Grupo { get; set; } = "";
}

public class CartaIngrediente
{
    public int IdProducto { get; set; }
    public int IdInsumo { get; set; }
    public string Nombre { get; set; } = "";
}

public class CartaProducto
{
    public int IdProducto { get; set; }
    public string Nombre { get; set; } = "";
    public string Descripcion { get; set; } = "";
    public int IdCategoriaMenu { get; set; }
    public string CategoriaMenu { get; set; } = "";
    public string Icono { get; set; } = "";
    public decimal Precio { get; set; }
    public string ImagenUrl { get; set; } = "";
    public bool Agotado { get; set; }
}

public class CartaAdicion
{
    public string Grupo { get; set; } = "";
    public string Nombre { get; set; } = "";
    public decimal Precio { get; set; }
}

// Yesenia Quejada Rojas - Claude — 29/10/2026: carrito de la carta digital. El cliente lo envía desde el QR de su mesa y queda
// en espera hasta que el personal lo revisa en Vender.
public class PedidoCartaNuevo
{
    public int IdMesa { get; set; }
    // Yesenia Quejada Rojas - Claude — 13/11/2026: también para llevar y a domicilio (sin mesa: la sede viene de la carta).
    public int IdSede { get; set; }
    public string? TipoPedido { get; set; }
    public string? Telefono { get; set; }
    public string? Direccion { get; set; }
    public string? ClienteNombre { get; set; }
    public string? Nota { get; set; }
    public List<PedidoCartaLinea> Lineas { get; set; } = new();
}

public class PedidoCartaLinea
{
    public int Linea { get; set; }
    public int IdProducto { get; set; }
    public string Nombre { get; set; } = "";
    public int Cantidad { get; set; }
    public decimal PrecioUnitario { get; set; }
    public string? Notas { get; set; }
    /// <summary>Salsas y adiciones (IdModificador) e ingredientes que se quitan (IdInsumo).</summary>
    public List<int> Modificadores { get; set; } = new();
    public List<int> Quitados { get; set; } = new();
    /// <summary>Para mostrar en Vender: "Con: BBQ · Sin: cebolla".</summary>
    public string Opciones { get; set; } = "";
}

public class PedidoCarta
{
    public int IdPedidoCarta { get; set; }
    public string Mesa { get; set; } = "";
    public string ClienteNombre { get; set; } = "";
    public string Nota { get; set; } = "";
    /// <summary>MESA, LLEVAR o DOMICILIO (Yesenia Quejada Rojas - Claude — 13/11/2026).</summary>
    public string TipoPedido { get; set; } = "MESA";
    public string Telefono { get; set; } = "";
    public string Direccion { get; set; } = "";
    public decimal Total { get; set; }
    public string Estado { get; set; } = "";
    public int Segundos { get; set; }
    public List<PedidoCartaLinea> Lineas { get; set; } = new();
}

/// <summary>Respuesta al cliente: número del pedido y el código con el que consulta si ya lo confirmaron.</summary>
public class PedidoCartaEnviado
{
    public bool Resultado { get; set; }
    public string Mensaje { get; set; } = "";
    public int Id { get; set; }
    public Guid? Codigo { get; set; }
    public string Estado { get; set; } = "";
}

/// <summary>Pedido apartado con "Cobrar después". Se guarda en la base de datos para verlo desde cualquier equipo de la sede.</summary>
// Yesenia Quejada Rojas - Claude — 30/10/2026: antes vivía en el navegador; lo apartado en la tablet no se veía en el computador.
public class PedidoEspera
{
    public int IdPedidoEspera { get; set; }
    public string Nombre { get; set; } = "";
    public string TipoPedido { get; set; } = "";
    /// <summary>JSON con las líneas y los datos del cliente tal como estaban en pantalla.</summary>
    public string Datos { get; set; } = "";
    public int Minutos { get; set; }
    public string Usuario { get; set; } = "";
}
