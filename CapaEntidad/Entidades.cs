namespace CapaEntidad
{
    public class Usuario
    {
        public int IdUsuario { get; set; }
        public string NombreCompleto { get; set; } = "";
        public string NombreUsuario { get; set; } = "";
        public string Clave { get; set; } = "";
        public int IdRol { get; set; }
        public string Rol { get; set; } = "";
        public bool Activo { get; set; }
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
    }

    public class Movimiento
    {
        public int IdMovimiento { get; set; }
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
        public string? Observacion { get; set; }
        public int IdUsuario { get; set; }
        public string Usuario { get; set; } = "";
        public string Fecha { get; set; } = "";
    }

    public class RecetaItem
    {
        public int IdInsumo { get; set; }
        public string Insumo { get; set; } = "";
        public string UnidadMedida { get; set; } = "";
        public decimal Cantidad { get; set; }
    }

    public class ProductoMenu
    {
        public int IdProducto { get; set; }
        public string Nombre { get; set; } = "";
        public decimal Precio { get; set; }
        public bool Activo { get; set; } = true;
        public int TotalInsumos { get; set; }
        public List<RecetaItem> Receta { get; set; } = new();
    }

    public class DetalleVenta
    {
        public int IdProducto { get; set; }
        public int Cantidad { get; set; }
    }

    public class Venta
    {
        public int IdVenta { get; set; }
        public string Fecha { get; set; } = "";
        public decimal Total { get; set; }
        public string Usuario { get; set; } = "";
        public string Detalle { get; set; } = "";
    }

    public class Dashboard
    {
        public int TotalInsumos { get; set; }
        public int InsumosBajoStock { get; set; }
        public decimal ValorInventario { get; set; }
        public decimal VentasHoy { get; set; }
        public int PedidosHoy { get; set; }
        public List<Insumo> Alertas { get; set; } = new();
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
