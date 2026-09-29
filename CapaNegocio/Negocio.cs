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
            if (c.MinutosEdicion < 0 || c.MinutosEdicion > 60)
                return Respuesta.Error("El tiempo para editar pedidos debe estar entre 0 y 60 minutos");
            if (c.MinutosAlertaCocina < 1 || c.MinutosAlertaDomicilio < 1)
                return Respuesta.Error("Los tiempos de alerta deben ser de al menos 1 minuto");
            if (c.CostoDomicilio < 0) return Respuesta.Error("El valor del domicilio no puede ser negativo");
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

        /// <summary>
        /// Carga masiva desde la plantilla de Excel: crea o actualiza insumos por código (y sus categorías)
        /// y, si la fila trae stock, lo deja igual al contado con un ajuste de conteo físico.
        /// Primero valida todo; si hay errores no guarda nada.
        /// </summary>
        public ResultadoImportacion Importar(List<FilaImportacion> filas, int idSede, int idUsuario)
        {
            var res = new ResultadoImportacion();
            filas = filas.Where(f => !(string.IsNullOrWhiteSpace(f.Codigo) && string.IsNullOrWhiteSpace(f.Nombre))).ToList();
            if (filas.Count == 0) { res.Errores.Add("La plantilla no tiene filas con datos"); return res; }

            foreach (var f in filas)
            {
                f.Codigo = f.Codigo.Trim().ToUpper();
                f.Nombre = f.Nombre.Trim();
                f.Categoria = f.Categoria.Trim();
                f.UnidadMedida = f.UnidadMedida.Trim().ToUpper();
                if (f.Codigo == "") res.Errores.Add($"Fila {f.Fila}: falta el código");
                else if (f.Codigo.Length > 30) res.Errores.Add($"Fila {f.Fila}: el código tiene más de 30 caracteres");
                if (f.Nombre == "") res.Errores.Add($"Fila {f.Fila}: falta el nombre");
                else if (f.Nombre.Length > 100) res.Errores.Add($"Fila {f.Fila}: el nombre tiene más de 100 caracteres");
                if (f.Categoria == "") res.Errores.Add($"Fila {f.Fila}: falta la categoría");
                if (!Unidades.Contains(f.UnidadMedida)) res.Errores.Add($"Fila {f.Fila}: unidad \"{f.UnidadMedida}\" no válida (use {string.Join(", ", Unidades)})");
                if (f.StockMinimo < 0 || f.CostoUnitario < 0 || f.Stock < 0) res.Errores.Add($"Fila {f.Fila}: hay valores negativos");
            }
            foreach (var g in filas.Where(f => f.Codigo != "").GroupBy(f => f.Codigo).Where(g => g.Count() > 1))
                res.Errores.Add($"El código {g.Key} está repetido en las filas {string.Join(", ", g.Select(f => f.Fila))}");
            if (res.Errores.Count > 0) return res;

            // Categorías que no existen se crean
            var cnCategoria = new CN_Categoria();
            var categorias = cnCategoria.Listar().ToDictionary(c => c.Descripcion.Trim(), c => c.IdCategoria, StringComparer.OrdinalIgnoreCase);
            foreach (var nombre in filas.Select(f => f.Categoria).Distinct(StringComparer.OrdinalIgnoreCase).Where(n => !categorias.ContainsKey(n)))
            {
                var r = cnCategoria.Guardar(new Categoria { Descripcion = nombre, Activo = true });
                if (!r.Resultado) { res.Errores.Add($"Categoría {nombre}: {r.Mensaje}"); return res; }
                categorias[nombre] = r.Id;
                res.CategoriasNuevas++;
            }

            var existentes = _datos.Listar(idSede).ToDictionary(i => i.Codigo, StringComparer.OrdinalIgnoreCase);
            var conteo = new Conteo { Observacion = "Carga de inventario desde Excel" };
            foreach (var f in filas)
            {
                existentes.TryGetValue(f.Codigo, out var actual);
                var r = _datos.Guardar(new Insumo
                {
                    IdInsumo = actual?.IdInsumo ?? 0,
                    Codigo = f.Codigo,
                    Nombre = f.Nombre,
                    IdCategoria = categorias[f.Categoria],
                    UnidadMedida = f.UnidadMedida,
                    StockMinimo = f.StockMinimo,
                    CostoUnitario = f.CostoUnitario,
                    Activo = actual?.Activo ?? true
                });
                if (!r.Resultado) { res.Errores.Add($"Fila {f.Fila} ({f.Codigo}): {r.Mensaje}"); continue; }
                if (actual == null) res.Creados++; else res.Actualizados++;
                if (f.Stock.HasValue && f.Stock.Value != (actual?.Stock ?? 0))
                    conteo.Detalle.Add(new ConteoItem { IdInsumo = r.Id, StockContado = f.Stock.Value });
            }

            if (conteo.Detalle.Count > 0)
            {
                var r = new CN_Conteo().Registrar(idSede, idUsuario, conteo);
                if (r.Resultado) res.StockAjustado = conteo.Detalle.Count;
                else res.Errores.Add("Los insumos se guardaron pero el stock no se ajustó: " + r.Mensaje);
            }
            res.Resultado = res.Errores.Count == 0;
            return res;
        }
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
        public CatalogoPos Catalogo(int idSede) => _datos.Catalogo(idSede);
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
            m.Grupo = string.IsNullOrWhiteSpace(m.Grupo) ? "Adiciones" : m.Grupo.Trim();
            if (m.Grupo.Length > 40) return Respuesta.Error("El grupo puede tener máximo 40 caracteres");
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

        public ReporteCaja? Reporte(int idSede, int idCaja)
        {
            var r = _datos.Reporte(idSede, idCaja);
            if (r != null) r.Configuracion = new CN_Configuracion().Obtener();
            return r;
        }
    }

    public class CN_Venta
    {
        private static readonly string[] TiposPedido = { "MESA", "LLEVAR", "DOMICILIO" };
        private static readonly string[] Metodos = { "EFECTIVO", "TARJETA", "TRANSFERENCIA" };
        private static readonly string[] Estados = { "PENDIENTE", "EN_CAMINO", "ENTREGADO" };
        private static readonly string[] EstadosCocina = { "PENDIENTE", "PREPARANDO", "LISTO", "ENTREGADO" };
        private readonly CD_Venta _datos = new();

        public Respuesta Registrar(int idSede, int idUsuario, NuevaVenta v)
        {
            if (v.Lineas == null || v.Lineas.Count == 0) return Respuesta.Error("Agregue productos a la venta");
            if (v.Lineas.Any(l => l.Cantidad <= 0)) return Respuesta.Error("Las cantidades deben ser mayores a cero");
            if (!TiposPedido.Contains(v.TipoPedido)) return Respuesta.Error("Tipo de pedido no válido");
            if (!Metodos.Contains(v.MetodoPago)) return Respuesta.Error("Forma de pago no válida");
            if (v.CostoDomicilio < 0 || v.MontoRecibido < 0) return Respuesta.Error("Los valores no pueden ser negativos");
            if (v.IdVenta < 0) return Respuesta.Error("Pedido no válido");
            v.ClienteTelefono = SoloDigitos(v.ClienteTelefono);
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

        public Respuesta Anular(int idSede, int idVenta, int idUsuario, bool esAdmin, string? motivo) =>
            string.IsNullOrWhiteSpace(motivo) ? Respuesta.Error("Indique el motivo de la anulación")
                : _datos.Anular(idSede, idVenta, idUsuario, esAdmin, motivo.Trim());

        public Respuesta CambiarEstado(int idSede, int idVenta, string estado, string? repartidor = null)
        {
            if (!Estados.Contains(estado)) return Respuesta.Error("Estado no válido");
            if (estado == "EN_CAMINO" && string.IsNullOrWhiteSpace(repartidor)) return Respuesta.Error("Indique quién lleva el domicilio");
            return _datos.CambiarEstado(idSede, idVenta, estado, repartidor?.Trim());
        }

        public List<string> Repartidores(int idSede) => _datos.Repartidores(idSede);

        public ClienteFrecuente? Cliente(string? telefono)
        {
            var t = SoloDigitos(telefono);
            return t.Length < 7 ? null : _datos.Cliente(t);
        }

        public List<Comanda> Cocina(int idSede) => _datos.Cocina(idSede);

        public Respuesta EstadoCocina(int idSede, int idVenta, string estado) =>
            EstadosCocina.Contains(estado) ? _datos.EstadoCocina(idSede, idVenta, estado) : Respuesta.Error("Estado no válido");

        /// <summary>Deja solo los números del teléfono para poder reconocer al cliente la próxima vez.</summary>
        private static string SoloDigitos(string? telefono) => new((telefono ?? "").Where(char.IsDigit).ToArray());
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
