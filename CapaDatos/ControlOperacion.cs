using CapaEntidad;
using static CapaDatos.Conexion;
namespace CapaDatos;
public class CD_ControlOperacion {
 public List<MovimientoCaja> Movimientos(int sede,int caja) => Listar("SP_CAJA_MOVIMIENTOS",dr=>new MovimientoCaja {
 IdMovimientoCaja=dr.Entero("IdMovimientoCaja"),IdCaja=dr.Entero("IdCaja"),Fecha=dr.Texto("FechaTexto"),Usuario=dr.Texto("Usuario"),Tipo=dr.Texto("Tipo"),MetodoPago=dr.Texto("MetodoPago"),Monto=dr.Decimal("Monto"),Concepto=dr.Texto("Concepto"),Beneficiario=dr.Texto("Beneficiario"),Anulado=dr.Bool("Anulado"),MotivoAnulacion=dr.Texto("MotivoAnulacion")},P("@IdSede",sede),P("@IdCaja",caja));
 public Respuesta Registrar(int sede,int usuario,MovimientoCaja m) => Ejecutar("SP_CAJA_MOVIMIENTO_REGISTRAR",P("@IdSede",sede),P("@IdUsuario",usuario),P("@Tipo",m.Tipo),P("@MetodoPago",m.MetodoPago),P("@Monto",m.Monto),P("@Concepto",m.Concepto),P("@Beneficiario",m.Beneficiario),P("@Referencia",m.Referencia));
 public Respuesta Anular(int sede,int usuario,int id,string motivo) => Ejecutar("SP_CAJA_MOVIMIENTO_ANULAR",P("@IdSede",sede),P("@IdUsuario",usuario),P("@IdMovimientoCaja",id),P("@Motivo",motivo));
 public List<EventoAuditoria> Auditoria(int sede,DateTime inicio,DateTime fin)=>Listar("SP_AUDITORIA_LISTAR",dr=>new EventoAuditoria {Fecha=dr.Texto("Fecha"),Usuario=dr.Texto("Usuario"),Tabla=dr.Texto("Tabla"),Accion=dr.Texto("Accion"),Antes=dr.Texto("Antes"),Despues=dr.Texto("Despues")},P("@IdSede",sede),P("@Inicio",inicio.Date),P("@Fin",fin.Date));
 public List<DiferenciaInventario> Verificar(int sede)=>Listar("SP_INVENTARIO_VERIFICAR",dr=>new DiferenciaInventario {Codigo=dr.Texto("Codigo"),Nombre=dr.Texto("Nombre"),Stock=dr.Decimal("Stock"),Lotes=dr.Decimal("Lotes"),Kardex=dr.Decimal("Kardex")},P("@IdSede",sede));
}
