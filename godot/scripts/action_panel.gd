extends RefCounted

var host
var screen


func _init(value, game_screen) -> void:
	host = value
	screen = game_screen


func _build_confirmation_layer() -> void:
	host.confirmation_layer = Control.new()
	host.confirmation_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.confirmation_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	host.confirmation_layer.hide()
	host.add_child(host.confirmation_layer)
	var shade = ColorRect.new()
	shade.color = host.AppVisualThemeScript.alpha8(host.COLORS.overlay, 0x9c)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.confirmation_layer.add_child(shade)
	var card = PanelContainer.new()
	card.anchor_left = 0.08
	card.anchor_right = 0.92
	card.anchor_top = 0.08
	card.anchor_bottom = 0.96
	var confirmation_style = host.ui_factory.panel_style(host.AppVisualThemeScript.alpha8(host.COLORS.surface_dock, 0xf8), 0, 2, Color.TRANSPARENT, 26, 20)
	confirmation_style.border_width_left = 3
	confirmation_style.border_color = host.COLORS.accent
	card.add_theme_stylebox_override("panel", confirmation_style)
	host.confirmation_layer.add_child(card)
	var card_content = VBoxContainer.new()
	card_content.add_theme_constant_override("separation", 10)
	card.add_child(card_content)
	var confirmation_scroll = ScrollContainer.new()
	confirmation_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	confirmation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_content.add_child(confirmation_scroll)
	host.confirmation_box = VBoxContainer.new()
	host.confirmation_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.confirmation_box.add_theme_constant_override("separation", 10)
	confirmation_scroll.add_child(host.confirmation_box)
	var action_rule = HSeparator.new()
	action_rule.modulate = Color(host.COLORS.accent, 0.26)
	card_content.add_child(action_rule)
	host.confirmation_actions_box = HBoxContainer.new()
	host.confirmation_actions_box.add_theme_constant_override("separation", 12)
	card_content.add_child(host.confirmation_actions_box)


func _render_actions(actions: Array) -> void:
	host.ui_factory.clear(screen.actions_box)
	host.ui_factory.clear(screen.overview_actions_box)
	host.ui_factory.clear(screen.actor_focus_message_list)
	host.ui_factory.clear(screen.actor_dialogue_input_host)
	host.ui_factory.clear(screen.actor_focus_detail_box)
	host.ui_factory.clear(screen.actor_focus_footer)
	var focused_actions = host.action_panel_controller._focused_information_actions(actions)
	var has_action_focus = host.focused_actor_id != "" or host.focused_fact_id != ""
	host.action_panel_controller._configure_action_dock_layout(has_action_focus)
	if screen.location_detail_box:
		screen.location_detail_box.visible = not has_action_focus
	if screen.stage_people_box:
		screen.stage_people_box.visible = not has_action_focus
	screen.overview_actions_box.visible = not has_action_focus
	if screen.action_dock_status_box:
		screen.action_dock_status_box.visible = not has_action_focus
	screen.actor_focus_workspace.visible = host.focused_actor_id != ""
	screen.actor_focus_footer.visible = host.focused_actor_id != "" and not focused_actions.is_empty() and not host.ai_server_enabled
	screen.fact_action_scroll.visible = host.focused_fact_id != ""
	if host.focused_actor_id != "":
		screen.action_dock_title.text = host.focused_actor_name
		host.action_panel_controller._render_actor_focus_workspace(focused_actions)
		return
	if host.focused_fact_id != "":
		screen.action_dock_title.text = "把消息交给谁"
		screen.objective_label.text = host.focused_fact_claim
		host.ui_factory.text(screen.actions_box, host.focused_fact_claim, true, 14)
		var back = host.ui_factory.utility_button("回到眼前", host.action_panel_controller._clear_action_focus)
		back.alignment = HORIZONTAL_ALIGNMENT_LEFT
		screen.actions_box.add_child(back)
		if focused_actions.is_empty():
			host.ui_factory.text(screen.actions_box, "这里已经没有尚未听过这条消息的人。", true)
			return
		host.action_panel_controller._add_focused_information_actions(focused_actions)
		return
	screen.action_dock_title.text = str(host.current_view.get("location", {}).get("name", "眼前"))
	var guidance: Array = host.current_view.get("guidance", [])
	screen.objective_label.text = str(guidance[0]) if not guidance.is_empty() else "风声未定，先看清眼前的人和路。"
	if actions.is_empty():
		host.ui_factory.text(screen.overview_actions_box, "眼下无事可做，或许该换个地方看看。", true)
		return
	var eligible = host.action_panel_controller._location_context_actions(actions)
	if eligible.is_empty():
		host.ui_factory.text(screen.overview_actions_box, "想赶路就翻开地图；想传话就先选中一个人。", true, 14)
		return
	host.journal_panel_controller._render_route_progresses(screen.overview_actions_box, host.current_view.get("route_progresses", []), true)
	var visible_count = eligible.size() if host.show_all_actions else mini(3, eligible.size())
	for index in visible_count:
		host.action_panel_controller._add_overview_choice(eligible[index], index)
	if eligible.size() > visible_count:
		var more = host.ui_factory.utility_button("展开其余 %d 项安排" % (eligible.size() - visible_count), host.action_panel_controller._toggle_all_actions)
		more.alignment = HORIZONTAL_ALIGNMENT_LEFT
		screen.overview_actions_box.add_child(more)
	elif host.show_all_actions and eligible.size() > 3:
		var less = host.ui_factory.utility_button("只看眼前要事", host.action_panel_controller._toggle_all_actions)
		less.alignment = HORIZONTAL_ALIGNMENT_LEFT
		screen.overview_actions_box.add_child(less)


