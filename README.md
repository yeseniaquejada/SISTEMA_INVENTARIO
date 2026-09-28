# SISTEMA_INVENTARIO

Sistema de Inventario para un Local de Comidas Rápidas

ASP.NET Core MVC (.NET 10) · C# · JavaScript · SQL Server (ADO.NET + procedimientos almacenados)

## Estructura (N-capas)

| Proyecto | Contenido |
|---|---|
| `BaseDatos/01_BaseDatos.sql` | Base de datos, tablas y procedimientos almacenados (borra y crea la base) |
| `BaseDatos/02_DatosIniciales.sql` | Menú, insumos, recetas y adiciones de John Wick (tomados del Excel de costos) |
| `CapaEntidad` | Clases: Usuario, Categoria, Proveedor, Insumo, Movimiento, ProductoMenu, Venta... |
| `CapaDatos` | `Conexion.cs` (ADO.NET) y repositorios `CD_*` que llaman a los SP |
| `CapaNegocio` | Validaciones `CN_*` y `Seguridad.cs` (contraseñas con PBKDF2) |
| `CapaPresentacion` | ASP.NET Core MVC: controladores, vistas Razor y JS (`wwwroot/js`) con `fetch` |

## Módulos

- **Inicio**: ventas y pedidos del día, domicilios pendientes, estado de la caja, insumos por pedir y lotes por vencer.
- **Vender**: tarjetas de productos con foto por categoría, adiciones y notas para cocina, pedido en mesa, para llevar o a domicilio, pago en efectivo (con cambio), tarjeta o transferencia, e impresión del ticket de 80 mm.
- **Domicilios**: pedidos pendientes, en camino y entregados.
- **Caja**: apertura con base, totales por forma de pago y cierre con el efectivo contado y la diferencia.
- **Inventario**: stock por sede, entradas con fecha de vencimiento (lotes), salidas, mermas, kardex, conteo físico con ajuste automático y orden de compra sugerida por proveedor.
- **Reportes**: ventas por día, productos más vendidos, formas de pago, costo de insumos, ganancia y mermas, con gráficas.
- **Exportar**: Excel (inventario, kardex, ventas, orden de compra) y PDF desde el botón imprimir.
- **Mantenimiento**: productos con foto y receta (costo y margen), adiciones y modificadores, categorías del menú e insumos, proveedores, usuarios, sedes y **Configuración** (nombre del negocio, NIT, logo, colores, moneda y mensaje del ticket). El sistema es una plantilla: cada negocio lo personaliza desde ahí.
- **Varias sedes**: cada usuario pertenece a una sede; el administrador cambia de sede desde la barra superior.
- **Roles**: ADMINISTRADOR (todo) y CAJERO (inicio, ventas, domicilios y caja).

## Cómo ejecutarlo

1. En SQL Server Management Studio ejecute `BaseDatos/01_BaseDatos.sql` y luego `BaseDatos/02_DatosIniciales.sql` (SQL Server 2017 o superior). Ojo: el primero borra la base si ya existe.
2. Revise la cadena `CadenaSQL` en `CapaPresentacion/appsettings.json` (por defecto: `Server=localhost`, autenticación de Windows).
3. Abra `InventarioComidas.sln` en Visual Studio 2026 (con la carga de trabajo "ASP.NET y desarrollo web" y el SDK de .NET 10), marque `CapaPresentacion` como proyecto de inicio y presione F5.
   Por consola: `dotnet run --project CapaPresentacion`.
4. Ingrese con **admin / Admin123** y cambie la contraseña.
5. Suba las fotos de los productos en *Mantenimiento > Productos y recetas* y el logo y colores en *Mantenimiento > Configuración*.

## Reglas importantes

- El stock solo cambia por movimientos (entrada, salida, merma) o ventas; todo queda en el kardex.
- Las ventas y salidas validan stock dentro de una transacción; si falta algún insumo, no se registra nada.
- Registros con historial no se eliminan: se desactivan.
- Para vender debe haber una caja abierta en la sede.
- Las fotos y el logo se guardan en `CapaPresentacion/wwwroot/uploads` (JPG, PNG, WEBP o GIF de hasta 3 MB).
- Chart.js y Bootstrap Icons vienen incluidos en `wwwroot/lib`, así que no se necesita internet.

![Pantalla de ventas](captura-venta.png)
