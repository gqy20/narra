# Development workflow

> Status: current operational guide
> Last verified: 2026-08-04
> Validation details: [`VALIDATION.md`](VALIDATION.md)

GNU Make is the single command entry point for local development, validation, and desktop packaging. Scripts under `tools/` contain the implementation so the same operations can also be run directly or from CI.

Run `make` or `make help` to list available commands.

## Environment

```powershell
make doctor
```

On Windows, the doctor checks Go, Godot, GNU Make, Python, and Windows x86_64 Godot export templates. Missing templates can be installed with:

```powershell
make templates-windows GODOT_VERSION=4.7.1.stable
```

## Daily development

```powershell
make fmt
make test-go
make test-godot
make test-logging
make verify
```

`make verify` is the local quality gate: formatting check, Go tests, `go vet`, logging failure-path checks, and Godot integration tests. Logging checks cover client/server rotation, level filtering, centralized redaction, write-failure fallback, missing scenario data, occupied ports, invalid log directories, graceful-shutdown authorization, diagnostics environment metadata, and panic/crash reports.

Run the game through one of the supported front ends:

```powershell
make run-cli
make run-godot
```

## Desktop releases

Create a testable portable package and ZIP:

```powershell
make package-windows
```

Create a versioned release after running the complete quality gate:

```powershell
make release-windows VERSION=0.1.0
```

The release remains under `dist/narra-windows-x86_64/`; the version is added to the archive filename. Test an existing package independently with `make smoke-windows`.

`make package-windows-fast` skips duplicate Go tests but still exports the game and runs the packaged client/server smoke test. It is intended for use after `make verify`, as done by `make release-windows`.

On macOS, install the matching template and build an unsigned Universal 2 package with:

```bash
make templates-macos GODOT_VERSION=4.7.1.stable
make package-macos VERSION=0.1.0
```

Pushes to `main` and pull requests run `.github/workflows/ci.yml`. Every pushed commit also runs `.github/workflows/build.yml`; its independent Windows and macOS jobs build and smoke-test both packages in parallel, then retain the downloadable artifacts for seven days without creating a release. Pushing a version tag such as `v0.1.0` runs `.github/workflows/release.yml`, verifies that the tag matches `godot/project.godot`, builds both platforms in parallel, and publishes both ZIP files to one GitHub Release. The automated macOS artifact is unsigned; see [`PACKAGING.md`](PACKAGING.md) for signing and notarization requirements.

Official GitHub Actions dependencies are kept on their current major versions, and `.github/dependabot.yml` checks them weekly for future updates.

## Cleanup

```powershell
make clean-package
make clean-server
make clean
```

Cleanup is restricted to the repository's top-level ignored `dist/` and `bin/` build directories. It does not remove saves, reports, source assets, or Godot's import cache.
