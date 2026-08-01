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
	if app.connection_label.text != "":
		return _fail("healthy start screen leaks local-service diagnostics")
	if "从白石坊市入局" not in _descendant_text(app.start_layer):
		return _fail("start call to action does not match the actual opening location")

	app.name_input.text = "烟测修士"
	app._new_game()
	if not await _wait_until_idle():
		return _fail("new game request timed out")
	if app.current_view.is_empty():
		return _fail("new game returned no player view")
	var actions: Array = app.current_view.get("available_actions", [])
	if actions.is_empty():
		return _fail("new game returned no actions")
	if not app.location_panel.visible or app.map_panel.visible or not app.action_dock.visible:
		return _fail("new players do not enter through the first actionable location view")
	for action in actions:
		if not app._action_has_visible_entry(action):
			return _fail("available backend action has no frontend entry contract: " + str(action.get("id", "")))
	var world_map: Dictionary = app.current_view.get("world_map", {})
	if world_map.get("locations", []).size() != 5 or world_map.get("routes", []).is_empty():
		return _fail("new game returned no public world map")
	if app.world_map_view.locations.size() != 5:
		return _fail("2D world map did not consume the player view")
	if not app.world_map_view.has_formal_assets():
		return _fail("world map does not use the registered scenic assets")
	var action_text := _descendant_text(app.actions_box)
	if "核验" not in action_text or "起手任选" not in action_text or "亲自入谷" not in action_text or "查证与探索" in action_text or app.active_action_category != "":
		return _fail("contextual action dock fell back to dashboard categories")
	if str(app.location_stage.location.get("scene_key", "")) != "market":
		return _fail("location stage did not render the current place")
	if not app.location_stage.has_formal_asset():
		return _fail("market did not load its registered production background")
	for scene_key in ["market", "qinglan", "apothecary", "valley_edge", "inner_valley"]:
		if not app.presentation_registry.has_location(scene_key):
			return _fail("missing production location profile: " + scene_key)
	for actor_id in ["N01", "N02", "N03", "N04", "N05", "N06", "N07", "N08", "N09", "N10"]:
		if not app.presentation_registry.has_actor(actor_id):
			return _fail("missing production actor profile: " + actor_id)
		var actor_profile = app.presentation_registry.actor_profile(actor_id)
		if actor_profile == null or actor_profile.portrait() == null:
			return _fail("actor profile has no loadable portrait: " + actor_id)
	if not app.actor_portrait.visible or app.actor_portrait.texture == null:
		return _fail("initial core actor did not load its registered portrait")
	if app.stage_actor_id != "N01" or app.actor_portrait_name.text != "李玄":
		return _fail("location stage did not establish the first visible actor")
	app._focus_actor_from_stage("N04", "魏无咎")
	await process_frame
	if app.stage_actor_id != "N04" or app.focused_actor_id != "N04":
		return _fail("actor selection did not synchronize stage and action focus")
	if app.actor_portrait.texture != app.presentation_registry.actor_profile("N04").portrait():
		return _fail("actor selection did not switch the production portrait")
	if app.actor_portrait_name.text != "魏无咎" or not app.location_panel.visible:
		return _fail("actor selection did not update the visible stage caption")
	if app.actions_box.get_child_count() < 2 or "眼下可说" not in _descendant_text(app.actions_box.get_child(1)):
		return _fail("actor focus does not place available dialogue before the dossier")
	if app.location_detail_box.visible or app.stage_people_box.visible:
		return _fail("actor focus keeps unrelated location chrome above the dialogue action")
	for bus_name in ["Ambient", "Event", "UI"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			return _fail("missing audio bus: " + bus_name)
	app._open_audio_settings()
	if not app.settings_layer.visible:
		return _fail("audio settings entry did not open")
	app._toggle_motion()
	if app.motion_enabled or app.world_map_view.motion_enabled or app.presentation_director.motion_enabled:
		return _fail("reduced-motion preference did not propagate to presentation components")
	app._toggle_motion()
	app._close_audio_settings()
	app._on_map_location_selected("L02")
	if app.selected_map_location_id != "L02" or app.map_detail_box.get_child_count() == 0:
		return _fail("map location selection has no detail state")
	if "前往青岚门驻地" not in _descendant_text(app.map_detail_box):
		return _fail("map travel call to action does not name its destination")
	app._set_visual_mode("location")
	if not app.location_panel.visible or app.map_panel.visible or not app.action_dock.visible:
		return _fail("location scene mode did not replace the map")
	app._set_visual_mode("map")
	if app.action_dock.visible:
		return _fail("map mode keeps the narrative action dock open")
	if app.map_mode_button.text != "地图" or app.location_mode_button.text != "当前地点":
		return _fail("map and location modes still rely on unexplained poetic labels")
	if app.day_label.text != "第 1 / 30 日":
		return _fail("initial day is not player-facing day one")
	if app.phase_label.text != "筹备期":
		return _fail("initial phase does not explain the preparation stage")
	if app.timing_label.text != "第24天 · 传闻":
		return _fail("initial known timing is not visible")
	app._open_journal()
	if not app.journal_layer.visible or "烟测修士" not in _descendant_text(app.journal_panel):
		return _fail("travel dossier does not expose the player summary")
	if app.journal_tabs.get_tab_count() != 4 or app.journal_travel_button.text != "行装 !2":
		return _fail("travel dossier does not expose four layered sections with blocking gear status")
	var player_metrics := _descendant_text(app.player_resources_box)
	if "战力 2" not in player_metrics or "灵石 100" not in player_metrics or "助力 0" in player_metrics or "伤势 0" in player_metrics:
		return _fail("player summary did not hide zero-value secondary metrics")
	app._select_journal_tab(3)
	var travel_text := _descendant_text(app.travel_box)
	if app.journal_tabs.current_tab != 3 or "仍缺 2 项才能成行" not in travel_text or "缺少 · 解瘴丹" not in travel_text or "现在购买解瘴丹" not in travel_text or "入口尚未开放" not in travel_text or "你的争夺准备" not in travel_text or "助力 0 · 当前尚未建立" not in travel_text:
		return _fail("gear section does not prioritize blocking preparation: " + travel_text)
	if app.journal_travel_details_box.visible:
		return _fail("gear section exposes completed checks before the player asks")
	app._toggle_journal_travel_details()
	if not app.journal_travel_details_box.visible or "路线已发现" not in travel_text:
		return _fail("gear section cannot reveal completed checks on demand")
	app._select_journal_tab(0)
	app._close_journal()
	if app.journal_layer.visible:
		return _fail("travel dossier cannot be dismissed")
	var found_verification := false
	for action in actions:
		if action.get("timing", "") == "" or action.get("expected_outcomes", []).is_empty():
			return _fail("action lacks timing or expected outcomes")
		if action.get("known_conditions", []).is_empty() and action.get("unknowns", []).is_empty():
			return _fail("action does not separate known conditions from uncertainty")
		if action.get("kind", "") == "tell" and (action.get("target_role", "") == "" or action.get("relevance", "") == "" or action.get("risk", "") == ""):
			return _fail("tell action lacks public decision context")
		if action.get("id", "") == "verify:F02":
			found_verification = true
			if int(action.get("completion_day", 0)) != 2 or "传闻口径" not in str(action.get("timing", "")) or action.get("resolves", []).is_empty():
				return _fail("verification action lacks a player-facing decision summary")
			if app._action_needs_confirmation(action):
				return _fail("ordinary verification still uses a blocking commitment modal")
		if action.get("id", "") == "wait:next":
			if not app._action_needs_confirmation(action):
				return _fail("open-ended time advance lost its confirmation")
			if int(action.get("completion_day", 0)) != 0:
				return _fail("open-ended advance exposes a misleading completion day")
			app._consider_action(action)
			if not app.confirmation_layer.visible:
				return _fail("multi-day advance has no confirmation")
			if app.confirmation_details_box.visible:
				return _fail("confirmation reveals secondary reasoning before the player asks")
			app._toggle_confirmation_details()
			if not app.confirmation_details_box.visible:
				return _fail("confirmation reasoning disclosure cannot be opened")
			if "仍未知" not in _descendant_text(app.confirmation_details_box):
				return _fail("confirmation does not expose uncertainty separately")
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
	if app.presentation_director.card.anchor_left != 0.0 or app.presentation_director.message_label.text == "":
		return _fail("verification feedback did not use the peripheral echo layer")
	app.presentation_director.present({
		"day": 4,
		"action_id": "tell:N03:F01",
		"action": "告知沈砚秋一条线索",
		"messages": ["情报已经送达沈砚秋。", "对方是否改变行动，会在后续局势变化时显现。"],
		"presentation": {"kind": "actor_focus", "intensity": 1, "subject_id": "N03"},
	}, "", "")
	await process_frame
	if app.presentation_director.title_label.text != "沈砚秋" or app.presentation_director.message_label.text != "记下了这句话":
		return _fail("actor feedback did not collapse system messages into one human echo")
	if app.presentation_director.card.anchor_left != 1.0 or "后续局势" in app.presentation_director.message_label.text:
		return _fail("actor feedback did not move beside the actor or still leaks system explanation")
	app.presentation_director.cancel()
	if app.journal_echo_button.text != "回响 · 新" or app.journal_feedback_details_box.visible:
		return _fail("new echo is not marked or reveals its evidence by default")
	app._open_journal()
	if "查看推演过程" not in _descendant_text(app.scene_box):
		return _fail("echo summary does not offer progressive disclosure")
	app._toggle_journal_feedback_details()
	if not app.journal_feedback_details_box.visible:
		return _fail("echo evidence cannot be expanded")
	app._close_journal()
	if app.journal_echo_button.text != "回响":
		return _fail("echo unread marker is not cleared after reading")
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