func _configure_action_dock_layout(has_action_focus: bool) -> void:
	if not screen.action_dock or not screen.action_dock_host:
		return
	screen.action_dock_host.anchor_top = 0.25 if has_action_focus else 0.32
	screen.action_dock_host.anchor_bottom = 0.94
	var dock_color: Color = host.AppVisualThemeScript.alpha8(host.COLORS.surface_dock, 0xf4 if has_action_focus else 0xec)
	var dock_style = host.ui_factory.panel_style(dock_color, 0, 2, Color.TRANSPARENT, 24, 18)
	dock_style.border_width_left = 2
	dock_style.border_color = Color(host.COLORS.accent, 0.72 if has_action_focus else 0.62)
	screen.action_dock.add_theme_stylebox_override("panel", dock_style)


func _add_overview_choice(action: Dictionary, _index: int) -> void:
	var label = str(action.get("name", "做一件事"))
	var card := PanelContainer.new()
	var card_style = host.ui_factory.panel_style(Color(host.COLORS.panel_alt, 0.28), 0, 2, Color.TRANSPARENT, 10, 7)
	card_style.border_width_left = 2
	card_style.border_color = Color(host.COLORS.line, 0.76)
	card.add_theme_stylebox_override("panel", card_style)
	screen.overview_actions_box.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	card.add_child(content)
	var outcomes = host.action_panel_controller._joined_action_values(action.get("expected_outcomes", []))
	var callback = host.action_panel_controller._consider_action.bind(action, "wait:complete") if action.get("kind", "") == "cultivate" else host.action_panel_controller._consider_action.bind(action)
	var action_header := HBoxContainer.new()
	action_header.name = "OverviewActionHeader"
	action_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_header.add_theme_constant_override("separation", 8)
	content.add_child(action_header)
	var button = host.ui_factory.action_button(label, callback)
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = "%s\n%s" % [action.get("description", ""), action.get("timing", "")]
	action_header.add_child(button)
	host.action_panel_controller._action_tag(action_header, "耗时 %d 日" % int(action.get("duration", 1)), host.COLORS.accent)
	if outcomes != "":
		var outcome = host.ui_factory.text(content, outcomes, true, host.TYPE_SCALE.compact)
		outcome.add_theme_color_override("font_color", host.COLORS.muted)


func _render_actor_focus_workspace(focused_actions: Array) -> void:
	var back = host.ui_factory.utility_button("‹  返回当前地点", host.action_panel_controller._clear_action_focus)
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	screen.actor_focus_detail_box.add_child(back)
	var actor = screen._actor_by_id(host.current_view.get("known_actors", []), host.focused_actor_id)
	var state_names = {"neutral": "平静", "alert": "正在留意你", "troubled": "正在权衡消息", "decisive": "已经形成决断"}
	var expression = str(host.actor_expression_by_id.get(host.focused_actor_id, "alert"))
	screen.objective_label.text = "%s · %s" % [actor.get("public_role", "可交谈人物"), state_names.get(expression, expression)]
	host.dialogue_panel_controller._render_actor_dialogue_line(actor)
	screen.actor_focus_detail_scroll.visible = true
	if host.ai_server_enabled:
		host.action_panel_controller._render_ai_conversation_context(focused_actions)
		return
	var has_terms = false
	var has_route_response = false
	for action in focused_actions:
		if str(action.get("term_label", "")) != "":
			has_terms = true
		if str(action.get("kind", "")) == "route":
			has_route_response = true
	if focused_actions.is_empty():
		host.focused_actor_action_id = ""
		var empty_card := PanelContainer.new()
		var empty_style = host.ui_factory.panel_style(Color(host.COLORS.panel_alt, 0.34), 1, 3, Color(host.COLORS.line, 0.66), 16, 14)
		empty_style.border_width_left = 2
		empty_style.border_color = Color(host.COLORS.accent, 0.62)
		empty_card.add_theme_stylebox_override("panel", empty_style)
		screen.actor_focus_detail_box.add_child(empty_card)
		var empty_content := VBoxContainer.new()
		empty_content.add_theme_constant_override("separation", 8)
		empty_card.add_child(empty_content)
		var empty_title = host.ui_factory.text(empty_content, "暂无可传达的新消息", false, host.TYPE_SCALE.headline)
		empty_title.add_theme_color_override("font_color", host.COLORS.accent)
		host.ui_factory.text(empty_content, "已送达的消息不会重复出现。你仍可直接交谈，或到随身卷宗查看完整人物档案。", true, host.TYPE_SCALE.compact)
		var journal_button = host.ui_factory.utility_button("查看人物卷宗", host.action_panel_controller._open_focused_actor_journal)
		journal_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		empty_content.add_child(journal_button)
		return
	var workspace_heading = "回应路线考验" if has_route_response else ("选择交换条件" if has_terms else "选择线索")
	var heading = host.ui_factory.text(screen.actor_focus_detail_box, workspace_heading, true, host.TYPE_SCALE.meta)
	heading.add_theme_color_override("font_color", host.COLORS.accent)
	var focused_choice = host.action_panel_controller._resolve_focused_actor_action(focused_actions)
	var choice_list := VBoxContainer.new()
	choice_list.name = "ActorFocusChoiceList"
	choice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_list.add_theme_constant_override("separation", 6)
	screen.actor_focus_detail_box.add_child(choice_list)
	for action in focused_actions:
		var action_id = str(action.get("id", ""))
		var claim: String = host.action_panel_controller._focused_action_label(action, true)
		var selected = action_id == str(focused_choice.get("id", ""))
		var button = host.ui_factory.action_button(claim, host.action_panel_controller._select_focused_actor_action.bind(action_id))
		button.custom_minimum_size.y = 46
		if selected:
			button.name = "SelectedActorFocusChoice"
			var selected_style = host.ui_factory.panel_style(Color(host.COLORS.panel_hover, 0.72), 0, 2, Color.TRANSPARENT, 12, 8)
			selected_style.border_width_left = 2
			selected_style.border_color = host.COLORS.accent
			button.add_theme_stylebox_override("normal", selected_style)
		choice_list.add_child(button)
	host.action_panel_controller._render_actor_focus_detail(focused_choice)


