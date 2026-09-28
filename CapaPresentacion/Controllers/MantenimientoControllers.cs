using CapaEntidad;
using CapaNegocio;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CapaPresentacion.Controllers;

[Authorize(Roles = "ADMINISTRADOR")]
public class CategoriaController : Controller
{
    private readonly CN_Categoria _negocio = new();

    public IActionResult Index() => View();
    [HttpGet] public JsonResult Listar() => Json(_negocio.Listar());
    [HttpPost] public JsonResult Guardar([FromBody] Categoria obj) => Json(_negocio.Guardar(obj));
    [HttpPost] public JsonResult Eliminar(int id) => Json(_negocio.Eliminar(id));
}

[Authorize(Roles = "ADMINISTRADOR")]
public class ProveedorController : Controller
{
    private readonly CN_Proveedor _negocio = new();

    public IActionResult Index() => View();
    [HttpGet] public JsonResult Listar() => Json(_negocio.Listar());
    [HttpPost] public JsonResult Guardar([FromBody] Proveedor obj) => Json(_negocio.Guardar(obj));
    [HttpPost] public JsonResult Eliminar(int id) => Json(_negocio.Eliminar(id));
}

public class InsumoController : Controller
{
    private readonly CN_Insumo _negocio = new();

    [Authorize(Roles = "ADMINISTRADOR")] public IActionResult Index() => View();
    [HttpGet] public JsonResult Listar() => Json(_negocio.Listar());
    [HttpPost, Authorize(Roles = "ADMINISTRADOR")] public JsonResult Guardar([FromBody] Insumo obj) => Json(_negocio.Guardar(obj));
    [HttpPost, Authorize(Roles = "ADMINISTRADOR")] public JsonResult Eliminar(int id) => Json(_negocio.Eliminar(id));
}

[Authorize(Roles = "ADMINISTRADOR")]
public class ProductoController : Controller
{
    private readonly CN_Producto _negocio = new();

    public IActionResult Index() => View();
    [HttpGet] public JsonResult Listar() => Json(_negocio.Listar());
    [HttpGet] public JsonResult Receta(int id) => Json(_negocio.ListarReceta(id));
    [HttpPost] public JsonResult Guardar([FromBody] ProductoMenu obj) => Json(_negocio.Guardar(obj));
    [HttpPost] public JsonResult Eliminar(int id) => Json(_negocio.Eliminar(id));
}
