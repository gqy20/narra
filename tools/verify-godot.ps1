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

    $server = Start-Process -FilePath $serverPath -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru
    try {
        Start-Sleep -Milliseconds 500
        & $godot.Source --headless --path $godotProject --script res://tests/integration.gd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        & $godot.Source --headless --path $godotProject --script res://tests/propagation.gd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        & $godot.Source --headless --path $godotProject --script res://tests/contender.gd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        & $godot.Source --headless --path $godotProject --script res://tests/diagnostics.gd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    finally {
        if (-not $server.HasExited) {
            Stop-Process -Id $server.Id
        }
    }
}
finally {
    Pop-Location
}

Write-Host "Godot verification passed."
