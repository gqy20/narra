[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SourcePath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [int]$Width = 1920,
    [int]$Height = 1080,
    [int]$Crf = 19,
    [switch]$SkipLoudnessNormalization
)

$ErrorActionPreference = "Stop"
$ffmpeg = Get-Command ffmpeg -ErrorAction Stop
$resolvedSource = (Resolve-Path -LiteralPath $SourcePath).Path
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $resolvedOutput
New-Item -ItemType Directory -Force $outputDirectory | Out-Null
$temporaryOutput = Join-Path $outputDirectory (([System.IO.Path]::GetFileNameWithoutExtension($resolvedOutput)) + ".partial.mp4")

$audioArguments = if ($SkipLoudnessNormalization) {
    @("-c:a", "aac", "-b:a", "192k", "-ar", "48000")
} else {
    @("-af", "loudnorm=I=-16:TP=-1.5:LRA=11", "-c:a", "aac", "-b:a", "192k", "-ar", "48000")
}

try {
    $videoFilter = "scale=${Width}:${Height}:force_original_aspect_ratio=decrease:flags=lanczos,pad=${Width}:${Height}:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1,format=yuv420p"
    & $ffmpeg.Source -y -i $resolvedSource `
        -map 0:v:0 -map 0:a:0 `
        -vf $videoFilter `
        -c:v libx264 -preset medium -crf $Crf -pix_fmt yuv420p `
        -color_range tv -colorspace bt709 -color_primaries bt709 -color_trc bt709 `
        @audioArguments -movflags +faststart $temporaryOutput
    if ($LASTEXITCODE -ne 0) {
        throw "FFmpeg failed with exit code $LASTEXITCODE."
    }
    Move-Item -LiteralPath $temporaryOutput -Destination $resolvedOutput -Force
}
finally {
    if (Test-Path -LiteralPath $temporaryOutput) {
        Remove-Item -LiteralPath $temporaryOutput -Force
    }
}

Write-Host "Recording post-processed: $resolvedOutput"
