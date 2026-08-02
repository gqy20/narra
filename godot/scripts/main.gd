extends Control

const WorldMapViewScript = preload("res://scripts/world_map.gd")
const LocationStageScript = preload("res://scripts/location_stage.gd")
const PresentationDirectorScript = preload("res://scripts/presentation_director.gd")
const PresentationRegistryScript = preload("res://scripts/presentation_registry.gd")
const AudioDirectorScript = preload("res://scripts/audio_director.gd")
const CausalSealTexture = preload("res://assets/ui/causal/causal-seal.png")
const DecisionFrameTexture = preload("res://assets/ui/causal/decision-frame.png")
const TimelineArrowTexture = preload("res://assets/ui/causal/timeline-arrow.png")
const StartBackgroundTexture = preload("res://assets/locations/market/background.png")
const API_BASE := "http://127.0.0.1:8787/api/v1"
const AUTOSAVE_SLOT := "autosave"
const BUNDLED_SERVER_NAME := "fantu-server.exe"
const BUNDLED_SERVER_STARTUP_DELAY := 0.4
const PORTABLE_USER_ARG := "--portable"
const LOG_MAX_MIB := 5
const LOG_BACKUPS := 5
const LOG_LEVELS: Array[String] = ["DEBUG", "INFO", "WARN", "ERROR"]
const LOG_LEVEL_RANK := {"DEBUG": 0, "INFO": 1, "WARN": 2, "ERROR": 3}
const DIAGNOSTIC_FILE_MAX_BYTES := 25 * 1024 * 1024
const TYPE_SCALE := {
	"display": 60,
	"brand": 28,
	"section": 18,
	"metric": 18,
	"body": 16,
	"compact": 15,
	"detail": 14,
	"meta": 13,
	"button": 15,
}
const COLORS := {
	"bg": Color("090c0a"),
	"bg_lift": Color("101712"),
	"panel": Color("121713"),
	"panel_alt": Color("1a231d"),
	"panel_hover": Color("232e26"),
	"line": Color("344039"),
	"line_soft": Color("242e28"),
	"ink": Color("f2ebdd"),
	"muted": Color("a9b3a6"),
	"accent": Color("d6ae62"),
	"accent_hover": Color("e4c079"),
	"accent_pressed": Color("b98e47"),
	"accent_ink": Color("15110a"),
	"danger": Color("c46352"),
	"danger_deep": Color("8f352c"),
	"success": Color("82aa78"),
}

@onready var http: HTTPRequest = $HTTPRequest

var current_view: Dictionary = {}
var pending_operation := ""
var autosave_after_action := false
var selected_action: Dictionary = {}
var selected_followup_action_id := ""
var queued_followup_action_id := ""
var available_actions_cache: Array = []
var focused_actor_id := ""
var focused_actor_name := ""
var focused_actor_action_id := ""
var focused_fact_id := ""
var focused_fact_claim := ""
var stage_actor_id := ""
var stage_actor_name := ""
var actor_expression_by_id := {}
var selected_map_location_id := ""
var rendered_location_id := ""
var visual_mode := "map"
var view_before_action: Dictionary = {}
var presentation_registry = PresentationRegistryScript.new()
var sound_enabled := true
var motion_enabled := true
var presentation_busy := false
var active_action_category := ""
var show_all_actions := false
var focused_actor_details_visible := false
var causal_change_count_by_actor := {}
var causal_actor_id_by_name := {}
var last_causal_actor_id := ""
var journal_feedback_details_visible := false
var journal_travel_details_visible := false
var journal_seen_feedback_signature := ""
var journal_current_feedback_signature := ""
var journal_tab_labels: Array[String] = ["回响", "线索", "人物", "行装"]
var journal_tab_colors: Array[Color] = [COLORS.muted, COLORS.muted, COLORS.muted, COLORS.muted]
var bundled_server_pid := -1
var runtime_root := ""
var logs_dir := ""
var archived_logs_dir := ""
var saves_dir := ""
var crash_dir := ""
var client_log_path := ""
var portable_mode := false
var session_id := ""
var shutdown_token := ""
var build_version := "dev"
var pending_request_path := ""
var pending_request_method := ""
var request_started_msec := 0
var shutdown_in_progress := false
var log_level := "INFO"
var runtime_warning := ""
var recovery_log_path := ""
var session_marker_path := ""
var build_info: Dictionary = {}
var last_server_http_status := 0
var client_log_failure_reported := false

var start_layer: Control
var game_layer: Control
var name_input: LineEdit
var connection_label: Label
var retry_button: Button
var day_label: Label
var place_label: Label
var phase_label: Label
var timing_label: Label
var objective_label: Label
var player_summary_label: Label
var player_resources_box: HFlowContainer
var journal_tabs: TabContainer
var journal_echo_button: Button
var journal_clues_button: Button
var journal_people_button: Button
var journal_travel_button: Button
var clues_box: VBoxContainer
var scene_box: VBoxContainer
var people_box: VBoxContainer
var travel_box: VBoxContainer
var journal_feedback_details_box: VBoxContainer
var journal_feedback_details_button: Button
var journal_travel_details_box: VBoxContainer
var journal_travel_details_button: Button
var actions_box: VBoxContainer
var overview_actions_box: VBoxContainer
var legacy_action_scroll: ScrollContainer
var actor_focus_workspace: HBoxContainer
var actor_focus_message_list: VBoxContainer
var actor_focus_detail_scroll: ScrollContainer
var actor_focus_detail_box: VBoxContainer
var actor_focus_footer: HBoxContainer
var action_canvas: CanvasLayer
var action_dock_host: Control
var action_dock: PanelContainer
var action_dock_title: Label
var footer_label: Label
var journal_layer: Control
var journal_panel: PanelContainer
var ending_layer: Control
var ending_box: VBoxContainer
var ending_background: TextureRect
var ending_portrait: TextureRect
var ending_seal: TextureRect
var ending_annex_box: VBoxContainer
var ending_annex_button: Button
var causal_layer: Control
var causal_background: TextureRect
var causal_portrait: TextureRect
var causal_message: Label
var causal_actor_meta: Label
var causal_original: Label
var causal_now: Label
var causal_day: Label
var confirmation_layer: Control
var confirmation_box: VBoxContainer
var confirmation_details_box: VBoxContainer
var confirmation_details_button: Button
var visual_stack: Control
var map_panel: HBoxContainer
var location_panel: VBoxContainer
var map_detail_box: VBoxContainer
var location_detail_box: VBoxContainer
var stage_people_box: HFlowContainer
var map_mode_button: Button
var location_mode_button: Button
var world_map_view: Control
var location_stage: Control
var presentation_director: Control
var audio_director: Node
var actor_portrait_frame: PanelContainer
var actor_portrait: TextureRect
var actor_portrait_name: Label
var actor_portrait_meta: Label
var sound_button: Button
var motion_button: Button
var settings_layer: Control
var settings_box: VBoxContainer
var log_level_button: Button
var body_font: SystemFont
var medium_font: SystemFont
var display_font: SystemFont


func _ready() -> void:
	_configure_runtime_paths()
	_configure_runtime_identity()
	_initialize_crash_tracking()
	get_tree().auto_accept_quit = false
	_log_event("INFO", "startup", "client starting", {
		"pid": OS.get_process_id(),
		"os": OS.get_name(),
		"portable": portable_mode,
	})
	_configure_theme()
	audio_director = AudioDirectorScript.new()
	add_child(audio_director)
	http.request_completed.connect(_on_request_completed)
	_build_interface()
	if runtime_warning != "":
		_show_error(runtime_warning)
	_start_bundled_server()
	if bundled_server_pid > 0:
		await get_tree().create_timer(BUNDLED_SERVER_STARTUP_DELAY).timeout
	_request("health", HTTPClient.METHOD_GET, "/health")


func _exit_tree() -> void:
	if bundled_server_pid > 0:
		_log_event("WARN", "server_force_stop", "forcing bundled service to stop", {"pid": bundled_server_pid})
		OS.kill(bundled_server_pid)
		bundled_server_pid = -1
	_log_event("INFO", "stopped", "client stopped")
	_clear_crash_marker()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_begin_graceful_shutdown()


func _begin_graceful_shutdown() -> void:
	if shutdown_in_progress:
		return
	shutdown_in_progress = true
	_log_event("INFO", "shutdown_requested", "window close requested")
	if bundled_server_pid <= 0:
		get_tree().quit()
		return
	var shutdown_http := HTTPRequest.new()
	shutdown_http.timeout = 1.5
	add_child(shutdown_http)
	var request_error := shutdown_http.request(
		API_BASE + "/server/shutdown",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify({"token": shutdown_token})
	)
	if request_error == OK:
		var response: Array = await shutdown_http.request_completed
		_log_event("INFO", "server_shutdown_response", "shutdown endpoint completed", {
			"result": response[0],
			"status": response[1],
		})
		await get_tree().create_timer(0.5).timeout
	shutdown_http.queue_free()
	if OS.is_process_running(bundled_server_pid):
		_log_event("WARN", "server_shutdown_fallback", "service did not stop gracefully", {"pid": bundled_server_pid})
		OS.kill(bundled_server_pid)
	else:
		_log_event("INFO", "server_stopped", "bundled service stopped gracefully")
	bundled_server_pid = -1
	get_tree().quit()


func _start_bundled_server() -> void:
	if OS.has_feature("editor") or OS.get_name() != "Windows":
		return
	var install_dir := OS.get_executable_path().get_base_dir()
	var server_path := install_dir.path_join(BUNDLED_SERVER_NAME)
	if not FileAccess.file_exists(server_path):
		push_error("Bundled game server is missing: %s" % server_path)
		return
	var data_dir := install_dir.path_join("data").path_join("blackwind")
	bundled_server_pid = OS.create_process(
		server_path,
		PackedStringArray([
			"-data", data_dir,
			"-saves", saves_dir,
			"-log", logs_dir.path_join("server.log"),
			"-crash-dir", crash_dir,
			"-log-max-mb", str(LOG_MAX_MIB),
			"-log-backups", str(LOG_BACKUPS),
			"-log-level", log_level,
			"-version", build_version,
			"-session-id", session_id,
			"-shutdown-token", shutdown_token,
		]),
		false
	)
	if bundled_server_pid > 0:
		_log_event("INFO", "server_started", "bundled service process created", {
			"pid": bundled_server_pid,
			"data": data_dir,
			"saves": saves_dir,
		})
	else:
		_log_event("ERROR", "server_start_failed", "could not create bundled service process", {"path": server_path})


func _configure_runtime_paths() -> void:
	portable_mode = OS.get_cmdline_user_args().has(PORTABLE_USER_ARG)
	if portable_mode and not OS.has_feature("editor"):
		runtime_root = OS.get_executable_path().get_base_dir()
	else:
		runtime_root = OS.get_user_data_dir()
	logs_dir = runtime_root.path_join("logs")
	archived_logs_dir = logs_dir.path_join("archived")
	saves_dir = runtime_root.path_join("saves")
	crash_dir = runtime_root.path_join("crash")
	client_log_path = logs_dir.path_join("client.log")
	var failed_directories: Array[String] = []
	for directory in [logs_dir, archived_logs_dir, saves_dir, crash_dir, runtime_root.path_join("diagnostics")]:
		var mkdir_error := DirAccess.make_dir_recursive_absolute(directory)
		if mkdir_error != OK:
			failed_directories.append(directory)
	if not failed_directories.is_empty():
		var requested_root := runtime_root
		runtime_root = OS.get_cache_dir().path_join("Fantu-Recovery")
		logs_dir = runtime_root.path_join("logs")
		archived_logs_dir = logs_dir.path_join("archived")
		saves_dir = runtime_root.path_join("saves")
		crash_dir = runtime_root.path_join("crash")
		client_log_path = logs_dir.path_join("client.log")
		for directory in [logs_dir, archived_logs_dir, saves_dir, crash_dir, runtime_root.path_join("diagnostics")]:
			DirAccess.make_dir_recursive_absolute(directory)
		runtime_warning = "运行数据目录不可写，已降级到恢复目录：%s（原目录：%s）" % [runtime_root, requested_root]
		recovery_log_path = logs_dir.path_join("client-recovery.log")
		push_error(runtime_warning)
	_archive_previous_client_logs()


func _configure_runtime_identity() -> void:
	var crypto := Crypto.new()
	session_id = crypto.generate_random_bytes(16).hex_encode()
	shutdown_token = crypto.generate_random_bytes(24).hex_encode()
	build_version = str(ProjectSettings.get_setting("application/config/version", "dev"))
	_load_diagnostic_settings()
	if not OS.has_feature("editor"):
		var build_info_path := OS.get_executable_path().get_base_dir().path_join("build-info.json")
		if FileAccess.file_exists(build_info_path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(build_info_path))
			if parsed is Dictionary:
				build_info = parsed
				build_version = str(parsed.get("version", build_version))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--log-level="):
			var requested_level := argument.trim_prefix("--log-level=").to_upper()
			if LOG_LEVELS.has(requested_level):
				log_level = requested_level


func _log_event(level: String, event: String, message: String, fields := {}) -> void:
	level = level.to_upper()
	if not LOG_LEVEL_RANK.has(level):
		level = "INFO"
	if int(LOG_LEVEL_RANK[level]) < int(LOG_LEVEL_RANK.get(log_level, 1)):
		return
	var parts: Array[String] = [
		"timestamp=%sZ" % Time.get_datetime_string_from_system(true, false),
		"level=%s" % level,
		"component=client",
		"event=%s" % event,
		"session=%s" % JSON.stringify(session_id),
		"version=%s" % JSON.stringify(build_version),
		"message=%s" % JSON.stringify(_redact_log_text(message)),
	]
	if fields is Dictionary:
		var keys: Array = fields.keys()
		keys.sort()
		for key in keys:
			parts.append("%s=%s" % [str(key), JSON.stringify(_redact_log_field(str(key), fields[key]))])
	var line := " ".join(parts)
	print(line)
	_write_client_log(line)


func _redact_log_field(key: String, value: Variant) -> String:
	var lower_key := key.to_lower()
	for sensitive_key in ["token", "password", "secret", "authorization", "cookie", "request_body", "response_body", "player_name", "query"]:
		if lower_key.contains(sensitive_key):
			return "[REDACTED]"
	var text := _redact_log_text(str(value))
	if lower_key.contains("path") or lower_key in ["data", "saves", "crash_dir"]:
		if runtime_root != "":
			text = text.replace(runtime_root, "<runtime>")
		var install_dir := OS.get_executable_path().get_base_dir()
		if install_dir != "":
			text = text.replace(install_dir, "<app>")
	return text


func _redact_log_text(value: String) -> String:
	var text := value.replace("\r", "\\r").replace("\n", "\\n")
	var credential_pattern := RegEx.new()
	if credential_pattern.compile("(?i)(token|password|secret|authorization|cookie)=([^\\s&]+)") == OK:
		text = credential_pattern.sub(text, "$1=[REDACTED]", true)
	var url_pattern := RegEx.new()
	if url_pattern.compile("(https?://[^\\s?]+)\\?[^\\s]+") == OK:
		text = url_pattern.sub(text, "$1", true)
	return text


func _append_recovery_log(line: String) -> void:
	var recovery_file := FileAccess.open(recovery_log_path, FileAccess.READ_WRITE)
	if recovery_file == null:
		recovery_file = FileAccess.open(recovery_log_path, FileAccess.WRITE)
	if recovery_file == null:
		push_error("Could not write fallback client diagnostics: %s" % recovery_log_path)
		return
	recovery_file.seek_end()
	recovery_file.store_line(line)


func _write_client_log(line: String) -> void:
	var encoded_size := line.to_utf8_buffer().size() + 1
	if _file_size(client_log_path) + encoded_size > LOG_MAX_MIB * 1024 * 1024:
		_rotate_client_log()
	var client_file := FileAccess.open(client_log_path, FileAccess.READ_WRITE)
	if client_file == null:
		client_file = FileAccess.open(client_log_path, FileAccess.WRITE)
	if client_file == null:
		if not client_log_failure_reported:
			client_log_failure_reported = true
			runtime_warning = "客户端日志文件不可写：%s。诊断信息将仅输出到控制台。" % client_log_path
			push_error(runtime_warning)
		if recovery_log_path != "":
			_append_recovery_log(line)
		return
	client_file.seek_end()
	client_file.store_line(line)


func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file != null else 0


func _rotate_client_log() -> void:
	var timestamp := Time.get_datetime_string_from_system(true, false).replace("-", "").replace(":", "")
	var target_path := archived_logs_dir.path_join("client-%sZ.log" % timestamp)
	var suffix := 1
	while FileAccess.file_exists(target_path):
		target_path = archived_logs_dir.path_join("client-%sZ-%d.log" % [timestamp, suffix])
		suffix += 1
	var rotate_error := DirAccess.rename_absolute(client_log_path, target_path)
	if rotate_error != OK:
		push_error("Could not rotate client log: %s" % client_log_path)
		return
	_prune_log_archives("client-")


func _prune_log_archives(prefix: String) -> void:
	var archive_directory := DirAccess.open(archived_logs_dir)
	if archive_directory == null:
		return
	var archives: Array[String] = []
	for file_name in archive_directory.get_files():
		if file_name.begins_with(prefix) and file_name.ends_with(".log"):
			archives.append(file_name)
	archives.sort()
	while archives.size() > LOG_BACKUPS:
		DirAccess.remove_absolute(archived_logs_dir.path_join(archives.pop_front()))


func _load_diagnostic_settings() -> void:
	var config := ConfigFile.new()
	if config.load(runtime_root.path_join("settings.cfg")) == OK:
		var configured_level := str(config.get_value("diagnostics", "log_level", "INFO")).to_upper()
		if LOG_LEVELS.has(configured_level):
			log_level = configured_level


func _save_diagnostic_settings() -> void:
	var config := ConfigFile.new()
	var settings_path := runtime_root.path_join("settings.cfg")
	config.load(settings_path)
	config.set_value("diagnostics", "log_level", log_level)
	var save_error := config.save(settings_path)
	if save_error != OK:
		_log_event("ERROR", "settings_save_failed", "could not save diagnostic settings", {"error": save_error, "path": settings_path})


func _initialize_crash_tracking() -> void:
	session_marker_path = crash_dir.path_join("client-running.json")
	if FileAccess.file_exists(session_marker_path):
		var timestamp := Time.get_datetime_string_from_system(true, false).replace("-", "").replace(":", "")
		var unclean_path := crash_dir.path_join("client-unclean-exit-%sZ.json" % timestamp)
		var previous_marker := FileAccess.get_file_as_string(session_marker_path)
		var previous_data = JSON.parse_string(previous_marker)
		if not previous_data is Dictionary:
			previous_data = {"raw_marker": _redact_log_text(previous_marker)}
		previous_data["detected_at_utc"] = "%sZ" % Time.get_datetime_string_from_system(true, false)
		previous_data["reason"] = "The previous client session did not complete normal shutdown."
		var report := FileAccess.open(unclean_path, FileAccess.WRITE)
		if report != null:
			report.store_string(JSON.stringify(previous_data, "  "))
		_log_event("ERROR", "previous_unclean_exit", "previous client session ended unexpectedly", {"file": unclean_path.get_file()})
	var marker := FileAccess.open(session_marker_path, FileAccess.WRITE)
	if marker == null:
		_log_event("ERROR", "crash_marker_failed", "could not create client crash marker", {"path": session_marker_path})
		return
	marker.store_string(JSON.stringify({
		"application": "Fantu",
		"session_id": session_id,
		"version": build_version,
		"pid": OS.get_process_id(),
		"started_at_utc": "%sZ" % Time.get_datetime_string_from_system(true, false),
		"operating_system": OS.get_name(),
		"godot": Engine.get_version_info().get("string", "unknown"),
	}, "  "))


