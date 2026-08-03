extends RefCounted

var host


func _init(value) -> void:
	host = value


func _build_journal_layer() -> void:
	host.journal_layer = Control.new()
	host.journal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.journal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	host.journal_layer.hide()
	host.add_child(host.journal_layer)
	var shade = ColorRect.new()
	shade.color = Color("030504df")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.journal_layer.add_child(shade)
	var dismiss_area = Button.new()
	dismiss_area.flat = true
	dismiss_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dismiss_area.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	dismiss_area.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	dismiss_area.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	dismiss_area.pressed.connect(host.journal_panel_controller._close_journal)
	host.journal_layer.add_child(dismiss_area)
	host.journal_panel = PanelContainer.new()
	host.journal_panel.anchor_left = 0.57
	host.journal_panel.anchor_right = 0.992
	host.journal_panel.anchor_top = 0.026
	host.journal_panel.anchor_bottom = 0.974
	host.journal_panel.add_theme_stylebox_override("panel", host.game_screen_controller._panel_style(Color("101612ff"), 1, 3, Color(host.COLORS.accent, 0.44), 24, 20))
	host.journal_layer.add_child(host.journal_panel)
	host.journal_paper = TextureRect.new()
	host.journal_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.journal_paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.journal_paper.stretch_mode = TextureRect.STRETCH_SCALE
	host.journal_paper.modulate = Color(0.22, 0.25, 0.21, 0.16)
	host.journal_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.journal_paper.hide()
	host.journal_panel.add_child(host.journal_paper)
	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	host.journal_panel.add_child(outer)
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	outer.add_child(title_row)
	var title = Label.new()
	title.text = "随身卷宗"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", host.display_font)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", host.COLORS.accent)
	title_row.add_child(title)
	var close_button = host.game_screen_controller._utility_button("收起", host.journal_panel_controller._close_journal)
	close_button.custom_minimum_size = Vector2(72, 38)
	title_row.add_child(close_button)
	host.player_summary_label = Label.new()
	host.player_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.player_summary_label.add_theme_font_override("font", host.medium_font)
	host.player_summary_label.add_theme_font_size_override("font_size", host.TYPE_SCALE.body)
	host.player_summary_label.add_theme_constant_override("line_spacing", 4)
	host.player_summary_label.add_theme_color_override("font_color", host.COLORS.ink)
	outer.add_child(host.player_summary_label)
	host.player_resources_box = HFlowContainer.new()
	host.player_resources_box.add_theme_constant_override("h_separation", 7)
	host.player_resources_box.add_theme_constant_override("v_separation", 7)
	outer.add_child(host.player_resources_box)
	var rule = HSeparator.new()
	rule.modulate = Color(host.COLORS.accent, 0.35)
	outer.add_child(rule)
	host.journal_panel_controller._build_reference_tabs(outer)


func _build_reference_tabs(parent: VBoxContainer) -> void:
	var navigation = HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 2)
	parent.add_child(navigation)
	host.journal_echo_button = host.journal_panel_controller._journal_tab_button("回响", 0)
	host.journal_clues_button = host.journal_panel_controller._journal_tab_button(host._ui_text("term_clues"), 1)
	host.journal_people_button = host.journal_panel_controller._journal_tab_button("人物", 2)
	host.journal_travel_button = host.journal_panel_controller._journal_tab_button("行装", 3)
	for button in [host.journal_echo_button, host.journal_clues_button, host.journal_people_button, host.journal_travel_button]:
		navigation.add_child(button)
	host.journal_tabs = TabContainer.new()
	host.journal_tabs.tabs_visible = false
	host.journal_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(host.journal_tabs)
	host.scene_box = host.journal_panel_controller._reference_tab(host.journal_tabs, "回响")
	host.clues_box = host.journal_panel_controller._reference_tab(host.journal_tabs, host._ui_text("term_clues"))
	host.people_box = host.journal_panel_controller._reference_tab(host.journal_tabs, "人物")
	host.travel_box = host.journal_panel_controller._reference_tab(host.journal_tabs, "行装")
	host.journal_panel_controller._refresh_journal_tab_styles()


