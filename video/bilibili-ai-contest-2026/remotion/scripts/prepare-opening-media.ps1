$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$projectPath = Join-Path $repositoryRoot 'video\bilibili-ai-contest-2026\project.json'
$project = Get-Content -Raw -Encoding UTF8 $projectPath | ConvertFrom-Json
$outputDirectory = Join-Path $repositoryRoot 'video\bilibili-ai-contest-2026\remotion\public\generated'
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

function Resolve-RepositoryPath([string]$relativePath) {
    $resolvedPath = Join-Path $repositoryRoot ($relativePath -replace '/', '\')
    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        throw "Opening source does not exist: $resolvedPath"
    }
    return $resolvedPath
}

function Export-OpeningClip {
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][double]$StartSeconds,
        [Parameter(Mandatory = $true)][double]$DurationSeconds,
        [Parameter(Mandatory = $true)][string]$OutputName
    )

    $outputPath = Join-Path $outputDirectory $OutputName
    & ffmpeg -y -ss $StartSeconds -i $InputPath -t $DurationSeconds `
        -vf 'scale=3840:2160:flags=lanczos,fps=30' -an `
        -c:v libx264 -preset fast -crf 16 -pix_fmt yuv420p -movflags '+faststart' `
        $outputPath
    if ($LASTEXITCODE -ne 0) {
        throw "ffmpeg failed while preparing $OutputName"
    }
}

$tianqiSource = Resolve-RepositoryPath $project.sources.tianqi
$aiDialogueSource = Resolve-RepositoryPath $project.sources.ai_dialogue
$fantuSource = Resolve-RepositoryPath $project.sources.fantu

Export-OpeningClip -InputPath $tianqiSource -StartSeconds 4.2 -DurationSeconds 4.3 -OutputName 'tianqi-explosion.mp4'
Export-OpeningClip -InputPath $aiDialogueSource -StartSeconds 38.0 -DurationSeconds 27.0 -OutputName 'tianqi-ai-dialogue.mp4'
Export-OpeningClip -InputPath $fantuSource -StartSeconds 13.5 -DurationSeconds 8.0 -OutputName 'fantu-intro.mp4'

Write-Host "Opening media prepared in $outputDirectory"
