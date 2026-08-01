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
	if app.current_view.is_empty():
		return _fail("new game returned no player view")
	var actions: Array = app.current_view.get("available_actions", [])
	if actions.is_empty():
		return _fail("new game returned no actions")
	if app.day_label.text != "第 1 / 30 日":
		return _fail("initial day is not player-facing day one")
	if app.timing_label.text != "第24天 · 传闻":
		return _fail("initial known timing is not visible")
	for action in actions:
		if action.get("id", "") == "wait:next":
			app._consider_action(action)
			if not app.confirmation_layer.visible:
				return _fail("multi-day advance has no confirmation")
			app._cancel_confirmation()
			break

	app._consider_action(actions[0])
	if app.confirmation_layer.visible:
		app._confirm_selected_action()
	if not await _wait_until_idle(12000):
		return _fail("action or autosave request timed out")
	if int(app.current_view.get("day", 0)) < 1:
		return _fail("action returned an invalid view")
	print("Godot integration smoke test passed: day %d, %d actions" % [app.current_view.get("day", 0), app.current_view.get("available_actions", []).size()])
	quit(0)


func _wait_until_idle(timeout_ms := 8000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if app.pending_operation == "":
			# The action callback can enqueue autosave in the same frame.
			await process_frame
			if app.pending_operation == "":
				return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
