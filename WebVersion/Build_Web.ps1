param([string]$Godot = 'D:\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe', [string]$Python = 'D:\Anaconda\python.exe')
$ErrorActionPreference = 'Stop'
$env:APPDATA = Join-Path $PSScriptRoot 'toolchain\userdata'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
& $Godot --headless --path (Join-Path $PSScriptRoot 'project') --export-release Web (Join-Path $PSScriptRoot 'site\game.html') --log-file (Join-Path $PSScriptRoot 'reports\export.log')
if ($LASTEXITCODE -ne 0) { throw 'Godot Web export failed.' }
if (Select-String -Path (Join-Path $PSScriptRoot 'reports\export.log') -Pattern 'SCRIPT ERROR|Parse Error|Failed to export' -Quiet) { throw 'Godot reported an export or script error. See reports/export.log.' }
& $Python (Join-Path $PSScriptRoot 'tools\finalize_site.py')
if ($LASTEXITCODE -ne 0) { throw 'Web packaging failed.' }
