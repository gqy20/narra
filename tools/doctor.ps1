$ErrorActionPreference = "Stop"

$requiredCommands = @("go", "godot", "make", "py")
$missingCommands = @()
foreach ($commandName in $requiredCommands) {
    $command = Get-Command $commandName -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        $missingCommands += $commandName
    }
    else {
        Write-Host ("[ok] {0}: {1}" -f $commandName, $command.Source)
    }
}

if ($missingCommands.Count -gt 0) {
    throw "Missing required commands: $($missingCommands -join ', ')"
}

$godotVersionOutput = (& godot --version | Select-Object -First 1).Trim()
if ($godotVersionOutput -notmatch '^(\d+\.\d+\.\d+\.[^.]+)') {
    throw "Could not determine the Godot template version from: $godotVersionOutput"
}
$godotTemplateVersion = $Matches[1]
$templateDirectory = Join-Path $env:APPDATA "Godot\export_templates\$godotTemplateVersion"
$releaseTemplate = Join-Path $templateDirectory "windows_release_x86_64.exe"
$debugTemplate = Join-Path $templateDirectory "windows_debug_x86_64.exe"

if (-not (Test-Path -LiteralPath $releaseTemplate -PathType Leaf) -or
    -not (Test-Path -LiteralPath $debugTemplate -PathType Leaf)) {
    throw "Godot $godotTemplateVersion Windows templates are missing. Run: make templates-windows GODOT_VERSION=$godotTemplateVersion"
}

Write-Host "[ok] Godot Windows templates: $templateDirectory"
Write-Host "Development environment is ready."
