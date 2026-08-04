$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$serverPath = Join-Path $projectRoot "bin\narra-server.exe"
$godotProject = Join-Path $projectRoot "godot"
$auditDirectory = Join-Path $projectRoot "artifacts\audits\playability-2026-08-01"
$moviePath = Join-Path $auditDirectory "audit-capture-source.avi"
$godot = Get-Command godot -ErrorAction Stop

New-Item -ItemType Directory -Force (Split-Path -Parent $serverPath) | Out-Null
New-Item -ItemType Directory -Force $auditDirectory | Out-Null
Push-Location $projectRoot
try {
    go build -o $serverPath ./cmd/server
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $server = Start-Process -FilePath $serverPath -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru
    try {
        Start-Sleep -Milliseconds 500
        & $godot.Source --path $godotProject --resolution 2048x1152 --write-movie $moviePath --fixed-fps 10 --disable-vsync --script res://demo/capture_playability_audit.gd
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
Write-Host "Playability audit screenshots captured in artifacts/audits/playability-2026-08-01."
