[CmdletBinding()]
param(
    [string]$Version = "",
    [switch]$SkipTests,
    [switch]$SkipSmokeTest
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$godotProject = Join-Path $projectRoot "godot"
$distRoot = Join-Path $projectRoot "dist"
$packageName = "fantu-windows-x86_64"
$packageDir = Join-Path $distRoot $packageName
$archiveBaseName = if ([string]::IsNullOrWhiteSpace($Version)) {
    $packageName
} else {
    "$packageName-$Version"
}
$archivePath = Join-Path $distRoot "$archiveBaseName.zip"
$godot = Get-Command godot -ErrorAction Stop
$go = Get-Command go -ErrorAction Stop

function Assert-SafeBuildPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolvedDist = [System.IO.Path]::GetFullPath($distRoot).TrimEnd('\')
    $resolvedTarget = [System.IO.Path]::GetFullPath($Path)
    if (-not $resolvedTarget.StartsWith("$resolvedDist\", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to modify a path outside the dist directory: $resolvedTarget"
    }
}

Assert-SafeBuildPath $packageDir
Assert-SafeBuildPath $archivePath

if (Test-Path -LiteralPath $packageDir) {
    Remove-Item -LiteralPath $packageDir -Recurse -Force
}
if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}
New-Item -ItemType Directory -Path $packageDir -Force | Out-Null

Push-Location $projectRoot
try {
    if (-not $SkipTests) {
        & $go.Source test ./...
        if ($LASTEXITCODE -ne 0) { throw "Go tests failed." }
    }

    $serverPath = Join-Path $packageDir "fantu-server.exe"
    $previousGoOs = $env:GOOS
    $previousGoArch = $env:GOARCH
    $previousCgoEnabled = $env:CGO_ENABLED
    try {
        $env:GOOS = "windows"
        $env:GOARCH = "amd64"
        $env:CGO_ENABLED = "0"
        & $go.Source build -trimpath '-ldflags=-s -w' -o $serverPath ./cmd/server
        if ($LASTEXITCODE -ne 0) { throw "Go server build failed." }
    }
    finally {
        $env:GOOS = $previousGoOs
        $env:GOARCH = $previousGoArch
        $env:CGO_ENABLED = $previousCgoEnabled
    }

    & $godot.Source --headless --path $godotProject --editor --quit
    if ($LASTEXITCODE -ne 0) { throw "Godot project import failed." }

    $clientPath = Join-Path $packageDir "Fantu.exe"
    & $godot.Source --headless --path $godotProject --export-release "Windows Desktop" $clientPath
    if ($LASTEXITCODE -ne 0) { throw "Godot Windows export failed." }

    $dataDestination = Join-Path $packageDir "data\blackwind"
    New-Item -ItemType Directory -Path $dataDestination -Force | Out-Null
    Copy-Item -Path (Join-Path $projectRoot "data\blackwind\*") -Destination $dataDestination -Recurse -Force

    $resolvedVersion = if ([string]::IsNullOrWhiteSpace($Version)) { "dev" } else { $Version }
    $gitCommit = "unknown"
    try {
        $gitCommit = (& git rev-parse --short HEAD 2>$null).Trim()
    }
    catch {
        $gitCommit = "unknown"
    }
    $buildInfo = [ordered]@{
        application = "Fantu"
        version = $resolvedVersion
        commit = $gitCommit
        built_at_utc = [DateTime]::UtcNow.ToString("o")
        platform = "windows-x86_64"
    } | ConvertTo-Json
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Join-Path $packageDir "build-info.json"), $buildInfo, $utf8NoBom)

    $releaseNotes = @"
Fantu for Windows

Run Fantu.exe to start the game. The bundled local rules service starts and stops automatically.
Logs, saves, and crash diagnostics are stored under %APPDATA%\Fantu.
Run Fantu-Portable.cmd only when you want logs and saves beside the game executable.

Files:
- Fantu.exe: game client
- Fantu-Portable.cmd: optional portable developer launcher
- fantu-server.exe: local rules service
- build-info.json: release version and source revision
- data/blackwind: game scenario data
"@
    Set-Content -LiteralPath (Join-Path $packageDir "README.txt") -Value $releaseNotes -Encoding utf8

    $portableLauncher = @"
@echo off
setlocal
if not exist "%~dp0logs" mkdir "%~dp0logs"
start "" "%~dp0Fantu.exe" --log-file "%~dp0logs\client.log" -- --portable
"@
    Set-Content -LiteralPath (Join-Path $packageDir "Fantu-Portable.cmd") -Value $portableLauncher -Encoding ascii

    if (-not $SkipSmokeTest) {
        & (Join-Path $PSScriptRoot "smoke-test-windows.ps1") -PackageDirectory $packageDir
        if ($LASTEXITCODE -ne 0) { throw "Windows release smoke test failed." }
    }

    $hashLines = Get-ChildItem -LiteralPath $packageDir -Recurse -File |
        Sort-Object FullName |
        ForEach-Object {
            $relativePath = $_.FullName.Substring($packageDir.Length).TrimStart('\').Replace('\', '/')
            $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            "$hash  $relativePath"
        }
    Set-Content -LiteralPath (Join-Path $packageDir "SHA256SUMS.txt") -Value $hashLines -Encoding ascii

    Compress-Archive -Path (Join-Path $packageDir "*") -DestinationPath $archivePath -CompressionLevel Optimal

    $installedBytes = (Get-ChildItem -LiteralPath $packageDir -Recurse -File | Measure-Object Length -Sum).Sum
    $archiveBytes = (Get-Item -LiteralPath $archivePath).Length
    Write-Host "Windows package built successfully."
    Write-Host ("Package directory: {0} ({1:N2} MiB)" -f $packageDir, ($installedBytes / 1MB))
    Write-Host ("Archive: {0} ({1:N2} MiB)" -f $archivePath, ($archiveBytes / 1MB))
}
finally {
    Pop-Location
}
