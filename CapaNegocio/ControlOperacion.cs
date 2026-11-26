using CapaDatos;
using CapaEntidad;
namespace CapaNegocio;
public class CN_ControlOperacion {
 private readonly CD_ControlOperacion _datos=new();
 public List<MovimientoCaja> Movimientos(int sede,int caja)=>_datos.Movimientos(sede,caja);
 public Respuesta Registrar(int sede,int usuario,bool admin,MovimientoCaja? m){
 if(m==null) return Respuesta.Error("Datos del movimiento incompletos; recargue la página");
 m.Concepto=m.Concepto?.Trim()??"";
 if(m.Referencia==Guid.Empty) return Respuesta.Error("Falta la referencia de la operación; recargue la página");
 if(m.Monto<=0 || m.Monto>9999999999.99m || decimal.Round(m.Monto,2)!=m.Monto) return Respuesta.Error("Ingrese un monto positivo con máximo dos decimales");
 if(m.Concepto.Length==0 || m.Concepto.Length>250 || (m.Beneficiario?.Length??0)>100) return Respuesta.Error("Indique el concepto (máximo 250 caracteres) y un beneficiario de máximo 100 caracteres");
 if(!new[]{"COMPRA","PAGO","RETIRO","INGRESO"}.Contains(m.Tipo) || !new[]{"EFECTIVO","TARJETA","TRANSFERENCIA"}.Contains(m.MetodoPago)) return Respuesta.Error("Tipo o medio de pago inválido");
 if(m.Tipo=="RETIRO" && !admin) return Respuesta.Error("Solo el administrador puede registrar retiros");
 // Yesenia Quejada Rojas - Claude — 28/10/2026: el fondo del negocio lo mueve el administrador; el salario es un pago con nombre del empleado.
 m.Origen=string.IsNullOrWhiteSpace(m.Origen)?"CAJA":m.Origen; m.Clase=string.IsNullOrWhiteSpace(m.Clase)?null:m.Clase;
 if(!new[]{"CAJA","FONDO"}.Contains(m.Origen)) return Respuesta.Error("Origen del dinero inválido");
 if(m.Origen=="FONDO" && !admin) return Respuesta.Error("Solo el administrador mueve el fondo del negocio");
 if(m.Clase!=null && (m.Clase!="SALARIO" || m.Tipo!="PAGO")) return Respuesta.Error("Clase de movimiento inválida");
 if(m.Clase=="SALARIO" && string.IsNullOrWhiteSpace(m.Beneficiario)) return Respuesta.Error("Indique el nombre del empleado al que se le paga");
 if(new[]{"RETIRO","INGRESO"}.Contains(m.Tipo) && m.MetodoPago!="EFECTIVO") return Respuesta.Error("Los retiros y aportes son de efectivo");
 return _datos.Registrar(sede,usuario,m);
 }
 // Yesenia Quejada Rojas - Claude — 31/10/2026: corrige un movimiento de la caja abierta; solo el administrador (igual que anular).
 public Respuesta Editar(int sede,int usuario,MovimientoCaja? m){
 if(m==null || m.IdMovimientoCaja<=0) return Respuesta.Error("Datos del movimiento incompletos; recargue la página");
 m.Concepto=m.Concepto?.Trim()??""; m.Clase=string.IsNullOrWhiteSpace(m.Clase)?null:m.Clase;
 if(m.Monto<=0 || m.Monto>9999999999.99m || decimal.Round(m.Monto,2)!=m.Monto) return Respuesta.Error("Ingrese un monto positivo con máximo dos decimales");
 if(m.Concepto.Length==0 || m.Concepto.Length>250 || (m.Beneficiario?.Length??0)>100) return Respuesta.Error("Indique el concepto (máximo 250 caracteres) y un beneficiario de máximo 100 caracteres");
 return _datos.Editar(sede,usuario,m);
 }
 public Respuesta Anular(int sede,int usuario,int id,string? motivo)=>string.IsNullOrWhiteSpace(motivo)||motivo.Length>250?Respuesta.Error("Indique un motivo de máximo 250 caracteres"):_datos.Anular(sede,usuario,id,motivo.Trim());
 public List<EventoAuditoria> Auditoria(int sede,DateTime inicio,DateTime fin)=>_datos.Auditoria(sede,inicio,fin);
 public List<DiferenciaInventario> Verificar(int sede)=>_datos.Verificar(sede);
}
