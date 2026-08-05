param(
    [string]$ProjectFile = "video/bilibili-ai-contest-2026/project.json",
    [switch]$SkipMotionCheck
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
$projectPath = Join-Path $repoRoot $ProjectFile
$project = Get-Content -Raw -Encoding UTF8 $projectPath | ConvertFrom-Json
$outputRoot = Join-Path $repoRoot $project.output_directory
$narrationDirectory = if ($project.audio.narration_directory) { [string]$project.audio.narration_directory } else { "narration" }
$rawNarration = Join-Path $outputRoot $narrationDirectory
$workRoot = Join-Path $outputRoot "work"
$processedNarration = Join-Path $workRoot "narration-processed"
$sectionRoot = Join-Path $workRoot "sections"
$finalRoot = Join-Path $outputRoot "final"
New-Item -ItemType Directory -Force $processedNarration, $workRoot, $sectionRoot, $finalRoot | Out-Null

function Invoke-Checked([string]$Command, [string[]]$Arguments) {
    if ($Command -eq 'ffmpeg') {
        $Arguments = @('-hide_banner', '-loglevel', 'warning', '-stats') + $Arguments
    }
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Command failed with exit code $LASTEXITCODE" }
}

function Get-Duration([string]$Path) {
    $value = & ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 $Path
    if ($LASTEXITCODE -ne 0) { throw "ffprobe failed: $Path" }
    return [double]::Parse($value.Trim(), [Globalization.CultureInfo]::InvariantCulture)
}

function Format-AssTime([double]$Seconds) {
    $ticks = [Math]::Round($Seconds * 100)
    $hours = [Math]::Floor($ticks / 360000)
    $ticks %= 360000
    $minutes = [Math]::Floor($ticks / 6000)
    $ticks %= 6000
    $secs = [Math]::Floor($ticks / 100)
    $centis = $ticks % 100
    return "{0}:{1:00}:{2:00}.{3:00}" -f $hours, $minutes, $secs, $centis
}

function Format-SrtTime([double]$Seconds) {
    $millis = [Math]::Round($Seconds * 1000)
    $hours = [Math]::Floor($millis / 3600000)
    $millis %= 3600000
    $minutes = [Math]::Floor($millis / 60000)
    $millis %= 60000
    $secs = [Math]::Floor($millis / 1000)
    $millis %= 1000
    return "{0:00}:{1:00}:{2:00},{3:000}" -f $hours, $minutes, $secs, $millis
}

function Get-SubtitleUnits([string]$Text) {
    $units = 0.0
    foreach ($character in $Text.ToCharArray()) {
        $units += if ([int]$character -le 127) { 0.55 } else { 1.0 }
    }
    return $units
}

function Split-Subtitle([string]$Text, [int]$Limit = 26) {
    if ((Get-SubtitleUnits $Text) -le $Limit) { return $Text }
    $punctuation = "，。；：！？、"
    foreach ($punctuationOnly in @($true, $false)) {
        $split = -1
        $bestScore = [double]::PositiveInfinity
        for ($candidate = 1; $candidate -lt $Text.Length; $candidate++) {
            $isPunctuation = $punctuation.Contains($Text[$candidate - 1])
            if ($punctuationOnly -and -not $isPunctuation) { continue }
            if (-not $punctuationOnly -and $isPunctuation) { continue }
            $leftUnits = Get-SubtitleUnits $Text.Substring(0, $candidate)
            $rightUnits = Get-SubtitleUnits $Text.Substring($candidate)
            if ($leftUnits -le $Limit -and $rightUnits -le $Limit) {
                $score = [Math]::Abs($leftUnits - $rightUnits)
                if ($score -lt $bestScore) { $bestScore = $score; $split = $candidate }
            }
        }
        if ($split -ge 0) {
            return $Text.Substring(0, $split) + '\N' + $Text.Substring($split)
        }
    }
    throw "Subtitle exceeds two-line 65% width contract: $Text"
}

function Get-ConcatLine([string]$Path) {
    $safePath = $Path.Replace("'", "''")
    return "file '$safePath'"
}

$narrationPath = Join-Path $repoRoot $project.narration_file
$segments = [ordered]@{}
$currentId = $null
foreach ($line in Get-Content -Encoding UTF8 $narrationPath) {
    if ($line -match '^\s+- id:\s*(n\d+)\s*$') {
        $currentId = $Matches[1]
        $segments[$currentId] = [ordered]@{ id = $currentId; text = "" }
    } elseif ($currentId -and $line -match '^\s+text:\s*(.+?)\s*$') {
        $segments[$currentId].text = $Matches[1]
    }
}
if ($segments.Count -ne 24) { throw "Expected 24 narration segments, got $($segments.Count)" }

$tempo = [double]$project.audio.speech_tempo
$sentenceGap = [double]$project.audio.gap_seconds
$sectionGap = [double]$project.audio.section_gap_seconds
$culture = [Globalization.CultureInfo]::InvariantCulture
$timing = [System.Collections.Generic.List[object]]::new()
$cursor = 0.0
$concatAudio = [System.Collections.Generic.List[string]]::new()
$sectionEndIds = @{}
foreach ($section in $project.sections) {
    $sectionLastId = [string]$section.narration[$section.narration.Count - 1]
    if ($sectionLastId -ne 'n24') { $sectionEndIds[$sectionLastId] = $true }
}

$sentenceGapPath = Join-Path $workRoot "sentence-gap.wav"
$sectionGapPath = Join-Path $workRoot "section-gap.wav"
Invoke-Checked ffmpeg @('-y', '-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=mono', '-t', $sentenceGap.ToString('0.000', $culture), '-c:a', 'pcm_s16le', $sentenceGapPath)
Invoke-Checked ffmpeg @('-y', '-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=mono', '-t', $sectionGap.ToString('0.000', $culture), '-c:a', 'pcm_s16le', $sectionGapPath)

foreach ($item in $segments.Values) {
    $source = Join-Path $rawNarration "$($item.id).mp3"
    if (-not (Test-Path $source)) { throw "Missing narration stem: $source" }
    $processed = Join-Path $processedNarration "$($item.id).wav"
    $filter = "silenceremove=start_periods=1:start_duration=0.03:start_threshold=-48dB,atempo=$($tempo.ToString('0.00', $culture)),aresample=48000"
    Invoke-Checked ffmpeg @('-y', '-i', $source, '-af', $filter, '-ac', '1', '-c:a', 'pcm_s16le', $processed)
    $duration = Get-Duration $processed
    $entry = [ordered]@{ id = $item.id; text = $item.text; start = $cursor; end = $cursor + $duration; duration = $duration; file = $processed }
    $timing.Add([pscustomobject]$entry)
    $concatAudio.Add((Get-ConcatLine $processed))
    if ($item.id -ne 'n24') {
        $isSectionEnd = $sectionEndIds.ContainsKey([string]$item.id)
        $nextGap = if ($isSectionEnd) { $sectionGap } else { $sentenceGap }
        $nextGapPath = if ($isSectionEnd) { $sectionGapPath } else { $sentenceGapPath }
        $concatAudio.Add((Get-ConcatLine $nextGapPath))
        $cursor += $duration + $nextGap
    } else { $cursor += $duration }
}

$timing | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 (Join-Path $outputRoot 'timing.json')
$narrationList = Join-Path $workRoot 'narration-concat.txt'
$concatAudio | Set-Content -Encoding ASCII $narrationList
$narrationMix = Join-Path $outputRoot 'narration.wav'
Invoke-Checked ffmpeg @('-y', '-f', 'concat', '-safe', '0', '-i', $narrationList, '-c:a', 'pcm_s16le', $narrationMix)

$ass = [System.Collections.Generic.List[string]]::new()
$ass.Add('[Script Info]')
$ass.Add('ScriptType: v4.00+')
$ass.Add('PlayResX: 3840')
$ass.Add('PlayResY: 2160')
$ass.Add('WrapStyle: 2')
$ass.Add('ScaledBorderAndShadow: yes')
$ass.Add('')
$ass.Add('[V4+ Styles]')
$ass.Add('Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding')
$fontSize = [int]$project.subtitles.font_size
$marginBottom = [int]$project.subtitles.margin_bottom
$maxWidthRatio = [double]$project.subtitles.max_width_ratio
$sideMargin = [Math]::Round(([double]$project.video.width * (1.0 - $maxWidthRatio)) / 2.0)
$ass.Add("Style: Default,$($project.subtitles.font),$fontSize,&H00FFFFFF,&H000000FF,&HCC000000,&H88000000,0,0,0,0,100,100,1,0,1,5,2,2,$sideMargin,$sideMargin,$marginBottom,1")
$ass.Add('')
$ass.Add('[Events]')
$ass.Add('Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text')
$srt = [System.Collections.Generic.List[string]]::new()
$index = 1
foreach ($item in $timing) {
    $subtitle = Split-Subtitle $item.text ([int]$project.subtitles.characters_per_line)
    $ass.Add("Dialogue: 0,$(Format-AssTime $item.start),$(Format-AssTime $item.end),Default,,0,0,0,,$subtitle")
    $srt.Add([string]$index)
    $srt.Add("$(Format-SrtTime $item.start) --> $(Format-SrtTime $item.end)")
    $srt.Add($subtitle.Replace('\N', "`n"))
    $srt.Add('')
    $index++
}
$assPath = Join-Path $outputRoot 'subtitles.ass'
$srtPath = Join-Path $outputRoot 'subtitles.srt'
$ass | Set-Content -Encoding UTF8 $assPath
$srt | Set-Content -Encoding UTF8 $srtPath

if (-not $SkipMotionCheck) {
    $motionPath = Join-Path $repoRoot $project.sources.motion
    if (-not (Test-Path $motionPath)) { throw "Remotion output is missing: $motionPath" }
}

$sectionVideoList = [System.Collections.Generic.List[string]]::new()
$sectionAudioList = [System.Collections.Generic.List[string]]::new()
$alignment = [System.Collections.Generic.List[object]]::new()
$sectionIndex = 0
foreach ($section in $project.sections) {
    $first = $timing | Where-Object id -eq $section.narration[0] | Select-Object -First 1
    $lastId = $section.narration[$section.narration.Count - 1]
    $last = $timing | Where-Object id -eq $lastId | Select-Object -First 1
    $sectionStart = [double]$first.start
    $sectionEnd = [double]$last.end
    if ($lastId -ne 'n24') { $sectionEnd += $sectionGap }
    $targetDuration = $sectionEnd - $sectionStart
    $sourceDuration = [double]$section.out - [double]$section.in
    $speed = $sourceDuration / $targetDuration
    $sourceProperty = $project.sources.PSObject.Properties[[string]$section.source].Value
    $sourcePath = Join-Path $repoRoot $sourceProperty
    if (-not (Test-Path $sourcePath)) { throw "Missing video source: $sourcePath" }
    $videoOut = Join-Path $sectionRoot ("{0:00}-{1}.mp4" -f $sectionIndex, $section.id)
    $audioOut = Join-Path $sectionRoot ("{0:00}-{1}.wav" -f $sectionIndex, $section.id)
    $setpts = (1.0 / $speed).ToString('0.00000000', $culture)
    $videoFilter = "trim=start=$(([double]$section.in).ToString($culture)):end=$(([double]$section.out).ToString($culture)),setpts=$setpts*(PTS-STARTPTS),fps=$($project.video.fps),scale=$($project.video.width):$($project.video.height):flags=lanczos:out_range=tv,format=yuv420p,setparams=range=limited,setsar=1"
    Invoke-Checked ffmpeg @('-y', '-i', $sourcePath, '-vf', $videoFilter, '-an', '-c:v', 'libx264', '-preset', 'faster', '-crf', ([string]$project.video.crf), '-pix_fmt', 'yuv420p', '-video_track_timescale', '90000', $videoOut)

    $audioProbe = & ffprobe -v error -select_streams a:0 -show_entries stream=index -of csv=p=0 $sourcePath
    if ($audioProbe) {
        $fade = [Math]::Min([double]$project.audio.section_fade_seconds, $targetDuration / 4.0)
        $fadeOutStart = [Math]::Max(0.0, $targetDuration - $fade)
        $audioFilter = "atrim=start=$(([double]$section.in).ToString($culture)):end=$(([double]$section.out).ToString($culture)),asetpts=N/SR/TB,atempo=$($speed.ToString('0.00000000', $culture)),aresample=48000,apad=whole_dur=$($targetDuration.ToString('0.000000', $culture)),atrim=duration=$($targetDuration.ToString('0.000000', $culture)),afade=t=in:st=0:d=$($fade.ToString('0.000', $culture)),afade=t=out:st=$($fadeOutStart.ToString('0.000', $culture)):d=$($fade.ToString('0.000', $culture))"
        Invoke-Checked ffmpeg @('-y', '-i', $sourcePath, '-vn', '-af', $audioFilter, '-ac', '2', '-c:a', 'pcm_s16le', $audioOut)
    } else {
        Invoke-Checked ffmpeg @('-y', '-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo', '-t', $targetDuration.ToString('0.000', $culture), '-c:a', 'pcm_s16le', $audioOut)
    }
    $sectionVideoList.Add((Get-ConcatLine $videoOut))
    $sectionAudioList.Add((Get-ConcatLine $audioOut))
    $actualVideoDuration = Get-Duration $videoOut
    $actualAudioDuration = Get-Duration $audioOut
    $videoDelta = [Math]::Abs($actualVideoDuration - $targetDuration)
    $audioDelta = [Math]::Abs($actualAudioDuration - $targetDuration)
    if ($videoDelta -gt 0.08 -or $audioDelta -gt 0.08) {
        throw "Section alignment failed for $($section.id): target=$targetDuration video=$actualVideoDuration audio=$actualAudioDuration"
    }
    $alignment.Add([pscustomobject][ordered]@{
        section = $section.id
        narration_start = $sectionStart
        narration_end = $sectionEnd
        target_duration = $targetDuration
        video_duration = $actualVideoDuration
        audio_duration = $actualAudioDuration
        video_delta = $videoDelta
        audio_delta = $audioDelta
        source = $section.source
        source_in = [double]$section.in
        source_out = [double]$section.out
        playback_speed = $speed
    })
    $sectionIndex++
}
$alignment | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $outputRoot 'alignment.csv')

