$ErrorActionPreference = "Stop"

$unformatted = @(gofmt -l .)
if ($unformatted.Count -gt 0) {
    Write-Error ("These Go files need gofmt:`n" + ($unformatted -join "`n"))
}

go test ./...
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

go vet ./...
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Verification passed."
