[CmdletBinding()]
param(
    [ValidateSet("fast", "core", "full")]
    [string]$Mode = "fast",
    [switch]$Fresh
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$go = Get-Command go -ErrorAction Stop
$timings = [System.Collections.Generic.List[object]]::new()
$total = [System.Diagnostics.Stopwatch]::StartNew()

function Invoke-TimedGo {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$CaptureOutput
    )

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    if ($CaptureOutput) {
        $output = & $go.Source @Arguments
    } else {
        & $go.Source @Arguments
        $output = $null
    }
    $exitCode = $LASTEXITCODE
    $watch.Stop()
    $script:timings.Add([pscustomobject]@{
        Step = $Name
        Seconds = [math]::Round($watch.Elapsed.TotalSeconds, 2)
    })
    if ($exitCode -ne 0) {
        throw "$Name failed with exit code $exitCode."
    }
    return $output
}

function Assert-TianqiBaseline {
    param([Parameter(Mandatory = $true)]$State)

    if ($State.Day -ne 15) {
        throw "T00 ended on day $($State.Day), expected day 15."
    }
    if ([string]::IsNullOrWhiteSpace($State.Outcome)) {
        throw "Unexpected T00 outcome: $($State.Outcome)"
    }
    $winnerID = $State.Items.official_draft
    $winner = $State.NPCs.N02
    $winnerScore = $winner.Resources.authority + $winner.Resources.evidence + $winner.Resources.allies
    if ($winnerID -ne "N02" -or $winnerScore -ne 12) {
        throw "Unexpected T00 winner: owner=$winnerID, score=$winnerScore."
    }
    if ($State.Items.e10_statement -ne "N09" -or -not $State.WorldFlags.zhou_intercepted) {
        throw "Unexpected E10 baseline: owner=$($State.Items.e10_statement), intercepted=$($State.WorldFlags.zhou_intercepted)."
    }
    $failedEvents = @($State.Events | Where-Object { $_.Status -eq "failed" })
    if ($failedEvents.Count -gt 0) {
        throw "T00 contains $($failedEvents.Count) failed events."
    }
    $genericEvents = @($State.Events | Where-Object { $_.StrategyID -like "generic-*" })
    if ($genericEvents.Count -gt 0) {
        throw "T00 contains $($genericEvents.Count) legacy generic strategy events."
    }
}

Push-Location $projectRoot
try {
    $freshArguments = if ($Fresh -or $Mode -ne "fast") { @("-count=1") } else { @() }
    switch ($Mode) {
        "fast" {
            Invoke-TimedGo -Name "Tianqi route tests" -Arguments (@("test", "./internal/app", "-run", "Tianqi") + $freshArguments)
        }
        "core" {
            Invoke-TimedGo -Name "Core Go tests" -Arguments (@("test", "./internal/app", "./internal/engine", "./internal/scenario") + $freshArguments)
        }
        "full" {
            Invoke-TimedGo -Name "All Go tests" -Arguments (@("test", "./...") + $freshArguments)
        }
    }

    $simulationOutput = Invoke-TimedGo -Name "T00 simulation" -Arguments @("run", "./cmd/sim", "-data", "data/tianqi", "-format", "json") -CaptureOutput
    $simulation = ($simulationOutput -join [Environment]::NewLine) | ConvertFrom-Json
    Assert-TianqiBaseline -State $simulation
}
finally {
    Pop-Location
    $total.Stop()
}

Write-Host ""
$timings | Format-Table -AutoSize
Write-Host ("Tianqi {0} verification passed in {1:N2}s." -f $Mode, $total.Elapsed.TotalSeconds)
