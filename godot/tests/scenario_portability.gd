extends SceneTree

var app


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if not await _wait_until_idle():
		return _fail("orbital health request timed out")
	if app.scenario_info.get("id", "") != "orbital_t00":
		return _fail("client did not connect to the orbital portability scenario")
	var start_text := _descendant_text(app.start_layer)
	if "远星环站" not in start_text or "白石补给环" not in start_text:
		return _fail("orbital presentation metadata was not rendered")
	for forbidden in ["黑风谷", "青髓芝", "青岚门"]:
		if forbidden in start_text:
			return _fail("previous story terminology leaked into orbital start screen: " + forbidden)
	app.name_input.text = "移植测试员"
	app._new_game()
	if not await _wait_until_idle():
		return _fail("orbital new game request timed out")
	var view: Dictionary = app.current_view
	if view.get("scenario_id", "") != "orbital_t00" or view.get("available_actions", []).is_empty():
		return _fail("orbital world did not produce an actionable player view")
	if view.get("world_map", {}).get("locations", []).size() != 5:
		return _fail("orbital world map was not rendered through the generic contract")
	app._execute_action("wait:next")
	if not await _wait_until_idle():
		return _fail("orbital action request timed out")
	if int(app.current_view.get("day", 0)) <= 0:
		return _fail("orbital action did not advance the game")
	print("Godot scenario portability test passed: orbital day %d" % int(app.current_view.get("day", 0)))
	quit(0)


func _wait_until_idle(timeout_ms := 12000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if app.pending_operation == "" and not app.presentation_busy and not app.cinematic_director.active:
			await process_frame
			if app.pending_operation == "" and not app.presentation_busy and not app.cinematic_director.active:
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
