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
	if app.body_font.resource_path != "res://assets/fonts/SourceHanSansCN-Regular.otf":
		return _fail("body copy is not using the bundled Source Han Sans font")
	if app.medium_font.resource_path != "res://assets/fonts/SourceHanSansCN-Medium.otf":
		return _fail("control typography is not using bundled Source Han Sans Medium")
	if app.display_font.resource_path != "res://assets/fonts/SourceHanSerifCN-SemiBold.otf":
		return _fail("display typography is not using bundled Source Han Serif")
	if app.narrative_font.resource_path != "res://assets/fonts/LXGWWenKaiLite-Regular.ttf":
		return _fail("narrative typography is not using LXGW WenKai Lite")
	if app.theme.default_font != app.AppVisualThemeScript.BodyFont:
		return _fail("root theme does not come from the shared visual-theme authority")
	if app.TYPE_SCALE.body != app.AppVisualThemeScript.TYPE_SCALE.body or app.COLORS.accent != app.AppVisualThemeScript.COLORS.accent:
		return _fail("main compatibility tokens drifted from the visual-theme authority")
	var theme_style: StyleBoxFlat = app.AppVisualThemeScript.panel_style(Color.BLACK, 1, 3, Color.WHITE, 7, 9)
	if theme_style.border_width_left != 1 or theme_style.corner_radius_top_left != 3 or theme_style.content_margin_left != 7 or theme_style.content_margin_top != 9:
		return _fail("shared visual-theme style factory lost its layout contract")
	if app.AppVisualThemeScript.alpha8(app.COLORS.accent, 0x99) != Color("d6ae6299"):
		return _fail("shared visual-theme alpha helper does not preserve byte-accurate colors")
	var minimum_size_probe_parent = VBoxContainer.new()
	app.add_child(minimum_size_probe_parent)
	var minimum_size_probe = app.ui_factory.text(minimum_size_probe_parent, "", false, 1)
	if minimum_size_probe.get_theme_font_size("font_size") < app.MIN_READABLE_TEXT_SIZE:
		return _fail("standard UI text can render below the minimum readable size")
	minimum_size_probe_parent.queue_free()
	if app.game_screen_controller.world_map_view.minimum_font_size < app.MIN_READABLE_TEXT_SIZE:
		return _fail("custom-drawn map text can render below the minimum readable size")
	if "从白石坊市入局" not in _descendant_text(app.start_layer):
		return _fail("start call to action does not match the actual opening location")
	if app.start_title_label.text == app.start_eyebrow_label.text or app.start_eyebrow_label.text.begins_with(app.start_title_label.text + "："):
		return _fail("start screen repeats the world title instead of using a distinct scenario qualifier")

	app.name_input.text = "烟测修士"
	app._new_game()
	if not await _wait_until_idle():
		return _fail("new game request timed out")
	if app.current_view.is_empty():
		return _fail("new game returned no player view")
	var actions: Array = app.current_view.get("available_actions", [])
	if actions.is_empty():
		return _fail("new game returned no actions")
	if not app.game_screen_controller.location_panel.visible or app.game_screen_controller.map_panel.visible or not app.game_screen_controller.action_dock.visible:
		return _fail("new players do not enter through the first actionable location view")
	for action in actions:
		if not app.action_panel_controller._action_has_visible_entry(action):
			return _fail("available backend action has no frontend entry contract: " + str(action.get("id", "")))
	var world_map: Dictionary = app.current_view.get("world_map", {})
	if world_map.get("locations", []).size() != 5 or world_map.get("routes", []).is_empty():
		return _fail("new game returned no public world map")
	if app.game_screen_controller.world_map_view.locations.size() != 5:
		return _fail("dimensional world map did not consume the player view")
	if world_map.get("actors", []).size() != 3 or app.game_screen_controller.world_map_view.actors.size() != 3 or not app.game_screen_controller.world_map_view.has_actor_plan_presentation():
		return _fail("world map did not expose the three core actor plans")
	if not app.game_screen_controller.world_map_view.has_formal_assets():
		return _fail("world map does not use the registered scenic assets")
	var direct_route := {}
	for candidate in app.game_screen_controller.world_map_view.routes:
		if str(candidate.get("from_id", "")) == "L01" and str(candidate.get("to_id", "")) == "L02":
			direct_route = candidate
			break
	if direct_route.is_empty() or app.game_screen_controller.world_map_view._route_destination(direct_route) != "L02":
		return _fail("raised map routes are not selectable navigation targets")
	if app.game_screen_controller.world_map_view.visible_route_mark_count() != 0:
		return _fail("world map shows route duration badges before route focus")
	app.game_screen_controller.world_map_view.hovered_route_key = app.game_screen_controller.world_map_view._route_key(direct_route)
	if app.game_screen_controller.world_map_view.visible_route_mark_count() != 1:
		return _fail("world map does not reveal exactly one focused route duration")
	app.game_screen_controller.world_map_view.hovered_route_key = ""
	if app.game_screen_controller.world_map_view.visible_actor_token_count() > 2:
		return _fail("world map exposes more than two actor chips in the focused location plate")
	app.game_screen_controller._set_visual_mode("map")
	var map_text := _descendant_text(app.game_screen_controller.map_detail_box)
	var current_map_name := str(app.current_view.get("location", {}).get("name", ""))
	if not (app.game_screen_controller.map_panel is HBoxContainer) or "路线沙盘" in map_text or "选择地点，查看人物、耗时与道路风险" in map_text or current_map_name not in map_text:
		return _fail("world map detail panel did not preserve the reduced location hierarchy")
	app.game_screen_controller._set_visual_mode("location")
	var action_text := _descendant_text(app.game_screen_controller.overview_actions_box)
	var contextual_actions: Array = app.action_panel_controller._location_context_actions(actions)
	if contextual_actions.is_empty() or str(contextual_actions[0].get("name", "")) not in action_text or "耗时" not in action_text or "01 · " in action_text or "起手可选" in action_text or "查证与探索" in action_text or app.active_action_category != "":
		return _fail("contextual action cards did not preserve the reduced title, timing, and outcome hierarchy")
	var overview_action_header: Node = _hbox_with_text(app.game_screen_controller.overview_actions_box, "耗时")
	if not overview_action_header is HBoxContainer:
		return _fail("contextual action title and duration are not kept on one row")
	var location_status_text := _descendant_text(app.game_screen_controller.action_dock_status_box)
	if not app.game_screen_controller.action_dock_status_box.visible or "安稳" not in location_status_text or "在场 4 人" not in location_status_text:
		return _fail("location title does not own its safety and attendance status")
	if not app.game_screen_controller.overview_actions_box.visible or app.game_screen_controller.fact_action_scroll.visible or app.game_screen_controller.actor_focus_workspace.visible:
		return _fail("default location state is not the compact non-scrolling overview")
	if str(app.game_screen_controller.location_stage.location.get("scene_key", "")) != "market":
		return _fail("location stage did not render the current place")
	if not app.game_screen_controller.location_stage.has_formal_asset():
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
	if app.presentation_registry.actor_count() != 10 or app.presentation_registry.location_count() != 5:
		return _fail("presentation manifest counts are invalid")
	if app.presentation_registry.actor_token_offset("N06", Vector2.ZERO) != Vector2(0, -52):
		return _fail("presentation manifest did not supply actor map-token metadata")
	if not app.game_screen_controller.actor_portrait.visible or app.game_screen_controller.actor_portrait.texture == null:
		return _fail("initial core actor did not load its registered portrait")
	if app.stage_actor_id != "N01" or app.game_screen_controller.actor_portrait_name.text != "李玄":
		return _fail("location stage did not establish the first visible actor")
	app.game_screen_controller._focus_actor_from_stage("N04", "魏无咎")
	await process_frame
	if app.stage_actor_id != "N04" or app.focused_actor_id != "N04":
		return _fail("actor selection did not synchronize stage and action focus")
	if app.pending_operation != "":
		return _fail("NPC dialogue reused the authoritative gameplay request channel")
	if not await _wait_for_dialogue("N04"):
		return _fail("NPC dialogue request timed out")
	var npc_dialogue: Dictionary = app.actor_dialogue_by_id.get("N04", {})
	if not npc_dialogue.is_empty():
		if str(npc_dialogue.get("actor_id", "")) != "N04" or str(npc_dialogue.get("utterance", "")) == "":
			return _fail("NPC dialogue did not return a displayable typed response")
		if str(npc_dialogue.get("source", "")) not in ["anthropic", "cache"]:
			return _fail("NPC dialogue did not identify its model generation source")
	elif str(app.actor_dialogue_error_by_id.get("N04", "")) == "":
		return _fail("NPC dialogue failure was hidden instead of reported")
	if app.game_screen_controller.actor_portrait.texture != app.presentation_registry.actor_profile("N04").portrait():
		return _fail("actor selection did not switch the production portrait")
	if app.game_screen_controller.actor_portrait_name.text != "魏无咎" or not app.game_screen_controller.location_panel.visible:
		return _fail("actor selection did not update the visible stage caption")
	var actor_focus_text := _descendant_text(app.game_screen_controller.actor_focus_message_list) + _descendant_text(app.game_screen_controller.actor_focus_detail_box) + _descendant_text(app.game_screen_controller.actor_focus_footer)
	if not app.game_screen_controller.actor_focus_workspace.visible or app.game_screen_controller.fact_action_scroll.visible or "选择线索" not in actor_focus_text or "相关性" not in actor_focus_text or "可能结果" not in actor_focus_text or "传播风险" not in actor_focus_text or "确认告知" not in actor_focus_text or "送出后不可撤回" not in actor_focus_text:
		return _fail("actor focus does not expose selection, decision context, and fixed commitment footer")
	var risk_header: Node = app.game_screen_controller.actor_focus_detail_box.find_child("RiskHeader", true, false)
	if not risk_header is HBoxContainer or "传播风险" not in _descendant_text(risk_header):
		return _fail("actor focus does not use a single-row risk header")
	var relevance_header: Node = _hbox_with_text(app.game_screen_controller.actor_focus_detail_box, "相关性")
	var timing_header: Node = _hbox_with_text(app.game_screen_controller.actor_focus_detail_box, "传播时机")
	if not relevance_header is HBoxContainer or "相关性" not in _descendant_text(relevance_header):
		return _fail("actor focus does not keep relevance metadata on one labeled row")
	if timing_header != null and (not timing_header is HBoxContainer or "传播时机" not in _descendant_text(timing_header)):
		return _fail("actor focus timing metadata is not kept on one labeled row")
	if "选择要传达的话" in actor_focus_text or "◆" in actor_focus_text or "✦" in actor_focus_text:
		return _fail("actor focus still uses verbose selection copy or ambiguous glyph markers")
	if not app.game_screen_controller.actor_focus_detail_scroll.visible or app.game_screen_controller.action_dock_title.text != "魏无咎":
		return _fail("populated actor focus did not keep a single actor title and its decision detail")
	if app.game_screen_controller.location_detail_box.visible or app.game_screen_controller.stage_people_box.visible:
		return _fail("actor focus keeps unrelated location chrome above the dialogue action")
	var original_dialogue_history: Array = app.actor_dialogue_history_by_id.get("N04", [])
	var long_dialogue_history: Array = []
	for dialogue_index in range(20):
		long_dialogue_history.append({
			"speaker": "player" if dialogue_index % 2 == 0 else "npc",
			"text": "用于验证长对话滚动与固定输入区的第 %d 条消息。" % (dialogue_index + 1),
		})
	app.actor_dialogue_history_by_id["N04"] = long_dialogue_history
	app.actor_dialogue_visible_count_by_id.erase("N04")
	app.action_panel_controller._render_actions(actions)
	await process_frame
	await process_frame
	var dialogue_input: Node = app.game_screen_controller.actor_dialogue_input_host.find_child("ActorDialogueInput", true, false)
	var history_scroll: ScrollContainer = app.game_screen_controller.actor_focus_message_scroll
	var history_scroll_bar := history_scroll.get_v_scroll_bar()
	if not dialogue_input is TextEdit:
		return _fail("long actor dialogue does not use a multi-line input")
	var dialogue_text_edit := dialogue_input as TextEdit
	if not dialogue_text_edit.is_visible_in_tree() or dialogue_text_edit.custom_minimum_size.y < 72:
		return _fail("long actor dialogue does not keep a visible multi-line input at the bottom")
	if "查看更早对话 · 12 条" not in _descendant_text(app.game_screen_controller.actor_focus_message_list):
		return _fail("long actor dialogue does not collapse older messages behind a clear progressive disclosure control")
	if history_scroll_bar.max_value <= history_scroll_bar.page or history_scroll.scroll_vertical <= 0:
		return _fail("long actor dialogue history is not independently scrollable or did not open at the latest message")
	app.actor_dialogue_history_by_id["N04"] = original_dialogue_history
	app.actor_dialogue_visible_count_by_id.erase("N04")
	app.action_panel_controller._render_actions(actions)
	await process_frame
	app.action_panel_controller._render_actions([])
	await process_frame
	var actor_empty_text := _descendant_text(app.game_screen_controller.actor_focus_message_list) + _descendant_text(app.game_screen_controller.actor_focus_detail_box)
	if "暂无可传达的新消息" not in actor_empty_text or "查看人物卷宗" not in actor_empty_text or "选择线索" in actor_empty_text or app.game_screen_controller.actor_focus_detail_scroll.visible or app.game_screen_controller.actor_focus_footer.visible:
		return _fail("actor focus empty state did not collapse to one clear message and next step: detail=%s footer=%s text=%s" % [app.game_screen_controller.actor_focus_detail_scroll.visible, app.game_screen_controller.actor_focus_footer.visible, actor_empty_text])
	app.action_panel_controller._render_actions(actions)
	await process_frame
	for bus_name in ["Ambient", "Event", "UI"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			return _fail("missing audio bus: " + bus_name)
	app.start_settings_screen_controller._open_audio_settings()
	if not app.settings_layer.visible or app.game_screen_controller.action_canvas.visible:
		return _fail("audio settings entry did not open")
	var settings_text := _descendant_text(app.settings_box)
	if "窗口模式" not in settings_text or "输出分辨率" not in settings_text or "界面缩放" not in settings_text:
		return _fail("display settings do not expose mode, resolution, and UI scale")
	if "大模型" not in settings_text or "模型" not in settings_text or "接口地址" not in settings_text or "API Key" not in settings_text:
		return _fail("AI settings do not expose enablement, model, endpoint, and API key")
	if not app.ai_api_key_input.secret:
		return _fail("AI API key input is not masked")
	if "4K" not in app.display_settings_controller._resolution_label(Vector2i(3840, 2160)):
		return _fail("display settings do not expose a 4K output preset")
	var original_display_mode: String = app.display_mode
	app.display_mode = "borderless"
	app.display_settings_controller._apply_display_settings(false)
	if not app.display_resolution_option.disabled or "原生" not in app.display_resolution_option.get_item_text(0):
		return _fail("fullscreen display mode does not use the monitor's native resolution")
	app.display_mode = original_display_mode
	app.display_settings_controller._apply_display_settings(false)
	app.start_settings_screen_controller._toggle_motion()
	if app.motion_enabled or app.game_screen_controller.world_map_view.motion_enabled or app.presentation_director.motion_enabled:
		return _fail("reduced-motion preference did not propagate to presentation components")
	app.start_settings_screen_controller._toggle_motion()
	app.start_settings_screen_controller._close_audio_settings()
	if not app.game_screen_controller.action_canvas.visible:
		return _fail("closing audio settings did not restore the location action layer")
	app.game_screen_controller._on_map_location_selected("L02")
	if app.selected_map_location_id != "L02" or app.game_screen_controller.map_detail_box.get_child_count() == 0:
		return _fail("map location selection has no detail state")
	var qinglan_map_text := _descendant_text(app.game_screen_controller.map_detail_box)
	if "前往青岚门驻地" not in qinglan_map_text:
		return _fail("map travel call to action does not name its destination")
	if "人物动向" not in qinglan_map_text or "沈砚秋" not in qinglan_map_text:
		return _fail("map detail does not explain who is acting at the selected place")
	app.game_screen_controller._set_visual_mode("location")
	if not app.game_screen_controller.location_panel.visible or app.game_screen_controller.map_panel.visible or not app.game_screen_controller.action_dock.visible:
		return _fail("location scene mode did not replace the map")
	if app.game_screen_controller.action_dock_host.anchor_top > 0.33 or not is_equal_approx(app.game_screen_controller.action_dock_host.anchor_bottom, 0.94):
		return _fail("location action dock does not preserve its top room and footer safe area")
	app._show_operation_status("action")
	if app.game_screen_controller.action_dock_title.text != "正在推演行动结果…" or app.game_screen_controller.footer_label.text != "":
		return _fail("visible action dock repeats its pending state in the global footer")
	app.action_panel_controller._render_actions(app.available_actions_cache)
	app.game_screen_controller._set_visual_mode("map")
	if app.game_screen_controller.action_dock.visible:
		return _fail("map mode keeps the narrative action dock open")
	if app.game_screen_controller.map_mode_button.text != "◇ 地图" or app.game_screen_controller.location_mode_button.text != "◉ 当前地点":
		return _fail("map and location modes still rely on unexplained poetic labels")
	if app.game_screen_controller.day_label.text != "◷ 1 / 30":
		return _fail("initial day is not player-facing day one")
	if app.game_screen_controller.place_label.visible or app.game_screen_controller.phase_label.text != "◌ 筹备":
		return _fail("global header repeats the location name or loses the preparation phase")
	if app.game_screen_controller.timing_label.text != "第24天 · 传闻":
		return _fail("initial known timing is not visible")
	app.journal_panel_controller._open_journal()
	if not app.journal_layer.visible or app.game_screen_controller.action_canvas.visible or app.player_summary_label.visible or app.player_resources_box.visible:
		return _fail("journal overview repeats the player summary outside the gear section")
	if app.journal_tabs.get_tab_count() != 5 or app.journal_travel_button.text != "行装 · 缺 2" or app.journal_graph_button.text != "图谱":
		return _fail("travel dossier does not expose its layered sections and knowledge graph")
	for tab_index in app.journal_tabs.get_tab_count():
		app.journal_panel_controller._select_journal_tab(tab_index)
		await process_frame
		if app.journal_panel.anchor_left > 0.051 or app.journal_panel.anchor_right < 0.991:
			return _fail("journal sibling tabs do not share the same near-fullscreen frame")
	app.journal_panel_controller._select_journal_tab(1)
	var clue_text := _descendant_text(app.clues_box)
	if "待核验" not in clue_text or "条已知" in clue_text:
		return _fail("material summary repeats the tab total instead of prioritizing unresolved work")
	var clue_header: Node = _hbox_with_text(app.clues_box, "待核验")
	if not clue_header is HBoxContainer or "待核验" not in _descendant_text(clue_header):
		return _fail("clue claim, confidence, and source are not kept on one row")
	app.journal_panel_controller._select_journal_tab(2)
	var people_text := _descendant_text(app.people_box)
	if "局势人物" not in people_text or "青岚门驻地 · 3 人观望" not in people_text or "观察各方动向" not in people_text or "此地人物" not in people_text or "可交谈 4" not in people_text:
		return _fail("people dossier does not separate shared world plans from local conversation choices: " + people_text)
	var local_people_header: Node = app.people_box.find_child("LocalPeopleHeader", true, false)
	if not local_people_header is HBoxContainer or "此地人物" not in _descendant_text(local_people_header) or "在场 4" not in _descendant_text(local_people_header) or "可交谈 4" not in _descendant_text(local_people_header):
		return _fail("people dossier does not keep the local title and availability counts on one row")
	var situation_header: Node = _hbox_with_text(app.people_box, "观察各方动向")
	var actor_summary_header: Node = _hbox_with_text(app.people_box, "关注")
	if not situation_header is HBoxContainer or "观察各方动向" not in _descendant_text(situation_header) or not actor_summary_header is HBoxContainer or "关注" not in _descendant_text(actor_summary_header):
		return _fail("people dossier still separates summary titles from their status tags")
	if people_text.count("观察各方动向") != 1 or people_text.count("尚未掌握足以改变公开安排的可靠消息") != 1 or "目标 ·" in people_text or "计划 ·" in people_text or "缘由 ·" in people_text:
		return _fail("people dossier still repeats shared plan fields or exposes flat field labels: " + people_text)
	if app.player_summary_label.visible or app.player_resources_box.visible:
		return _fail("people dossier still competes with the player gear summary")
	app.journal_panel_controller._select_journal_tab(3)
	var player_metrics := _descendant_text(app.player_resources_box)
	if not app.player_summary_label.visible or not app.player_resources_box.visible or "战力 2" not in player_metrics or "灵石 100" not in player_metrics or "助力 0" in player_metrics or "伤势 0" in player_metrics:
		return _fail("gear section did not own the compact player summary")
	if _descendant_type_count(app.player_resources_box, "PanelContainer") > 0 or player_metrics.count("·") < 3:
		return _fail("gear resources still use boxed chips or unexplained accent bars")
	if app.player_summary_label.get_parent() != app.player_resources_box.get_parent() or not app.player_summary_label.get_parent() is HBoxContainer:
		return _fail("gear section does not keep player identity and resources on one row")
	var travel_text := _descendant_text(app.travel_box)
	if app.journal_tabs.current_tab != 3 or app.journal_travel_button.text != "行装" or "尚缺 2 项" not in travel_text or "缺少 · 解瘴丹" not in travel_text or "购买解瘴丹 · 灵石 20" not in travel_text or "入口尚未开放" not in travel_text or "准备度" not in travel_text or not app.journal_travel_details_fold is FoldableContainer or app.journal_travel_details_fold.title != "路线与依据" or app.journal_travel_details_fold.focus_mode != Control.FOCUS_ALL:
		return _fail("gear section does not prioritize blocking preparation: " + travel_text)
	var preparation_header: Node = _hbox_with_text(app.travel_box, "准备度")
	if not preparation_header is HBoxContainer or "准备度" not in _descendant_text(preparation_header) or "2 / 6" not in _descendant_text(preparation_header) or "明显不足" not in _descendant_text(preparation_header):
		return _fail("gear readiness title, score, and rating are not kept on one row")
	var blocker_list: Node = app.travel_box.find_child("TravelBlockerList", true, false)
	var preparation_section: Node = app.travel_box.find_child("PreparationSection", true, false)
	if not blocker_list is VBoxContainer or _descendant_type_count(blocker_list, "PanelContainer") > 0 or not preparation_section is VBoxContainer or _descendant_type_count(preparation_section, "PanelContainer") > 0:
		return _fail("gear blockers or readiness still use nested information cards")
	if "仍缺 2 项才能成行" in travel_text or "你的争夺准备" in travel_text or "综合准备" in travel_text:
		return _fail("gear section still uses repetitive or system-like preparation copy: " + travel_text)
	if not app.journal_travel_details_fold.folded:
		return _fail("gear section exposes completed checks before the player asks")
	app.journal_travel_details_fold.expand()
	await process_frame
	var expanded_travel_text := _descendant_text(app.journal_travel_details_box)
	if app.journal_travel_details_fold.folded or not app.journal_travel_details_box.is_visible_in_tree() or "路线已发现" not in expanded_travel_text:
		return _fail("gear section cannot reveal completed checks on demand")
	var route_header: Node = _hbox_with_text(app.journal_travel_details_box, "路线已发现")
	if not route_header is HBoxContainer or "路线已发现" not in _descendant_text(route_header):
		return _fail("expanded route title and readiness state are not kept on one row")
	app.journal_panel_controller._select_journal_tab(4)
	await process_frame
	var graph_text := _descendant_text(app.knowledge_graph_detail_box)
	if app.journal_tabs.current_tab != 4 or app.journal_panel.anchor_left > 0.051 or app.knowledge_graph_view.visible_node_count() == 0:
		return _fail("knowledge graph did not open as a wide, populated dossier view")
	if "待核验" not in graph_text or "第1日获知" not in graph_text or "F02" in graph_text:
		return _fail("knowledge graph detail either lacks player-facing context or leaks an internal fact id: " + graph_text)
	if graph_text.begins_with("说法\n") or "这是玩家当前掌握的说法" in graph_text or "来源\n" in graph_text or "获知时间\n" in graph_text or "可以继续" in graph_text:
		return _fail("knowledge graph detail still exposes redundant field labels or system explanation: " + graph_text)
	if "第1日获知" not in graph_text or "相关人物" not in graph_text or "下一步" not in graph_text or "告知对象" not in graph_text or "核验这条线索" not in graph_text:
		return _fail("knowledge graph detail does not follow conclusion, provenance, relations, action hierarchy: " + graph_text)
	if "相关说法" in graph_text or "核验这条说法" in graph_text or "告知人物" in graph_text:
		return _fail("knowledge graph still mixes player-facing clue terminology with internal claim terminology: " + graph_text)
	if "可告知" in graph_text:
		return _fail("knowledge graph detail repeats actionable relation labels instead of grouping actions: " + graph_text)
	var selected_claim_id := str(app.knowledge_graph_view.selected_node().get("id", ""))
	app.journal_panel_controller._select_graph_filter("claim")
	await process_frame
	var relation_button: Button = _knowledge_relation_button(app.knowledge_graph_detail_box)
	if not relation_button:
		return _fail("knowledge graph relation did not render as a focusable navigation control")
	if relation_button.text.begins_with("人　") or relation_button.text.begins_with("说　") or relation_button.text.begins_with("事　") or relation_button.text.begins_with("地　"):
		return _fail("knowledge graph relation repeats the type already expressed by its section heading")
	var relation_id := str(relation_button.get_meta("knowledge_relation_id", ""))
	relation_button.pressed.emit()
	await process_frame
	if relation_id == "" or str(app.knowledge_graph_view.selected_node().get("id", "")) != relation_id or app.knowledge_graph_view.active_filter != "all":
		return _fail("knowledge graph relation control did not switch focus and reveal the related node")
	app.journal_panel_controller._focus_knowledge_node(selected_claim_id)
	await process_frame
	var checked_edge_path := false
	for edge in app.knowledge_graph_view.edges:
		var source_id := str(edge.get("source_id", ""))
		var target_id := str(edge.get("target_id", ""))
		if not app.knowledge_graph_view.node_rects.has(source_id) or not app.knowledge_graph_view.node_rects.has(target_id):
			continue
		var source_rect: Rect2 = app.knowledge_graph_view.node_rects[source_id]
		var target_rect: Rect2 = app.knowledge_graph_view.node_rects[target_id]
		var edge_path: PackedVector2Array = app.knowledge_graph_view._edge_path(source_rect, target_rect)
		if edge_path.size() != 25 or source_rect.has_point(edge_path[0]) or target_rect.has_point(edge_path[edge_path.size() - 1]):
			return _fail("knowledge graph edge path does not terminate outside node cards")
		checked_edge_path = true
		break
	if not checked_edge_path:
		return _fail("knowledge graph did not expose a visible edge path for layout regression")
	app.journal_panel_controller._select_graph_filter("actor")
	if app.knowledge_graph_view.active_filter != "actor" or app.knowledge_graph_view.visible_node_count() != app.current_view.get("known_actors", []).size():
		return _fail("knowledge graph actor filter does not match visible actors")
	app.journal_panel_controller._select_graph_filter("all")
	app.journal_panel_controller._select_journal_tab(0)
	app.journal_panel_controller._close_journal()
	if app.journal_layer.visible or app.game_screen_controller.action_canvas.visible != (app.visual_mode == "location"):
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
			if app.action_panel_controller._action_needs_confirmation(action):
				return _fail("ordinary verification still uses a blocking commitment modal")
		if action.get("id", "") == "wait:next":
			if not app.action_panel_controller._action_needs_confirmation(action):
				return _fail("open-ended time advance lost its confirmation")
			if int(action.get("completion_day", 0)) != 0:
				return _fail("open-ended advance exposes a misleading completion day")
			app.action_panel_controller._consider_action(action)
			if not app.confirmation_layer.visible:
				return _fail("multi-day advance has no confirmation")
			if not app.confirmation_details_fold is FoldableContainer or app.confirmation_details_fold.title != "盘算详情" or app.confirmation_details_fold.focus_mode != Control.FOCUS_ALL or not app.confirmation_details_fold.folded:
				return _fail("confirmation reveals secondary reasoning before the player asks")
			app.confirmation_details_fold.expand()
			await process_frame
			if app.confirmation_details_fold.folded or not app.confirmation_details_box.is_visible_in_tree():
				return _fail("confirmation reasoning disclosure cannot be opened")
			var reasoning_text := _descendant_text(app.confirmation_details_box)
			if "执行判断" not in reasoning_text or "仍未知" not in reasoning_text:
				return _fail("confirmation does not expose uncertainty separately")
			app.action_panel_controller._cancel_confirmation()
			break
	if not found_verification:
		return _fail("initial verification action is missing")
	var hierarchy_probe := {
		"id": "test:hierarchy",
		"name": "按约赴会",
		"kind": "route",
		"description": "确认是否按约行动。",
		"timing": "明日抵达",
		"expected_outcomes": ["换取一次会面"],
		"costs": {"spirit_stones": 5},
		"warnings": ["道路尚不安稳"],
		"irreversible": true,
	}
	app.action_panel_controller._consider_action(hierarchy_probe)
	var confirmation_text := _descendant_text(app.confirmation_box) + _descendant_text(app.confirmation_actions_box)
	if "时机与消耗" not in confirmation_text or "风险与承诺" not in confirmation_text or "时机与代价" in confirmation_text or "按约赴会" not in _descendant_text(app.confirmation_actions_box):
		return _fail("confirmation hierarchy does not separate neutral context from actual risk")
	var confirmation_context_header: Node = _hbox_with_text(app.confirmation_box, "时机与消耗")
	if not confirmation_context_header is HBoxContainer or "明日抵达" not in _descendant_text(confirmation_context_header) or "灵石 5" not in _descendant_text(confirmation_context_header):
		return _fail("confirmation timing and costs are not kept in the context title row")
	app.action_panel_controller._cancel_confirmation()
	var tell_probe := {
		"id": "test:tell-hierarchy",
		"name": "告知某人一条线索",
		"kind": "tell",
		"target_name": "某人",
		"target_role": "知情者",
		"fact_claim": "一条待核验的线索",
		"relevance": "直接相关 · 对方公开关注：线索去向",
		"risk": "未经核验，可能改变对方行动。",
		"timing": "时机 · 传闻口径 · 行动后预留 2 日抵达",
		"expected_outcomes": ["对方获得这条线索"],
		"known_conditions": ["对方就在此地", "你持有这条线索"],
		"unknowns": ["对方是否采用消息"],
		"completion_day": 1,
		"warnings": ["线索尚未核实"],
		"irreversible": true,
	}
	app.action_panel_controller._consider_action(tell_probe)
	var tell_confirmation_text := _descendant_text(app.confirmation_box)
	if "人物与线索" in tell_confirmation_text or "传闻口径" not in tell_confirmation_text or "预计 2 日后抵达" not in tell_confirmation_text:
		return _fail("tell confirmation does not expose a compact person, clue, and timing summary")
	app.confirmation_details_fold.expand()
	await process_frame
	var tell_reasoning_text := _descendant_text(app.confirmation_details_box)
	if "执行判断" not in tell_reasoning_text or "对方情况" not in tell_reasoning_text or "相关性" not in tell_reasoning_text or tell_reasoning_text.count("直接相关") != 1:
		return _fail("tell reasoning does not use the two-column hierarchy or repeats relevance labels")
	if tell_confirmation_text.count("对方获得这条线索") != 1 or tell_confirmation_text.count("预计 2 日后抵达") != 1 or "人物\n某人" in tell_reasoning_text:
		return _fail("tell confirmation repeats its result, timing, or person field label")
	app.action_panel_controller._cancel_confirmation()

	app.action_panel_controller._consider_action(actions[0])
	if app.confirmation_layer.visible:
		app.action_panel_controller._confirm_selected_action()
	if not await _wait_until_idle(12000):
		return _fail("action or autosave request timed out")
	if int(app.current_view.get("day", 0)) < 1:
		return _fail("action returned an invalid view")
	if app.presentation_director.generation < 1:
		return _fail("action result did not enter the presentation queue")
	var presentation: Dictionary = app.current_view.get("last_turn", {}).get("presentation", {})
	if presentation.get("kind", "") != "focus":
		return _fail("verification start has no semantic presentation cue")
	if app.presentation_director.card.anchor_left != 0.0 or app.presentation_director.message_label.text == "" or app.presentation_director.message_label.autowrap_mode != TextServer.AUTOWRAP_OFF or app.presentation_director.message_label.max_lines_visible != 1 or app.presentation_director.card.offset_right - app.presentation_director.card.offset_left < 680:
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
	if app.journal_echo_button.text != "回响 · 新" or not app.journal_feedback_details_fold.folded:
		return _fail("new echo is not marked or reveals its evidence by default")
	app.journal_panel_controller._open_journal()
	if not app.journal_feedback_details_fold is FoldableContainer or app.journal_feedback_details_fold.title != "推演过程" or app.journal_feedback_details_fold.focus_mode != Control.FOCUS_ALL:
		return _fail("echo summary does not offer progressive disclosure")
	app.journal_feedback_details_fold.expand()
	await process_frame
	if app.journal_feedback_details_fold.folded or not app.journal_feedback_details_box.is_visible_in_tree():
		return _fail("echo evidence cannot be expanded")
	app.journal_panel_controller._close_journal()
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


func _wait_for_dialogue(actor_id: String, timeout_ms := 34000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if app.actor_dialogue_loading_id == "" and (app.actor_dialogue_by_id.has(actor_id) or app.actor_dialogue_error_by_id.has(actor_id)):
			return true
	return false


func _descendant_text(node: Node) -> String:
	var result := ""
	if node is Label or node is Button:
		result += str(node.text) + "\n"
	for child in node.get_children():
		result += _descendant_text(child)
	return result


func _hbox_with_text(node: Node, expected_text: String) -> HBoxContainer:
	for child in node.get_children():
		var found := _hbox_with_text(child, expected_text)
		if found:
			return found
	if node is HBoxContainer and expected_text in _descendant_text(node):
		return node
	return null


func _descendant_type_count(node: Node, class_type: String) -> int:
	var count := 1 if node.is_class(class_type) else 0
	for child in node.get_children():
		count += _descendant_type_count(child, class_type)
	return count


func _knowledge_relation_button(node: Node) -> Button:
	if node is Button and node.has_meta("knowledge_relation_id"):
		return node
	for child in node.get_children():
		var found := _knowledge_relation_button(child)
		if found:
			return found
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
