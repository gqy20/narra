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
	if app.world_map_view.travel_end_day < 1 or app.world_map_view.travel_active or app.presentation_busy:
		return _fail("map travel animation did not finish cleanly")
	if app.audio_director.current_scene_key != "qinglan" or not app.location_stage.has_formal_asset():
		return _fail("Qinglan presentation profile did not become active")
	if not app.actor_portrait_frame.visible or app.actor_portrait.texture == null:
		return _fail("Shen Yanqiu portrait is not visible at the location")
	var shen_profile: ActorVisualProfile = app.presentation_registry.actor_profile("N03")
	if shen_profile == null or shen_profile.alert == null or shen_profile.troubled == null or shen_profile.decisive == null:
		return _fail("Shen Yanqiu expression portraits are not fully registered")
	if app.actor_expression_by_id.get("N03", "") != "troubled" or app.actor_portrait.texture != shen_profile.troubled:
		return _fail("delivered information did not put Shen Yanqiu into the weighing state")
	var travel: Dictionary = app.current_view.get("travel", {})
	if travel.get("route", []).size() < 2 or travel.get("checks", []).is_empty():
		return _fail("travel route and readiness checks are not available")
	var found_verified_timing := false
	for action in app.current_view.get("available_actions", []):
		if action.get("id", "") == "tell:N03:F01":
			return _fail("delivered clue is still available")
		if "已核实" in str(action.get("timing", "")) and "传闻" not in str(action.get("timing", "")):
			found_verified_timing = true
	if not found_verified_timing:
		return _fail("action timing did not update after verification")
	app._focus_actor_actions("N03", "沈砚秋")
	var dossier_text := _descendant_text(app.actions_box)
	if "传播风险" not in dossier_text or "当前状态" not in dossier_text or "正在权衡" not in dossier_text:
		return _fail("focused actor dossier does not expose decision context and state")
	var shen_actions: Array = app._focused_information_actions(app.available_actions_cache)
	for action in shen_actions:
		if action.get("fact_id", "") == "F01":
			return _fail("actor focus still shows the delivered clue")
		if action.get("relevance", "") == "" or action.get("risk", "") == "":
			return _fail("actor focus lacks public decision context")
	app._clear_action_focus()
	if not await _execute("wait:next"):
		return
	if app.actor_expression_by_id.get("N03", "") != "decisive" or app.actor_portrait.texture != shen_profile.decisive:
		return _fail("visible decision change did not put Shen Yanqiu into the decisive state")
	if not app.causal_layer.visible or app.causal_background.texture == null or app.causal_portrait.texture != shen_profile.decisive:
		return _fail("decision change did not enter the full-screen causal theatre")
	var causal_text := _descendant_text(app.causal_layer)
	if "沈砚秋" not in causal_text or "原本" not in causal_text or "现在" not in causal_text:
		return _fail("causal theatre does not show the actor and before/after change")
	app._dismiss_causal()
	if app.causal_layer.visible:
		return _fail("causal theatre cannot be dismissed")
	for index in 3:
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
	if "余波记录" not in _descendant_text(app.ending_box):
		return _fail("ending overlay does not expose the aftermath section")
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
