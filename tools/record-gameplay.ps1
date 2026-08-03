[CmdletBinding()]
param(
    [string]$Route = "godot/demo/recordings/tianqi-evidence-route.json",
    [string]$OutputDirectory = "",
    [switch]$KeepSource
)

$arguments = @{ Route = $Route; KeepSource = $KeepSource }
if (-not [string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $arguments.OutputDirectory = $OutputDirectory
}
& (Join-Path $PSScriptRoot "record-playthrough.ps1") @arguments
exit $LASTEXITCODE
