using System.Text.RegularExpressions;
using CapaDatos;
using CapaEntidad;

namespace CapaNegocio
{
    public class CN_Configuracion
    {
        private static readonly Regex ColorHex = new("^#[0-9A-Fa-f]{6}$");
        private readonly CD_Configuracion _datos = new();

        // La configuración se lee en cada página: se guarda en memoria y se refresca al guardar
        private static Configuracion? _cache;
        private static readonly object _bloqueo = new();

        public Configuracion Obtener()
        {
            lock (_bloqueo) return _cache ??= _datos.Obtener();
        }

        public Respuesta Guardar(Configuracion c)
        {
            c.NombreNegocio = c.NombreNegocio?.Trim() ?? "";
            if (c.NombreNegocio == "") return Respuesta.Error("El nombre del negocio es obligatorio");
            if (!ColorHex.IsMatch(c.ColorPrimario ?? "") || !ColorHex.IsMatch(c.ColorSecundario ?? ""))
                return Respuesta.Error("Los colores deben tener el formato #RRGGBB");
            if (c.DiasAlertaVencimiento < 0 || c.DiasAlertaVencimiento > 60)
                return Respuesta.Error("Los días de alerta deben estar entre 0 y 60");
            if (string.IsNullOrWhiteSpace(c.SimboloMoneda)) c.SimboloMoneda = "$";
            var r = _datos.Guardar(c);
            lock (_bloqueo) _cache = null;
            return r;
        }
    }

    public class CN_Sede
    {
        private readonly CD_Sede _datos = new();
        public List<Sede> Listar() => _datos.Listar();

        public Respuesta Guardar(Sede s)
        {
            s.Nombre = s.Nombre?.Trim() ?? "";
            if (s.Nombre == "") return Respuesta.Error("El nombre de la sede es obligatorio");
            return _datos.Guardar(s);
        }

        public Respuesta Eliminar(int id) => _datos.Eliminar(id);
    }

    public class CN_Usuario
    {
        private readonly CD_Usuario _datos = new();

        public Usuario? Autenticar(string usuario, string clave)
        {
            if (string.IsNullOrWhiteSpace(usuario) || string.IsNullOrWhiteSpace(clave)) return null;
            var u = _datos.Obtener(usuario.Trim());
            if (u == null || !u.Activo || !Seguridad.Verificar(clave, u.Clave)) return null;
            u.Clave = "";
            return u;
        }

        public List<Usuario> Listar() => _datos.Listar();
        public List<Rol> Roles() => _datos.Roles();

        public Respuesta Guardar(Usuario u)
        {
            u.NombreCompleto = u.NombreCompleto?.Trim() ?? "";
            u.NombreUsuario = u.NombreUsuario?.Trim() ?? "";
            if (u.NombreCompleto == "") return Respuesta.Error("El nombre es obligatorio");
            if (!Regex.IsMatch(u.NombreUsuario, "^[a-zA-Z0-9._-]{3,50}$"))
                return Respuesta.Error("El usuario debe tener entre 3 y 50 letras, números, punto o guion");
            if (u.IdRol <= 0 || u.IdSede <= 0) return Respuesta.Error("Seleccione el rol y la sede");
            string hash = "";
            if (!string.IsNullOrEmpty(u.Clave))
            {
                if (u.Clave.Length < 6) return Respuesta.Error("La contraseña debe tener al menos 6 caracteres");
                hash = Seguridad.GenerarHash(u.Clave);
            }
            else if (u.IdUsuario == 0) return Respuesta.Error("La contraseña es obligatoria");
            return _datos.Guardar(u, hash);
        }

        public Respuesta CambiarClave(int idUsuario, string actual, string nueva, string confirmacion)
        {
            var u = _datos.Obtener(idUsuario);
            if (u == null || !Seguridad.Verificar(actual ?? "", u.Clave)) return Respuesta.Error("La contraseña actual no es correcta");
            if ((nueva ?? "").Length < 6) return Respuesta.Error("La nueva contraseña debe tener al menos 6 caracteres");
            if (nueva != confirmacion) return Respuesta.Error("La confirmación no coincide");
            return _datos.CambiarClave(idUsuario, Seguridad.GenerarHash(nueva!));
        }
    }

    public class CN_Categoria
    {
        private readonly CD_Categoria _datos = new();
        public List<Categoria> Listar() => _datos.Listar();

        public Respuesta Guardar(Categoria c)
        {
            c.Descripcion = c.Descripcion?.Trim() ?? "";
            if (c.Descripcion == "") return Respuesta.Error("La descripción es obligatoria");
            return _datos.Guardar(c);
        }

        public Respuesta Eliminar(int id) => _datos.Eliminar(id);
    }

    public class CN_Proveedor
    {
        private readonly CD_Proveedor _datos = new();
        public List<Proveedor> Listar() => _datos.Listar();

