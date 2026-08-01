$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$serverPath = Join-Path $projectRoot "bin\fantu-server.exe"
$godotProject = Join-Path $projectRoot "godot"
$screenshotDirectory = Join-Path $projectRoot "artifacts\screenshots"
$moviePath = Join-Path $screenshotDirectory "ui-capture-source.avi"
$godot = Get-Command godot -ErrorAction Stop

New-Item -ItemType Directory -Force (Split-Path -Parent $serverPath) | Out-Null
New-Item -ItemType Directory -Force $screenshotDirectory | Out-Null
Push-Location $projectRoot
try {
    go build -o $serverPath ./cmd/server
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $server = Start-Process -FilePath $serverPath -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru
    try {
        Start-Sleep -Milliseconds 500
        & $godot.Source --path $godotProject --resolution 2048x1152 --write-movie $moviePath --fixed-fps 10 --disable-vsync --script res://demo/capture_ui_states.gd
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

if (Test-Path -LiteralPath $moviePath) {
    Remove-Item -LiteralPath $moviePath
}
Write-Host "UI state screenshots captured in artifacts/screenshots."
