extends SceneTree


func _initialize() -> void:
	var process = load("res://scripts/local_server_process.gd").new()
	var selected: String = process.resolve_data_dir({"scenario": "second-story"}, "C:/Games/Fantu")
	if selected != "C:/Games/Fantu/data/second-story":
		return _fail("scenario selector did not resolve under the installed data root: " + selected)
	var explicit: String = process.resolve_data_dir({"scenario": "ignored", "data_dir": "D:/Stories/demo"}, "C:/Games/Fantu")
	if explicit != "D:/Stories/demo":
		return _fail("explicit data directory was not preserved: " + explicit)
	if process.resolve_data_dir({"scenario": "../outside"}, "C:/Games/Fantu") != "":
		return _fail("relative scenario traversal was accepted")
	process.free()
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
