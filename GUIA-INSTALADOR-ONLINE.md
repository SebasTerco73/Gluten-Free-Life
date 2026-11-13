# Guía: instalador online para una aplicación Node.js con PostgreSQL

## Objetivo

Este procedimiento convierte una aplicación web con frontend React/Vite y backend Node.js/TypeScript en un instalador para Windows. La PC del cliente no necesita tener VS Code, Node.js, npm ni PostgreSQL antes de ejecutar el instalador.

El instalador es **online**: descarga los componentes durante la instalación. No es un instalador completamente offline.

## Qué se preparó

En la carpeta `installer/` se encuentran:

- `Install-GlutenFreeLife.ps1`: script de instalación para Windows.
- `GlutenFreeLife.iss`: proyecto de Inno Setup que genera el `.exe`.
- `README.md`: instrucciones breves de uso y actualización.

El script hace lo siguiente:

1. Comprueba que PowerShell se ejecute como administrador.
2. Descarga e instala Node.js 22 si no existe.
3. Descarga e instala PostgreSQL 16 si no existe.
4. Crea el usuario de base `gfl` y la base `gfl`.
5. Ejecuta `npm ci` en backend y frontend.
6. Compila el backend y el frontend.
7. Genera un `JWT_SECRET` aleatorio.
8. Escribe `backend/.env` con rutas absolutas para Windows.
9. Ejecuta migraciones.
10. Carga datos de demostración solamente si la base no tiene usuarios.
11. Crea un acceso directo en el escritorio.
12. Puede iniciar el backend y abrir el navegador.

## Crear el ejecutable

La compilación del `.exe` se debe hacer en Windows:

1. Copiar el repositorio a una PC Windows.
2. Instalar Inno Setup desde <https://jrsoftware.org/isinfo.php>.
3. Abrir `installer/GlutenFreeLife.iss`.
4. Presionar **Compile**.
5. Entregar `installer/output/GlutenFreeLife-Setup.exe`.

El archivo resultante contiene el código fuente y los scripts, pero no contiene Node.js ni PostgreSQL. La PC del cliente necesita conexión a Internet durante la primera instalación.

## Probar sin compilar un `.exe`

Abrir PowerShell como administrador en la raíz del proyecto:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\installer\Install-GlutenFreeLife.ps1 -InstallRoot (Get-Location) -OpenBrowser
```

El resultado esperado es:

- Aplicación en `http://localhost:4000`.
- Usuario demo `admin`.
- Contraseña demo `1234`.
- Acceso directo `Gluten Free Life` en el escritorio.

## Decisiones de configuración

La aplicación se ejecuta en un solo proceso: el backend sirve también el `frontend/dist`. Por eso el cliente abre el puerto `4000`, no el puerto de desarrollo `5173`.

La base de datos queda en PostgreSQL local:

```text
Base: gfl
Usuario: gfl
Contraseña: gfl_dev
Puerto: 5432
```

La contraseña `gfl_dev` es una contraseña técnica local del instalador, no una contraseña de acceso de usuario. Para un entorno real conviene reemplazarla por una contraseña generada y guardarla fuera del repositorio.

## Actualizaciones

Para publicar una versión nueva:

1. Actualizar el código.
2. Verificar `npm run build` en backend y frontend.
3. Compilar un nuevo `GlutenFreeLife-Setup.exe`.
4. Conservar `backend/.env` y la base de datos del cliente.
5. Ejecutar las migraciones pendientes.

No ejecutar `npm run seed` sobre una base real: el seed completo borra datos de negocio. El instalador usa `seed:prod --if-empty`, por lo que solamente carga la demo cuando no hay usuarios.

## Respaldos

La base de datos y la carpeta `storage/` deben respaldarse por separado. Un ejemplo de respaldo de PostgreSQL, ejecutado con una cuenta con permisos, es:

```powershell
& 'C:\Program Files\PostgreSQL\16\bin\pg_dump.exe' -h localhost -U gfl -d gfl -F c -f 'C:\Backups\gfl.backup'
```

Para restaurar se utiliza `pg_restore` sobre una base vacía. Probar periódicamente que los respaldos puedan restaurarse.

## Limitaciones del instalador online

- Requiere Windows de 64 bits.
- Requiere permisos de administrador.
- Requiere Internet durante la instalación para descargar Node.js, PostgreSQL y paquetes npm.
- Las URLs de los instaladores externos están fijadas a Node.js 22.14.0 y PostgreSQL 16.4; deben revisarse antes de reutilizar el proceso en el futuro.
- Si ya existe PostgreSQL, el script supone que el usuario administrador `postgres` y su contraseña son los valores configurados. En ese caso puede ser necesario adaptar el parámetro `-PostgresPassword`.
- El instalador no elimina PostgreSQL ni la base de datos al desinstalar, para evitar pérdida accidental de información.

## Adaptarlo a otra app

1. Reemplazar las carpetas `backend/` y `frontend/`.
2. Mantener `package-lock.json` en cada proyecto.
3. Ajustar los comandos de build si la app usa otros scripts.
4. Ajustar `DATABASE_URL`, `PORT` y las variables de entorno requeridas.
5. Cambiar el comando de migración y el seed.
6. Cambiar la ruta del frontend si el backend no sirve archivos estáticos.
7. Cambiar el nombre, versión y GUID en el archivo `.iss`.
8. Probar primero el `.ps1` en una máquina virtual limpia.
9. Compilar el `.exe` y repetir la prueba con un usuario sin herramientas de desarrollo.
