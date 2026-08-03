extends RefCounted

var host


func _init(value) -> void:
	host = value


func _configure_runtime_paths() -> void:
	host.portable_mode = OS.get_cmdline_user_args().has(host.PORTABLE_USER_ARG)
	if host.portable_mode and not OS.has_feature("editor"):
		host.runtime_root = OS.get_executable_path().get_base_dir()
	else:
		host.runtime_root = OS.get_user_data_dir()
	host.logs_dir = host.runtime_root.path_join("logs")
	host.archived_logs_dir = host.logs_dir.path_join("archived")
	host.saves_dir = host.runtime_root.path_join("saves")
	host.crash_dir = host.runtime_root.path_join("crash")
	host.client_log_path = host.logs_dir.path_join("client.log")
	var failed_directories: Array[String] = []
	for directory in [host.logs_dir, host.archived_logs_dir, host.saves_dir, host.crash_dir, host.runtime_root.path_join("diagnostics")]:
		var mkdir_error = DirAccess.make_dir_recursive_absolute(directory)
		if mkdir_error != OK:
			failed_directories.append(directory)
	if not failed_directories.is_empty():
		var requested_root = host.runtime_root
		host.runtime_root = OS.get_cache_dir().path_join("Fantu-Recovery")
		host.logs_dir = host.runtime_root.path_join("logs")
		host.archived_logs_dir = host.logs_dir.path_join("archived")
		host.saves_dir = host.runtime_root.path_join("saves")
		host.crash_dir = host.runtime_root.path_join("crash")
		host.client_log_path = host.logs_dir.path_join("client.log")
		for directory in [host.logs_dir, host.archived_logs_dir, host.saves_dir, host.crash_dir, host.runtime_root.path_join("diagnostics")]:
			DirAccess.make_dir_recursive_absolute(directory)
		host.runtime_warning = "运行数据目录不可写，已降级到恢复目录：%s（原目录：%s）" % [host.runtime_root, requested_root]
		host.recovery_log_path = host.logs_dir.path_join("client-recovery.log")
		push_error(host.runtime_warning)
	host.runtime_logger_controller._archive_previous_client_logs()


func _configure_runtime_identity() -> void:
	var crypto = Crypto.new()
	host.session_id = crypto.generate_random_bytes(16).hex_encode()
	host.shutdown_token = crypto.generate_random_bytes(24).hex_encode()
	host.build_version = str(ProjectSettings.get_setting("application/config/version", "dev"))
	host.display_settings_controller._load_user_settings()
	if not OS.has_feature("editor"):
		var build_info_path = OS.get_executable_path().get_base_dir().path_join("build-info.json")
		if FileAccess.file_exists(build_info_path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(build_info_path))
			if parsed is Dictionary:
				host.build_info = parsed
				host.build_version = str(parsed.get("version", host.build_version))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--log-level="):
			var requested_level = argument.trim_prefix("--log-level=").to_upper()
			if host.LOG_LEVELS.has(requested_level):
				host.log_level = requested_level


func _log_event(level: String, event: String, message: String, fields := {}) -> void:
	level = level.to_upper()
	if not host.LOG_LEVEL_RANK.has(level):
		level = "INFO"
	if int(host.LOG_LEVEL_RANK[level]) < int(host.LOG_LEVEL_RANK.get(host.log_level, 1)):
		return
	var parts: Array[String] = [
		"timestamp=%sZ" % Time.get_datetime_string_from_system(true, false),
		"level=%s" % level,
		"component=client",
		"event=%s" % event,
		"session=%s" % JSON.stringify(host.session_id),
		"version=%s" % JSON.stringify(host.build_version),
		"message=%s" % JSON.stringify(host.runtime_logger_controller._redact_log_text(message)),
	]
	if fields is Dictionary:
		var keys: Array = fields.keys()
		keys.sort()
		for key in keys:
			parts.append("%s=%s" % [str(key), JSON.stringify(host.runtime_logger_controller._redact_log_field(str(key), fields[key]))])
	var line = " ".join(parts)
	print(line)
	host.runtime_logger_controller._write_client_log(line)