func _clear_crash_marker() -> void:
	if session_marker_path != "" and FileAccess.file_exists(session_marker_path):
		var remove_error := DirAccess.remove_absolute(session_marker_path)
		if remove_error != OK:
			push_warning("Could not clear client crash marker: %s" % session_marker_path)


func _archive_previous_client_logs() -> void:
	var log_directory := DirAccess.open(logs_dir)
	if log_directory == null:
		return
	for file_name in log_directory.get_files():
		if file_name in ["client.log", "engine.log"] or not file_name.ends_with(".log"):
			continue
		var archive_prefix := "client" if file_name.begins_with("client") else "engine" if file_name.begins_with("engine") else ""
		if archive_prefix == "":
			continue
		var source_path := logs_dir.path_join(file_name)
		var modified := FileAccess.get_modified_time(source_path)
		var timestamp := Time.get_datetime_string_from_unix_time(modified).replace("-", "").replace(":", "")
		var target_name := "%s-%sZ.log" % [archive_prefix, timestamp]
		var target_path := archived_logs_dir.path_join(target_name)
		var suffix := 1
		if FileAccess.file_exists(target_path):
			while FileAccess.file_exists(archived_logs_dir.path_join("%s-%sZ-%d.log" % [archive_prefix, timestamp, suffix])):
				suffix += 1
			target_path = archived_logs_dir.path_join("%s-%sZ-%d.log" % [archive_prefix, timestamp, suffix])
		var archive_error := DirAccess.rename_absolute(source_path, target_path)
		if archive_error != OK:
			push_warning("Could not archive client log: %s" % source_path)
	_prune_log_archives("client-")
	_prune_log_archives("engine-")


func _open_log_folder() -> void:
	_log_event("INFO", "open_log_folder", "opening log directory")
	var open_error := OS.shell_open(logs_dir)
	if open_error != OK:
		push_error("Could not open the log directory: %s" % logs_dir)


func _export_diagnostics(open_folder := true) -> String:
	_log_event("INFO", "diagnostics_export", "creating diagnostics archive")
	var diagnostics_dir := runtime_root.path_join("diagnostics")
	var mkdir_error := DirAccess.make_dir_recursive_absolute(diagnostics_dir)
	if mkdir_error != OK:
		_log_event("ERROR", "diagnostics_failed", "could not create diagnostics directory", {"error": mkdir_error})
		_show_error("无法创建诊断目录。")
		return ""
	var timestamp := Time.get_datetime_string_from_system(true, false).replace("-", "").replace(":", "")
	var archive_path := diagnostics_dir.path_join("Fantu-Diagnostics-%sZ.zip" % timestamp)
	var packer := ZIPPacker.new()
	var open_error := packer.open(archive_path)
	if open_error != OK:
		_log_event("ERROR", "diagnostics_failed", "could not open diagnostics archive", {"error": open_error})
		_show_error("无法创建诊断压缩包。")
		return ""
	var manifest := {
		"application": "Fantu",
		"generated_at_utc": "%sZ" % Time.get_datetime_string_from_system(true, false),
		"version": build_version,
		"session_id": session_id,
		"operating_system": OS.get_name(),
		"godot": Engine.get_version_info().get("string", "unknown"),
		"portable_mode": portable_mode,
		"log_level": log_level,
		"environment": _diagnostic_environment(),
		"contents": "Logs and environment metadata only; saves and request bodies are excluded.",
	}
	packer.start_file("manifest.json")
	packer.write_file(JSON.stringify(manifest, "  ").to_utf8_buffer())
	packer.close_file()
	packer.start_file("environment.json")
	packer.write_file(JSON.stringify(_diagnostic_environment(), "  ").to_utf8_buffer())
	packer.close_file()
	_add_diagnostic_log(packer, logs_dir.path_join("client.log"), "logs/client.log")
	_add_diagnostic_log(packer, logs_dir.path_join("engine.log"), "logs/engine.log")
	_add_diagnostic_log(packer, logs_dir.path_join("server.log"), "logs/server.log")
	var archive_directory := DirAccess.open(archived_logs_dir)
	if archive_directory != null:
		var archive_names: Array[String] = []
		for file_name in archive_directory.get_files():
			if file_name.ends_with(".log"):
				archive_names.append(file_name)
		archive_names.sort()
		for file_name in archive_names:
			_add_diagnostic_log(packer, archived_logs_dir.path_join(file_name), "logs/archived/" + file_name)
	var crash_directory := DirAccess.open(crash_dir)
	if crash_directory != null:
		var crash_names: Array[String] = []
		for file_name in crash_directory.get_files():
			if file_name.ends_with(".json") or file_name.ends_with(".dmp") or file_name.ends_with(".log"):
				crash_names.append(file_name)
		crash_names.sort()
		while crash_names.size() > LOG_BACKUPS:
			crash_names.pop_front()
		for file_name in crash_names:
			_add_diagnostic_log(packer, crash_dir.path_join(file_name), "crash/" + file_name)
	packer.close()
	_log_event("INFO", "diagnostics_created", "diagnostics archive created", {"file": archive_path.get_file()})
	if open_folder:
		OS.shell_open(diagnostics_dir)
	return archive_path


func _add_diagnostic_log(packer: ZIPPacker, source_path: String, archive_path: String) -> void:
	if not FileAccess.file_exists(source_path):
		return
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		_log_event("WARN", "diagnostics_file_skipped", "could not read diagnostics file", {"file": source_path.get_file()})
		return
	if source.get_length() > DIAGNOSTIC_FILE_MAX_BYTES:
		_log_event("WARN", "diagnostics_file_skipped", "diagnostics file exceeds size limit", {"file": source_path.get_file(), "size": source.get_length()})
		return
	if packer.start_file(archive_path) != OK:
		return
	packer.write_file(source.get_buffer(source.get_length()))
	packer.close_file()


func _diagnostic_environment() -> Dictionary:
	var memory := OS.get_memory_info()
	var screen_size := DisplayServer.screen_get_size()
	var runtime_space := -1
	var runtime_directory := DirAccess.open(runtime_root)
	if runtime_directory != null:
		runtime_space = runtime_directory.get_space_left()
	return {
		"operating_system": OS.get_name(),
		"os_distribution": OS.get_distribution_name(),
		"os_version": OS.get_version(),
		"locale": OS.get_locale(),
		"processor": OS.get_processor_name(),
		"processor_count": OS.get_processor_count(),
		"memory_physical_bytes": memory.get("physical", -1),
		"memory_available_bytes": memory.get("free", -1),
		"screen_width": screen_size.x,
		"screen_height": screen_size.y,
		"screen_dpi": DisplayServer.screen_get_dpi(),
		"graphics_adapter": RenderingServer.get_video_adapter_name(),
		"graphics_vendor": RenderingServer.get_video_adapter_vendor(),
		"graphics_api": RenderingServer.get_video_adapter_api_version(),
		"godot_version": Engine.get_version_info().get("string", "unknown"),
		"build": build_info,
		"runtime_space_available_bytes": runtime_space,
		"portable_mode": portable_mode,
		"server_process_running": bundled_server_pid > 0 and OS.is_process_running(bundled_server_pid),
		"last_server_http_status": last_server_http_status,
		"log_level": log_level,
	}


func _configure_theme() -> void:
	body_font = SystemFont.new()
	body_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	body_font.font_weight = 400
	medium_font = SystemFont.new()
	medium_font.font_names = body_font.font_names
	medium_font.font_weight = 500
	display_font = SystemFont.new()
	display_font.font_names = PackedStringArray(["STZhongsong", "SimSun", "Noto Serif CJK SC"])
	display_font.font_weight = 600
	var app_theme := Theme.new()
	app_theme.default_font = body_font
	app_theme.default_font_size = TYPE_SCALE.body
	app_theme.set_font("font", "Button", medium_font)
	app_theme.set_font("font", "MenuButton", medium_font)
	app_theme.set_font("font", "TabBar", medium_font)
	app_theme.set_color("font_color", "Label", COLORS.ink)
	app_theme.set_color("font_color", "Button", COLORS.ink)
	app_theme.set_color("font_hover_color", "Button", COLORS.ink)
	app_theme.set_color("font_pressed_color", "Button", COLORS.ink)
	app_theme.set_color("font_focus_color", "Button", COLORS.ink)
	app_theme.set_color("font_disabled_color", "Button", Color(COLORS.muted, 0.45))
	app_theme.set_color("font_color", "LineEdit", COLORS.ink)
	app_theme.set_color("font_placeholder_color", "LineEdit", Color(COLORS.muted, 0.62))
	app_theme.set_color("caret_color", "LineEdit", COLORS.accent)
	app_theme.set_color("selection_color", "LineEdit", Color(COLORS.accent, 0.28))
	app_theme.set_stylebox("panel", "TabContainer", _panel_style(Color.TRANSPARENT, 0, 0))
	app_theme.set_stylebox("tab_selected", "TabBar", _tab_style(COLORS.panel_hover, COLORS.accent))
	app_theme.set_stylebox("tab_hovered", "TabBar", _tab_style(COLORS.panel_alt, COLORS.line))
	app_theme.set_stylebox("tab_unselected", "TabBar", _tab_style(Color.TRANSPARENT, Color.TRANSPARENT))
	app_theme.set_color("font_selected_color", "TabBar", COLORS.accent)
	app_theme.set_color("font_hovered_color", "TabBar", COLORS.ink)
	app_theme.set_color("font_unselected_color", "TabBar", COLORS.muted)
	app_theme.set_stylebox("scroll", "VScrollBar", _panel_style(Color.TRANSPARENT, 0, 0, Color.TRANSPARENT, 0, 0))
	app_theme.set_stylebox("grabber", "VScrollBar", _panel_style(Color(COLORS.line, 0.82), 0, 4, Color.TRANSPARENT, 0, 0))
	app_theme.set_stylebox("grabber_highlight", "VScrollBar", _panel_style(COLORS.accent_pressed, 0, 4, Color.TRANSPARENT, 0, 0))
	app_theme.set_stylebox("grabber_pressed", "VScrollBar", _panel_style(COLORS.accent, 0, 4, Color.TRANSPARENT, 0, 0))
	app_theme.set_constant("minimum_grab_thickness", "VScrollBar", 28)
	app_theme.set_stylebox("panel", "TooltipPanel", _panel_style(COLORS.panel_alt, 1, 5, COLORS.line, 10, 8))
	app_theme.set_color("font_color", "TooltipLabel", COLORS.ink)
	app_theme.set_font_size("font_size", "TooltipLabel", TYPE_SCALE.meta)
	theme = app_theme


func _build_interface() -> void:
	var background := TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.46, 1.0])
	gradient.colors = PackedColorArray([COLORS.bg_lift, COLORS.bg, Color("060806")])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 1024
	gradient_texture.height = 1024
	gradient_texture.fill_from = Vector2(0.0, 0.0)
	gradient_texture.fill_to = Vector2(1.0, 1.0)
	background.texture = gradient_texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var top_rule := ColorRect.new()
	top_rule.color = Color(COLORS.accent, 0.45)
	top_rule.custom_minimum_size.y = 2
	top_rule.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_rule)

	game_layer = VBoxContainer.new()
	game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
	game_layer.add_theme_constant_override("separation", 10)
	add_child(game_layer)
	_build_header()
	_build_dashboard()
	_build_footer()
	game_layer.hide()

	_build_start_layer()
	_build_journal_layer()
	_build_confirmation_layer()
	_build_settings_layer()
	_build_causal_layer()
	_build_ending_layer()
	presentation_director = PresentationDirectorScript.new()
	add_child(presentation_director)
	presentation_director.configure(display_font, medium_font)


func _build_header() -> void:
	var header := PanelContainer.new()
	var header_style := _panel_style(Color("090d0ac7"), 0, 0, Color.TRANSPARENT, 18, 6)
	header_style.border_width_bottom = 1
	header_style.border_color = Color(COLORS.accent, 0.22)
	header.add_theme_stylebox_override("panel", header_style)
	header.custom_minimum_size.y = 56
	game_layer.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	header.add_child(row)

	var brand := Label.new()
	brand.text = "凡途"
	brand.add_theme_font_override("font", display_font)
	brand.add_theme_font_size_override("font_size", 25)
	brand.add_theme_color_override("font_color", COLORS.accent)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(brand)

	day_label = _hud_label(row, COLORS.accent)
	place_label = _hud_label(row, COLORS.ink)
	phase_label = _hud_label(row, COLORS.muted)
	timing_label = Label.new()
	timing_label.hide()
	header.add_child(timing_label)
	var journal_button := _utility_button("卷宗", _open_journal)
	journal_button.custom_minimum_size = Vector2(64, 34)
	row.add_child(journal_button)
	sound_button = _utility_button("设置", _open_audio_settings)
	sound_button.custom_minimum_size = Vector2(64, 34)
	row.add_child(sound_button)
	var save_button := _utility_button("留存", _save_game)
	save_button.custom_minimum_size = Vector2(64, 34)
	row.add_child(save_button)
	var return_button := _utility_button("卷首", _return_to_start)
	return_button.custom_minimum_size = Vector2(64, 34)
	row.add_child(return_button)


func _build_dashboard() -> void:
	var workspace := Control.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_layer.add_child(workspace)

	var world_column := VBoxContainer.new()
	world_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world_column.add_theme_constant_override("separation", 8)
	workspace.add_child(world_column)
	_build_world_stage(world_column)

	action_dock_host = Control.new()
	action_dock_host.anchor_left = 0.025
	action_dock_host.anchor_right = 0.62
	action_dock_host.anchor_top = 0.50
	action_dock_host.anchor_bottom = 0.985
	action_dock_host.clip_contents = true
	# Keep the decision layer on its own canvas so focused content can never
	# enlarge either the dashboard workspace or the root interface.
	action_canvas = CanvasLayer.new()
	action_canvas.layer = 1
	add_child(action_canvas)
	action_canvas.add_child(action_dock_host)

	action_dock = PanelContainer.new()
	action_dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dock_style := _panel_style(Color("0b100ddf"), 0, 2, Color.TRANSPARENT, 22, 16)
	dock_style.border_width_left = 2
	dock_style.border_color = Color(COLORS.accent, 0.68)
	action_dock.add_theme_stylebox_override("panel", dock_style)
	action_dock_host.add_child(action_dock)
	var action_content_host := Control.new()
	action_content_host.clip_contents = true
	action_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_dock.add_child(action_content_host)
	var decision_column := VBoxContainer.new()
	decision_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	decision_column.grow_vertical = Control.GROW_DIRECTION_END
	decision_column.add_theme_constant_override("separation", 7)
	action_content_host.add_child(decision_column)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	decision_column.add_child(title_row)
	action_dock_title = Label.new()
	action_dock_title.text = "眼前"
	action_dock_title.add_theme_font_override("font", display_font)
	action_dock_title.add_theme_font_size_override("font_size", 22)
	action_dock_title.add_theme_color_override("font_color", COLORS.accent)
	action_dock_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(action_dock_title)
	objective_label = Label.new()
	objective_label.text = "风声未定，先看清眼前的人和路。"
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.max_lines_visible = 2
	objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objective_label.add_theme_font_size_override("font_size", TYPE_SCALE.meta)
	objective_label.add_theme_constant_override("line_spacing", 3)
	objective_label.add_theme_color_override("font_color", COLORS.muted)
	decision_column.add_child(objective_label)
	location_detail_box = VBoxContainer.new()
	location_detail_box.add_theme_constant_override("separation", 2)
	decision_column.add_child(location_detail_box)
	stage_people_box = HFlowContainer.new()
	stage_people_box.add_theme_constant_override("h_separation", 7)
	stage_people_box.add_theme_constant_override("v_separation", 5)
	decision_column.add_child(stage_people_box)
	var rule := HSeparator.new()
	rule.modulate = Color(COLORS.accent, 0.24)
	decision_column.add_child(rule)
	overview_actions_box = VBoxContainer.new()
	overview_actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview_actions_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overview_actions_box.add_theme_constant_override("separation", 5)
	decision_column.add_child(overview_actions_box)

	actor_focus_workspace = HBoxContainer.new()
	actor_focus_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actor_focus_workspace.add_theme_constant_override("separation", 14)
	decision_column.add_child(actor_focus_workspace)
	var message_panel := PanelContainer.new()
	message_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_panel.size_flags_stretch_ratio = 0.38
	message_panel.add_theme_stylebox_override("panel", _panel_style(Color(COLORS.panel_alt, 0.24), 0, 1, Color.TRANSPARENT, 8, 8))
	actor_focus_workspace.add_child(message_panel)
	actor_focus_message_list = VBoxContainer.new()
	actor_focus_message_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actor_focus_message_list.add_theme_constant_override("separation", 6)
	message_panel.add_child(actor_focus_message_list)
	actor_focus_detail_scroll = ScrollContainer.new()
	actor_focus_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actor_focus_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actor_focus_detail_scroll.size_flags_stretch_ratio = 0.62
	actor_focus_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	actor_focus_workspace.add_child(actor_focus_detail_scroll)
	actor_focus_detail_box = VBoxContainer.new()
	actor_focus_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actor_focus_detail_box.add_theme_constant_override("separation", 9)
	actor_focus_detail_scroll.add_child(actor_focus_detail_box)

	legacy_action_scroll = ScrollContainer.new()
	legacy_action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	legacy_action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	decision_column.add_child(legacy_action_scroll)
	actions_box = VBoxContainer.new()
	actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_box.add_theme_constant_override("separation", 7)
	legacy_action_scroll.add_child(actions_box)

	actor_focus_footer = HBoxContainer.new()
	actor_focus_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actor_focus_footer.add_theme_constant_override("separation", 12)
	decision_column.add_child(actor_focus_footer)
	overview_actions_box.hide()
	actor_focus_workspace.hide()
	legacy_action_scroll.hide()
	actor_focus_footer.hide()
	action_dock.hide()