func _render_ai_conversation_context(focused_actions: Array) -> void:
	var duration := maxi(1, int(host.scenario_info.get("conversation_duration", 1)))
	var heading = host.ui_factory.text(screen.actor_focus_detail_box, "本次交谈", true, host.TYPE_SCALE.meta)
	heading.add_theme_color_override("font_color", host.COLORS.accent)
	host.ui_factory.text(screen.actor_focus_detail_box, "每次发送成功后推进 %d 日；若话中明确告知线索，会在同一次交谈中直接送达。" % duration, true, host.TYPE_SCALE.compact)
	var claims: Array[String] = []
	for action in focused_actions:
		if str(action.get("kind", "")) != "tell":
			continue
		var claim := str(action.get("fact_claim", "")).strip_edges()
		if claim != "" and claim not in claims:
			claims.append(claim)
	if claims.is_empty():
		host.ui_factory.text(screen.actor_focus_detail_box, "当前没有尚未送达的线索，仍可进行普通交谈。", true, host.TYPE_SCALE.compact)
		return
	var clue_heading = host.ui_factory.text(screen.actor_focus_detail_box, "可在话中提及", true, host.TYPE_SCALE.meta)
	clue_heading.add_theme_color_override("font_color", host.COLORS.muted)
	var clue_tags := HFlowContainer.new()
	clue_tags.add_theme_constant_override("h_separation", 6)
	clue_tags.add_theme_constant_override("v_separation", 6)
	screen.actor_focus_detail_box.add_child(clue_tags)
	for claim in claims:
		host.action_panel_controller._action_tag(clue_tags, claim, host.COLORS.accent)


func _open_focused_actor_journal() -> void:
	host.journal_panel_controller._select_journal_tab(2)
	host.journal_panel_controller._open_journal()


func _resolve_focused_actor_action(actions: Array) -> Dictionary:
	for action in actions:
		if str(action.get("id", "")) == host.focused_actor_action_id:
			return action
	for action in actions:
		if str(action.get("kind", "")) == "route":
			host.focused_actor_action_id = ""
			return {}
	var first: Dictionary = actions[0]
	host.focused_actor_action_id = str(first.get("id", ""))
	return first


func _select_focused_actor_action(action_id: String) -> void:
	host.focused_actor_action_id = action_id
	host.action_panel_controller._render_actions(host.available_actions_cache)
	screen.actor_focus_detail_scroll.set_deferred("scroll_vertical", 0)


func _render_actor_focus_detail(action: Dictionary) -> void:
	if action.is_empty():
		var prompt = host.ui_factory.text(screen.actor_focus_detail_box, "先选择一种回应", false, host.TYPE_SCALE.headline)
		prompt.add_theme_color_override("font_color", host.COLORS.accent)
		host.ui_factory.text(screen.actor_focus_detail_box, "这些选择会改变路线与人物关系。系统不会替你预选不可撤回的决定。", true, host.TYPE_SCALE.compact)
		return
	var claim: String = host.action_panel_controller._focused_action_label(action)
	var title = host.ui_factory.text(screen.actor_focus_detail_box, claim, false, host.TYPE_SCALE.section)
	title.add_theme_color_override("font_color", host.COLORS.accent)
	var term_label = str(action.get("term_label", ""))
	if term_label != "":
		var term_prefix = "你的回应" if action.get("kind", "") == "route" else "你提出的条件"
		host.action_panel_controller._render_action_tag_row(screen.actor_focus_detail_box, [term_prefix, term_label], host.COLORS.accent)
		host.ui_factory.text(screen.actor_focus_detail_box, str(action.get("personal_outcome", action.get("description", ""))), false, host.TYPE_SCALE.compact)
	var relevance = str(action.get("relevance", "尚不了解这条消息会在对方心里留下什么"))
	host.action_panel_controller._action_header_row(screen.actor_focus_detail_box, "相关性", host.COLORS.accent, host.action_panel_controller._action_detail_tags(relevance), "RelevanceHeader")
	var outcomes = host.action_panel_controller._joined_action_values(action.get("expected_outcomes", []))
	var outcome_card = host.action_panel_controller._action_info_card(screen.actor_focus_detail_box, "可能结果", host.COLORS.success)
	var outcome_line = host.ui_factory.text(outcome_card, outcomes if outcomes != "" else str(action.get("description", "影响仍待局势验证")), false, host.TYPE_SCALE.compact)
	outcome_line.add_theme_color_override("font_color", host.COLORS.success)
	var risk = str(action.get("risk", "尚未发现明确风险"))
	var risk_card = host.action_panel_controller._action_info_card(screen.actor_focus_detail_box, "", host.COLORS.danger)
	var risk_header := HBoxContainer.new()
	risk_header.name = "RiskHeader"
	risk_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	risk_header.add_theme_constant_override("separation", 8)
	risk_card.add_child(risk_header)
	var risk_heading = host.ui_factory.text(risk_header, "传播风险", true, host.TYPE_SCALE.meta)
	risk_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	risk_heading.add_theme_color_override("font_color", Color(host.COLORS.danger, 0.92))
	if risk.contains("未经核实") or risk.contains("未经核验"):
		host.action_panel_controller._action_tag(risk_header, "未经核验", host.COLORS.danger)
	host.ui_factory.text(risk_card, risk, false, host.TYPE_SCALE.compact)
	var timing = str(action.get("timing", ""))
	if timing != "":
		host.action_panel_controller._action_header_row(screen.actor_focus_detail_box, "传播时机", host.COLORS.muted, host.action_panel_controller._action_timing_tags(timing), "TimingHeader")

	var primary_label = "确认告知" if str(action.get("kind", "")) == "tell" else "确认行动"
	var primary = host.ui_factory.button(primary_label, host.action_panel_controller._consider_action.bind(action), false)
	primary.custom_minimum_size = Vector2(210, 46)
	screen.actor_focus_footer.add_child(primary)
	host.action_panel_controller._action_tag(screen.actor_focus_footer, "耗时 %d 日" % int(action.get("duration", 1)), host.COLORS.accent)
	var warning = host.ui_factory.text(screen.actor_focus_footer, "送出后不可撤回", false, 14)
	warning.autowrap_mode = TextServer.AUTOWRAP_OFF
	warning.custom_minimum_size.x = 150
	warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning.add_theme_color_override("font_color", host.COLORS.danger)


