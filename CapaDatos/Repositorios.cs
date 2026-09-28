using System.Data;
using CapaEntidad;
using Microsoft.Data.SqlClient;
using static CapaDatos.Conexion;

namespace CapaDatos
{
    public class CD_Usuario
    {
        public Usuario? Obtener(string usuario) =>
            Listar("SP_USUARIO_OBTENER", dr => new Usuario
            {
                IdUsuario = dr.Entero("IdUsuario"),
                NombreCompleto = dr.Texto("NombreCompleto"),
                NombreUsuario = dr.Texto("Usuario"),
                Clave = dr.Texto("Clave"),
                IdRol = dr.Entero("IdRol"),
                Rol = dr.Texto("Rol"),
                Activo = dr.Bool("Activo")
            }, P("@Usuario", usuario)).FirstOrDefault();
    }

    public class CD_Categoria
    {
        public List<Categoria> Listar() =>
            Conexion.Listar("SP_CATEGORIA_LISTAR", dr => new Categoria
            {
                IdCategoria = dr.Entero("IdCategoria"),
                Descripcion = dr.Texto("Descripcion"),
                Activo = dr.Bool("Activo")
            });

        public Respuesta Guardar(Categoria c) =>
            Ejecutar("SP_CATEGORIA_GUARDAR", P("@IdCategoria", c.IdCategoria), P("@Descripcion", c.Descripcion), P("@Activo", c.Activo));

        public Respuesta Eliminar(int id) => Ejecutar("SP_CATEGORIA_ELIMINAR", P("@IdCategoria", id));
    }

    public class CD_Proveedor
    {
        public List<Proveedor> Listar() =>
            Conexion.Listar("SP_PROVEEDOR_LISTAR", dr => new Proveedor
            {
                IdProveedor = dr.Entero("IdProveedor"),
                Documento = dr.Texto("Documento"),
                RazonSocial = dr.Texto("RazonSocial"),
                Telefono = dr.Texto("Telefono"),
                Correo = dr.Texto("Correo"),
                Activo = dr.Bool("Activo")
            });

        public Respuesta Guardar(Proveedor p) =>
            Ejecutar("SP_PROVEEDOR_GUARDAR", P("@IdProveedor", p.IdProveedor), P("@Documento", p.Documento),
                P("@RazonSocial", p.RazonSocial), P("@Telefono", p.Telefono), P("@Correo", p.Correo), P("@Activo", p.Activo));

        public Respuesta Eliminar(int id) => Ejecutar("SP_PROVEEDOR_ELIMINAR", P("@IdProveedor", id));
    }

    public class CD_Insumo
    {
        public List<Insumo> Listar() =>
            Conexion.Listar("SP_INSUMO_LISTAR", dr => new Insumo
            {
                IdInsumo = dr.Entero("IdInsumo"),
                Codigo = dr.Texto("Codigo"),
                Nombre = dr.Texto("Nombre"),
                IdCategoria = dr.Entero("IdCategoria"),
                Categoria = dr.Texto("Categoria"),
                UnidadMedida = dr.Texto("UnidadMedida"),
                Stock = dr.Decimal("Stock"),
                StockMinimo = dr.Decimal("StockMinimo"),
                CostoUnitario = dr.Decimal("CostoUnitario"),
                Activo = dr.Bool("Activo")
            });

        public Respuesta Guardar(Insumo i) =>
            Ejecutar("SP_INSUMO_GUARDAR", P("@IdInsumo", i.IdInsumo), P("@Codigo", i.Codigo), P("@Nombre", i.Nombre),
                P("@IdCategoria", i.IdCategoria), P("@UnidadMedida", i.UnidadMedida), P("@StockMinimo", i.StockMinimo),
                P("@CostoUnitario", i.CostoUnitario), P("@Activo", i.Activo));

        public Respuesta Eliminar(int id) => Ejecutar("SP_INSUMO_ELIMINAR", P("@IdInsumo", id));
    }

    public class CD_Movimiento
    {
        public Respuesta Registrar(Movimiento m) =>
            Ejecutar("SP_MOVIMIENTO_REGISTRAR", P("@IdInsumo", m.IdInsumo), P("@Tipo", m.Tipo), P("@Cantidad", m.Cantidad),
                P("@CostoUnitario", m.CostoUnitario), P("@IdProveedor", m.IdProveedor), P("@Observacion", m.Observacion),
                P("@IdUsuario", m.IdUsuario));

