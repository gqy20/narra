param(
    [string]$DataDirectory = "",
    [string]$OutputDirectory = "",
    [string[]]$Resolutions = @("2048x1152"),
    [switch]$KnowledgeGraphOnly
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$serverPath = Join-Path $projectRoot "bin\narra-server.exe"
$godotProject = Join-Path $projectRoot "godot"
$screenshotDirectory = if ($OutputDirectory) { [System.IO.Path]::GetFullPath($OutputDirectory) } else { Join-Path $projectRoot "artifacts\screenshots" }
$godot = Get-Command godot -ErrorAction Stop
$captureStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$temporarySaves = Join-Path ([System.IO.Path]::GetTempPath()) ("narra-ui-capture-" + [Guid]::NewGuid().ToString("N"))
$resolvedTemporarySaves = [System.IO.Path]::GetFullPath($temporarySaves)
$resolvedTemporaryBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
if (-not $resolvedTemporarySaves.StartsWith("$resolvedTemporaryBase\narra-ui-capture-", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use an unsafe temporary save path: $resolvedTemporarySaves"
}

New-Item -ItemType Directory -Force (Split-Path -Parent $serverPath) | Out-Null
New-Item -ItemType Directory -Force $screenshotDirectory | Out-Null
New-Item -ItemType Directory -Force $resolvedTemporarySaves | Out-Null
Push-Location $projectRoot
try {
    go build -o $serverPath ./cmd/server
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $portProbe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 8787)
    try {
        $portProbe.Start()
    }
    catch {
        throw "Port 8787 is already in use; refusing to reuse an unknown service."
    }
    finally {
        $portProbe.Stop()
    }
    $serverArguments = @("-saves", $resolvedTemporarySaves, "-ai-enabled=false")
    if ($DataDirectory) {
        $serverArguments += @("-data", [System.IO.Path]::GetFullPath($DataDirectory))
    }
    $server = Start-Process -FilePath $serverPath -WorkingDirectory $projectRoot -WindowStyle Hidden -ArgumentList $serverArguments -PassThru
    try {
        $healthDeadline = [DateTime]::UtcNow.AddSeconds(8)
        while ($true) {
            if ($server.HasExited) { throw "Narra server exited before becoming healthy." }
            try {
                Invoke-RestMethod -Uri "http://127.0.0.1:8787/api/v1/health" -TimeoutSec 1 | Out-Null
                break
            }
            catch {
                if ([DateTime]::UtcNow -ge $healthDeadline) { throw "Timed out waiting for the Narra server health endpoint." }
                Start-Sleep -Milliseconds 50
            }
        }
        foreach ($resolution in $Resolutions) {
            $captureArguments = @("--capture-output-dir=$screenshotDirectory", "--capture-label=$resolution")
            if ($KnowledgeGraphOnly) { $captureArguments += "--capture-stop-after=knowledge-graph" }
            & $godot.Source --path $godotProject --disable-vsync --script res://demo/capture_ui_states.gd -- $captureArguments
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
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
    if (Test-Path -LiteralPath $resolvedTemporarySaves) {
        Remove-Item -LiteralPath $resolvedTemporarySaves -Recurse -Force
    }
}

$captureStopwatch.Stop()
Write-Host ("UI state screenshots captured in {0} in {1:N2}s." -f $screenshotDirectory, $captureStopwatch.Elapsed.TotalSeconds)