func _focused_action_label(action: Dictionary, for_choice := false) -> String:
	var kind := str(action.get("kind", ""))
	var term_label := str(action.get("term_label", ""))
	if kind == "route" and for_choice and term_label != "":
		return term_label
	if kind in ["recover", "escort", "route"]:
		return str(action.get("name", "回应眼前局势"))
	if term_label != "":
		return term_label
	return str(action.get("fact_claim", action.get("name", "一条消息")))


func _action_info_card(parent: Container, label_text: String, tone: Color) -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = host.ui_factory.panel_style(Color(host.COLORS.panel_alt, 0.24), 0, 2, Color.TRANSPARENT, 12, 9)
	style.border_width_left = 2
	style.border_color = Color(tone, 0.70)
	frame.add_theme_stylebox_override("panel", style)
	parent.add_child(frame)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	frame.add_child(content)
	if label_text != "":
		var heading = host.ui_factory.text(content, label_text, true, host.TYPE_SCALE.meta)
		heading.add_theme_color_override("font_color", Color(tone, 0.92))
	return content


func _action_header_row(parent: Container, label_text: String, tone: Color, values: Array, node_name := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	if node_name != "":
		row.name = node_name
	var label = host.ui_factory.text(row, label_text, true, host.TYPE_SCALE.meta)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color(tone, 0.92))
	for value in values:
		var text_value := str(value).strip_edges()
		if text_value != "":
			host.action_panel_controller._action_tag(row, text_value, tone)
	return row


func _action_tag(parent: Container, value: String, tone: Color) -> PanelContainer:
	var tag := PanelContainer.new()
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tag.add_theme_stylebox_override("panel", host.ui_factory.panel_style(Color(host.COLORS.panel_alt, 0.46), 0, 2, Color.TRANSPARENT, 9, 5))
	parent.add_child(tag)
	var label = host.ui_factory.text(tag, value, true, host.TYPE_SCALE.meta)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_color", Color(tone, 0.96))
	return tag


func _render_action_tag_row(parent: Container, values: Array, tone: Color) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	parent.add_child(row)
	for value in values:
		var text_value := str(value).strip_edges()
		if text_value != "":
			host.action_panel_controller._action_tag(row, text_value, tone)
	return row


func _action_detail_tags(value: String) -> Array[String]:
	var result: Array[String] = []
	var normalized := value.replace("：", " · ").replace(":", " · ")
	for raw_part in normalized.split(" · "):
		var part := str(raw_part).strip_edges()
		if part.begins_with("对方"):
			part = part.trim_prefix("对方").strip_edges()
		if part != "" and part not in result:
			result.append(part)
	return result if not result.is_empty() else [value]


func _action_timing_tags(value: String) -> Array[String]:
	var result: Array[String] = []
	for raw_part in value.split(" · "):
		var part := str(raw_part).strip_edges()
		if part == "" or part == "时机":
			continue
		if part.begins_with("行动后预留 ") and part.ends_with(" 日抵达"):
			part = "预计 %s 日后抵达" % part.trim_prefix("行动后预留 ").trim_suffix(" 日抵达")
		result.append(part)
	return result if not result.is_empty() else [value]


func _location_context_actions(actions: Array) -> Array:
	var result: Array = []
	for action in actions:
		var category = str(action.get("category", "other"))
		if str(action.get("kind", "")) == "tell" or category == "move":
			continue
		result.append(action)
	return result


func _add_contextual_choice(action: Dictionary) -> void:
	var label = str(action.get("name", "做一件事"))
	if int(action.get("completion_day", 0)) > 0:
		label += "　·　%d 日 · 第 %d 日完成" % [int(action.get("duration", 1)), int(action.get("completion_day", 0))]
	var callback = host.action_panel_controller._consider_action.bind(action, "wait:complete") if action.get("kind", "") == "cultivate" else host.action_panel_controller._consider_action.bind(action)
	var button = host.ui_factory.action_button(label, callback)
	button.custom_minimum_size.y = 44
	button.tooltip_text = str(action.get("description", ""))
	screen.actions_box.add_child(button)
	var description = str(action.get("description", ""))
	if description != "":
		host.ui_factory.text(screen.actions_box, description, true, 13)


func _toggle_all_actions() -> void:
	host.show_all_actions = not host.show_all_actions
	host.action_panel_controller._render_actions(host.available_actions_cache)


func _render_focused_actor_summary(focused_actions: Array) -> void:
	var actor = screen._actor_by_id(host.current_view.get("known_actors", []), host.focused_actor_id)
	if actor.is_empty():
		return
	var panel = PanelContainer.new()
	var summary_style = host.ui_factory.panel_style(Color(host.COLORS.panel_alt, 0.34), 0, 2, Color.TRANSPARENT, 13, 10)
	summary_style.border_width_left = 2
	summary_style.border_color = Color(host.COLORS.accent, 0.56)
	panel.add_theme_stylebox_override("panel", summary_style)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	var role_line = host.ui_factory.text(content, str(actor.get("public_role", "可交谈人物")), true, 13)
	role_line.add_theme_color_override("font_color", host.COLORS.accent)
	host.ui_factory.text(content, str(actor.get("public_profile", "公开资料尚未收集")), false, 14)
	var state_names = {"neutral": "平静", "alert": "正在留意你", "troubled": "正在权衡消息", "decisive": "已经形成决断"}
	var expression = str(host.actor_expression_by_id.get(host.focused_actor_id, "alert"))
	var state_line = host.ui_factory.text(content, host._ui_text("dialogue_available_clues") % [state_names.get(expression, expression), focused_actions.size()], false, 13)
	state_line.add_theme_color_override("font_color", host.COLORS.success if expression == "decisive" else host.COLORS.muted)
	var disclosure: Dictionary = host.ui_factory.foldable_section(content, "判断依据", not host.focused_actor_details_visible)
	var details: VBoxContainer = disclosure.content
	var details_fold: FoldableContainer = disclosure.container
	details_fold.folding_changed.connect(host.action_panel_controller._on_focused_actor_details_folded)
	var focus: Array = actor.get("public_focus", [])
	if not focus.is_empty():
		host.action_panel_controller._action_header_row(details, "关注", host.COLORS.accent, focus, "ActorFocusHeader")
	host.action_panel_controller._action_header_row(details, "传播风险", host.COLORS.danger, [actor.get("public_risk", "尚不了解")], "ActorRiskHeader")
	screen.actions_box.add_child(panel)


