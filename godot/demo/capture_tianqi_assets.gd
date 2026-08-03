extends SceneTree

var app


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if not await _wait_until_idle():
		return _fail("tianqi health request timed out")
	await _settle_layout()
	if not await _capture("tianqi-start-2048x1152.png"):
		return
	app.name_input.text = "会勘抄手"
	app._new_game()
	if not await _wait_until_idle():
		return _fail("tianqi new game request timed out")
	app.game_screen_controller._set_visual_mode("location")
	await _settle_layout()
	if not await _capture("tianqi-location-2048x1152.png"):
		return
	app.game_screen_controller._set_visual_mode("map")
	await _settle_layout()
	if not await _capture("tianqi-map-2048x1152.png"):
		return
	app.journal_panel_controller._open_journal()
	app.journal_panel_controller._select_journal_tab(1)
	await _settle_layout()
	if not await _capture("tianqi-evidence-2048x1152.png"):
		return
	print("Tianqi asset integration screenshots captured.")
	quit(0)


func _capture(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	var output_dir := ProjectSettings.globalize_path("res://../artifacts/screenshots")
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create screenshot directory")
		return false
	var image: Image = app.get_viewport().get_texture().get_image()
	if image.save_png(output_dir.path_join(file_name)) != OK:
		_fail("could not save screenshot: " + file_name)
		return false
	return true


func _settle_layout() -> void:
	for index in 5:
		await process_frame


func _wait_until_idle(timeout_ms := 12000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if app.pending_operation == "" and not app.presentation_busy and not app.cinematic_director.active:
			await process_frame
			if app.pending_operation == "" and not app.presentation_busy and not app.cinematic_director.active:
				return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
