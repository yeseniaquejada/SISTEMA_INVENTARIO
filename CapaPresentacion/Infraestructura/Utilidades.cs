using System.Globalization;
using System.Security.Claims;
using ClosedXML.Excel;
using Microsoft.AspNetCore.Mvc;

namespace CapaPresentacion.Infraestructura;

public static class Claves
{
    public const string IdSede = "IdSede";
    public const string Sede = "Sede";
    public const string Admin = "ADMINISTRADOR";
    // Yesenia Quejada Rojas - Claude — 19/10/2026: tres perfiles por defecto (administrador, cajero/cocina y domiciliario).
    public const string Cajero = "CAJERO";
    public const string Domiciliario = "DOMICILIARIO";
    /// <summary>Quien atiende el local: vende, cocina y maneja la caja (el domiciliario no).</summary>
    public const string Local = Admin + "," + Cajero;
}

public static class UsuarioActual
{
    public static int Id(this ClaimsPrincipal u) => int.Parse(u.FindFirstValue(ClaimTypes.NameIdentifier)!);
    public static int IdSede(this ClaimsPrincipal u) => int.Parse(u.FindFirstValue(Claves.IdSede) ?? "1");
    public static string Sede(this ClaimsPrincipal u) => u.FindFirstValue(Claves.Sede) ?? "";
    public static bool EsAdmin(this ClaimsPrincipal u) => u.IsInRole(Claves.Admin);
    public static bool EsDomiciliario(this ClaimsPrincipal u) => u.IsInRole(Claves.Domiciliario);
}

public static class Colores
{
    /// <summary>Devuelve blanco o casi negro según qué contraste mejor sobre el color dado.</summary>
    public static string TextoSobre(string hex)
    {
        if (hex is not { Length: 7 }) return "#ffffff";
        double C(int i)
        {
            var c = int.Parse(hex.Substring(i, 2), NumberStyles.HexNumber) / 255.0;
            return c <= 0.03928 ? c / 12.92 : Math.Pow((c + 0.055) / 1.055, 2.4);
        }
        var l = 0.2126 * C(1) + 0.7152 * C(3) + 0.0722 * C(5);
        return l > 0.4 ? "#1b1b1b" : "#ffffff";
    }
}

/// <summary>Guarda imágenes subidas (logo, fotos de productos) en wwwroot/uploads.</summary>
public static class Archivos
{
    private static readonly string[] Extensiones = { ".jpg", ".jpeg", ".png", ".webp", ".gif" };
    public const long TamanoMaximo = 3 * 1024 * 1024;

    public static async Task<(string? url, string? error)> GuardarImagen(IFormFile? archivo, IWebHostEnvironment env, string prefijo)
    {
        if (archivo == null || archivo.Length == 0) return (null, "Seleccione una imagen");
        if (archivo.Length > TamanoMaximo) return (null, "La imagen no puede pesar más de 3 MB");
        var ext = Path.GetExtension(archivo.FileName).ToLowerInvariant();
        if (!Extensiones.Contains(ext) || !archivo.ContentType.StartsWith("image/"))
            return (null, "Solo se permiten imágenes JPG, PNG, WEBP o GIF");

        var carpeta = Path.Combine(env.WebRootPath, "uploads");
        Directory.CreateDirectory(carpeta);
        var nombre = $"{prefijo}-{Guid.NewGuid():N}{ext}";
        await using var fs = File.Create(Path.Combine(carpeta, nombre));
        await archivo.CopyToAsync(fs);
        return ($"/uploads/{nombre}", null);
    }
}