        public Respuesta Guardar(Proveedor p)
        {
            p.Documento = p.Documento?.Trim() ?? "";
            p.RazonSocial = p.RazonSocial?.Trim() ?? "";
            if (p.Documento == "") return Respuesta.Error("El documento es obligatorio");
            if (p.RazonSocial == "") return Respuesta.Error("La razón social es obligatoria");
            if (!string.IsNullOrWhiteSpace(p.Correo) && !p.Correo.Contains('@'))
                return Respuesta.Error("El correo no es válido");
            return _datos.Guardar(p);
        }

        public Respuesta Eliminar(int id) => _datos.Eliminar(id);
    }

    public class CN_Insumo
    {
        public static readonly string[] Unidades = { "UND", "PORC", "KG", "GR", "LT", "ML" };
        private readonly CD_Insumo _datos = new();

        public List<Insumo> Listar(int idSede) => _datos.Listar(idSede);

        public Respuesta Guardar(Insumo i)
        {
            i.Codigo = i.Codigo?.Trim().ToUpper() ?? "";
            i.Nombre = i.Nombre?.Trim() ?? "";
            if (i.Codigo == "") return Respuesta.Error("El código es obligatorio");
            if (i.Nombre == "") return Respuesta.Error("El nombre es obligatorio");
            if (i.IdCategoria <= 0) return Respuesta.Error("Seleccione una categoría");
            if (!Unidades.Contains(i.UnidadMedida)) return Respuesta.Error("Unidad de medida no válida");
            if (i.StockMinimo < 0 || i.CostoUnitario < 0) return Respuesta.Error("Los valores no pueden ser negativos");
            return _datos.Guardar(i);
        }

        public Respuesta Eliminar(int id) => _datos.Eliminar(id);
    }

    public class CN_Movimiento
    {
        private static readonly string[] Tipos = { "ENTRADA", "SALIDA", "MERMA" };
        private readonly CD_Movimiento _datos = new();

        public Respuesta Registrar(Movimiento m)
        {
            if (m.IdInsumo <= 0) return Respuesta.Error("Seleccione un insumo");
            if (!Tipos.Contains(m.Tipo)) return Respuesta.Error("Tipo de movimiento no válido");
            if (m.Cantidad <= 0) return Respuesta.Error("La cantidad debe ser mayor a cero");
            if (m.CostoUnitario < 0) return Respuesta.Error("El costo no puede ser negativo");
            if (m.Tipo != "ENTRADA") { m.IdProveedor = 0; m.CostoUnitario = 0; m.FechaVencimiento = null; }
            if (m.FechaVencimiento.HasValue && m.FechaVencimiento.Value.Date < DateTime.Today)
                return Respuesta.Error("La fecha de vencimiento ya pasó");
            if (m.Tipo == "MERMA" && string.IsNullOrWhiteSpace(m.Observacion))
                return Respuesta.Error("Indique el motivo de la merma");
            return _datos.Registrar(m);
        }

        public List<Movimiento> Listar(int idSede, DateTime inicio, DateTime fin, int idInsumo) => _datos.Listar(idSede, inicio, fin, idInsumo);
    }

    public class CN_Conteo
    {
        private readonly CD_Conteo _datos = new();
        public List<Conteo> Listar(int idSede) => _datos.Listar(idSede);

        public Respuesta Registrar(int idSede, int idUsuario, Conteo c)
        {
            c.Detalle = c.Detalle?.GroupBy(d => d.IdInsumo).Select(g => g.Last()).ToList() ?? new();
            if (c.Detalle.Count == 0) return Respuesta.Error("Ingrese al menos una cantidad contada");
            if (c.Detalle.Any(d => d.StockContado < 0)) return Respuesta.Error("Las cantidades no pueden ser negativas");
            return _datos.Registrar(idSede, idUsuario, c);
        }
    }

    public class CN_CategoriaMenu
    {
        private readonly CD_CategoriaMenu _datos = new();
        public List<CategoriaMenu> Listar() => _datos.Listar();

        public Respuesta Guardar(CategoriaMenu c)
        {
            c.Nombre = c.Nombre?.Trim() ?? "";
            c.Icono = string.IsNullOrWhiteSpace(c.Icono) ? "🍽️" : c.Icono.Trim();
            if (c.Nombre == "") return Respuesta.Error("El nombre es obligatorio");
            return _datos.Guardar(c);
        }

        public Respuesta Eliminar(int id) => _datos.Eliminar(id);
    }

    public class CN_Producto
    {
        private readonly CD_Producto _datos = new();

        public List<ProductoMenu> Listar() => _datos.Listar();
        public List<RecetaItem> ListarReceta(int idProducto) => _datos.ListarReceta(idProducto);
        public List<int> ListarModificadores(int idProducto) => _datos.ListarModificadores(idProducto);
        public CatalogoPos Catalogo() => _datos.Catalogo();
        public Respuesta GuardarImagen(int idProducto, string? url) => _datos.GuardarImagen(idProducto, url);

