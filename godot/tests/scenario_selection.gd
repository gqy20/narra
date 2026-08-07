extends SceneTree


func _initialize() -> void:
	var process = load("res://scripts/local_server_process.gd").new()
	var selected: String = process.resolve_data_dir({"scenario": "second-story"}, "C:/Games/Narra")
	if selected != "C:/Games/Narra/data/second-story":
		return _fail("scenario selector did not resolve under the installed data root: " + selected)
	var explicit: String = process.resolve_data_dir({"scenario": "ignored", "data_dir": "D:/Stories/demo"}, "C:/Games/Narra")
	if explicit != "D:/Stories/demo":
		return _fail("explicit data directory was not preserved: " + explicit)
	if process.resolve_data_dir({"scenario": "../outside"}, "C:/Games/Narra") != "":
		return _fail("relative scenario traversal was accepted")
	if not process.supports_bundled_server("Windows") or process.server_name_for_platform("Windows") != "narra-server.exe":
		return _fail("Windows bundled server naming is invalid")
	if not process.supports_bundled_server("macOS") or process.server_name_for_platform("macOS") != "narra-server":
		return _fail("macOS bundled server naming is invalid")
	if not process.supports_bundled_server("Linux") or process.server_name_for_platform("Linux") != "narra-server":
		return _fail("Linux bundled server naming is invalid")
	if process.supports_bundled_server("Web") or process.server_name_for_platform("Web") != "":
		return _fail("unsupported platforms should not select a bundled server")
	process.free()
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
