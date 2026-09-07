$pidFile = Join-Path (Split-Path -Parent $PSScriptRoot) 'reports\server.pid'
if (-not (Test-Path -LiteralPath $pidFile)) { Write-Output 'No local web server PID is recorded.'; exit }
$webServerId = [int](Get-Content -LiteralPath $pidFile)
$webProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $webServerId" -ErrorAction SilentlyContinue
if ($webProcess -and $webProcess.CommandLine -match 'WebVersion[\\/].*tools[\\/]serve\.py' -and $webProcess.CommandLine -match '--port[ ]+9089') {
    Stop-Process -Id $webServerId
    Write-Output 'RAINROT local web server stopped.'
} else { Write-Output 'The recorded process is no longer this web server; no process was stopped.' }
