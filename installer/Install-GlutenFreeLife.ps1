[CmdletBinding()]
param(
  [string]$InstallRoot = (Split-Path -Parent $PSScriptRoot),
  [string]$PostgresPassword = 'gfl_dev',
  [switch]$OpenBrowser
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Assert-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]$identity
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Este instalador debe ejecutarse como administrador.'
  }
}

function Download-File([string]$Url, [string]$Destination) {
  Write-Host "Descargando $Url"
  Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
}

function Get-CommandPath([string]$Name, [string[]]$Candidates) {
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }
  foreach ($candidate in $Candidates) {
    if (Test-Path $candidate) { return $candidate }
  }
  return $null
}

function Invoke-PostgresSql([string]$Psql, [string]$Sql) {
  & $Psql -h localhost -U postgres -d postgres -v ON_ERROR_STOP=1 -c $Sql
  if ($LASTEXITCODE -ne 0) {
    throw "No se pudo ejecutar SQL de PostgreSQL."
  }
}

Assert-Administrator
$InstallRoot = [IO.Path]::GetFullPath($InstallRoot)
$downloadDir = Join-Path $env:TEMP 'GlutenFreeLifeInstaller'
New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $InstallRoot 'storage\pedidos') | Out-Null

Write-Step 'Instalando Node.js 22'
$node = Get-CommandPath 'node' @(
  "$env:ProgramFiles\nodejs\node.exe",
  "${env:ProgramFiles(x86)}\nodejs\node.exe"
)
if (-not $node) {
  $nodeMsi = Join-Path $downloadDir 'node-v22.14.0-x64.msi'
  if (-not (Test-Path $nodeMsi)) {
    Download-File 'https://nodejs.org/dist/v22.14.0/node-v22.14.0-x64.msi' $nodeMsi
  }
  $process = Start-Process msiexec.exe -ArgumentList "/i `"$nodeMsi`" /qn /norestart" -Wait -PassThru
  if ($process.ExitCode -notin @(0, 3010)) {
    throw "La instalación de Node.js terminó con código $($process.ExitCode)."
  }
  $node = Get-CommandPath 'node' @("$env:ProgramFiles\nodejs\node.exe")
}
if (-not $node) { throw 'No se encontró Node.js después de instalarlo.' }
$nodeDir = Split-Path -Parent $node
$npm = Join-Path $nodeDir 'npm.cmd'

Write-Step 'Instalando PostgreSQL 16'
$psql = Get-CommandPath 'psql' @(
  "$env:ProgramFiles\PostgreSQL\16\bin\psql.exe",
  "${env:ProgramFiles(x86)}\PostgreSQL\16\bin\psql.exe"
)
if (-not $psql) {
  $postgresExe = Join-Path $downloadDir 'postgresql-16.4-1-windows-x64.exe'
  if (-not (Test-Path $postgresExe)) {
    Download-File 'https://get.enterprisedb.com/postgresql/postgresql-16.4-1-windows-x64.exe' $postgresExe
  }
  $arguments = "--mode unattended --unattendedmodeui none --superpassword `"$PostgresPassword`" --serverport 5432"
  $process = Start-Process $postgresExe -ArgumentList $arguments -Wait -PassThru
  if ($process.ExitCode -ne 0) {
    throw "La instalación de PostgreSQL terminó con código $($process.ExitCode)."
  }
  $psql = Get-CommandPath 'psql' @("$env:ProgramFiles\PostgreSQL\16\bin\psql.exe")
}
if (-not $psql) { throw 'No se encontró PostgreSQL después de instalarlo.' }

Write-Step 'Configurando la base de datos'
$env:PGPASSWORD = $PostgresPassword
try {
  $roleSql = "DO `$`$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'gfl') THEN CREATE ROLE gfl LOGIN PASSWORD 'gfl_dev'; ELSE ALTER ROLE gfl WITH LOGIN PASSWORD 'gfl_dev'; END IF; END `$`$;"
  Invoke-PostgresSql $psql $roleSql
  $databaseExists = & $psql -h localhost -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = 'gfl';"
  if ($LASTEXITCODE -ne 0) { throw 'No se pudo comprobar la base de datos gfl.' }
  if ($databaseExists.Trim() -ne '1') {
    Invoke-PostgresSql $psql "CREATE DATABASE gfl OWNER gfl;"
  }
} finally {
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}

$backend = Join-Path $InstallRoot 'backend'
$frontend = Join-Path $InstallRoot 'frontend'
Write-Step 'Instalando dependencias y compilando la aplicación'
Push-Location $backend
try {
  & $npm 'ci'
  if ($LASTEXITCODE -ne 0) { throw 'Falló la instalación de dependencias del backend.' }
  & $npm 'run' 'build'
  if ($LASTEXITCODE -ne 0) { throw 'Falló la compilación del backend.' }
  & $npm 'prune' '--omit=dev'
  if ($LASTEXITCODE -ne 0) { throw 'Falló la limpieza de dependencias de desarrollo del backend.' }
} finally {
  Pop-Location
}
Push-Location $frontend
try {
  & $npm 'ci'
  if ($LASTEXITCODE -ne 0) { throw 'Falló la instalación de dependencias del frontend.' }
  & $npm 'run' 'build'
  if ($LASTEXITCODE -ne 0) { throw 'Falló la compilación del frontend.' }
} finally {
  Pop-Location
}

Write-Step 'Creando configuración y cargando la demostración'
$jwt = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
$envFile = @"
DATABASE_URL=postgres://gfl:gfl_dev@localhost:5432/gfl
JWT_SECRET=$jwt
PORT=4000
CORS_ORIGIN=http://localhost:4000
TZ_NEGOCIO=America/Argentina/Buenos_Aires
FRONTEND_DIST=$($frontend.Replace('\', '/'))/dist
STORAGE_DIR=$($InstallRoot.Replace('\', '/'))/storage
"@
Set-Content -Path (Join-Path $backend '.env') -Value $envFile -Encoding utf8
Push-Location $backend
try {
  & $npm 'run' 'migrate:prod'
  if ($LASTEXITCODE -ne 0) { throw 'Fallaron las migraciones.' }
  & $npm 'run' 'seed:prod' '--' '--if-empty'
  if ($LASTEXITCODE -ne 0) { throw 'Falló la carga de datos de demostración.' }
} finally {
  Pop-Location
}

Write-Step 'Creando acceso directo e iniciando la aplicación'
$startScript = Join-Path $InstallRoot 'Start-GlutenFreeLife.ps1'
@"
`$env:PATH = '$nodeDir;' + `$env:PATH
Set-Location '$backend'
& '$node' 'dist/index.js'
"@ | Set-Content -Path $startScript -Encoding utf8
$shortcutPath = Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'Gluten Free Life.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = 'powershell.exe'
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$startScript`""
$shortcut.WorkingDirectory = $backend
$shortcut.Description = 'Iniciar Gluten Free Life'
$shortcut.Save()

if ($OpenBrowser) {
  Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$startScript`""
  Start-Sleep -Seconds 5
  Start-Process 'http://localhost:4000'
}

Write-Host "`nInstalación finalizada. Usuario: admin  Contraseña: 1234" -ForegroundColor Green