func _on_focused_actor_details_folded(is_folded: bool) -> void:
	host.focused_actor_details_visible = not is_folded


func _set_action_category(category: String) -> void:
	host.active_action_category = category
	host.action_panel_controller._render_actions(host.available_actions_cache)


func _count_tell_actions(actions: Array, actor_id: String, fact_id: String) -> int:
	var count = 0
	for action in actions:
		if action.get("kind", "") not in ["tell", "recover", "escort", "route"]:
			continue
		if actor_id != "" and str(action.get("target_id", "")) != actor_id:
			continue
		if fact_id != "" and str(action.get("fact_id", "")) != fact_id:
			continue
		count += 1
	return count


func _focused_information_actions(actions: Array) -> Array:
	var result: Array = []
	for action in actions:
		if action.get("kind", "") not in ["tell", "recover", "escort", "route"]:
			continue
		if host.focused_actor_id != "" and str(action.get("target_id", "")) != host.focused_actor_id:
			continue
		if host.focused_fact_id != "" and str(action.get("fact_id", "")) != host.focused_fact_id:
			continue
		result.append(action)
	return result


func _add_focused_information_actions(actions: Array) -> void:
	for index in actions.size():
		var action: Dictionary = actions[index]
		if host.focused_actor_id != "":
			if action.get("kind", "") in ["recover", "escort", "route"]:
				host.ui_factory.text(screen.actions_box, str(action.get("name", "行动")), false, 16)
				host.ui_factory.text(screen.actions_box, str(action.get("description", "执行当前行动")), true, 13)
			else:
				host.ui_factory.text(screen.actions_box, str(action.get("fact_claim", host._ui_text("unknown_clue"))), false, 16)
		else:
			host.ui_factory.text(screen.actions_box, "%s · %s" % [action.get("target_name", "某人"), action.get("target_role", "可交谈人物")], false, 16)
		var relevance = host.ui_factory.text(screen.actions_box, str(action.get("relevance", "尚不了解这条消息会在对方心里留下什么")), false, 13)
		relevance.add_theme_color_override("font_color", host.COLORS.accent)
		var button_label = ""
		if action.get("kind", "") == "recover":
			button_label = str(action.get("name", "确认行动"))
			var warning_line = host.ui_factory.text(screen.actions_box, "代价 · 消息送出后不可撤回", false, 13)
			warning_line.add_theme_color_override("font_color", host.COLORS.danger)
		elif action.get("kind", "") == "escort":
			button_label = "按约随队出发"
		elif action.get("kind", "") == "route":
			button_label = str(action.get("name", "做出路线决定"))
		else:
			var term_label = str(action.get("term_label", ""))
			button_label = (host._ui_text("deliver_term") % term_label) if term_label != "" else (host._ui_text("tell_focused_actor") if host.focused_actor_id != "" else host._ui_text("tell_actor") % action.get("target_name", "对方"))
		if int(action.get("completion_day", 0)) > 0:
			button_label += " · %d 日" % int(action.get("duration", 1))
		var tell_button = host.ui_factory.action_button(button_label, host.action_panel_controller._consider_action.bind(action))
		tell_button.tooltip_text = "%s\n%s" % [action.get("timing", ""), action.get("risk", "")]
		screen.actions_box.add_child(tell_button)
		if index < actions.size() - 1:
			var separator = HSeparator.new()
			separator.modulate = host.COLORS.line
			screen.actions_box.add_child(separator)


func _focus_actor_actions(actor_id: String, actor_name: String) -> void:
	host.focused_actor_id = actor_id
	host.focused_actor_name = actor_name
	host.focused_actor_action_id = ""
	host.focused_fact_id = ""
	host.focused_fact_claim = ""
	host.focused_actor_details_visible = false
	host.stage_actor_id = actor_id
	host.stage_actor_name = actor_name
	screen._focus_portrait(actor_id)
	host.actor_dialogue_error_by_id.erase(actor_id)
	host.actor_dialogue_loading_id = ""
	screen._render_stage_people(host.current_view.get("known_actors", []), host.available_actions_cache)
	host.action_panel_controller._render_actions(host.available_actions_cache)


func _action_has_visible_entry(action: Dictionary) -> bool:
	var kind = str(action.get("kind", ""))
	if kind == "move":
		return str(action.get("target_id", "")) != ""
	if kind in ["tell", "recover", "escort", "route"]:
		return str(action.get("target_id", "")) != ""
	return kind != ""


func _focus_actor_from_reference(actor_id: String, actor_name: String) -> void:
	screen._set_visual_mode("location")
	host.audio_director.play_ui()
	host.action_panel_controller._focus_actor_actions(actor_id, actor_name)


func _focus_fact_actions(fact_id: String, fact_claim: String) -> void:
	host.focused_fact_id = fact_id
	host.focused_fact_claim = fact_claim
	host.focused_actor_id = ""
	host.focused_actor_name = ""
	host.action_panel_controller._render_actions(host.available_actions_cache)


