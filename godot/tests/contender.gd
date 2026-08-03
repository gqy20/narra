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

	app.name_input.text = "入谷烟测修士"
	app._new_game()
	if not await _wait_until_idle():
		return _fail("new game request timed out")

	var initial_actions: Array = app.current_view.get("available_actions", [])
	if app.action_panel_controller._count_tell_actions(initial_actions, "N01", "") < 1:
		return _fail("actor-to-clue link has no available action")
	app.action_panel_controller._focus_actor_actions("N01", "李玄")
	var actor_actions: Array = app.action_panel_controller._focused_information_actions(initial_actions)
	if actor_actions.is_empty():
		return _fail("actor action focus is empty")
	for action in actor_actions:
		if action.get("target_id", "") != "N01":
			return _fail("actor action focus leaked another target")
	app.action_panel_controller._focus_fact_actions("F02", "青髓芝将在第24天成熟")
	var fact_actions: Array = app.action_panel_controller._focused_information_actions(initial_actions)
	if fact_actions.is_empty():
		return _fail("clue-to-actor link is empty")
	for action in fact_actions:
		if action.get("fact_id", "") != "F02":
			return _fail("clue action focus leaked another fact")
	app.action_panel_controller._clear_action_focus()

	if not await _execute("buy:M01:antidote"):
		return
	for _cycle in 5:
		if not await _execute_cultivation_stage():
			return
	if not await _execute("wait:next"):
		return
	if not await _execute("move:L04"):
		return
	if not await _execute("wait:complete"):
		return
	if not await _execute("move:L05"):
		return
	if not await _execute("wait:next"):
		return

	if not bool(app.current_view.get("resolved", false)):
		return _fail("prepared contender route did not resolve")
	if not app.ending_layer.visible or app.action_canvas.visible:
		return _fail("ending overlay is not visible")
	var player: Dictionary = app.current_view.get("player", {})
	if int(player.get("resources", {}).get("combat", 0)) < 7:
		return _fail("cultivation did not reach contender strength")
	if int(player.get("resources", {}).get("spirit_stones", 0)) != 20:
		return _fail("repeat cultivation did not consume its escalating visible costs")
	if str(app.current_view.get("location", {}).get("id", "")) != "L05":
		return _fail("player did not reach the inner valley")
	if "入谷烟测修士" not in str(app.current_view.get("outcome", "")):
		return _fail("prepared player did not win the contest")
	if "准备值" in str(app.current_view.get("outcome", "")):
		return _fail("ending leaked an internal score")
	var resolved_day := int(app.current_view.get("day", 0))
	var ending_text := _descendant_text(app.ending_box)
	if "回看本局选择与余波" not in ending_text or "换一条路 · 重新入局" not in ending_text or "返回卷首" not in ending_text:
		return _fail("ending does not offer review and replay exits")
	app._restart_from_ending()
	if not await _wait_until_idle(15000):
		return _fail("restart from ending timed out")
	if app.ending_layer.visible or int(app.current_view.get("day", -1)) != 0 or int(app.current_view.get("player", {}).get("resources", {}).get("combat", 0)) != 2:
		return _fail("restart from ending did not create a fresh journey")
	print("Godot contender journey passed: player won on day %d" % resolved_day)
	quit(0)


func _execute_cultivation_stage() -> bool:
	var action := _find_action("cultivate")
	if action.is_empty():
		_fail("missing action: cultivate")
		return false
	var before_combat := int(app.current_view.get("player", {}).get("resources", {}).get("combat", 0))
	var action_text := _descendant_text(app.overview_actions_box)
	if str(action.get("description", "")) not in action_text:
		app.action_panel_controller._toggle_all_actions()
		action_text = _descendant_text(app.overview_actions_box)
	if str(action.get("name", "")) not in action_text or str(action.get("expected_outcomes", [""])[0]) not in action_text:
		_fail("cultivation action does not render its server-provided outcome")
		return false
	if before_combat == 4 and "累计闭关耗费 10 灵石" not in str(action.get("description", "")):
		_fail("high-cost cultivation does not expose cumulative spending")
		return false
	app.action_panel_controller._consider_action(action, "wait:complete")
	if app.confirmation_layer.visible:
		app.action_panel_controller._confirm_selected_action()
	if not await _wait_until_idle(15000):
		_fail("cultivation stage timed out")
		return false
	var player: Dictionary = app.current_view.get("player", {})
	if bool(player.get("busy", false)) or app.queued_followup_action_id != "" or int(player.get("resources", {}).get("combat", 0)) != before_combat + 1:
		_fail("one-click cultivation did not finish the next stage")
		return false
	return true


func _execute(action_id: String) -> bool:
	var action := _find_action(action_id)
	if action.is_empty():
		_fail("missing action: " + action_id)
		return false
	app.action_panel_controller._consider_action(action)
	if app.confirmation_layer.visible:
		app.action_panel_controller._confirm_selected_action()
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
