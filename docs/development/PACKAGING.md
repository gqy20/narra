# Desktop packaging and GitHub releases

> Status: current operational guide
> Last verified: 2026-08-07

All distributable file and directory names use ASCII English names so they work reliably with launchers, archives, CI systems, and download services.

## Prerequisites

- Go matching the version declared by `go.mod`
- Godot 4.7.1 or a compatible 4.7 release
- Godot export templates for the target platform and installed Godot version

The template installer fetches only the files required by the selected platform:

```powershell
py ./tools/install-godot-templates.py --platform windows --version 4.7.1.stable
```

```bash
python3 ./tools/install-godot-templates.py --platform macos --version 4.7.1.stable
```

```bash
python3 ./tools/install-godot-templates.py --platform linux --version 4.7.1.stable
```

## Windows build

From the repository root:

```powershell
./tools/build-windows.ps1
```

For a versioned archive name:

```powershell
./tools/build-windows.ps1 -Version 0.1.0
```

The script runs the Go test suite, builds a stripped Windows rules service, imports and exports the Godot project, copies the release scenario, runs a headless release smoke test, writes SHA-256 checksums, and creates a compressed ZIP archive.

The public Windows package is intentionally a single-story release. It bundles only 《天变邸抄》 (`data/tianqi`, internal scenario ID `tianqi_t00`), and launching `Narra.exe` without arguments starts that story. 《黑风谷》 remains development/prototype content, while 《远星环站》 remains portability-test content; neither is copied into a public package.

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

## macOS build

The macOS package must be built on macOS because it uses `lipo`, preserves application-bundle metadata with `ditto`, and runs the exported application as its smoke test:

```bash
bash ./tools/build-macos.sh 0.1.0
```

The script builds `narra-server` for both `amd64` and `arm64`, combines it into one Universal binary, exports `Narra.app`, installs the service and `data/tianqi` under `Contents/MacOS`, verifies the bundled service through the live health endpoint, and creates:

```text
dist/
|-- narra-macos-universal-unsigned/
|   |-- Narra.app/
|   |-- README.txt
|   `-- SHA256SUMS.txt
`-- narra-macos-universal-0.1.0-unsigned.zip
```

The repository does not contain an Apple signing identity. Local and GitHub-hosted builds are therefore explicitly named `unsigned`. They are useful for internal verification, but Gatekeeper may block a downloaded copy. Public macOS distribution should import a Developer ID Application certificate into the CI keychain, sign the bundled service and application, submit the archive to Apple's notarization service, staple the result, and only then publish it. Those credentials must be stored as GitHub Actions secrets and must never be committed.

## Linux build

Build the Linux x86_64 package on Linux so the exported client and bundled service can be exercised by the live smoke test:

```bash
bash ./tools/build-linux.sh 0.1.0
```

The script builds a stripped `linux/amd64` rules service, exports the Godot client with its PCK embedded, copies only `data/tianqi`, starts the packaged client headlessly, verifies the live health endpoint and service shutdown, writes SHA-256 checksums, and creates:

```text
dist/
|-- narra-linux-x86_64/
|   |-- Narra.x86_64
|   |-- narra-server
|   |-- build-info.json
|   |-- data/tianqi/
|   |-- README.txt
|   `-- SHA256SUMS.txt
`-- narra-linux-x86_64-0.1.0.tar.gz
```

Run `./Narra.x86_64` after extracting the archive. Executable permissions are preserved by the `tar.gz` package. Logs, saves, and diagnostics use `~/.local/share/Narra` by default, or the equivalent location under `XDG_DATA_HOME` when it is set. The current public Linux target is x86_64; a native ARM64 package is not produced.

## GitHub Actions

`.github/workflows/ci.yml` runs the deterministic Go/content/docs gate on Ubuntu and the complete Godot gate on Windows for pushes to `main` and pull requests.

`.github/workflows/build.yml` runs for every push and can also be started manually. Its Windows, macOS, and Linux jobs have no dependency between them, so GitHub schedules them in parallel. Every job builds the bundled client and service, runs the package smoke test on its target operating system, and uploads a seven-day workflow artifact. This provides installable test builds without creating a GitHub Release.

`.github/workflows/release.yml` runs only for semantic version tags. Before tagging, update `config/version` in `godot/project.godot` and add the matching dated section to the root `CHANGELOG.md`; the workflow rejects version or changelog mismatches:

```bash
git tag v0.1.0
git push origin v0.1.0
```

After all three platform jobs pass their package smoke tests, the workflow extracts the matching `CHANGELOG.md` section as the release notes and creates one GitHub Release containing the Windows x86_64 ZIP, unsigned macOS Universal ZIP, Linux x86_64 tarball, and SHA-256 checksums. The release still bundles only the Chinese story 《天变邸抄》 (`data/tianqi`, internal scenario ID `tianqi_t00`); the internal directory and ID remain stable configuration identifiers, not player-facing names.

CI and release workflows use the current major versions of the official `checkout`, `setup-go`, `upload-artifact`, and `download-artifact` actions. Dependabot checks the `github-actions` ecosystem weekly and opens an update when a newer compatible action is available.
