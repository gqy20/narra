param(
    [ValidateSet("fast", "full")]
    [string]$Mode = "full"
)

$ErrorActionPreference = "Stop"

function Test-LocalPortAvailable {
    param([int]$Port)
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
    try {
        $listener.Start()
        return $true
    }
    catch {
        return $false
    }
    finally {
        $listener.Stop()
    }
}

function Wait-NarraServer {
    param([System.Diagnostics.Process]$Process)
    $deadline = [DateTime]::UtcNow.AddSeconds(8)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($Process.HasExited) {
            throw "Narra server exited before becoming healthy."
        }
        try {
            Invoke-RestMethod -Uri "http://127.0.0.1:8787/api/v1/health" -TimeoutSec 1 | Out-Null
            return
        }
        catch {
            Start-Sleep -Milliseconds 50
        }
    }
    throw "Timed out waiting for the Narra server health endpoint."
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$serverPath = Join-Path $projectRoot "bin\narra-server.exe"
$godotProject = Join-Path $projectRoot "godot"
$godot = Get-Command godot -ErrorAction Stop
$verificationStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

New-Item -ItemType Directory -Force (Split-Path -Parent $serverPath) | Out-Null
Push-Location $projectRoot
try {
    go build -o $serverPath ./cmd/server
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    if ($Mode -eq "full") {
        & $godot.Source --headless --path $godotProject --editor --quit
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    if (-not (Test-LocalPortAvailable -Port 8787)) {
        throw "Port 8787 is already in use; refusing to reuse an unknown service."
    }
    $server = Start-Process -FilePath $serverPath -WorkingDirectory $projectRoot -WindowStyle Hidden -ArgumentList @("-ai-enabled=false") -PassThru
    try {
        Wait-NarraServer -Process $server
        if ($Mode -eq "full") {
            & $godot.Source --headless --path $godotProject --script res://tests/api_contract.gd
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

            & $godot.Source --headless --path $godotProject --script res://tests/scenario_selection.gd
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }

        & $godot.Source --headless --path $godotProject --script res://tests/integration.gd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        if ($Mode -eq "full") {
            & $godot.Source --headless --path $godotProject --script res://tests/propagation.gd
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

            & $godot.Source --headless --path $godotProject --script res://tests/contender.gd
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

            & $godot.Source --headless --path $godotProject --script res://tests/diagnostics.gd
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

            & $godot.Source --headless --path $godotProject --script res://tests/logging.gd
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
    }
    finally {
        if (-not $server.HasExited) {
            Stop-Process -Id $server.Id
            $server.WaitForExit()
        }
    }

    $temporarySaves = Join-Path ([System.IO.Path]::GetTempPath()) ("narra-tianqi-saves-" + [Guid]::NewGuid().ToString("N"))
    $resolvedTemporarySaves = [System.IO.Path]::GetFullPath($temporarySaves)
    $resolvedTemporaryBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
    if (-not $resolvedTemporarySaves.StartsWith("$resolvedTemporaryBase\narra-tianqi-saves-", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to use an unsafe temporary save path: $resolvedTemporarySaves"
    }
    New-Item -ItemType Directory -Path $resolvedTemporarySaves -Force | Out-Null
    if (-not (Test-LocalPortAvailable -Port 8787)) {
        throw "Port 8787 is still in use before the tianqi verification."
    }
    $tianqiServer = Start-Process -FilePath $serverPath -WorkingDirectory $projectRoot -WindowStyle Hidden -ArgumentList @(
        "-data", (Join-Path $projectRoot "data\tianqi"),
        "-saves", $resolvedTemporarySaves,
        "-ai-enabled=false"
    ) -PassThru
    try {
        Wait-NarraServer -Process $tianqiServer
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

    if ($Mode -eq "full") {
        $orbitalTemporarySaves = Join-Path ([System.IO.Path]::GetTempPath()) ("narra-orbital-saves-" + [Guid]::NewGuid().ToString("N"))
        $resolvedOrbitalSaves = [System.IO.Path]::GetFullPath($orbitalTemporarySaves)
        if (-not $resolvedOrbitalSaves.StartsWith("$resolvedTemporaryBase\narra-orbital-saves-", [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to use an unsafe orbital save path: $resolvedOrbitalSaves"
        }
        New-Item -ItemType Directory -Path $resolvedOrbitalSaves -Force | Out-Null
        if (-not (Test-LocalPortAvailable -Port 8787)) {
            throw "Port 8787 is still in use before the orbital verification."
        }
        $orbitalServer = Start-Process -FilePath $serverPath -WorkingDirectory $projectRoot -WindowStyle Hidden -ArgumentList @(
            "-data", (Join-Path $projectRoot "data\orbital"),
            "-saves", $resolvedOrbitalSaves,
            "-ai-enabled=false"
        ) -PassThru
        try {
            Wait-NarraServer -Process $orbitalServer
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
}
finally {
    Pop-Location
}

$verificationStopwatch.Stop()
Write-Host ("Godot {0} verification passed in {1:N2}s." -f $Mode, $verificationStopwatch.Elapsed.TotalSeconds)
