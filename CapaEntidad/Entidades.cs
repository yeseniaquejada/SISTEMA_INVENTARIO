namespace CapaEntidad
{
    public class Configuracion
    {
        public string NombreNegocio { get; set; } = "Mi Negocio";
        public string? Nit { get; set; }
        public string? Direccion { get; set; }
        public string? Telefono { get; set; }
        public string ColorPrimario { get; set; } = "#E53935";
        public string ColorSecundario { get; set; } = "#0B0B10";
        public string? LogoUrl { get; set; }
        public string SimboloMoneda { get; set; } = "$";
        public string? MensajeTicket { get; set; }
        public int DiasAlertaVencimiento { get; set; } = 3;
        public int MinutosEdicion { get; set; } = 5;
        public int MinutosAlertaCocina { get; set; } = 15;
        public int MinutosAlertaDomicilio { get; set; } = 40;
        public decimal CostoDomicilio { get; set; }
        public bool MostrarCocina { get; set; } = true;
        public bool MostrarDomicilios { get; set; } = true;
        public bool MostrarMultisede { get; set; } = true;
        public bool MostrarAvanzado { get; set; } = true;
        public int AnchoTicket { get; set; } = 80;
        // Yesenia Quejada Rojas - Claude — 29/10/2026: ancho que de verdad imprime la cabeza térmica. En 58 mm (p. ej. Digital POS
        // DIG-C58) son 48 mm y en 80 mm son 72 mm; con el ancho del papel el ticket se cortaba por la derecha.
        // Yesenia Quejada Rojas - Claude — 30/10/2026: con 48 mm la DIG-C58 cortaba un poco a la derecha (el driver deja un margen);
        // se usan 45 mm (y 70 mm en 80 mm) para que quepa completo.
        // Yesenia Quejada Rojas - Claude — 30/10/2026: con 45 mm aún se cortaba el último 0 de los precios; se bajan a 42 mm.
        public int AreaImpresion => AnchoTicket == 58 ? 42 : 70;
        /// <summary>Letra del ticket en px: más pequeña en 58 mm para que quepan ~32 caracteres por línea.</summary>
        // Yesenia Quejada Rojas - Claude — 30/10/2026: un punto más grande (12 y 13 px) porque se leía muy pequeña.
        public int LetraTicket => AnchoTicket == 58 ? 12 : 13;
        public bool ImprimirAutomatico { get; set; } = true;
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
        /// <summary>Lo que falta confirmar de este insumo con el cliente; vacío = todo confirmado.</summary>
        public string PorConfirmar { get; set; } = "";
        // Yesenia Quejada Rojas - Claude — 28/10/2026: solo para unidad PAQ; cuántas unidades trae el paquete (las recetas descuentan fracción).
        public decimal? UnidadesPorPaquete { get; set; }
        /// <summary>Si es falso no se descuenta al vender ni bloquea la venta (porciones preparadas).</summary>
        public bool ControlaStock { get; set; } = true;
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
        /// <summary>Costos por unidad corregidos al contar (Yesenia Quejada Rojas - Claude — 28/10/2026).</summary>
        public List<CostoInsumo> Costos { get; set; } = new();
    }

    public class CostoInsumo
    {
        public int IdInsumo { get; set; }
        public decimal CostoUnitario { get; set; }
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
        // Yesenia Quejada Rojas - Claude — 02/11/2026: false = el producto solo sale en Vender; la carta pública (QR) no lo muestra ni deja pedirlo.
        public bool EnCarta { get; set; } = true;
        public int TotalInsumos { get; set; }
        public decimal Costo { get; set; }
        public List<RecetaItem> Receta { get; set; } = new();
        public List<int> Modificadores { get; set; } = new();
        /// <summary>Unidades vendidas en los últimos 30 días (para ordenar el punto de venta).</summary>
        public int Vendidos { get; set; }
        /// <summary>Unidades que alcanzan a salir con el stock actual; null si no tiene receta.</summary>
        public int? Disponibles { get; set; }
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
        /// <summary>Adiciones, Salsas, Preferencias... agrupa las opciones en la pantalla de venta.</summary>
        public string Grupo { get; set; } = "Adiciones";
    }

    public class ProductoModificador
    {
        public int IdProducto { get; set; }
        public int IdModificador { get; set; }
        public string Nombre { get; set; } = "";
        public decimal Precio { get; set; }
        public string Grupo { get; set; } = "Adiciones";
    }

    public class CatalogoPos
    {
        public List<ProductoMenu> Productos { get; set; } = new();
        public List<ProductoModificador> Modificadores { get; set; } = new();
        // Yesenia Quejada Rojas - Claude — 19/10/2026: ingredientes de la receta para ofrecer "Sin ..." al vender.
        public List<IngredienteReceta> Ingredientes { get; set; } = new();
    }

    public class IngredienteReceta
    {
        public int IdProducto { get; set; }
        public int IdInsumo { get; set; }
        public string Nombre { get; set; } = "";
    }

    public class LineaVenta
    {
        public int IdProducto { get; set; }
        public int Cantidad { get; set; }
        public string? Notas { get; set; }
        public List<int> Modificadores { get; set; } = new();
        // Yesenia Quejada Rojas - Claude — 19/10/2026: insumos de la receta que el cliente pidió quitar; no se descuentan.
        public List<int> Quitados { get; set; } = new();
    }

    public class NuevaVenta
    {
        /// <summary>0 = venta nueva; mayor a 0 = editar ese pedido (si aún está dentro del tiempo permitido).</summary>
        public int IdVenta { get; set; }
        public string TipoPedido { get; set; } = "MESA";
        public string? ClienteNombre { get; set; }
        public string? ClienteTelefono { get; set; }
        public string? Direccion { get; set; }
        public decimal CostoDomicilio { get; set; }
        public string MetodoPago { get; set; } = "EFECTIVO";
        public decimal MontoRecibido { get; set; }
        // Yesenia Quejada Rojas - Claude — 31/10/2026: cajas de empaque que lleva el pedido (0 a 99); al cerrar la caja se cuentan como "cajas gastadas".
        public int Cajas { get; set; }
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
        public bool Anulada { get; set; }
        public string MotivoAnulacion { get; set; } = "";
        public string EstadoCocina { get; set; } = "";
        /// <summary>Segundos que quedan para editar o anular el pedido (0 = ya no se puede).</summary>
        public int SegundosEdicion { get; set; }
        public bool CajaAbierta { get; set; }
        public string Repartidor { get; set; } = "";
        public int MinutosEnCamino { get; set; }
        public string HoraDespacho { get; set; } = "";
        public string HoraEntrega { get; set; } = "";
        // Yesenia Quejada Rojas - Claude — 30/10/2026: el pago de Rappi ya entró a la cuenta.
        public bool PagoConfirmado { get; set; }
        public string FechaPagoConfirmado { get; set; } = "";
        // Yesenia Quejada Rojas - Claude — 31/10/2026: cajas de empaque del pedido.
        public int Cajas { get; set; }
    }

    /// <summary>Pedido en la pantalla de cocina.</summary>
    public class Comanda
    {
        public int IdVenta { get; set; }
        public string Fecha { get; set; } = "";
        public string TipoPedido { get; set; } = "";
        public string ClienteNombre { get; set; } = "";
        public string EstadoCocina { get; set; } = "";
        public string EstadoPedido { get; set; } = "";
        public int Segundos { get; set; }
        public int SegundosEdicion { get; set; }
        public decimal Total { get; set; }
        public bool Editada { get; set; }
        public List<TicketLinea> Lineas { get; set; } = new();
    }

    public class ClienteFrecuente
    {
        public string ClienteNombre { get; set; } = "";
        public string Direccion { get; set; } = "";
        public int Pedidos { get; set; }
        public string UltimoPedido { get; set; } = "";
    }

    public class TicketLinea
    {
        public int IdDetalle { get; set; }
        public int IdProducto { get; set; }
        public string Nombre { get; set; } = "";
        public int Cantidad { get; set; }
        public decimal PrecioUnitario { get; set; }
        public decimal Subtotal { get; set; }
        public string Notas { get; set; } = "";
        public List<string> Adiciones { get; set; } = new();
        public List<int> Modificadores { get; set; } = new();
        // Yesenia Quejada Rojas - Claude — 19/10/2026: "Sin lechuga"... se muestran aparte para que cocina no los pase por alto.
        public List<string> SinIngredientes { get; set; } = new();
        public List<int> Quitados { get; set; } = new();
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
        // Yesenia Quejada Rojas - Claude — 30/10/2026: pagadas en la app de Rappi; no entran al efectivo esperado.
        public decimal VentasRappi { get; set; }
        // Yesenia Quejada Rojas - Claude — 31/10/2026: saldo del negocio (efectivo + tarjeta + transferencias + Rappi − gastos);
        // la base de cada caja es el saldo de la anterior. El efectivo del cajón sigue en EfectivoEsperado.
        public decimal BaseNegocio { get; set; }
        public decimal SaldoNegocio { get; set; }
        public decimal VentasTotal { get; set; }
        public decimal GastosTotal { get; set; }
        // Yesenia Quejada Rojas - Claude — 31/10/2026: cajas de empaque gastadas en esta caja; cada una vale lo que cuesta el insumo "Caja de empaque".
        // Es informativo: no se descuenta del saldo.
        public int Cajas { get; set; }
        public decimal CostoCaja { get; set; }
        public decimal TotalCajas => Cajas * CostoCaja;
        public int NumeroVentas { get; set; }
        public decimal EfectivoEsperado { get; set; }
        public decimal IngresosEfectivo { get; set; }
        public decimal EgresosEfectivo { get; set; }
        public decimal EfectivoContado { get; set; }
        public decimal Diferencia { get; set; }
        public string Observacion { get; set; } = "";
        public int NumeroAnuladas { get; set; }
        public decimal TotalAnulado { get; set; }
        /// <summary>Efectivo de domicilios que aún no han vuelto (lo tiene el repartidor).</summary>
        public decimal EfectivoEnDomicilios { get; set; }
        public decimal Domicilios { get; set; }
        // Yesenia Quejada Rojas - Claude — 28/10/2026: fondo del negocio (plata para compras y pagos), aparte del efectivo del cajón.
        public decimal FondoNegocio { get; set; }
        public decimal IngresosFondo { get; set; }
        public decimal EgresosFondo { get; set; }
        public decimal FondoDisponible => FondoNegocio + IngresosFondo - EgresosFondo;
        public string Estado { get; set; } = "";
        public string Sede { get; set; } = "";
    }

    /// <summary>Reporte de cierre de caja (resumen, productos vendidos y anulaciones).</summary>
    public class ReporteCaja
    {
        public List<MovimientoCaja> Movimientos { get; set; } = new();
        public Caja Caja { get; set; } = new();
        public List<PuntoReporte> Productos { get; set; } = new();
        public List<Venta> Anuladas { get; set; } = new();
        public Configuracion Configuracion { get; set; } = new();
    }

    /// <summary>Una fila de la plantilla de Excel para cargar insumos y stock.</summary>
    public class FilaImportacion
    {
        public int Fila { get; set; }
        public string Codigo { get; set; } = "";
        public string Nombre { get; set; } = "";
        public string UnidadMedida { get; set; } = "";
        public decimal StockMinimo { get; set; }
        public decimal CostoUnitario { get; set; }
        /// <summary>Stock real contado; null = no cambiar el stock.</summary>
        public decimal? Stock { get; set; }
        /// <summary>Dato por confirmar; null = la plantilla no trae la columna y no se cambia.</summary>
        public string? PorConfirmar { get; set; }
    }

    public class ResultadoImportacion
    {
        public bool Resultado { get; set; }
        public int Creados { get; set; }
        public int Actualizados { get; set; }
        public int StockAjustado { get; set; }
        public int CategoriasNuevas { get; set; }
        public List<string> Errores { get; set; } = new();
    }

    public class OrdenCompraItem
    {
        public int IdInsumo { get; set; }
        public string Codigo { get; set; } = "";
        public string Nombre { get; set; } = "";
        public string UnidadMedida { get; set; } = "";
        public decimal Stock { get; set; }
        public decimal StockMinimo { get; set; }
        public decimal ConsumoDia { get; set; }
        public decimal CantidadSugerida { get; set; }
        public decimal CostoUnitario { get; set; }
        public decimal CostoEstimado { get; set; }
        public int IdProveedor { get; set; }
        public string Proveedor { get; set; } = "";
        public string TelefonoProveedor { get; set; } = "";
    }

    // Yesenia Quejada Rojas - Claude — 11/11/2026: insumo que el administrador quitó de "Qué debo comprar" (p. ej. la bolsa ziploc).
    public class InsumoFueraCompra
    {
        public int IdInsumo { get; set; }
        public string Codigo { get; set; } = "";
        public string Nombre { get; set; } = "";
    }

    // Yesenia Quejada Rojas - Claude — 11/11/2026: lista de compras para imprimir en tirilla (impresora térmica).
    public class TirillaCompra
    {
        public List<OrdenCompraItem> Items { get; set; } = new();
        public Configuracion Configuracion { get; set; } = new();
        public string Fecha { get; set; } = "";
        public string Sede { get; set; } = "";
        public string Usuario { get; set; } = "";
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
        // Yesenia Quejada Rojas - Claude — 31/10/2026: cajas de empaque gastadas en el periodo y lo que valen (informativo, no resta de la ganancia).
        public int Cajas { get; set; }
        public decimal CostoCaja { get; set; }
        public decimal TotalCajas => Cajas * CostoCaja;
        public List<PuntoReporte> PorDia { get; set; } = new();
        public List<PuntoReporte> TopProductos { get; set; } = new();
        // Yesenia Quejada Rojas - Claude — 19/10/2026: productos que menos salen, para decidir qué promocionar o retirar.
        public List<PuntoReporte> MenosVendidos { get; set; } = new();
        public List<PuntoReporte> PorMetodo { get; set; } = new();
    }

    /// <summary>Un hecho del día contado en lenguaje sencillo (quién abrió la caja, registró un gasto, anuló un pedido...).</summary>
    public class Actividad
    {
        public string Fecha { get; set; } = "";
        public string Usuario { get; set; } = "";
        public string Tipo { get; set; } = "";
        public string Descripcion { get; set; } = "";
        public decimal? Monto { get; set; }
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
