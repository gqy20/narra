param(
    [string]$ProjectFile = "video/bilibili-ai-contest-2026/project.json",
    [string[]]$SegmentIds = @(),
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
$projectPath = Join-Path $repoRoot $ProjectFile
$project = Get-Content -Raw -Encoding UTF8 $projectPath | ConvertFrom-Json
$narrationPath = Join-Path $repoRoot $project.narration_file
$outputRoot = Join-Path $repoRoot $project.output_directory
$narrationDirectory = if ($project.audio.narration_directory) { [string]$project.audio.narration_directory } else { "narration" }
$outputDirectory = Join-Path $outputRoot $narrationDirectory
New-Item -ItemType Directory -Force $outputDirectory | Out-Null

$lines = Get-Content -Encoding UTF8 $narrationPath
$tts = [ordered]@{
    model = ""
    voice = ""
    speed = 1.0
    sample_rate = 44100
    bitrate = 256000
    channels = 1
    pronunciation = [System.Collections.Generic.List[string]]::new()
}
$segments = [System.Collections.Generic.List[object]]::new()
$inTts = $false
$inPronunciation = $false
$current = $null

foreach ($line in $lines) {
    if ($line -match '^tts:\s*$') {
        $inTts = $true
        $inPronunciation = $false
        continue
    }
    if ($line -match '^notes:\s*$') {
        $inTts = $false
        $inPronunciation = $false
        continue
    }
    if ($inTts -and $line -match '^\s{2}(model|voice|speed|sample_rate|bitrate|channels):\s*(.+?)\s*$') {
        $key = $Matches[1]
        $value = $Matches[2]
        $tts[$key] = if ($key -in @('speed', 'sample_rate', 'bitrate', 'channels')) {
            [double]::Parse($value, [Globalization.CultureInfo]::InvariantCulture)
        } else { $value }
        $inPronunciation = $false
        continue
    }
    if ($inTts -and $line -match '^\s{2}pronunciation:\s*$') {
        $inPronunciation = $true
        continue
    }
    if ($inTts -and $inPronunciation -and $line -match '^\s{4}-\s*(.+?)\s*$') {
        $tts.pronunciation.Add($Matches[1])
        continue
    }
    if ($line -match '^\s{2}- id:\s*(n\d+)\s*$') {
        $current = [ordered]@{ id = $Matches[1]; text = "" }
        $segments.Add([pscustomobject]$current)
        continue
    }
    if ($null -ne $current -and $line -match '^\s{4}text:\s*(.+?)\s*$') {
        $current.text = $Matches[1]
        $segments[$segments.Count - 1].text = $Matches[1]
    }
}

if ($segments.Count -ne 24) { throw "Expected 24 narration segments, got $($segments.Count)" }
if (-not $tts.model -or -not $tts.voice) { throw "Missing TTS model or voice in $narrationPath" }

$knownSegmentIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($segment in $segments) { $knownSegmentIds.Add([string]$segment.id) | Out-Null }
$requestedSegmentIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($segmentId in $SegmentIds) {
    $normalizedId = $segmentId.Trim()
    if (-not $normalizedId) { continue }
    if (-not $knownSegmentIds.Contains($normalizedId)) { throw "Unknown narration segment: $normalizedId" }
    $requestedSegmentIds.Add($normalizedId) | Out-Null
}
$hasSegmentSelection = $requestedSegmentIds.Count -gt 0

$manifest = [System.Collections.Generic.List[object]]::new()
$index = 0
foreach ($segment in $segments) {
    $index++
    $destination = Join-Path $outputDirectory "$($segment.id).mp3"
    $isSelected = $requestedSegmentIds.Contains([string]$segment.id)
    if ($hasSegmentSelection -and -not $isSelected -and -not (Test-Path $destination)) {
        throw "Missing narration stem excluded by -SegmentIds: $destination"
    }
    $shouldGenerate = if ($hasSegmentSelection) { $isSelected } else { $Force -or -not (Test-Path $destination) }
    if ($shouldGenerate) {
        Write-Host "[$index/$($segments.Count)] Generating $($segment.id) with $($tts.voice)"
        $arguments = @(
            'speech', 'synthesize',
            '--text', [string]$segment.text,
            '--model', [string]$tts.model,
            '--voice', [string]$tts.voice,
            '--speed', ([double]$tts.speed).ToString('0.00', [Globalization.CultureInfo]::InvariantCulture),
            '--sample-rate', ([int]$tts.sample_rate).ToString(),
            '--bitrate', ([int]$tts.bitrate).ToString(),
            '--channels', ([int]$tts.channels).ToString(),
            '--language', 'Chinese',
            '--format', 'mp3',
            '--out', $destination,
            '--non-interactive', '--quiet', '--output', 'json'
        )
        foreach ($entry in $tts.pronunciation) {
            $arguments += @('--pronunciation', [string]$entry)
        }
        & mmx @arguments
        if ($LASTEXITCODE -ne 0) { throw "mmx failed for $($segment.id) with exit code $LASTEXITCODE" }
    } else {
        Write-Host "[$index/$($segments.Count)] Reusing $($segment.id)"
    }

    $probe = & ffprobe -v error -show_entries format=duration,size -show_entries stream=codec_name,sample_rate,channels -of json $destination
    if ($LASTEXITCODE -ne 0) { throw "ffprobe failed for $destination" }
    $metadata = $probe | ConvertFrom-Json
    $duration = [double]::Parse([string]$metadata.format.duration, [Globalization.CultureInfo]::InvariantCulture)
    if ($duration -le 0.1) { throw "Generated audio is unexpectedly short: $destination" }
    $manifest.Add([pscustomobject][ordered]@{
        id = $segment.id
        text = $segment.text
        model = $tts.model
        voice = $tts.voice
        speed = [double]$tts.speed
        duration = $duration
        sample_rate = [int]$metadata.streams[0].sample_rate
        channels = [int]$metadata.streams[0].channels
        size = [long]$metadata.format.size
        file = $destination
    })
}

$manifestPath = Join-Path $outputDirectory 'generation-manifest.json'
$manifest | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 $manifestPath
$totalDuration = ($manifest | Measure-Object -Property duration -Sum).Sum
Write-Host "Generated narration: $outputDirectory"
Write-Host "Manifest: $manifestPath"
Write-Host ("Speech duration without edit gaps: {0:N2}s" -f $totalDuration)