func _build_world_stage(parent: VBoxContainer) -> void:
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	parent.add_child(mode_row)
	var heading := Label.new()
	heading.text = "黑风谷山川"
	heading.add_theme_font_override("font", display_font)
	heading.add_theme_font_size_override("font_size", TYPE_SCALE.section)
	heading.add_theme_color_override("font_color", COLORS.accent)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_child(heading)
	map_mode_button = _mode_button("地图", _set_visual_mode.bind("map"))
	map_mode_button.custom_minimum_size = Vector2(82, 36)
	mode_row.add_child(map_mode_button)
	location_mode_button = _mode_button("当前地点", _set_visual_mode.bind("location"))
	location_mode_button.custom_minimum_size = Vector2(104, 36)
	mode_row.add_child(location_mode_button)

	var stage_frame := PanelContainer.new()
	stage_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_frame.size_flags_stretch_ratio = 1.0
	stage_frame.custom_minimum_size.y = 560
	stage_frame.add_theme_stylebox_override("panel", _panel_style(Color(COLORS.panel, 0.66), 0, 2, Color.TRANSPARENT, 8, 8))
	parent.add_child(stage_frame)
	visual_stack = Control.new()
	visual_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	visual_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_frame.add_child(visual_stack)

	map_panel = HBoxContainer.new()
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_panel.add_theme_constant_override("separation", 0)
	visual_stack.add_child(map_panel)
	world_map_view = WorldMapViewScript.new()
	world_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	world_map_view.size_flags_stretch_ratio = 1.0
	world_map_view.location_selected.connect(_on_map_location_selected)
	world_map_view.travel_day_changed.connect(_on_travel_day_changed)
	map_panel.add_child(world_map_view)
	var map_detail_frame := PanelContainer.new()
	map_detail_frame.custom_minimum_size.x = 310
	map_detail_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var map_detail_style := _panel_style(Color("08100be8"), 0, 0, Color.TRANSPARENT, 18, 18)
	map_detail_style.border_width_left = 1
	map_detail_style.border_color = Color(COLORS.accent, 0.42)
	map_detail_frame.add_theme_stylebox_override("panel", map_detail_style)
	map_panel.add_child(map_detail_frame)
	map_detail_box = VBoxContainer.new()
	map_detail_box.custom_minimum_size = Vector2(274, 88)
	map_detail_box.add_theme_constant_override("separation", 9)
	map_detail_frame.add_child(map_detail_box)

	location_panel = VBoxContainer.new()
	location_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	location_panel.add_theme_constant_override("separation", 8)
	visual_stack.add_child(location_panel)
	var stage_canvas := Control.new()
	stage_canvas.custom_minimum_size = Vector2(640, 320)
	stage_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_canvas.clip_contents = true
	location_panel.add_child(stage_canvas)
	location_stage = LocationStageScript.new()
	location_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_canvas.add_child(location_stage)
	actor_portrait_frame = PanelContainer.new()
	actor_portrait_frame.anchor_left = 0.56
	actor_portrait_frame.anchor_right = 0.965
	actor_portrait_frame.anchor_top = 0.005
	actor_portrait_frame.anchor_bottom = 1.02
	actor_portrait_frame.add_theme_stylebox_override("panel", _panel_style(Color("080b0966"), 0, 0, Color.TRANSPARENT, 0, 0))
	actor_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_canvas.add_child(actor_portrait_frame)
	var portrait_stack := Control.new()
	portrait_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor_portrait_frame.add_child(portrait_stack)
	actor_portrait = TextureRect.new()
	actor_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	actor_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	actor_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	actor_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait_shader := Shader.new()
	portrait_shader.code = "shader_type canvas_item; void fragment(){ vec4 c = texture(TEXTURE, UV); float l = smoothstep(0.0, 0.28, UV.x); float r = 1.0 - smoothstep(0.92, 1.0, UV.x); float b = 1.0 - smoothstep(0.94, 1.0, UV.y); COLOR = vec4(c.rgb, c.a * l * r * b); }"
	var portrait_material := ShaderMaterial.new()
	portrait_material.shader = portrait_shader
	actor_portrait.material = portrait_material
	portrait_stack.add_child(actor_portrait)
	var portrait_caption := PanelContainer.new()
	portrait_caption.anchor_left = 0.18
	portrait_caption.anchor_right = 0.94
	portrait_caption.anchor_top = 0.79
	portrait_caption.anchor_bottom = 0.96
	portrait_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption_style := _panel_style(Color("070b08a6"), 0, 0, Color.TRANSPARENT, 14, 8)
	caption_style.border_width_left = 1
	caption_style.border_color = Color(COLORS.accent, 0.48)
	portrait_caption.add_theme_stylebox_override("panel", caption_style)
	portrait_stack.add_child(portrait_caption)
	var portrait_caption_content := VBoxContainer.new()
	portrait_caption_content.add_theme_constant_override("separation", 2)
	portrait_caption.add_child(portrait_caption_content)
	actor_portrait_name = _text(portrait_caption_content, "", false, 17)
	actor_portrait_name.add_theme_color_override("font_color", COLORS.accent)
	actor_portrait_meta = _text(portrait_caption_content, "", true, 12)
	actor_portrait_frame.hide()
	_set_visual_mode("map")


func _build_footer() -> void:
	footer_label = Label.new()
	footer_label.text = ""
	footer_label.add_theme_color_override("font_color", COLORS.muted)
	footer_label.add_theme_font_override("font", medium_font)
	footer_label.add_theme_font_size_override("font_size", TYPE_SCALE.meta)
	footer_label.custom_minimum_size.y = 20
	game_layer.add_child(footer_label)


func _build_start_layer() -> void:
	start_layer = Control.new()
	start_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(start_layer)
	var scene := TextureRect.new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.texture = StartBackgroundTexture
	scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_layer.add_child(scene)
	var shade := ColorRect.new()
	shade.color = Color("0305048f")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_layer.add_child(shade)
	var center := CenterContainer.new()
	center.anchor_left = 0.48
	center.anchor_right = 0.94
	center.anchor_top = 0.04
	center.anchor_bottom = 0.98
	start_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 520)
	var start_style := _panel_style(Color("070a0875"), 0, 0, Color.TRANSPARENT, 38, 34)
	start_style.border_width_left = 2
	start_style.border_color = Color(COLORS.accent, 0.46)
	card.add_theme_stylebox_override("panel", start_style)
	center.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	card.add_child(content)

	var eyebrow := Label.new()
	eyebrow.text = "黑风谷异动　·　三十日局势"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	eyebrow.add_theme_color_override("font_color", COLORS.accent)
	eyebrow.add_theme_font_override("font", medium_font)
	eyebrow.add_theme_font_size_override("font_size", TYPE_SCALE.meta)
	content.add_child(eyebrow)
	var title := Label.new()
	title.text = "凡 途"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_override("font", display_font)
	title.add_theme_font_size_override("font_size", 68)
	title.add_theme_color_override("font_color", COLORS.ink)
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "三十日内，青髓芝的归属将被决定。\n你未必亲手夺取它，也能让一条消息改写别人的去向。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle.add_theme_color_override("font_color", COLORS.muted)
	subtitle.add_theme_font_size_override("font_size", TYPE_SCALE.body)
	subtitle.add_theme_constant_override("line_spacing", 7)
	content.add_child(subtitle)
	var divider := HSeparator.new()
	divider.modulate = Color(COLORS.accent, 0.48)
	content.add_child(divider)

	name_input = LineEdit.new()
	var name_prompt := _text(content, "你以何名入谷", true, 13)
	name_prompt.add_theme_color_override("font_color", Color(COLORS.accent, 0.84))
	name_input.placeholder_text = "留下名号"
	name_input.text = "无名修士"
	name_input.add_theme_font_size_override("font_size", TYPE_SCALE.metric)
	name_input.custom_minimum_size.y = 52
	var name_style := _input_style(Color("111812c2"), Color(COLORS.line, 0.58))
	name_style.set_corner_radius_all(1)
	name_input.add_theme_stylebox_override("normal", name_style)
	var name_focus_style := _input_style(Color("151d17dc"), COLORS.accent)
	name_focus_style.set_corner_radius_all(1)
	name_input.add_theme_stylebox_override("focus", name_focus_style)
	name_input.add_theme_constant_override("minimum_character_width", 8)
	content.add_child(name_input)
	var begin_button := _ornate_button("从白石坊市入局", _new_game)
	begin_button.custom_minimum_size.y = 66
	content.add_child(begin_button)
	var continue_button := _utility_button("翻开旧卷", _load_game)
	continue_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(continue_button)
	retry_button = _action_button("重新连接本地服务", _retry_connection)
	retry_button.hide()
	content.add_child(retry_button)
	connection_label = Label.new()
	connection_label.text = ""
	connection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	connection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	connection_label.add_theme_color_override("font_color", COLORS.muted)
	connection_label.add_theme_font_size_override("font_size", TYPE_SCALE.meta)
	connection_label.add_theme_constant_override("line_spacing", 4)
	content.add_child(connection_label)


func _build_journal_layer() -> void:
	journal_layer = Control.new()
	journal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	journal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	journal_layer.hide()
	add_child(journal_layer)
	var shade := ColorRect.new()
	shade.color = Color("030504b8")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	journal_layer.add_child(shade)
	var dismiss_area := Button.new()
	dismiss_area.flat = true
	dismiss_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dismiss_area.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	dismiss_area.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	dismiss_area.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	dismiss_area.pressed.connect(_close_journal)
	journal_layer.add_child(dismiss_area)
	journal_panel = PanelContainer.new()
	journal_panel.anchor_left = 0.57
	journal_panel.anchor_right = 0.992
	journal_panel.anchor_top = 0.026
	journal_panel.anchor_bottom = 0.974
	journal_panel.add_theme_stylebox_override("panel", _panel_style(Color("101612f5"), 1, 3, Color(COLORS.accent, 0.44), 24, 20))
	journal_layer.add_child(journal_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	journal_panel.add_child(outer)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	outer.add_child(title_row)
	var title := Label.new()
	title.text = "随身卷宗"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", display_font)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLORS.accent)
	title_row.add_child(title)
	var close_button := _utility_button("收起", _close_journal)
	close_button.custom_minimum_size = Vector2(72, 38)
	title_row.add_child(close_button)
	player_summary_label = Label.new()
	player_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_summary_label.add_theme_font_override("font", medium_font)
	player_summary_label.add_theme_font_size_override("font_size", TYPE_SCALE.body)
	player_summary_label.add_theme_constant_override("line_spacing", 4)
	player_summary_label.add_theme_color_override("font_color", COLORS.ink)
	outer.add_child(player_summary_label)
	player_resources_box = HFlowContainer.new()
	player_resources_box.add_theme_constant_override("h_separation", 7)
	player_resources_box.add_theme_constant_override("v_separation", 7)
	outer.add_child(player_resources_box)
	var rule := HSeparator.new()
	rule.modulate = Color(COLORS.accent, 0.35)
	outer.add_child(rule)
	_build_reference_tabs(outer)


func _build_confirmation_layer() -> void:
	confirmation_layer = Control.new()
	confirmation_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	confirmation_layer.hide()
	add_child(confirmation_layer)
	var shade := ColorRect.new()
	shade.color = Color("0507069c")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation_layer.add_child(shade)
	var card := PanelContainer.new()
	card.anchor_left = 0.055
	card.anchor_right = 0.72
	card.anchor_top = 0.53
	card.anchor_bottom = 0.94
	var confirmation_style := _panel_style(Color("0b100df4"), 0, 2, Color.TRANSPARENT, 30, 22)
	confirmation_style.border_width_left = 3
	confirmation_style.border_color = COLORS.accent
	card.add_theme_stylebox_override("panel", confirmation_style)
	confirmation_layer.add_child(card)
	confirmation_box = VBoxContainer.new()
	confirmation_box.add_theme_constant_override("separation", 11)
	card.add_child(confirmation_box)


func _build_settings_layer() -> void:
	settings_layer = Control.new()
	settings_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_layer.hide()
	add_child(settings_layer)
	var shade := ColorRect.new()
	shade.color = Color("050706dc")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(500, 610)
	card.add_theme_stylebox_override("panel", _panel_style(COLORS.panel, 1, 14, COLORS.accent_pressed, 28, 24))
	center.add_child(card)
	settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 13)
	card.add_child(settings_box)
	_text(settings_box, "体验设置", false, 25)
	_text(settings_box, "声音与动态效果只影响呈现，不会改变推演结果。", true, 14)
	_audio_slider(settings_box, "主音量", "Master", 82.0)
	_audio_slider(settings_box, "环境", "Ambient", 64.0)
	_audio_slider(settings_box, "事件", "Event", 78.0)
	_audio_slider(settings_box, "界面", "UI", 70.0)
	motion_button = _action_button("动态效果 · 开启", _toggle_motion)
	settings_box.add_child(motion_button)
	settings_box.add_child(_action_button("全部静音", _toggle_sound))
	log_level_button = _action_button("日志等级 · %s" % log_level, _cycle_log_level)
	log_level_button.tooltip_text = "DEBUG 记录更多诊断信息；INFO 适合正式版。服务端会在下次启动时应用新等级。"
	settings_box.add_child(log_level_button)
	settings_box.add_child(_action_button("打开日志目录", _open_log_folder))
	settings_box.add_child(_action_button("导出诊断包", _export_diagnostics))
	settings_box.add_child(_button("返回游戏", _close_audio_settings, false))


func _cycle_log_level() -> void:
	var level_index := LOG_LEVELS.find(log_level)
	log_level = LOG_LEVELS[(level_index + 1) % LOG_LEVELS.size()]
	if log_level_button:
		log_level_button.text = "日志等级 · %s" % log_level
	_save_diagnostic_settings()
	_log_event(log_level, "log_level_changed", "client log level changed", {"new_level": log_level, "server_effect": "next_start"})


func _audio_slider(parent: VBoxContainer, label_text: String, bus_name: String, initial_value: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 78
	label.add_theme_font_override("font", medium_font)
	label.add_theme_color_override("font_color", COLORS.ink)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 32
	slider.value_changed.connect(_set_bus_volume.bind(bus_name))
	row.add_child(slider)
	_set_bus_volume(initial_value, bus_name)


func _build_ending_layer() -> void:
	ending_layer = Control.new()
	ending_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	ending_layer.hide()
	add_child(ending_layer)
	ending_background = TextureRect.new()
	ending_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ending_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ending_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ending_layer.add_child(ending_background)
	var shade := ColorRect.new()
	shade.color = Color("030504a8")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_layer.add_child(shade)
	ending_portrait = TextureRect.new()
	ending_portrait.anchor_left = 0.015
	ending_portrait.anchor_right = 0.42
	ending_portrait.anchor_top = 0.04
	ending_portrait.anchor_bottom = 1.0
	ending_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ending_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ending_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ending_layer.add_child(ending_portrait)
	ending_seal = TextureRect.new()
	ending_seal.anchor_left = 0.775
	ending_seal.anchor_right = 0.925
	ending_seal.anchor_top = 0.085
	ending_seal.anchor_bottom = 0.31
	ending_seal.texture = CausalSealTexture
	ending_seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ending_seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ending_seal.modulate = Color(1, 1, 1, 0.17)
	ending_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ending_layer.add_child(ending_seal)
	ending_box = VBoxContainer.new()
	ending_box.anchor_left = 0.445
	ending_box.anchor_right = 0.925
	ending_box.anchor_top = 0.13
	ending_box.anchor_bottom = 0.91
	ending_box.add_theme_constant_override("separation", 14)
	ending_layer.add_child(ending_box)


func _build_causal_layer() -> void:
	causal_layer = Control.new()
	causal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	causal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	causal_layer.hide()
	add_child(causal_layer)
	causal_background = TextureRect.new()
	causal_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	causal_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	causal_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	causal_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	causal_layer.add_child(causal_background)
	var shade := ColorRect.new()
	shade.color = Color("030504a8")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	causal_layer.add_child(shade)

	causal_portrait = TextureRect.new()
	causal_portrait.anchor_left = 0.015
	causal_portrait.anchor_right = 0.34
	causal_portrait.anchor_top = 0.035
	causal_portrait.anchor_bottom = 1.0
	causal_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	causal_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	causal_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	causal_layer.add_child(causal_portrait)

	var content := VBoxContainer.new()
	content.anchor_left = 0.39
	content.anchor_right = 0.94
	content.anchor_top = 0.13
	content.anchor_bottom = 0.94
	content.add_theme_constant_override("separation", 13)
	causal_layer.add_child(content)
	causal_actor_meta = _text(content, "一念入局", true, 14)
	causal_actor_meta.add_theme_color_override("font_color", COLORS.accent)
	causal_message = _text(content, "你送出的消息改变了一个人的判断", false, 27)
	causal_message.add_theme_font_override("font", display_font)
	causal_message.add_theme_color_override("font_color", Color("ead6a8"))
	causal_message.add_theme_constant_override("line_spacing", 6)

	var timeline := VBoxContainer.new()
	timeline.custom_minimum_size.y = 300
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.add_theme_constant_override("separation", 7)
	content.add_child(timeline)
	var before_heading := _text(timeline, "改写之前", true, TYPE_SCALE.meta)
	before_heading.add_theme_color_override("font_color", COLORS.muted)
	causal_original = _text(timeline, "原本的安排", false, 16)
	var arrow := TextureRect.new()
	arrow.custom_minimum_size = Vector2(0, 38)
	arrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arrow.texture = TimelineArrowTexture
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.modulate = Color(1, 1, 1, 0.78)
	timeline.add_child(arrow)
	var now_row := HBoxContainer.new()
	now_row.custom_minimum_size.y = 126
	now_row.add_theme_constant_override("separation", 16)
	timeline.add_child(now_row)
	var now_stack := VBoxContainer.new()
	now_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	now_stack.add_theme_constant_override("separation", 7)
	now_row.add_child(now_stack)
	var now_heading := _text(now_stack, "现在", true, TYPE_SCALE.meta)
	now_heading.add_theme_color_override("font_color", COLORS.accent)
	causal_now = _text(now_stack, "新的安排", false, 18)
	causal_now.add_theme_color_override("font_color", COLORS.ink)
	var seal := TextureRect.new()
	seal.custom_minimum_size = Vector2(128, 116)
	seal.texture = CausalSealTexture
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seal.modulate = Color(1, 1, 1, 0.48)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	now_row.add_child(seal)

	causal_day = _text(content, "已有决断", true, 15)
	causal_day.add_theme_color_override("font_color", COLORS.accent)
	var continue_button := _ornate_button("记下这次变化", _dismiss_causal)
	continue_button.custom_minimum_size = Vector2(380, 68)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	content.add_child(continue_button)


func _header_value(parent: Container, caption: String) -> Label:
	var group := VBoxContainer.new()
	var small := Label.new()
	small.text = caption
	small.add_theme_font_override("font", medium_font)
	small.add_theme_font_size_override("font_size", TYPE_SCALE.meta)
	small.add_theme_color_override("font_color", COLORS.muted)
	group.add_child(small)
	var value := Label.new()
	value.text = "—"
	value.add_theme_font_override("font", medium_font)
	value.add_theme_font_size_override("font_size", TYPE_SCALE.metric)
	value.add_theme_color_override("font_color", COLORS.ink)
	group.add_child(value)
	parent.add_child(group)
	return value


func _hud_label(parent: Container, color: Color) -> Label:
	var value := Label.new()
	value.text = "—"
	value.add_theme_font_override("font", medium_font)
	value.add_theme_font_size_override("font_size", TYPE_SCALE.compact)
	value.add_theme_color_override("font_color", color)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(value)
	return value


func _zone(parent: VBoxContainer, title_text: String, ratio: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.add_theme_stylebox_override("panel", _panel_style(Color(COLORS.panel, 0.62), 0, 2, Color.TRANSPARENT, 16, 14))
	parent.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_override("font", display_font)
	title.add_theme_font_size_override("font_size", TYPE_SCALE.section)
	title.add_theme_color_override("font_color", COLORS.accent)
	outer.add_child(title)
	var rule := HSeparator.new()
	rule.modulate = Color(COLORS.accent, 0.35)
	outer.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	return box


func _build_reference_tabs(parent: VBoxContainer) -> void:
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 2)
	parent.add_child(navigation)
	journal_echo_button = _journal_tab_button("回响", 0)
	journal_clues_button = _journal_tab_button("线索", 1)
	journal_people_button = _journal_tab_button("人物", 2)
	journal_travel_button = _journal_tab_button("行装", 3)
	for button in [journal_echo_button, journal_clues_button, journal_people_button, journal_travel_button]:
		navigation.add_child(button)
	journal_tabs = TabContainer.new()
	journal_tabs.tabs_visible = false
	journal_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(journal_tabs)
	scene_box = _reference_tab(journal_tabs, "回响")
	clues_box = _reference_tab(journal_tabs, "线索")
	people_box = _reference_tab(journal_tabs, "人物")
	travel_box = _reference_tab(journal_tabs, "行装")
	_refresh_journal_tab_styles()


func _journal_tab_button(label_text: String, index: int) -> Button:
	var button := _utility_button(label_text, _select_journal_tab.bind(index))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 38)
	button.add_theme_font_size_override("font_size", TYPE_SCALE.compact)
	return button


func _select_journal_tab(index: int) -> void:
	if not journal_tabs:
		return
	journal_tabs.current_tab = clampi(index, 0, journal_tabs.get_tab_count() - 1)
	_refresh_journal_tab_styles()


func _refresh_journal_tab_styles() -> void:
	if not journal_tabs:
		return
	var buttons: Array[Button] = [journal_echo_button, journal_clues_button, journal_people_button, journal_travel_button]
	for index in buttons.size():
		var button := buttons[index]
		if not button:
			continue
		button.text = journal_tab_labels[index]
		var active := journal_tabs.current_tab == index
		var status_color := journal_tab_colors[index]
		button.add_theme_color_override("font_color", COLORS.accent if active and status_color == COLORS.muted else status_color)
		button.add_theme_color_override("font_hover_color", COLORS.ink)
		var normal := _panel_style(Color.TRANSPARENT, 0, 0, Color.TRANSPARENT, 8, 7)
		normal.border_width_bottom = 2 if active else 0
		normal.border_color = COLORS.accent
		button.add_theme_stylebox_override("normal", normal)