$videoListPath = Join-Path $workRoot 'video-concat.txt'
$audioListPath = Join-Path $workRoot 'game-audio-concat.txt'
$sectionVideoList | Set-Content -Encoding ASCII $videoListPath
$sectionAudioList | Set-Content -Encoding ASCII $audioListPath
$cleanVideo = Join-Path $outputRoot 'picture-lock-4k.mp4'
$gameAudio = Join-Path $outputRoot 'game-audio.wav'
Invoke-Checked ffmpeg @('-y', '-f', 'concat', '-safe', '0', '-i', $videoListPath, '-c', 'copy', $cleanVideo)
Invoke-Checked ffmpeg @('-y', '-f', 'concat', '-safe', '0', '-i', $audioListPath, '-c:a', 'pcm_s16le', $gameAudio)

$finalAudio = Join-Path $outputRoot 'final-mix.wav'
$gameGain = [double]$project.audio.game_gain
$narrationGain = [double]$project.audio.narration_gain
$fantuStart = [double](($timing | Where-Object id -eq 'n17' | Select-Object -First 1).start)
$fantuEnd = [double](($timing | Where-Object id -eq 'n20' | Select-Object -First 1).end) + $sectionGap
$fantuDuration = $fantuEnd - $fantuStart
$fantuMusic = Join-Path $repoRoot ([string]$project.audio.fantu_music)
if (-not (Test-Path $fantuMusic)) { throw "Missing Fantu music: $fantuMusic" }
$fantuMusicGain = [double]$project.audio.fantu_music_gain
$fantuFade = [Math]::Min([double]$project.audio.fantu_music_fade_seconds, $fantuDuration / 4.0)
$fantuFadeOut = $fantuDuration - $fantuFade
$fantuDelayMs = [Math]::Round($fantuStart * 1000)
$mixFilter = "[0:a]volume=$($narrationGain.ToString('0.00', $culture))[n];[1:a]volume='if(between(t\,$($fantuStart.ToString('0.000', $culture))\,$($fantuEnd.ToString('0.000', $culture)))\,0\,$($gameGain.ToString('0.00', $culture)))':eval=frame[g];[2:a]atrim=start=0:end=$($fantuDuration.ToString('0.000', $culture)),asetpts=N/SR/TB,aresample=48000,afade=t=in:st=0:d=$($fantuFade.ToString('0.000', $culture)),afade=t=out:st=$($fantuFadeOut.ToString('0.000', $culture)):d=$($fantuFade.ToString('0.000', $culture)),volume=$($fantuMusicGain.ToString('0.00', $culture)),adelay=$fantuDelayMs`:all=1[b];[n][g][b]amix=inputs=3:duration=longest:normalize=0:dropout_transition=0,loudnorm=I=-16:TP=-1.5:LRA=11,alimiter=limit=0.95[out]"
Invoke-Checked ffmpeg @('-y', '-i', $narrationMix, '-i', $gameAudio, '-i', $fantuMusic, '-filter_complex', $mixFilter, '-map', '[out]', '-ac', '2', '-ar', '48000', '-c:a', 'pcm_s16le', $finalAudio)

