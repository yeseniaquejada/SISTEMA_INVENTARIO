# SISTEMA_INVENTARIO

Sistema de Inventario para un Local de Comidas Rápidas

ASP.NET Core MVC (.NET 10) · C# · JavaScript · SQL Server (ADO.NET + procedimientos almacenados)

## Estructura (N-capas)

| Proyecto | Contenido |
|---|---|
| `BaseDatos/01_BaseDatos.sql` | Base de datos, tablas, procedimientos almacenados y datos de ejemplo |
| `CapaEntidad` | Clases: Usuario, Categoria, Proveedor, Insumo, Movimiento, ProductoMenu, Venta... |
| `CapaDatos` | `Conexion.cs` (ADO.NET) y repositorios `CD_*` que llaman a los SP |
| `CapaNegocio` | Validaciones `CN_*` y `Seguridad.cs` (contraseñas con PBKDF2) |
| `CapaPresentacion` | ASP.NET Core MVC: controladores, vistas Razor y JS (`wwwroot/js`) con `fetch` |

## Módulos

- **Panel**: ventas y pedidos del día, valor del inventario, insumos bajo el mínimo.
- **Ventas**: punto de venta; cada venta descuenta los insumos según la receta del producto.
- **Movimientos**: entradas (compras a proveedor), salidas, mermas y kardex por fechas.
- **Mantenimiento**: insumos, productos del menú con su receta, categorías, proveedores.
- **Roles**: ADMINISTRADOR (todo) y CAJERO (panel y ventas).

## Cómo ejecutarlo

1. Abra `BaseDatos/01_BaseDatos.sql` en SQL Server Management Studio y ejecútelo (SQL Server 2017 o superior).
2. Revise la cadena `CadenaSQL` en `CapaPresentacion/appsettings.json` (por defecto: `Server=localhost`, autenticación de Windows).
3. Abra `InventarioComidas.sln` en Visual Studio 2026 (con la carga de trabajo "ASP.NET y desarrollo web" y el SDK de .NET 10), marque `CapaPresentacion` como proyecto de inicio y presione F5.
   Por consola: `dotnet run --project CapaPresentacion`.
4. Ingrese con **admin / Admin123** y cambie la contraseña.

## Reglas importantes

- El stock solo cambia por movimientos (entrada, salida, merma) o ventas; todo queda en el kardex.
- Las ventas y salidas validan stock dentro de una transacción; si falta algún insumo, no se registra nada.
- Registros con historial no se eliminan: se desactivan.

![Pantalla de ventas](captura-venta.png)
