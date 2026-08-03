[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [int]$ExpectedWidth = 1920,
    [int]$ExpectedHeight = 1080,
    [double]$MinimumDurationSeconds = 30
)

$ErrorActionPreference = "Stop"
$ffprobe = Get-Command ffprobe -ErrorAction Stop
$resolvedPath = (Resolve-Path -LiteralPath $Path).Path
$probeText = (& $ffprobe.Source -v error -show_streams -show_format -of json $resolvedPath) -join [Environment]::NewLine
if ($LASTEXITCODE -ne 0) {
    throw "ffprobe failed for $resolvedPath."
}
$probe = $probeText | ConvertFrom-Json
$video = @($probe.streams | Where-Object codec_type -eq "video") | Select-Object -First 1
$audio = @($probe.streams | Where-Object codec_type -eq "audio") | Select-Object -First 1
if ($null -eq $video) { throw "Recording has no video stream." }
if ($null -eq $audio) { throw "Recording has no audio stream." }
if ([int]$video.width -ne $ExpectedWidth -or [int]$video.height -ne $ExpectedHeight) {
    throw "Recording resolution is $($video.width)x$($video.height), expected ${ExpectedWidth}x${ExpectedHeight}."
}
$duration = [double]::Parse([string]$probe.format.duration, [Globalization.CultureInfo]::InvariantCulture)
if ($duration -lt $MinimumDurationSeconds) {
    throw "Recording is only $([math]::Round($duration, 1)) seconds, expected at least $MinimumDurationSeconds seconds."
}
if ([string]$video.pix_fmt -ne "yuv420p") {
    throw "Recording pixel format is $($video.pix_fmt), expected yuv420p."
}
if ([string]$video.sample_aspect_ratio -ne "1:1") {
    throw "Recording sample aspect ratio is $($video.sample_aspect_ratio), expected square pixels (1:1)."
}

Write-Host "Recording validated: ${ExpectedWidth}x${ExpectedHeight}, $([math]::Round($duration, 1))s, video=$($video.codec_name), audio=$($audio.codec_name)."
