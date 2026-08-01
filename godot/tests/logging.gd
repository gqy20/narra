extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_resource := load("res://main.tscn")
	if scene_resource == null:
		return _fail("could not load main scene")
	var game = scene_resource.instantiate()
	root.add_child(game)
	await process_frame

	if game._redact_log_field("shutdown_token", "unsafe") != "[REDACTED]":
		return _fail("sensitive client log field was not redacted")
	if game._redact_log_text("https://example.test/path?secret=unsafe").contains("unsafe"):
		return _fail("client log URL query was not redacted")

	var original_path: String = game.client_log_path
	var original_level: String = game.log_level
	var test_path: String = game.logs_dir.path_join("client-rotation-test.log")
	var before_archives := _client_archives(game.archived_logs_dir)
	var oversized := FileAccess.open(test_path, FileAccess.WRITE)
	if oversized == null:
		return _fail("could not create oversized client test log")
	oversized.resize(game.LOG_MAX_MIB * 1024 * 1024)
	oversized = null
	game.client_log_path = test_path
	game.log_level = "INFO"
	game._log_event("INFO", "rotation_test", "trigger rotation")
	if not FileAccess.file_exists(test_path) or not FileAccess.get_file_as_string(test_path).contains("rotation_test"):
		return _fail("client log was not recreated after rotation")
	var after_archives := _client_archives(game.archived_logs_dir)
	if after_archives.size() <= before_archives.size():
		return _fail("oversized client log was not archived")

	var current_size: int = game._file_size(test_path)
	game.log_level = "ERROR"
	game._log_event("DEBUG", "filtered_debug", "must not be written")
	if game._file_size(test_path) != current_size:
		return _fail("client log level did not filter DEBUG")

	var original_recovery_path: String = game.recovery_log_path
	var recovery_path: String = game.logs_dir.path_join("client-recovery-test.log")
	game.log_level = "INFO"
	game.client_log_path = game.logs_dir
	game.recovery_log_path = recovery_path
	game.client_log_failure_reported = false
	game._log_event("ERROR", "write_failure_test", "trigger fallback")
	if not game.client_log_failure_reported or not FileAccess.file_exists(recovery_path):
		return _fail("client log write failure did not use recovery output")

	game.client_log_path = original_path
	game.log_level = original_level
	game.recovery_log_path = original_recovery_path
	game.client_log_failure_reported = false
	DirAccess.remove_absolute(test_path)
	DirAccess.remove_absolute(recovery_path)
	for archive_name in after_archives:
		if not before_archives.has(archive_name):
			DirAccess.remove_absolute(game.archived_logs_dir.path_join(archive_name))
	print("Godot client logging verification passed.")
	game.queue_free()
	quit(0)


func _client_archives(directory: String) -> Array[String]:
	var result: Array[String] = []
	var access := DirAccess.open(directory)
	if access != null:
		for file_name in access.get_files():
			if file_name.begins_with("client-") and file_name.ends_with(".log"):
				result.append(file_name)
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