func _journal_tab_button(label_text: String, index: int) -> Button:
	var button = host.game_screen_controller._utility_button(label_text, host.journal_panel_controller._select_journal_tab.bind(index))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 38)
	button.add_theme_font_size_override("font_size", host.TYPE_SCALE.compact)
	return button


func _select_journal_tab(index: int) -> void:
	if not host.journal_tabs:
		return
	host.journal_tabs.current_tab = clampi(index, 0, host.journal_tabs.get_tab_count() - 1)
	host.journal_panel_controller._refresh_journal_tab_styles()


func _refresh_journal_tab_styles() -> void:
	if not host.journal_tabs:
		return
	var buttons: Array[Button] = [host.journal_echo_button, host.journal_clues_button, host.journal_people_button, host.journal_travel_button]
	for index in buttons.size():
		var button = buttons[index]
		if not button:
			continue
		button.text = host.journal_tab_labels[index]
		var active = host.journal_tabs.current_tab == index
		var status_color = host.journal_tab_colors[index]
		button.add_theme_color_override("font_color", host.COLORS.accent if active and status_color == host.COLORS.muted else status_color)
		button.add_theme_color_override("font_hover_color", host.COLORS.ink)
		var normal = host.game_screen_controller._panel_style(Color.TRANSPARENT, 0, 0, Color.TRANSPARENT, 8, 7)
		normal.border_width_bottom = 2 if active else 0
		normal.border_color = host.COLORS.accent
		button.add_theme_stylebox_override("normal", normal)


func _render_journal_tab_states(clues: Array, actors: Array, travel, feedback, actions: Array) -> void:
	host.journal_current_feedback_signature = host.journal_panel_controller._feedback_signature(feedback) if feedback is Dictionary else ""
	var has_unread_feedback = host.journal_current_feedback_signature != "" and host.journal_current_feedback_signature != host.journal_seen_feedback_signature
	host.journal_tab_labels[0] = "回响 · 新" if has_unread_feedback else "回响"
	host.journal_tab_colors[0] = host.COLORS.accent if has_unread_feedback else host.COLORS.muted
	var actionable_clues = 0
	for clue in clues:
		var fact_id = str(clue.get("fact_id", ""))
		if host.journal_panel_controller._has_action_for_fact(actions, fact_id):
			actionable_clues += 1
	var clue_term: String = str(host._ui_text("term_clues"))
	host.journal_tab_labels[1] = "%s · %d" % [clue_term, actionable_clues] if actionable_clues > 0 else clue_term
	host.journal_tab_colors[1] = host.COLORS.muted
	var talkable_people = 0
	for actor in actors:
		if host.action_panel_controller._count_tell_actions(actions, str(actor.get("id", "")), "") > 0:
			talkable_people += 1
	host.journal_tab_labels[2] = "人物 · %d" % talkable_people if talkable_people > 0 else "人物"
	host.journal_tab_colors[2] = host.COLORS.muted
	host.journal_tab_labels[3] = "行装"
	host.journal_tab_colors[3] = host.COLORS.muted
	if travel is Dictionary:
		var missing = host.journal_panel_controller._travel_missing_checks(travel).size()
		if missing > 0:
			host.journal_tab_labels[3] = "行装 !%d" % missing
			host.journal_tab_colors[3] = host.COLORS.danger
		else:
			host.journal_tab_labels[3] = "行装 · 齐"
			host.journal_tab_colors[3] = host.COLORS.success
	host.journal_panel_controller._refresh_journal_tab_styles()


func _reference_tab(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.name = tab_name
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 9)
	scroll.add_child(box)
	return box


func _open_journal() -> void:
	host.audio_director.play_ui()
	if not host.motion_enabled:
		host.journal_panel.position.x = 0
		host.journal_layer.modulate = Color.WHITE
		host.journal_layer.show()
		host.game_screen_controller._sync_action_canvas_visibility()
		return
	host.journal_panel.position.x = 42
	host.journal_layer.modulate = Color(1, 1, 1, 0)
	host.journal_layer.show()
	host.game_screen_controller._sync_action_canvas_visibility()
	var tween = host.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(host.journal_layer, "modulate", Color.WHITE, 0.22)
	tween.tween_property(host.journal_panel, "position:x", 0.0, 0.28)


