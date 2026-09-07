$ErrorActionPreference = 'Stop'
$webRoot = Split-Path -Parent $PSScriptRoot
$webUrl = 'http://127.0.0.1:9089/'
$ready = $false
try { $ready = (Invoke-RestMethod ($webUrl + 'health') -TimeoutSec 2).app -eq 'rainrot-web' } catch {}
if (-not $ready) {
    $pythonPath = @('D:\Anaconda\python.exe', (Get-Command python.exe -ErrorAction SilentlyContinue).Source, (Get-Command py.exe -ErrorAction SilentlyContinue).Source) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    if (-not $pythonPath) { throw 'Python 3 was not found. Install Python 3, or host the site folder on a static HTTP server.' }
    $serverScript = Join-Path $PSScriptRoot 'serve.py'
    $server = Start-Process -FilePath $pythonPath -ArgumentList @(('"' + $serverScript + '"'), '--port', '9089') -WorkingDirectory $webRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $webRoot 'reports\server.log') -RedirectStandardError (Join-Path $webRoot 'reports\server-errors.log')
    $server.Id | Set-Content (Join-Path $webRoot 'reports\server.pid')
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        Start-Sleep -Milliseconds 250
        try { $ready = (Invoke-RestMethod ($webUrl + 'health') -TimeoutSec 1).app -eq 'rainrot-web' } catch {}
        if ($ready) { break }
    }
    if (-not $ready) { throw 'The local web server could not start. See reports/server-errors.log; port 9089 may be in use.' }
}
Start-Process $webUrl