func _clear_action_focus() -> void:
	host.action_panel_controller._reset_action_focus()
	host.action_panel_controller._render_actions(host.available_actions_cache)


func _reset_action_focus() -> void:
	if host.dialogue_client != null:
		host.dialogue_client.cancel()
	host.actor_dialogue_loading_id = ""
	host.focused_actor_id = ""
	host.focused_actor_name = ""
	host.focused_actor_action_id = ""
	host.focused_fact_id = ""
	host.focused_fact_claim = ""
	host.focused_actor_details_visible = false
	host.show_all_actions = false


func _reconcile_action_focus(actors: Array, clues: Array) -> void:
	if host.focused_actor_id != "":
		var actor_still_here = false
		for actor in actors:
			if str(actor.get("id", "")) == host.focused_actor_id:
				actor_still_here = true
				break
		if not actor_still_here:
			host.focused_actor_id = ""
			host.focused_actor_name = ""
			host.focused_actor_action_id = ""
	if host.focused_fact_id != "":
		var fact_still_known = false
		for clue in clues:
			if str(clue.get("fact_id", "")) == host.focused_fact_id:
				fact_still_known = true
				break
		if not fact_still_known:
			host.focused_fact_id = ""
			host.focused_fact_claim = ""


func _add_information_actions(actions: Array) -> void:
	var tell_groups = {}
	for action in actions:
		if action.get("kind", "") != "tell":
			host.action_panel_controller._add_action_button(action)
			continue
		var target = str(action.get("target_name", "某人"))
		if not tell_groups.has(target):
			tell_groups[target] = []
		tell_groups[target].append(action)
	for target in tell_groups:
		var facts: Array = tell_groups[target]
		if facts.size() == 1:
			var action: Dictionary = facts[0]
			var button = host.ui_factory.action_button(host._ui_text("action_send_clue") % target, host.action_panel_controller._consider_action.bind(action))
			button.tooltip_text = "%s\n%s\n%s" % [action.get("description", ""), action.get("relevance", ""), action.get("risk", "")]
			screen.actions_box.add_child(button)
			host.ui_factory.text(screen.actions_box, "“%s”" % action.get("fact_claim", host._ui_text("unknown_clue")), true, 14)
			host.action_panel_controller._add_action_decision_context(screen.actions_box, action, true)
		else:
			var menu = MenuButton.new()
			menu.text = host._ui_text("action_send_clues_menu") % [target, facts.size()]
			menu.custom_minimum_size.y = 42
			host.ui_factory.style_menu_button(menu)
			menu.get_popup().id_pressed.connect(host.action_panel_controller._on_tell_fact_selected.bind(facts))
			for index in facts.size():
				menu.get_popup().add_item(str(facts[index].get("fact_claim", host._ui_text("one_clue"))), index)
			screen.actions_box.add_child(menu)


func _add_action_button(action: Dictionary) -> void:
	var duration = int(action.get("duration", 1))
	var label = str(action.get("name", "行动"))
	if action.get("id", "") == "wait:next":
		label += "　· 直至新变化"
	elif int(action.get("completion_day", 0)) > 0:
		label += "　· 第 %d 日完成" % int(action.get("completion_day", 0))
	else:
		label += "　· %d 日" % duration
	var list_costs: Dictionary = action.get("costs", {})
	for key in list_costs:
		if int(list_costs[key]) > 0:
			label += "　· %s %d" % [screen._resource_label(str(key)), int(list_costs[key])]
	var button = host.ui_factory.action_button(label, host.action_panel_controller._consider_action.bind(action))
	button.tooltip_text = str(action.get("description", ""))
	screen.actions_box.add_child(button)
	host.action_panel_controller._add_action_decision_context(screen.actions_box, action, true)


func _add_action_decision_context(parent: VBoxContainer, action: Dictionary, compact: bool = false) -> void:
	if not compact and int(action.get("completion_day", 0)) > 0:
		host.ui_factory.text(parent, "完成 · 第 %d 日结束时" % int(action.get("completion_day", 0)), false, 15)
	var outcomes = host.action_panel_controller._joined_action_values(action.get("expected_outcomes", []))
	if outcomes != "":
		var outcome_line = host.ui_factory.text(parent, "预期 · %s" % outcomes, false, 14)
		outcome_line.add_theme_color_override("font_color", host.COLORS.success)
	var resolves = host.action_panel_controller._joined_action_values(action.get("resolves", []))
	if resolves != "" and not compact:
		host.ui_factory.text(parent, "解决 · %s" % resolves, true, 14)
	var known_conditions = host.action_panel_controller._joined_action_values(action.get("known_conditions", []))
	if known_conditions != "" and not compact:
		var known_line = host.ui_factory.text(parent, "已满足 · %s" % known_conditions, true, 14)
		known_line.add_theme_color_override("font_color", host.COLORS.success)
	var unknowns = host.action_panel_controller._joined_action_values(action.get("unknowns", []))
	if unknowns != "" and not compact:
		var unknown_line = host.ui_factory.text(parent, "仍未知 · %s" % unknowns, true, 14)
		unknown_line.add_theme_color_override("font_color", host.COLORS.accent)
	var timing = str(action.get("timing", ""))
	if timing != "":
		var timing_line = host.ui_factory.text(parent, "时间 · %s" % timing, true, 14)
		if timing.contains("挤压") or timing.contains("来不及") or timing.contains("无法预先保证"):
			timing_line.add_theme_color_override("font_color", host.COLORS.danger)
		else:
			timing_line.add_theme_color_override("font_color", host.COLORS.accent)


func _joined_action_values(values: Variant) -> String:
	if not values is Array:
		return ""
	var parts: Array[String] = []
	for value in values:
		parts.append(str(value))
	return "、".join(parts)


func _on_tell_fact_selected(index: int, facts: Array) -> void:
	if index >= 0 and index < facts.size():
		host.action_panel_controller._consider_action(facts[index])


