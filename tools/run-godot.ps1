$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$serverPath = Join-Path $projectRoot "bin\fantu-server.exe"
$godotProject = Join-Path $projectRoot "godot"

New-Item -ItemType Directory -Force (Split-Path -Parent $serverPath) | Out-Null
Push-Location $projectRoot
try {
    go build -o $serverPath ./cmd/server
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $server = Start-Process -FilePath $serverPath -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru
    try {
        & godot --path $godotProject
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
