# Runtime logging

## Production layout

Normal Windows builds keep writable runtime data outside the installation directory:

```text
%APPDATA%/Fantu/
|-- logs/
|   |-- client.log
|   |-- server.log
|   `-- archived/
|-- saves/
`-- crash/
```

The Godot client writes engine and application output to `client.log`. Previous client sessions are moved to `logs/archived/`, with the newest five retained.

The bundled Go rules service writes startup, scenario loading, listening, graceful shutdown, HTTP access summaries, HTTP panic, port-binding, and fatal diagnostics to `server.log`. The active server log rotates at 5 MiB and retains the newest five `server-*.log` files under `logs/archived/`.

Client and server application events use UTC timestamps and share `level`, `component`, `event`, `session`, `version`, and `message` fields. HTTP summaries contain only the method, URL path, status code, duration, operation, and stable error code. Query strings, request bodies, player names, and save contents are not logged.

Recovered HTTP panics are written to both `server.log` and a timestamped report under `crash/`. Native engine crash dumps remain platform-managed and may not be available on every Windows installation.

The in-game settings panel contains **Open Log Folder** and **Export Diagnostics** actions so users do not need to navigate into AppData manually.

The diagnostics ZIP contains a manifest, current client and server logs, and retained log archives. It intentionally excludes saves and HTTP request bodies. Archives are written under `%APPDATA%/Fantu/diagnostics/` in production mode or the executable directory in portable mode.

## Portable developer mode

Run `Fantu-Portable.cmd` from an extracted Windows package to place `logs/`, `saves/`, and `crash/` beside `Fantu.exe`. The launcher also redirects the Godot engine log to the portable `logs/client.log` file.

Portable mode requires a writable game directory and is intended for development and troubleshooting. Normal players should launch `Fantu.exe` and use the per-user AppData layout.

The equivalent command is:

```powershell
./Fantu.exe --log-file ./logs/client.log -- --portable
```

Arguments after `--` are application arguments passed to the game rather than Godot engine arguments.
