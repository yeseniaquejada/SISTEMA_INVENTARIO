# Lista de compras en tirilla y caja organizada (11/11/2026)

Hecho sobre el código más reciente: `.claude\worktrees\prueba-iis`.

1. Copie las carpetas `CapaDatos`, `CapaEntidad`, `CapaNegocio` y `CapaPresentacion` de aquí encima de las de `prueba-iis`
   (reemplaza 6 archivos y agrega 1):
   - CapaDatos\Repositorios.cs
   - CapaEntidad\Entidades.cs
   - CapaNegocio\Negocio.cs (ya trae el arreglo de "eliminar insumo" del 10/11)
   - CapaPresentacion\Controllers\OperacionesControllers.cs
   - CapaPresentacion\Views\Caja\Index.cshtml
   - CapaPresentacion\Views\Compra\Index.cshtml
   - CapaPresentacion\Views\Compra\Tirilla.cshtml (nuevo)
2. Ejecute `BaseDatos\08_Lista_Compras.sql` en la base de datos del hosting. Crea una tabla y dos procedimientos
   y deja las bolsas ziploc fuera de la lista. No borra ni cambia insumos, ventas ni inventario.
   Si aún no ha ejecutado `06_Arreglo_SP_INSUMO_ELIMINAR.sql` (de arreglo-eliminar-insumo), ejecútelo también.
3. Publique como siempre.

## Qué debo comprar (Configuración > Qué debo comprar)
- Botón **Imprimir tirilla**: saca la lista en la impresora térmica, agrupada por proveedor, con un cuadrito `[ ]` para
  chulear lo comprado, la cantidad y el costo estimado. En la tirilla también está "Imprimir sin precios".
- Cada insumo tiene un chulito (desmarcado = hoy no se compra, no sale en la tirilla) y la cantidad "A pedir" se puede cambiar.
- La **X** quita un insumo de la lista para siempre (sigue en el inventario). Abajo aparece "Quitados de la lista" con
  "Volver a incluir". El script ya deja fuera las bolsas ziploc.

## Caja
- La caja abierta se lee por bloques: Vendido hoy, Efectivo del cajón, Otros medios de pago, Saldo para gastar y Cajas.
- En "Efectivo del cajón" ahora solo restan los gastos en efectivo, así la cuenta da justo el esperado. Los gastos por
  transferencia o tarjeta salen en "Otros medios de pago". El saldo para gastar no cambia.
- "Cerrar caja" va en su propia tarjeta.
- **Contar cajas**: al cerrar salen las cajas de empaque (insumos cuyo nombre empieza por "Caja", p. ej. "Caja C1 hamburguesa"
  y "Caja de empaque") con lo que dice el sistema. Se escribe cuántas quedan y muestra si cuadra o faltan. Al cerrar, el
  inventario de esas cajas queda con lo contado (sale en Contar inventario) y lo contado se anota en la observación del cierre.
  Si se deja vacía, esa caja no se toca.
