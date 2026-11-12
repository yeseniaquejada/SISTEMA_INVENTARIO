# Publicación y scripts SQL automáticos (12/11/2026)

Objetivo: que usted no tenga que copiar carpetas, abrir SSMS ni publicar a mano. Claude trabaja
directo en el código de su PC (`.claude\worktrees\prueba-iis`), deja cada cambio de base de datos como
un script numerado y corre un solo comando que ejecuta los SQL pendientes y publica.

## Qué hay aquí

| Ruta | Para qué |
|---|---|
| `herramientas\configurar.ps1` | Guarda servidor, base, usuario y clave **cifrados con Windows** (solo su usuario, en su PC). Se corre una vez. |
| `herramientas\aplicar-sql.ps1` | Ejecuta en orden los scripts de `BaseDatos\Cambios` que falten y los anota en la tabla `HISTORIAL_SCRIPTS` de la base. Nunca corre dos veces el mismo. |
| `herramientas\publicar.ps1` | Compila y deja un zip en `publicado-zip\` para subirlo en el panel del hosting, sin `appsettings.json` ni fotos. También soporta Web Deploy o carpeta de IIS si algún día se usan. |
| `herramientas\desplegar.ps1` | Los dos pasos en orden: primero SQL, luego publicar. Si un SQL falla, no publica. |
| `herramientas\publicacion.config.ejemplo.json` | Plantilla del método de publicación (sin claves). |
| `BaseDatos\Cambios\004…010` | Los scripts que ya teníamos, en orden y con 3 dígitos (había dos "08"). |
| `BaseDatos\PorConfirmar\` | Scripts de `inventario-cliente` que no sé si se corrieron. No se ejecutan solos. |

Orden de los scripts (por fecha):

| Nuevo nombre | Antes |
|---|---|
| 004_Caja_EditarBase | cambios-caja-base/04 |
| 005_Arreglo_SP_CAJA_EDITAR_BASE | cambios-caja-base/05 |
| 006_Arreglo_SP_INSUMO_ELIMINAR | arreglo-eliminar-insumo/06 |
| 007_Quitar_Gaseosa_De_Nombres | quitar-gaseosa-nombre/07 |
| 008_Lista_Compras | lista-compras-caja/08 |
| 009_Gaseosas_Nachos_Ziploc | gaseosas-nachos-ziploc/08 |
| 010_Revertir_400ml_y_Buscar_Latas | gaseosas-nachos-ziploc/09 |

## Instalación (una sola vez, la hace Claude con su permiso)

1. Copiar `herramientas\` y `BaseDatos\Cambios\` a la raíz de `prueba-iis` y agregar al `.gitignore`:
   `publicado/`, `publicado-zip/`, `BaseDatos/Resultados/`, `herramientas/publicacion.config.json`.
2. Crear `herramientas\publicacion.config.json` a partir del ejemplo (método Zip y la dirección de la página).
3. **Usted** abre PowerShell en `prueba-iis\herramientas` y corre:
   ```
   .\configurar.ps1 -Que BaseDatos -Entorno hosting
   ```
   Escribe la clave en la ventanita de Windows. La clave no pasa por el chat ni queda en el código.
4. Marcar lo que ya se ejecutó en el hosting, por ejemplo si ya corrió hasta el 010:
   `.\aplicar-sql.ps1 -Entorno hosting -MarcarHasta 010`

## Uso diario

Usted pide el cambio en el chat. Claude edita el código, agrega `BaseDatos\Cambios\011_….sql` si hace falta,
compila, y con su visto bueno corre `.\desplegar.ps1 -Entorno hosting -SinPreguntar`: ejecuta los SQL pendientes en el hosting y deja el zip listo. Usted solo sube el zip en el panel.
Para ver qué falta sin tocar nada: `.\aplicar-sql.ps1 -Entorno hosting -Ver`.
El resultado de cada ejecución queda en `BaseDatos\Resultados\`.

Si un SQL sale mal no se edita el ya ejecutado: se crea el siguiente número con la corrección.
