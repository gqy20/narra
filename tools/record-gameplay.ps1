[CmdletBinding()]
param(
    [string]$Route = "godot/demo/recordings/tianqi-evidence-route.json",
    [ValidateSet("1080p", "4k")]
    [string]$Profile = "1080p",
    [string]$OutputDirectory = "",
    [switch]$KeepSource
)

$arguments = @{ Route = $Route; Profile = $Profile; KeepSource = $KeepSource }
if (-not [string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $arguments.OutputDirectory = $OutputDirectory
}
& (Join-Path $PSScriptRoot "record-playthrough.ps1") @arguments
exit $LASTEXITCODE
