$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$serverPath = Join-Path $projectRoot "bin\narra-server.exe"
$godotProject = Join-Path $projectRoot "godot"

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

function Stop-ExistingNarraServer {
    param(
        [int]$Port,
        [string]$ExpectedServerPath
    )
    $connections = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
    if ($connections.Count -eq 0) {
        return
    }
    $expectedPath = [System.IO.Path]::GetFullPath($ExpectedServerPath)
    $ownerIds = @($connections | Select-Object -ExpandProperty OwningProcess -Unique)
    foreach ($ownerId in $ownerIds) {
        $process = Get-CimInstance Win32_Process -Filter "ProcessId = $ownerId" -ErrorAction SilentlyContinue
        if ($null -eq $process -or [string]::IsNullOrWhiteSpace($process.ExecutablePath)) {
            throw "Port $Port is occupied by PID $ownerId, but its executable path cannot be verified. Refusing to terminate it."
        }
        $actualPath = [System.IO.Path]::GetFullPath($process.ExecutablePath)
        if (-not $actualPath.Equals($expectedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Port $Port is occupied by another program: PID $ownerId ($actualPath). Refusing to terminate it."
        }
        Write-Host "Stopping previous Narra service on port $Port (PID $ownerId)..."
        Stop-Process -Id $ownerId -Force
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    while ([DateTime]::UtcNow -lt $deadline) {
        if (Test-LocalPortAvailable -Port $Port) {
            return
        }
        Start-Sleep -Milliseconds 50
    }
    throw "Port $Port was not released after stopping the previous Narra service."
}

function Wait-NarraServer {
    param([System.Diagnostics.Process]$Process)
    $deadline = [DateTime]::UtcNow.AddSeconds(8)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($Process.HasExited) {
            throw "The newly built Narra service exited before becoming healthy. Check whether port 8787 is available."
        }
        try {
            Invoke-RestMethod -Uri "http://127.0.0.1:8787/api/v1/health" -TimeoutSec 1 | Out-Null
            return
        }
        catch {
            Start-Sleep -Milliseconds 50
        }
    }
    throw "Timed out waiting for the newly built Narra service."
}

New-Item -ItemType Directory -Force (Split-Path -Parent $serverPath) | Out-Null
Push-Location $projectRoot
try {
    Stop-ExistingNarraServer -Port 8787 -ExpectedServerPath $serverPath
    go build -o $serverPath ./cmd/server
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $server = Start-Process -FilePath $serverPath -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru
    try {
        Wait-NarraServer -Process $server
        & godot --path $godotProject
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    finally {
        if (-not $server.HasExited) {
            Stop-Process -Id $server.Id
            $server.WaitForExit()
        }
    }
}
finally {
    Pop-Location
}
