# Development workflow

GNU Make is the single command entry point for local development, validation, and Windows packaging. PowerShell scripts under `tools/` contain the implementation so the same operations can also be run directly or from CI.

Run `make` or `make help` to list available commands.

## Environment

```powershell
make doctor
```

The doctor checks Go, Godot, GNU Make, Python, and Windows x86_64 Godot export templates. Missing templates can be installed with:

```powershell
make templates-windows GODOT_VERSION=4.7.1.stable
```

## Daily development

```powershell
make fmt
make test-go
make test-godot
make verify
```

`make verify` is the local quality gate: formatting check, Go tests, `go vet`, and Godot integration tests.

Run the game through one of the supported front ends:

```powershell
make run-cli
make run-godot
```

## Windows releases

Create a testable portable package and ZIP:

```powershell
make package-windows
```

Create a versioned release after running the complete quality gate:

```powershell
make release-windows VERSION=0.1.0
```

The release remains under `dist/fantu-windows-x86_64/`; the version is added to the archive filename. Test an existing package independently with `make smoke-windows`.

`make package-windows-fast` skips duplicate Go tests but still exports the game and runs the packaged client/server smoke test. It is intended for use after `make verify`, as done by `make release-windows`.

## Cleanup

```powershell
make clean-package
make clean-server
make clean
```

Cleanup is restricted to the repository's top-level ignored `dist/` and `bin/` build directories. It does not remove saves, reports, source assets, or Godot's import cache.
