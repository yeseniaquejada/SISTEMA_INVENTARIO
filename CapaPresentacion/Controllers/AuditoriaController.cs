using CapaNegocio;
using CapaPresentacion.Infraestructura;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace CapaPresentacion.Controllers;
[Authorize(Roles=Claves.Admin)]
public class AuditoriaController:Controller {
 private readonly CN_ControlOperacion _negocio=new();
 public IActionResult Index()=>View();
 [HttpGet] public JsonResult Listar(DateTime inicio,DateTime fin)=>Json(_negocio.Auditoria(User.IdSede(),inicio,fin));
 [HttpGet] public JsonResult VerificarInventario()=>Json(_negocio.Verificar(User.IdSede()));
}
