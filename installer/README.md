# Instalador online de Gluten Free Life

Este instalador conserva la aplicación actual y automatiza la preparación de una PC Windows. Durante la instalación descarga Node.js 22 y PostgreSQL 16, crea la base `gfl`, instala dependencias npm, compila frontend y backend, ejecuta migraciones, carga la demo y crea un acceso directo.

## Uso directo sin crear un `.exe`

Abrir PowerShell como administrador en la carpeta del proyecto y ejecutar:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\installer\Install-GlutenFreeLife.ps1 -InstallRoot (Get-Location) -OpenBrowser
```

El instalador usa las contraseñas locales `postgres` (la indicada durante la instalación silenciosa) y `gfl_dev` para la aplicación. La demo se puede abrir con `admin` / `1234`.

## Crear el `.exe` con Inno Setup

1. En una PC Windows, instalar Inno Setup desde https://jrsoftware.org/isinfo.php.
2. Abrir `installer/GlutenFreeLife.iss` con Inno Setup.
3. Presionar **Compile**.
4. El resultado queda en `installer/output/GlutenFreeLife-Setup.exe`.
5. Copiar ese `.exe` a la PC del cliente y ejecutarlo como administrador.

El `.exe` es un instalador online: el archivo contiene el código de la aplicación, pero descarga Node.js y PostgreSQL durante la instalación. La PC necesita Internet la primera vez.

## Actualización

Para una actualización, reemplazar el contenido de la carpeta de la aplicación, conservar `backend/.env` y ejecutar nuevamente la compilación. No ejecutar `seed:prod` sobre datos reales: ese comando puede reemplazar datos de negocio. Las migraciones sí deben ejecutarse.

## Desinstalación y datos

La desinstalación de la aplicación no elimina PostgreSQL ni la base de datos. Esto evita perder información del comercio. Para eliminar datos hay que hacer un respaldo y borrar explícitamente la base `gfl`.