func _render_journal_tab_states(clues: Array, actors: Array, travel, feedback, actions: Array) -> void:
	journal_current_feedback_signature = _feedback_signature(feedback) if feedback is Dictionary else ""
	var has_unread_feedback := journal_current_feedback_signature != "" and journal_current_feedback_signature != journal_seen_feedback_signature
	journal_tab_labels[0] = "回响 · 新" if has_unread_feedback else "回响"
	journal_tab_colors[0] = COLORS.accent if has_unread_feedback else COLORS.muted
	var actionable_clues := 0
	for clue in clues:
		var fact_id := str(clue.get("fact_id", ""))
		if _has_action_for_fact(actions, fact_id):
			actionable_clues += 1
	journal_tab_labels[1] = "线索 · %d" % actionable_clues if actionable_clues > 0 else "线索"
	journal_tab_colors[1] = COLORS.muted
	var talkable_people := 0
	for actor in actors:
		if _count_tell_actions(actions, str(actor.get("id", "")), "") > 0:
			talkable_people += 1
	journal_tab_labels[2] = "人物 · %d" % talkable_people if talkable_people > 0 else "人物"
	journal_tab_colors[2] = COLORS.muted
	journal_tab_labels[3] = "行装"
	journal_tab_colors[3] = COLORS.muted
	if travel is Dictionary:
		var missing := _travel_missing_checks(travel).size()
		if missing > 0:
			journal_tab_labels[3] = "行装 !%d" % missing
			journal_tab_colors[3] = COLORS.danger
		else:
			journal_tab_labels[3] = "行装 · 齐"
			journal_tab_colors[3] = COLORS.success
	_refresh_journal_tab_styles()


func _reference_tab(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 9)
	scroll.add_child(box)
	return box


func _panel_style(color: Color, border: int, radius: int, border_color := COLORS.line, horizontal_margin := 16, vertical_margin := 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal_margin
	style.content_margin_right = horizontal_margin
	style.content_margin_top = vertical_margin
	style.content_margin_bottom = vertical_margin
	return style


func _tab_style(color: Color, border_color: Color) -> StyleBoxFlat:
	var style := _panel_style(color, 0, 5, border_color, 12, 8)
	style.border_width_bottom = 2 if border_color.a > 0.0 else 0
	return style


func _input_style(color: Color, border_color: Color) -> StyleBoxFlat:
	return _panel_style(color, 1, 6, border_color, 16, 11)


func _button(text_value: String, callback: Callable, secondary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 46
	button.add_theme_font_override("font", medium_font)
	button.add_theme_font_size_override("font_size", TYPE_SCALE.button)
	if secondary:
		button.add_theme_color_override("font_color", COLORS.ink)
		button.add_theme_color_override("font_hover_color", COLORS.ink)
		button.add_theme_color_override("font_pressed_color", COLORS.accent)
		button.add_theme_stylebox_override("normal", _panel_style(COLORS.panel_alt, 1, 6, COLORS.line, 14, 10))
		button.add_theme_stylebox_override("hover", _panel_style(COLORS.panel_hover, 1, 6, COLORS.accent_pressed, 14, 10))
		button.add_theme_stylebox_override("pressed", _panel_style(COLORS.bg_lift, 1, 6, COLORS.accent, 14, 11))
	else:
		button.add_theme_color_override("font_color", COLORS.accent_ink)
		button.add_theme_color_override("font_hover_color", COLORS.accent_ink)
		button.add_theme_color_override("font_pressed_color", COLORS.accent_ink)
		button.add_theme_stylebox_override("normal", _panel_style(COLORS.accent, 0, 6, COLORS.accent, 14, 11))
		button.add_theme_stylebox_override("hover", _panel_style(COLORS.accent_hover, 0, 6, COLORS.accent_hover, 14, 10))
		button.add_theme_stylebox_override("pressed", _panel_style(COLORS.accent_pressed, 0, 6, COLORS.accent_pressed, 14, 12))
	button.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, 2, 7, COLORS.accent_hover, 12, 8))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(COLORS.panel_alt, 0.58), 1, 6, Color(COLORS.line, 0.5), 14, 10))
	button.pressed.connect(callback)
	return button


func _utility_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 36
	button.add_theme_font_override("font", medium_font)
	button.add_theme_font_size_override("font_size", TYPE_SCALE.detail)
	button.add_theme_color_override("font_color", COLORS.muted)
	button.add_theme_color_override("font_hover_color", COLORS.ink)
	button.add_theme_color_override("font_pressed_color", COLORS.accent)
	button.add_theme_stylebox_override("normal", _panel_style(Color.TRANSPARENT, 0, 2, Color.TRANSPARENT, 10, 7))
	button.add_theme_stylebox_override("hover", _panel_style(Color(COLORS.panel_alt, 0.72), 0, 2, Color.TRANSPARENT, 10, 7))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(COLORS.bg_lift, 0.92), 0, 2, Color.TRANSPARENT, 10, 8))
	button.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, 1, 2, COLORS.accent, 9, 6))
	button.add_theme_stylebox_override("disabled", _panel_style(Color.TRANSPARENT, 0, 2, Color.TRANSPARENT, 10, 7))
	button.pressed.connect(callback)
	return button


func _mode_button(text_value: String, callback: Callable) -> Button:
	var button := _utility_button(text_value, callback)
	button.add_theme_font_size_override("font_size", TYPE_SCALE.compact)
	button.custom_minimum_size.y = 38
	return button


func _style_mode_state(button: Button, active: bool) -> void:
	button.add_theme_color_override("font_color", COLORS.accent if active else COLORS.muted)
	var normal := _panel_style(Color.TRANSPARENT, 0, 0, Color.TRANSPARENT, 12, 7)
	normal.border_width_bottom = 2 if active else 0
	normal.border_color = COLORS.accent
	button.add_theme_stylebox_override("normal", normal)


func _action_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 42
	button.add_theme_font_override("font", medium_font)
	button.add_theme_font_size_override("font_size", TYPE_SCALE.button)
	button.add_theme_color_override("font_color", COLORS.ink)
	button.add_theme_color_override("font_hover_color", COLORS.ink)
	button.add_theme_color_override("font_pressed_color", COLORS.accent)
	var normal := _panel_style(Color(COLORS.panel_alt, 0.38), 0, 2, Color.TRANSPARENT, 14, 9)
	normal.border_width_left = 2
	normal.border_color = Color(COLORS.line, 0.84)
	var hover := _panel_style(Color(COLORS.panel_hover, 0.78), 0, 2, Color.TRANSPARENT, 14, 9)
	hover.border_width_left = 2
	hover.border_color = COLORS.accent
	var pressed := _panel_style(Color(COLORS.bg_lift, 0.92), 0, 2, Color.TRANSPARENT, 14, 10)
	pressed.border_width_left = 2
	pressed.border_color = COLORS.accent_pressed
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, 1, 2, COLORS.accent_hover, 12, 7))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(COLORS.panel_alt, 0.26), 0, 2, Color.TRANSPARENT, 14, 9))
	button.pressed.connect(callback)
	return button


func _category_button(text_value: String, category: String, active: bool) -> Button:
	var marker := "当前" if active else "展开"
	var button := _utility_button("%s　·　%s" % [text_value, marker], _set_action_category.bind(category))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 34
	button.add_theme_color_override("font_color", COLORS.accent if active else COLORS.muted)
	return button


func _ornate_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.add_theme_font_override("font", display_font)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("e5c47d"))
	button.add_theme_color_override("font_hover_color", COLORS.ink)
	button.add_theme_color_override("font_pressed_color", COLORS.accent_pressed)
	button.add_theme_stylebox_override("normal", _panel_style(Color("080b09b8"), 0, 0, Color.TRANSPARENT, 20, 14))
	button.add_theme_stylebox_override("hover", _panel_style(Color("171c16e6"), 0, 0, Color.TRANSPARENT, 20, 14))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("050706f2"), 0, 0, Color.TRANSPARENT, 20, 15))
	button.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, 1, 2, COLORS.accent_hover, 18, 12))
	var frame := TextureRect.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.texture = DecisionFrameTexture
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.modulate = Color(1, 1, 1, 0.90)
	button.add_child(frame)
	button.move_child(frame, 0)
	button.pressed.connect(callback)
	return button


func _style_menu_button(button: MenuButton) -> void:
	button.add_theme_font_override("font", medium_font)
	button.add_theme_font_size_override("font_size", TYPE_SCALE.button)
	button.add_theme_color_override("font_color", COLORS.ink)
	button.add_theme_color_override("font_hover_color", COLORS.ink)
	button.add_theme_color_override("font_pressed_color", COLORS.accent)
	var normal := _panel_style(Color(COLORS.panel_alt, 0.38), 0, 2, Color.TRANSPARENT, 14, 9)
	normal.border_width_left = 2
	normal.border_color = Color(COLORS.line, 0.84)
	var hover := _panel_style(Color(COLORS.panel_hover, 0.78), 0, 2, Color.TRANSPARENT, 14, 9)
	hover.border_width_left = 2
	hover.border_color = COLORS.accent
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, 1, 2, COLORS.accent_hover, 12, 7))
	var popup := button.get_popup()
	popup.add_theme_color_override("font_color", COLORS.ink)
	popup.add_theme_color_override("font_hover_color", COLORS.accent_ink)
	popup.add_theme_stylebox_override("panel", _panel_style(COLORS.panel_alt, 1, 7, COLORS.line, 8, 8))
	popup.add_theme_stylebox_override("hover", _panel_style(COLORS.accent, 0, 4, COLORS.accent, 8, 6))


func _text(parent: Container, value: String, muted := false, size := TYPE_SCALE.body) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if size >= 24:
		label.add_theme_font_override("font", display_font)
	elif size >= 17 or size <= TYPE_SCALE.meta:
		label.add_theme_font_override("font", medium_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", COLORS.muted if muted else COLORS.ink)
	if size <= TYPE_SCALE.body:
		label.add_theme_constant_override("line_spacing", 4)
	elif size < 24:
		label.add_theme_constant_override("line_spacing", 3)
	parent.add_child(label)
	return label


func _clear(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()


func _set_buttons_disabled(node: Node, disabled: bool) -> void:
	if node is BaseButton:
		node.disabled = disabled
		if disabled:
			# 全局请求中的按钮只是暂时忙碌，不应看起来像永久不可用。
			node.add_theme_color_override("font_disabled_color", Color(COLORS.ink, 0.76))
		else:
			node.remove_theme_color_override("font_disabled_color")
	for child in node.get_children():
		_set_buttons_disabled(child, disabled)


func _operation_label(operation: String) -> String:
	var labels := {
		"health": "正在连接规则服务",
		"new": "正在进入白石坊市",
		"load": "正在读取旅程",
		"save": "正在保存",
		"autosave": "正在自动保存",
		"action": "正在推演行动结果",
		"quit": "正在返回",
	}
	return str(labels.get(operation, "处理中"))


func _request(operation: String, method: HTTPClient.Method, path: String, payload := {}) -> void:
	if pending_operation != "" or operation == "action" and presentation_busy:
		return
	pending_operation = operation
	pending_request_path = path
	pending_request_method = _http_method_name(method)
	request_started_msec = Time.get_ticks_msec()
	_log_event("INFO", "http_request", "request started", {
		"method": pending_request_method,
		"operation": operation,
		"path": path,
	})
	_set_buttons_disabled(self, true)
	if action_dock and action_dock.visible:
		action_dock_title.text = _operation_label(operation) + "…"
	if footer_label:
		footer_label.text = _operation_label(operation) + "…"
		footer_label.add_theme_color_override("font_color", COLORS.accent)
	if start_layer.visible and connection_label:
		connection_label.text = "正在确认旅途入口…"
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := "" if method == HTTPClient.METHOD_GET else JSON.stringify(payload)
	var error := http.request(API_BASE + path, headers, method, body)
	if error != OK:
		_log_event("ERROR", "http_send_failed", "request could not be sent", {
			"error": error,
			"method": pending_request_method,
			"operation": operation,
			"path": path,
		})
		pending_operation = ""
		pending_request_path = ""
		pending_request_method = ""
		_set_buttons_disabled(self, false)
		_show_error("无法发送请求（%s）" % error)


func _http_method_name(method: HTTPClient.Method) -> String:
	match method:
		HTTPClient.METHOD_GET:
			return "GET"
		HTTPClient.METHOD_POST:
			return "POST"
		HTTPClient.METHOD_PUT:
			return "PUT"
		HTTPClient.METHOD_DELETE:
			return "DELETE"
		_:
			return str(method)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	last_server_http_status = response_code
	var operation := pending_operation
	var request_path := pending_request_path
	var request_method := pending_request_method
	var duration_msec := maxi(0, Time.get_ticks_msec() - request_started_msec)
	pending_operation = ""
	pending_request_path = ""
	pending_request_method = ""
	_set_buttons_disabled(self, presentation_busy)
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	var error_code := ""
	if parsed is Dictionary and parsed.get("error", {}) is Dictionary:
		error_code = str(parsed.get("error", {}).get("code", ""))
	_log_event("INFO" if response_code >= 200 and response_code < 300 else "ERROR", "http_response", "request completed", {
		"duration_ms": duration_msec,
		"error_code": error_code,
		"method": request_method,
		"operation": operation,
		"path": request_path,
		"result": result,
		"status": response_code,
	})
	if response_code < 200 or response_code >= 300 or not parsed is Dictionary:
		queued_followup_action_id = ""
		var message := "本地服务无响应，请先运行项目启动脚本。"
		if parsed is Dictionary and parsed.get("error", {}) is Dictionary:
			message = str(parsed.get("error", {}).get("message", message))
		_show_error(message)
		return

	if connection_label:
		connection_label.text = ""
		connection_label.add_theme_color_override("font_color", COLORS.success)
		retry_button.hide()
	if operation == "health":
		if footer_label:
			footer_label.text = ""
		return
	if operation == "quit":
		_show_start()
		return
	if parsed.has("view") and operation not in ["autosave", "save"]:
		var previous_view := view_before_action if operation == "action" else current_view
		current_view = parsed["view"]
		if operation == "action":
			_apply_feedback_actor_state(current_view.get("last_turn", {}))
		_show_game()
		_render_view()
		if operation == "action":
			_play_action_presentation(previous_view, current_view)
		view_before_action = {}
	if operation == "action" and autosave_after_action:
		autosave_after_action = false
		_request("autosave", HTTPClient.METHOD_POST, "/game/save", {"slot": AUTOSAVE_SLOT})
	elif operation == "autosave":
		if _continue_queued_followup():
			return
		_show_footer_message("已自动保存")
		_render_actions(available_actions_cache)
	elif operation == "save":
		_show_footer_message("存档已保存")
		_render_actions(available_actions_cache)
	else:
		footer_label.text = ""


func _show_footer_message(message: String) -> void:
	footer_label.text = message
	footer_label.add_theme_color_override("font_color", COLORS.muted)
	_clear_footer_message_later(message)


func _play_action_presentation(previous_view: Dictionary, next_view: Dictionary) -> void:
	presentation_director.cancel()
	if ending_layer.visible:
		causal_layer.hide()
		return
	var feedback: Dictionary = next_view.get("last_turn", {})
	var cue: Dictionary = feedback.get("presentation", {})
	var previous_location: Dictionary = previous_view.get("location", {})
	var next_location: Dictionary = next_view.get("location", {})
	var from_id := str(previous_location.get("id", ""))
	var to_id := str(next_location.get("id", ""))
	if from_id != "" and to_id != "" and from_id != to_id:
		presentation_busy = true
		_set_buttons_disabled(self, true)
		_set_visual_mode("map")
		place_label.text = "%s → %s" % [previous_location.get("name", ""), next_location.get("name", "")]
		phase_label.text = "赶路中"
		audio_director.play_cue("travel", int(cue.get("intensity", 2)))
		var callback := _finish_travel_presentation.bind(feedback, previous_location, next_location)
		world_map_view.travel_finished.connect(callback, CONNECT_ONE_SHOT)
		world_map_view.animate_travel(from_id, to_id, int(previous_view.get("day", 0)), int(next_view.get("day", 0)))
		return
	_apply_presentation_cue(cue)
	if _has_causal_change(feedback):
		_present_causal_change(feedback, next_location)
		return
	presentation_director.present(feedback, str(previous_location.get("name", "")), str(next_location.get("name", "")))


func _finish_travel_presentation(feedback: Dictionary, previous_location: Dictionary, next_location: Dictionary) -> void:
	presentation_busy = false
	_set_buttons_disabled(self, pending_operation != "")
	_set_visual_mode("location")
	day_label.text = "第 %d / %d 日" % [maxi(1, int(current_view.get("day", 0))), int(current_view.get("duration", 0))]
	place_label.text = str(next_location.get("name", "未知"))
	phase_label.text = _phase_display(str(current_view.get("phase", "")))
	location_stage.play_establish()
	if _has_causal_change(feedback):
		_present_causal_change(feedback, next_location)
	else:
		presentation_director.present(feedback, str(previous_location.get("name", "")), str(next_location.get("name", "")))


func _has_causal_change(feedback: Dictionary) -> bool:
	var influences = feedback.get("influence", [])
	if not influences is Array or influences.is_empty():
		return false
	for influence in influences:
		if influence.get("changes", []) is Array and not influence.get("changes", []).is_empty():
			return true
	return false


func _present_causal_change(feedback: Dictionary, location: Dictionary) -> void:
	var influences: Array = feedback.get("influence", [])
	if influences.is_empty():
		return
	var influence: Dictionary = influences[0]
	var changes: Array = influence.get("changes", [])
	if changes.is_empty():
		return
	var change: Dictionary = changes[0]
	var actor_name := str(influence.get("actor_name", "有人"))
	var actor_id := _actor_id_by_name(actor_name)
	if actor_id != "":
		causal_actor_id_by_name[actor_name] = actor_id
		last_causal_actor_id = actor_id
	elif causal_actor_id_by_name.has(actor_name):
		actor_id = str(causal_actor_id_by_name[actor_name])
	var fact_claim := str(influence.get("fact_claim", "你送出的消息"))
	var causal_key := actor_name
	var previous_count := int(causal_change_count_by_actor.get(causal_key, 0))
	causal_change_count_by_actor[causal_key] = previous_count + 1
	var change_day := int(change.get("day", feedback.get("day", current_view.get("day", 0))))
	if previous_count > 0:
		var ripple := feedback.duplicate(true)
		ripple["action"] = "余波继续 · %s" % actor_name
		ripple["messages"] = ["第 %d 日 · %s不再%s，转而%s。" % [change_day, actor_name, change.get("without_information", "照原计划行事"), change.get("with_information", "改变安排")]]
		presentation_director.present(ripple, "", "")
		audio_director.play_cue("focus", 2)
		return
	var profile: ActorVisualProfile = presentation_registry.actor_profile(actor_id)
	var location_profile: LocationVisualProfile = presentation_registry.location_profile(str(location.get("scene_key", "")))
	causal_background.texture = location_profile.background if location_profile and location_profile.background else null
	causal_portrait.texture = profile.portrait("decisive") if profile else null
	causal_actor_meta.text = "%s · 已有决断" % actor_name
	causal_message.text = "你告知%s：%s" % [actor_name, fact_claim]
	causal_original.text = str(change.get("without_information", "原有安排"))
	causal_now.text = str(change.get("with_information", "新的安排"))
	causal_day.text = "第 %d 日 · 由原本到现在，已有决断" % change_day
	causal_layer.modulate = Color(1, 1, 1, 0) if motion_enabled else Color.WHITE
	causal_layer.show()
	_sync_action_canvas_visibility()
	var portrait_tint := Color(0.78, 0.78, 0.74, 1.0)
	causal_portrait.modulate = Color(portrait_tint, 0) if motion_enabled else portrait_tint
	causal_portrait.position.x = -32 if motion_enabled else 0
	if motion_enabled:
		var tween := create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(causal_layer, "modulate", Color.WHITE, 0.34)
		tween.tween_property(causal_portrait, "modulate", portrait_tint, 0.48).set_delay(0.10)
		tween.tween_property(causal_portrait, "position:x", 0.0, 0.62).set_delay(0.08)
	audio_director.play_cue("focus", 3)


func _dismiss_causal() -> void:
	audio_director.play_ui()
	causal_layer.hide()
	causal_layer.modulate = Color.WHITE
	_sync_action_canvas_visibility()


func _apply_presentation_cue(cue: Dictionary) -> void:
	if cue.is_empty():
		return
	var kind := str(cue.get("kind", "time"))
	var intensity := int(cue.get("intensity", 1))
	audio_director.play_cue(kind, intensity)
	if kind in ["reveal", "danger", "focus", "acquire"]:
		location_stage.play_reveal(intensity)
	if kind == "actor_focus":
		_focus_portrait(str(cue.get("subject_id", "")))


func _apply_feedback_actor_state(feedback: Dictionary) -> void:
	if feedback.is_empty():
		return
	var action_id := str(feedback.get("action_id", ""))
	if action_id.begins_with("tell:"):
		var parts := action_id.split(":")
		if parts.size() >= 2:
			actor_expression_by_id[str(parts[1])] = "troubled"
	for influence in feedback.get("influence", []):
		var actor_id := _actor_id_by_name(str(influence.get("actor_name", "")))
		if actor_id != "":
			actor_expression_by_id[actor_id] = "decisive"


func _on_travel_day_changed(day: int) -> void:
	day_label.text = "第 %d / %d 日" % [maxi(1, day), int(current_view.get("duration", 0))]


func _clear_footer_message_later(expected: String) -> void:
	await get_tree().create_timer(2.5).timeout
	if footer_label.text == expected:
		footer_label.text = ""


func _new_game() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name == "":
		player_name = "无名修士"
	actor_expression_by_id.clear()
	causal_change_count_by_actor.clear()
	causal_actor_id_by_name.clear()
	last_causal_actor_id = ""
	journal_seen_feedback_signature = ""
	journal_current_feedback_signature = ""
	journal_feedback_details_visible = false
	journal_travel_details_visible = false
	active_action_category = ""
	selected_followup_action_id = ""
	queued_followup_action_id = ""
	_reset_action_focus()
	ending_layer.hide()
	_set_visual_mode("location")
	_request("new", HTTPClient.METHOD_POST, "/game/new", {"player_name": player_name})


func _retry_connection() -> void:
	connection_label.text = "正在重新确认旅途入口…"
	connection_label.add_theme_color_override("font_color", COLORS.muted)
	_request("health", HTTPClient.METHOD_GET, "/health")


func _load_game() -> void:
	_set_visual_mode("map")
	_request("load", HTTPClient.METHOD_POST, "/game/load", {"slot": AUTOSAVE_SLOT})


func _save_game() -> void:
	_request("save", HTTPClient.METHOD_POST, "/game/save", {"slot": AUTOSAVE_SLOT})


func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	sound_button.text = "声音" if sound_enabled else "声音 · 静音"
	audio_director.set_enabled(sound_enabled)


func _toggle_motion() -> void:
	motion_enabled = not motion_enabled
	if motion_button:
		motion_button.text = "动态效果 · 开启" if motion_enabled else "动态效果 · 精简"
	if world_map_view:
		world_map_view.set_motion_enabled(motion_enabled)
	if presentation_director:
		presentation_director.motion_enabled = motion_enabled


func _open_audio_settings() -> void:
	audio_director.play_ui()
	settings_layer.show()
	_sync_action_canvas_visibility()


func _close_audio_settings() -> void:
	audio_director.play_ui()
	settings_layer.hide()
	_sync_action_canvas_visibility()


func _open_journal() -> void:
	audio_director.play_ui()
	if not motion_enabled:
		journal_panel.position.x = 0
		journal_layer.modulate = Color.WHITE
		journal_layer.show()
		_sync_action_canvas_visibility()
		return
	journal_panel.position.x = 42
	journal_layer.modulate = Color(1, 1, 1, 0)
	journal_layer.show()
	_sync_action_canvas_visibility()
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(journal_layer, "modulate", Color.WHITE, 0.22)
	tween.tween_property(journal_panel, "position:x", 0.0, 0.28)


func _close_journal() -> void:
	audio_director.play_ui()
	journal_layer.hide()
	journal_panel.position.x = 0
	_sync_action_canvas_visibility()
	if journal_current_feedback_signature != "":
		journal_seen_feedback_signature = journal_current_feedback_signature
		_render_journal_tab_states(
			current_view.get("known_facts", []),
			current_view.get("known_actors", []),
			current_view.get("travel", null),
			current_view.get("last_turn", null),
			available_actions_cache,
		)


func _set_bus_volume(value: float, bus_name: String) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, value <= 0.0)
	if value > 0.0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value / 100.0))