func _confirmation_card(parent: Container, label_text: String, tone: Color, minimum_height := 0.0) -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.custom_minimum_size.y = minimum_height
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame_style = host.ui_factory.panel_style(Color(host.COLORS.panel_alt, 0.24), 0, 2, Color.TRANSPARENT, 13, 10)
	frame_style.border_width_left = 2
	frame_style.border_color = Color(tone, 0.68)
	frame.add_theme_stylebox_override("panel", frame_style)
	parent.add_child(frame)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	frame.add_child(content)
	if label_text != "":
		var label = host.ui_factory.text(content, label_text, true, host.TYPE_SCALE.meta)
		label.add_theme_color_override("font_color", Color(tone, 0.92))
	return content


func _consider_action(action: Dictionary, followup_action_id := "") -> void:
	var kind = str(action.get("kind", ""))
	var warnings = action.get("warnings", [])
	if not host.action_panel_controller._action_needs_confirmation(action):
		host._execute_action(str(action.get("id", "")), followup_action_id)
		return
	host.selected_action = action
	host.selected_followup_action_id = followup_action_id
	host.ui_factory.clear(host.confirmation_box)
	host.ui_factory.clear(host.confirmation_actions_box)
	var decision_card: VBoxContainer = host.action_panel_controller._confirmation_card(host.confirmation_box, "", host.COLORS.accent, 78.0)
	var decision_title_text := "告知%s" % str(action.get("target_name", "对方")) if kind == "tell" else str(action.get("name", "行动"))
	var decision_title = host.ui_factory.text(decision_card, decision_title_text, false, host.TYPE_SCALE.headline)
	decision_title.add_theme_font_override("font", host.display_font)
	if action.get("id", "") == "wait:next":
		var warning = host.ui_factory.text(decision_card, "你会放下手边的事，直到新的风声找上门来。", false, host.TYPE_SCALE.compact)
		warning.add_theme_color_override("font_color", host.COLORS.accent)
	elif kind == "tell":
		host.ui_factory.text(decision_card, "线索 · %s" % str(action.get("fact_claim", action.get("description", "一条消息"))), true, host.TYPE_SCALE.compact)
	else:
		host.ui_factory.text(decision_card, str(action.get("description", "")), true, host.TYPE_SCALE.compact)
	var summary_row := HBoxContainer.new()
	summary_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_row.add_theme_constant_override("separation", 10)
	host.confirmation_box.add_child(summary_row)
	var summary_primary := VBoxContainer.new()
	summary_primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_primary.size_flags_stretch_ratio = 1.08
	summary_primary.add_theme_constant_override("separation", 10)
	summary_row.add_child(summary_primary)
	var summary_secondary := VBoxContainer.new()
	summary_secondary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_secondary.size_flags_stretch_ratio = 0.92
	summary_secondary.add_theme_constant_override("separation", 10)
	summary_row.add_child(summary_secondary)
	var outcomes = host.action_panel_controller._joined_action_values(action.get("expected_outcomes", []))
	if outcomes != "":
		var outcome_card: VBoxContainer = host.action_panel_controller._confirmation_card(summary_primary, "可能结果", host.COLORS.success)
		var outcome_line = host.ui_factory.text(outcome_card, outcomes, false, host.TYPE_SCALE.compact)
		outcome_line.add_theme_color_override("font_color", host.COLORS.success)
	var timing = str(action.get("timing", ""))
	var has_warnings: bool = warnings is Array and not warnings.is_empty()
	var costs: Dictionary = action.get("costs", {})
	var context_card: VBoxContainer
	if timing != "" or not costs.is_empty():
		var context_label := "时机与消耗" if timing != "" and not costs.is_empty() else ("时机" if timing != "" else "消耗")
		context_card = host.action_panel_controller._confirmation_card(summary_secondary if outcomes != "" else summary_primary, "", host.COLORS.accent)
		var context_tags: Array[String] = []
		if timing != "":
			context_tags.append_array(host.action_panel_controller._action_timing_tags(timing))
		if not costs.is_empty():
			for key in costs:
				context_tags.append("%s %s" % [screen._resource_label(str(key)), costs[key]])
		host.action_panel_controller._action_header_row(context_card, context_label, host.COLORS.accent, context_tags, "ConfirmationContextHeader")
	var consequence_card: VBoxContainer
	if has_warnings or bool(action.get("irreversible", false)):
		consequence_card = host.action_panel_controller._confirmation_card(summary_secondary if outcomes != "" or timing != "" or not costs.is_empty() else summary_primary, "风险与承诺", host.COLORS.danger)
	if warnings is Array:
		for warning_text in warnings:
			var warning_line = host.ui_factory.text(consequence_card, str(warning_text), false, host.TYPE_SCALE.compact)
			warning_line.add_theme_color_override("font_color", host.COLORS.danger)
	if bool(action.get("irreversible", false)):
		var irreversible_line = host.ui_factory.text(consequence_card, "不可撤回 · 公开信息与交换结果会保留", false, host.TYPE_SCALE.compact)
		irreversible_line.add_theme_color_override("font_color", host.COLORS.danger)
	if summary_primary.get_child_count() == 0:
		summary_primary.hide()
	if summary_secondary.get_child_count() == 0:
		summary_secondary.hide()
	if summary_primary.get_child_count() == 0 and summary_secondary.get_child_count() == 0:
		summary_row.hide()
	var disclosure: Dictionary = host.ui_factory.foldable_section(host.confirmation_box, "盘算详情", true)
	host.confirmation_details_fold = disclosure.container
	host.confirmation_details_box = disclosure.content
	host.confirmation_details_box.add_theme_constant_override("separation", 10)
	host.action_panel_controller._render_confirmation_details(host.confirmation_details_box, action)
	var cancel_button = host.ui_factory.button("暂且不动", host.action_panel_controller._cancel_confirmation, true)
	cancel_button.custom_minimum_size = Vector2(150, 44)
	host.confirmation_actions_box.add_child(cancel_button)
	var button_spacer = Control.new()
	button_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.confirmation_actions_box.add_child(button_spacer)
	var confirm_button = host.ui_factory.button(host.action_panel_controller._commitment_label(action), host.action_panel_controller._confirm_selected_action, false)
	confirm_button.custom_minimum_size = Vector2(240, 44)
	host.confirmation_actions_box.add_child(confirm_button)
	if screen.action_dock:
		screen.action_dock.hide()
	host.confirmation_layer.show()
	screen._sync_action_canvas_visibility()