func _close_journal() -> void:
	host.audio_director.play_ui()
	host.journal_layer.hide()
	host.journal_panel.position.x = 0
	host.game_screen_controller._sync_action_canvas_visibility()
	if host.journal_current_feedback_signature != "":
		host.journal_seen_feedback_signature = host.journal_current_feedback_signature
		host.journal_panel_controller._render_journal_tab_states(
			host.current_view.get("known_facts", []),
			host.current_view.get("known_actors", []),
			host.current_view.get("travel", null),
			host.current_view.get("last_turn", null),
			host.available_actions_cache,
		)


func _render_clues(clues: Array, actions: Array) -> void:
	host.game_screen_controller._clear(host.clues_box)
	if clues.is_empty():
		host.game_screen_controller._text(host.clues_box, host._ui_text("journal_empty_clues"), true)
		return
	var unverified = 0
	for clue in clues:
		if int(clue.get("confidence", 0)) < 3:
			unverified += 1
	var overview = "%d 条已知" % clues.size()
	if unverified > 0:
		overview += host._ui_text("journal_unverified_count") % unverified
	var overview_label = host.game_screen_controller._text(host.clues_box, overview, true, host.TYPE_SCALE.meta)
	overview_label.add_theme_color_override("font_color", host.COLORS.accent if unverified > 0 else host.COLORS.success)
	for index in clues.size():
		var clue: Dictionary = clues[index]
		var fact_id = str(clue.get("fact_id", ""))
		var clue_texture: Texture2D = host.presentation_registry.fact_texture(fact_id)
		if clue_texture:
			var preview_panel := PanelContainer.new()
			preview_panel.custom_minimum_size.y = 138
			preview_panel.add_theme_stylebox_override("panel", host.game_screen_controller._panel_style(Color("090c0ab8"), 1, 2, Color(host.COLORS.accent, 0.22), 5, 5))
			var preview := TextureRect.new()
			preview.texture = clue_texture
			preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
			preview_panel.add_child(preview)
			host.clues_box.add_child(preview_panel)
		var claim = host.game_screen_controller._text(host.clues_box, str(clue.get("claim", "未知传言")), false, 15)
		claim.add_theme_font_override("font", host.medium_font)
		var confidence = int(clue.get("confidence", 0))
		var status = "已核实" if confidence >= 3 else ("较可信" if confidence == 2 else "未经核实")
		if bool(clue.get("contested", false)):
			status += " · 与旧说法冲突"
		var status_line = host.game_screen_controller._text(host.clues_box, "%s · %s" % [status, clue.get("source", "来源未知")], true, 13)
		status_line.add_theme_color_override("font_color", host.COLORS.success if confidence >= 3 else host.COLORS.accent)
		var verify_action = host.journal_panel_controller._action_for_fact(actions, fact_id, "verify")
		var target_count = host.action_panel_controller._count_tell_actions(actions, "", fact_id)
		if not verify_action.is_empty() and confidence < 3:
			var verify_link = host.game_screen_controller._action_button(host._ui_text("journal_verify_clue"), host.action_panel_controller._consider_action.bind(verify_action))
			verify_link.custom_minimum_size.y = 36
			host.clues_box.add_child(verify_link)
		elif target_count > 0:
			var link = host.game_screen_controller._action_button("可告知 %d 人" % target_count, host.action_panel_controller._focus_fact_actions.bind(fact_id, str(clue.get("claim", "未知传言"))))
			link.custom_minimum_size.y = 36
			host.clues_box.add_child(link)
		if index < clues.size() - 1:
			var separator = HSeparator.new()
			separator.modulate = Color(host.COLORS.line, 0.58)
			host.clues_box.add_child(separator)


func _action_for_fact(actions: Array, fact_id: String, kind: String = "") -> Dictionary:
	for action in actions:
		if str(action.get("fact_id", "")) != fact_id:
			continue
		if kind != "" and str(action.get("kind", "")) != kind:
			continue
		return action
	return {}


func _has_action_for_fact(actions: Array, fact_id: String) -> bool:
	return not host.journal_panel_controller._action_for_fact(actions, fact_id).is_empty()


