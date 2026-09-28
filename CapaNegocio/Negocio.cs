using CapaDatos;
using CapaEntidad;

namespace CapaNegocio
{
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
        private static readonly string[] Unidades = { "UND", "KG", "GR", "LT", "ML" };
        private readonly CD_Insumo _datos = new();

        public List<Insumo> Listar() => _datos.Listar();

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
            if (m.Tipo != "ENTRADA") { m.IdProveedor = 0; m.CostoUnitario = 0; }
            if (m.Tipo == "MERMA" && string.IsNullOrWhiteSpace(m.Observacion))
                return Respuesta.Error("Indique el motivo de la merma");
            return _datos.Registrar(m);
        }

        public List<Movimiento> Listar(DateTime inicio, DateTime fin, int idInsumo) => _datos.Listar(inicio, fin, idInsumo);
    }

    public class CN_Producto
    {
        private readonly CD_Producto _datos = new();

        public List<ProductoMenu> Listar() => _datos.Listar();
        public List<RecetaItem> ListarReceta(int idProducto) => _datos.ListarReceta(idProducto);

        public Respuesta Guardar(ProductoMenu p)
        {
            p.Nombre = p.Nombre?.Trim() ?? "";
            if (p.Nombre == "") return Respuesta.Error("El nombre es obligatorio");
            if (p.Precio <= 0) return Respuesta.Error("El precio debe ser mayor a cero");
            if (p.Receta.Count == 0) return Respuesta.Error("Agregue al menos un insumo a la receta");
            if (p.Receta.Any(r => r.IdInsumo <= 0 || r.Cantidad <= 0))
                return Respuesta.Error("Revise los insumos y cantidades de la receta");
            return _datos.Guardar(p);
        }

        public Respuesta Eliminar(int id) => _datos.Eliminar(id);
    }

    public class CN_Venta
    {
        private readonly CD_Venta _datos = new();

        public Respuesta Registrar(int idUsuario, List<DetalleVenta> detalle)
        {
            if (detalle == null || detalle.Count == 0) return Respuesta.Error("Agregue productos a la venta");
            if (detalle.Any(d => d.Cantidad <= 0)) return Respuesta.Error("Las cantidades deben ser mayores a cero");
            var agrupado = detalle.GroupBy(d => d.IdProducto)
                                  .Select(g => new DetalleVenta { IdProducto = g.Key, Cantidad = g.Sum(x => x.Cantidad) })
                                  .ToList();
            return _datos.Registrar(idUsuario, agrupado);
        }

        public List<Venta> Listar(DateTime inicio, DateTime fin) => _datos.Listar(inicio, fin);
    }

    public class CN_Dashboard
    {
        private readonly CD_Dashboard _datos = new();
        public Dashboard Obtener() => _datos.Obtener();
    }
}
