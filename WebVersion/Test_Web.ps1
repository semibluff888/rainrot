param(
    [string]$Godot = 'D:\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe',
    [string]$Node = 'node',
    [switch]$Rendered
)
$ErrorActionPreference='Stop'
$workspace=Split-Path $PSScriptRoot -Parent
$testRoot=Join-Path $workspace '.runtime/web-performance'
New-Item -ItemType Directory -Force $testRoot | Out-Null
$previousAppData=$env:APPDATA
try {
    $env:APPDATA=Join-Path $testRoot 'test-userdata'
    New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
    & $Node --test (Join-Path $PSScriptRoot 'tools/test_shell.cjs')
    if ($LASTEXITCODE -ne 0) { throw 'Web shell checks failed' }
    $runs=@(
        @{Name='integration';Flags=@('--test')},
        @{Name='enemies';Flags=@('--enemy-test')},
        @{Name='walkthrough';Flags=@('--walkthrough')},
        @{Name='pacifist';Flags=@('--walkthrough','--pacifist')}
    )
    if ($Rendered) { $runs+=@{Name='controls-rendered';Flags=@('--web-performance-test')} }
    foreach ($run in $runs) {
        $logPath=Join-Path $testRoot ($run.Name+'.log')
        $renderArgs=if ($run.Name -eq 'controls-rendered') { @() } else { @('--headless') }
        & $Godot @renderArgs --fixed-fps 60 --quit-after 60000 --path (Join-Path $PSScriptRoot 'project') --log-file $logPath -- @($run.Flags) > ($logPath+'.output.txt') 2>&1
        if ($LASTEXITCODE -ne 0 -or (Select-String -Path $logPath -Pattern '^SCRIPT ERROR|^ERROR:|^FAIL ' -Quiet)) {
            Get-Content -LiteralPath $logPath -Tail 20
            throw ($run.Name+' failed')
        }
        $marker=switch ($run.Name) {
            'integration' { 'TEST_RESULT passed=55 failed=0' }
            'enemies' { 'ENEMY_TEST_RESULT passed=52 failed=0' }
            'controls-rendered' { '"failed":0' }
            default { 'WALKTHROUGH_COMPLETE' }
        }
        if (-not (Select-String -LiteralPath $logPath -SimpleMatch $marker -Quiet)) { throw ($run.Name+' did not complete') }
        Write-Output ($run.Name+': passed')
    }
} finally {
    $env:APPDATA=$previousAppData
}
