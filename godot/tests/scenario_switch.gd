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
	if app.scenario_info.get("id", "") != "tianqi_t00":
		return _fail("client did not connect to the selected tianqi scenario")
	if app.header_brand_label.text != "天变邸抄":
		return _fail("scenario brand was not applied to the header")
	if app.start_title_label.text != "天变邸抄":
		return _fail("scenario brand was not applied to the start screen")
	if app.start_begin_button.text != "从王恭厂外街开始记录":
		return _fail("scenario start action was not applied")
	if "灾变之后" not in app.start_intro_label.text:
		return _fail("scenario introduction was not applied")

	app.name_input.text = "切换测试抄手"
	app._new_game()
	if not await _wait_until_idle():
		return _fail("tianqi new game request timed out")
	if app.current_view.get("scenario_id", "") != "tianqi_t00":
		return _fail("new game returned the wrong scenario")
	if app.current_view.get("presentation", {}).get("world_title", "") != "京师灾变与会勘":
		return _fail("player view did not carry tianqi presentation metadata")
	var resource_text := _descendant_text(app.player_resources_box)
	for expected in ["权势", "证据", "盟援"]:
		if expected not in resource_text:
			return _fail("resource presentation is missing: " + expected)
	for forbidden in ["战力", "灵石", "助力", "解瘴丹", "黑风谷"]:
		if forbidden in resource_text:
			return _fail("blackwind content leaked into tianqi resources: " + forbidden)
	app.game_screen_controller._set_visual_mode("map")
	for location in app.current_view.get("world_map", {}).get("locations", []):
		if bool(location.get("contest", false)):
			app.game_screen_controller._on_map_location_selected(str(location.get("id", "")))
			break
	var map_text := _descendant_text(app.map_detail_box)
	if "第十四日前，决定哪些材料进入会勘定稿" not in map_text:
		return _fail("scenario objective was not applied to the world map")
	if app.world_map_view.locations.size() != 6:
		return _fail("tianqi world map did not render all six locations")

	var actions: Array = app.current_view.get("available_actions", [])
	if actions.is_empty():
		return _fail("tianqi new game returned no actions")
	var action_id := str(actions[0].get("id", ""))
	app._execute_action(action_id)
	if not await _wait_until_idle():
		return _fail("tianqi action or autosave timed out")
	if app.current_view.get("last_turn", null) == null:
		return _fail("tianqi action returned no turn feedback")
	print("Scenario switch smoke test passed: %s via %s" % [app.current_view.get("scenario_id", ""), action_id])
	quit(0)


func _wait_until_idle(timeout_ms := 10000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if app.pending_operation == "" and not app.presentation_busy:
			await process_frame
			if app.pending_operation == "" and not app.presentation_busy:
				return true
	return false


func _descendant_text(node: Node) -> String:
	var result := ""
	if node is Label or node is Button:
		result += str(node.text) + "\n"
	for child in node.get_children():
		result += _descendant_text(child)
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
