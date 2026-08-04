param(
    [string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = "Stop"
$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
$docsRoot = Join-Path $root "docs"

if (-not (Test-Path -LiteralPath (Join-Path $docsRoot "README.md") -PathType Leaf)) {
    Write-Error "docs/README.md is required as the documentation entry point."
}

$activeRoadmaps = @(Get-ChildItem -LiteralPath $docsRoot -Recurse -File -Filter "ROADMAP.md" |
    Where-Object { $_.FullName -notlike "*\docs\archive\*" })
if ($activeRoadmaps.Count -ne 1 -or $activeRoadmaps[0].FullName -ne (Join-Path $docsRoot "product\ROADMAP.md")) {
    Write-Error "Exactly one active roadmap is allowed: docs/product/ROADMAP.md."
}

$markdownFiles = @(
    Get-Item -LiteralPath (Join-Path $root "README.md")
    Get-ChildItem -LiteralPath $docsRoot -Recurse -File -Filter "*.md"
)
$inlineLinkPattern = [regex]'!?(?:\[[^\]]*\])\((?<target><[^>]+>|[^)\s]+)(?:\s+"[^"]*")?\)'
$referenceLinkPattern = [regex]'^\s*\[[^\]]+\]:\s*(?<target><[^>]+>|\S+)'
$failures = [System.Collections.Generic.List[string]]::new()
$checkedLinks = 0

foreach ($file in $markdownFiles) {
    $insideFence = $false
    $lineNumber = 0
    foreach ($line in [System.IO.File]::ReadLines($file.FullName)) {
        $lineNumber++
        if ($line.TrimStart().StartsWith('```')) {
            $insideFence = -not $insideFence
            continue
        }
        if ($insideFence) { continue }

        $matches = @($inlineLinkPattern.Matches($line)) + @($referenceLinkPattern.Matches($line))
        foreach ($match in $matches) {
            $target = $match.Groups['target'].Value.Trim('<', '>')
            if ($target -match '^(?:https?|mailto|data):' -or $target.StartsWith('#')) { continue }
            $pathPart = ($target -split '[#?]', 2)[0]
            if ([string]::IsNullOrWhiteSpace($pathPart)) { continue }
            $pathPart = [System.Uri]::UnescapeDataString($pathPart).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            $resolved = if ([System.IO.Path]::IsPathRooted($pathPart)) {
                [System.IO.Path]::GetFullPath($pathPart)
            }
            else {
                [System.IO.Path]::GetFullPath((Join-Path $file.DirectoryName $pathPart))
            }
            $checkedLinks++
            if (-not (Test-Path -LiteralPath $resolved)) {
                $relativeFile = $file.FullName.Substring($root.Length).TrimStart('\', '/')
                $failures.Add("${relativeFile}:${lineNumber}: missing local link '$target'")
            }
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Error ("Documentation verification failed:`n" + ($failures -join "`n"))
}

Write-Host "Documentation verification passed: $($markdownFiles.Count) files, $checkedLinks local links."