/// <summary>Genera archivos de Excel a partir de listas.</summary>
public static class Excel
{
    public static FileContentResult Archivo<T>(string nombre, string hoja, IEnumerable<T> filas, params (string titulo, Func<T, object?> valor)[] columnas)
    {
        using var wb = new XLWorkbook();
        var ws = wb.Worksheets.Add(hoja);
        for (int c = 0; c < columnas.Length; c++)
        {
            var celda = ws.Cell(1, c + 1);
            celda.Value = columnas[c].titulo;
            celda.Style.Font.Bold = true;
            celda.Style.Fill.BackgroundColor = XLColor.FromHtml("#EEEEEE");
        }
        int f = 2;
        foreach (var fila in filas)
        {
            for (int c = 0; c < columnas.Length; c++)
                ws.Cell(f, c + 1).Value = XLCellValue.FromObject(columnas[c].valor(fila));
            f++;
        }
        ws.Columns().AdjustToContents();
        ws.SheetView.FreezeRows(1);
        return Descargar(wb, nombre);
    }

    private static FileContentResult Descargar(XLWorkbook wb, string nombre)
    {
        using var ms = new MemoryStream();
        wb.SaveAs(ms);
        return new FileContentResult(ms.ToArray(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        {
            FileDownloadName = $"{nombre}-{DateTime.Now:yyyyMMdd-HHmm}.xlsx"
        };
    }

    /* ---------- Plantilla de carga de inventario ---------- */
    /* Yesenia Quejada Rojas - Claude — 19/10/2026. Plantilla más sencilla: sin categoría, código opcional,
       unidad elegida de una lista, números validados y formato General (con "#,##0.###" Excel mostraba "120,"). */

    private const int FilasPlantilla = 1000;

    private static readonly (string titulo, string ayuda, bool obligatoria)[] ColumnasInventario =
    {
        ("Nombre del insumo", "Escriba el nombre, por ejemplo: Pan de hamburguesa.", true),
        ("Unidad", "Elija de la lista cómo se cuenta este insumo.", true),
        ("Cantidad que hay hoy", "Cuente lo que hay en el local hoy. Si la deja vacía, no se cambia.", false),
        ("Avisar cuando queden", "El sistema avisa que hay que comprar cuando queden esta cantidad o menos.", false),
        ("Costo por unidad", "Lo que le cuesta una unidad. Sirve para calcular el costo de cada producto.", false),
        ("Código (opcional)", "Déjelo vacío y el sistema lo crea. Solo cámbielo si ya usa códigos propios.", false),
    };

    /// <summary>
    /// Plantilla para configurar o actualizar el inventario: trae los insumos actuales,
    /// la unidad como lista desplegable y una hoja de instrucciones.
    /// </summary>
    public static FileContentResult PlantillaInventario(string nombre, IEnumerable<CapaEntidad.Insumo> insumos)
    {
        using var wb = new XLWorkbook();
        var ws = wb.Worksheets.Add("Inventario");
        var ins = wb.Worksheets.Add("Instrucciones");
        var listas = wb.Worksheets.Add("Listas");

        for (int c = 0; c < ColumnasInventario.Length; c++)
        {
            var (titulo, ayuda, obligatoria) = ColumnasInventario[c];
            var celda = ws.Cell(1, c + 1);
            celda.Value = titulo + (obligatoria ? " *" : "");
            celda.Style.Font.Bold = true;
            celda.Style.Font.FontColor = XLColor.White;
            celda.Style.Fill.BackgroundColor = XLColor.FromHtml(obligatoria ? "#C8322B" : c == 2 ? "#B7791F" : "#555555");
            celda.Style.Alignment.WrapText = true;
            celda.Style.Alignment.Vertical = XLAlignmentVerticalValues.Center;
            // Mensaje que aparece al seleccionar cualquier celda de la columna
            var dvAyuda = ws.Range(2, c + 1, FilasPlantilla, c + 1).CreateDataValidation();
            dvAyuda.InputTitle = titulo;
            dvAyuda.InputMessage = ayuda;
            dvAyuda.ShowInputMessage = true;
            if (c >= 2 && c <= 4)
            {
                dvAyuda.Decimal.EqualOrGreaterThan(0);
                dvAyuda.ErrorTitle = "Número no válido";
                dvAyuda.ErrorMessage = "Escriba solo números, sin puntos de miles ni símbolos. Ejemplo: 120 o 2,5";
            }
            else if (c == 1)
            {
                var unidades = CapaNegocio.CN_Insumo.UnidadesTexto;
                for (int k = 0; k < unidades.Length; k++) listas.Cell(k + 1, 1).Value = unidades[k];
                dvAyuda.List(listas.Range(1, 1, unidades.Length, 1), true);
                dvAyuda.ErrorTitle = "Unidad no válida";
                dvAyuda.ErrorMessage = "Elija una unidad de la lista desplegable.";
            }
        }
        ws.Row(1).Height = 32;

        int f = 2;
        foreach (var i in insumos.Where(i => i.Activo))
        {
            ws.Cell(f, 1).Value = i.Nombre;
            var u = Array.IndexOf(CapaNegocio.CN_Insumo.Unidades, i.UnidadMedida);
            ws.Cell(f, 2).Value = u >= 0 ? CapaNegocio.CN_Insumo.UnidadesTexto[u] : i.UnidadMedida;
            ws.Cell(f, 3).Value = i.Stock;
            ws.Cell(f, 4).Value = i.StockMinimo;
            ws.Cell(f, 5).Value = i.CostoUnitario;
            ws.Cell(f, 6).Value = i.Codigo;
            f++;
        }
        ws.Range(2, 3, FilasPlantilla, 5).Style.NumberFormat.Format = "General";
        ws.Range(2, 3, FilasPlantilla, 3).Style.Fill.BackgroundColor = XLColor.FromHtml("#FFF7D6");
        ws.Range(2, 6, FilasPlantilla, 6).Style.Font.FontColor = XLColor.FromHtml("#777777");

        ws.Column(1).Width = 36;
        ws.Column(2).Width = 18;
        ws.Columns(3, 5).Width = 16;
        ws.Column(6).Width = 18;
        ws.SheetView.FreezeRows(1);
        listas.Hide();

        string[] texto =
        {
            "CÓMO LLENAR ESTA PLANTILLA",
            "",
            "1. En la hoja \"Inventario\" escriba una fila por cada insumo (lo que compra para preparar: pan, carne, queso, gaseosas...).",
            "2. Las columnas con * son obligatorias: el nombre y la unidad. La unidad se elige de la lista, no hay que escribirla.",
            "3. \"Cantidad que hay hoy\" (amarilla): lo que contó en el local. Si la deja vacía, la cantidad del sistema no cambia.",
            "4. \"Avisar cuando queden\": cuando el inventario baje a esa cantidad, el sistema le avisa que debe comprar.",
            "5. \"Costo por unidad\": lo que le cuesta cada unidad. Escriba solo números, sin $ ni puntos (ejemplo: 1500).",
            "6. El código es opcional. Si lo deja vacío, el sistema lo crea solo.",
            "7. Guarde el archivo y súbalo en Configuración > Insumos > Subir plantilla.",
            "",
            "Si algo está mal, el sistema le dice en qué fila y no guarda nada, para que lo corrija y lo vuelva a subir.",
            "",
            "Ejemplo:",
        };
        for (int k = 0; k < texto.Length; k++) ins.Cell(k + 1, 1).Value = texto[k];
        ins.Cell(1, 1).Style.Font.Bold = true;
        ins.Cell(1, 1).Style.Font.FontSize = 14;
        int e = texto.Length + 1;
        object[][] ejemplo =
        {
            ColumnasInventario.Select(x => (object)x.titulo).ToArray(),
            new object[] { "Pan de hamburguesa", "Unidad (UND)", 120, 30, 1000, "" },
            new object[] { "Queso mozzarella (tajada)", "Porción (PORC)", 200, 40, 500, "" },
            new object[] { "Carne de res", "Kilogramo (KG)", 2.5, 1, 32000, "" },
        };
        for (int r = 0; r < ejemplo.Length; r++)
            for (int c = 0; c < ejemplo[r].Length; c++)
                ins.Cell(e + r, c + 1).Value = XLCellValue.FromObject(ejemplo[r][c]);
        ins.Row(e).Style.Font.Bold = true;
        ins.Column(1).Width = 30;
        ins.Columns(2, 6).Width = 18;

        return Descargar(wb, nombre);
    }

    /// <summary>Lee la hoja "Inventario" de la plantilla. Las columnas se reconocen por su título (nuevo o anterior).</summary>
    public static List<CapaEntidad.FilaImportacion> LeerInventario(Stream archivo)
    {
        using var wb = new XLWorkbook(archivo);
        var ws = wb.Worksheets.FirstOrDefault(w => Normalizar(w.Name) == "inventario") ?? wb.Worksheet(1);
        var col = new Dictionary<string, int>();
        foreach (var celda in ws.Row(1).CellsUsed())
            col[Normalizar(celda.GetString().Replace("*", ""))] = celda.Address.ColumnNumber;

        int Buscar(params string[] titulos) =>
            titulos.Select(t => col.TryGetValue(Normalizar(t), out var n) ? n : 0).FirstOrDefault(n => n > 0);
        int cNombre = Buscar("Nombre del insumo", "Nombre"), cUnidad = Buscar("Unidad");
        if (cNombre == 0 || cUnidad == 0)
            throw new InvalidOperationException("Faltan las columnas \"Nombre del insumo\" y \"Unidad\". Descargue la plantilla de nuevo.");
        int cCodigo = Buscar("Código (opcional)", "Código");
        int cMinimo = Buscar("Avisar cuando queden", "Stock mínimo");
        int cCosto = Buscar("Costo por unidad", "Costo unitario");
        int cStock = Buscar("Cantidad que hay hoy", "Stock actual");

        var filas = new List<CapaEntidad.FilaImportacion>();
        int ultima = ws.LastRowUsed()?.RowNumber() ?? 1;
        for (int r = 2; r <= ultima; r++)
        {
            var fila = ws.Row(r);
            filas.Add(new CapaEntidad.FilaImportacion
            {
                Fila = r,
                Codigo = cCodigo > 0 ? fila.Cell(cCodigo).GetString() : "",
                Nombre = fila.Cell(cNombre).GetString(),
                UnidadMedida = fila.Cell(cUnidad).GetString(),
                StockMinimo = cMinimo > 0 ? Numero(fila.Cell(cMinimo), r) ?? 0 : 0,
                CostoUnitario = cCosto > 0 ? Numero(fila.Cell(cCosto), r) ?? 0 : 0,
                Stock = cStock > 0 ? Numero(fila.Cell(cStock), r) : null
            });
        }
        return filas;
    }

    private static decimal? Numero(IXLCell celda, int fila)
    {
        if (celda.IsEmpty()) return null;
        if (celda.DataType == XLDataType.Number) return (decimal)celda.GetDouble();
        var t = celda.GetString().Trim().Replace(" ", "");
        if (t == "") return null;
        // Acepta 1.500,5 o 1500.5
        if (t.Contains(',') && t.Contains('.')) t = t.Replace(".", "").Replace(',', '.');
        else t = t.Replace(',', '.');
        if (decimal.TryParse(t, NumberStyles.Number, CultureInfo.InvariantCulture, out var v)) return v;
        throw new InvalidOperationException($"Fila {fila}: \"{celda.GetString()}\" no es un número");
    }

    private static string Normalizar(string s)
    {
        var d = s.Trim().ToLowerInvariant().Normalize(System.Text.NormalizationForm.FormD);
        return new string(d.Where(ch => CharUnicodeInfo.GetUnicodeCategory(ch) != UnicodeCategory.NonSpacingMark).ToArray());
    }
}
