$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$serverPath = Join-Path $projectRoot "bin\fantu-server.exe"
$godotProject = Join-Path $projectRoot "godot"
$videoDirectory = Join-Path $projectRoot "artifacts\video"
$aviPath = Join-Path $videoDirectory "fantu-gameplay-source.avi"
$videoPath = Join-Path $videoDirectory "fantu-gameplay-demo.mp4"
$godot = Get-Command godot -ErrorAction Stop
$ffmpeg = Get-Command ffmpeg -ErrorAction Stop
$ffprobe = Get-Command ffprobe -ErrorAction Stop

New-Item -ItemType Directory -Force (Split-Path -Parent $serverPath) | Out-Null
New-Item -ItemType Directory -Force $videoDirectory | Out-Null

Push-Location $projectRoot
try {
    go build -o $serverPath ./cmd/server
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $server = Start-Process -FilePath $serverPath -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru
    try {
        Start-Sleep -Milliseconds 500
        $previousErrorPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $godotOutput = @(& $godot.Source --path $godotProject --resolution 1280x800 --write-movie $aviPath --fixed-fps 20 --disable-vsync --script res://demo/record_gameplay.gd 2>&1)
        $godotExitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorPreference
        $godotOutput | ForEach-Object { Write-Host $_ }
        if ($godotExitCode -ne 0) { exit $godotExitCode }

        $movieSummary = ($godotOutput | Select-String -Pattern '([0-9]+) frames at').Matches | Select-Object -Last 1
        if ($null -eq $movieSummary -or [int]$movieSummary.Groups[1].Value -lt 700) {
            throw "Godot did not render enough distinct movie frames; keep the game window visible and record again."
        }
    }
    finally {
        if (-not $server.HasExited) {
            Stop-Process -Id $server.Id
        }
    }

    $sourceFrameCount = & $ffprobe.Source -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=noprint_wrappers=1:nokey=1 $aviPath
    if ($LASTEXITCODE -ne 0 -or [int]$sourceFrameCount -lt 700) {
        throw "Movie writer produced only $sourceFrameCount rendered frames; keep the Godot window visible and record again."
    }

    & $ffmpeg.Source -y -i $aviPath -map 0:v:0 -map 0:a? -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart $videoPath
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $duration = & $ffprobe.Source -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $videoPath
    if ($LASTEXITCODE -ne 0 -or [double]$duration -lt 10) {
        throw "Recorded video is missing or unexpectedly short."
    }
    Remove-Item -LiteralPath $aviPath
    Write-Host "Gameplay video recorded: $videoPath ($([math]::Round([double]$duration, 1)) seconds)"
}
finally {
    Pop-Location
}
