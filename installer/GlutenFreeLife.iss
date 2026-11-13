#define AppName "Gluten Free Life"
#define AppVersion "1.0.0"
#define AppPublisher "Gluten Free Life"

[Setup]
AppId={{B1E3F8C0-4E9D-4C6C-A9CE-3D2D1C0D4B89}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\Gluten Free Life
DefaultGroupName={#AppName}
OutputDir=output
OutputBaseFilename=GlutenFreeLife-Setup
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64
WizardStyle=modern

[Files]
Source: "..\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: ".git\*,node_modules\*,dist\*,installer\output\*,backend\.env,frontend\.env,docs\*.pdf"

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\installer\Install-GlutenFreeLife.ps1"" -InstallRoot ""{app}"" -OpenBrowser"; Flags: runascurrentuser waituntilterminated

[UninstallDelete]
Type: filesandordirs; Name: "{app}\backend\node_modules"
Type: filesandordirs; Name: "{app}\frontend\node_modules"
