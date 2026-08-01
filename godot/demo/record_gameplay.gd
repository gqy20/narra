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

	await _hold(1.8)
	var player_name := "听风客"
	app.name_input.text = ""
	for index in player_name.length():
		app.name_input.text += player_name.substr(index, 1)
		await _hold(0.08)
	await _hold(0.8)
	app._new_game()
	if not await _wait_until_idle():
		return _fail("new game request timed out")
	await _hold(2.0)

	app._set_visual_mode("location")
	await _hold(2.0)
	if not await _execute("verify:F02", 1.4, 1.8):
		return
	if not await _execute("wait:complete", 1.2, 1.8):
		return

	app._set_visual_mode("map")
	app._on_map_location_selected("L02")
	await _hold(2.0)
	if not await _execute("move:L02", 1.4, 1.5):
		return
	app._set_visual_mode("location")
	await _hold(2.0)

	app._focus_actor_actions("N03", "沈砚秋")
	await _hold(2.2)
	if not await _execute("tell:N03:F01:trust", 1.5, 2.3):
		return
	if not await _execute("wait:next", 1.2, 1.4):
		return
	if not app.causal_layer.visible:
		return _fail("causal theatre did not open")
	await _hold(4.2)
	app._dismiss_causal()
	await _hold(1.0)
	app._open_journal()
	await _hold(2.0)
	app._select_journal_tab(1)
	await _hold(1.4)
	app._select_journal_tab(2)
	await _hold(1.4)
	app._select_journal_tab(3)
	await _hold(2.0)
	app._toggle_journal_travel_details()
	await _hold(1.7)
	app._close_journal()

	app._clear_action_focus()
	for index in 3:
		if not await _execute("wait:next", 0.55, 0.9):
			return
	await _wait_until_presentations_finish()
	await _hold(2.8)
	quit(0)


func _execute(action_id: String, confirmation_hold: float, result_hold: float) -> bool:
	var action := _find_action(action_id)
	if action.is_empty():
		_fail("missing action: " + action_id)
		return false
	app._consider_action(action)
	if app.confirmation_layer.visible:
		await _hold(confirmation_hold)
		app._confirm_selected_action()
	if not await _wait_until_idle(15000):
		_fail("action timed out: " + action_id)
		return false
	await _hold(result_hold)
	return true


func _find_action(action_id: String) -> Dictionary:
	var actions = app.current_view.get("available_actions", [])
	if not actions is Array:
		return {}
	for action in actions:
		if action.get("id", "") == action_id:
			return action
	return {}


func _wait_until_idle(timeout_ms := 10000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if app.pending_operation == "" and not app.presentation_busy:
			await process_frame
			if app.pending_operation == "" and not app.presentation_busy:
				return true
	return false


func _hold(seconds: float) -> void:
	await create_timer(seconds).timeout


func _wait_until_presentations_finish() -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline and app.presentation_director.card.visible:
		await create_timer(0.2).timeout


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
