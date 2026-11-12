using CapaDatos;
using CapaEntidad;

namespace CapaNegocio;

// Yesenia Quejada Rojas - Claude — 28/10/2026: mesas y carta pública.
public class CN_Mesa
{
    private readonly CD_Mesa _datos = new();
    public List<Mesa> Listar(int idSede) => _datos.Listar(idSede);

    public Respuesta Guardar(int idSede, Mesa m)
    {
        m.Nombre = m.Nombre?.Trim() ?? "";
        if (m.Nombre == "" || m.Nombre.Length > 30) return Respuesta.Error("Escriba el nombre o número de la mesa (máximo 30 caracteres)");
        if (m.Puestos < 1 || m.Puestos > 50) return Respuesta.Error("Los puestos deben estar entre 1 y 50");
        return _datos.Guardar(idSede, m);
    }

    public Respuesta Eliminar(int idSede, int idMesa) => _datos.Eliminar(idSede, idMesa);
}

public class CN_Carta
{
    public CartaPublica? Obtener(int idSede, int? idMesa)
    {
        var c = new CD_Carta().Obtener(idSede, idMesa);
        if (c != null)
        {
            c.Configuracion = new CN_Configuracion().Obtener();
            c.IdMesa = c.Mesa == "" ? 0 : idMesa ?? 0;
        }
        return c;
    }
}

// Yesenia Quejada Rojas - Claude — 29/10/2026: carrito de la carta digital. Lo envía un cliente sin sesión, así que se limpia
// y se limita aquí; el SP vuelve a validar mesa, productos y cantidades y pone los precios de la carta.
public class CN_PedidoCarta
{
    private static readonly string[] EstadosPersonal = { "CONFIRMADO", "CERRADO", "RECHAZADO" };
    private readonly CD_PedidoCarta _datos = new();

    public PedidoCartaEnviado Registrar(PedidoCartaNuevo? p)
    {
        if (p == null || p.IdMesa <= 0) return new PedidoCartaEnviado { Mensaje = "Para pedir desde la carta escanee el QR de su mesa." };
        p.Lineas = (p.Lineas ?? new()).Where(l => l.IdProducto > 0 && l.Cantidad > 0).ToList();
        if (p.Lineas.Count == 0) return new PedidoCartaEnviado { Mensaje = "El carrito está vacío" };
        if (p.Lineas.Count > 30 || p.Lineas.Any(l => l.Cantidad > 20)) return new PedidoCartaEnviado { Mensaje = "Cada producto admite de 1 a 20 unidades" };
        p.ClienteNombre = Recortar(p.ClienteNombre, 60);
        p.Nota = Recortar(p.Nota, 150);
        foreach (var l in p.Lineas)
        {
            l.Notas = Recortar(l.Notas, 150);
            l.Modificadores = (l.Modificadores ?? new()).Where(x => x > 0).Distinct().Take(20).ToList();
            l.Quitados = (l.Quitados ?? new()).Where(x => x > 0).Distinct().Take(20).ToList();
        }
        return _datos.Registrar(p);
    }

    public PedidoCartaEnviado? Estado(Guid codigo) => codigo == Guid.Empty ? null : _datos.Estado(codigo);

    public List<PedidoCarta> Listar(int idSede) => _datos.Listar(idSede);

    public Respuesta Atender(int idSede, int idPedidoCarta, string? estado, int idUsuario, int? idVenta)
    {
        estado = estado?.Trim().ToUpperInvariant() ?? "";
        if (!EstadosPersonal.Contains(estado)) return Respuesta.Error("Estado no válido");
        return _datos.Atender(idSede, idPedidoCarta, estado, idUsuario, idVenta);
    }

    private static string Recortar(string? texto, int maximo)
    {
        var t = (texto ?? "").Trim();
        return t.Length > maximo ? t[..maximo] : t;
    }
}

// Yesenia Quejada Rojas - Claude — 30/10/2026: pedidos "Por cobrar" en la base de datos para que la tablet y el computador
// vean los mismos. No registran venta ni descuentan inventario: solo guardan lo que había en pantalla.
public class CN_PedidoEspera
{
    private static readonly string[] Tipos = { "MESA", "LLEVAR", "DOMICILIO" };
    private readonly CD_PedidoEspera _datos = new();

    public List<PedidoEspera> Listar(int idSede) => _datos.Listar(idSede);

    public Respuesta Guardar(int idSede, int idUsuario, PedidoEspera p)
    {
        if (p == null) return Respuesta.Error("El pedido no es válido");
        p.Nombre = (p.Nombre ?? "").Trim();
        if (p.Nombre.Length > 100) p.Nombre = p.Nombre[..100];
        if (p.Nombre == "") p.Nombre = "Pedido";
        p.TipoPedido = (p.TipoPedido ?? "").Trim().ToUpperInvariant();
        if (!Tipos.Contains(p.TipoPedido)) return Respuesta.Error("Tipo de pedido no válido");
        if (string.IsNullOrWhiteSpace(p.Datos) || p.Datos.Length > 200_000) return Respuesta.Error("El pedido no es válido");
        try { using var _ = System.Text.Json.JsonDocument.Parse(p.Datos); }
        catch (System.Text.Json.JsonException) { return Respuesta.Error("El pedido no es válido"); }
        return _datos.Guardar(idSede, idUsuario, p);
    }

    public Respuesta Eliminar(int idSede, int idPedidoEspera) =>
        idPedidoEspera <= 0 ? Respuesta.Error("Pedido no válido") : _datos.Eliminar(idSede, idPedidoEspera);

    public Respuesta Consecutivo(int idSede) => _datos.Consecutivo(idSede);
}