func _return_to_start() -> void:
	_request("quit", HTTPClient.METHOD_POST, "/game/quit")


func _restart_from_ending() -> void:
	_new_game()


func _execute_action(action_id: String, followup_action_id := "") -> void:
	view_before_action = current_view.duplicate(true)
	autosave_after_action = true
	queued_followup_action_id = followup_action_id
	_request("action", HTTPClient.METHOD_POST, "/game/action", {"action_id": action_id})


func _continue_queued_followup() -> bool:
	if queued_followup_action_id == "":
		return false
	var followup_id := queued_followup_action_id
	queued_followup_action_id = ""
	if _action_by_id(available_actions_cache, followup_id).is_empty():
		_show_footer_message("局势提前变化，已停下等待你的判断")
		_render_actions(available_actions_cache)
		return true
	footer_label.text = "继续推进到这一阶段结束…"
	footer_label.add_theme_color_override("font_color", COLORS.accent)
	_execute_action(followup_id)
	return true


func _show_start() -> void:
	current_view = {}
	selected_action = {}
	selected_followup_action_id = ""
	queued_followup_action_id = ""
	available_actions_cache = []
	selected_map_location_id = ""
	rendered_location_id = ""
	view_before_action = {}
	presentation_busy = false
	causal_change_count_by_actor.clear()
	causal_actor_id_by_name.clear()
	last_causal_actor_id = ""
	active_action_category = ""
	_reset_action_focus()
	game_layer.hide()
	journal_layer.hide()
	confirmation_layer.hide()
	settings_layer.hide()
	causal_layer.hide()
	ending_layer.hide()
	if presentation_director:
		presentation_director.cancel()
	start_layer.show()
	_sync_action_canvas_visibility()


func _show_game() -> void:
	start_layer.hide()
	game_layer.show()
	_sync_action_canvas_visibility()


func _show_error(message: String) -> void:
	if start_layer.visible:
		connection_label.text = message
		connection_label.add_theme_color_override("font_color", COLORS.danger)
		retry_button.show()
	else:
		footer_label.text = message
		footer_label.add_theme_color_override("font_color", COLORS.danger)


func _render_view() -> void:
	var player: Dictionary = current_view.get("player", {})
	var location: Dictionary = current_view.get("location", {})
	var day := int(current_view.get("day", 0))
	day_label.text = "第 %d / %d 日" % [maxi(1, day), int(current_view.get("duration", 0))]
	place_label.text = str(location.get("name", "未知"))
	phase_label.text = _phase_display(str(current_view.get("phase", "")))
	var travel = current_view.get("travel", null)
	footer_label.add_theme_color_override("font_color", COLORS.muted)
	var available_actions = current_view.get("available_actions", [])
	if not available_actions is Array:
		available_actions = []
	available_actions_cache = available_actions
	var known_actors: Array = current_view.get("known_actors", [])
	var known_facts: Array = current_view.get("known_facts", [])
	var guidance: Array = current_view.get("guidance", [])
	_reconcile_action_focus(known_actors, known_facts)
	var location_id := str(location.get("id", ""))
	if rendered_location_id != location_id:
		selected_map_location_id = location_id
		rendered_location_id = location_id
		stage_actor_id = ""
		stage_actor_name = ""
	_reconcile_stage_actor(known_actors)
	timing_label.text = _known_timing(known_facts)
	objective_label.text = str(guidance[0]) if not guidance.is_empty() else "风声未定，先看清眼前的人和路。"
	_render_player(player)
	_render_clues(known_facts, available_actions_cache)
	_render_scene(current_view.get("recent_events", []), guidance.slice(1), travel, current_view.get("last_turn", null), current_view.get("causal_threads", []), str(player.get("name", "旅人")))
	_render_people(known_actors, available_actions_cache)
	_render_travel_readiness(travel, current_view.get("preparation", {}), current_view.get("route_progress", null))
	_render_journal_tab_states(known_facts, known_actors, travel, current_view.get("last_turn", null), available_actions_cache)
	_render_actions(available_actions_cache)
	_render_world_map(current_view.get("world_map", {}), location, available_actions_cache)
	_render_location_stage(location, known_actors, available_actions_cache)
	_sync_action_canvas_visibility()
	var ending = current_view.get("ending", null)
	if bool(current_view.get("resolved", false)) or bool(current_view.get("ended", false)) or ending is Dictionary:
		_render_ending(ending if ending is Dictionary else {})


func _set_visual_mode(mode: String) -> void:
	var previous_mode := visual_mode
	visual_mode = mode
	if mode == "map" and (focused_actor_id != "" or focused_fact_id != ""):
		_reset_action_focus()
		if actions_box:
			_render_actions(available_actions_cache)
	if map_panel:
		map_panel.visible = mode == "map"
	if location_panel:
		location_panel.visible = mode == "location"
	_sync_action_canvas_visibility()
	if map_mode_button:
		map_mode_button.text = "地图"
		map_mode_button.tooltip_text = "查看公开地点、路线与行程"
		_style_mode_state(map_mode_button, mode == "map")
	if location_mode_button:
		location_mode_button.text = "当前地点"
		location_mode_button.tooltip_text = "返回当前位置、人物与行动"
		_style_mode_state(location_mode_button, mode == "location")
	if mode == "location" and previous_mode != "location" and location_stage:
		location_stage.play_establish.call_deferred()
	if actions_box:
		_render_actions(available_actions_cache)


func _sync_action_canvas_visibility() -> void:
	if not action_canvas or not action_dock:
		return
	var should_show := (
		game_layer
		and game_layer.visible
		and visual_mode == "location"
		and not start_layer.visible
		and not journal_layer.visible
		and not confirmation_layer.visible
		and not settings_layer.visible
		and not causal_layer.visible
		and not ending_layer.visible
	)
	action_canvas.visible = should_show
	action_dock.visible = should_show


func _render_world_map(world_map, current_location: Dictionary, actions: Array) -> void:
	if not world_map is Dictionary:
		world_map = {}
	world_map_view.set_map(world_map, selected_map_location_id)
	_render_map_detail(world_map, current_location, actions)


func _on_map_location_selected(location_id: String) -> void:
	selected_map_location_id = location_id
	_render_map_detail(current_view.get("world_map", {}), current_view.get("location", {}), available_actions_cache)


func _render_map_detail(world_map: Dictionary, current_location: Dictionary, actions: Array) -> void:
	_clear(map_detail_box)
	var eyebrow := _text(map_detail_box, "黑风谷 · 立体路线沙盘", true, 12)
	eyebrow.add_theme_color_override("font_color", COLORS.accent)
	var guidance := _text(map_detail_box, "点击地点或发光路径，查看目的地、耗时与阻碍。", true, 12)
	guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var map_separator := HSeparator.new()
	map_separator.add_theme_color_override("separator", Color(COLORS.accent, 0.24))
	map_detail_box.add_child(map_separator)
	var selected := _map_location(world_map.get("locations", []), selected_map_location_id)
	if selected.is_empty():
		_text(map_detail_box, "选择地点查看路线", false, 18)
		return
	var title_line := _text(map_detail_box, str(selected.get("name", "未知地点")), false, 22)
	title_line.add_theme_color_override("font_color", COLORS.accent if bool(selected.get("current", false)) else COLORS.ink)
	var place_state := "当前据点" if bool(selected.get("current", false)) else ("安全落脚点" if bool(selected.get("safe", false)) else "危险区域")
	var state_line := _text(map_detail_box, place_state, false, 13)
	state_line.add_theme_color_override("font_color", COLORS.success if bool(selected.get("safe", false)) else COLORS.danger)
	_text(map_detail_box, str(selected.get("description", "尚无公开地点资料")), true, 13)
	if bool(selected.get("contest", false)):
		var contest_line := _text(map_detail_box, "核心目标 · 青髓芝争夺将在这里落定", false, 13)
		contest_line.add_theme_color_override("font_color", COLORS.accent)
	match str(selected.get("scene_key", "")):
		"valley_edge":
			_text(map_detail_box, "推进阶段 · 第一段：谷口判断", true, 13)
		"inner_valley":
			_text(map_detail_box, "推进阶段 · 第二段：核心争夺", true, 13)
	if bool(selected.get("current", false)):
		_render_route_progress(map_detail_box, current_view.get("route_progress", null), true)
		var hint := _text(map_detail_box, "沙盘上的金色道路当前可以通行。", true, 12)
		hint.add_theme_color_override("font_color", COLORS.muted)
		var enter_button := _utility_button("回到眼前", _set_visual_mode.bind("location"))
		enter_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		enter_button.custom_minimum_size.y = 42
		map_detail_box.add_child(enter_button)
		return
	var route := _current_map_route(world_map.get("routes", []), str(current_location.get("id", "")), selected_map_location_id)
	if route.is_empty():
		_text(map_detail_box, "这里不与当前位置直接相连，需要从相邻地点转进。", true, 13)
		return
	var route_status := str(route.get("status", "known"))
	var route_labels := {"available": "可以通行", "blocked": "道路受阻", "known": "尚未打通"}
	var route_line := _text(map_detail_box, "道路状态 · %s" % route_labels.get(route_status, "尚不明确"), false, 13)
	route_line.add_theme_color_override("font_color", COLORS.accent if route_status == "available" else (COLORS.danger if route_status == "blocked" else COLORS.muted))
	_text(map_detail_box, "耗时 %d 日 · 危险 %d" % [int(route.get("duration", 1)), int(route.get("danger", 0))], true, 13)
	if route_status == "available":
		var action := _action_by_id(actions, str(route.get("action_id", "")))
		if not action.is_empty():
			var move_button := _button("前往%s · %d 日" % [selected.get("name", "目的地"), int(route.get("duration", 1))], _consider_action.bind(action), false)
			move_button.custom_minimum_size.y = 46
			move_button.tooltip_text = "危险 %d · 途中局势会继续推进" % int(route.get("danger", 0))
			map_detail_box.add_child(move_button)
	elif route_status == "blocked":
		var blockers := _joined_action_values(route.get("blockers", []))
		var blocked_line := _text(map_detail_box, "路线受阻 · %s" % blockers, false, 13)
		blocked_line.add_theme_color_override("font_color", COLORS.danger)


func _render_location_stage(location: Dictionary, actors: Array, actions: Array) -> void:
	location_stage.set_location(location)
	audio_director.set_scene(str(location.get("scene_key", "")))
	_render_actor_portrait(actors)
	_clear(location_detail_box)
	var phase_marker := ""
	match str(location.get("scene_key", "")):
		"valley_edge":
			phase_marker = "第一段 · 谷口判断"
		"inner_valley":
			phase_marker = "第二段 · 核心争夺"
	var place_title := "%s" % ["安稳" if bool(location.get("safe", false)) else "险地"]
	if phase_marker != "":
		place_title += " · %s" % phase_marker
	if not actors.is_empty():
		place_title += " · 在场 %d 人" % actors.size()
	var place_line := _text(location_detail_box, place_title, false, 13)
	place_line.add_theme_color_override("font_color", COLORS.accent)
	_text(location_detail_box, str(location.get("atmosphere", location.get("description", ""))), true, 13)
	_render_stage_people(actors, actions)


func _render_stage_people(actors: Array, actions: Array) -> void:
	_clear(stage_people_box)
	if actors.is_empty():
		_text(stage_people_box, "此地暂时无人可交涉", true, 13)
		return
	for index in actors.size():
		var actor: Dictionary = actors[index]
		var actor_id := str(actor.get("id", ""))
		var actor_name := str(actor.get("name", "无名者"))
		var clue_count := _count_tell_actions(actions, actor_id, "")
		var selected := actor_id == stage_actor_id
		var button_text := ("◆ " if selected else "") + actor_name
		if clue_count > 0:
			button_text += " · %d 条" % clue_count
		var button := _action_button(button_text, _focus_actor_from_stage.bind(actor_id, actor_name))
		button.custom_minimum_size = Vector2(132, 36)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = "%s\n%s" % [actor.get("public_role", "可交谈人物"), actor.get("public_profile", "")]
		if selected:
			var profile: ActorVisualProfile = presentation_registry.actor_profile(actor_id)
			var actor_accent := profile.accent_color if profile else COLORS.accent
			button.add_theme_color_override("font_color", COLORS.ink)
			button.add_theme_stylebox_override("normal", _panel_style(COLORS.panel_hover, 1, 6, actor_accent.lerp(COLORS.accent, 0.35), 12, 7))
		stage_people_box.add_child(button)


func _render_actor_portrait(actors: Array) -> void:
	actor_portrait_frame.hide()
	actor_portrait.texture = null
	var actor := _selected_stage_actor(actors)
	if actor.is_empty():
		return
	var actor_id := str(actor.get("id", ""))
	_show_actor_portrait(actor, str(actor_expression_by_id.get(actor_id, "neutral")))


func _focus_portrait(actor_id: String, expression_override := "") -> void:
	var actor := _actor_by_id(current_view.get("known_actors", []), actor_id)
	if actor.is_empty():
		actor = {"id": actor_id, "name": stage_actor_name, "public_role": "可交谈人物"}
	stage_actor_id = actor_id
	stage_actor_name = str(actor.get("name", stage_actor_name))
	var expression := expression_override
	if expression == "":
		expression = str(actor_expression_by_id.get(actor_id, "alert"))
	_show_actor_portrait(actor, expression)


