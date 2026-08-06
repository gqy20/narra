extends SceneTree

const ROUTE_ARGUMENT_PREFIX := "--recording-route="
const DEFAULT_ROUTE := "res://demo/recordings/tianqi-evidence-route.json"

var app
var route: Dictionary = {}
var completed_actions := 0
var recording_fps := 30
var recording_start_frame := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	recording_fps = _recording_fps_from_arguments()
	recording_start_frame = Engine.get_process_frames()
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

	var step_index := 0
	for raw_step in route.get("steps", []):
		if not raw_step is Dictionary:
			return _fail("recording route contains a non-object step")
		_print_step_marker("START", step_index, raw_step)
		if not await _run_step(raw_step):
			return
		_print_step_marker("END", step_index, raw_step)
		step_index += 1

	var expected_min_actions := int(route.get("expected_min_actions", 0))
	if completed_actions < expected_min_actions:
		return _fail("recording completed only %d actions; expected at least %d" % [completed_actions, expected_min_actions])
	var expected_min_day := int(route.get("expected_min_day", 0))
	if int(app.current_view.get("day", 0)) < expected_min_day:
		return _fail("recording ended on day %d; expected at least day %d" % [int(app.current_view.get("day", 0)), expected_min_day])
	if bool(route.get("expected_resolved", false)) and not bool(app.current_view.get("resolved", false)):
		return _fail("recording route expected a resolved ending")

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
		"focus_actor":
			if not await _focus_actor(str(step.get("id", "")), step):
				return false
		"dialogue_turn":
			if not await _dialogue_turn(str(step.get("message", "")), step):
				return false
		"clear_focus":
			app.action_panel_controller._reset_action_focus()
			app.action_panel_controller._render_actions(app.available_actions_cache)
			await _hold(float(step.get("after", 0.8)))
		_:
			return _step_failure("unknown recording step type: " + kind)
	return true


func _focus_actor(actor_id: String, timing: Dictionary) -> bool:
	var actor := _find_actor(actor_id)
	if actor.is_empty():
		return _step_failure("missing visible actor %s at %s" % [actor_id, str(app.current_view.get("location", {}).get("id", "unknown"))])
	app.game_screen_controller._focus_actor_from_stage(actor_id, str(actor.get("name", actor_id)))
	await _hold(float(timing.get("after", 1.2)))
	return true


func _dialogue_turn(message: String, timing: Dictionary) -> bool:
	if app.focused_actor_id == "":
		return _step_failure("dialogue turn requires a focused actor")
	if message.strip_edges() == "":
		return _step_failure("dialogue turn message is empty")
	app.dialogue_panel_controller._submit_actor_dialogue(message)
	var actor_id: String = app.focused_actor_id
	var attempts := maxi(1, int(timing.get("attempts", 1)))
	for attempt in attempts:
		await _hold(float(timing.get("loading_hold", 1.2)))
		if not await _wait_for_dialogue(actor_id, int(timing.get("timeout_ms", 90000))):
			return _step_failure("NPC dialogue turn timed out for " + actor_id)
		if not app.actor_dialogue_error_by_id.has(actor_id):
			await _hold(float(timing.get("after", 6.0)))
			return true
		if attempt + 1 >= attempts:
			break
		await _hold(float(timing.get("retry_hold", 2.0)))
		app.actor_dialogue_error_by_id.erase(actor_id)
		app.actor_dialogue_loading_id = actor_id
		app.dialogue_client.request_turn(actor_id, message)
		app.action_panel_controller._render_actions(app.available_actions_cache)
	return _step_failure("NPC dialogue turn failed for %s after %d attempts: %s" % [actor_id, attempts, app.actor_dialogue_error_by_id.get(actor_id, "unknown error")])


func _find_actor(actor_id: String) -> Dictionary:
	for actor in app.current_view.get("known_actors", []):
		if str(actor.get("id", "")) == actor_id:
			return actor
	return {}


func _wait_for_dialogue(actor_id: String, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if app.actor_dialogue_loading_id == "" and (app.actor_dialogue_history_by_id.has(actor_id) or app.actor_dialogue_error_by_id.has(actor_id)):
			return true
	return false


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
		var prologue_director: Variant = app.get("prologue_director")
		var prologue_active: bool = prologue_director != null and bool(prologue_director.get("active"))
		if include_cinematic and prologue_active and int(prologue_director.get("current_beat_index")) >= prologue_director.get("beats").size() - 1:
			prologue_director.advance()
			prologue_active = bool(prologue_director.get("active"))
		if app.pending_operation == "" and not app.presentation_busy and (not include_cinematic or not cinematic_active and not prologue_active):
			await process_frame
			cinematic_director = app.get("cinematic_director")
			cinematic_active = cinematic_director != null and bool(cinematic_director.get("active"))
			prologue_director = app.get("prologue_director")
			prologue_active = prologue_director != null and bool(prologue_director.get("active"))
			if app.pending_operation == "" and not app.presentation_busy and (not include_cinematic or not cinematic_active and not prologue_active):
				return true
	return false


func _hold(seconds: float) -> void:
	var frames_to_hold := ceili(maxf(0.0, seconds) * float(recording_fps))
	for frame_index in frames_to_hold:
		await process_frame
		await RenderingServer.frame_post_draw


func _route_path_from_arguments() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(ROUTE_ARGUMENT_PREFIX):
			return argument.trim_prefix(ROUTE_ARGUMENT_PREFIX).strip_edges()
	return DEFAULT_ROUTE


func _recording_fps_from_arguments() -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--recording-fps="):
			return maxi(1, int(argument.trim_prefix("--recording-fps=")))
	return 30


func _print_step_marker(phase: String, index: int, step: Dictionary) -> void:
	var frame := maxi(0, Engine.get_process_frames() - recording_start_frame)
	print("RECORDING_STEP_%s index=%d type=%s frame=%d second=%.3f" % [
		phase,
		index,
		str(step.get("type", "unknown")),
		frame,
		float(frame) / float(recording_fps),
	])


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