func _redact_log_field(key: String, value: Variant) -> String:
	var lower_key = key.to_lower()
	for sensitive_key in ["token", "password", "secret", "authorization", "cookie", "request_body", "response_body", "player_name", "query"]:
		if lower_key.contains(sensitive_key):
			return "[REDACTED]"
	var text = host.runtime_logger_controller._redact_log_text(str(value))
	if lower_key.contains("path") or lower_key in ["data", "saves", "crash_dir"]:
		if host.runtime_root != "":
			text = text.replace(host.runtime_root, "<runtime>")
		var install_dir = OS.get_executable_path().get_base_dir()
		if install_dir != "":
			text = text.replace(install_dir, "<app>")
	return text


func _redact_log_text(value: String) -> String:
	var text = value.replace("\r", "\\r").replace("\n", "\\n")
	var credential_pattern = RegEx.new()
	if credential_pattern.compile("(?i)(token|password|secret|authorization|cookie)=([^\\s&]+)") == OK:
		text = credential_pattern.sub(text, "$1=[REDACTED]", true)
	var url_pattern = RegEx.new()
	if url_pattern.compile("(https?://[^\\s?]+)\\?[^\\s]+") == OK:
		text = url_pattern.sub(text, "$1", true)
	return text


func _append_recovery_log(line: String) -> void:
	var recovery_file = FileAccess.open(host.recovery_log_path, FileAccess.READ_WRITE)
	if recovery_file == null:
		recovery_file = FileAccess.open(host.recovery_log_path, FileAccess.WRITE)
	if recovery_file == null:
		push_error("Could not write fallback client diagnostics: %s" % host.recovery_log_path)
		return
	recovery_file.seek_end()
	recovery_file.store_line(line)


func _write_client_log(line: String) -> void:
	var encoded_size = line.to_utf8_buffer().size() + 1
	if host.runtime_logger_controller._file_size(host.client_log_path) + encoded_size > host.LOG_MAX_MIB * 1024 * 1024:
		host.runtime_logger_controller._rotate_client_log()
	var client_file = FileAccess.open(host.client_log_path, FileAccess.READ_WRITE)
	if client_file == null:
		client_file = FileAccess.open(host.client_log_path, FileAccess.WRITE)
	if client_file == null:
		if not host.client_log_failure_reported:
			host.client_log_failure_reported = true
			host.runtime_warning = "客户端日志文件不可写：%s。诊断信息将仅输出到控制台。" % host.client_log_path
			push_error(host.runtime_warning)
		if host.recovery_log_path != "":
			host.runtime_logger_controller._append_recovery_log(line)
		return
	client_file.seek_end()
	client_file.store_line(line)


func _file_size(path: String) -> int:
	var file = FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file != null else 0


func _rotate_client_log() -> void:
	var timestamp = Time.get_datetime_string_from_system(true, false).replace("-", "").replace(":", "")
	var target_path = host.archived_logs_dir.path_join("client-%sZ.log" % timestamp)
	var suffix = 1
	while FileAccess.file_exists(target_path):
		target_path = host.archived_logs_dir.path_join("client-%sZ-%d.log" % [timestamp, suffix])
		suffix += 1
	var rotate_error = DirAccess.rename_absolute(host.client_log_path, target_path)
	if rotate_error != OK:
		push_error("Could not rotate client log: %s" % host.client_log_path)
		return
	host.runtime_logger_controller._prune_log_archives("client-")


func _prune_log_archives(prefix: String) -> void:
	var archive_directory = DirAccess.open(host.archived_logs_dir)
	if archive_directory == null:
		return
	var archives: Array[String] = []
	for file_name in archive_directory.get_files():
		if file_name.begins_with(prefix) and file_name.ends_with(".log"):
			archives.append(file_name)
	archives.sort()
	while archives.size() > host.LOG_BACKUPS:
		DirAccess.remove_absolute(host.archived_logs_dir.path_join(archives.pop_front()))