func _render_scene(events: Array, guidance: Array, travel, feedback, causal_threads: Array, player_name: String) -> void:
	host.game_screen_controller._clear(host.scene_box)
	if feedback is Dictionary:
		var feedback_signature = host.journal_panel_controller._feedback_signature(feedback)
		if feedback_signature != host.journal_current_feedback_signature:
			host.journal_feedback_details_visible = false
		host.journal_current_feedback_signature = feedback_signature
		host.journal_panel_controller._render_feedback_summary(host.scene_box, feedback)
		var separator = HSeparator.new()
		separator.modulate = host.COLORS.line
		host.scene_box.add_child(separator)
	host.journal_panel_controller._render_causal_threads(host.scene_box, causal_threads)
	if not guidance.is_empty():
		var guidance_heading = host.game_screen_controller._text(host.scene_box, "眼下", true, host.TYPE_SCALE.meta)
		guidance_heading.add_theme_color_override("font_color", host.COLORS.accent)
		for index in range(mini(guidance.size(), 2)):
			host.game_screen_controller._text(host.scene_box, str(guidance[index]), true, 14)
	if events.is_empty():
		if not feedback is Dictionary:
			host.game_screen_controller._text(host.scene_box, "四下暂时没有新的公开动静。", true)
		return
	var event_heading = host.game_screen_controller._text(host.scene_box, "近来风声", true, host.TYPE_SCALE.meta)
	event_heading.add_theme_color_override("font_color", host.COLORS.accent)
	var rendered_events = 0
	for index in range(events.size() - 1, -1, -1):
		var event = events[index]
		if str(event.get("actor_name", "")) == player_name:
			continue
		host.game_screen_controller._text(host.scene_box, "第 %d 日 · %s" % [int(event.get("day", 0)), event.get("description", "局势变化")], true, 14)
		rendered_events += 1
		if rendered_events >= 3:
			break


func _render_causal_threads(parent: VBoxContainer, threads: Array) -> void:
	if threads.is_empty():
		return
	var heading = host.game_screen_controller._text(parent, host._ui_text("information_causal_heading"), true, host.TYPE_SCALE.meta)
	heading.add_theme_color_override("font_color", host.COLORS.accent)
	var first = maxi(0, threads.size() - 2)
	for index in range(threads.size() - 1, first - 1, -1):
		var thread: Dictionary = threads[index]
		var stage = str(thread.get("stage", "delivered"))
		var stage_line = host.game_screen_controller._text(parent, "%s · %s" % [thread.get("actor_name", "有人"), thread.get("stage_label", "已送达")], false, 14)
		stage_line.add_theme_color_override("font_color", host.COLORS.success if stage == "changed" else host.COLORS.accent)
		var fact_line = host.game_screen_controller._text(parent, "“%s”" % thread.get("fact_claim", "一条消息"), true, 16)
		fact_line.add_theme_font_override("font", host.narrative_font)
		fact_line.add_theme_constant_override("line_spacing", 4)
		host.game_screen_controller._text(parent, str(thread.get("summary", "尚无公开回响")), true, 13)


