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

        // Yesenia Quejada Rojas - Claude — 31/10/2026: fechas con las que las páginas (ventas y ganancias, facturas, movimientos) filtran "hoy".
        // Hoy = fecha del reloj del servidor SQL, porque ese reloj graba las ventas (hoy 2 horas atrás de Colombia; 3 desde el 1/11); con la fecha del PC,
        // pasada la medianoche todo daba 0. Inicio = el día en que se abrió la caja que sigue abierta: mientras el negocio no cierra, "hoy" sigue siendo
        // el día que están trabajando aunque ya sea otra fecha. Sin caja abierta, Inicio = Hoy. Se guarda 10 segundos por sede; si la base falla se usa la
        // hora de Colombia, para que ninguna página se caiga por esto.
        private static readonly Dictionary<int, (string Hoy, string Inicio, DateTime Vence)> _fechas = new();

        public (string Hoy, string Inicio) Fechas(int idSede)
        {
            lock (_bloqueo)
            {
                if (_fechas.TryGetValue(idSede, out var f) && DateTime.UtcNow < f.Vence) return (f.Hoy, f.Inicio);
                string hoy, inicio;
                try
                {
                    var (h, diaCaja) = _datos.Fechas(idSede);
                    if (string.IsNullOrEmpty(h)) throw new InvalidOperationException("La base no devolvió la fecha");
                    hoy = h;
                    inicio = diaCaja != "" && string.CompareOrdinal(diaCaja, h) < 0 ? diaCaja : h;
                    _fechas[idSede] = (hoy, inicio, DateTime.UtcNow.AddSeconds(10));
                }
                catch
                {
                    hoy = inicio = DateTime.UtcNow.AddHours(-5).ToString("yyyy-MM-dd");
                    _fechas[idSede] = (hoy, inicio, DateTime.UtcNow.AddSeconds(5));
                }
                return (hoy, inicio);
            }
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
            if (c.AnchoTicket != 58 && c.AnchoTicket != 80) return Respuesta.Error("El ancho del ticket debe ser 58 u 80 mm");
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
        // Yesenia Quejada Rojas - Claude — 28/10/2026: PAQ para lo que se compra en paquetes (servilletas, tortillas, bolsas).
        public static readonly string[] Unidades = { "UND", "PORC", "KG", "GR", "LT", "ML", "PAQ" };
        // Yesenia Quejada Rojas - Claude — 19/10/2026: en la plantilla de Excel la unidad se elige de una lista con nombre claro.
        public static readonly string[] UnidadesTexto =
            { "Unidad (UND)", "Porción (PORC)", "Kilogramo (KG)", "Gramo (GR)", "Litro (LT)", "Mililitro (ML)", "Paquete (PAQ)" };

        /// <summary>Acepta "Kilogramo (KG)", "kg" o "Kilogramo" y devuelve el código de la unidad.</summary>
        public static string UnidadDesdeTexto(string? texto)
        {
            var t = (texto ?? "").Trim();
            var abre = t.LastIndexOf('(');
            if (abre >= 0 && t.EndsWith(")")) t = t[(abre + 1)..^1];
            t = t.Trim().ToUpperInvariant();
            if (Unidades.Contains(t)) return t;
            var i = Array.FindIndex(UnidadesTexto, u => u.StartsWith(t, StringComparison.OrdinalIgnoreCase) && t.Length >= 3);
            return i >= 0 ? Unidades[i] : t;
        }
        private readonly CD_Insumo _datos = new();

        public List<Insumo> Listar(int idSede) => _datos.Listar(idSede);

        public Respuesta Guardar(Insumo i)
        {
            i.Codigo = i.Codigo?.Trim().ToUpper() ?? "";
            i.Nombre = i.Nombre?.Trim() ?? "";
            if (i.Nombre == "") return Respuesta.Error("El nombre es obligatorio");
            // Yesenia Quejada Rojas - Claude — 19/10/2026: el código y la categoría ya no se piden; el código se arma con el nombre.
            if (i.Codigo == "")
                i.Codigo = GenerarCodigo(i.Nombre, _datos.Listar(1).Where(x => x.IdInsumo != i.IdInsumo).Select(x => x.Codigo));
            if (i.Codigo.Length > 30) return Respuesta.Error("El código puede tener máximo 30 caracteres");
            if (!Unidades.Contains(i.UnidadMedida)) return Respuesta.Error("Unidad de medida no válida");
            if (i.StockMinimo < 0 || i.CostoUnitario < 0) return Respuesta.Error("Los valores no pueden ser negativos");
            if (i.UnidadMedida != "PAQ") i.UnidadesPorPaquete = null;
            else if (!(i.UnidadesPorPaquete > 1)) return Respuesta.Error("Indique cuántas unidades trae el paquete");
            i.PorConfirmar = i.PorConfirmar?.Trim() ?? "";
            if (i.PorConfirmar.Length > 300) return Respuesta.Error("El dato por confirmar puede tener máximo 300 caracteres");
            var r = _datos.Guardar(i);
            if (r.Resultado)
            {
                var n = GuardarPorConfirmar(r.Id, i.PorConfirmar);
                if (!n.Resultado) return Respuesta.Error("El insumo se guardó pero la nota no: " + n.Mensaje);
            }
            return r;
        }

        /// <summary>
        /// Guarda o borra (texto vacío) la nota de dato por confirmar. Borrar una nota en una base
        /// sin el script Insumos_PorConfirmar.sql no es un error: no había nada que borrar.
        /// </summary>
        private Respuesta GuardarPorConfirmar(int idInsumo, string nota)
        {
            var r = _datos.GuardarPendiente(idInsumo, nota);
            if (r.Resultado || nota == "") return Respuesta.Ok(idInsumo);
            return Respuesta.Error(r.Mensaje + " (ejecute BaseDatos/Insumos_PorConfirmar.sql en la base)");
        }

        // Yesenia Quejada Rojas - Claude — 10/11/2026: si el insumo ya se usó en un conteo, una venta u otro registro, la base
        // no deja borrarlo y antes salía el error en inglés sin terminar. Ahora se explica y la pantalla ofrece desactivarlo.
        public Respuesta Eliminar(int id)
        {
            var r = _datos.Eliminar(id);
            if (!r.Resultado && r.Mensaje.Contains("REFERENCE", StringComparison.OrdinalIgnoreCase))
                return Respuesta.Error("Este insumo ya tiene historial (conteos, compras o ventas) y no se puede borrar. Puede desactivarlo para que no se use más.");
            return r;
        }

        /// <summary>Código corto a partir del nombre ("Queso mozzarella" = QUEMOZ); agrega un número si ya existe.</summary>
        public static string GenerarCodigo(string nombre, IEnumerable<string> usados)
        {
            var limpio = new string(nombre.Normalize(System.Text.NormalizationForm.FormD)
                .Where(c => char.IsLetterOrDigit(c) || c == ' ').ToArray()).ToUpperInvariant();
            var palabras = limpio.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            var baseCodigo = string.Concat(palabras.Take(3).Select(p => p.Length > 3 ? p[..3] : p));
            if (baseCodigo == "") baseCodigo = "INS";
            var ocupados = new HashSet<string>(usados, StringComparer.OrdinalIgnoreCase);
            var codigo = baseCodigo;
            for (int n = 2; ocupados.Contains(codigo); n++) codigo = baseCodigo + n;
            return codigo;
        }

        /// <summary>
        /// Carga masiva desde la plantilla de Excel: crea o actualiza insumos por código (o por nombre si no trae código)
        /// y, si la fila trae stock, lo deja igual al contado con un ajuste de conteo físico.
        /// Primero valida todo; si hay errores no guarda nada.
        /// </summary>
        public ResultadoImportacion Importar(List<FilaImportacion> filas, int idSede, int idUsuario)
        {
            var res = new ResultadoImportacion();
            filas = filas.Where(f => !(string.IsNullOrWhiteSpace(f.Codigo) && string.IsNullOrWhiteSpace(f.Nombre))).ToList();
            if (filas.Count == 0) { res.Errores.Add("La plantilla no tiene filas con datos"); return res; }

            var lista = _datos.Listar(idSede);
            var porNombre = lista.GroupBy(i => i.Nombre.Trim(), StringComparer.OrdinalIgnoreCase).ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);
            var usados = new HashSet<string>(lista.Select(i => i.Codigo), StringComparer.OrdinalIgnoreCase);
            foreach (var f in filas)
            {
                f.Codigo = f.Codigo.Trim().ToUpper();
                f.Nombre = f.Nombre.Trim();
                f.UnidadMedida = UnidadDesdeTexto(f.UnidadMedida);
                if (f.Nombre == "") res.Errores.Add($"Fila {f.Fila}: falta el nombre");
                else if (f.Nombre.Length > 100) res.Errores.Add($"Fila {f.Fila}: el nombre tiene más de 100 caracteres");
                // Yesenia Quejada Rojas - Claude — 19/10/2026: el código es opcional; sin código se reconoce el insumo por su nombre o se crea uno.
                if (f.Codigo == "" && f.Nombre != "")
                {
                    if (porNombre.TryGetValue(f.Nombre, out var mismo)) f.Codigo = mismo.Codigo;
                    else { f.Codigo = GenerarCodigo(f.Nombre, usados); usados.Add(f.Codigo); }
                }
                if (f.Codigo.Length > 30) res.Errores.Add($"Fila {f.Fila}: el código tiene más de 30 caracteres");
                if (!Unidades.Contains(f.UnidadMedida)) res.Errores.Add($"Fila {f.Fila}: elija la unidad de la lista ({string.Join(", ", Unidades)})");
                if (f.StockMinimo < 0 || f.CostoUnitario < 0 || f.Stock < 0) res.Errores.Add($"Fila {f.Fila}: hay valores negativos");
                f.PorConfirmar = f.PorConfirmar?.Trim();
                if (f.PorConfirmar?.Length > 300) res.Errores.Add($"Fila {f.Fila}: el dato por confirmar tiene más de 300 caracteres");
            }
            foreach (var g in filas.Where(f => f.Codigo != "").GroupBy(f => f.Codigo).Where(g => g.Count() > 1))
                res.Errores.Add($"El insumo {g.Key} está repetido en las filas {string.Join(", ", g.Select(f => f.Fila))}");
            if (res.Errores.Count > 0) return res;

            var existentes = lista.ToDictionary(i => i.Codigo, StringComparer.OrdinalIgnoreCase);
            var conteo = new Conteo { Observacion = "Carga de inventario desde Excel" };
            foreach (var f in filas)
            {
                existentes.TryGetValue(f.Codigo, out var actual);
                var r = _datos.Guardar(new Insumo
                {
                    IdInsumo = actual?.IdInsumo ?? 0,
                    Codigo = f.Codigo,
                    Nombre = f.Nombre,
                    IdCategoria = actual?.IdCategoria ?? 0,
                    UnidadMedida = f.UnidadMedida,
                    StockMinimo = f.StockMinimo,
                    CostoUnitario = f.CostoUnitario,
                    Activo = actual?.Activo ?? true
                });
                if (!r.Resultado) { res.Errores.Add($"Fila {f.Fila} ({f.Codigo}): {r.Mensaje}"); continue; }
                if (actual == null) res.Creados++; else res.Actualizados++;
                if (f.PorConfirmar != null)
                {
                    var n = GuardarPorConfirmar(r.Id, f.PorConfirmar);
                    if (!n.Resultado) res.Errores.Add($"Fila {f.Fila} ({f.Codigo}): {n.Mensaje}");
                }
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
            // Yesenia Quejada Rojas - Claude — 28/10/2026: el conteo también puede traer solo costos corregidos.
            c.Costos = c.Costos?.GroupBy(k => k.IdInsumo).Select(g => g.Last()).ToList() ?? new();
            if (c.Detalle.Count == 0 && c.Costos.Count == 0) return Respuesta.Error("Ingrese al menos una cantidad contada o un costo");
            if (c.Detalle.Any(d => d.StockContado < 0)) return Respuesta.Error("Las cantidades no pueden ser negativas");
            // Yesenia Quejada Rojas - Claude — 13/11/2026: modo "Sumar lo que llegó". Se suma a la existencia de este momento (no a la
            // que se vio al abrir la pantalla) y se guarda como un conteo normal con el total, así el SP no cambia.
            if (c.Sumar && c.Detalle.Count > 0)
            {
                var stock = new CN_Insumo().Listar(idSede).ToDictionary(i => i.IdInsumo, i => i.Stock);
                foreach (var d in c.Detalle) d.StockContado += stock.TryGetValue(d.IdInsumo, out var s) ? s : 0;
                if (string.IsNullOrWhiteSpace(c.Observacion)) c.Observacion = "Llegó mercancía (sumado)";
            }
            if (c.Costos.Any(k => k.CostoUnitario < 0 || k.CostoUnitario > 9999999999.99m)) return Respuesta.Error("Los costos no pueden ser negativos");
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
            if (m.IdInsumo > 0 && m.Cantidad == 0) return Respuesta.Error("Indique cuánto insumo gasta cada vez que se elige");
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

        public Respuesta Abrir(int idSede, int idUsuario, decimal baseInicial, decimal fondoNegocio) =>
            baseInicial < 0 || fondoNegocio < 0 ? Respuesta.Error("La base y el fondo no pueden ser negativos") : _datos.Abrir(idSede, idUsuario, baseInicial, fondoNegocio);

        public decimal FondoSugerido(int idSede) => _datos.FondoSugerido(idSede);

        // Yesenia Quejada Rojas - Claude — 04/11/2026: si al abrir se escribió mal (o no se escribió) la base de caja, se corrige mientras la caja siga abierta.
        public Respuesta EditarBase(int idSede, int idUsuario, decimal baseInicial) =>
            baseInicial < 0 || baseInicial > 9999999999.99m || decimal.Round(baseInicial, 2) != baseInicial
                ? Respuesta.Error("La base de caja debe ser un valor positivo con máximo dos decimales")
                : _datos.EditarBase(idSede, idUsuario, baseInicial);

        public Respuesta Cerrar(int idSede, int idUsuario, decimal efectivoContado, string? observacion) =>
            efectivoContado < 0 ? Respuesta.Error("El efectivo contado no puede ser negativo") : _datos.Cerrar(idSede, idUsuario, efectivoContado, observacion);

        // Yesenia Quejada Rojas - Claude — 11/11/2026: al cerrar la caja también se cuentan las cajas de empaque (insumos activos cuyo nombre
        // empieza por "Caja", p. ej. "Caja C1 hamburguesa" y "Caja de empaque"). Lo contado queda como un conteo de inventario normal, así
        // que corrige el stock y se ve en Inventario > Contar inventario. Solo acepta esas cajas, para que el cajero no toque otros insumos.
        private static readonly Regex NombreCaja = new(@"^\s*cajas?\b", RegexOptions.IgnoreCase);

        // Yesenia Quejada Rojas - Claude — 13/11/2026: solo las cajas que salieron con las ventas de esta caja (las que no se usaron no se piden).
        public List<Insumo> CajasEmpaque(int idSede)
        {
            var vendidas = _datos.InsumosVendidos(idSede).ToHashSet();
            return new CN_Insumo().Listar(idSede)
                .Where(i => i.Activo && i.ControlaStock && NombreCaja.IsMatch(i.Nombre ?? "") && vendidas.Contains(i.IdInsumo))
                .OrderBy(i => i.Nombre).ToList();
        }

        public Respuesta ContarCajas(int idSede, int idUsuario, List<ConteoItem>? detalle)
        {
            var permitidas = CajasEmpaque(idSede).Select(i => i.IdInsumo).ToHashSet();
            var lista = detalle?.Where(d => permitidas.Contains(d.IdInsumo)).GroupBy(d => d.IdInsumo).Select(g => g.Last()).ToList() ?? new();
            if (lista.Count == 0) return Respuesta.Error("No llegó ninguna caja contada");
            if (lista.Any(d => d.StockContado < 0 || d.StockContado > 99999 || d.StockContado != Math.Floor(d.StockContado)))
                return Respuesta.Error("Las cajas se cuentan en números enteros, sin negativos");
            var caja = Actual(idSede);
            return new CN_Conteo().Registrar(idSede, idUsuario, new Conteo
            {
                Observacion = caja == null ? "Cajas de empaque contadas" : $"Cajas de empaque contadas al cerrar la caja N° {caja.IdCaja}",
                Detalle = lista
            });
        }

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
        // Yesenia Quejada Rojas - Claude — 30/10/2026: RAPPI = el cliente pagó en la app de Rappi (no es efectivo de la caja).
        private static readonly string[] Metodos = { "EFECTIVO", "TARJETA", "TRANSFERENCIA", "RAPPI" };
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
            // Yesenia Quejada Rojas - Claude — 31/10/2026: cajas de empaque del pedido (0 a 99); el SP y el CHECK de la tabla lo vuelven a validar.
            if (v.Cajas < 0 || v.Cajas > 99) return Respuesta.Error("Las cajas deben estar entre 0 y 99");
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

        public Respuesta ConfirmarPago(int idSede, int idUsuario, int idVenta, bool confirmado) =>
            idVenta <= 0 ? Respuesta.Error("Venta no válida") : _datos.ConfirmarPago(idSede, idUsuario, idVenta, confirmado);

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
        private readonly CD_Compra _datos = new();

        // Yesenia Quejada Rojas - Claude — 11/11/2026: los insumos quitados de la lista (p. ej. la bolsa ziploc) ya no salen en la pantalla,
        // el Excel ni la tirilla. Siguen en el inventario y se pueden volver a incluir.
        public List<OrdenCompraItem> Sugerida(int idSede)
        {
            var fuera = _datos.FueraDeLista().Select(f => f.IdInsumo).ToHashSet();
            return _datos.Sugerida(idSede).Where(o => !fuera.Contains(o.IdInsumo)).ToList();
        }

        public List<InsumoFueraCompra> FueraDeLista() => _datos.FueraDeLista();

        public Respuesta CambiarEnLista(int idInsumo, bool fuera)
        {
            if (idInsumo <= 0) return Respuesta.Error("Insumo no válido");
            var r = _datos.CambiarEnLista(idInsumo, fuera);
            if (!r.Resultado && r.Mensaje.Contains("SP_COMPRA_FUERA_GUARDAR", StringComparison.OrdinalIgnoreCase))
                return Respuesta.Error("Falta ejecutar en la base de datos el script 08_Lista_Compras.sql");
            return r;
        }

        /// <summary>Lista para la tirilla: si llegan cantidades (lo que el administrador dejó marcado en pantalla) solo salen esos
        /// insumos con esa cantidad; si no llega nada sale la lista sugerida completa.</summary>
        public List<OrdenCompraItem> ParaTirilla(int idSede, Dictionary<int, decimal>? cantidades)
        {
            var lista = Sugerida(idSede);
            if (cantidades == null) return lista;
            return lista.Where(o => cantidades.TryGetValue(o.IdInsumo, out var c) && c > 0)
                .Select(o =>
                {
                    o.CantidadSugerida = Math.Round(cantidades[o.IdInsumo], 3);
                    o.CostoEstimado = Math.Round(o.CantidadSugerida * o.CostoUnitario, 2);
                    return o;
                }).ToList();
        }
    }

    public class CN_Reporte
    {
        public Reporte Obtener(int idSede, DateTime inicio, DateTime fin) =>
            new CD_Reporte().Obtener(idSede, inicio, fin <= inicio ? inicio : fin);

        public List<Actividad> Actividad(int idSede, DateTime inicio, DateTime fin) =>
            new CD_Reporte().Actividad(idSede, inicio, fin <= inicio ? inicio : fin);
    }

    public class CN_Dashboard
    {
        public Dashboard Obtener(int idSede) => new CD_Dashboard().Obtener(idSede);
    }
}
