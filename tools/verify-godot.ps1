$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$serverPath = Join-Path $projectRoot "bin\fantu-server.exe"
$godotProject = Join-Path $projectRoot "godot"
$godot = Get-Command godot -ErrorAction Stop

New-Item -ItemType Directory -Force (Split-Path -Parent $serverPath) | Out-Null
Push-Location $projectRoot
try {
    go build -o $serverPath ./cmd/server
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & $godot.Source --headless --path $godotProject --editor --quit
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $server = Start-Process -FilePath $serverPath -WorkingDirectory $projectRoot -WindowStyle Hidden -ArgumentList @("-ai-enabled=false") -PassThru
    try {
        Start-Sleep -Milliseconds 500
        & $godot.Source --headless --path $godotProject --script res://tests/api_contract.gd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        & $godot.Source --headless --path $godotProject --script res://tests/scenario_selection.gd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        & $godot.Source --headless --path $godotProject --script res://tests/integration.gd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        & $godot.Source --headless --path $godotProject --script res://tests/propagation.gd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        & $godot.Source --headless --path $godotProject --script res://tests/contender.gd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        & $godot.Source --headless --path $godotProject --script res://tests/diagnostics.gd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        & $godot.Source --headless --path $godotProject --script res://tests/logging.gd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    finally {
        if (-not $server.HasExited) {
            Stop-Process -Id $server.Id
            $server.WaitForExit()
        }
    }

    $temporarySaves = Join-Path ([System.IO.Path]::GetTempPath()) ("fantu-tianqi-saves-" + [Guid]::NewGuid().ToString("N"))
    $resolvedTemporarySaves = [System.IO.Path]::GetFullPath($temporarySaves)
    $resolvedTemporaryBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
    if (-not $resolvedTemporarySaves.StartsWith("$resolvedTemporaryBase\fantu-tianqi-saves-", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to use an unsafe temporary save path: $resolvedTemporarySaves"
    }
    New-Item -ItemType Directory -Path $resolvedTemporarySaves -Force | Out-Null
    $tianqiServer = Start-Process -FilePath $serverPath -WorkingDirectory $projectRoot -WindowStyle Hidden -ArgumentList @(
        "-data", (Join-Path $projectRoot "data\tianqi"),
        "-saves", $resolvedTemporarySaves,
        "-ai-enabled=false"
    ) -PassThru
    try {
        Start-Sleep -Milliseconds 500
        & $godot.Source --headless --path $godotProject --script res://tests/scenario_switch.gd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    finally {
        if (-not $tianqiServer.HasExited) {
            Stop-Process -Id $tianqiServer.Id
            $tianqiServer.WaitForExit()
        }
        if (Test-Path -LiteralPath $resolvedTemporarySaves) {
            Remove-Item -LiteralPath $resolvedTemporarySaves -Recurse -Force
        }
    }

    $orbitalTemporarySaves = Join-Path ([System.IO.Path]::GetTempPath()) ("fantu-orbital-saves-" + [Guid]::NewGuid().ToString("N"))
    $resolvedOrbitalSaves = [System.IO.Path]::GetFullPath($orbitalTemporarySaves)
    if (-not $resolvedOrbitalSaves.StartsWith("$resolvedTemporaryBase\fantu-orbital-saves-", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to use an unsafe orbital save path: $resolvedOrbitalSaves"
    }
    New-Item -ItemType Directory -Path $resolvedOrbitalSaves -Force | Out-Null
    $orbitalServer = Start-Process -FilePath $serverPath -WorkingDirectory $projectRoot -WindowStyle Hidden -ArgumentList @(
        "-data", (Join-Path $projectRoot "data\orbital"),
        "-saves", $resolvedOrbitalSaves,
        "-ai-enabled=false"
    ) -PassThru
    try {
        Start-Sleep -Milliseconds 500
        & $godot.Source --headless --path $godotProject --script res://tests/scenario_portability.gd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    finally {
        if (-not $orbitalServer.HasExited) {
            Stop-Process -Id $orbitalServer.Id
            $orbitalServer.WaitForExit()
        }
        if (Test-Path -LiteralPath $resolvedOrbitalSaves) {
            Remove-Item -LiteralPath $resolvedOrbitalSaves -Recurse -Force
        }
    }
}
finally {
    Pop-Location
}

Write-Host "Godot verification passed."
