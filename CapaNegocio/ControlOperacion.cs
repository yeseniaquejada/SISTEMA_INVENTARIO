using CapaDatos;
using CapaEntidad;
namespace CapaNegocio;
public class CN_ControlOperacion {
 private readonly CD_ControlOperacion _datos=new();
 public List<MovimientoCaja> Movimientos(int sede,int caja)=>_datos.Movimientos(sede,caja);
 public Respuesta Registrar(int sede,int usuario,bool admin,MovimientoCaja m){
 m.Concepto=m.Concepto?.Trim()??"";
 if(m.Referencia==Guid.Empty) return Respuesta.Error("Falta la referencia de la operación; recargue la página");
 if(m.Monto<=0 || m.Monto>9999999999.99m || decimal.Round(m.Monto,2)!=m.Monto) return Respuesta.Error("Ingrese un monto positivo con máximo dos decimales");
 if(m.Concepto.Length==0 || m.Concepto.Length>250 || (m.Beneficiario?.Length??0)>100) return Respuesta.Error("Indique el concepto (máximo 250 caracteres) y un beneficiario de máximo 100 caracteres");
 if(!new[]{"COMPRA","PAGO","RETIRO","INGRESO"}.Contains(m.Tipo) || !new[]{"EFECTIVO","TARJETA","TRANSFERENCIA"}.Contains(m.MetodoPago)) return Respuesta.Error("Tipo o medio de pago inválido");
 if(m.Tipo=="RETIRO" && !admin) return Respuesta.Error("Solo el administrador puede registrar retiros");
 if(new[]{"RETIRO","INGRESO"}.Contains(m.Tipo) && m.MetodoPago!="EFECTIVO") return Respuesta.Error("Los retiros y aportes son de efectivo");
 return _datos.Registrar(sede,usuario,m);
 }
 public Respuesta Anular(int sede,int usuario,int id,string? motivo)=>string.IsNullOrWhiteSpace(motivo)||motivo.Length>250?Respuesta.Error("Indique un motivo de máximo 250 caracteres"):_datos.Anular(sede,usuario,id,motivo.Trim());
 public List<EventoAuditoria> Auditoria(int sede,DateTime inicio,DateTime fin)=>_datos.Auditoria(sede,inicio,fin);
 public List<DiferenciaInventario> Verificar(int sede)=>_datos.Verificar(sede);
}
