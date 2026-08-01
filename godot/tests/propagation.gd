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

	app.name_input.text = "传播烟测修士"
	app._new_game()
	if not await _wait_until_idle():
		return _fail("new game request timed out")
	for action_id in ["verify:F02", "wait:complete", "move:L02", "tell:N03:F01"]:
		if not await _execute(action_id):
			return
	if app.timing_label.text != "第21天子时 · 已核实":
		return _fail("verified timing is not visible in the header")
	for action in app.current_view.get("available_actions", []):
		if action.get("id", "") == "tell:N03:F01":
			return _fail("delivered clue is still available")
	app._focus_actor_actions("N03", "沈砚秋")
	for action in app._focused_information_actions(app.available_actions_cache):
		if action.get("fact_id", "") == "F01":
			return _fail("actor focus still shows the delivered clue")
	app._clear_action_focus()
	for index in 4:
		if not await _execute("wait:next"):
			return

	if not bool(app.current_view.get("resolved", false)):
		return _fail("propagation route did not resolve")
	var actions = app.current_view.get("available_actions", null)
	if not actions is Array or not actions.is_empty():
		return _fail("resolved view actions are not an empty array")
	if not app.ending_layer.visible:
		return _fail("ending overlay is not visible")
	if "沈砚秋" not in str(app.current_view.get("outcome", "")):
		return _fail("unexpected propagation outcome")
	if "准备值" in str(app.current_view.get("outcome", "")):
		return _fail("ending leaked an internal score")
	print("Godot propagation journey passed: ending visible on day %d" % app.current_view.get("day", 0))
	quit(0)


func _execute(action_id: String) -> bool:
	var action := _find_action(action_id)
	if action.is_empty():
		_fail("missing action: " + action_id)
		return false
	app._consider_action(action)
	if app.confirmation_layer.visible:
		app._confirm_selected_action()
	if not await _wait_until_idle(15000):
		_fail("action timed out: " + action_id)
		return false
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
		if app.pending_operation == "":
			await process_frame
			if app.pending_operation == "":
				return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