func _render_feedback_summary(parent: VBoxContainer, feedback: Dictionary) -> void:
	var status_names = {"completed": "已结算", "started": "进行中", "failed": "未能完成", "advanced": "已推进"}
	var status_key = str(feedback.get("status", ""))
	var status = str(status_names.get(status_key, "已结算"))
	var day = int(feedback.get("day", host.current_view.get("day", 0)))
	var meta = host.game_screen_controller._text(parent, "第 %d 日 · %s" % [day, status], true, host.TYPE_SCALE.meta)
	meta.add_theme_color_override("font_color", host.COLORS.danger if status_key == "failed" else host.COLORS.accent)
	var influences: Array = feedback.get("influence", [])
	var headline = str(feedback.get("action", "局势有了变化"))
	var cause = ""
	if not influences.is_empty():
		var influence: Dictionary = influences[0]
		var changes: Array = influence.get("changes", [])
		if not changes.is_empty():
			headline = str(changes[0].get("with_information", headline))
		cause = "%s因你透露“%s”改变了安排" % [influence.get("actor_name", "有人"), influence.get("fact_claim", "一条消息")]
	var title = host.game_screen_controller._text(parent, headline, false, 18)
	title.add_theme_font_override("font", host.display_font)
	if cause != "":
		host.game_screen_controller._text(parent, cause, true, 14)
	var messages: Array = feedback.get("messages", [])
	var stop_reason = str(feedback.get("stop_reason", ""))
	if stop_reason != "":
		var stop_line = host.game_screen_controller._text(parent, "为何停下 · %s" % stop_reason, false, 14)
		stop_line.add_theme_color_override("font_color", host.COLORS.accent)
	for index in range(mini(messages.size(), 2)):
		host.game_screen_controller._text(parent, "· %s" % messages[index], false, 14)
	var journal: Array = feedback.get("journal", [])
	if not journal.is_empty():
		var journal_heading = host.game_screen_controller._text(parent, "记入卷宗", true, host.TYPE_SCALE.meta)
		journal_heading.add_theme_color_override("font_color", host.COLORS.accent)
		for entry in journal:
			host.game_screen_controller._text(parent, "· %s" % entry, false, 14)
	host.journal_feedback_details_button = host.game_screen_controller._utility_button("收起推演过程" if host.journal_feedback_details_visible else "查看推演过程", host.journal_panel_controller._toggle_journal_feedback_details)
	host.journal_feedback_details_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(host.journal_feedback_details_button)
	host.journal_feedback_details_box = VBoxContainer.new()
	host.journal_feedback_details_box.add_theme_constant_override("separation", 6)
	host.journal_feedback_details_box.visible = host.journal_feedback_details_visible
	parent.add_child(host.journal_feedback_details_box)
	host.presentation_controller._render_feedback_evidence_into(host.journal_feedback_details_box, feedback)


func _toggle_journal_feedback_details() -> void:
	host.journal_feedback_details_visible = not host.journal_feedback_details_visible
	if host.journal_feedback_details_box:
		host.journal_feedback_details_box.visible = host.journal_feedback_details_visible
	if host.journal_feedback_details_button:
		host.journal_feedback_details_button.text = "收起推演过程" if host.journal_feedback_details_visible else "查看推演过程"


func _feedback_signature(feedback) -> String:
	if not feedback is Dictionary:
		return ""
	return "%s|%s|%s" % [feedback.get("day", ""), feedback.get("action_id", ""), feedback.get("status", "")]


