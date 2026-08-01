[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackageDirectory
)

$ErrorActionPreference = "Stop"

$packageDirectory = (Resolve-Path -LiteralPath $PackageDirectory).Path
$gamePath = Join-Path $packageDirectory "Fantu.exe"
if (-not (Test-Path -LiteralPath $gamePath -PathType Leaf)) {
    throw "Fantu.exe was not found in the package directory."
}

$existingServerIds = @(
    Get-Process -Name "fantu-server" -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Id
)
if ($existingServerIds.Count -gt 0) {
    throw "A fantu-server process is already running; stop it before the release smoke test."
}

$game = Start-Process `
    -FilePath $gamePath `
    -ArgumentList @("--headless", "--quit-after", "600") `
    -WorkingDirectory $packageDirectory `
    -WindowStyle Hidden `
    -PassThru

$runtimeRoot = Join-Path $env:APPDATA "Fantu"
$logsDirectory = Join-Path $runtimeRoot "logs"
$clientLog = Join-Path $logsDirectory "client.log"
$serverLog = Join-Path $logsDirectory "server.log"

$healthPassed = $false
try {
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        try {
            $response = Invoke-RestMethod -Uri "http://127.0.0.1:8787/api/v1/health" -TimeoutSec 1
            if ($response.api_version -eq "v1") {
                $healthPassed = $true
                break
            }
        }
        catch {
            Start-Sleep -Milliseconds 250
        }
    }

    if (-not $game.WaitForExit(20000)) {
        throw "Fantu.exe did not exit after the smoke-test timeout."
    }
    if ($game.ExitCode -ne 0) {
        throw "Fantu.exe exited with code $($game.ExitCode)."
    }
    if (-not $healthPassed) {
        throw "The bundled rules service did not pass its health check."
    }

    Start-Sleep -Milliseconds 500
    $remainingServers = @(
        Get-Process -Name "fantu-server" -ErrorAction SilentlyContinue |
            Where-Object { $existingServerIds -notcontains $_.Id }
    )
    if ($remainingServers.Count -gt 0) {
        throw "The bundled rules service remained active after Fantu.exe exited."
    }

    foreach ($directoryName in @("logs", "logs\archived", "saves", "crash")) {
        $directoryPath = Join-Path $runtimeRoot $directoryName
        if (-not (Test-Path -LiteralPath $directoryPath -PathType Container)) {
            throw "Expected runtime directory was not created: $directoryPath"
        }
    }
    if (-not (Test-Path -LiteralPath $clientLog -PathType Leaf)) {
        throw "The packaged client did not create client.log."
    }
    if (-not (Test-Path -LiteralPath $serverLog -PathType Leaf)) {
        throw "The packaged rules service did not create server.log."
    }
    $serverLogContent = Get-Content -LiteralPath $serverLog -Raw
    foreach ($expectedServerField in @("component=server", "event=listening", "session=", "version=", 'url="http://127.0.0.1:8787"')) {
        if ($serverLogContent -notmatch [regex]::Escape($expectedServerField)) {
            throw "server.log does not contain expected diagnostic field: $expectedServerField"
        }
    }
    $clientLogContent = Get-Content -LiteralPath $clientLog -Raw
    foreach ($expectedClientField in @("component=client", "event=startup", "session=", "version=")) {
        if ($clientLogContent -notmatch [regex]::Escape($expectedClientField)) {
            throw "client.log does not contain expected diagnostic field: $expectedClientField"
        }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $packageDirectory "build-info.json") -PathType Leaf)) {
        throw "The Windows package does not contain build-info.json."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $packageDirectory "Fantu-Portable.cmd") -PathType Leaf)) {
        throw "The Windows package does not contain Fantu-Portable.cmd."
    }
}
finally {
    if (-not $game.HasExited) {
        $game.Kill()
    }
}

Write-Host "Windows release smoke test passed."