$finalVideo = Join-Path $finalRoot 'narra-bilibili-ai-contest-4k.mp4'
$previewVideo = Join-Path $finalRoot 'narra-bilibili-ai-contest-preview-720p.mp4'
Push-Location $outputRoot
try {
    Invoke-Checked ffmpeg @('-y', '-i', $cleanVideo, '-i', $finalAudio, '-vf', 'ass=subtitles.ass,scale=in_range=auto:out_range=tv,format=yuv420p,setparams=range=limited', '-map', '0:v:0', '-map', '1:a:0', '-c:v', 'libx264', '-preset', 'medium', '-crf', ([string]$project.video.crf), '-pix_fmt', 'yuv420p', '-color_range', 'tv', '-c:a', 'aac', '-b:a', '320k', '-ar', '48000', '-shortest', '-movflags', '+faststart', $finalVideo)
    Invoke-Checked ffmpeg @('-y', '-i', $finalVideo, '-vf', 'scale=1280:720:flags=lanczos:in_range=auto:out_range=tv,format=yuv420p,setparams=range=limited', '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-pix_fmt', 'yuv420p', '-color_range', 'tv', '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', $previewVideo)
} finally { Pop-Location }

Write-Host "Built 4K master: $finalVideo"
Write-Host "Built preview:   $previewVideo"
Write-Host ("Duration: {0:N2}s" -f $cursor)
