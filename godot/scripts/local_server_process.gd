class_name LocalServerProcess
extends Node

signal log_event(level: String, event: String, message: String, fields: Dictionary)

const SERVER_NAME := "narra-server.exe"

var pid := -1
var data_dir := ""


func start(config: Dictionary) -> int:
	if OS.has_feature("editor") or OS.get_name() != "Windows":
		return pid
	var install_dir := OS.get_executable_path().get_base_dir()
	var server_path := install_dir.path_join(SERVER_NAME)
	if not FileAccess.file_exists(server_path):
		push_error("Bundled game server is missing: %s" % server_path)
		return pid
	data_dir = resolve_data_dir(config, install_dir)
	if data_dir == "" or not DirAccess.dir_exists_absolute(data_dir):
		push_error("Scenario data directory is missing: %s" % data_dir)
		return pid
	var runtime_root := str(config.get("runtime_root", ""))
	var logs_dir := str(config.get("logs_dir", ""))
	pid = OS.create_process(
		server_path,
		PackedStringArray([
			"-data", data_dir,
			"-saves", str(config.get("saves_dir", "")),
			"-log", logs_dir.path_join("server.log"),
			"-crash-dir", str(config.get("crash_dir", "")),
			"-log-max-mb", str(config.get("log_max_mib", 5)),
			"-log-backups", str(config.get("log_backups", 5)),
			"-log-level", str(config.get("log_level", "INFO")),
			"-version", str(config.get("build_version", "dev")),
			"-session-id", str(config.get("session_id", "")),
			"-shutdown-token", str(config.get("shutdown_token", "")),
			"-ai-settings", runtime_root.path_join(str(config.get("ai_settings_file", "ai-settings.json"))),
		]),
		false
	)
	if pid > 0:
		log_event.emit("INFO", "server_started", "bundled service process created", {
			"pid": pid,
			"data": data_dir,
			"saves": str(config.get("saves_dir", "")),
		})
	else:
		log_event.emit("ERROR", "server_start_failed", "could not create bundled service process", {"path": server_path})
	return pid


func resolve_data_dir(config: Dictionary, install_dir := "") -> String:
	var explicit_dir := str(config.get("data_dir", "")).strip_edges()
	if explicit_dir != "":
		return explicit_dir.simplify_path()
	var root := install_dir if install_dir != "" else OS.get_executable_path().get_base_dir()
	var scenario := str(config.get("scenario", "")).strip_edges()
	if scenario == "":
		scenario = _first_installed_scenario(root.path_join("data"))
	if scenario == "" or scenario.get_file() != scenario or scenario in [".", ".."]:
		return ""
	return root.path_join("data").path_join(scenario).simplify_path()


func _first_installed_scenario(data_root: String) -> String:
	var directory := DirAccess.open(data_root)
	if directory == null:
		return ""
	var candidates: Array[String] = []
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		if directory.current_is_dir() and not entry.begins_with("."):
			var scenario_root := data_root.path_join(entry)
			if FileAccess.file_exists(scenario_root.path_join("manifest.yml")) or FileAccess.file_exists(scenario_root.path_join("manifest.yaml")) or FileAccess.file_exists(scenario_root.path_join("manifest.json")):
				candidates.append(entry)
		entry = directory.get_next()
	directory.list_dir_end()
	candidates.sort()
	return candidates[0] if not candidates.is_empty() else ""


func is_running() -> bool:
	return pid > 0 and OS.is_process_running(pid)


func force_stop() -> void:
	if pid <= 0:
		return
	log_event.emit("WARN", "server_force_stop", "forcing bundled service to stop", {"pid": pid})
	OS.kill(pid)
	pid = -1


func shutdown(api_base: String, token: String) -> void:
	if pid <= 0:
		return
	var shutdown_http := HTTPRequest.new()
	shutdown_http.timeout = 1.5
	add_child(shutdown_http)
	var request_error := shutdown_http.request(
		api_base + "/server/shutdown",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify({"token": token})
	)
	if request_error == OK:
		var response: Array = await shutdown_http.request_completed
		log_event.emit("INFO", "server_shutdown_response", "shutdown endpoint completed", {
			"result": response[0],
			"status": response[1],
		})
		await get_tree().create_timer(0.5).timeout
	shutdown_http.queue_free()
	if OS.is_process_running(pid):
		log_event.emit("WARN", "server_shutdown_fallback", "service did not stop gracefully", {"pid": pid})
		OS.kill(pid)
	else:
		log_event.emit("INFO", "server_stopped", "bundled service stopped gracefully", {})
	pid = -1