        public List<Movimiento> Listar(DateTime inicio, DateTime fin, int idInsumo) =>
            Conexion.Listar("SP_MOVIMIENTO_LISTAR", dr => new Movimiento
            {
                IdMovimiento = dr.Entero("IdMovimiento"),
                Fecha = dr.Texto("Fecha"),
                Insumo = dr.Texto("Insumo"),
                UnidadMedida = dr.Texto("UnidadMedida"),
                Tipo = dr.Texto("Tipo"),
                Cantidad = dr.Decimal("Cantidad"),
                CostoUnitario = dr.Decimal("CostoUnitario"),
                StockAnterior = dr.Decimal("StockAnterior"),
                StockNuevo = dr.Decimal("StockNuevo"),
                Proveedor = dr.Texto("Proveedor"),
                Observacion = dr.Texto("Observacion"),
                Usuario = dr.Texto("Usuario")
            }, P("@FechaInicio", inicio.Date), P("@FechaFin", fin.Date), P("@IdInsumo", idInsumo));
    }

    public class CD_Producto
    {
        public List<ProductoMenu> Listar() =>
            Conexion.Listar("SP_PRODUCTO_LISTAR", dr => new ProductoMenu
            {
                IdProducto = dr.Entero("IdProducto"),
                Nombre = dr.Texto("Nombre"),
                Precio = dr.Decimal("Precio"),
                Activo = dr.Bool("Activo"),
                TotalInsumos = dr.Entero("TotalInsumos")
            });

        public List<RecetaItem> ListarReceta(int idProducto) =>
            Conexion.Listar("SP_RECETA_LISTAR", dr => new RecetaItem
            {
                IdInsumo = dr.Entero("IdInsumo"),
                Insumo = dr.Texto("Insumo"),
                UnidadMedida = dr.Texto("UnidadMedida"),
                Cantidad = dr.Decimal("Cantidad")
            }, P("@IdProducto", idProducto));

        public Respuesta Guardar(ProductoMenu p)
        {
            var receta = new DataTable();
            receta.Columns.Add("IdInsumo", typeof(int));
            receta.Columns.Add("Cantidad", typeof(decimal));
            foreach (var r in p.Receta) receta.Rows.Add(r.IdInsumo, r.Cantidad);

            return Ejecutar("SP_PRODUCTO_GUARDAR", P("@IdProducto", p.IdProducto), P("@Nombre", p.Nombre),
                P("@Precio", p.Precio), P("@Activo", p.Activo), Tabla("@Receta", "EReceta", receta));
        }

        public Respuesta Eliminar(int id) => Ejecutar("SP_PRODUCTO_ELIMINAR", P("@IdProducto", id));
    }

    public class CD_Venta
    {
        public Respuesta Registrar(int idUsuario, List<DetalleVenta> detalle)
        {
            var tabla = new DataTable();
            tabla.Columns.Add("IdProducto", typeof(int));
            tabla.Columns.Add("Cantidad", typeof(int));
            foreach (var d in detalle) tabla.Rows.Add(d.IdProducto, d.Cantidad);

            return Ejecutar("SP_VENTA_REGISTRAR", P("@IdUsuario", idUsuario), Tabla("@Detalle", "EDetalleVenta", tabla));
        }

        public List<Venta> Listar(DateTime inicio, DateTime fin) =>
            Conexion.Listar("SP_VENTA_LISTAR", dr => new Venta
            {
                IdVenta = dr.Entero("IdVenta"),
                Fecha = dr.Texto("Fecha"),
                Total = dr.Decimal("Total"),
                Usuario = dr.Texto("Usuario"),
                Detalle = dr.Texto("Detalle")
            }, P("@FechaInicio", inicio.Date), P("@FechaFin", fin.Date));
    }

    public class CD_Dashboard
    {
        public Dashboard Obtener()
        {
            var d = new Dashboard();
            using var cn = Abrir();
            using var cmd = new SqlCommand("SP_DASHBOARD", cn) { CommandType = CommandType.StoredProcedure };
            using var dr = cmd.ExecuteReader();
            if (dr.Read())
            {
                d.TotalInsumos = dr.Entero("TotalInsumos");
                d.InsumosBajoStock = dr.Entero("InsumosBajoStock");
                d.ValorInventario = dr.Decimal("ValorInventario");
                d.VentasHoy = dr.Decimal("VentasHoy");
                d.PedidosHoy = dr.Entero("PedidosHoy");
            }
            dr.NextResult();
            while (dr.Read())
            {
                d.Alertas.Add(new Insumo
                {
                    IdInsumo = dr.Entero("IdInsumo"),
                    Codigo = dr.Texto("Codigo"),
                    Nombre = dr.Texto("Nombre"),
                    UnidadMedida = dr.Texto("UnidadMedida"),
                    Stock = dr.Decimal("Stock"),
                    StockMinimo = dr.Decimal("StockMinimo")
                });
            }
            return d;
        }
    }
}
