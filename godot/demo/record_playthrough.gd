extends SceneTree

const ROUTE_ARGUMENT_PREFIX := "--recording-route="
const DEFAULT_ROUTE := "res://demo/recordings/tianqi-evidence-route.json"

var app
var route: Dictionary = {}
var completed_actions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var route_path := _route_path_from_arguments()
	route = _load_route(route_path)
	if route.is_empty():
		return

	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if not await _wait_until_stable(15000, false):
		return _fail("health request timed out")

	var expected_scenario := str(route.get("scenario_id", ""))
	if expected_scenario != "" and str(app.scenario_info.get("id", "")) != expected_scenario:
		return _fail("recording route expected scenario %s but connected to %s" % [expected_scenario, app.scenario_info.get("id", "unknown")])

	for raw_step in route.get("steps", []):
		if not raw_step is Dictionary:
			return _fail("recording route contains a non-object step")
		if not await _run_step(raw_step):
			return

	print("PLAYTHROUGH_RECORDED route=%s day=%d actions=%d resolved=%s" % [
		route.get("id", "unnamed"),
		int(app.current_view.get("day", 0)),
		completed_actions,
		str(bool(app.current_view.get("resolved", false))).to_lower(),
	])
	quit(0)


func _run_step(step: Dictionary) -> bool:
	var kind := str(step.get("type", "")).strip_edges()
	match kind:
		"hold":
			await _hold(float(step.get("seconds", 1.0)))
		"new_game":
			app.name_input.text = str(route.get("player_name", "听风客"))
			app._new_game()
			if not await _wait_until_stable(30000, true):
				return _step_failure("new game or opening cinematic timed out")
			await _hold(float(step.get("after", 1.5)))
		"mode":
			app.game_screen_controller._set_visual_mode(str(step.get("value", "location")))
			await _hold(float(step.get("after", 1.0)))
		"select_location":
			app.game_screen_controller._set_visual_mode("map")
			app.game_screen_controller._on_map_location_selected(str(step.get("id", "")))
			await _hold(float(step.get("after", 1.0)))
		"action":
			if not await _execute_action(str(step.get("id", "")), step):
				return false
		"advance_until":
			var target_day := int(step.get("day", 0))
			while int(app.current_view.get("day", 0)) < target_day:
				if not await _execute_action("wait:next", step):
					return false
		"advance_until_resolved":
			var max_actions := int(step.get("max_actions", 20))
			var advances := 0
			while not bool(app.current_view.get("resolved", false)) and advances < max_actions:
				if not await _execute_action("wait:next", step):
					return false
				advances += 1
			if not bool(app.current_view.get("resolved", false)):
				return _step_failure("playthrough did not resolve after %d advance actions" % max_actions)
		"journal":
			app.journal_panel_controller._open_journal()
			await _hold(0.8)
			app.journal_panel_controller._select_journal_tab(int(step.get("tab", 0)))
			await _hold(float(step.get("after", 2.0)))
		"close_journal":
			app.journal_panel_controller._close_journal()
			await _hold(float(step.get("after", 0.8)))
		_:
			return _step_failure("unknown recording step type: " + kind)
	return true


func _execute_action(action_id: String, timing: Dictionary) -> bool:
	var action := _find_action(action_id)
	if action.is_empty():
		return _step_failure("missing action %s on day %d at %s; available=%s" % [
			action_id,
			int(app.current_view.get("day", 0)),
			str(app.current_view.get("location", {}).get("id", "unknown")),
			_available_action_ids(),
		])

	app.action_panel_controller._consider_action(action)
	if app.confirmation_layer.visible:
		await _hold(float(timing.get("preview", 1.5)))
		app.action_panel_controller._confirm_selected_action()
	else:
		app._execute_action(action_id)

	if not await _wait_until_stable(20000, false):
		return _step_failure("action timed out: " + action_id)
	completed_actions += 1
	await _hold(float(timing.get("result", 2.2)))
	if app.causal_layer.visible:
		await _hold(float(timing.get("causal", 2.0)))
		app.presentation_controller._dismiss_causal()
		await _hold(0.8)
	if bool(app.current_view.get("resolved", false)):
		if not await _wait_until_stable(30000, true):
			return _step_failure("ending cinematic timed out")
		await _hold(1.5)
	return true


func _find_action(action_id: String) -> Dictionary:
	var actions = app.current_view.get("available_actions", [])
	if not actions is Array:
		return {}
	for action in actions:
		if str(action.get("id", "")) == action_id:
			return action
	return {}


func _available_action_ids() -> String:
	var ids: Array[String] = []
	for action in app.current_view.get("available_actions", []):
		ids.append(str(action.get("id", "")))
	return ",".join(ids)


func _wait_until_stable(timeout_ms: int, include_cinematic: bool) -> bool:
	var timeout: SceneTreeTimer = create_timer(float(timeout_ms) / 1000.0)
	while timeout.time_left > 0.0:
		await process_frame
		var cinematic_director: Variant = app.get("cinematic_director")
		var cinematic_active: bool = cinematic_director != null and bool(cinematic_director.get("active"))
		if app.pending_operation == "" and not app.presentation_busy and (not include_cinematic or not cinematic_active):
			await process_frame
			cinematic_director = app.get("cinematic_director")
			cinematic_active = cinematic_director != null and bool(cinematic_director.get("active"))
			if app.pending_operation == "" and not app.presentation_busy and (not include_cinematic or not cinematic_active):
				return true
	return false


func _hold(seconds: float) -> void:
	if seconds > 0.0:
		await create_timer(seconds).timeout


func _route_path_from_arguments() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(ROUTE_ARGUMENT_PREFIX):
			return argument.trim_prefix(ROUTE_ARGUMENT_PREFIX).strip_edges()
	return DEFAULT_ROUTE


func _load_route(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("recording route does not exist: " + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("cannot open recording route: " + path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_fail("recording route must contain a JSON object: " + path)
		return {}
	if not parsed.get("steps", null) is Array or parsed.get("steps", []).is_empty():
		_fail("recording route has no steps: " + path)
		return {}
	return parsed


func _step_failure(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error("Recording failed: " + message)
	quit(1)
