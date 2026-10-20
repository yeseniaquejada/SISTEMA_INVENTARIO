namespace CapaEntidad;
public class MovimientoCaja {
 public int IdMovimientoCaja {get;set;} public int IdCaja {get;set;}
 public string Tipo {get;set;}="COMPRA"; public string MetodoPago {get;set;}="EFECTIVO";
 public decimal Monto {get;set;} public string Concepto {get;set;}="";
 public string? Beneficiario {get;set;} public Guid Referencia {get;set;}
 public string Fecha {get;set;}=""; public string Usuario {get;set;}="";
 public bool Anulado {get;set;} public string MotivoAnulacion {get;set;}="";
}
public class EventoAuditoria {
 public string Fecha {get;set;}=""; public string Usuario {get;set;}="";
 public string Tabla {get;set;}=""; public string Accion {get;set;}="";
 public string Antes {get;set;}=""; public string Despues {get;set;}="";
}
public class DiferenciaInventario {
 public string Codigo {get;set;}=""; public string Nombre {get;set;}="";
 public decimal Stock {get;set;} public decimal Lotes {get;set;} public decimal Kardex {get;set;}
}
