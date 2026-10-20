# Plantilla de sistema para negocios de comidas

ASP.NET Core MVC (.NET 10), C# y SQL Server. Incluye ventas, caja, cocina, domicilios, inventario, reportes, auditoría, impresión y temas claro/oscuro.

## Estructura

- CapaEntidad: modelos.
- CapaDatos: conexión y repositorios SQL.
- CapaNegocio: reglas y validaciones.
- CapaPresentacion: controladores, vistas y recursos de interfaz.

## Preparar una copia para un cliente

1. Copiar las cuatro carpetas de código, InventarioComidas.sln, .gitignore y este README. No copiar .git para iniciar un proyecto independiente.
2. Preparar una base SQL Server con el esquema y procedimientos compatibles del sistema. Esta carpeta no contiene SQL de instalación ni datos iniciales.
3. En CapaPresentacion/appsettings.json reemplazar BASE_DATOS_DEL_CLIENTE por el nombre de la nueva base y configurar el servidor. No apuntar la copia a la base de otro negocio.
4. Restaurar y compilar: dotnet restore InventarioComidas.sln y dotnet build InventarioComidas.sln.
5. Ejecutar CapaPresentacion en Visual Studio o con dotnet run --project CapaPresentacion. El acceso requiere usuarios configurados en esa base.
6. Configurar nombre, logo, colores, módulos, ticket y sede desde el sistema. Cargar menú, precios, recetas, opciones y existencias reales del cliente.

## Alcance de la plantilla

No contiene pruebas, scripts SQL, menú precargado, fotografías del cliente ni archivos de compilación. La base de datos existente no fue borrada ni modificada durante esta limpieza. Las fotos anteriores se archivaron fuera del proyecto; esta carpeta uploads está vacía para el nuevo negocio.

La plantilla no crea automáticamente una base nueva. La conexión BASE_DATOS_DEL_CLIENTE es un marcador y debe configurarse antes de ejecutar. La copia necesita una base compatible para funcionar.
