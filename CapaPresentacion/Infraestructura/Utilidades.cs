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
}

public static class UsuarioActual
{
    public static int Id(this ClaimsPrincipal u) => int.Parse(u.FindFirstValue(ClaimTypes.NameIdentifier)!);
    public static int IdSede(this ClaimsPrincipal u) => int.Parse(u.FindFirstValue(Claves.IdSede) ?? "1");
    public static string Sede(this ClaimsPrincipal u) => u.FindFirstValue(Claves.Sede) ?? "";
    public static bool EsAdmin(this ClaimsPrincipal u) => u.IsInRole(Claves.Admin);
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

    private static readonly string[] ColumnasInventario =
        { "Código", "Nombre", "Categoría", "Unidad", "Stock mínimo", "Costo unitario", "Stock actual" };

    /// <summary>
    /// Plantilla para configurar o actualizar el inventario: trae los insumos actuales,
    /// listas desplegables de categorías y unidades, y una hoja de instrucciones.
    /// </summary>
    public static FileContentResult PlantillaInventario(string nombre, IEnumerable<CapaEntidad.Insumo> insumos,
        IEnumerable<string> categorias, IEnumerable<string> unidades)
    {
        using var wb = new XLWorkbook();
        var ws = wb.Worksheets.Add("Inventario");
        var ins = wb.Worksheets.Add("Instrucciones");
        var listas = wb.Worksheets.Add("Listas");

        for (int c = 0; c < ColumnasInventario.Length; c++)
        {
            var celda = ws.Cell(1, c + 1);
            celda.Value = ColumnasInventario[c];
            celda.Style.Font.Bold = true;
            celda.Style.Font.FontColor = XLColor.White;
            celda.Style.Fill.BackgroundColor = XLColor.FromHtml(c < 4 ? "#C8322B" : "#555555");
        }
        int f = 2;
        foreach (var i in insumos.Where(i => i.Activo))
        {
            ws.Cell(f, 1).Value = i.Codigo;
            ws.Cell(f, 2).Value = i.Nombre;
            ws.Cell(f, 3).Value = i.Categoria;
            ws.Cell(f, 4).Value = i.UnidadMedida;
            ws.Cell(f, 5).Value = i.StockMinimo;
            ws.Cell(f, 6).Value = i.CostoUnitario;
            ws.Cell(f, 7).Value = i.Stock;
            f++;
        }
        ws.Range("E2:G2000").Style.NumberFormat.Format = "#,##0.###";
        ws.Range("G2:G2000").Style.Fill.BackgroundColor = XLColor.FromHtml("#FFF7D6");

        var cats = categorias.OrderBy(x => x).ToList();
        var unds = unidades.ToList();
        listas.Cell(1, 1).Value = "Categorías";
        listas.Cell(1, 2).Value = "Unidades";
        for (int k = 0; k < cats.Count; k++) listas.Cell(k + 2, 1).Value = cats[k];
        for (int k = 0; k < unds.Count; k++) listas.Cell(k + 2, 2).Value = unds[k];
        listas.Row(1).Style.Font.Bold = true;

        if (cats.Count > 0)
        {
            var dvCat = ws.Range("C2:C2000").CreateDataValidation();
            dvCat.List(listas.Range(2, 1, cats.Count + 1, 1), true);
            dvCat.ErrorStyle = XLErrorStyle.Information;   // se permiten categorías nuevas
            dvCat.ShowErrorMessage = false;
        }
        var dvUnd = ws.Range("D2:D2000").CreateDataValidation();
        dvUnd.List(listas.Range(2, 2, unds.Count + 1, 2), true);
        dvUnd.ErrorTitle = "Unidad no válida";
        dvUnd.ErrorMessage = "Use una de la lista: " + string.Join(", ", unds);

        ws.Columns().AdjustToContents();
        ws.Column(2).Width = Math.Max(ws.Column(2).Width, 32);
        ws.SheetView.FreezeRows(1);

        string[] texto =
        {
            "CÓMO USAR ESTA PLANTILLA",
            "",
            "1. Llene una fila por cada insumo en la hoja \"Inventario\". Las columnas en rojo son obligatorias.",
            "2. Código: identificador corto y único (ej. PANH, QMOZ). Si el código ya existe, el insumo se actualiza; si no, se crea.",
            "3. Categoría: elija de la lista o escriba una nueva (se crea sola).",
            "4. Unidad: " + string.Join(", ", unds) + ".",
            "5. Stock mínimo: cantidad a partir de la cual el sistema avisa que hay que pedir.",
            "6. Costo unitario: lo que cuesta cada unidad (se usa para el costo de las recetas y la ganancia).",
            "7. Stock actual (amarillo): cantidad REAL contada hoy en la sede. Si la deja vacía, el stock no se toca.",
            "   El sistema registra la diferencia como un conteo físico, así queda en el kardex.",
            "8. Guarde el archivo y cárguelo en Inventario > Insumos > Cargar Excel.",
            "",
            "Si hay errores, el sistema muestra la fila y no guarda nada, para que pueda corregir y volver a cargar.",
            "",
            "Ejemplo:",
        };
        for (int k = 0; k < texto.Length; k++) ins.Cell(k + 1, 1).Value = texto[k];
        ins.Cell(1, 1).Style.Font.Bold = true;
        ins.Cell(1, 1).Style.Font.FontSize = 14;
        int e = texto.Length + 1;
        object[][] ejemplo =
        {
            ColumnasInventario,
            new object[] { "PANH", "Pan de hamburguesa", "Panadería", "UND", 30, 1000, 120 },
            new object[] { "QMOZ", "Queso mozzarella (porción)", "Lácteos", "PORC", 40, 500, 200 },
        };
        for (int r = 0; r < ejemplo.Length; r++)
            for (int c = 0; c < ejemplo[r].Length; c++)
                ins.Cell(e + r, c + 1).Value = XLCellValue.FromObject(ejemplo[r][c]);
        ins.Row(e).Style.Font.Bold = true;
        ins.Column(1).Width = 14;
        ins.Columns(2, 7).AdjustToContents();

        return Descargar(wb, nombre);
    }

