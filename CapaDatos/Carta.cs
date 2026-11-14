using CapaEntidad;
using Microsoft.Data.SqlClient;
using static CapaDatos.Conexion;

namespace CapaDatos;

// Yesenia Quejada Rojas - Claude — 28/10/2026: mesas y carta pública.
public class CD_Mesa
{
    public List<Mesa> Listar(int idSede) =>
        Conexion.Listar("SP_MESA_LISTAR", dr => new Mesa
        {
            IdMesa = dr.Entero("IdMesa"),
            Nombre = dr.Texto("Nombre"),
            Puestos = dr.Entero("Puestos"),
            Activo = dr.Bool("Activo")
        }, P("@IdSede", idSede));

    public Respuesta Guardar(int idSede, Mesa m) =>
        Ejecutar("SP_MESA_GUARDAR", P("@IdSede", idSede), P("@IdMesa", m.IdMesa), P("@Nombre", m.Nombre),
            P("@Puestos", (byte)m.Puestos), P("@Activo", m.Activo));

    public Respuesta Eliminar(int idSede, int idMesa) =>
        Ejecutar("SP_MESA_ELIMINAR", P("@IdSede", idSede), P("@IdMesa", idMesa));
}

public class CD_Carta
{
    /// <summary>Carta de la sede; null si la sede no existe o está inactiva.</summary>
    public CartaPublica? Obtener(int idSede, int? idMesa)
    {
        CartaPublica? c = null;
        Leer("SP_CARTA_PUBLICA", dr =>
        {
            if (!dr.Read()) return;
            c = new CartaPublica
            {
                IdSede = dr.Entero("IdSede"),
                Sede = dr.Texto("Sede"),
                Direccion = dr.Texto("Direccion"),
                Telefono = dr.Texto("Telefono"),
                Mesa = dr.Texto("Mesa")
            };
            dr.NextResult();
            while (dr.Read())
                c.Productos.Add(new CartaProducto
                {
                    IdProducto = dr.Entero("IdProducto"),
                    Nombre = dr.Texto("Nombre"),
                    Descripcion = dr.Texto("Descripcion"),
                    IdCategoriaMenu = dr.Entero("IdCategoriaMenu"),
                    CategoriaMenu = dr.Texto("CategoriaMenu"),
                    Icono = dr.Texto("Icono"),
                    Precio = dr.Decimal("Precio"),
                    ImagenUrl = dr.Texto("ImagenUrl"),
                    Agotado = dr.Bool("Agotado")
                });
            dr.NextResult();
            while (dr.Read())
                c.Adiciones.Add(new CartaAdicion { Grupo = dr.Texto("Grupo"), Nombre = dr.Texto("Nombre"), Precio = dr.Decimal("Precio") });
            // Yesenia Quejada Rojas - Claude — 29/10/2026: opciones de cada producto para el carrito.
            dr.NextResult();
            while (dr.Read())
                c.Opciones.Add(new CartaOpcion
                {
                    IdProducto = dr.Entero("IdProducto"), IdModificador = dr.Entero("IdModificador"), Nombre = dr.Texto("Nombre"),
                    Precio = dr.Decimal("Precio"), Grupo = dr.Texto("Grupo")
                });
            dr.NextResult();
            while (dr.Read())
                c.Ingredientes.Add(new CartaIngrediente { IdProducto = dr.Entero("IdProducto"), IdInsumo = dr.Entero("IdInsumo"), Nombre = dr.Texto("Nombre") });
        }, P("@IdSede", idSede), P("@IdMesa", idMesa));
        return c;
    }
}

// Yesenia Quejada Rojas - Claude — 29/10/2026: pedidos del carrito de la carta digital.
public class CD_PedidoCarta
{
    public PedidoCartaEnviado Registrar(PedidoCartaNuevo p)
    {
        var lineas = new System.Data.DataTable();
        lineas.Columns.Add("Linea", typeof(int));
        lineas.Columns.Add("IdProducto", typeof(int));
        lineas.Columns.Add("Cantidad", typeof(int));
        lineas.Columns.Add("Notas", typeof(string));
        var mods = new System.Data.DataTable();
        mods.Columns.Add("Linea", typeof(int));
        mods.Columns.Add("IdModificador", typeof(int));
        var quitados = new System.Data.DataTable();
        quitados.Columns.Add("Linea", typeof(int));
        quitados.Columns.Add("IdInsumo", typeof(int));
        for (int i = 0; i < p.Lineas.Count; i++)
        {
            var l = p.Lineas[i];
            lineas.Rows.Add(i + 1, l.IdProducto, l.Cantidad, l.Notas ?? "");
            foreach (var m in l.Modificadores.Distinct()) mods.Rows.Add(i + 1, m);
            foreach (var q in l.Quitados.Distinct()) quitados.Rows.Add(i + 1, q);
        }

        var codigo = new Microsoft.Data.SqlClient.SqlParameter("@Codigo", System.Data.SqlDbType.UniqueIdentifier)
            { Direction = System.Data.ParameterDirection.Output };
        // Yesenia Quejada Rojas - Claude — 13/11/2026: tipo de pedido, sede y datos del domicilio (script 012).
        var r = Ejecutar("SP_PEDIDO_CARTA_REGISTRAR", P("@IdMesa", p.IdMesa > 0 ? p.IdMesa : (object?)null), P("@ClienteNombre", p.ClienteNombre ?? ""),
            P("@Nota", p.Nota ?? ""), Tabla("@Lineas", "ELineaVenta", lineas),
            Tabla("@Modificadores", "ELineaModificador", mods), Tabla("@Quitados", "ELineaQuitado", quitados), codigo,
            P("@IdSede", p.IdSede), P("@TipoPedido", p.TipoPedido ?? "MESA"), P("@Telefono", p.Telefono ?? ""), P("@Direccion", p.Direccion ?? ""));
        return new PedidoCartaEnviado
        {
            Resultado = r.Resultado, Mensaje = r.Mensaje, Id = r.Id, Estado = r.Resultado ? "PENDIENTE" : "",
            Codigo = r.Resultado && codigo.Value is Guid g ? g : null
        };
    }

