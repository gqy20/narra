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
	for action_id in ["verify:F02", "wait:complete", "move:L02"]:
		if not await _execute(action_id):
			return
	var date_terms: Array = []
	for action in app.current_view.get("available_actions", []):
		if str(action.get("id", "")).begins_with("tell:N03:F01:"):
			date_terms.append(action)
	if date_terms.size() != 3:
		var visible_ids: Array[String] = []
		for action in app.current_view.get("available_actions", []):
			visible_ids.append(str(action.get("id", "")))
		return _fail("verified date did not expose three exchange terms: %s" % ", ".join(visible_ids))
	app.action_panel_controller._focus_actor_actions("N03", "沈砚秋")
	var term_text := _descendant_text(app.actor_focus_message_list) + _descendant_text(app.actor_focus_detail_box)
	if "选择交换条件" not in term_text or "无偿相助" not in term_text or "交换解瘴丹" not in term_text or "换取同行名额" not in term_text or "你提出的条件" not in term_text:
		return _fail("actor workspace does not explain the three intelligence terms")
	app.action_panel_controller._clear_action_focus()
	if not await _execute("tell:N03:F01:trust"):
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
		if str(action.get("id", "")).begins_with("tell:N03:F01:"):
			return _fail("delivered clue is still available")
		if "已核实" in str(action.get("timing", "")) and "传闻" not in str(action.get("timing", "")):
			found_verified_timing = true
	if not found_verified_timing:
		return _fail("action timing did not update after verification")
	var threads: Array = app.current_view.get("causal_threads", [])
	if threads.is_empty() or threads[0].get("stage", "") != "delivered":
		return _fail("delivered information has no persistent causal thread")
	app.journal_panel_controller._open_journal()
	if app.action_canvas.visible or "情报因果线" not in _descendant_text(app.scene_box) or "等待公开回响" not in _descendant_text(app.scene_box):
		return _fail("journal does not show the delivered causal stage")
	app.journal_panel_controller._close_journal()
	if not app.action_canvas.visible:
		return _fail("closing the journal did not restore the location action layer")
	app.action_panel_controller._focus_actor_actions("N03", "沈砚秋")
	var dossier_text: String = _descendant_text(app.actor_focus_message_list) + _descendant_text(app.actor_focus_detail_box) + str(app.objective_label.text)
	if "传播风险" not in dossier_text or "正在权衡" not in dossier_text or not app.actor_focus_workspace.visible:
		return _fail("focused actor workspace does not expose decision context and state")
	var shen_actions: Array = app.action_panel_controller._focused_information_actions(app.available_actions_cache)
	for action in shen_actions:
		if action.get("fact_id", "") == "F01":
			return _fail("actor focus still shows the delivered clue")
		if action.get("relevance", "") == "" or action.get("risk", "") == "":
			return _fail("actor focus lacks public decision context")
	app.action_panel_controller._clear_action_focus()
	if not await _execute("wait:next"):
		return
	if app.actor_expression_by_id.get("N03", "") != "decisive" or app.actor_portrait.texture != shen_profile.decisive:
		return _fail("visible decision change did not put Shen Yanqiu into the decisive state")
	threads = app.current_view.get("causal_threads", [])
	if threads.is_empty() or threads[0].get("stage", "") != "changed":
		return _fail("causal thread did not advance after a public decision change")
	if not app.causal_layer.visible or app.action_canvas.visible or app.causal_background.texture == null or app.causal_portrait.texture != shen_profile.decisive:
		return _fail("decision change did not enter the full-screen causal theatre")
	var causal_text := _descendant_text(app.causal_layer)
	if "沈砚秋" not in causal_text or "原本" not in causal_text or "现在" not in causal_text:
		return _fail("causal theatre does not show the actor and before/after change")
	app.presentation_controller._dismiss_causal()
	if app.causal_layer.visible or not app.action_canvas.visible:
		return _fail("causal theatre cannot be dismissed")
	var saved_known_actors: Array = app.current_view.get("known_actors", [])
	app.current_view["known_actors"] = []
	app.presentation_controller._present_causal_change(app.current_view.get("last_turn", {}), app.current_view.get("location", {}))
	app.current_view["known_actors"] = saved_known_actors
	await process_frame
	if app.causal_layer.visible or "余波继续" not in app.presentation_director.title_label.text:
		return _fail("repeated causal change did not step down to the compact ripple presentation")
	app.presentation_director.cancel()
	if not await _execute("wait:next"):
		return
	if int(app.current_view.get("day", 0)) != 8:
		return _fail("advance did not stop when the recovery route appeared")
	var recovery := _find_action("recover:N06:antidote")
	if recovery.is_empty() or not app.action_panel_controller._action_has_visible_entry(recovery):
		return _fail("recovery action has no frontend entry")
	if not app.action_panel_controller._action_needs_confirmation(recovery):
		return _fail("irreversible recovery exchange lost its confirmation")
	app.action_panel_controller._focus_actor_actions("N06", "苏晚照")
	var recovery_focus_text: String = _descendant_text(app.actor_focus_message_list) + _descendant_text(app.actor_focus_detail_box) + _descendant_text(app.actor_focus_footer)
	if "以情报换取解瘴丹" not in recovery_focus_text:
		return _fail("recovery action is not visible from Su Wanzhao's dialogue")
	if "为何停下" not in _descendant_text(app.scene_box) or "以情报换取解瘴丹" not in _descendant_text(app.scene_box):
		return _fail("recovery interruption does not explain why time stopped")
	app.action_panel_controller._clear_action_focus()
	if not await _execute("wait:next"):
		return
	if int(app.current_view.get("day", 0)) != 10:
		return _fail("trust route did not stop for the sect review")
	var vouch := _find_action("route:trust:vouch")
	var leak := _find_action("route:trust:leak")
	if vouch.is_empty() or leak.is_empty() or not app.action_panel_controller._action_needs_confirmation(vouch):
		return _fail("trust route does not expose both midgame responses")
	app.action_panel_controller._focus_actor_actions("N09", "赵鹤鸣")
	var route_text := _descendant_text(app.actor_focus_message_list) + _descendant_text(app.actor_focus_detail_box) + _descendant_text(app.actor_focus_footer)
	if "回应路线考验" not in route_text or "公开担保" not in route_text or "转交计划" not in route_text or "先选择一种回应" not in route_text or "做出这个决定" in route_text:
		return _fail("route response workspace preselected an irreversible response")
	app.action_panel_controller._select_focused_actor_action("route:trust:vouch")
	route_text = _descendant_text(app.actor_focus_message_list) + _descendant_text(app.actor_focus_detail_box) + _descendant_text(app.actor_focus_footer)
	if "你的回应" not in route_text or "为情报来源担保 · 确认" not in route_text:
		return _fail("route response workspace lacks the trust test and its stakes")
	app.action_panel_controller._clear_action_focus()
	if not await _execute("route:trust:vouch"):
		return
	if not await _execute("wait:next"):
		return
	if int(app.current_view.get("day", 0)) != 14 or _find_action("route:trust:commission").is_empty():
		return _fail("trust route did not return with a personal payoff choice")
	if not await _execute("route:trust:commission"):
		return
	for index in 3:
		if not await _execute("wait:next"):
			return

	if not bool(app.current_view.get("resolved", false)):
		return _fail("propagation route did not resolve")
	var actions = app.current_view.get("available_actions", null)
	if not actions is Array or not actions.is_empty():
		return _fail("resolved view actions are not an empty array")
	if not app.ending_layer.visible or app.action_canvas.visible:
		return _fail("ending overlay is not visible")
	if not app.ending_portrait.visible or app.ending_portrait.texture != shen_profile.decisive:
		return _fail("ending did not carry the decisive actor into the final narrative frame")
	if app.ending_box.anchor_left <= app.ending_portrait.anchor_right:
		return _fail("ending reading column overlaps the decisive portrait")
	if app.ending_box.anchor_right - app.ending_box.anchor_left > 0.5:
		return _fail("ending reading column is too wide for comfortable reading")
	if "沈砚秋" not in str(app.current_view.get("outcome", "")):
		return _fail("unexpected propagation outcome")
	if "准备值" in str(app.current_view.get("outcome", "")):
		return _fail("ending leaked an internal score")
	if "余波记录" not in _descendant_text(app.ending_box):
		return _fail("ending overlay does not expose the aftermath section")
	if "这次选择最终为你带来了什么" not in _descendant_text(app.ending_box) or "2 点信用" not in _descendant_text(app.ending_box):
		return _fail("ending does not surface the player's intelligence-route return")
	app.presentation_controller._toggle_ending_annex()
	if not app.ending_annex_box.visible:
		return _fail("ending aftermath section does not expand")
	app.presentation_controller._toggle_ending_annex()
	print("Godot propagation journey passed: ending visible on day %d" % app.current_view.get("day", 0))
	quit(0)


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
