# Plantilla de sistema para negocios de comidas

ASP.NET Core MVC (.NET 10), C# y SQL Server. Incluye ventas, caja, cocina, domicilios, inventario, reportes, registro de actividad, impresión y temas claro/oscuro.

## Estructura

- CapaEntidad: modelos.
- CapaDatos: conexión y repositorios SQL.
- CapaNegocio: reglas y validaciones.
- CapaPresentacion: controladores, vistas y recursos de interfaz.

## Preparar una copia para un cliente

1. Copiar las cuatro carpetas de código, InventarioComidas.sln, .gitignore y este README. No copiar .git para iniciar un proyecto independiente.
2. Preparar una base SQL Server con el esquema y procedimientos compatibles del sistema. Esta carpeta no contiene SQL de instalación ni datos iniciales.
3. En CapaPresentacion/appsettings.json reemplazar BASE_DATOS_DEL_CLIENTE por el nombre de la nueva base y configurar el servidor. No apuntar la copia a la base de otro negocio.
   Para que la pantalla de Insumos muestre los datos por confirmar, ejecutar una vez BaseDatos/Insumos_PorConfirmar.sql en esa base.
4. Restaurar y compilar: dotnet restore InventarioComidas.sln y dotnet build InventarioComidas.sln.
5. Ejecutar CapaPresentacion en Visual Studio o con dotnet run --project CapaPresentacion. El acceso requiere usuarios configurados en esa base.
6. Entrar como administrador y seguir *Configuración > Guía: por dónde empezar*: datos del negocio, insumos (con la plantilla de Excel), categorías, productos y recetas, adiciones y salsas, y usuarios.

## Alcance de la plantilla

No contiene pruebas, scripts SQL de instalación (solo BaseDatos/Insumos_PorConfirmar.sql), menú precargado, fotografías del cliente ni archivos de compilación. La base de datos existente no fue borrada ni modificada durante esta limpieza. Las fotos anteriores se archivaron fuera del proyecto; esta carpeta uploads está vacía para el nuevo negocio.

La plantilla no crea automáticamente una base nueva. La conexión BASE_DATOS_DEL_CLIENTE es un marcador y debe configurarse antes de ejecutar. La copia necesita una base compatible para funcionar.

## Cómo funciona el inventario

- **Insumos**: lo que se compra (pan, carne, gaseosas) y cuánto hay. Se cargan con la plantilla de Excel (Descargar plantilla / Subir plantilla).
- **Ventas**: al cobrar un pedido se descuentan los insumos de la receta de cada producto y de las adiciones elegidas. Los ingredientes que el cliente pide quitar ("Sin lechuga") no se descuentan. Si el pedido se edita o se anula, los insumos vuelven al inventario.
- **Registrar compras y salidas**: lo que pasa fuera de una venta (llegó una compra, se usó algo, se dañó).
- **Contar inventario**: corrige la cantidad cuando lo contado en el local no coincide con el sistema.
- **Cobrar después**: aparta el pedido solo en ese equipo; no se registra la venta, no va a cocina ni descuenta inventario hasta cobrarlo desde "Por cobrar".

## Perfiles

- **Administrador**: todo.
- **Cajero**: vende, cocina, domicilios y caja.
- **Domiciliario**: solo ve los domicilios, los despacha y los marca como entregados. No puede despachar mientras cocina no termina el pedido.
