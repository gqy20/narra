$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("fantu-server-diagnostics-" + [Guid]::NewGuid().ToString("N"))
$resolvedTemporaryBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
$resolvedTemporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot)
if (-not $resolvedTemporaryRoot.StartsWith("$resolvedTemporaryBase\fantu-server-diagnostics-", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe diagnostics test directory: $resolvedTemporaryRoot"
}

New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null
try {
    $serverPath = Join-Path $temporaryRoot "fantu-server.exe"
    function Invoke-ExpectedServerFailure {
        param([string[]]$Arguments)

        $previousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            $output = & $serverPath @Arguments 2>&1 | Out-String
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        return [pscustomobject]@{ ExitCode = $exitCode; Output = $output }
    }
    Push-Location $projectRoot
    try {
        go build -trimpath '-ldflags=-s -w' -o $serverPath ./cmd/server
        if ($LASTEXITCODE -ne 0) { throw "Could not build the diagnostics test server." }
    }
    finally {
        Pop-Location
    }

    $invalidLevelResult = Invoke-ExpectedServerFailure -Arguments @("-log-level", "VERBOSE")
    if ($invalidLevelResult.ExitCode -ne 2 -or $invalidLevelResult.Output -notmatch "unsupported log level") {
        throw "An invalid server log level did not produce the expected configuration error."
    }

    $missingDataLog = Join-Path $temporaryRoot "missing-data.log"
    $missingDataResult = Invoke-ExpectedServerFailure -Arguments @(
        "-data", (Join-Path $temporaryRoot "missing-data"),
        "-saves", (Join-Path $temporaryRoot "saves"),
        "-log", $missingDataLog,
        "-session-id", "diagnostics-test",
        "-version", "test"
    )
    if ($missingDataResult.ExitCode -eq 0) { throw "Missing scenario data unexpectedly started the server." }
    $missingDataContent = Get-Content -LiteralPath $missingDataLog -Raw
    if ($missingDataContent -notmatch "event=fatal" -or $missingDataContent -notmatch "load scenario data") {
        throw "Missing scenario data was not recorded in the server log."
    }

    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try {
        $occupiedPort = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
        $portLog = Join-Path $temporaryRoot "port-conflict.log"
        $portResult = Invoke-ExpectedServerFailure -Arguments @(
            "-addr", "127.0.0.1:$occupiedPort",
            "-data", (Join-Path $projectRoot "data\blackwind"),
            "-saves", (Join-Path $temporaryRoot "saves"),
            "-log", $portLog,
            "-session-id", "diagnostics-test",
            "-version", "test"
        )
        if ($portResult.ExitCode -eq 0) { throw "An occupied port unexpectedly started the server." }
        $portContent = Get-Content -LiteralPath $portLog -Raw
        if ($portContent -notmatch "event=fatal" -or $portContent -notmatch "listen") {
            throw "The port conflict was not recorded in the server log."
        }
    }
    finally {
        $listener.Stop()
    }

    $portProbe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $portProbe.Start()
    $shutdownPort = ([System.Net.IPEndPoint]$portProbe.LocalEndpoint).Port
    $portProbe.Stop()

    $shutdownLog = Join-Path $temporaryRoot "graceful-shutdown.log"
    $shutdownToken = "diagnostics-shutdown-token"
    $shutdownProcess = Start-Process -FilePath $serverPath -ArgumentList @(
        "-addr", "127.0.0.1:$shutdownPort",
        "-data", (Join-Path $projectRoot "data\blackwind"),
        "-saves", (Join-Path $temporaryRoot "shutdown-saves"),
        "-log", $shutdownLog,
        "-session-id", "graceful-shutdown-test",
        "-version", "test",
        "-shutdown-token", $shutdownToken
    ) -WindowStyle Hidden -PassThru
    try {
        $healthUri = "http://127.0.0.1:$shutdownPort/api/v1/health"
        $serverReady = $false
        for ($attempt = 0; $attempt -lt 50; $attempt++) {
            try {
                Invoke-RestMethod -Uri $healthUri -TimeoutSec 1 | Out-Null
                $serverReady = $true
                break
            }
            catch {
                Start-Sleep -Milliseconds 100
            }
        }
        if (-not $serverReady) { throw "The graceful-shutdown test server did not become ready." }

        $shutdownUri = "http://127.0.0.1:$shutdownPort/api/v1/server/shutdown"
        Invoke-RestMethod -Method Post -Uri $shutdownUri -ContentType "application/json" -Body (@{ token = $shutdownToken } | ConvertTo-Json -Compress) -TimeoutSec 5 | Out-Null
        if (-not $shutdownProcess.WaitForExit(10000)) {
            throw "The server did not exit after an authorized shutdown request."
        }
        if ($shutdownProcess.ExitCode -ne 0) {
            throw "The gracefully stopped server exited with code $($shutdownProcess.ExitCode)."
        }

        $shutdownContent = Get-Content -LiteralPath $shutdownLog -Raw
        if ($shutdownContent -notmatch "event=shutdown_requested" -or
            $shutdownContent -notmatch 'reason="client_request"' -or
            $shutdownContent -notmatch "event=stopped") {
            throw "The graceful shutdown lifecycle was not fully recorded in the server log."
        }
    }
    finally {
        if (-not $shutdownProcess.HasExited) {
            $shutdownProcess.Kill()
            $shutdownProcess.WaitForExit()
        }
        $shutdownProcess.Dispose()
    }

    $blockedParent = Join-Path $temporaryRoot "blocked-parent"
    Set-Content -LiteralPath $blockedParent -Value "not a directory" -Encoding ascii
    $loggingResult = Invoke-ExpectedServerFailure -Arguments @(
        "-data", (Join-Path $projectRoot "data\blackwind"),
        "-saves", (Join-Path $temporaryRoot "saves"),
        "-log", (Join-Path $blockedParent "server.log")
    )
    if ($loggingResult.ExitCode -eq 0) { throw "An invalid log directory unexpectedly started the server." }
    if ($loggingResult.Output -notmatch "configure logging") {
        throw "An invalid log directory did not produce a visible startup error."
    }
}
finally {
    if (Test-Path -LiteralPath $resolvedTemporaryRoot) {
        Remove-Item -LiteralPath $resolvedTemporaryRoot -Recurse -Force
    }
}

Write-Host "Server diagnostics failure-path verification passed."
