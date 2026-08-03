[CmdletBinding()]
param(
    [string]$Route = "godot/demo/recordings/tianqi-evidence-route.json",
    [int]$CaptureWidth = 2048,
    [int]$CaptureHeight = 1152,
    [int]$FramesPerSecond = 30,
    [string]$OutputDirectory = "",
    [switch]$KeepSource
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$serverPath = Join-Path $projectRoot "bin\fantu-server.exe"
$godotProject = Join-Path $projectRoot "godot"
$routePath = (Resolve-Path -LiteralPath (Join-Path $projectRoot $Route)).Path
$routeConfig = Get-Content -Raw -Encoding utf8 $routePath | ConvertFrom-Json
$routeID = [string]$routeConfig.id
if ([string]::IsNullOrWhiteSpace($routeID)) { throw "Recording route has no id: $routePath" }

$runID = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ") + "-" + $routeID
$recordingRoot = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    Join-Path $projectRoot ("artifacts\recordings\tianqi\" + $runID)
} else {
    [System.IO.Path]::GetFullPath($OutputDirectory)
}
$sourcePath = Join-Path $recordingRoot "source.avi"
$videoPath = Join-Path $recordingRoot ($routeID + ".mp4")
$godotLogPath = Join-Path $recordingRoot "godot.log"
$serverLogPath = Join-Path $recordingRoot "server.log"
$serverErrorLogPath = Join-Path $recordingRoot "server-error.log"
$manifestPath = Join-Path $recordingRoot "manifest.json"
$minimumDuration = [double]$routeConfig.min_duration_seconds

$go = Get-Command go -ErrorAction Stop
$godot = Get-Command godot -ErrorAction Stop
Get-Command ffmpeg -ErrorAction Stop | Out-Null
Get-Command ffprobe -ErrorAction Stop | Out-Null

New-Item -ItemType Directory -Force (Split-Path -Parent $serverPath) | Out-Null
New-Item -ItemType Directory -Force $recordingRoot | Out-Null

$temporarySaves = Join-Path ([System.IO.Path]::GetTempPath()) ("fantu-recording-saves-" + [Guid]::NewGuid().ToString("N"))
$resolvedTemporarySaves = [System.IO.Path]::GetFullPath($temporarySaves)
$resolvedTemporaryBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
if (-not $resolvedTemporarySaves.StartsWith("$resolvedTemporaryBase\fantu-recording-saves-", [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use unsafe temporary save path: $resolvedTemporarySaves"
}
New-Item -ItemType Directory -Path $resolvedTemporarySaves -Force | Out-Null

function Wait-ForServer {
    param([int]$TimeoutSeconds = 15)
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:8787/api/v1/health" -TimeoutSec 1
            if ($response.StatusCode -eq 200) { return }
        } catch {
            Start-Sleep -Milliseconds 200
        }
    }
    throw "Tianqi server did not become healthy within $TimeoutSeconds seconds."
}

$server = $null
Push-Location $projectRoot
try {
    & $go.Source build -o $serverPath ./cmd/server
    if ($LASTEXITCODE -ne 0) { throw "Server build failed with exit code $LASTEXITCODE." }

    try {
        $existingHealth = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:8787/api/v1/health" -TimeoutSec 1
        if ($existingHealth.StatusCode -eq 200) {
            throw "Port 8787 already has a running Fantu server. Stop it before recording so the route uses an isolated save."
        }
    } catch {
        if ($_.Exception.Message -like "Port 8787*") { throw }
    }

    $server = Start-Process -FilePath $serverPath -WorkingDirectory $projectRoot -WindowStyle Hidden -ArgumentList @(
        "-data", (Join-Path $projectRoot "data\tianqi"),
        "-saves", $resolvedTemporarySaves
    ) -RedirectStandardOutput $serverLogPath -RedirectStandardError $serverErrorLogPath -PassThru
    Wait-ForServer

    $resolvedGodotProject = [System.IO.Path]::GetFullPath($godotProject).TrimEnd('\')
    if (-not $routePath.StartsWith("$resolvedGodotProject\", [StringComparison]::OrdinalIgnoreCase)) {
        throw "Recording route must be inside the Godot project: $routePath"
    }
    $routeResourcePath = "res://" + $routePath.Substring($resolvedGodotProject.Length + 1).Replace('\', '/')
    $godotArguments = @(
        "--path", $godotProject,
        "--resolution", "${CaptureWidth}x${CaptureHeight}",
        "--write-movie", $sourcePath,
        "--fixed-fps", "$FramesPerSecond",
        "--disable-vsync",
        "--script", "res://demo/record_playthrough.gd",
        "--",
        "--scenario=tianqi",
        "--recording-route=$routeResourcePath"
    )
    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $godotOutput = @(& $godot.Source @godotArguments 2>&1)
        $godotExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorPreference
    }
    $godotOutput | Set-Content -LiteralPath $godotLogPath -Encoding utf8
    $godotOutput | ForEach-Object { Write-Host $_ }
    if ($godotExitCode -ne 0) { throw "Godot recording failed with exit code $godotExitCode. See $godotLogPath" }
    if (-not ($godotOutput -match "PLAYTHROUGH_RECORDED")) { throw "Godot exited without a completed playthrough marker. See $godotLogPath" }

    $sourceProbeText = (& ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of json $sourcePath) -join [Environment]::NewLine
    if ($LASTEXITCODE -ne 0) { throw "Could not inspect the recorded source video." }
    $sourceProbe = $sourceProbeText | ConvertFrom-Json
    $sourceVideo = @($sourceProbe.streams) | Select-Object -First 1
    $actualCaptureWidth = [int]$sourceVideo.width
    $actualCaptureHeight = [int]$sourceVideo.height

    & (Join-Path $PSScriptRoot "postprocess-recording.ps1") -SourcePath $sourcePath -OutputPath $videoPath
    & (Join-Path $PSScriptRoot "validate-recording.ps1") -Path $videoPath -MinimumDurationSeconds $minimumDuration

    $gitCommit = (& git rev-parse HEAD).Trim()
    $manifest = [ordered]@{
        run_id = $runID
        route_id = $routeID
        scenario_id = [string]$routeConfig.scenario_id
        git_commit = $gitCommit
        recorded_at_utc = [DateTime]::UtcNow.ToString("o")
        capture = [ordered]@{ width = $actualCaptureWidth; height = $actualCaptureHeight; requested_width = $CaptureWidth; requested_height = $CaptureHeight; fps = $FramesPerSecond }
        output = [ordered]@{ width = 1920; height = 1080; fit = "contain"; codec = "h264"; audio = "aac"; path = [System.IO.Path]::GetFileName($videoPath) }
        route_file = $routePath.Substring([System.IO.Path]::GetFullPath($projectRoot).TrimEnd('\').Length + 1).Replace('\', '/')
        source_preserved = [bool]$KeepSource
    }
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8

    if (-not $KeepSource -and (Test-Path -LiteralPath $sourcePath)) {
        Remove-Item -LiteralPath $sourcePath -Force
    }
    Write-Host "Playthrough recording completed: $videoPath"
}
finally {
    if ($null -ne $server -and -not $server.HasExited) {
        Stop-Process -Id $server.Id
        $server.WaitForExit()
    }
    if (Test-Path -LiteralPath $resolvedTemporarySaves) {
        Remove-Item -LiteralPath $resolvedTemporarySaves -Recurse -Force
    }
    Pop-Location
}