        public Respuesta Guardar(ProductoMenu p)
        {
            p.Nombre = p.Nombre?.Trim() ?? "";
            if (p.Nombre == "") return Respuesta.Error("El nombre es obligatorio");
            if (p.IdCategoriaMenu <= 0) return Respuesta.Error("Seleccione la categoría del menú");
            if (p.Precio <= 0) return Respuesta.Error("El precio debe ser mayor a cero");
            if (p.Receta.Count == 0) return Respuesta.Error("Agregue al menos un insumo a la receta");
            if (p.Receta.Any(r => r.IdInsumo <= 0 || r.Cantidad <= 0))
                return Respuesta.Error("Revise los insumos y cantidades de la receta");
            return _datos.Guardar(p);
        }

        public Respuesta Eliminar(int id) => _datos.Eliminar(id);
    }

    public class CN_Modificador
    {
        private readonly CD_Modificador _datos = new();
        public List<Modificador> Listar() => _datos.Listar();

        public Respuesta Guardar(Modificador m)
        {
            m.Nombre = m.Nombre?.Trim() ?? "";
            if (m.Nombre == "") return Respuesta.Error("El nombre es obligatorio");
            if (m.Precio < 0) return Respuesta.Error("El precio no puede ser negativo");
            if (m.IdInsumo > 0 && m.Cantidad == 0) return Respuesta.Error("Indique cuánto insumo suma o resta");
            return _datos.Guardar(m);
        }

        public Respuesta Eliminar(int id) => _datos.Eliminar(id);
    }

    public class CN_Caja
    {
        private readonly CD_Caja _datos = new();
        public Caja? Actual(int idSede) => _datos.Actual(idSede);
        public List<Caja> Historial(int idSede) => _datos.Historial(idSede);

        public Respuesta Abrir(int idSede, int idUsuario, decimal baseInicial) =>
            baseInicial < 0 ? Respuesta.Error("La base no puede ser negativa") : _datos.Abrir(idSede, idUsuario, baseInicial);

        public Respuesta Cerrar(int idSede, int idUsuario, decimal efectivoContado, string? observacion) =>
            efectivoContado < 0 ? Respuesta.Error("El efectivo contado no puede ser negativo") : _datos.Cerrar(idSede, idUsuario, efectivoContado, observacion);
    }

    public class CN_Venta
    {
        private static readonly string[] TiposPedido = { "MESA", "LLEVAR", "DOMICILIO" };
        private static readonly string[] Metodos = { "EFECTIVO", "TARJETA", "TRANSFERENCIA" };
        private static readonly string[] Estados = { "PENDIENTE", "EN_CAMINO", "ENTREGADO" };
        private readonly CD_Venta _datos = new();

        public Respuesta Registrar(int idSede, int idUsuario, NuevaVenta v)
        {
            if (v.Lineas == null || v.Lineas.Count == 0) return Respuesta.Error("Agregue productos a la venta");
            if (v.Lineas.Any(l => l.Cantidad <= 0)) return Respuesta.Error("Las cantidades deben ser mayores a cero");
            if (!TiposPedido.Contains(v.TipoPedido)) return Respuesta.Error("Tipo de pedido no válido");
            if (!Metodos.Contains(v.MetodoPago)) return Respuesta.Error("Forma de pago no válida");
            if (v.CostoDomicilio < 0 || v.MontoRecibido < 0) return Respuesta.Error("Los valores no pueden ser negativos");
            if (v.TipoPedido == "DOMICILIO" &&
                (string.IsNullOrWhiteSpace(v.ClienteNombre) || string.IsNullOrWhiteSpace(v.ClienteTelefono) || string.IsNullOrWhiteSpace(v.Direccion)))
                return Respuesta.Error("Para domicilio indique nombre, teléfono y dirección del cliente");
            return _datos.Registrar(idSede, idUsuario, v);
        }

        public List<Venta> Listar(int idSede, DateTime inicio, DateTime fin) => _datos.Listar(idSede, inicio, fin);
        public List<Venta> Domicilios(int idSede, bool soloPendientes) => _datos.Domicilios(idSede, soloPendientes);

        public Ticket? Ticket(int idVenta, int idSede, bool esAdmin)
        {
            var (t, sedeVenta) = _datos.Ticket(idVenta);
            if (t == null || (!esAdmin && sedeVenta != idSede)) return null;
            t.Configuracion = new CN_Configuracion().Obtener();
            return t;
        }

        public Respuesta CambiarEstado(int idSede, int idVenta, string estado) =>
            Estados.Contains(estado) ? _datos.CambiarEstado(idSede, idVenta, estado) : Respuesta.Error("Estado no válido");
    }

    public class CN_Compra
    {
        public List<OrdenCompraItem> Sugerida(int idSede) => new CD_Compra().Sugerida(idSede);
    }

    public class CN_Reporte
    {
        public Reporte Obtener(int idSede, DateTime inicio, DateTime fin) =>
            new CD_Reporte().Obtener(idSede, inicio, fin <= inicio ? inicio : fin);
    }

    public class CN_Dashboard
    {
        public Dashboard Obtener(int idSede) => new CD_Dashboard().Obtener(idSede);
    }
}