func _render_travel_readiness(travel, preparation = {}) -> void:
	host.game_screen_controller._clear(host.travel_box)
	host.journal_panel_controller._render_route_progresses(host.travel_box, host.current_view.get("route_progresses", []), false)
	if not travel is Dictionary:
		host.game_screen_controller._text(host.travel_box, "还没有明确的远行目标。", true)
		return
	var route: Array = travel.get("route", [])
	var destination = str(travel.get("destination", "目标地点"))
	if destination == "" and not route.is_empty():
		destination = str(route[route.size() - 1])
	var meta_text = "%s · 约 %d 日" % [destination, int(travel.get("travel_days", 0))]
	var meta = host.game_screen_controller._text(host.travel_box, meta_text, true, host.TYPE_SCALE.meta)
	meta.add_theme_color_override("font_color", host.COLORS.accent)
	var missing = host.journal_panel_controller._travel_missing_checks(travel)
	var ready_checks = host.journal_panel_controller._travel_ready_checks(travel)
	if missing.is_empty():
		var ready_title = host.game_screen_controller._text(host.travel_box, "行装已经齐备", false, 19)
		ready_title.add_theme_color_override("font_color", host.COLORS.success)
		host.game_screen_controller._text(host.travel_box, "路已认清，可以按自己的时机启程。", true, 14)
	else:
		var missing_title = host.game_screen_controller._text(host.travel_box, "仍缺 %d 项才能成行" % missing.size(), false, 19)
		missing_title.add_theme_color_override("font_color", host.COLORS.danger)
		for check in missing:
			var check_label = str(check.get("label", "路线条件"))
			var missing_line = host.game_screen_controller._text(host.travel_box, host.journal_panel_controller._travel_blocker_text(check_label), false, 15)
			missing_line.add_theme_color_override("font_color", host.COLORS.danger)
			var resolution_action = host.journal_panel_controller._travel_resolution_action(host.available_actions_cache, check_label)
			if not resolution_action.is_empty():
				var resolution_button = host.game_screen_controller._action_button(host.journal_panel_controller._travel_resolution_label(resolution_action), host.journal_panel_controller._consider_action_from_journal.bind(resolution_action))
				resolution_button.custom_minimum_size.y = 38
				host.travel_box.add_child(resolution_button)
	if preparation is Dictionary:
		var score_sources: Array = preparation.get("score_sources", [])
		if not score_sources.is_empty():
			var preparation_heading = host.game_screen_controller._text(host.travel_box, host._ui_text("preparation_heading"), true, host.TYPE_SCALE.meta)
			preparation_heading.add_theme_color_override("font_color", host.COLORS.accent)
			var rating = str(preparation.get("rating", "尚未判断"))
			var total_score = int(preparation.get("total_score", 0))
			var target_score = int(preparation.get("target_score", 0))
			var rating_line = host.game_screen_controller._text(host.travel_box, "综合准备 %d / 基线 %d · %s" % [total_score, target_score, rating], false, 18)
			rating_line.add_theme_color_override("font_color", host.COLORS.success if total_score >= target_score else host.COLORS.danger)
			host.game_screen_controller._text(host.travel_box, str(preparation.get("rating_detail", "")), true, 13)
			for factor in score_sources:
				var factor_line = host.game_screen_controller._text(host.travel_box, "%s %d · %s" % [factor.get("label", "准备"), int(factor.get("value", 0)), factor.get("status", "")], false, 14)
				factor_line.add_theme_color_override("font_color", host.COLORS.success if bool(factor.get("ready", false)) else host.COLORS.muted)
			host.game_screen_controller._text(host.travel_box, host._ui_text("preparation_explanation"), true, 13)
	var timing = str(travel.get("timing", ""))
	if timing != "":
		var timing_line = host.game_screen_controller._text(host.travel_box, timing, true, 13)
		timing_line.add_theme_color_override("font_color", host.COLORS.danger if timing.contains("来不及") else host.COLORS.accent)
	host.journal_travel_details_button = host.game_screen_controller._utility_button("收起完整行装" if host.journal_travel_details_visible else "查看已备与路线", host.journal_panel_controller._toggle_journal_travel_details)
	host.journal_travel_details_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	host.travel_box.add_child(host.journal_travel_details_button)
	host.journal_travel_details_box = VBoxContainer.new()
	host.journal_travel_details_box.add_theme_constant_override("separation", 6)
	host.journal_travel_details_box.visible = host.journal_travel_details_visible
	host.travel_box.add_child(host.journal_travel_details_box)
	if not route.is_empty():
		host.game_screen_controller._text(host.journal_travel_details_box, "路线 · %s" % " → ".join(route), true, 13)
	for check in ready_checks:
		var ready_line = host.game_screen_controller._text(host.journal_travel_details_box, host.journal_panel_controller._travel_ready_text(str(check.get("label", "路线条件"))), false, 13)
		ready_line.add_theme_color_override("font_color", host.COLORS.success)
	if ready_checks.is_empty():
		host.game_screen_controller._text(host.journal_travel_details_box, "尚无已经满足的准备项。", true, 13)


func _render_route_progress(parent: VBoxContainer, route_progress, compact: bool) -> void:
	if not route_progress is Dictionary or route_progress.is_empty():
		return
	var heading = host.game_screen_controller._text(parent, "当前路线 · %s" % route_progress.get("label", "未命名路线"), true, host.TYPE_SCALE.meta)
	heading.add_theme_color_override("font_color", host.COLORS.accent)
	var status = str(route_progress.get("status", "推进中"))
	var next_step = str(route_progress.get("next_step", "等待下一次变化"))
	var status_line = host.game_screen_controller._text(parent, "%s · %s" % [status, next_step], false, 14 if compact else 15)
	status_line.add_theme_color_override("font_color", host.COLORS.danger if bool(route_progress.get("urgent", false)) else (host.COLORS.success if bool(route_progress.get("complete", false)) else host.COLORS.ink))
	if compact:
		return
	var window = str(route_progress.get("window", ""))
	var location = str(route_progress.get("location", ""))
	if window != "" or location != "":
		host.game_screen_controller._text(parent, "窗口 · %s%s" % [window, (" · " + location) if location != "" else ""], true, 13)
	var personal_return = str(route_progress.get("personal_return", ""))
	if personal_return != "":
		host.game_screen_controller._text(parent, "个人收益 · %s" % personal_return, true, 13)


