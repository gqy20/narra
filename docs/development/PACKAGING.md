# Windows packaging

> Status: current operational guide
> Last verified: 2026-08-04

All distributable file and directory names use ASCII English names so they work reliably with launchers, archives, CI systems, and download services.

## Prerequisites

- Go matching the version declared by `go.mod`
- Godot 4.7.1 or a compatible 4.7 release
- Godot Windows export templates for the installed Godot version

If the matching templates are not installed, Windows x86_64 templates can be fetched from the official Godot release archive without downloading templates for every platform:

```powershell
py ./tools/install-godot-windows-templates.py --version 4.7.1.stable
```

## Build

From the repository root:

```powershell
./tools/build-windows.ps1
```

For a versioned archive name:

```powershell
./tools/build-windows.ps1 -Version 0.1.0
```

The script runs the Go test suite, builds a stripped Windows rules service, imports and exports the Godot project, copies the release scenario, runs a headless release smoke test, writes SHA-256 checksums, and creates a compressed ZIP archive.

The public Windows package is intentionally a single-story release. It bundles only `data/tianqi`, and launching `Narra.exe` without arguments starts the Tianqi story (`tianqi_t00`). `blackwind` remains development/prototype content, while `orbital` remains portability-test content; neither is copied into a public package.

`build-info.json` records the version, commit, build time, platform, and `source_dirty` state. A formal release should be built from a clean tree so its source revision is reproducible.

Use `-SkipTests` only when tests have already passed in the same source revision.
Use `-SkipSmokeTest` only in an environment that cannot launch Windows executables.

## Outputs

```text
dist/
|-- narra-windows-x86_64/
|   |-- Narra.exe
|   |-- Narra-Portable.cmd
|   |-- Enable-Crash-Dumps.cmd
|   |-- Disable-Crash-Dumps.cmd
|   |-- narra-server.exe
|   |-- build-info.json
|   |-- data/tianqi/
|   |-- README.txt
|   `-- SHA256SUMS.txt
`-- narra-windows-x86_64.zip
```

`Narra.exe` starts the local service automatically in exported Windows builds and stops the process when the game exits. The release smoke test rejects packages that contain any story other than `tianqi`, then verifies that the running service reports `tianqi_t00`. Logs, saves, and crash diagnostics are written under `%APPDATA%/Narra/` instead of the installation directory. See [runtime logging](LOGGING.md) for log rotation and portable developer mode.

Native Windows Error Reporting dumps for `Narra.exe` are intentionally opt-in. The two crash-dump scripts enable or remove the current-user WER setting without requiring administrator privileges. The service's own recovered-panic minidumps do not require this opt-in.