    /// <summary>Lee la hoja "Inventario" de la plantilla. Las columnas se reconocen por su título.</summary>
    public static List<CapaEntidad.FilaImportacion> LeerInventario(Stream archivo)
    {
        using var wb = new XLWorkbook(archivo);
        var ws = wb.Worksheets.FirstOrDefault(w => Normalizar(w.Name) == "inventario") ?? wb.Worksheet(1);
        var encabezado = ws.Row(1);
        var col = new Dictionary<string, int>();
        foreach (var celda in encabezado.CellsUsed()) col[Normalizar(celda.GetString())] = celda.Address.ColumnNumber;

        int C(string titulo) => col.TryGetValue(Normalizar(titulo), out var n) ? n
            : throw new InvalidOperationException($"Falta la columna \"{titulo}\". Descargue la plantilla de nuevo.");
        int cCodigo = C("Código"), cNombre = C("Nombre"), cCategoria = C("Categoría"), cUnidad = C("Unidad");
        col.TryGetValue(Normalizar("Stock mínimo"), out var cMinimo);
        col.TryGetValue(Normalizar("Costo unitario"), out var cCosto);
        col.TryGetValue(Normalizar("Stock actual"), out var cStock);

        var filas = new List<CapaEntidad.FilaImportacion>();
        int ultima = ws.LastRowUsed()?.RowNumber() ?? 1;
        for (int r = 2; r <= ultima; r++)
        {
            var fila = ws.Row(r);
            filas.Add(new CapaEntidad.FilaImportacion
            {
                Fila = r,
                Codigo = fila.Cell(cCodigo).GetString(),
                Nombre = fila.Cell(cNombre).GetString(),
                Categoria = fila.Cell(cCategoria).GetString(),
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
