# Diagnóstico de merma de insumos (26/11/2026)

`Auditoria_Merma_Insumos.sql` solo lee datos (SELECT/PRINT). No está en `BaseDatos\Cambios`,
así que `desplegar.ps1` no lo ejecuta. Ábralo en SSMS contra la base del hosting y ejecútelo.
Cada bloque sale vacío si está bien.

| Bloque | Qué revisa |
|---|---|
| 1 | Productos activos sin receta (no descuentan nada) |
| 2 | Productos cuya receta no descuenta nada |
| 3 | Recetas con insumos inactivos o "no descontar al vender" |
| 4 | Adiciones que no descuentan (sin insumo o insumo apagado) |
| 5 | Adiciones negativas sobre insumos que no están en la receta |
| 6 | Insumos que nunca bajan con ventas (no están en recetas ni adiciones) |
| 7 | Unidades raras: KG/LT con cantidades altas, GR/ML bajas, paquetes con redondeo |
| 8 | Insumos repetidos o parecidos (como los dos chicharrones) |
| 9 | Ventas que no pudieron descontar porque el stock estaba en 0 ("faltaron") |
| 10 | Lo que debió bajar por ventas vs. lo que bajó, por insumo |
| 11 | Ventas con receta que no generaron ningún movimiento |
| 12 | Stock vs. lotes |
| 13 | Scripts ejecutados desde el 012 |

Los parámetros `@Sede` (1) y `@Dias` (30) están al principio.
