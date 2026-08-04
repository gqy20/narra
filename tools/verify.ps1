$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "verify-docs.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$unformatted = @(gofmt -l .)
if ($unformatted.Count -gt 0) {
    Write-Error ("These Go files need gofmt:`n" + ($unformatted -join "`n"))
}

go test ./...
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

go vet ./...
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

foreach ($scenario in @("data/blackwind", "data/tianqi", "data/orbital")) {
    go run ./cmd/narra-content test $scenario
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "Verification passed."