func _initialize_crash_tracking() -> void:
	host.session_marker_path = host.crash_dir.path_join("client-running.json")
	if FileAccess.file_exists(host.session_marker_path):
		var timestamp = Time.get_datetime_string_from_system(true, false).replace("-", "").replace(":", "")
		var unclean_path = host.crash_dir.path_join("client-unclean-exit-%sZ.json" % timestamp)
		var previous_marker = FileAccess.get_file_as_string(host.session_marker_path)
		var previous_data = JSON.parse_string(previous_marker)
		if not previous_data is Dictionary:
			previous_data = {"raw_marker": host.runtime_logger_controller._redact_log_text(previous_marker)}
		previous_data["detected_at_utc"] = "%sZ" % Time.get_datetime_string_from_system(true, false)
		previous_data["reason"] = "The previous client session did not complete normal shutdown."
		var report = FileAccess.open(unclean_path, FileAccess.WRITE)
		if report != null:
			report.store_string(JSON.stringify(previous_data, "  "))
		host.runtime_logger_controller._log_event("ERROR", "previous_unclean_exit", "previous client session ended unexpectedly", {"file": unclean_path.get_file()})
	var marker = FileAccess.open(host.session_marker_path, FileAccess.WRITE)
	if marker == null:
		host.runtime_logger_controller._log_event("ERROR", "crash_marker_failed", "could not create client crash marker", {"path": host.session_marker_path})
		return
	marker.store_string(JSON.stringify({
		"application": "Fantu",
		"session_id": host.session_id,
		"version": host.build_version,
		"pid": OS.get_process_id(),
		"started_at_utc": "%sZ" % Time.get_datetime_string_from_system(true, false),
		"operating_system": OS.get_name(),
		"godot": Engine.get_version_info().get("string", "unknown"),
	}, "  "))


func _clear_crash_marker() -> void:
	if host.session_marker_path != "" and FileAccess.file_exists(host.session_marker_path):
		var remove_error = DirAccess.remove_absolute(host.session_marker_path)
		if remove_error != OK:
			push_warning("Could not clear client crash marker: %s" % host.session_marker_path)


func _archive_previous_client_logs() -> void:
	var log_directory = DirAccess.open(host.logs_dir)
	if log_directory == null:
		return
	for file_name in log_directory.get_files():
		if file_name in ["client.log", "engine.log"] or not file_name.ends_with(".log"):
			continue
		var archive_prefix = "client" if file_name.begins_with("client") else "engine" if file_name.begins_with("engine") else ""
		if archive_prefix == "":
			continue
		var source_path = host.logs_dir.path_join(file_name)
		var modified = FileAccess.get_modified_time(source_path)
		var timestamp = Time.get_datetime_string_from_unix_time(modified).replace("-", "").replace(":", "")
		var target_name = "%s-%sZ.log" % [archive_prefix, timestamp]
		var target_path = host.archived_logs_dir.path_join(target_name)
		var suffix = 1
		if FileAccess.file_exists(target_path):
			while FileAccess.file_exists(host.archived_logs_dir.path_join("%s-%sZ-%d.log" % [archive_prefix, timestamp, suffix])):
				suffix += 1
			target_path = host.archived_logs_dir.path_join("%s-%sZ-%d.log" % [archive_prefix, timestamp, suffix])
		var archive_error = DirAccess.rename_absolute(source_path, target_path)
		if archive_error != OK:
			push_warning("Could not archive client log: %s" % source_path)
	host.runtime_logger_controller._prune_log_archives("client-")
	host.runtime_logger_controller._prune_log_archives("engine-")


func _open_log_folder() -> void:
	host.runtime_logger_controller._log_event("INFO", "open_log_folder", "opening log directory")
	var open_error = OS.shell_open(host.logs_dir)
	if open_error != OK:
		push_error("Could not open the log directory: %s" % host.logs_dir)


func _export_diagnostics(open_folder := true) -> String:
	var archive_path = host.diagnostics_exporter.export(host.runtime_logger_controller._diagnostics_context(), open_folder)
	if archive_path == "":
		host._show_error("无法创建诊断压缩包。")
	return archive_path


func _diagnostic_environment() -> Dictionary:
	return host.diagnostics_exporter.environment(host.runtime_logger_controller._diagnostics_context())


func _diagnostics_context() -> Dictionary:
	return {
		"runtime_root": host.runtime_root, "logs_dir": host.logs_dir, "archived_logs_dir": host.archived_logs_dir, "crash_dir": host.crash_dir,
		"build_version": host.build_version, "session_id": host.session_id, "portable_mode": host.portable_mode, "log_level": host.log_level,
		"display_mode": host.display_mode, "display_resolution": host.display_resolution, "ui_scale": host.ui_scale, "build_info": host.build_info,
		"server_process_running": host.local_server_process != null and host.local_server_process.is_running(),
		"last_server_http_status": host.last_server_http_status, "max_file_bytes": host.DIAGNOSTIC_FILE_MAX_BYTES, "backups": host.LOG_BACKUPS,
	}