func _show_actor_portrait(actor: Dictionary, expression: String) -> void:
	var actor_id := str(actor.get("id", ""))
	var profile: ActorVisualProfile = presentation_registry.actor_profile(actor_id)
	if profile == null or profile.neutral == null:
		return
	var portrait_texture := profile.portrait(expression)
	if portrait_texture == null:
		return
	actor_portrait.texture = portrait_texture
	actor_portrait_name.text = str(actor.get("name", "无名者"))
	var role := str(actor.get("public_role", "可交谈人物"))
	var faction := str(actor.get("faction", ""))
	var expression_names := {"neutral": "平静", "alert": "警觉", "troubled": "权衡中", "decisive": "已有决断"}
	var meta_parts: Array[String] = [role]
	if faction != "":
		meta_parts.append(faction)
	if expression != "neutral":
		meta_parts.append(str(expression_names.get(expression, expression)))
	actor_portrait_meta.text = " · ".join(meta_parts)
	actor_portrait_frame.tooltip_text = "%s · %s" % [actor_portrait_name.text, role]
	actor_portrait_frame.add_theme_stylebox_override("panel", _panel_style(Color.TRANSPARENT, 0, 0, Color.TRANSPARENT, 0, 0))
	actor_portrait_frame.show()
	var target_modulate := Color.WHITE
	match expression:
		"alert":
			target_modulate = Color("f0eadf")
		"troubled":
			target_modulate = Color("cbd3cb")
		"decisive":
			target_modulate = Color("fff0c8")
	actor_portrait.modulate = Color(target_modulate, 0.25)
	actor_portrait.scale = Vector2(0.985, 0.985)
	var portrait_tween := create_tween().set_parallel(true)
	portrait_tween.tween_property(actor_portrait, "modulate", target_modulate, 0.28)
	portrait_tween.tween_property(actor_portrait, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _selected_stage_actor(actors: Array) -> Dictionary:
	var selected := _actor_by_id(actors, stage_actor_id)
	if not selected.is_empty() and presentation_registry.has_actor(stage_actor_id):
		return selected
	for actor in actors:
		var actor_id := str(actor.get("id", ""))
		if presentation_registry.has_actor(actor_id):
			stage_actor_id = actor_id
			stage_actor_name = str(actor.get("name", "无名者"))
			return actor
	return {}


func _actor_by_id(actors, actor_id: String) -> Dictionary:
	if not actors is Array:
		return {}
	for actor in actors:
		if str(actor.get("id", "")) == actor_id:
			return actor
	return {}


func _actor_id_by_name(actor_name: String) -> String:
	for actor in current_view.get("known_actors", []):
		if str(actor.get("name", "")) == actor_name:
			return str(actor.get("id", ""))
	return ""


func _reconcile_stage_actor(actors: Array) -> void:
	if stage_actor_id != "" and not _actor_by_id(actors, stage_actor_id).is_empty():
		return
	stage_actor_id = ""
	stage_actor_name = ""
	_selected_stage_actor(actors)
	actor_portrait_frame.pivot_offset = actor_portrait_frame.size * 0.5
	actor_portrait_frame.scale = Vector2(0.965, 0.965)
	actor_portrait_frame.modulate = Color(1, 1, 1, 0.45)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(actor_portrait_frame, "scale", Vector2.ONE, 0.28)
	tween.tween_property(actor_portrait_frame, "modulate", Color.WHITE, 0.22)


func _focus_actor_from_stage(actor_id: String, actor_name: String) -> void:
	_set_visual_mode("location")
	audio_director.play_ui()
	_focus_actor_actions(actor_id, actor_name)


func _map_location(locations, location_id: String) -> Dictionary:
	if not locations is Array:
		return {}
	for location in locations:
		if str(location.get("id", "")) == location_id:
			return location
	return {}


func _current_map_route(routes, from_id: String, to_id: String) -> Dictionary:
	if not routes is Array:
		return {}
	for route in routes:
		if str(route.get("from_id", "")) == from_id and str(route.get("to_id", "")) == to_id:
			return route
	return {}


func _action_by_id(actions: Array, action_id: String) -> Dictionary:
	for action in actions:
		if str(action.get("id", "")) == action_id:
			return action
	return {}


func _render_player(player: Dictionary) -> void:
	var state := "空闲"
	if bool(player.get("busy", false)):
		state = "%s · 至第 %d 日" % [str(player.get("busy_action", "行动中")), int(player.get("busy_until", 0))]
	var resources: Dictionary = player.get("resources", {})
	var items: Array = player.get("items", [])
	player_summary_label.text = "%s · %s" % [player.get("name", "旅人"), state]
	_clear(player_resources_box)
	_add_status_chip(player_resources_box, "战力 %s" % _compact_number(resources.get("combat", 0)), COLORS.ink)
	_add_status_chip(player_resources_box, "灵石 %s" % _compact_number(resources.get("spirit_stones", 0)), COLORS.accent)
	var support := float(resources.get("support", 0))
	if support > 0.0:
		_add_status_chip(player_resources_box, "助力 %s" % _compact_number(support), COLORS.success)
	var injury := int(player.get("injury", 0))
	if injury > 0:
		_add_status_chip(player_resources_box, "伤势 %d" % injury, COLORS.danger)
	for index in range(mini(items.size(), 2)):
		var item: Dictionary = items[index]
		var item_name := str(item.get("name", "物品"))
		match str(item.get("id", "")):
			"healing_pill":
				item_name += " · 治伤"
			"antidote":
				item_name += " · 入谷"
		_add_status_chip(player_resources_box, "%s ×%d" % [item_name, int(item.get("amount", 1))], COLORS.muted)
	if items.size() > 2:
		_add_status_chip(player_resources_box, "行囊 %d 种" % items.size(), COLORS.muted)


func _compact_number(value: Variant) -> String:
	var numeric := float(value)
	if is_equal_approx(numeric, round(numeric)):
		return str(int(round(numeric)))
	return "%.1f" % numeric


func _add_status_chip(parent: Container, value: String, color: Color) -> void:
	var panel := PanelContainer.new()
	var style := _panel_style(Color(COLORS.panel_alt, 0.46), 0, 2, Color.TRANSPARENT, 9, 5)
	style.border_width_left = 2
	style.border_color = Color(color, 0.72)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", medium_font)
	label.add_theme_font_size_override("font_size", TYPE_SCALE.meta)
	label.add_theme_color_override("font_color", color)
	panel.add_child(label)
	parent.add_child(panel)


func _known_timing(clues: Array) -> String:
	var best: Dictionary = {}
	for clue in clues:
		if "成熟" not in str(clue.get("claim", "")):
			continue
		if best.is_empty() or int(clue.get("confidence", 0)) > int(best.get("confidence", 0)):
			best = clue
	if best.is_empty():
		return "尚未查明"
	var timing := str(best.get("claim", "未知"))
	timing = timing.replace("青髓芝将在", "").replace("成熟", "")
	var confidence := int(best.get("confidence", 0))
	var status := "已核实" if confidence >= 3 else ("较可信" if confidence == 2 else "传闻")
	return "%s · %s" % [timing, status]


func _phase_display(phase: String) -> String:
	match phase:
		"准备":
			return "筹备期"
		"扩散":
			return "消息扩散期"
		"入谷":
			return "入谷争夺期"
	return "筹备期" if phase == "" else phase


func _render_clues(clues: Array, actions: Array) -> void:
	_clear(clues_box)
	if clues.is_empty():
		_text(clues_box, "尚未掌握线索。先观察人物或调查地点。", true)
		return
	var unverified := 0
	for clue in clues:
		if int(clue.get("confidence", 0)) < 3:
			unverified += 1
	var overview := "%d 条已知" % clues.size()
	if unverified > 0:
		overview += " · %d 条待核验" % unverified
	var overview_label := _text(clues_box, overview, true, TYPE_SCALE.meta)
	overview_label.add_theme_color_override("font_color", COLORS.accent if unverified > 0 else COLORS.success)
	for index in clues.size():
		var clue: Dictionary = clues[index]
		var claim := _text(clues_box, str(clue.get("claim", "未知传言")), false, 15)
		claim.add_theme_font_override("font", medium_font)
		var confidence := int(clue.get("confidence", 0))
		var status := "已核实" if confidence >= 3 else ("较可信" if confidence == 2 else "未经核实")
		if bool(clue.get("contested", false)):
			status += " · 与旧说法冲突"
		var status_line := _text(clues_box, "%s · %s" % [status, clue.get("source", "来源未知")], true, 13)
		status_line.add_theme_color_override("font_color", COLORS.success if confidence >= 3 else COLORS.accent)
		var fact_id := str(clue.get("fact_id", ""))
		var verify_action := _action_for_fact(actions, fact_id, "verify")
		var target_count := _count_tell_actions(actions, "", fact_id)
		if not verify_action.is_empty() and confidence < 3:
			var verify_link := _action_button("核验这条线索", _consider_action.bind(verify_action))
			verify_link.custom_minimum_size.y = 36
			clues_box.add_child(verify_link)
		elif target_count > 0:
			var link := _action_button("可告知 %d 人" % target_count, _focus_fact_actions.bind(fact_id, str(clue.get("claim", "未知传言"))))
			link.custom_minimum_size.y = 36
			clues_box.add_child(link)
		if index < clues.size() - 1:
			var separator := HSeparator.new()
			separator.modulate = Color(COLORS.line, 0.58)
			clues_box.add_child(separator)


func _action_for_fact(actions: Array, fact_id: String, kind: String = "") -> Dictionary:
	for action in actions:
		if str(action.get("fact_id", "")) != fact_id:
			continue
		if kind != "" and str(action.get("kind", "")) != kind:
			continue
		return action
	return {}


func _has_action_for_fact(actions: Array, fact_id: String) -> bool:
	return not _action_for_fact(actions, fact_id).is_empty()


func _render_scene(events: Array, guidance: Array, travel, feedback, causal_threads: Array, player_name: String) -> void:
	_clear(scene_box)
	if feedback is Dictionary:
		var feedback_signature := _feedback_signature(feedback)
		if feedback_signature != journal_current_feedback_signature:
			journal_feedback_details_visible = false
		journal_current_feedback_signature = feedback_signature
		_render_feedback_summary(scene_box, feedback)
		var separator := HSeparator.new()
		separator.modulate = COLORS.line
		scene_box.add_child(separator)
	_render_causal_threads(scene_box, causal_threads)
	if not guidance.is_empty():
		var guidance_heading := _text(scene_box, "眼下", true, TYPE_SCALE.meta)
		guidance_heading.add_theme_color_override("font_color", COLORS.accent)
		for index in range(mini(guidance.size(), 2)):
			_text(scene_box, str(guidance[index]), true, 14)
	if events.is_empty():
		if not feedback is Dictionary:
			_text(scene_box, "四下暂时没有新的公开动静。", true)
		return
	var event_heading := _text(scene_box, "近来风声", true, TYPE_SCALE.meta)
	event_heading.add_theme_color_override("font_color", COLORS.accent)
	var rendered_events := 0
	for index in range(events.size() - 1, -1, -1):
		var event = events[index]
		if str(event.get("actor_name", "")) == player_name:
			continue
		_text(scene_box, "第 %d 日 · %s" % [int(event.get("day", 0)), event.get("description", "局势变化")], true, 14)
		rendered_events += 1
		if rendered_events >= 3:
			break


func _render_causal_threads(parent: VBoxContainer, threads: Array) -> void:
	if threads.is_empty():
		return
	var heading := _text(parent, "情报因果线", true, TYPE_SCALE.meta)
	heading.add_theme_color_override("font_color", COLORS.accent)
	var first := maxi(0, threads.size() - 2)
	for index in range(threads.size() - 1, first - 1, -1):
		var thread: Dictionary = threads[index]
		var stage := str(thread.get("stage", "delivered"))
		var stage_line := _text(parent, "%s · %s" % [thread.get("actor_name", "有人"), thread.get("stage_label", "已送达")], false, 14)
		stage_line.add_theme_color_override("font_color", COLORS.success if stage == "changed" else COLORS.accent)
		_text(parent, "“%s”" % thread.get("fact_claim", "一条消息"), true, 13)
		_text(parent, str(thread.get("summary", "尚无公开回响")), true, 13)


func _render_feedback_summary(parent: VBoxContainer, feedback: Dictionary) -> void:
	var status_names := {"completed": "已结算", "started": "进行中", "failed": "未能完成", "advanced": "已推进"}
	var status_key := str(feedback.get("status", ""))
	var status := str(status_names.get(status_key, "已结算"))
	var day := int(feedback.get("day", current_view.get("day", 0)))
	var meta := _text(parent, "第 %d 日 · %s" % [day, status], true, TYPE_SCALE.meta)
	meta.add_theme_color_override("font_color", COLORS.danger if status_key == "failed" else COLORS.accent)
	var influences: Array = feedback.get("influence", [])
	var headline := str(feedback.get("action", "局势有了变化"))
	var cause := ""
	if not influences.is_empty():
		var influence: Dictionary = influences[0]
		var changes: Array = influence.get("changes", [])
		if not changes.is_empty():
			headline = str(changes[0].get("with_information", headline))
		cause = "%s因你透露“%s”改变了安排" % [influence.get("actor_name", "有人"), influence.get("fact_claim", "一条消息")]
	var title := _text(parent, headline, false, 18)
	title.add_theme_font_override("font", display_font)
	if cause != "":
		_text(parent, cause, true, 14)
	var messages: Array = feedback.get("messages", [])
	var stop_reason := str(feedback.get("stop_reason", ""))
	if stop_reason != "":
		var stop_line := _text(parent, "为何停下 · %s" % stop_reason, false, 14)
		stop_line.add_theme_color_override("font_color", COLORS.accent)
	for index in range(mini(messages.size(), 2)):
		_text(parent, "· %s" % messages[index], false, 14)
	journal_feedback_details_button = _utility_button("收起推演过程" if journal_feedback_details_visible else "查看推演过程", _toggle_journal_feedback_details)
	journal_feedback_details_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(journal_feedback_details_button)
	journal_feedback_details_box = VBoxContainer.new()
	journal_feedback_details_box.add_theme_constant_override("separation", 6)
	journal_feedback_details_box.visible = journal_feedback_details_visible
	parent.add_child(journal_feedback_details_box)
	_render_feedback_evidence_into(journal_feedback_details_box, feedback)


func _toggle_journal_feedback_details() -> void:
	journal_feedback_details_visible = not journal_feedback_details_visible
	if journal_feedback_details_box:
		journal_feedback_details_box.visible = journal_feedback_details_visible
	if journal_feedback_details_button:
		journal_feedback_details_button.text = "收起推演过程" if journal_feedback_details_visible else "查看推演过程"


func _feedback_signature(feedback) -> String:
	if not feedback is Dictionary:
		return ""
	return "%s|%s|%s" % [feedback.get("day", ""), feedback.get("action_id", ""), feedback.get("status", "")]


func _render_travel_readiness(travel, preparation = {}, route_progress = null) -> void:
	_clear(travel_box)
	_render_route_progress(travel_box, route_progress, false)
	if not travel is Dictionary:
		_text(travel_box, "还没有明确的远行目标。", true)
		return
	var route: Array = travel.get("route", [])
	var destination := str(travel.get("destination", "黑风谷"))
	if destination == "" and not route.is_empty():
		destination = str(route[route.size() - 1])
	var meta_text := "%s · 约 %d 日" % [destination, int(travel.get("travel_days", 0))]
	var meta := _text(travel_box, meta_text, true, TYPE_SCALE.meta)
	meta.add_theme_color_override("font_color", COLORS.accent)
	var missing := _travel_missing_checks(travel)
	var ready_checks := _travel_ready_checks(travel)
	if missing.is_empty():
		var ready_title := _text(travel_box, "行装已经齐备", false, 19)
		ready_title.add_theme_color_override("font_color", COLORS.success)
		_text(travel_box, "路已认清，可以按自己的时机启程。", true, 14)
	else:
		var missing_title := _text(travel_box, "仍缺 %d 项才能成行" % missing.size(), false, 19)
		missing_title.add_theme_color_override("font_color", COLORS.danger)
		for check in missing:
			var check_label := str(check.get("label", "路线条件"))
			var missing_line := _text(travel_box, _travel_blocker_text(check_label), false, 15)
			missing_line.add_theme_color_override("font_color", COLORS.danger)
			if check_label.contains("解瘴丹"):
				var resolution_action := _travel_resolution_action(available_actions_cache)
				if not resolution_action.is_empty():
					var resolution_button := _action_button(_travel_resolution_label(resolution_action), _consider_action_from_journal.bind(resolution_action))
					resolution_button.custom_minimum_size.y = 38
					travel_box.add_child(resolution_button)
			elif check_label.contains("入口开放"):
				_text(travel_box, "入口会随局势开放；眼下可以核验、交涉或继续准备。", true, 13)
	if preparation is Dictionary:
		var score_sources: Array = preparation.get("score_sources", [])
		if not score_sources.is_empty():
			var preparation_heading := _text(travel_box, "你的争夺准备", true, TYPE_SCALE.meta)
			preparation_heading.add_theme_color_override("font_color", COLORS.accent)
			var rating := str(preparation.get("rating", "尚未判断"))
			var total_score := int(preparation.get("total_score", 0))
			var target_score := int(preparation.get("target_score", 0))
			var rating_line := _text(travel_box, "综合准备 %d / 基线 %d · %s" % [total_score, target_score, rating], false, 18)
			rating_line.add_theme_color_override("font_color", COLORS.success if total_score >= target_score else COLORS.danger)
			_text(travel_box, str(preparation.get("rating_detail", "")), true, 13)
			for factor in score_sources:
				var factor_line := _text(travel_box, "%s %d · %s" % [factor.get("label", "准备"), int(factor.get("value", 0)), factor.get("status", "")], false, 14)
				factor_line.add_theme_color_override("font_color", COLORS.success if bool(factor.get("ready", false)) else COLORS.muted)
			_text(travel_box, "基线来自已知主要争夺者的公开实力，只用于判断是否值得正面入局。", true, 13)
	var timing := str(travel.get("timing", ""))
	if timing != "":
		var timing_line := _text(travel_box, timing, true, 13)
		timing_line.add_theme_color_override("font_color", COLORS.danger if timing.contains("来不及") else COLORS.accent)
	journal_travel_details_button = _utility_button("收起完整行装" if journal_travel_details_visible else "查看已备与路线", _toggle_journal_travel_details)
	journal_travel_details_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	travel_box.add_child(journal_travel_details_button)
	journal_travel_details_box = VBoxContainer.new()
	journal_travel_details_box.add_theme_constant_override("separation", 6)
	journal_travel_details_box.visible = journal_travel_details_visible
	travel_box.add_child(journal_travel_details_box)
	if not route.is_empty():
		_text(journal_travel_details_box, "路线 · %s" % " → ".join(route), true, 13)
	for check in ready_checks:
		var ready_line := _text(journal_travel_details_box, _travel_ready_text(str(check.get("label", "路线条件"))), false, 13)
		ready_line.add_theme_color_override("font_color", COLORS.success)
	if ready_checks.is_empty():
		_text(journal_travel_details_box, "尚无已经满足的准备项。", true, 13)


func _render_route_progress(parent: VBoxContainer, route_progress, compact: bool) -> void:
	if not route_progress is Dictionary or route_progress.is_empty():
		return
	var heading := _text(parent, "当前路线 · %s" % route_progress.get("label", "未命名路线"), true, TYPE_SCALE.meta)
	heading.add_theme_color_override("font_color", COLORS.accent)
	var status := str(route_progress.get("status", "推进中"))
	var next_step := str(route_progress.get("next_step", "等待下一次变化"))
	var status_line := _text(parent, "%s · %s" % [status, next_step], false, 14 if compact else 15)
	status_line.add_theme_color_override("font_color", COLORS.danger if bool(route_progress.get("urgent", false)) else (COLORS.success if bool(route_progress.get("complete", false)) else COLORS.ink))
	if compact:
		return
	var window := str(route_progress.get("window", ""))
	var location := str(route_progress.get("location", ""))
	if window != "" or location != "":
		_text(parent, "窗口 · %s%s" % [window, (" · " + location) if location != "" else ""], true, 13)
	var personal_return := str(route_progress.get("personal_return", ""))
	if personal_return != "":
		_text(parent, "个人收益 · %s" % personal_return, true, 13)


func _toggle_journal_travel_details() -> void:
	journal_travel_details_visible = not journal_travel_details_visible
	if journal_travel_details_box:
		journal_travel_details_box.visible = journal_travel_details_visible
	if journal_travel_details_button:
		journal_travel_details_button.text = "收起完整行装" if journal_travel_details_visible else "查看已备与路线"


func _travel_resolution_action(actions: Array) -> Dictionary:
	for action in actions:
		if str(action.get("kind", "")) == "recover" and str(action.get("target_id", "")) == "N06":
			return action
	for action in actions:
		if str(action.get("kind", "")) == "buy" and str(action.get("target_id", "")) == "antidote":
			return action
	for action in actions:
		if str(action.get("kind", "")) == "move" and str(action.get("target_id", "")) == "L01":
			return action
	return {}


func _travel_resolution_label(action: Dictionary) -> String:
	match str(action.get("kind", "")):
		"recover":
			return "找苏晚照 · 用情报交换解瘴丹"
		"buy":
			return "现在购买解瘴丹 · %d 灵石" % int(action.get("costs", {}).get("spirit_stones", 0))
		"move":
			return "返回白石坊市寻找解瘴丹"
	return str(action.get("name", "处理缺项"))


func _consider_action_from_journal(action: Dictionary) -> void:
	_close_journal()
	_consider_action(action)


func _travel_missing_checks(travel: Dictionary) -> Array:
	var result: Array = []
	for check in travel.get("checks", []):
		if not bool(check.get("ready", false)):
			result.append(check)
	return result


func _travel_ready_checks(travel: Dictionary) -> Array:
	var result: Array = []
	for check in travel.get("checks", []):
		if bool(check.get("ready", false)):
			result.append(check)
	return result


func _travel_blocker_text(label_text: String) -> String:
	if label_text.begins_with("携带"):
		return "缺少 · %s" % label_text.trim_prefix("携带")
	if label_text.contains("入口开放"):
		return label_text.replace("入口开放", "入口尚未开放")
	if label_text.contains("路线"):
		return "尚未发现 · %s" % label_text
	return "未就绪 · %s" % label_text


func _travel_ready_text(label_text: String) -> String:
	if label_text == "可用路线":
		return "路线已发现"
	if label_text.begins_with("携带"):
		return "已备 · %s" % label_text.trim_prefix("携带")
	if label_text.contains("入口开放"):
		return label_text.replace("入口开放", "入口已开放")
	return "已备 · %s" % label_text


func _render_people(actors: Array, actions: Array) -> void:
	_clear(people_box)
	if actors.is_empty():
		_text(people_box, "此地没有可交谈的人。", true)
		return
	var talkable_people := 0
	for actor in actors:
		if _count_tell_actions(actions, str(actor.get("id", "")), "") > 0:
			talkable_people += 1
	var overview := "%d 人在场" % actors.size()
	if talkable_people > 0:
		overview += " · %d 人有新话可谈" % talkable_people
	var overview_label := _text(people_box, overview, true, TYPE_SCALE.meta)
	overview_label.add_theme_color_override("font_color", COLORS.accent if talkable_people > 0 else COLORS.muted)
	for index in actors.size():
		var actor: Dictionary = actors[index]
		var actor_name := str(actor.get("name", "无名者"))
		_text(people_box, "%s · %s" % [actor_name, actor.get("public_role", "可交谈人物")], false, 16)
		var focus: Array = actor.get("public_focus", [])
		var context_parts: Array[String] = [str(actor.get("faction", "散修"))]
		if not focus.is_empty():
			context_parts.append("关注%s" % str(focus[0]))
		_text(people_box, " · ".join(context_parts), true, 13)
		var actor_id := str(actor.get("id", ""))
		var clue_count := _count_tell_actions(actions, actor_id, "")
		var link_text := "交谈 · %d 条线索可用" % clue_count if clue_count > 0 else "查看人物"
		var link := _action_button(link_text, _focus_actor_from_reference.bind(actor_id, actor_name))
		link.custom_minimum_size.y = 36
		people_box.add_child(link)
		if index < actors.size() - 1:
			var separator := HSeparator.new()
			separator.modulate = Color(COLORS.line, 0.7)
			people_box.add_child(separator)


func _render_actions(actions: Array) -> void:
	_clear(actions_box)
	_clear(overview_actions_box)
	_clear(actor_focus_message_list)
	_clear(actor_focus_detail_box)
	_clear(actor_focus_footer)
	var focused_actions := _focused_information_actions(actions)
	var has_action_focus := focused_actor_id != "" or focused_fact_id != ""
	_configure_action_dock_layout(has_action_focus)
	if location_detail_box:
		location_detail_box.visible = not has_action_focus
	if stage_people_box:
		stage_people_box.visible = not has_action_focus
	overview_actions_box.visible = not has_action_focus
	actor_focus_workspace.visible = focused_actor_id != ""
	actor_focus_footer.visible = focused_actor_id != "" and not focused_actions.is_empty()
	legacy_action_scroll.visible = focused_fact_id != ""
	if focused_actor_id != "":
		action_dock_title.text = "与%s说话" % focused_actor_name
		_render_actor_focus_workspace(focused_actions)
		return
	if focused_fact_id != "":
		action_dock_title.text = "把消息交给谁"
		objective_label.text = focused_fact_claim
		_text(actions_box, focused_fact_claim, true, 14)
		var back := _utility_button("回到眼前", _clear_action_focus)
		back.alignment = HORIZONTAL_ALIGNMENT_LEFT
		actions_box.add_child(back)
		if focused_actions.is_empty():
			_text(actions_box, "这里已经没有尚未听过这条消息的人。", true)
			return
		_add_focused_information_actions(focused_actions)
		return
	action_dock_title.text = str(current_view.get("location", {}).get("name", "眼前"))
	var guidance: Array = current_view.get("guidance", [])
	objective_label.text = str(guidance[0]) if not guidance.is_empty() else "风声未定，先看清眼前的人和路。"
	if actions.is_empty():
		_text(overview_actions_box, "眼下无事可做，或许该换个地方看看。", true)
		return
	var eligible := _location_context_actions(actions)
	if eligible.is_empty():
		_text(overview_actions_box, "想赶路就翻开地图；想传话就先选中一个人。", true, 14)
		return
	_render_route_progress(overview_actions_box, current_view.get("route_progress", null), true)
	_render_first_day_route_compass(eligible, overview_actions_box)
	var visible_count := eligible.size() if show_all_actions else mini(3, eligible.size())
	for index in visible_count:
		_add_overview_choice(eligible[index], index)
	if eligible.size() > visible_count:
		var more := _utility_button("展开其余 %d 项安排" % (eligible.size() - visible_count), _toggle_all_actions)
		more.alignment = HORIZONTAL_ALIGNMENT_LEFT
		overview_actions_box.add_child(more)
	elif show_all_actions and eligible.size() > 3:
		var less := _utility_button("只看眼前要事", _toggle_all_actions)
		less.alignment = HORIZONTAL_ALIGNMENT_LEFT
		overview_actions_box.add_child(less)


func _configure_action_dock_layout(has_action_focus: bool) -> void:
	if not action_dock or not action_dock_host:
		return
	action_dock_host.anchor_top = 0.22 if has_action_focus else 0.45
	var dock_style := _panel_style(Color("0b100df2") if has_action_focus else Color("0b100de8"), 0, 2, Color.TRANSPARENT, 22, 16)
	dock_style.border_width_left = 2
	dock_style.border_color = Color(COLORS.accent, 0.72 if has_action_focus else 0.62)
	action_dock.add_theme_stylebox_override("panel", dock_style)


func _add_overview_choice(action: Dictionary, index: int) -> void:
	var label := str(action.get("name", "做一件事"))
	if action.get("id", "") == "verify:F02":
		label = "查明日期 · 核验成熟传闻"
	elif action.get("kind", "") == "buy" and action.get("target_id", "") == "antidote":
		label = "备好入谷药 · 购买解瘴丹"
	elif action.get("kind", "") == "recover":
		label = "交出已核实日期 → 获得解瘴丹"
	elif action.get("kind", "") == "escort":
		label = "兑现同行承诺 · 随青岚队伍入谷"
	elif action.get("kind", "") == "cultivate":
		var combat := int(current_view.get("player", {}).get("resources", {}).get("combat", 0))
		label = "修炼至下一阶段 · 战力 %d → %d" % [combat, combat + 1]
	if action.get("id", "") == "wait:next":
		label = "静候下一阵风声"
	var meta: Array[String] = []
	if int(action.get("completion_day", 0)) > 0:
		meta.append("%d日" % int(action.get("duration", 1)))
	else:
		meta.append("%d日" % int(action.get("duration", 1)))
	var outcomes := _joined_action_values(action.get("expected_outcomes", []))
	if outcomes != "":
		meta.append(outcomes)
	var button_label := "%d　%s" % [index + 1, label]
	if not meta.is_empty():
		button_label += "　·　%s" % " · ".join(meta)
	var callback := _consider_action.bind(action, "wait:complete") if action.get("kind", "") == "cultivate" else _consider_action.bind(action)
	var button := _action_button(button_label, callback)
	button.custom_minimum_size.y = 44
	button.tooltip_text = "%s\n%s" % [action.get("description", ""), action.get("timing", "")]
	overview_actions_box.add_child(button)


func _render_actor_focus_workspace(focused_actions: Array) -> void:
	var back := _utility_button("‹  返回%s" % current_view.get("location", {}).get("name", "眼前"), _clear_action_focus)
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	actor_focus_message_list.add_child(back)
	var actor := _actor_by_id(current_view.get("known_actors", []), focused_actor_id)
	var state_names := {"neutral": "平静", "alert": "正在留意你", "troubled": "正在权衡消息", "decisive": "已经形成决断"}
	var expression := str(actor_expression_by_id.get(focused_actor_id, "alert"))
	objective_label.text = "%s · %s · %s" % [actor.get("public_role", "可交谈人物"), actor.get("faction", "散修"), state_names.get(expression, expression)]
	var has_terms := false
	var has_route_response := false
	for action in focused_actions:
		if str(action.get("term_label", "")) != "":
			has_terms = true
		if str(action.get("kind", "")) == "route":
			has_route_response = true
	var workspace_heading := "回应路线考验" if has_route_response else ("选择交换条件" if has_terms else "选择要传达的话")
	var heading := _text(actor_focus_message_list, workspace_heading, true, TYPE_SCALE.meta)
	heading.add_theme_color_override("font_color", COLORS.accent)
	if focused_actions.is_empty():
		focused_actor_action_id = ""
		_text(actor_focus_message_list, "此刻没有新的话可说", true, 14)
		_text(actor_focus_detail_box, str(actor.get("public_profile", "公开资料尚未收集")), false, 16)
		_text(actor_focus_detail_box, "已经送达的消息不会重复出现。完整人物档案可在随身卷宗中查看。", true, 14)
		return
	var focused_choice := _resolve_focused_actor_action(focused_actions)
	for action in focused_actions:
		var action_id := str(action.get("id", ""))
		var claim := str(action.get("term_label", ""))
		if claim == "":
			claim = str(action.get("name", "以情报换取解瘴丹")) if action.get("kind", "") in ["recover", "escort"] else str(action.get("fact_claim", action.get("name", "一条消息")))
		var selected := action_id == str(focused_choice.get("id", ""))
		var button := _action_button(("◆  " if selected else "　") + claim, _select_focused_actor_action.bind(action_id))
		button.custom_minimum_size.y = 46
		if selected:
			var selected_style := _panel_style(Color(COLORS.panel_hover, 0.72), 0, 2, Color.TRANSPARENT, 12, 8)
			selected_style.border_width_left = 2
			selected_style.border_color = COLORS.accent
			button.add_theme_stylebox_override("normal", selected_style)
		actor_focus_message_list.add_child(button)
	_render_actor_focus_detail(focused_choice)


func _resolve_focused_actor_action(actions: Array) -> Dictionary:
	for action in actions:
		if str(action.get("id", "")) == focused_actor_action_id:
			return action
	for action in actions:
		if str(action.get("kind", "")) == "route":
			focused_actor_action_id = ""
			return {}
	var first: Dictionary = actions[0]
	focused_actor_action_id = str(first.get("id", ""))
	return first


func _select_focused_actor_action(action_id: String) -> void:
	focused_actor_action_id = action_id
	_render_actions(available_actions_cache)
	actor_focus_detail_scroll.set_deferred("scroll_vertical", 0)


func _render_actor_focus_detail(action: Dictionary) -> void:
	if action.is_empty():
		var prompt := _text(actor_focus_detail_box, "先选择一种回应", false, 22)
		prompt.add_theme_color_override("font_color", COLORS.accent)
		_text(actor_focus_detail_box, "这些选择会改变路线与人物关系。系统不会替你预选不可撤回的决定。", true, 15)
		return
	var claim := str(action.get("fact_claim", action.get("name", "一条消息")))
	if action.get("kind", "") == "route":
		claim = str(action.get("name", "回应眼前局势"))
	if action.get("kind", "") in ["recover", "escort"] and str(action.get("term_label", "")) == "":
		claim = str(action.get("name", "以情报换取解瘴丹"))
	var title := _text(actor_focus_detail_box, claim, false, 19)
	title.add_theme_color_override("font_color", COLORS.accent)
	var term_label := str(action.get("term_label", ""))
	if term_label != "":
		var term_prefix := "你的回应" if action.get("kind", "") == "route" else "你提出的条件"
		var term_heading := _text(actor_focus_detail_box, "%s · %s" % [term_prefix, term_label], true, TYPE_SCALE.meta)
		term_heading.add_theme_color_override("font_color", COLORS.accent)
		_text(actor_focus_detail_box, str(action.get("personal_outcome", action.get("description", ""))), false, 15)
	var relevance := str(action.get("relevance", "尚不了解这条消息会在对方心里留下什么"))
	var impact_heading := _text(actor_focus_detail_box, "他为何在意", true, TYPE_SCALE.meta)
	impact_heading.add_theme_color_override("font_color", COLORS.accent)
	_text(actor_focus_detail_box, relevance, false, 15)
	var outcomes := _joined_action_values(action.get("expected_outcomes", []))
	var outcome_heading := _text(actor_focus_detail_box, "可能影响", true, TYPE_SCALE.meta)
	outcome_heading.add_theme_color_override("font_color", COLORS.accent)
	_text(actor_focus_detail_box, outcomes if outcomes != "" else str(action.get("description", "影响仍待局势验证")), false, 15)
	var risk_heading := _text(actor_focus_detail_box, "传播风险", true, TYPE_SCALE.meta)
	risk_heading.add_theme_color_override("font_color", COLORS.accent)
	_text(actor_focus_detail_box, str(action.get("risk", "尚未发现明确风险")), false, 15)
	var timing := str(action.get("timing", ""))
	if timing != "":
		_text(actor_focus_detail_box, "时机 · %s" % timing, true, 14)

	var primary_label := "按此条件交付情报" if term_label != "" else ("以情报换取解瘴丹" if action.get("kind", "") == "recover" else "把这句话告诉他")
	if action.get("kind", "") == "escort":
		primary_label = "按约随队出发"
	elif action.get("kind", "") == "route":
		primary_label = "%s · 确认" % action.get("name", "确认路线选择")
	var primary := _ornate_button(primary_label, _consider_action.bind(action))
	primary.custom_minimum_size = Vector2(300, 54)
	actor_focus_footer.add_child(primary)
	var duration := _text(actor_focus_footer, "耗时 · %d 日" % int(action.get("duration", 1)), false, 15)
	duration.autowrap_mode = TextServer.AUTOWRAP_OFF
	duration.custom_minimum_size.x = 110
	duration.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var warning := _text(actor_focus_footer, "送出后不可撤回", false, 14)
	warning.autowrap_mode = TextServer.AUTOWRAP_OFF
	warning.custom_minimum_size.x = 150
	warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning.add_theme_color_override("font_color", COLORS.danger)


func _location_context_actions(actions: Array) -> Array:
	var result: Array = []
	for action in actions:
		var category := str(action.get("category", "other"))
		if str(action.get("kind", "")) == "tell" or category == "move":
			continue
		result.append(action)
	return result


func _render_first_day_route_compass(actions: Array, parent: VBoxContainer = null) -> void:
	if int(current_view.get("day", 0)) > 1:
		return
	if parent == null:
		parent = actions_box
	var has_verify := not _action_by_id(actions, "verify:F02").is_empty()
	var has_antidote := false
	for action in actions:
		if str(action.get("kind", "")) == "buy" and str(action.get("target_id", "")) == "antidote":
			has_antidote = true
			break
	if not has_verify and not has_antidote:
		return
	var panel := PanelContainer.new()
	var style := _panel_style(Color(COLORS.panel_alt, 0.26), 0, 2, Color.TRANSPARENT, 10, 4)
	style.border_width_left = 2
	style.border_color = Color(COLORS.accent, 0.64)
	panel.add_theme_stylebox_override("panel", style)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	var heading := _text(content, "起手任选 · 查日期 / 备丹药 / 找人传话　—　情报可靠 / 保留入谷 / 影响人物安排", false, 12)
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_color_override("font_color", COLORS.accent)
	parent.add_child(panel)


func _add_contextual_choice(action: Dictionary) -> void:
	var label := str(action.get("name", "做一件事"))
	if action.get("id", "") == "verify:F02":
		label = "查明日期 · 核验成熟传闻"
	elif action.get("kind", "") == "buy" and action.get("target_id", "") == "antidote":
		label = "备好入谷药 · 购买解瘴丹"
	elif action.get("kind", "") == "recover":
		label = "交出已核实日期 → 获得解瘴丹"
	elif action.get("kind", "") == "cultivate":
		var combat := int(current_view.get("player", {}).get("resources", {}).get("combat", 0))
		label = "修炼至下一阶段 · 战力 %d → %d" % [combat, combat + 1]
	if action.get("id", "") == "wait:next":
		label = "静候下一阵风声"
	elif int(action.get("completion_day", 0)) > 0:
		label += "　·　%d 日 · 第 %d 日完成" % [int(action.get("duration", 1)), int(action.get("completion_day", 0))]
	var callback := _consider_action.bind(action, "wait:complete") if action.get("kind", "") == "cultivate" else _consider_action.bind(action)
	var button := _action_button(label, callback)
	button.custom_minimum_size.y = 44
	button.tooltip_text = str(action.get("description", ""))
	actions_box.add_child(button)
	var description := str(action.get("description", ""))
	if description != "":
		_text(actions_box, description, true, 13)


func _toggle_all_actions() -> void:
	show_all_actions = not show_all_actions
	_render_actions(available_actions_cache)


func _render_focused_actor_summary(focused_actions: Array) -> void:
	var actor := _actor_by_id(current_view.get("known_actors", []), focused_actor_id)
	if actor.is_empty():
		return
	var panel := PanelContainer.new()
	var summary_style := _panel_style(Color(COLORS.panel_alt, 0.34), 0, 2, Color.TRANSPARENT, 13, 10)
	summary_style.border_width_left = 2
	summary_style.border_color = Color(COLORS.accent, 0.56)
	panel.add_theme_stylebox_override("panel", summary_style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	var role_line := _text(content, "%s · %s" % [actor.get("public_role", "可交谈人物"), actor.get("faction", "散修")], true, 13)
	role_line.add_theme_color_override("font_color", COLORS.accent)
	_text(content, str(actor.get("public_profile", "公开资料尚未收集")), false, 14)
	var state_names := {"neutral": "平静", "alert": "正在留意你", "troubled": "正在权衡消息", "decisive": "已经形成决断"}
	var expression := str(actor_expression_by_id.get(focused_actor_id, "alert"))
	var state_line := _text(content, "当前状态 · %s · 可谈线索 %d 条" % [state_names.get(expression, expression), focused_actions.size()], false, 13)
	state_line.add_theme_color_override("font_color", COLORS.success if expression == "decisive" else COLORS.muted)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 5)
	content.add_child(details)
	var focus: Array = actor.get("public_focus", [])
	if not focus.is_empty():
		_text(details, "关注 · %s" % "、".join(focus), true, 13)
	_text(details, "传播风险 · %s" % actor.get("public_risk", "尚不了解"), true, 13)
	details.visible = focused_actor_details_visible
	content.add_child(_utility_button("收起判断依据" if focused_actor_details_visible else "查看判断依据", _toggle_focused_actor_details))
	actions_box.add_child(panel)


func _toggle_focused_actor_details() -> void:
	focused_actor_details_visible = not focused_actor_details_visible
	_render_actions(available_actions_cache)


func _set_action_category(category: String) -> void:
	active_action_category = category
	_render_actions(available_actions_cache)


func _count_tell_actions(actions: Array, actor_id: String, fact_id: String) -> int:
	var count := 0
	for action in actions:
		if action.get("kind", "") not in ["tell", "recover", "escort", "route"]:
			continue
		if actor_id != "" and str(action.get("target_id", "")) != actor_id:
			continue
		if fact_id != "" and str(action.get("fact_id", "")) != fact_id:
			continue
		count += 1
	return count


func _focused_information_actions(actions: Array) -> Array:
	var result: Array = []
	for action in actions:
		if action.get("kind", "") not in ["tell", "recover", "escort", "route"]:
			continue
		if focused_actor_id != "" and str(action.get("target_id", "")) != focused_actor_id:
			continue
		if focused_fact_id != "" and str(action.get("fact_id", "")) != focused_fact_id:
			continue
		result.append(action)
	return result


func _add_focused_information_actions(actions: Array) -> void:
	for index in actions.size():
		var action: Dictionary = actions[index]
		if focused_actor_id != "":
			if action.get("kind", "") in ["recover", "escort", "route"]:
				_text(actions_box, str(action.get("name", "以情报换取解瘴丹")), false, 16)
				_text(actions_box, str(action.get("description", "交出情报并换取入谷所需物品")), true, 13)
			else:
				_text(actions_box, str(action.get("fact_claim", "未知线索")), false, 16)
		else:
			_text(actions_box, "%s · %s" % [action.get("target_name", "某人"), action.get("target_role", "可交谈人物")], false, 16)
		var relevance := _text(actions_box, str(action.get("relevance", "尚不了解这条消息会在对方心里留下什么")), false, 13)
		relevance.add_theme_color_override("font_color", COLORS.accent)
		var button_label := ""
		if action.get("kind", "") == "recover":
			button_label = "交出已核实日期 → 获得解瘴丹"
			var warning_line := _text(actions_box, "代价 · 消息送出后不可撤回", false, 13)
			warning_line.add_theme_color_override("font_color", COLORS.danger)
		elif action.get("kind", "") == "escort":
			button_label = "按约随队出发"
		elif action.get("kind", "") == "route":
			button_label = str(action.get("name", "做出路线决定"))
		else:
			var term_label := str(action.get("term_label", ""))
			button_label = ("按“%s”交付情报" % term_label) if term_label != "" else ("把这句话告诉他" if focused_actor_id != "" else "告诉%s" % action.get("target_name", "对方"))
		if int(action.get("completion_day", 0)) > 0:
			button_label += " · %d 日" % int(action.get("duration", 1))
		var tell_button := _action_button(button_label, _consider_action.bind(action))
		tell_button.tooltip_text = "%s\n%s" % [action.get("timing", ""), action.get("risk", "")]
		actions_box.add_child(tell_button)
		if index < actions.size() - 1:
			var separator := HSeparator.new()
			separator.modulate = COLORS.line
			actions_box.add_child(separator)


func _focus_actor_actions(actor_id: String, actor_name: String) -> void:
	focused_actor_id = actor_id
	focused_actor_name = actor_name
	focused_actor_action_id = ""
	focused_fact_id = ""
	focused_fact_claim = ""
	focused_actor_details_visible = false
	stage_actor_id = actor_id
	stage_actor_name = actor_name
	_focus_portrait(actor_id)
	_render_stage_people(current_view.get("known_actors", []), available_actions_cache)
	_render_actions(available_actions_cache)


func _action_has_visible_entry(action: Dictionary) -> bool:
	var kind := str(action.get("kind", ""))
	if kind == "move":
		return str(action.get("target_id", "")) != ""
	if kind in ["tell", "recover", "escort", "route"]:
		return str(action.get("target_id", "")) != ""
	return kind != ""


func _focus_actor_from_reference(actor_id: String, actor_name: String) -> void:
	_set_visual_mode("location")
	audio_director.play_ui()
	_focus_actor_actions(actor_id, actor_name)


func _focus_fact_actions(fact_id: String, fact_claim: String) -> void:
	focused_fact_id = fact_id
	focused_fact_claim = fact_claim
	focused_actor_id = ""
	focused_actor_name = ""
	_render_actions(available_actions_cache)


func _clear_action_focus() -> void:
	_reset_action_focus()
	_render_actions(available_actions_cache)


func _reset_action_focus() -> void:
	focused_actor_id = ""
	focused_actor_name = ""
	focused_actor_action_id = ""
	focused_fact_id = ""
	focused_fact_claim = ""
	focused_actor_details_visible = false
	show_all_actions = false


func _reconcile_action_focus(actors: Array, clues: Array) -> void:
	if focused_actor_id != "":
		var actor_still_here := false
		for actor in actors:
			if str(actor.get("id", "")) == focused_actor_id:
				actor_still_here = true
				break
		if not actor_still_here:
			focused_actor_id = ""
			focused_actor_name = ""
			focused_actor_action_id = ""
	if focused_fact_id != "":
		var fact_still_known := false
		for clue in clues:
			if str(clue.get("fact_id", "")) == focused_fact_id:
				fact_still_known = true
				break
		if not fact_still_known:
			focused_fact_id = ""
			focused_fact_claim = ""


func _add_information_actions(actions: Array) -> void:
	var tell_groups := {}
	for action in actions:
		if action.get("kind", "") != "tell":
			_add_action_button(action)
			continue
		var target := str(action.get("target_name", "某人"))
		if not tell_groups.has(target):
			tell_groups[target] = []
		tell_groups[target].append(action)
	for target in tell_groups:
		var facts: Array = tell_groups[target]
		if facts.size() == 1:
			var action: Dictionary = facts[0]
			var button := _action_button("向%s传递线索" % target, _consider_action.bind(action))
			button.tooltip_text = "%s\n%s\n%s" % [action.get("description", ""), action.get("relevance", ""), action.get("risk", "")]
			actions_box.add_child(button)
			_text(actions_box, "“%s”" % action.get("fact_claim", "未知线索"), true, 14)
			_add_action_decision_context(actions_box, action, true)
		else:
			var menu := MenuButton.new()
			menu.text = "向%s传递线索…（%d 条）" % [target, facts.size()]
			menu.custom_minimum_size.y = 42
			_style_menu_button(menu)
			menu.get_popup().id_pressed.connect(_on_tell_fact_selected.bind(facts))
			for index in facts.size():
				menu.get_popup().add_item(str(facts[index].get("fact_claim", "一条线索")), index)
			actions_box.add_child(menu)


func _add_action_button(action: Dictionary) -> void:
	var duration := int(action.get("duration", 1))
	var label := str(action.get("name", "行动"))
	if action.get("id", "") == "wait:next":
		label += "　· 直至新变化"
	elif int(action.get("completion_day", 0)) > 0:
		label += "　· 第 %d 日完成" % int(action.get("completion_day", 0))
	else:
		label += "　· %d 日" % duration
	var list_costs: Dictionary = action.get("costs", {})
	if int(list_costs.get("spirit_stones", 0)) > 0:
		label += "　· 灵石 %d" % int(list_costs.get("spirit_stones", 0))
	var button := _action_button(label, _consider_action.bind(action))
	button.tooltip_text = str(action.get("description", ""))
	actions_box.add_child(button)
	_add_action_decision_context(actions_box, action, true)


func _add_action_decision_context(parent: VBoxContainer, action: Dictionary, compact: bool = false) -> void:
	if not compact and int(action.get("completion_day", 0)) > 0:
		_text(parent, "完成 · 第 %d 日结束时" % int(action.get("completion_day", 0)), false, 15)
	var outcomes := _joined_action_values(action.get("expected_outcomes", []))
	if outcomes != "":
		var outcome_line := _text(parent, "预期 · %s" % outcomes, false, 14)
		outcome_line.add_theme_color_override("font_color", COLORS.success)
	var resolves := _joined_action_values(action.get("resolves", []))
	if resolves != "" and not compact:
		_text(parent, "解决 · %s" % resolves, true, 14)
	var known_conditions := _joined_action_values(action.get("known_conditions", []))
	if known_conditions != "" and not compact:
		var known_line := _text(parent, "已满足 · %s" % known_conditions, true, 14)
		known_line.add_theme_color_override("font_color", COLORS.success)
	var unknowns := _joined_action_values(action.get("unknowns", []))
	if unknowns != "" and not compact:
		var unknown_line := _text(parent, "仍未知 · %s" % unknowns, true, 14)
		unknown_line.add_theme_color_override("font_color", COLORS.accent)
	var timing := str(action.get("timing", ""))
	if timing != "":
		var timing_line := _text(parent, "时间 · %s" % timing, true, 14)
		if timing.contains("挤压") or timing.contains("来不及") or timing.contains("无法预先保证"):
			timing_line.add_theme_color_override("font_color", COLORS.danger)
		else:
			timing_line.add_theme_color_override("font_color", COLORS.accent)


func _joined_action_values(values: Variant) -> String:
	if not values is Array:
		return ""
	var parts: Array[String] = []
	for value in values:
		parts.append(str(value))
	return "、".join(parts)


func _on_tell_fact_selected(index: int, facts: Array) -> void:
	if index >= 0 and index < facts.size():
		_consider_action(facts[index])


func _consider_action(action: Dictionary, followup_action_id := "") -> void:
	var kind := str(action.get("kind", ""))
	var warnings = action.get("warnings", [])
	if not _action_needs_confirmation(action):
		_execute_action(str(action.get("id", "")), followup_action_id)
		return
	selected_action = action
	selected_followup_action_id = followup_action_id
	_clear(confirmation_box)
	var eyebrow := _text(confirmation_box, "一念将定", true, 13)
	eyebrow.add_theme_color_override("font_color", COLORS.accent)
	_text(confirmation_box, str(action.get("name", "行动")), false, 27)
	if action.get("id", "") == "wait:next":
		var warning := _text(confirmation_box, "你会放下手边的事，直到新的风声找上门来。", false, 15)
		warning.add_theme_color_override("font_color", COLORS.accent)
	else:
		_text(confirmation_box, str(action.get("description", "")), true, 15)
	var outcomes := _joined_action_values(action.get("expected_outcomes", []))
	if outcomes != "":
		var outcome_line := _text(confirmation_box, "此举或将 · %s" % outcomes, false, 15)
		outcome_line.add_theme_color_override("font_color", COLORS.success)
	var timing := str(action.get("timing", ""))
	if timing != "":
		var timing_line := _text(confirmation_box, "时机 · %s" % timing, true, 14)
		if timing.contains("挤压") or timing.contains("来不及") or timing.contains("无法预先保证"):
			timing_line.add_theme_color_override("font_color", COLORS.danger)
	if warnings is Array:
		for warning_text in warnings:
			var warning_line := _text(confirmation_box, "注意 · %s" % warning_text, false, 14)
			warning_line.add_theme_color_override("font_color", COLORS.danger)
	if bool(action.get("irreversible", false)):
		var irreversible_line := _text(confirmation_box, "不可撤回 · 行动产生的公开信息与交换结果会保留", false, 14)
		irreversible_line.add_theme_color_override("font_color", COLORS.danger)
	var costs: Dictionary = action.get("costs", {})
	if not costs.is_empty():
		var cost_names := {"spirit_stones": "灵石", "credit": "信用", "combat": "战力", "support": "助力"}
		var cost_parts: Array[String] = []
		for key in costs:
			cost_parts.append("%s %s" % [cost_names.get(key, key), costs[key]])
		var cost_line := _text(confirmation_box, "消耗：" + "、".join(cost_parts), false, 15)
		cost_line.add_theme_color_override("font_color", COLORS.danger)
	confirmation_details_button = _utility_button("展开盘算", _toggle_confirmation_details)
	confirmation_details_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	confirmation_box.add_child(confirmation_details_button)
	confirmation_details_box = VBoxContainer.new()
	confirmation_details_box.add_theme_constant_override("separation", 6)
	confirmation_details_box.hide()
	confirmation_box.add_child(confirmation_details_box)
	_add_action_decision_context(confirmation_details_box, action)
	if kind == "tell":
		_text(confirmation_details_box, "%s · %s" % [action.get("target_name", "某人"), action.get("target_role", "可交谈人物")], false, 15)
		var relevance_line := _text(confirmation_details_box, str(action.get("relevance", "关联尚不明确")), false, 14)
		relevance_line.add_theme_color_override("font_color", COLORS.accent)
		_text(confirmation_details_box, "使用倾向 · %s" % action.get("risk", "尚不了解"), true, 14)
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	confirmation_box.add_child(button_row)
	var cancel_button := _utility_button("暂且不动", _cancel_confirmation)
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(cancel_button)
	var confirm_button := _button(_commitment_label(action), _confirm_selected_action, false)
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(confirm_button)
	if action_dock:
		action_dock.hide()
	confirmation_layer.show()
	_sync_action_canvas_visibility()


func _action_needs_confirmation(action: Dictionary) -> bool:
	var warnings = action.get("warnings", [])
	var has_warnings: bool = warnings is Array and not warnings.is_empty()
	var kind := str(action.get("kind", ""))
	return not action.get("costs", {}).is_empty() or bool(action.get("irreversible", false)) or has_warnings or kind in ["move", "tell", "recover", "escort", "route"] or action.get("id", "") == "wait:next"


func _toggle_confirmation_details() -> void:
	if not confirmation_details_box or not confirmation_details_button:
		return
	confirmation_details_box.visible = not confirmation_details_box.visible
	confirmation_details_button.text = "收起盘算" if confirmation_details_box.visible else "展开盘算"


func _commitment_label(action: Dictionary) -> String:
	if action.get("id", "") == "wait:next":
		return "静候其变"
	match str(action.get("kind", "")):
		"cultivate":
			return "闭关至下一阶段"
		"tell":
			return "传出此话"
		"move":
			return "即刻启程"
		"escort":
			return "按约随队出发"
		"route":
			return "确认这个选择"
		"advance":
			return "就此落子"
	return "就这么做"


func _confirm_selected_action() -> void:
	var action_id := str(selected_action.get("id", ""))
	var followup_action_id := selected_followup_action_id
	selected_action = {}
	selected_followup_action_id = ""
	confirmation_layer.hide()
	_execute_action(action_id, followup_action_id)


func _cancel_confirmation() -> void:
	selected_action = {}
	selected_followup_action_id = ""
	confirmation_layer.hide()
	_sync_action_canvas_visibility()


func _render_feedback_evidence_into(parent: VBoxContainer, feedback: Dictionary) -> void:
	var days := int(feedback.get("days_advanced", 0))
	if days > 0:
		var time_line := _text(parent, "经过 · %d 日" % days, true, 13)
		time_line.add_theme_color_override("font_color", COLORS.accent)
	var quiet_days := int(feedback.get("quiet_days", 0))
	if quiet_days > 0:
		_text(parent, "其中 %d 日没有新的公开变化" % quiet_days, true, 13)
	var influences: Array = feedback.get("influence", [])
	for influence in influences:
		for change in influence.get("changes", []):
			_text(parent, "原本 · %s" % change.get("without_information", "其他安排"), true, 13)
			var current_line := _text(parent, "改为 · %s" % change.get("with_information", "新的安排"), false, 14)
			current_line.add_theme_color_override("font_color", COLORS.success)


func _render_ending(ending: Dictionary) -> void:
	_clear(ending_box)
	var location_profile: LocationVisualProfile = presentation_registry.location_profile(str(current_view.get("location", {}).get("scene_key", "")))
	ending_background.texture = location_profile.background if location_profile and location_profile.background else null
	var outcome := str(ending.get("outcome", current_view.get("outcome", "旅程结束")))
	var influences: Array = ending.get("influence", [])
	var ending_actor_id := ""
	for actor in current_view.get("known_actors", []):
		var actor_name := str(actor.get("name", ""))
		if actor_name != "" and outcome.contains(actor_name):
			ending_actor_id = str(actor.get("id", ""))
			break
	if ending_actor_id == "":
		ending_actor_id = last_causal_actor_id
	if ending_actor_id == "" and not influences.is_empty():
		ending_actor_id = _actor_id_by_name(str(influences[0].get("actor_name", "")))
	var actor_profile: ActorVisualProfile = presentation_registry.actor_profile(ending_actor_id)
	ending_portrait.texture = actor_profile.portrait("decisive") if actor_profile else null
	ending_portrait.visible = ending_portrait.texture != null
	ending_box.anchor_left = 0.445 if ending_portrait.visible else 0.225
	var eyebrow := _text(ending_box, "尘埃落定", true, 16)
	eyebrow.add_theme_color_override("font_color", COLORS.accent)
	var title := _text(ending_box, outcome, false, 40)
	title.add_theme_color_override("font_color", Color("ead6a8"))
	var rule := HSeparator.new()
	rule.modulate = Color(COLORS.accent, 0.46)
	ending_box.add_child(rule)
	var consequences: Array = ending.get("player_consequences", [])
	if not consequences.is_empty():
		var gain_heading := _text(ending_box, "这次选择最终为你带来了什么", true, 16)
		gain_heading.add_theme_color_override("font_color", COLORS.accent)
		for consequence in consequences:
			_text(ending_box, str(consequence), false, 17)
	var review: Array = ending.get("review", [])
	if not review.is_empty():
		var review_heading := _text(ending_box, "为什么是这个结果", true, 16)
		review_heading.add_theme_color_override("font_color", COLORS.accent)
		_text(ending_box, str(review[0]), false, 16)
	if not influences.is_empty():
		var impact_heading := _text(ending_box, "你的介入留下了这些痕迹", true, 16)
		impact_heading.add_theme_color_override("font_color", COLORS.accent)
	for influence in influences:
		_text(ending_box, "你将“%s”告诉了%s。" % [influence.get("fact_claim", "消息"), influence.get("actor_name", "某人")], false, 17)
		var timeline_grid := GridContainer.new()
		timeline_grid.columns = 2
		timeline_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		timeline_grid.add_theme_constant_override("h_separation", 18)
		timeline_grid.add_theme_constant_override("v_separation", 9)
		ending_box.add_child(timeline_grid)
		for change in influence.get("changes", []):
			var day_mark := _text(timeline_grid, "第 %d 日" % int(change.get("day", 0)), false, 16)
			day_mark.custom_minimum_size.x = 78
			day_mark.add_theme_color_override("font_color", COLORS.accent)
			var change_line := _text(timeline_grid, "原本%s；后来%s。" % [change.get("without_information", "另有安排"), change.get("with_information", "改变计划")], true, 16)
			change_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if influences.is_empty():
		_text(ending_box, "这一次没有观察到你传递的消息改写他人计划。", true, 16)
	else:
		_text(ending_box, "局势已经落定，但被你改变的计划会成为下一段旅途的起点。", true, 16)
	ending_annex_button = _action_button("回看本局选择与余波", _toggle_ending_annex)
	ending_annex_button.custom_minimum_size.y = 42
	ending_annex_button.add_theme_font_size_override("font_size", 16)
	ending_box.add_child(ending_annex_button)
	ending_annex_box = VBoxContainer.new()
	ending_annex_box.add_theme_constant_override("separation", 6)
	ending_annex_box.hide()
	ending_box.add_child(ending_annex_box)
	var record_heading := _text(ending_annex_box, "你的路线与余波记录", true, 16)
	record_heading.add_theme_color_override("font_color", COLORS.accent)
	for index in range(1, review.size()):
		_text(ending_annex_box, "· %s" % review[index], true, 15)
	for highlight in ending.get("highlights", []):
		if str(highlight).begins_with("你传递的消息改变了"):
			continue
		_text(ending_annex_box, "· %s" % highlight, true, 15)
	var ending_actions := HBoxContainer.new()
	ending_actions.add_theme_constant_override("separation", 12)
	ending_box.add_child(ending_actions)
	var restart_button := _ornate_button("换一条路 · 重新入局", _restart_from_ending)
	restart_button.custom_minimum_size = Vector2(330, 62)
	restart_button.add_theme_font_size_override("font_size", 22)
	restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ending_actions.add_child(restart_button)
	var return_button := _utility_button("返回卷首", _return_to_start)
	return_button.custom_minimum_size = Vector2(132, 62)
	return_button.add_theme_font_size_override("font_size", 16)
	ending_actions.add_child(return_button)
	ending_layer.show()
	_sync_action_canvas_visibility()


func _toggle_ending_annex() -> void:
	if not ending_annex_box or not ending_annex_button:
		return
	ending_annex_box.visible = not ending_annex_box.visible
	ending_annex_button.text = "收起本局选择与余波" if ending_annex_box.visible else "回看本局选择与余波"
