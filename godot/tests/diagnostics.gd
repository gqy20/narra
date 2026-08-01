extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_resource := load("res://main.tscn")
	if scene_resource == null:
		_fail("could not load main scene")
		return
	var game = scene_resource.instantiate()
	root.add_child(game)
	await process_frame
	var archive_path: String = game._export_diagnostics(false)
	if archive_path == "" or not FileAccess.file_exists(archive_path):
		_fail("diagnostics archive was not created")
		return
	var reader := ZIPReader.new()
	if reader.open(archive_path) != OK:
		_fail("diagnostics archive could not be opened")
		return
	var files := reader.get_files()
	if not files.has("manifest.json") or not files.has("environment.json") or not files.has("logs/client.log"):
		_fail("diagnostics archive lacks its manifest or client log")
		return
	for file_name in files:
		if file_name.begins_with("saves/"):
			_fail("diagnostics archive contains save data")
			return
	var manifest = JSON.parse_string(reader.read_file("manifest.json").get_string_from_utf8())
	if not manifest is Dictionary or manifest.get("application", "") != "Fantu" or manifest.get("version", "") == "":
		_fail("diagnostics manifest is invalid")
		return
	var environment = JSON.parse_string(reader.read_file("environment.json").get_string_from_utf8())
	if not environment is Dictionary or not environment.has("processor_count") or not environment.has("graphics_adapter") or not environment.has("runtime_space_available_bytes"):
		_fail("diagnostics environment metadata is incomplete")
		return
	reader.close()
	DirAccess.remove_absolute(archive_path)
	print("Godot diagnostics export passed: %d files" % files.size())
	game.queue_free()
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
