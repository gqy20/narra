# Runtime logging and diagnostics

## Production layout

Normal Windows builds keep writable runtime data outside the installation directory:

```text
%APPDATA%/Fantu/
|-- logs/
|   |-- client.log
|   |-- engine.log
|   |-- server.log
|   `-- archived/
|-- saves/
|-- crash/
|-- diagnostics/
`-- settings.cfg
```

`client.log` contains structured application events. `engine.log` contains Godot engine output, script errors, and native crash-handler backtraces. `server.log` contains the bundled Go rules service output. Client and server application events use UTC timestamps and share `level`, `component`, `event`, `session`, `version`, and `message` fields, so both sides of one run can be correlated by session ID.

Client and server application logs rotate at 5 MiB and retain the newest five archives per component under `logs/archived/`. Godot rotates `engine.log` once per session and retains five engine logs; older engine logs are normalized into the same archive directory on the next launch.

## Levels and privacy

The supported thresholds are `DEBUG`, `INFO`, `WARN`, and `ERROR`. Production defaults to `INFO`. The in-game setting changes the client immediately, persists to `settings.cfg`, and is passed to the service on its next launch. Developers may also pass `--log-level=DEBUG` after Godot's `--` argument separator, or use the service's `-log-level` flag directly.

All structured fields pass through a centralized privacy filter. Token, password, authorization, cookie, query, payload, request/response body, and player-name fields are replaced with `[REDACTED]`. Inline credentials and URL queries are removed, local user paths are normalized, and line breaks cannot inject additional log records. HTTP summaries contain only method, path, status, duration, operation, and stable error code. Saves and request bodies are never logged.

## Failure handling and crash reports

If the normal AppData runtime directory cannot be created, the client falls back to the OS cache under `Fantu-Recovery`, writes `client-recovery.log`, and shows a visible in-game warning. If the service log fails while running, events continue on standard error and the file failure is reported once.

The client writes a running-session marker. If a native crash or forced termination leaves it behind, the next launch creates `crash/client-unclean-exit-*.json`. Godot's exported crash handler also writes its backtrace to `engine.log`, with release call-stack tracking enabled.

Recovered service panics create privacy-filtered JSON metadata and Go stacks under `crash/`. On Windows the service additionally calls `MiniDumpWriteDump` and creates a `.dmp` file when DbgHelp is available.

Windows Error Reporting minidumps for native `Fantu.exe` failures are opt-in because enabling them modifies the current user's registry. Run `Enable-Crash-Dumps.cmd` from the release package to retain up to five full dumps under `%APPDATA%/Fantu/crash`; run `Disable-Crash-Dumps.cmd` to remove that registry configuration. Neither script requires administrator privileges.

## In-game diagnostics

The settings panel provides **Open Log Folder**, **Export Diagnostics**, and the log-level selector. A diagnostics ZIP contains:

- manifest and build identity;
- OS, CPU, memory, screen, graphics adapter, Godot, disk-space, service-process, and last HTTP status metadata;
- current client, engine, and server logs plus retained archives;
- the newest crash reports and minidumps, with individual files capped at 25 MiB.

Diagnostics intentionally exclude saves, request bodies, command-line arguments, environment variables, and credentials. Archives are written under `%APPDATA%/Fantu/diagnostics/` in production mode or beside the executable in portable mode.

## Portable developer mode

Run `Fantu-Portable.cmd` from an extracted Windows package to place runtime files beside `Fantu.exe`. The launcher redirects Godot engine output to `logs/engine.log`; structured client output remains in `logs/client.log`.

Portable mode requires a writable game directory and is intended for development and troubleshooting. The equivalent command is:

```powershell
./Fantu.exe --log-file ./logs/engine.log -- --portable --log-level=DEBUG
```

Godot disables its built-in engine-log rotation when `--log-file` is supplied, so portable users should periodically remove an oversized `engine.log`. Client and server structured logs still use the normal 5 MiB rotation policy.