func _render_route_progresses(parent: VBoxContainer, route_progresses, compact: bool = false) -> void:
	if route_progresses is Array and not route_progresses.is_empty():
		var heading = host.game_screen_controller._text(parent, "并行路线 · %d 项" % route_progresses.size(), true, host.TYPE_SCALE.meta)
		heading.add_theme_color_override("font_color", host.COLORS.accent)
		var visible_count: int = mini(3, route_progresses.size()) if compact else route_progresses.size()
		for index in visible_count:
			_render_route_progress(parent, route_progresses[index], compact)
		if compact and route_progresses.size() > visible_count:
			host.game_screen_controller._text(parent, "另有 %d 条路线，详见卷宗。" % (route_progresses.size() - visible_count), true, 12)


func _toggle_journal_travel_details() -> void:
	host.journal_travel_details_visible = not host.journal_travel_details_visible
	if host.journal_travel_details_box:
		host.journal_travel_details_box.visible = host.journal_travel_details_visible
	if host.journal_travel_details_button:
		host.journal_travel_details_button.text = "收起完整行装" if host.journal_travel_details_visible else "查看已备与路线"


func _travel_resolution_action(actions: Array, check_label: String) -> Dictionary:
	var subject = check_label.trim_prefix("携带").strip_edges()
	for action in actions:
		var searchable = "%s %s %s %s" % [action.get("name", ""), action.get("description", ""), host.action_panel_controller._joined_action_values(action.get("resolves", [])), host.action_panel_controller._joined_action_values(action.get("expected_outcomes", []))]
		if subject != "" and searchable.contains(subject):
			return action
	return {}


func _travel_resolution_label(action: Dictionary) -> String:
	var label = str(action.get("name", "处理缺项"))
	var costs: Dictionary = action.get("costs", {})
	var cost_parts: Array[String] = []
	for key in costs:
		if int(costs[key]) > 0:
			cost_parts.append("%s %d" % [host.game_screen_controller._resource_label(str(key)), int(costs[key])])
	if not cost_parts.is_empty():
		label += " · " + "、".join(cost_parts)
	return label


func _consider_action_from_journal(action: Dictionary) -> void:
	host.journal_panel_controller._close_journal()
	host.action_panel_controller._consider_action(action)


func _travel_missing_checks(travel: Dictionary) -> Array:
	var result: Array = []
	for check in travel.get("checks", []):
		if not bool(check.get("ready", false)):
			result.append(check)
	return result


func _travel_ready_checks(travel: Dictionary) -> Array:
	var result: Array = []
	for check in travel.get("checks", []):
		if bool(check.get("ready", false)):
			result.append(check)
	return result


func _travel_blocker_text(label_text: String) -> String:
	if label_text.begins_with("携带"):
		return "缺少 · %s" % label_text.trim_prefix("携带")
	if label_text.contains("入口开放"):
		return label_text.replace("入口开放", "入口尚未开放")
	if label_text.contains("路线"):
		return "尚未发现 · %s" % label_text
	return "未就绪 · %s" % label_text


func _travel_ready_text(label_text: String) -> String:
	if label_text == "可用路线":
		return "路线已发现"
	if label_text.begins_with("携带"):
		return "已备 · %s" % label_text.trim_prefix("携带")
	if label_text.contains("入口开放"):
		return label_text.replace("入口开放", "入口已开放")
	return "已备 · %s" % label_text