    public PedidoCartaEnviado? Estado(Guid codigo)
    {
        PedidoCartaEnviado? e = null;
        Leer("SP_PEDIDO_CARTA_ESTADO", dr =>
        {
            if (dr.Read()) e = new PedidoCartaEnviado { Resultado = true, Id = dr.Entero("IdPedidoCarta"), Estado = dr.Texto("Estado") };
        }, P("@Codigo", codigo));
        return e;
    }

    public List<PedidoCarta> Listar(int idSede)
    {
        var lista = new List<PedidoCarta>();
        Leer("SP_PEDIDO_CARTA_LISTAR", dr =>
        {
            while (dr.Read())
                lista.Add(new PedidoCarta
                {
                    IdPedidoCarta = dr.Entero("IdPedidoCarta"), Mesa = dr.Texto("Mesa"), ClienteNombre = dr.Texto("ClienteNombre"),
                    Nota = dr.Texto("Nota"), Total = dr.Decimal("Total"), Estado = dr.Texto("Estado"), Segundos = dr.Entero("Segundos"),
                    TipoPedido = dr.Texto("TipoPedido"), Telefono = dr.Texto("Telefono"), Direccion = dr.Texto("Direccion")
                });
            var porId = lista.ToDictionary(x => x.IdPedidoCarta);
            dr.NextResult();
            while (dr.Read())
                if (porId.TryGetValue(dr.Entero("IdPedidoCarta"), out var pc))
                    pc.Lineas.Add(new PedidoCartaLinea
                    {
                        Linea = dr.Entero("Linea"), IdProducto = dr.Entero("IdProducto"), Nombre = dr.Texto("Nombre"), Cantidad = dr.Entero("Cantidad"),
                        PrecioUnitario = dr.Decimal("PrecioUnitario"), Notas = dr.Texto("Notas")
                    });
            // Yesenia Quejada Rojas - Claude — 29/10/2026: salsas/adiciones y "Sin ..." de cada línea.
            PedidoCartaLinea? LineaDe(SqlDataReader x) =>
                porId.TryGetValue(x.Entero("IdPedidoCarta"), out var pc) ? pc.Lineas.FirstOrDefault(l => l.Linea == x.Entero("Linea")) : null;
            var con = new Dictionary<PedidoCartaLinea, List<string>>();
            var sin = new Dictionary<PedidoCartaLinea, List<string>>();
            dr.NextResult();
            while (dr.Read())
                if (LineaDe(dr) is { } l) { l.Modificadores.Add(dr.Entero("IdModificador")); (con.TryGetValue(l, out var n) ? n : con[l] = new()).Add(dr.Texto("Nombre")); }
            dr.NextResult();
            while (dr.Read())
                if (LineaDe(dr) is { } l) { l.Quitados.Add(dr.Entero("IdInsumo")); (sin.TryGetValue(l, out var n) ? n : sin[l] = new()).Add(dr.Texto("Nombre")); }
            foreach (var l in lista.SelectMany(x => x.Lineas))
                l.Opciones = string.Join(" · ", new[]
                {
                    con.TryGetValue(l, out var c) ? "Con: " + string.Join(", ", c) : "",
                    sin.TryGetValue(l, out var s) ? "Sin: " + string.Join(", ", s) : ""
                }.Where(t => t != ""));
        }, P("@IdSede", idSede));
        return lista;
    }

    public Respuesta Atender(int idSede, int idPedidoCarta, string estado, int idUsuario, int? idVenta) =>
        Ejecutar("SP_PEDIDO_CARTA_ATENDER", P("@IdSede", idSede), P("@IdPedidoCarta", idPedidoCarta), P("@Estado", estado),
            P("@IdUsuario", idUsuario), P("@IdVenta", idVenta));
}

// Yesenia Quejada Rojas - Claude — 30/10/2026: pedidos "Por cobrar" compartidos entre equipos y número del día para "Pedido N".
public class CD_PedidoEspera
{
    public List<PedidoEspera> Listar(int idSede) =>
        Conexion.Listar("SP_PEDIDO_ESPERA_LISTAR", dr => new PedidoEspera
        {
            IdPedidoEspera = dr.Entero("IdPedidoEspera"),
            Nombre = dr.Texto("Nombre"),
            TipoPedido = dr.Texto("TipoPedido"),
            Datos = dr.Texto("Datos"),
            Minutos = dr.Entero("Minutos"),
            Usuario = dr.Texto("Usuario")
        }, P("@IdSede", idSede));

    public Respuesta Guardar(int idSede, int idUsuario, PedidoEspera p) =>
        Ejecutar("SP_PEDIDO_ESPERA_GUARDAR", P("@IdSede", idSede), P("@IdUsuario", idUsuario), P("@IdPedidoEspera", Math.Max(0, p.IdPedidoEspera)), P("@Nombre", p.Nombre),
            P("@TipoPedido", p.TipoPedido), P("@Datos", p.Datos));

    public Respuesta Eliminar(int idSede, int idPedidoEspera) =>
        Ejecutar("SP_PEDIDO_ESPERA_ELIMINAR", P("@IdSede", idSede), P("@IdPedidoEspera", idPedidoEspera));

    public Respuesta Consecutivo(int idSede) => Ejecutar("SP_PEDIDO_CONSECUTIVO_SIGUIENTE", P("@IdSede", idSede));
}