func _render_confirmation_details(parent: VBoxContainer, action: Dictionary) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	parent.add_child(grid)
	var execution = host.action_panel_controller._confirmation_detail_group(grid, "执行判断")
	if int(action.get("completion_day", 0)) > 0:
		host.action_panel_controller._confirmation_detail_line(execution, "完成", "第 %d 日结束时" % int(action.get("completion_day", 0)), host.COLORS.ink)
	var resolves = host.action_panel_controller._joined_action_values(action.get("resolves", []))
	if resolves != "":
		host.action_panel_controller._confirmation_detail_line(execution, "解决", resolves, host.COLORS.ink)
	var known_conditions = host.action_panel_controller._joined_action_values(action.get("known_conditions", []))
	if known_conditions != "":
		host.action_panel_controller._confirmation_detail_line(execution, "已满足", known_conditions, host.COLORS.success)
	var unknowns = host.action_panel_controller._joined_action_values(action.get("unknowns", []))
	if unknowns != "":
		host.action_panel_controller._confirmation_detail_line(execution, "仍未知", unknowns, host.COLORS.accent)
	if execution.get_child_count() == 1:
		host.ui_factory.text(execution, "当前没有更多可公开判断。", true, host.TYPE_SCALE.compact)
	var kind := str(action.get("kind", ""))
	var situation_label := "对方情况" if kind == "tell" else "条件与风险"
	var situation = host.action_panel_controller._confirmation_detail_group(grid, situation_label)
	if kind == "tell":
		var person = host.ui_factory.text(situation, "%s · %s" % [action.get("target_name", "某人"), action.get("target_role", "可交谈人物")], false, host.TYPE_SCALE.compact)
		person.add_theme_color_override("font_color", host.COLORS.ink)
		host.action_panel_controller._confirmation_detail_tag_line(situation, "相关性", host.action_panel_controller._action_detail_tags(str(action.get("relevance", "关联尚不明确"))), host.COLORS.accent)
		host.action_panel_controller._confirmation_detail_line(situation, "倾向", str(action.get("risk", "尚不了解")), host.COLORS.muted)
	else:
		var timing := str(action.get("timing", ""))
		if timing != "":
			host.action_panel_controller._confirmation_detail_line(situation, "时机", timing, host.COLORS.accent)
		var warnings = action.get("warnings", [])
		if warnings is Array:
			for warning_text in warnings:
				host.action_panel_controller._confirmation_detail_line(situation, "风险", str(warning_text), host.COLORS.danger)
	if situation.get_child_count() == 1:
		host.ui_factory.text(situation, "当前没有额外条件或风险。", true, host.TYPE_SCALE.compact)


func _confirmation_detail_group(parent: Container, label_text: String) -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", host.ui_factory.panel_style(Color(host.COLORS.panel_alt, 0.18), 0, 2, Color.TRANSPARENT, 13, 10))
	parent.add_child(frame)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	frame.add_child(content)
	var heading = host.ui_factory.text(content, label_text, true, host.TYPE_SCALE.meta)
	heading.add_theme_color_override("font_color", host.COLORS.accent)
	return content


func _confirmation_detail_line(parent: VBoxContainer, label_text: String, value: String, tone: Color) -> void:
	if value.strip_edges() == "":
		return
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 9)
	parent.add_child(row)
	var label = host.ui_factory.text(row, label_text, true, host.TYPE_SCALE.meta)
	label.custom_minimum_size.x = 62
	label.add_theme_color_override("font_color", host.COLORS.muted)
	var detail = host.ui_factory.text(row, value, true, host.TYPE_SCALE.compact)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_color_override("font_color", tone)


func _confirmation_detail_tag_line(parent: VBoxContainer, label_text: String, values: Array, tone: Color) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 9)
	parent.add_child(row)
	var label = host.ui_factory.text(row, label_text, true, host.TYPE_SCALE.meta)
	label.custom_minimum_size.x = 62
	label.add_theme_color_override("font_color", host.COLORS.muted)
	host.action_panel_controller._render_action_tag_row(row, values, tone)


func _action_needs_confirmation(action: Dictionary) -> bool:
	var warnings = action.get("warnings", [])
	var has_warnings: bool = warnings is Array and not warnings.is_empty()
	var kind = str(action.get("kind", ""))
	return not action.get("costs", {}).is_empty() or bool(action.get("irreversible", false)) or has_warnings or kind in ["move", "tell", "recover", "escort", "route"] or action.get("id", "") == "wait:next"


func _commitment_label(action: Dictionary) -> String:
	if action.get("id", "") == "wait:next":
		return "静候其变"
	match str(action.get("kind", "")):
		"cultivate":
			return "闭关至下一阶段"
		"tell":
			return "传出此话"
		"move":
			return "即刻启程"
		"escort":
			return "按约随队出发"
		"route":
			return str(action.get("name", "确认行动"))
		"advance":
			return "就此落子"
	return "就这么做"


func _confirm_selected_action() -> void:
	var action_id = str(host.selected_action.get("id", ""))
	var followup_action_id = host.selected_followup_action_id
	host.selected_action = {}
	host.selected_followup_action_id = ""
	host.confirmation_layer.hide()
	host._execute_action(action_id, followup_action_id)


func _cancel_confirmation() -> void:
	host.selected_action = {}
	host.selected_followup_action_id = ""
	host.confirmation_layer.hide()
	screen._sync_action_canvas_visibility()
