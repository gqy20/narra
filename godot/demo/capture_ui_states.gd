extends SceneTree

var app
var capture_output_dir := ""
var capture_label := "2048x1152"


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output-dir="):
			capture_output_dir = argument.trim_prefix("--capture-output-dir=")
		elif argument.begins_with("--capture-label="):
			capture_label = argument.trim_prefix("--capture-label=")
	call_deferred("_run")


func _run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if not await _wait_until_idle():
		return _fail("health request timed out")
	app.cinematic_director.set_enabled(false)
	app.name_input.text = "烟测修士"
	app._new_game()
	if not await _wait_until_idle():
		return _fail("new game request timed out")
	if app.cinematic_director and app.cinematic_director.active:
		app.cinematic_director.skip()
		await _settle_layout()
	app.game_screen_controller._set_visual_mode("location")
	await _settle_layout()
	if not await _capture("ui-overview-%s.png" % capture_label):
		return
	app.game_screen_controller._set_visual_mode("map")
	await _settle_layout()
	if not await _capture("ui-map-%s.png" % capture_label):
		return
	app.game_screen_controller._set_visual_mode("location")
	app.journal_panel_controller._open_journal()
	app.journal_panel_controller._select_journal_tab(1)
	await _settle_layout()
	if not await _capture("ui-journal-%s.png" % capture_label):
		return
	app.journal_panel_controller._close_journal()

	app.action_panel_controller._focus_actor_actions("N01", "李玄")
	await _settle_layout()
	if not await _capture("ui-actor-focus-%s.png" % capture_label):
		return
	for action in app.available_actions_cache:
		if app.action_panel_controller._action_needs_confirmation(action):
			app.action_panel_controller._consider_action(action)
			await _settle_layout()
			if not await _capture("ui-confirmation-%s.png" % capture_label):
				return
			break
	print("UI state screenshots captured.")
	quit(0)


func _capture(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	var output_dir := capture_output_dir if capture_output_dir != "" else ProjectSettings.globalize_path("res://../artifacts/screenshots")
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