func _render_people(actors: Array, actions: Array) -> void:
	host.game_screen_controller._clear(host.people_box)
	var tracked_plans: Array = host.current_view.get("world_map", {}).get("actors", [])
	if actors.is_empty() and tracked_plans.is_empty():
		host.game_screen_controller._text(host.people_box, "此地没有可交谈的人。", true)
		return
	var talkable_people = 0
	for actor in actors:
		if host.action_panel_controller._count_tell_actions(actions, str(actor.get("id", "")), "") > 0:
			talkable_people += 1
	var overview = "%d 人在场" % actors.size()
	if talkable_people > 0:
		overview += " · %d 人有新话可谈" % talkable_people
	var overview_label = host.game_screen_controller._text(host.people_box, overview, true, host.TYPE_SCALE.meta)
	overview_label.add_theme_color_override("font_color", host.COLORS.accent if talkable_people > 0 else host.COLORS.muted)
	if not tracked_plans.is_empty():
		var tracking_heading = host.game_screen_controller._text(host.people_box, "局势追踪 · 核心人物 %d" % tracked_plans.size(), false, 16)
		tracking_heading.add_theme_color_override("font_color", host.COLORS.accent)
		host.game_screen_controller._text(host.people_box, host._ui_text("people_information_hint"), true, 12)
		for plan in tracked_plans:
			var title = "%s · %s · %s" % [plan.get("name", "无名者"), plan.get("location_name", "位置不明"), plan.get("status", "观望")]
			host.game_screen_controller._text(host.people_box, title, false, 14)
			host.game_screen_controller._text(host.people_box, "目标 · %s" % plan.get("public_goal", "尚未公开"), true, 12)
			host.game_screen_controller._text(host.people_box, "计划 · %s" % plan.get("plan", "观察局势"), true, 13)
			host.game_screen_controller._text(host.people_box, "缘由 · %s" % plan.get("reason", "尚未公开"), true, 12)
			if str(plan.get("destination_name", "")) != "":
				host.game_screen_controller._text(host.people_box, "去向 · %s · 预计第 %d 日" % [plan.get("destination_name", "未知地点"), int(plan.get("expected_day", 0))], true, 12)
			if bool(plan.get("changed_by_player", false)):
				var intervention = host.game_screen_controller._text(host.people_box, "因你改变 · 原本%s" % plan.get("previous_plan", "另有安排"), true, 12)
				intervention.add_theme_color_override("font_color", host.COLORS.accent)
		var divider = HSeparator.new()
		divider.modulate = Color(host.COLORS.accent, 0.46)
		host.people_box.add_child(divider)
		var local_heading = host.game_screen_controller._text(host.people_box, "此地人物", false, 16)
		local_heading.add_theme_color_override("font_color", host.COLORS.accent)
	for index in actors.size():
		var actor: Dictionary = actors[index]
		var actor_name = str(actor.get("name", "无名者"))
		host.game_screen_controller._text(host.people_box, "%s · %s" % [actor_name, actor.get("public_role", "可交谈人物")], false, 16)
		var focus: Array = actor.get("public_focus", [])
		var context_parts: Array[String] = []
		if not focus.is_empty():
			context_parts.append("关注%s" % str(focus[0]))
		if not context_parts.is_empty():
			host.game_screen_controller._text(host.people_box, " · ".join(context_parts), true, 13)
		var local_plan: Dictionary = actor.get("plan", {}) if actor.get("plan", {}) is Dictionary else {}
		if not local_plan.is_empty():
			host.game_screen_controller._text(host.people_box, "当前计划 · %s" % local_plan.get("plan", "观察局势"), true, 13)
			host.game_screen_controller._text(host.people_box, "缘由 · %s" % local_plan.get("reason", "尚未公开"), true, 12)
		var actor_id = str(actor.get("id", ""))
		var clue_count = host.action_panel_controller._count_tell_actions(actions, actor_id, "")
		var link_text = host._ui_text("people_talk_clues") % clue_count if clue_count > 0 else host._ui_text("people_view")
		var link = host.game_screen_controller._action_button(link_text, host.action_panel_controller._focus_actor_from_reference.bind(actor_id, actor_name))
		link.custom_minimum_size.y = 36
		host.people_box.add_child(link)
		if index < actors.size() - 1:
			var separator = HSeparator.new()
			separator.modulate = Color(host.COLORS.line, 0.7)
			host.people_box.add_child(separator)
