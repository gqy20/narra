extends SceneTree

var app
var capture_output_dir := ""
var capture_label := "2048x1152"
var capture_viewport: SubViewport
var capture_stop_after := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output-dir="):
			capture_output_dir = argument.trim_prefix("--capture-output-dir=")
		elif argument.begins_with("--capture-label="):
			capture_label = argument.trim_prefix("--capture-label=")
		elif argument.begins_with("--capture-stop-after="):
			capture_stop_after = argument.trim_prefix("--capture-stop-after=")
	call_deferred("_run")


func _run() -> void:
	var capture_size := _capture_size()
	if capture_size != Vector2i.ZERO:
		capture_viewport = SubViewport.new()
		capture_viewport.size = capture_size
		capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(capture_viewport)
	app = load("res://main.tscn").instantiate()
	if capture_viewport:
		capture_viewport.add_child(app)
	else:
		root.add_child(app)
	await process_frame
	if not await _wait_until_idle():
		return _fail("health request timed out")
	var graph_only := capture_stop_after == "knowledge-graph"
	app.cinematic_director.set_enabled(false)
	await _settle_layout()
	if not graph_only and not await _capture("ui-start-%s.png" % capture_label):
		return
	app.name_input.text = "烟测修士"
	app._new_game()
	if not await _wait_until_idle():
		return _fail("new game request timed out")
	if app.cinematic_director and app.cinematic_director.active:
		app.cinematic_director.skip()
		await _settle_layout()
	if app.prologue_director and app.prologue_director.active:
		if graph_only:
			app.prologue_director.current_beat_index = app.prologue_director.beats.size() - 2
			app.prologue_director._show_next_beat()
			app.prologue_director._settle_current_beat()
			await _settle_layout()
		else:
			app.prologue_director._settle_current_beat()
			await _settle_layout()
			if not await _capture("ui-prologue-date-%s.png" % capture_label):
				return
			for beat_index in range(1, app.prologue_director.beats.size() - 1):
				app.prologue_director.current_beat_index = beat_index - 1
				app.prologue_director._show_next_beat()
				app.prologue_director._settle_current_beat()
				await _settle_layout()
				if not await _capture("ui-prologue-beat-%02d-%s.png" % [beat_index + 1, capture_label]):
					return
			app.prologue_director.current_beat_index = app.prologue_director.beats.size() - 2
			app.prologue_director._show_next_beat()
			app.prologue_director._settle_current_beat()
			await _settle_layout()
			if not await _capture("ui-prologue-deadline-%s.png" % capture_label):
				return
		app.prologue_director.advance()
		await _settle_layout()
	app.game_screen_controller._set_visual_mode("location")
	await _settle_layout()
	if not graph_only and not await _capture("ui-overview-%s.png" % capture_label):
		return
	if not graph_only:
		app.game_screen_controller._set_visual_mode("map")
		await _settle_layout()
		if not await _capture("ui-map-%s.png" % capture_label):
			return
	app.game_screen_controller._set_visual_mode("location")
	app.motion_enabled = false
	app.journal_panel_controller._open_journal()
	if not graph_only:
		for tab_capture in [[0, "echo"], [1, "clues"], [2, "people"], [3, "travel"]]:
			app.journal_panel_controller._select_journal_tab(int(tab_capture[0]))
			await _settle_layout()
			if not await _capture("ui-journal-%s-%s.png" % [tab_capture[1], capture_label]):
				return
			if int(tab_capture[0]) == 3:
				app.journal_panel_controller._toggle_journal_travel_details()
				await _settle_layout()
				if not await _capture("ui-journal-travel-expanded-%s.png" % capture_label):
					return
				app.journal_panel_controller._toggle_journal_travel_details()
	app.journal_panel_controller._select_journal_tab(4)
	await _settle_layout()
	if not await _capture("ui-knowledge-graph-%s.png" % capture_label):
		return
	if capture_stop_after == "knowledge-graph":
		for definition in [["actor", "actor"], ["event", "event"], ["location", "location"]]:
			app.journal_panel_controller._select_graph_filter(str(definition[0]))
			await _settle_layout()
			if app.knowledge_graph_view.visible_node_count() > 0:
				if not await _capture("ui-knowledge-graph-%s-%s.png" % [definition[1], capture_label]):
					return
		print("Knowledge graph screenshot captured.")
		app.journal_panel_controller._close_journal()
		quit(0)
		return
	app.journal_panel_controller._close_journal()

	app.action_panel_controller._focus_actor_actions("N01", "李玄")
	var confirmation_probe := {
		"id": "qa:tell",
		"name": "告知李玄一条线索",
		"kind": "tell",
		"description": "分享：“青髓芝将在第24天成熟”",
		"target_id": "N01",
		"target_name": "李玄",
		"target_role": "独行争夺者",
		"fact_claim": "青髓芝将在第24天成熟",
		"relevance": "直接相关 · 对方公开关注：青髓芝归属",
		"risk": "行动果断，未经核实的消息也可能促使他冒险。",
		"timing": "时机 · 传闻口径 · 行动后预留 20 日抵达",
		"expected_outcomes": ["让李玄获得这条线索、可能改变对方的后续选择"],
		"known_conditions": ["对方就在此地", "你持有这条线索"],
		"unknowns": ["对方是否采用消息，只能从之后的公开行动判断"],
		"completion_day": 1,
		"duration": 1,
		"warnings": ["这条线索尚未核实，对方可能据此改变行动。"],
		"irreversible": true,
	}
	app.action_panel_controller._render_actions([confirmation_probe])
	await _settle_layout()
	if not await _capture("ui-actor-focus-%s.png" % capture_label):
		return
	app.action_panel_controller._render_actions([])
	await _settle_layout()
	if not await _capture("ui-actor-empty-%s.png" % capture_label):
		return
	app.action_panel_controller._render_actions([confirmation_probe])
	await _settle_layout()
	app.action_panel_controller._consider_action(confirmation_probe)
	await _settle_layout()
	if not await _capture("ui-confirmation-%s.png" % capture_label):
		return
	app.action_panel_controller._toggle_confirmation_details()
	await _settle_layout()
	if not await _capture("ui-confirmation-expanded-%s.png" % capture_label):
		return
	print("UI state screenshots captured.")
	quit(0)


func _capture_size() -> Vector2i:
	var parts := capture_label.to_lower().split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


func _capture(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	var output_dir := capture_output_dir if capture_output_dir != "" else ProjectSettings.globalize_path("res://../artifacts/screenshots")
	var directory_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if directory_error != OK:
		_fail("could not create screenshot directory")
		return false
	var image: Image = app.get_viewport().get_texture().get_image()
	var save_error: Error = image.save_png(output_dir.path_join(file_name))
	if save_error != OK:
		_fail("could not save screenshot: " + file_name)
		return false
	return true


func _settle_layout() -> void:
	for index in 4:
		await process_frame


func _wait_until_idle(timeout_ms := 10000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if app.pending_operation == "" and not app.presentation_busy:
			await process_frame
			if app.pending_operation == "" and not app.presentation_busy:
				return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
