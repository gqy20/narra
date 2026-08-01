[CmdletBinding()]
param(
    [ValidateSet("all", "package", "server")]
    [string]$Scope = "all"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$targets = switch ($Scope) {
    "package" { @((Join-Path $projectRoot "dist")) }
    "server" { @((Join-Path $projectRoot "bin")) }
    default { @((Join-Path $projectRoot "dist"), (Join-Path $projectRoot "bin")) }
}

$resolvedRoot = [System.IO.Path]::GetFullPath($projectRoot).TrimEnd('\')
foreach ($target in $targets) {
    $resolvedTarget = [System.IO.Path]::GetFullPath($target)
    if (-not $resolvedTarget.StartsWith("$resolvedRoot\", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove a path outside the project: $resolvedTarget"
    }
    if ((Split-Path -Parent $resolvedTarget) -ne $resolvedRoot) {
        throw "Refusing to remove a non-top-level build directory: $resolvedTarget"
    }
    if (Test-Path -LiteralPath $resolvedTarget) {
        Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
        Write-Host "Removed $resolvedTarget"
    }
    else {
        Write-Host "Already clean: $resolvedTarget"
    }
}
