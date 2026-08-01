# Windows packaging

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

The script runs the Go test suite, builds a stripped Windows rules service, imports and exports the Godot project, copies runtime scenario data, runs a headless release smoke test, writes SHA-256 checksums, and creates a compressed ZIP archive.

Use `-SkipTests` only when tests have already passed in the same source revision.
Use `-SkipSmokeTest` only in an environment that cannot launch Windows executables.

## Outputs

```text
dist/
|-- fantu-windows-x86_64/
|   |-- Fantu.exe
|   |-- fantu-server.exe
|   |-- data/blackwind/
|   |-- README.txt
|   `-- SHA256SUMS.txt
`-- fantu-windows-x86_64.zip
```

`Fantu.exe` starts the local service automatically in exported Windows builds and stops the process when the game exits. Save files are written under the Godot per-user application-data directory instead of the installation directory.
