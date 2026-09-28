namespace CapaEntidad
{
    public class Configuracion
    {
        public string NombreNegocio { get; set; } = "Mi Negocio";
        public string? Nit { get; set; }
        public string? Direccion { get; set; }
        public string? Telefono { get; set; }
        public string ColorPrimario { get; set; } = "#C8322B";
        public string ColorSecundario { get; set; } = "#1F1A17";
        public string? LogoUrl { get; set; }
        public string SimboloMoneda { get; set; } = "$";
        public string? MensajeTicket { get; set; }
        public int DiasAlertaVencimiento { get; set; } = 3;
    }

    public class Sede
    {
        public int IdSede { get; set; }
        public string Nombre { get; set; } = "";
        public string? Direccion { get; set; }
        public string? Telefono { get; set; }
        public bool Activo { get; set; } = true;
    }

    public class Rol
    {
        public int IdRol { get; set; }
        public string Descripcion { get; set; } = "";
    }

    public class Usuario
    {
        public int IdUsuario { get; set; }
        public string NombreCompleto { get; set; } = "";
        public string NombreUsuario { get; set; } = "";
        public string Clave { get; set; } = "";
        public int IdRol { get; set; }
        public string Rol { get; set; } = "";
        public int IdSede { get; set; }
        public string Sede { get; set; } = "";
        public bool Activo { get; set; } = true;
    }

    public class Categoria
    {
        public int IdCategoria { get; set; }
        public string Descripcion { get; set; } = "";
        public bool Activo { get; set; } = true;
    }

    public class Proveedor
    {
        public int IdProveedor { get; set; }
        public string Documento { get; set; } = "";
        public string RazonSocial { get; set; } = "";
        public string? Telefono { get; set; }
        public string? Correo { get; set; }
        public bool Activo { get; set; } = true;
    }

    public class Insumo
    {
        public int IdInsumo { get; set; }
        public string Codigo { get; set; } = "";
        public string Nombre { get; set; } = "";
        public int IdCategoria { get; set; }
        public string Categoria { get; set; } = "";
        public string UnidadMedida { get; set; } = "UND";
        public decimal Stock { get; set; }
        public decimal StockMinimo { get; set; }
        public decimal CostoUnitario { get; set; }
        public bool Activo { get; set; } = true;
        public string ProximoVencimiento { get; set; } = "";
    }

    public class Movimiento
    {
        public int IdMovimiento { get; set; }
        public int IdSede { get; set; }
        public int IdInsumo { get; set; }
        public string Insumo { get; set; } = "";
        public string UnidadMedida { get; set; } = "";
        public string Tipo { get; set; } = "";
        public decimal Cantidad { get; set; }
        public decimal CostoUnitario { get; set; }
        public decimal StockAnterior { get; set; }
        public decimal StockNuevo { get; set; }
        public int IdProveedor { get; set; }
        public string Proveedor { get; set; } = "";
        public DateTime? FechaVencimiento { get; set; }
        public string? Observacion { get; set; }
        public int IdUsuario { get; set; }
        public string Usuario { get; set; } = "";
        public string Fecha { get; set; } = "";
    }

    public class ConteoItem
    {
        public int IdInsumo { get; set; }
        public decimal StockContado { get; set; }
    }

    public class Conteo
    {
        public int IdConteo { get; set; }
        public string Fecha { get; set; } = "";
        public string Usuario { get; set; } = "";
        public string? Observacion { get; set; }
        public int Insumos { get; set; }
        public int ConDiferencia { get; set; }
        public decimal ValorDiferencia { get; set; }
        public List<ConteoItem> Detalle { get; set; } = new();
    }

    public class CategoriaMenu
    {
        public int IdCategoriaMenu { get; set; }
        public string Nombre { get; set; } = "";
        public string Icono { get; set; } = "🍽️";
        public int Orden { get; set; }
        public bool Activo { get; set; } = true;
    }

    public class RecetaItem
    {
        public int IdInsumo { get; set; }
        public string Insumo { get; set; } = "";
        public string UnidadMedida { get; set; } = "";
        public decimal Cantidad { get; set; }
        public decimal CostoUnitario { get; set; }
    }

    public class ProductoMenu
    {
        public int IdProducto { get; set; }
        public string Nombre { get; set; } = "";
        public string? Descripcion { get; set; }
        public int IdCategoriaMenu { get; set; }
        public string CategoriaMenu { get; set; } = "";
        public string Icono { get; set; } = "";
        public decimal Precio { get; set; }
        public string ImagenUrl { get; set; } = "";
        public bool Activo { get; set; } = true;
        public int TotalInsumos { get; set; }
        public decimal Costo { get; set; }
        public List<RecetaItem> Receta { get; set; } = new();
        public List<int> Modificadores { get; set; } = new();
    }

    public class Modificador
    {
        public int IdModificador { get; set; }
        public string Nombre { get; set; } = "";
        public decimal Precio { get; set; }
        public int IdInsumo { get; set; }
        public string Insumo { get; set; } = "";
        public string UnidadMedida { get; set; } = "";
        public decimal Cantidad { get; set; }
        public bool Activo { get; set; } = true;
    }

    public class ProductoModificador
    {
        public int IdProducto { get; set; }
        public int IdModificador { get; set; }
        public string Nombre { get; set; } = "";
        public decimal Precio { get; set; }
    }

    public class CatalogoPos
    {
        public List<ProductoMenu> Productos { get; set; } = new();
        public List<ProductoModificador> Modificadores { get; set; } = new();
    }

    public class LineaVenta
    {
        public int IdProducto { get; set; }
        public int Cantidad { get; set; }
        public string? Notas { get; set; }
        public List<int> Modificadores { get; set; } = new();
    }

    public class NuevaVenta
    {
        public string TipoPedido { get; set; } = "MESA";
        public string? ClienteNombre { get; set; }
        public string? ClienteTelefono { get; set; }
        public string? Direccion { get; set; }
        public decimal CostoDomicilio { get; set; }
        public string MetodoPago { get; set; } = "EFECTIVO";
        public decimal MontoRecibido { get; set; }
        public List<LineaVenta> Lineas { get; set; } = new();
    }

    public class Venta
    {
        public int IdVenta { get; set; }
        public string Fecha { get; set; } = "";
        public string TipoPedido { get; set; } = "";
        public string MetodoPago { get; set; } = "";
        public decimal Subtotal { get; set; }
        public decimal CostoDomicilio { get; set; }
        public decimal Total { get; set; }
        public decimal MontoRecibido { get; set; }
        public decimal Cambio { get; set; }
        public string EstadoPedido { get; set; } = "";
        public string ClienteNombre { get; set; } = "";
        public string ClienteTelefono { get; set; } = "";
        public string Direccion { get; set; } = "";
        public string Usuario { get; set; } = "";
        public string Sede { get; set; } = "";
        public string SedeDireccion { get; set; } = "";
        public string Detalle { get; set; } = "";
        public int Minutos { get; set; }
    }

    public class TicketLinea
    {
        public int IdDetalle { get; set; }
        public string Nombre { get; set; } = "";
        public int Cantidad { get; set; }
        public decimal PrecioUnitario { get; set; }
        public decimal Subtotal { get; set; }
        public string Notas { get; set; } = "";
        public List<string> Adiciones { get; set; } = new();
    }

    public class Ticket
    {
        public Venta Venta { get; set; } = new();
        public List<TicketLinea> Lineas { get; set; } = new();
        public Configuracion Configuracion { get; set; } = new();
    }

    public class Caja
    {
        public int IdCaja { get; set; }
        public string FechaApertura { get; set; } = "";
        public string FechaCierre { get; set; } = "";
        public decimal BaseInicial { get; set; }
        public string UsuarioApertura { get; set; } = "";
        public string UsuarioCierre { get; set; } = "";
        public decimal VentasEfectivo { get; set; }
        public decimal VentasTarjeta { get; set; }
        public decimal VentasTransferencia { get; set; }
        public int NumeroVentas { get; set; }
        public decimal EfectivoEsperado { get; set; }
        public decimal EfectivoContado { get; set; }
        public decimal Diferencia { get; set; }
        public string Observacion { get; set; } = "";
    }

    public class OrdenCompraItem
    {
        public int IdInsumo { get; set; }
        public string Codigo { get; set; } = "";
        public string Nombre { get; set; } = "";
        public string UnidadMedida { get; set; } = "";
        public decimal Stock { get; set; }
        public decimal StockMinimo { get; set; }
        public decimal CantidadSugerida { get; set; }
        public decimal CostoUnitario { get; set; }
        public decimal CostoEstimado { get; set; }
        public int IdProveedor { get; set; }
        public string Proveedor { get; set; } = "";
        public string TelefonoProveedor { get; set; } = "";
    }

    public class LoteAlerta
    {
        public int IdLote { get; set; }
        public string Nombre { get; set; } = "";
        public string UnidadMedida { get; set; } = "";
        public decimal CantidadDisponible { get; set; }
        public string FechaVencimiento { get; set; } = "";
        public int DiasRestantes { get; set; }
    }

    public class Dashboard
    {
        public int TotalInsumos { get; set; }
        public int InsumosBajoStock { get; set; }
        public decimal ValorInventario { get; set; }
        public decimal VentasHoy { get; set; }
        public int PedidosHoy { get; set; }
        public int DomiciliosPendientes { get; set; }
        public bool CajaAbierta { get; set; }
        public List<Insumo> Alertas { get; set; } = new();
        public List<LoteAlerta> Vencimientos { get; set; } = new();
    }

    public class PuntoReporte
    {
        public string Etiqueta { get; set; } = "";
        public int Cantidad { get; set; }
        public decimal Total { get; set; }
    }

    public class Reporte
    {
        public decimal Ventas { get; set; }
        public int Pedidos { get; set; }
        public decimal TicketPromedio { get; set; }
        public decimal VentasProductos { get; set; }
        public decimal CostoInsumos { get; set; }
        public decimal Ganancia { get; set; }
        public decimal Mermas { get; set; }
        public List<PuntoReporte> PorDia { get; set; } = new();
        public List<PuntoReporte> TopProductos { get; set; } = new();
        public List<PuntoReporte> PorMetodo { get; set; } = new();
    }

    /// <summary>Respuesta estándar de las operaciones de guardar/eliminar.</summary>
    public class Respuesta
    {
        public bool Resultado { get; set; }
        public int Id { get; set; }
        public string Mensaje { get; set; } = "";

        public static Respuesta Ok(int id = 0) => new() { Resultado = true, Id = id };
        public static Respuesta Error(string mensaje) => new() { Resultado = false, Mensaje = mensaje };
    }
}
