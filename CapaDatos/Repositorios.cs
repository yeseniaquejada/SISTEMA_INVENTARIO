using System.Data;
using CapaEntidad;
using Microsoft.Data.SqlClient;
using static CapaDatos.Conexion;

namespace CapaDatos
{
    public class CD_Configuracion
    {
        public Configuracion Obtener() =>
            Listar("SP_CONFIGURACION_OBTENER", dr => new Configuracion
            {
                NombreNegocio = dr.Texto("NombreNegocio"),
                Nit = dr.Texto("Nit"),
                Direccion = dr.Texto("Direccion"),
                Telefono = dr.Texto("Telefono"),
                ColorPrimario = dr.Texto("ColorPrimario"),
                ColorSecundario = dr.Texto("ColorSecundario"),
                LogoUrl = dr.Texto("LogoUrl"),
                SimboloMoneda = dr.Texto("SimboloMoneda"),
                MensajeTicket = dr.Texto("MensajeTicket"),
                DiasAlertaVencimiento = dr.Entero("DiasAlertaVencimiento")
            }).FirstOrDefault() ?? new Configuracion();

        public Respuesta Guardar(Configuracion c) =>
            Ejecutar("SP_CONFIGURACION_GUARDAR", P("@NombreNegocio", c.NombreNegocio), P("@Nit", c.Nit),
                P("@Direccion", c.Direccion), P("@Telefono", c.Telefono), P("@ColorPrimario", c.ColorPrimario),
                P("@ColorSecundario", c.ColorSecundario), P("@LogoUrl", c.LogoUrl), P("@SimboloMoneda", c.SimboloMoneda),
                P("@MensajeTicket", c.MensajeTicket), P("@DiasAlertaVencimiento", c.DiasAlertaVencimiento));
    }

    public class CD_Sede
    {
        public List<Sede> Listar() =>
            Conexion.Listar("SP_SEDE_LISTAR", dr => new Sede
            {
                IdSede = dr.Entero("IdSede"),
                Nombre = dr.Texto("Nombre"),
                Direccion = dr.Texto("Direccion"),
                Telefono = dr.Texto("Telefono"),
                Activo = dr.Bool("Activo")
            });

        public Respuesta Guardar(Sede s) =>
            Ejecutar("SP_SEDE_GUARDAR", P("@IdSede", s.IdSede), P("@Nombre", s.Nombre), P("@Direccion", s.Direccion),
                P("@Telefono", s.Telefono), P("@Activo", s.Activo));

        public Respuesta Eliminar(int id) => Ejecutar("SP_SEDE_ELIMINAR", P("@IdSede", id));
    }

    public class CD_Usuario
    {
        private static Usuario Mapear(SqlDataReader dr) => new()
        {
            IdUsuario = dr.Entero("IdUsuario"),
            NombreCompleto = dr.Texto("NombreCompleto"),
            NombreUsuario = dr.Texto("Usuario"),
            Clave = dr.Texto("Clave"),
            IdRol = dr.Entero("IdRol"),
            Rol = dr.Texto("Rol"),
            IdSede = dr.Entero("IdSede"),
            Sede = dr.Texto("Sede"),
            Activo = dr.Bool("Activo")
        };

        public Usuario? Obtener(string usuario) => Conexion.Listar("SP_USUARIO_OBTENER", Mapear, P("@Usuario", usuario)).FirstOrDefault();
        public Usuario? Obtener(int id) => Conexion.Listar("SP_USUARIO_OBTENER_ID", Mapear, P("@IdUsuario", id)).FirstOrDefault();
        public List<Usuario> Listar() => Conexion.Listar("SP_USUARIO_LISTAR", Mapear);
        public List<Rol> Roles() => Conexion.Listar("SP_ROL_LISTAR", dr => new Rol { IdRol = dr.Entero("IdRol"), Descripcion = dr.Texto("Descripcion") });

        public Respuesta Guardar(Usuario u, string claveHash) =>
            Ejecutar("SP_USUARIO_GUARDAR", P("@IdUsuario", u.IdUsuario), P("@NombreCompleto", u.NombreCompleto),
                P("@Usuario", u.NombreUsuario), P("@Clave", claveHash), P("@IdRol", u.IdRol), P("@IdSede", u.IdSede),
                P("@Activo", u.Activo));

