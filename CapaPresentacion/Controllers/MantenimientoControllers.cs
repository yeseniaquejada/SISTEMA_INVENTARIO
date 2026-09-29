using CapaEntidad;
using CapaNegocio;
using CapaPresentacion.Infraestructura;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CapaPresentacion.Controllers;

[Authorize(Roles = Claves.Admin)]
public class CategoriaController : Controller
{
    private readonly CN_Categoria _negocio = new();
    public IActionResult Index() => View();
    [HttpGet] public JsonResult Listar() => Json(_negocio.Listar());
    [HttpPost] public JsonResult Guardar([FromBody] Categoria obj) => Json(_negocio.Guardar(obj));
    [HttpPost] public JsonResult Eliminar(int id) => Json(_negocio.Eliminar(id));
}

[Authorize(Roles = Claves.Admin)]
public class ProveedorController : Controller
{
    private readonly CN_Proveedor _negocio = new();
    public IActionResult Index() => View();
    [HttpGet] public JsonResult Listar() => Json(_negocio.Listar());
    [HttpPost] public JsonResult Guardar([FromBody] Proveedor obj) => Json(_negocio.Guardar(obj));
    [HttpPost] public JsonResult Eliminar(int id) => Json(_negocio.Eliminar(id));
}

[Authorize(Roles = Claves.Admin)]
public class SedeController : Controller
{
    private readonly CN_Sede _negocio = new();
    public IActionResult Index() => View();
    [HttpGet] public JsonResult Listar() => Json(_negocio.Listar());
    [HttpPost] public JsonResult Guardar([FromBody] Sede obj) => Json(_negocio.Guardar(obj));
    [HttpPost] public JsonResult Eliminar(int id) => Json(_negocio.Eliminar(id));
}

[Authorize(Roles = Claves.Admin)]
public class CategoriaMenuController : Controller
{
    private readonly CN_CategoriaMenu _negocio = new();
    public IActionResult Index() => View();
    [HttpGet] public JsonResult Listar() => Json(_negocio.Listar());
    [HttpPost] public JsonResult Guardar([FromBody] CategoriaMenu obj) => Json(_negocio.Guardar(obj));
    [HttpPost] public JsonResult Eliminar(int id) => Json(_negocio.Eliminar(id));
}

[Authorize(Roles = Claves.Admin)]
public class ModificadorController : Controller
{
    private readonly CN_Modificador _negocio = new();
    public IActionResult Index() => View();
    [HttpGet] public JsonResult Listar() => Json(_negocio.Listar());
    [HttpPost] public JsonResult Guardar([FromBody] Modificador obj) => Json(_negocio.Guardar(obj));
    [HttpPost] public JsonResult Eliminar(int id) => Json(_negocio.Eliminar(id));
}

[Authorize(Roles = Claves.Admin)]
public class UsuarioController : Controller
{
    private readonly CN_Usuario _negocio = new();
    public IActionResult Index() => View();
    [HttpGet] public JsonResult Listar() => Json(_negocio.Listar());
    [HttpGet] public JsonResult Roles() => Json(_negocio.Roles());
    [HttpPost] public JsonResult Guardar([FromBody] Usuario obj) => Json(_negocio.Guardar(obj));
}

public class InsumoController : Controller
{
    private readonly CN_Insumo _negocio = new();

    [Authorize(Roles = Claves.Admin)] public IActionResult Index() => View();
    [HttpGet] public JsonResult Listar() => Json(_negocio.Listar(User.IdSede()));
    [HttpPost, Authorize(Roles = Claves.Admin)] public JsonResult Guardar([FromBody] Insumo obj) => Json(_negocio.Guardar(obj));
    [HttpPost, Authorize(Roles = Claves.Admin)] public JsonResult Eliminar(int id) => Json(_negocio.Eliminar(id));

