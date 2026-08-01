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
	var world_map: Dictionary = app.current_view.get("world_map", {})
	if world_map.get("locations", []).size() != 5 or world_map.get("routes", []).is_empty():
		return _fail("new game returned no public world map")
	if app.world_map_view.locations.size() != 5:
		return _fail("2D world map did not consume the player view")
	if str(app.location_stage.location.get("scene_key", "")) != "market":
		return _fail("location stage did not render the current place")
	if not app.location_stage.has_formal_asset():
		return _fail("market did not load its registered production background")
	for scene_key in ["market", "qinglan", "apothecary", "valley_edge", "inner_valley"]:
		if not app.presentation_registry.has_location(scene_key):
			return _fail("missing production location profile: " + scene_key)
	for actor_id in ["N01", "N02", "N03"]:
		if not app.presentation_registry.has_actor(actor_id):
			return _fail("missing core actor profile: " + actor_id)
	if not app.actor_portrait.visible or app.actor_portrait.texture == null:
		return _fail("initial core actor did not load its registered portrait")
	for bus_name in ["Ambient", "Event", "UI"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			return _fail("missing audio bus: " + bus_name)
	app._open_audio_settings()
	if not app.settings_layer.visible:
		return _fail("audio settings entry did not open")
	app._close_audio_settings()
	app._on_map_location_selected("L04")
	if app.selected_map_location_id != "L04" or app.map_detail_box.get_child_count() == 0:
		return _fail("map location selection has no detail state")
	app._set_visual_mode("location")
	if not app.location_panel.visible or app.map_panel.visible:
		return _fail("location scene mode did not replace the map")
	app._set_visual_mode("map")
	if app.day_label.text != "第 1 / 30 日":
		return _fail("initial day is not player-facing day one")
	if app.timing_label.text != "第24天 · 传闻":
		return _fail("initial known timing is not visible")
	var found_verification := false
	for action in actions:
		if action.get("timing", "") == "" or action.get("expected_outcomes", []).is_empty():
			return _fail("action lacks timing or expected outcomes")
		if action.get("kind", "") == "tell" and (action.get("target_role", "") == "" or action.get("relevance", "") == "" or action.get("risk", "") == ""):
			return _fail("tell action lacks public decision context")
		if action.get("id", "") == "verify:F02":
			found_verification = true
			if int(action.get("completion_day", 0)) != 2 or "传闻口径" not in str(action.get("timing", "")) or action.get("resolves", []).is_empty():
				return _fail("verification action lacks a player-facing decision summary")
		if action.get("id", "") == "wait:next":
			if int(action.get("completion_day", 0)) != 0:
				return _fail("open-ended advance exposes a misleading completion day")
			app._consider_action(action)
			if not app.confirmation_layer.visible:
				return _fail("multi-day advance has no confirmation")
			app._cancel_confirmation()
			break
	if not found_verification:
		return _fail("initial verification action is missing")

	app._consider_action(actions[0])
	if app.confirmation_layer.visible:
		app._confirm_selected_action()
	if not await _wait_until_idle(12000):
		return _fail("action or autosave request timed out")
	if int(app.current_view.get("day", 0)) < 1:
		return _fail("action returned an invalid view")
	if app.presentation_director.generation < 1:
		return _fail("action result did not enter the presentation queue")
	var presentation: Dictionary = app.current_view.get("last_turn", {}).get("presentation", {})
	if presentation.get("kind", "") != "focus":
		return _fail("verification start has no semantic presentation cue")
	print("Godot integration smoke test passed: day %d, %d actions" % [app.current_view.get("day", 0), app.current_view.get("available_actions", []).size()])
	quit(0)


func _wait_until_idle(timeout_ms := 8000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if app.pending_operation == "" and not app.presentation_busy:
			# The action callback can enqueue autosave in the same frame.
			await process_frame
			if app.pending_operation == "" and not app.presentation_busy:
				return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