        public Respuesta CambiarClave(int idUsuario, string claveHash) =>
            Ejecutar("SP_USUARIO_CAMBIAR_CLAVE", P("@IdUsuario", idUsuario), P("@Clave", claveHash));
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
        public List<Insumo> Listar(int idSede) =>
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
                Activo = dr.Bool("Activo"),
                ProximoVencimiento = dr["ProximoVencimiento"] == DBNull.Value ? "" : ((DateTime)dr["ProximoVencimiento"]).ToString("yyyy-MM-dd")
            }, P("@IdSede", idSede));

        public Respuesta Guardar(Insumo i) =>
            Ejecutar("SP_INSUMO_GUARDAR", P("@IdInsumo", i.IdInsumo), P("@Codigo", i.Codigo), P("@Nombre", i.Nombre),
                P("@IdCategoria", i.IdCategoria), P("@UnidadMedida", i.UnidadMedida), P("@StockMinimo", i.StockMinimo),
                P("@CostoUnitario", i.CostoUnitario), P("@Activo", i.Activo));

        public Respuesta Eliminar(int id) => Ejecutar("SP_INSUMO_ELIMINAR", P("@IdInsumo", id));
    }

    public class CD_Movimiento
    {
        public Respuesta Registrar(Movimiento m) =>
            Ejecutar("SP_MOVIMIENTO_REGISTRAR", P("@IdSede", m.IdSede), P("@IdInsumo", m.IdInsumo), P("@Tipo", m.Tipo),
                P("@Cantidad", m.Cantidad), P("@CostoUnitario", m.CostoUnitario), P("@IdProveedor", m.IdProveedor),
                P("@FechaVencimiento", m.FechaVencimiento?.Date), P("@Observacion", m.Observacion), P("@IdUsuario", m.IdUsuario));

        public List<Movimiento> Listar(int idSede, DateTime inicio, DateTime fin, int idInsumo) =>
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
            }, P("@IdSede", idSede), P("@FechaInicio", inicio.Date), P("@FechaFin", fin.Date), P("@IdInsumo", idInsumo));
    }

    public class CD_Conteo
    {
        public Respuesta Registrar(int idSede, int idUsuario, Conteo c)
        {
            var t = new DataTable();
            t.Columns.Add("IdInsumo", typeof(int));
            t.Columns.Add("StockContado", typeof(decimal));
            foreach (var d in c.Detalle) t.Rows.Add(d.IdInsumo, d.StockContado);
            return Ejecutar("SP_CONTEO_REGISTRAR", P("@IdSede", idSede), P("@IdUsuario", idUsuario),
                P("@Observacion", c.Observacion), Tabla("@Detalle", "EConteo", t));
        }

        public List<Conteo> Listar(int idSede) =>
            Conexion.Listar("SP_CONTEO_LISTAR", dr => new Conteo
            {
                IdConteo = dr.Entero("IdConteo"),
                Fecha = dr.Texto("Fecha"),
                Usuario = dr.Texto("Usuario"),
                Observacion = dr.Texto("Observacion"),
                Insumos = dr.Entero("Insumos"),
                ConDiferencia = dr.Entero("ConDiferencia"),
                ValorDiferencia = dr.Decimal("ValorDiferencia")
            }, P("@IdSede", idSede));
    }

    public class CD_CategoriaMenu
    {
        public List<CategoriaMenu> Listar() =>
            Conexion.Listar("SP_CATEGORIA_MENU_LISTAR", dr => new CategoriaMenu
            {
                IdCategoriaMenu = dr.Entero("IdCategoriaMenu"),
                Nombre = dr.Texto("Nombre"),
                Icono = dr.Texto("Icono"),
                Orden = dr.Entero("Orden"),
                Activo = dr.Bool("Activo")
            });

        public Respuesta Guardar(CategoriaMenu c) =>
            Ejecutar("SP_CATEGORIA_MENU_GUARDAR", P("@IdCategoriaMenu", c.IdCategoriaMenu), P("@Nombre", c.Nombre),
                P("@Icono", c.Icono), P("@Orden", c.Orden), P("@Activo", c.Activo));

        public Respuesta Eliminar(int id) => Ejecutar("SP_CATEGORIA_MENU_ELIMINAR", P("@IdCategoriaMenu", id));
    }

    public class CD_Producto
    {
        private static ProductoMenu Mapear(SqlDataReader dr) => new()
        {
            IdProducto = dr.Entero("IdProducto"),
            Nombre = dr.Texto("Nombre"),
            Descripcion = dr.Texto("Descripcion"),
            IdCategoriaMenu = dr.Entero("IdCategoriaMenu"),
            CategoriaMenu = dr.Texto("CategoriaMenu"),
            Icono = dr.Texto("Icono"),
            Precio = dr.Decimal("Precio"),
            ImagenUrl = dr.Texto("ImagenUrl")
        };

        public List<ProductoMenu> Listar() =>
            Conexion.Listar("SP_PRODUCTO_LISTAR", dr =>
            {
                var p = Mapear(dr);
                p.Activo = dr.Bool("Activo");
                p.TotalInsumos = dr.Entero("TotalInsumos");
                p.Costo = dr.Decimal("Costo");
                return p;
            });

        public List<RecetaItem> ListarReceta(int idProducto) =>
            Conexion.Listar("SP_RECETA_LISTAR", dr => new RecetaItem
            {
                IdInsumo = dr.Entero("IdInsumo"),
                Insumo = dr.Texto("Insumo"),
                UnidadMedida = dr.Texto("UnidadMedida"),
                Cantidad = dr.Decimal("Cantidad"),
                CostoUnitario = dr.Decimal("CostoUnitario")
            }, P("@IdProducto", idProducto));

        public List<int> ListarModificadores(int idProducto) =>
            Conexion.Listar("SP_PRODUCTO_MODIFICADORES", dr => dr.Entero("IdModificador"), P("@IdProducto", idProducto));

        public Respuesta Guardar(ProductoMenu p)
        {
            var receta = new DataTable();
            receta.Columns.Add("IdInsumo", typeof(int));
            receta.Columns.Add("Cantidad", typeof(decimal));
            foreach (var r in p.Receta) receta.Rows.Add(r.IdInsumo, r.Cantidad);

            return Ejecutar("SP_PRODUCTO_GUARDAR", P("@IdProducto", p.IdProducto), P("@Nombre", p.Nombre),
                P("@Descripcion", p.Descripcion), P("@IdCategoriaMenu", p.IdCategoriaMenu), P("@Precio", p.Precio),
                P("@Activo", p.Activo), Tabla("@Receta", "EReceta", receta), Tabla("@Modificadores", "EIds", Ids(p.Modificadores)));
        }

        public Respuesta GuardarImagen(int idProducto, string? url) =>
            Ejecutar("SP_PRODUCTO_IMAGEN", P("@IdProducto", idProducto), P("@ImagenUrl", url));

        public Respuesta Eliminar(int id) => Ejecutar("SP_PRODUCTO_ELIMINAR", P("@IdProducto", id));

        public CatalogoPos Catalogo()
        {
            var c = new CatalogoPos();
            Leer("SP_POS_CATALOGO", dr =>
            {
                while (dr.Read()) c.Productos.Add(Mapear(dr));
                dr.NextResult();
                while (dr.Read())
                    c.Modificadores.Add(new ProductoModificador
                    {
                        IdProducto = dr.Entero("IdProducto"),
                        IdModificador = dr.Entero("IdModificador"),
                        Nombre = dr.Texto("Nombre"),
                        Precio = dr.Decimal("Precio")
                    });
            });
            return c;
        }
    }

    public class CD_Modificador
    {
        public List<Modificador> Listar() =>
            Conexion.Listar("SP_MODIFICADOR_LISTAR", dr => new Modificador
            {
                IdModificador = dr.Entero("IdModificador"),
                Nombre = dr.Texto("Nombre"),
                Precio = dr.Decimal("Precio"),
                IdInsumo = dr.Entero("IdInsumo"),
                Insumo = dr.Texto("Insumo"),
                UnidadMedida = dr.Texto("UnidadMedida"),
                Cantidad = dr.Decimal("Cantidad"),
                Activo = dr.Bool("Activo")
            });

        public Respuesta Guardar(Modificador m) =>
            Ejecutar("SP_MODIFICADOR_GUARDAR", P("@IdModificador", m.IdModificador), P("@Nombre", m.Nombre),
                P("@Precio", m.Precio), P("@IdInsumo", m.IdInsumo), P("@Cantidad", m.Cantidad), P("@Activo", m.Activo));

        public Respuesta Eliminar(int id) => Ejecutar("SP_MODIFICADOR_ELIMINAR", P("@IdModificador", id));
    }

    public class CD_Caja
    {
        public Caja? Actual(int idSede) =>
            Conexion.Listar("SP_CAJA_ACTUAL", dr => new Caja
            {
                IdCaja = dr.Entero("IdCaja"),
                FechaApertura = dr.Texto("FechaApertura"),
                BaseInicial = dr.Decimal("BaseInicial"),
                UsuarioApertura = dr.Texto("UsuarioApertura"),
                VentasEfectivo = dr.Decimal("VentasEfectivo"),
                VentasTarjeta = dr.Decimal("VentasTarjeta"),
                VentasTransferencia = dr.Decimal("VentasTransferencia"),
                NumeroVentas = dr.Entero("NumeroVentas")
            }, P("@IdSede", idSede)).FirstOrDefault();

        public Respuesta Abrir(int idSede, int idUsuario, decimal baseInicial) =>
            Ejecutar("SP_CAJA_ABRIR", P("@IdSede", idSede), P("@IdUsuario", idUsuario), P("@BaseInicial", baseInicial));

        public Respuesta Cerrar(int idSede, int idUsuario, decimal efectivoContado, string? observacion) =>
            Ejecutar("SP_CAJA_CERRAR", P("@IdSede", idSede), P("@IdUsuario", idUsuario),
                P("@EfectivoContado", efectivoContado), P("@Observacion", observacion));

        public List<Caja> Historial(int idSede) =>
            Conexion.Listar("SP_CAJA_HISTORIAL", dr => new Caja
            {
                IdCaja = dr.Entero("IdCaja"),
                FechaApertura = dr.Texto("FechaApertura"),
                FechaCierre = dr.Texto("FechaCierre"),
                BaseInicial = dr.Decimal("BaseInicial"),
                VentasEfectivo = dr.Decimal("VentasEfectivo"),
                VentasTarjeta = dr.Decimal("VentasTarjeta"),
                VentasTransferencia = dr.Decimal("VentasTransferencia"),
                EfectivoEsperado = dr.Decimal("EfectivoEsperado"),
                EfectivoContado = dr.Decimal("EfectivoContado"),
                Diferencia = dr.Decimal("Diferencia"),
                UsuarioCierre = dr.Texto("UsuarioCierre"),
                Observacion = dr.Texto("Observacion")
            }, P("@IdSede", idSede));
    }

    public class CD_Venta
    {
        public Respuesta Registrar(int idSede, int idUsuario, NuevaVenta v)
        {
            var lineas = new DataTable();
            lineas.Columns.Add("Linea", typeof(int));
            lineas.Columns.Add("IdProducto", typeof(int));
            lineas.Columns.Add("Cantidad", typeof(int));
            lineas.Columns.Add("Notas", typeof(string));
            var mods = new DataTable();
            mods.Columns.Add("Linea", typeof(int));
            mods.Columns.Add("IdModificador", typeof(int));
            for (int i = 0; i < v.Lineas.Count; i++)
            {
                var l = v.Lineas[i];
                lineas.Rows.Add(i + 1, l.IdProducto, l.Cantidad, l.Notas ?? "");
                foreach (var m in l.Modificadores.Distinct()) mods.Rows.Add(i + 1, m);
            }

            return Ejecutar("SP_VENTA_REGISTRAR", P("@IdSede", idSede), P("@IdUsuario", idUsuario), P("@TipoPedido", v.TipoPedido),
                P("@ClienteNombre", v.ClienteNombre), P("@ClienteTelefono", v.ClienteTelefono), P("@Direccion", v.Direccion),
                P("@CostoDomicilio", v.CostoDomicilio), P("@MetodoPago", v.MetodoPago), P("@MontoRecibido", v.MontoRecibido),
                Tabla("@Lineas", "ELineaVenta", lineas), Tabla("@Modificadores", "ELineaModificador", mods));
        }

        public List<Venta> Listar(int idSede, DateTime inicio, DateTime fin) =>
            Conexion.Listar("SP_VENTA_LISTAR", dr => new Venta
            {
                IdVenta = dr.Entero("IdVenta"),
                Fecha = dr.Texto("Fecha"),
                TipoPedido = dr.Texto("TipoPedido"),
                MetodoPago = dr.Texto("MetodoPago"),
                Total = dr.Decimal("Total"),
                EstadoPedido = dr.Texto("EstadoPedido"),
                ClienteNombre = dr.Texto("ClienteNombre"),
                Usuario = dr.Texto("Usuario"),
                Detalle = dr.Texto("Detalle")
            }, P("@IdSede", idSede), P("@FechaInicio", inicio.Date), P("@FechaFin", fin.Date));

        /// <summary>Devuelve el ticket y el Id de la sede de la venta (para validar acceso).</summary>
        public (Ticket? ticket, int idSede) Ticket(int idVenta)
        {
            Ticket? t = null;
            int idSede = 0;
            Leer("SP_VENTA_TICKET", dr =>
            {
                if (!dr.Read()) return;
                idSede = dr.Entero("IdSede");
                t = new Ticket
                {
                    Venta = new Venta
                    {
                        IdVenta = dr.Entero("IdVenta"),
                        Fecha = dr.Texto("Fecha"),
                        TipoPedido = dr.Texto("TipoPedido"),
                        MetodoPago = dr.Texto("MetodoPago"),
                        Subtotal = dr.Decimal("Subtotal"),
                        CostoDomicilio = dr.Decimal("CostoDomicilio"),
                        Total = dr.Decimal("Total"),
                        MontoRecibido = dr.Decimal("MontoRecibido"),
                        Cambio = dr.Decimal("Cambio"),
                        EstadoPedido = dr.Texto("EstadoPedido"),
                        ClienteNombre = dr.Texto("ClienteNombre"),
                        ClienteTelefono = dr.Texto("ClienteTelefono"),
                        Direccion = dr.Texto("Direccion"),
                        Usuario = dr.Texto("Usuario"),
                        Sede = dr.Texto("Sede"),
                        SedeDireccion = dr.Texto("SedeDireccion")
                    }
                };
                dr.NextResult();
                while (dr.Read())
                    t.Lineas.Add(new TicketLinea
                    {
                        IdDetalle = dr.Entero("IdDetalle"),
                        Nombre = dr.Texto("Nombre"),
                        Cantidad = dr.Entero("Cantidad"),
                        PrecioUnitario = dr.Decimal("PrecioUnitario"),
                        Subtotal = dr.Decimal("Subtotal"),
                        Notas = dr.Texto("Notas")
                    });
                dr.NextResult();
                while (dr.Read())
                {
                    var linea = t.Lineas.FirstOrDefault(x => x.IdDetalle == dr.Entero("IdDetalle"));
                    linea?.Adiciones.Add(dr.Texto("Nombre"));
                }
            }, P("@IdVenta", idVenta));
            return (t, idSede);
        }

        public List<Venta> Domicilios(int idSede, bool soloPendientes) =>
            Conexion.Listar("SP_DOMICILIO_LISTAR", dr => new Venta
            {
                IdVenta = dr.Entero("IdVenta"),
                Fecha = dr.Texto("Fecha"),
                ClienteNombre = dr.Texto("ClienteNombre"),
                ClienteTelefono = dr.Texto("ClienteTelefono"),
                Direccion = dr.Texto("Direccion"),
                Total = dr.Decimal("Total"),
                MetodoPago = dr.Texto("MetodoPago"),
                EstadoPedido = dr.Texto("EstadoPedido"),
                Minutos = dr.Entero("Minutos"),
                Detalle = dr.Texto("Detalle")
            }, P("@IdSede", idSede), P("@SoloPendientes", soloPendientes));

        public Respuesta CambiarEstado(int idSede, int idVenta, string estado) =>
            Ejecutar("SP_DOMICILIO_ESTADO", P("@IdSede", idSede), P("@IdVenta", idVenta), P("@Estado", estado));
    }

    public class CD_Compra
    {
        public List<OrdenCompraItem> Sugerida(int idSede) =>
            Conexion.Listar("SP_ORDEN_COMPRA_SUGERIDA", dr => new OrdenCompraItem
            {
                IdInsumo = dr.Entero("IdInsumo"),
                Codigo = dr.Texto("Codigo"),
                Nombre = dr.Texto("Nombre"),
                UnidadMedida = dr.Texto("UnidadMedida"),
                Stock = dr.Decimal("Stock"),
                StockMinimo = dr.Decimal("StockMinimo"),
                CantidadSugerida = dr.Decimal("CantidadSugerida"),
                CostoUnitario = dr.Decimal("CostoUnitario"),
                CostoEstimado = dr.Decimal("CostoEstimado"),
                IdProveedor = dr.Entero("IdProveedor"),
                Proveedor = dr.Texto("Proveedor"),
                TelefonoProveedor = dr.Texto("TelefonoProveedor")
            }, P("@IdSede", idSede));
    }

    public class CD_Reporte
    {
        public Reporte Obtener(int idSede, DateTime inicio, DateTime fin)
        {
            var r = new Reporte();
            var ps = () => new[] { P("@IdSede", idSede), P("@FechaInicio", inicio.Date), P("@FechaFin", fin.Date) };
            Leer("SP_REPORTE_RESUMEN", dr =>
            {
                if (dr.Read())
                {
                    r.Ventas = dr.Decimal("Ventas");
                    r.Pedidos = dr.Entero("Pedidos");
                    r.TicketPromedio = Math.Round(dr.Decimal("TicketPromedio"), 0);
                    r.VentasProductos = dr.Decimal("VentasProductos");
                    r.CostoInsumos = dr.Decimal("CostoInsumos");
                    r.Ganancia = dr.Decimal("Ganancia");
                    r.Mermas = dr.Decimal("Mermas");
                }
                dr.NextResult();
                while (dr.Read())
                    r.PorMetodo.Add(new PuntoReporte { Etiqueta = dr.Texto("MetodoPago"), Cantidad = dr.Entero("Pedidos"), Total = dr.Decimal("Total") });
            }, ps());
            r.PorDia = Conexion.Listar("SP_REPORTE_VENTAS_DIA", dr => new PuntoReporte
            { Etiqueta = dr.Texto("Dia"), Cantidad = dr.Entero("Pedidos"), Total = dr.Decimal("Total") }, ps());
            r.TopProductos = Conexion.Listar("SP_REPORTE_TOP_PRODUCTOS", dr => new PuntoReporte
            { Etiqueta = dr.Texto("Nombre"), Cantidad = dr.Entero("Cantidad"), Total = dr.Decimal("Total") }, ps());
            return r;
        }
    }

    public class CD_Dashboard
    {
        public Dashboard Obtener(int idSede)
        {
            var d = new Dashboard();
            Leer("SP_DASHBOARD", dr =>
            {
                if (dr.Read())
                {
                    d.TotalInsumos = dr.Entero("TotalInsumos");
                    d.InsumosBajoStock = dr.Entero("InsumosBajoStock");
                    d.ValorInventario = dr.Decimal("ValorInventario");
                    d.VentasHoy = dr.Decimal("VentasHoy");
                    d.PedidosHoy = dr.Entero("PedidosHoy");
                    d.DomiciliosPendientes = dr.Entero("DomiciliosPendientes");
                    d.CajaAbierta = dr.Bool("CajaAbierta");
                }
                dr.NextResult();
                while (dr.Read())
                    d.Alertas.Add(new Insumo
                    {
                        IdInsumo = dr.Entero("IdInsumo"),
                        Codigo = dr.Texto("Codigo"),
                        Nombre = dr.Texto("Nombre"),
                        UnidadMedida = dr.Texto("UnidadMedida"),
                        Stock = dr.Decimal("Stock"),
                        StockMinimo = dr.Decimal("StockMinimo")
                    });
                dr.NextResult();
                while (dr.Read())
                    d.Vencimientos.Add(new LoteAlerta
                    {
                        IdLote = dr.Entero("IdLote"),
                        Nombre = dr.Texto("Nombre"),
                        UnidadMedida = dr.Texto("UnidadMedida"),
                        CantidadDisponible = dr.Decimal("CantidadDisponible"),
                        FechaVencimiento = dr.Texto("FechaVencimiento"),
                        DiasRestantes = dr.Entero("DiasRestantes")
                    });
            }, P("@IdSede", idSede));
            return d;
        }
    }
}