    [HttpGet, Authorize(Roles = Claves.Admin)]
    public IActionResult Exportar() =>
        Excel.Archivo("inventario-" + User.Sede(), "Inventario", _negocio.Listar(User.IdSede()),
            ("Código", i => i.Codigo), ("Insumo", i => i.Nombre), ("Categoría", i => i.Categoria),
            ("Unidad", i => i.UnidadMedida), ("Stock", i => i.Stock), ("Mínimo", i => i.StockMinimo),
            ("Costo unitario", i => i.CostoUnitario), ("Valor", i => i.Stock * i.CostoUnitario),
            ("Próximo vencimiento", i => i.ProximoVencimiento), ("Activo", i => i.Activo ? "Sí" : "No"));

    /// <summary>Plantilla de Excel con los insumos actuales para llenar y volver a cargar.</summary>
    [HttpGet, Authorize(Roles = Claves.Admin)]
    public IActionResult Plantilla() =>
        Excel.PlantillaInventario("plantilla-inventario-" + User.Sede(), _negocio.Listar(User.IdSede()),
            new CN_Categoria().Listar().Where(c => c.Activo).Select(c => c.Descripcion), CN_Insumo.Unidades);

    [HttpPost, Authorize(Roles = Claves.Admin), RequestSizeLimit(5_000_000)]
    public JsonResult Importar(IFormFile? archivo)
    {
        if (archivo == null || archivo.Length == 0) return Json(new ResultadoImportacion { Errores = { "Seleccione el archivo de Excel" } });
        if (!archivo.FileName.EndsWith(".xlsx", StringComparison.OrdinalIgnoreCase))
            return Json(new ResultadoImportacion { Errores = { "El archivo debe ser de Excel (.xlsx)" } });
        List<FilaImportacion> filas;
        try
        {
            using var s = archivo.OpenReadStream();
            filas = Excel.LeerInventario(s);
        }
        catch (Exception ex)
        {
            return Json(new ResultadoImportacion { Errores = { "No se pudo leer el archivo: " + ex.Message } });
        }
        return Json(_negocio.Importar(filas, User.IdSede(), User.Id()));
    }
}

[Authorize(Roles = Claves.Admin)]
public class ProductoController : Controller
{
    private readonly CN_Producto _negocio = new();
    private readonly IWebHostEnvironment _env;
    public ProductoController(IWebHostEnvironment env) => _env = env;

    public IActionResult Index() => View();
    [HttpGet] public JsonResult Listar() => Json(_negocio.Listar());

    [HttpGet]
    public JsonResult Detalle(int id) => Json(new { receta = _negocio.ListarReceta(id), modificadores = _negocio.ListarModificadores(id) });

    [HttpPost] public JsonResult Guardar([FromBody] ProductoMenu obj) => Json(_negocio.Guardar(obj));
    [HttpPost] public JsonResult Eliminar(int id) => Json(_negocio.Eliminar(id));

    [HttpPost, RequestSizeLimit(Archivos.TamanoMaximo + 100_000)]
    public async Task<JsonResult> SubirImagen(int id, IFormFile? archivo)
    {
        var (url, error) = await Archivos.GuardarImagen(archivo, _env, "producto");
        if (url == null) return Json(Respuesta.Error(error!));
        var r = _negocio.GuardarImagen(id, url);
        return Json(r.Resultado ? new { resultado = true, url } : (object)r);
    }

    [HttpPost]
    public JsonResult QuitarImagen(int id) => Json(_negocio.GuardarImagen(id, null));
}

[Authorize(Roles = Claves.Admin)]
public class ConfiguracionController : Controller
{
    private readonly CN_Configuracion _negocio = new();
    private readonly IWebHostEnvironment _env;
    public ConfiguracionController(IWebHostEnvironment env) => _env = env;

    public IActionResult Index() => View();
    [HttpGet] public JsonResult Obtener() => Json(_negocio.Obtener());
    [HttpPost] public JsonResult Guardar([FromBody] Configuracion obj) => Json(_negocio.Guardar(obj));

    [HttpPost, RequestSizeLimit(Archivos.TamanoMaximo + 100_000)]
    public async Task<JsonResult> SubirLogo(IFormFile? archivo)
    {
        var (url, error) = await Archivos.GuardarImagen(archivo, _env, "logo");
        return Json(url == null ? new { resultado = false, mensaje = error } : new { resultado = true, url });
    }
}
