extends SceneTree

var app


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if not await _wait_until_idle():
		return _fail("health request timed out")
	app.name_input.text = "烟测修士"
	app._new_game()
	if not await _wait_until_idle():
		return _fail("new game request timed out")
	app._set_visual_mode("location")
	await _settle_layout()
	if not await _capture("ui-overview-2048x1152.png"):
		return

	app._focus_actor_actions("N01", "李玄")
	await _settle_layout()
	if not await _capture("ui-actor-focus-2048x1152.png"):
		return
	print("UI state screenshots captured.")
	quit(0)


func _capture(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	var output_dir := ProjectSettings.globalize_path("res://../artifacts/screenshots")
	var directory_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if directory_error != OK:
		_fail("could not create screenshot directory")
		return false
	var image: Image = app.get_viewport().get_texture().get_image()
	var save_error: Error = image.save_png(output_dir.path_join(file_name))
	if save_error != OK:
		_fail("could not save screenshot: " + file_name)
		return false
	return true


func _settle_layout() -> void:
	for index in 4:
		await process_frame


func _wait_until_idle(timeout_ms := 10000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if app.pending_operation == "" and not app.presentation_busy:
			await process_frame
			if app.pending_operation == "" and not app.presentation_busy:
				return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
