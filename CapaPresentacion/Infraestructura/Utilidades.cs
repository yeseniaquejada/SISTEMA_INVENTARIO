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
        using var ms = new MemoryStream();
        wb.SaveAs(ms);
        return new FileContentResult(ms.ToArray(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        {
            FileDownloadName = $"{nombre}-{DateTime.Now:yyyyMMdd-HHmm}.xlsx"
        };
    }
}
