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
}
finally {
    if (-not $game.HasExited) {
        $game.Kill()
    }
}

Write-Host "Windows release smoke test passed."
