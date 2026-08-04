class_name DiagnosticsExporter
extends RefCounted

signal log_event(level: String, event: String, message: String, fields: Dictionary)


func export(context: Dictionary, open_folder := true) -> String:
	log_event.emit("INFO", "diagnostics_export", "creating diagnostics archive", {})
	var diagnostics_dir := str(context.runtime_root).path_join("diagnostics")
	var mkdir_error := DirAccess.make_dir_recursive_absolute(diagnostics_dir)
	if mkdir_error != OK:
		log_event.emit("ERROR", "diagnostics_failed", "could not create diagnostics directory", {"error": mkdir_error})
		return ""
	var timestamp := Time.get_datetime_string_from_system(true, false).replace("-", "").replace(":", "")
	var archive_path := diagnostics_dir.path_join("Narra-Diagnostics-%sZ.zip" % timestamp)
	var packer := ZIPPacker.new()
	var open_error := packer.open(archive_path)
	if open_error != OK:
		log_event.emit("ERROR", "diagnostics_failed", "could not open diagnostics archive", {"error": open_error})
		return ""
	var environment := environment(context)
	var manifest := {
		"application": "Narra",
		"generated_at_utc": "%sZ" % Time.get_datetime_string_from_system(true, false),
		"version": context.build_version,
		"session_id": context.session_id,
		"operating_system": OS.get_name(),
		"godot": Engine.get_version_info().get("string", "unknown"),
		"portable_mode": context.portable_mode,
		"log_level": context.log_level,
		"environment": environment,
		"contents": "Logs and environment metadata only; saves and request bodies are excluded.",
	}
	_write_json(packer, "manifest.json", manifest)
	_write_json(packer, "environment.json", environment)
	_add_file(packer, str(context.logs_dir).path_join("client.log"), "logs/client.log", int(context.max_file_bytes))
	_add_file(packer, str(context.logs_dir).path_join("engine.log"), "logs/engine.log", int(context.max_file_bytes))
	_add_file(packer, str(context.logs_dir).path_join("server.log"), "logs/server.log", int(context.max_file_bytes))
	_add_directory_files(packer, str(context.archived_logs_dir), "logs/archived", [".log"], 0, int(context.max_file_bytes))
	_add_directory_files(packer, str(context.crash_dir), "crash", [".json", ".dmp", ".log"], int(context.backups), int(context.max_file_bytes))
	packer.close()
	log_event.emit("INFO", "diagnostics_created", "diagnostics archive created", {"file": archive_path.get_file()})
	if open_folder:
		OS.shell_open(diagnostics_dir)
	return archive_path


func environment(context: Dictionary) -> Dictionary:
	var memory := OS.get_memory_info()
	var screen_size := DisplayServer.screen_get_size()
	var runtime_space := -1
	var runtime_directory := DirAccess.open(str(context.runtime_root))
	if runtime_directory != null:
		runtime_space = runtime_directory.get_space_left()
	var resolution: Vector2i = context.display_resolution
	return {
		"operating_system": OS.get_name(), "os_distribution": OS.get_distribution_name(), "os_version": OS.get_version(),
		"locale": OS.get_locale(), "processor": OS.get_processor_name(), "processor_count": OS.get_processor_count(),
		"memory_physical_bytes": memory.get("physical", -1), "memory_available_bytes": memory.get("free", -1),
		"screen_width": screen_size.x, "screen_height": screen_size.y, "screen_dpi": DisplayServer.screen_get_dpi(),
		"window_mode": context.display_mode, "window_resolution": "%dx%d" % [resolution.x, resolution.y], "ui_scale": context.ui_scale,
		"graphics_adapter": RenderingServer.get_video_adapter_name(), "graphics_vendor": RenderingServer.get_video_adapter_vendor(),
		"graphics_api": RenderingServer.get_video_adapter_api_version(), "godot_version": Engine.get_version_info().get("string", "unknown"),
		"build": context.build_info, "runtime_space_available_bytes": runtime_space, "portable_mode": context.portable_mode,
		"server_process_running": context.server_process_running, "last_server_http_status": context.last_server_http_status, "log_level": context.log_level,
	}


func _write_json(packer: ZIPPacker, path: String, value: Dictionary) -> void:
	if packer.start_file(path) == OK:
		packer.write_file(JSON.stringify(value, "  ").to_utf8_buffer())
		packer.close_file()


func _add_directory_files(packer: ZIPPacker, directory_path: String, archive_dir: String, extensions: Array, limit: int, max_bytes: int) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	var names: Array[String] = []
	for file_name in directory.get_files():
		for extension in extensions:
			if file_name.ends_with(str(extension)):
				names.append(file_name)
				break
	names.sort()
	if limit > 0:
		while names.size() > limit:
			names.pop_front()
	for file_name in names:
		_add_file(packer, directory_path.path_join(file_name), archive_dir.path_join(file_name), max_bytes)


func _add_file(packer: ZIPPacker, source_path: String, archive_path: String, max_bytes: int) -> void:
	if not FileAccess.file_exists(source_path):
		return
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		log_event.emit("WARN", "diagnostics_file_skipped", "could not read diagnostics file", {"file": source_path.get_file()})
		return
	if source.get_length() > max_bytes:
		log_event.emit("WARN", "diagnostics_file_skipped", "diagnostics file exceeds size limit", {"file": source_path.get_file(), "size": source.get_length()})
		return
	if packer.start_file(archive_path) == OK:
		packer.write_file(source.get_buffer(source.get_length()))
		packer.close_file()
