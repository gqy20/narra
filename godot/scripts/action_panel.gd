extends RefCounted

var host


func _init(value) -> void:
	host = value


func _build_confirmation_layer() -> void:
	host.confirmation_layer = Control.new()
	host.confirmation_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.confirmation_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	host.confirmation_layer.hide()
	host.add_child(host.confirmation_layer)
	var shade = ColorRect.new()
	shade.color = Color("0507069c")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.confirmation_layer.add_child(shade)
	var card = PanelContainer.new()
	card.anchor_left = 0.10
	card.anchor_right = 0.68
	card.anchor_top = 0.38
	card.anchor_bottom = 0.93
	var confirmation_style = host.game_screen_controller._panel_style(Color("0b100df8"), 0, 2, Color.TRANSPARENT, 34, 26)
	confirmation_style.border_width_left = 3
	confirmation_style.border_color = host.COLORS.accent
	card.add_theme_stylebox_override("panel", confirmation_style)
	host.confirmation_layer.add_child(card)
	var card_content = VBoxContainer.new()
	card_content.add_theme_constant_override("separation", 12)
	card.add_child(card_content)
	var confirmation_scroll = ScrollContainer.new()
	confirmation_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	confirmation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_content.add_child(confirmation_scroll)
	host.confirmation_box = VBoxContainer.new()
	host.confirmation_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.confirmation_box.add_theme_constant_override("separation", 12)
	confirmation_scroll.add_child(host.confirmation_box)
	var action_rule = HSeparator.new()
	action_rule.modulate = Color(host.COLORS.accent, 0.26)
	card_content.add_child(action_rule)
	host.confirmation_actions_box = HBoxContainer.new()
	host.confirmation_actions_box.add_theme_constant_override("separation", 12)
	card_content.add_child(host.confirmation_actions_box)


func _render_actions(actions: Array) -> void:
	host.game_screen_controller._clear(host.actions_box)
	host.game_screen_controller._clear(host.overview_actions_box)
	host.game_screen_controller._clear(host.actor_focus_message_list)
	host.game_screen_controller._clear(host.actor_focus_detail_box)
	host.game_screen_controller._clear(host.actor_focus_footer)
	var focused_actions = host.action_panel_controller._focused_information_actions(actions)
	var has_action_focus = host.focused_actor_id != "" or host.focused_fact_id != ""
	host.action_panel_controller._configure_action_dock_layout(has_action_focus)
	if host.location_detail_box:
		host.location_detail_box.visible = not has_action_focus
	if host.stage_people_box:
		host.stage_people_box.visible = not has_action_focus
	host.overview_actions_box.visible = not has_action_focus
	host.actor_focus_workspace.visible = host.focused_actor_id != ""
	host.actor_focus_footer.visible = host.focused_actor_id != "" and not focused_actions.is_empty()
	host.fact_action_scroll.visible = host.focused_fact_id != ""
	if host.focused_actor_id != "":
		host.action_dock_title.text = "与%s说话" % host.focused_actor_name
		host.action_panel_controller._render_actor_focus_workspace(focused_actions)
		return
	if host.focused_fact_id != "":
		host.action_dock_title.text = "把消息交给谁"
		host.objective_label.text = host.focused_fact_claim
		host.game_screen_controller._text(host.actions_box, host.focused_fact_claim, true, 14)
		var back = host.game_screen_controller._utility_button("回到眼前", host.action_panel_controller._clear_action_focus)
		back.alignment = HORIZONTAL_ALIGNMENT_LEFT
		host.actions_box.add_child(back)
		if focused_actions.is_empty():
			host.game_screen_controller._text(host.actions_box, "这里已经没有尚未听过这条消息的人。", true)
			return
		host.action_panel_controller._add_focused_information_actions(focused_actions)
		return
	host.action_dock_title.text = str(host.current_view.get("location", {}).get("name", "眼前"))
	var guidance: Array = host.current_view.get("guidance", [])
	host.objective_label.text = str(guidance[0]) if not guidance.is_empty() else "风声未定，先看清眼前的人和路。"
	if actions.is_empty():
		host.game_screen_controller._text(host.overview_actions_box, "眼下无事可做，或许该换个地方看看。", true)
		return
	var eligible = host.action_panel_controller._location_context_actions(actions)
	if eligible.is_empty():
		host.game_screen_controller._text(host.overview_actions_box, "想赶路就翻开地图；想传话就先选中一个人。", true, 14)
		return
	host.journal_panel_controller._render_route_progresses(host.overview_actions_box, host.current_view.get("route_progresses", []), true)
	host.action_panel_controller._render_first_day_route_compass(eligible, host.overview_actions_box)
	var visible_count = eligible.size() if host.show_all_actions else mini(3, eligible.size())
	for index in visible_count:
		host.action_panel_controller._add_overview_choice(eligible[index], index)
	if eligible.size() > visible_count:
		var more = host.game_screen_controller._utility_button("展开其余 %d 项安排" % (eligible.size() - visible_count), host.action_panel_controller._toggle_all_actions)
		more.alignment = HORIZONTAL_ALIGNMENT_LEFT
		host.overview_actions_box.add_child(more)
	elif host.show_all_actions and eligible.size() > 3:
		var less = host.game_screen_controller._utility_button("只看眼前要事", host.action_panel_controller._toggle_all_actions)
		less.alignment = HORIZONTAL_ALIGNMENT_LEFT
		host.overview_actions_box.add_child(less)


func _configure_action_dock_layout(has_action_focus: bool) -> void:
	if not host.action_dock or not host.action_dock_host:
		return
	host.action_dock_host.anchor_top = 0.25 if has_action_focus else 0.47
	host.action_dock_host.anchor_bottom = 0.965
	var dock_style = host.game_screen_controller._panel_style(Color("0b100df4") if has_action_focus else Color("0b100dec"), 0, 2, Color.TRANSPARENT, 24, 18)
	dock_style.border_width_left = 2
	dock_style.border_color = Color(host.COLORS.accent, 0.72 if has_action_focus else 0.62)
	host.action_dock.add_theme_stylebox_override("panel", dock_style)


func _add_overview_choice(action: Dictionary, index: int) -> void:
	var label = str(action.get("name", "做一件事"))
	var meta: Array[String] = []
	if int(action.get("completion_day", 0)) > 0:
		meta.append("%d日" % int(action.get("duration", 1)))
	else:
		meta.append("%d日" % int(action.get("duration", 1)))
	var outcomes = host.action_panel_controller._joined_action_values(action.get("expected_outcomes", []))
	if outcomes != "":
		meta.append(outcomes)
	var button_label = "%d　%s" % [index + 1, label]
	if not meta.is_empty():
		button_label += "　·　%s" % " · ".join(meta)
	var callback = host.action_panel_controller._consider_action.bind(action, "wait:complete") if action.get("kind", "") == "cultivate" else host.action_panel_controller._consider_action.bind(action)
	var button = host.game_screen_controller._action_button(button_label, callback)
	button.custom_minimum_size.y = 44
	button.tooltip_text = "%s\n%s" % [action.get("description", ""), action.get("timing", "")]
	host.overview_actions_box.add_child(button)


func _render_actor_focus_workspace(focused_actions: Array) -> void:
	var back = host.game_screen_controller._utility_button("‹  返回%s" % host.current_view.get("location", {}).get("name", "眼前"), host.action_panel_controller._clear_action_focus)
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	host.actor_focus_message_list.add_child(back)
	var actor = host.game_screen_controller._actor_by_id(host.current_view.get("known_actors", []), host.focused_actor_id)
	var state_names = {"neutral": "平静", "alert": "正在留意你", "troubled": "正在权衡消息", "decisive": "已经形成决断"}
	var expression = str(host.actor_expression_by_id.get(host.focused_actor_id, "alert"))
	host.objective_label.text = "%s · %s" % [actor.get("public_role", "可交谈人物"), state_names.get(expression, expression)]
	host.dialogue_panel_controller._render_actor_dialogue_line(actor)
	var has_terms = false
	var has_route_response = false
	for action in focused_actions:
		if str(action.get("term_label", "")) != "":
			has_terms = true
		if str(action.get("kind", "")) == "route":
			has_route_response = true
	var workspace_heading = "回应路线考验" if has_route_response else ("选择交换条件" if has_terms else "选择要传达的话")
	var heading = host.game_screen_controller._text(host.actor_focus_message_list, workspace_heading, true, host.TYPE_SCALE.meta)
	heading.add_theme_color_override("font_color", host.COLORS.accent)
	if focused_actions.is_empty():
		host.focused_actor_action_id = ""
		host.game_screen_controller._text(host.actor_focus_message_list, "此刻没有新的话可说", true, 14)
		host.game_screen_controller._text(host.actor_focus_detail_box, str(actor.get("public_profile", "公开资料尚未收集")), false, 16)
		host.game_screen_controller._text(host.actor_focus_detail_box, "已经送达的消息不会重复出现。完整人物档案可在随身卷宗中查看。", true, 14)
		return
	var focused_choice = host.action_panel_controller._resolve_focused_actor_action(focused_actions)
	var suggested_action_ids: Array = []
	var raw_suggested_action_ids = host.actor_dialogue_by_id.get(host.focused_actor_id, {}).get("suggested_action_ids", [])
	if raw_suggested_action_ids is Array:
		suggested_action_ids = raw_suggested_action_ids
	for action in focused_actions:
		var action_id = str(action.get("id", ""))
		var claim = str(action.get("term_label", ""))
		if claim == "":
			claim = str(action.get("fact_claim", action.get("name", "一条消息")))
		var selected = action_id == str(focused_choice.get("id", ""))
		var suggested = action_id in suggested_action_ids
		var prefix = "◆  " if selected else ("✦  " if suggested else "　")
		var button = host.game_screen_controller._action_button(prefix + claim, host.action_panel_controller._select_focused_actor_action.bind(action_id))
		if suggested:
			button.tooltip_text = "模型建议；仍需由你确认执行"
		button.custom_minimum_size.y = 46
		if selected:
			var selected_style = host.game_screen_controller._panel_style(Color(host.COLORS.panel_hover, 0.72), 0, 2, Color.TRANSPARENT, 12, 8)
			selected_style.border_width_left = 2
			selected_style.border_color = host.COLORS.accent
			button.add_theme_stylebox_override("normal", selected_style)
		host.actor_focus_message_list.add_child(button)
	host.action_panel_controller._render_actor_focus_detail(focused_choice)


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
	host.actor_focus_detail_scroll.set_deferred("scroll_vertical", 0)


func _render_actor_focus_detail(action: Dictionary) -> void:
	if action.is_empty():
		var prompt = host.game_screen_controller._text(host.actor_focus_detail_box, "先选择一种回应", false, 22)
		prompt.add_theme_color_override("font_color", host.COLORS.accent)
		host.game_screen_controller._text(host.actor_focus_detail_box, "这些选择会改变路线与人物关系。系统不会替你预选不可撤回的决定。", true, 15)
		return
	var claim = str(action.get("fact_claim", action.get("name", "一条消息")))
	if action.get("kind", "") == "route":
		claim = str(action.get("name", "回应眼前局势"))
	var title = host.game_screen_controller._text(host.actor_focus_detail_box, claim, false, 19)
	title.add_theme_color_override("font_color", host.COLORS.accent)
	var term_label = str(action.get("term_label", ""))
	if term_label != "":
		var term_prefix = "你的回应" if action.get("kind", "") == "route" else "你提出的条件"
		var term_heading = host.game_screen_controller._text(host.actor_focus_detail_box, "%s · %s" % [term_prefix, term_label], true, host.TYPE_SCALE.meta)
		term_heading.add_theme_color_override("font_color", host.COLORS.accent)
		host.game_screen_controller._text(host.actor_focus_detail_box, str(action.get("personal_outcome", action.get("description", ""))), false, 15)
	var relevance = str(action.get("relevance", "尚不了解这条消息会在对方心里留下什么"))
	var impact_heading = host.game_screen_controller._text(host.actor_focus_detail_box, "他为何在意", true, host.TYPE_SCALE.meta)
	impact_heading.add_theme_color_override("font_color", host.COLORS.accent)
	host.game_screen_controller._text(host.actor_focus_detail_box, relevance, false, 15)
	var outcomes = host.action_panel_controller._joined_action_values(action.get("expected_outcomes", []))
	var outcome_heading = host.game_screen_controller._text(host.actor_focus_detail_box, "可能影响", true, host.TYPE_SCALE.meta)
	outcome_heading.add_theme_color_override("font_color", host.COLORS.accent)
	host.game_screen_controller._text(host.actor_focus_detail_box, outcomes if outcomes != "" else str(action.get("description", "影响仍待局势验证")), false, 15)
	var risk_heading = host.game_screen_controller._text(host.actor_focus_detail_box, "传播风险", true, host.TYPE_SCALE.meta)
	risk_heading.add_theme_color_override("font_color", host.COLORS.accent)
	host.game_screen_controller._text(host.actor_focus_detail_box, str(action.get("risk", "尚未发现明确风险")), false, 15)
	var timing = str(action.get("timing", ""))
	if timing != "":
		host.game_screen_controller._text(host.actor_focus_detail_box, "时机 · %s" % timing, true, 14)

	var primary_label = "%s · 确认" % action.get("name", "确认行动")
	var primary = host.game_screen_controller._ornate_button(primary_label, host.action_panel_controller._consider_action.bind(action))
	primary.custom_minimum_size = Vector2(300, 54)
	host.actor_focus_footer.add_child(primary)
	var duration = host.game_screen_controller._text(host.actor_focus_footer, "耗时 · %d 日" % int(action.get("duration", 1)), false, 15)
	duration.autowrap_mode = TextServer.AUTOWRAP_OFF
	duration.custom_minimum_size.x = 110
	duration.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var warning = host.game_screen_controller._text(host.actor_focus_footer, "送出后不可撤回", false, 14)
	warning.autowrap_mode = TextServer.AUTOWRAP_OFF
	warning.custom_minimum_size.x = 150
	warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning.add_theme_color_override("font_color", host.COLORS.danger)


func _location_context_actions(actions: Array) -> Array:
	var result: Array = []
	for action in actions:
		var category = str(action.get("category", "other"))
		if str(action.get("kind", "")) == "tell" or category == "move":
			continue
		result.append(action)
	return result


func _render_first_day_route_compass(actions: Array, parent: VBoxContainer = null) -> void:
	if int(host.current_view.get("day", 0)) > 1:
		return
	if parent == null:
		parent = host.actions_box
	if actions.size() < 2:
		return
	var panel = PanelContainer.new()
	var style = host.game_screen_controller._panel_style(Color(host.COLORS.panel_alt, 0.26), 0, 2, Color.TRANSPARENT, 10, 4)
	style.border_width_left = 2
	style.border_color = Color(host.COLORS.accent, 0.64)
	panel.add_theme_stylebox_override("panel", style)
	var content = HBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	var opening_names: Array[String] = []
	for index in range(mini(3, actions.size())):
		opening_names.append(str(actions[index].get("name", "行动")))
	var heading = host.game_screen_controller._text(content, "起手可选 · %s" % " / ".join(opening_names), false, 12)
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_color_override("font_color", host.COLORS.accent)
	parent.add_child(panel)


func _add_contextual_choice(action: Dictionary) -> void:
	var label = str(action.get("name", "做一件事"))
	if int(action.get("completion_day", 0)) > 0:
		label += "　·　%d 日 · 第 %d 日完成" % [int(action.get("duration", 1)), int(action.get("completion_day", 0))]
	var callback = host.action_panel_controller._consider_action.bind(action, "wait:complete") if action.get("kind", "") == "cultivate" else host.action_panel_controller._consider_action.bind(action)
	var button = host.game_screen_controller._action_button(label, callback)
	button.custom_minimum_size.y = 44
	button.tooltip_text = str(action.get("description", ""))
	host.actions_box.add_child(button)
	var description = str(action.get("description", ""))
	if description != "":
		host.game_screen_controller._text(host.actions_box, description, true, 13)


func _toggle_all_actions() -> void:
	host.show_all_actions = not host.show_all_actions
	host.action_panel_controller._render_actions(host.available_actions_cache)


func _render_focused_actor_summary(focused_actions: Array) -> void:
	var actor = host.game_screen_controller._actor_by_id(host.current_view.get("known_actors", []), host.focused_actor_id)
	if actor.is_empty():
		return
	var panel = PanelContainer.new()
	var summary_style = host.game_screen_controller._panel_style(Color(host.COLORS.panel_alt, 0.34), 0, 2, Color.TRANSPARENT, 13, 10)
	summary_style.border_width_left = 2
	summary_style.border_color = Color(host.COLORS.accent, 0.56)
	panel.add_theme_stylebox_override("panel", summary_style)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	var role_line = host.game_screen_controller._text(content, str(actor.get("public_role", "可交谈人物")), true, 13)
	role_line.add_theme_color_override("font_color", host.COLORS.accent)
	host.game_screen_controller._text(content, str(actor.get("public_profile", "公开资料尚未收集")), false, 14)
	var state_names = {"neutral": "平静", "alert": "正在留意你", "troubled": "正在权衡消息", "decisive": "已经形成决断"}
	var expression = str(host.actor_expression_by_id.get(host.focused_actor_id, "alert"))
	var state_line = host.game_screen_controller._text(content, host._ui_text("dialogue_available_clues") % [state_names.get(expression, expression), focused_actions.size()], false, 13)
	state_line.add_theme_color_override("font_color", host.COLORS.success if expression == "decisive" else host.COLORS.muted)
	var details = VBoxContainer.new()
	details.add_theme_constant_override("separation", 5)
	content.add_child(details)
	var focus: Array = actor.get("public_focus", [])
	if not focus.is_empty():
		host.game_screen_controller._text(details, "关注 · %s" % "、".join(focus), true, 13)
	host.game_screen_controller._text(details, "传播风险 · %s" % actor.get("public_risk", "尚不了解"), true, 13)
	details.visible = host.focused_actor_details_visible
	content.add_child(host.game_screen_controller._utility_button("收起判断依据" if host.focused_actor_details_visible else "查看判断依据", host.action_panel_controller._toggle_focused_actor_details))
	host.actions_box.add_child(panel)


func _toggle_focused_actor_details() -> void:
	host.focused_actor_details_visible = not host.focused_actor_details_visible
	host.action_panel_controller._render_actions(host.available_actions_cache)


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
				host.game_screen_controller._text(host.actions_box, str(action.get("name", "行动")), false, 16)
				host.game_screen_controller._text(host.actions_box, str(action.get("description", "执行当前行动")), true, 13)
			else:
				host.game_screen_controller._text(host.actions_box, str(action.get("fact_claim", host._ui_text("unknown_clue"))), false, 16)
		else:
			host.game_screen_controller._text(host.actions_box, "%s · %s" % [action.get("target_name", "某人"), action.get("target_role", "可交谈人物")], false, 16)
		var relevance = host.game_screen_controller._text(host.actions_box, str(action.get("relevance", "尚不了解这条消息会在对方心里留下什么")), false, 13)
		relevance.add_theme_color_override("font_color", host.COLORS.accent)
		var button_label = ""
		if action.get("kind", "") == "recover":
			button_label = str(action.get("name", "确认行动"))
			var warning_line = host.game_screen_controller._text(host.actions_box, "代价 · 消息送出后不可撤回", false, 13)
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
		var tell_button = host.game_screen_controller._action_button(button_label, host.action_panel_controller._consider_action.bind(action))
		tell_button.tooltip_text = "%s\n%s" % [action.get("timing", ""), action.get("risk", "")]
		host.actions_box.add_child(tell_button)
		if index < actions.size() - 1:
			var separator = HSeparator.new()
			separator.modulate = host.COLORS.line
			host.actions_box.add_child(separator)


func _focus_actor_actions(actor_id: String, actor_name: String) -> void:
	host.focused_actor_id = actor_id
	host.focused_actor_name = actor_name
	host.focused_actor_action_id = ""
	host.focused_fact_id = ""
	host.focused_fact_claim = ""
	host.focused_actor_details_visible = false
	host.stage_actor_id = actor_id
	host.stage_actor_name = actor_name
	host.game_screen_controller._focus_portrait(actor_id)
	host.actor_dialogue_by_id.erase(actor_id)
	host.actor_dialogue_error_by_id.erase(actor_id)
	host.actor_dialogue_history_by_id[actor_id] = []
	host.actor_dialogue_loading_id = actor_id
	host.dialogue_client.request_focus(actor_id)
	host.game_screen_controller._render_stage_people(host.current_view.get("known_actors", []), host.available_actions_cache)
	host.action_panel_controller._render_actions(host.available_actions_cache)


func _action_has_visible_entry(action: Dictionary) -> bool:
	var kind = str(action.get("kind", ""))
	if kind == "move":
		return str(action.get("target_id", "")) != ""
	if kind in ["tell", "recover", "escort", "route"]:
		return str(action.get("target_id", "")) != ""
	return kind != ""


func _focus_actor_from_reference(actor_id: String, actor_name: String) -> void:
	host.game_screen_controller._set_visual_mode("location")
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
			var button = host.game_screen_controller._action_button(host._ui_text("action_send_clue") % target, host.action_panel_controller._consider_action.bind(action))
			button.tooltip_text = "%s\n%s\n%s" % [action.get("description", ""), action.get("relevance", ""), action.get("risk", "")]
			host.actions_box.add_child(button)
			host.game_screen_controller._text(host.actions_box, "“%s”" % action.get("fact_claim", host._ui_text("unknown_clue")), true, 14)
			host.action_panel_controller._add_action_decision_context(host.actions_box, action, true)
		else:
			var menu = MenuButton.new()
			menu.text = host._ui_text("action_send_clues_menu") % [target, facts.size()]
			menu.custom_minimum_size.y = 42
			host.game_screen_controller._style_menu_button(menu)
			menu.get_popup().id_pressed.connect(host.action_panel_controller._on_tell_fact_selected.bind(facts))
			for index in facts.size():
				menu.get_popup().add_item(str(facts[index].get("fact_claim", host._ui_text("one_clue"))), index)
			host.actions_box.add_child(menu)


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
			label += "　· %s %d" % [host.game_screen_controller._resource_label(str(key)), int(list_costs[key])]
	var button = host.game_screen_controller._action_button(label, host.action_panel_controller._consider_action.bind(action))
	button.tooltip_text = str(action.get("description", ""))
	host.actions_box.add_child(button)
	host.action_panel_controller._add_action_decision_context(host.actions_box, action, true)


func _add_action_decision_context(parent: VBoxContainer, action: Dictionary, compact: bool = false) -> void:
	if not compact and int(action.get("completion_day", 0)) > 0:
		host.game_screen_controller._text(parent, "完成 · 第 %d 日结束时" % int(action.get("completion_day", 0)), false, 15)
	var outcomes = host.action_panel_controller._joined_action_values(action.get("expected_outcomes", []))
	if outcomes != "":
		var outcome_line = host.game_screen_controller._text(parent, "预期 · %s" % outcomes, false, 14)
		outcome_line.add_theme_color_override("font_color", host.COLORS.success)
	var resolves = host.action_panel_controller._joined_action_values(action.get("resolves", []))
	if resolves != "" and not compact:
		host.game_screen_controller._text(parent, "解决 · %s" % resolves, true, 14)
	var known_conditions = host.action_panel_controller._joined_action_values(action.get("known_conditions", []))
	if known_conditions != "" and not compact:
		var known_line = host.game_screen_controller._text(parent, "已满足 · %s" % known_conditions, true, 14)
		known_line.add_theme_color_override("font_color", host.COLORS.success)
	var unknowns = host.action_panel_controller._joined_action_values(action.get("unknowns", []))
	if unknowns != "" and not compact:
		var unknown_line = host.game_screen_controller._text(parent, "仍未知 · %s" % unknowns, true, 14)
		unknown_line.add_theme_color_override("font_color", host.COLORS.accent)
	var timing = str(action.get("timing", ""))
	if timing != "":
		var timing_line = host.game_screen_controller._text(parent, "时间 · %s" % timing, true, 14)
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


func _consider_action(action: Dictionary, followup_action_id := "") -> void:
	var kind = str(action.get("kind", ""))
	var warnings = action.get("warnings", [])
	if not host.action_panel_controller._action_needs_confirmation(action):
		host._execute_action(str(action.get("id", "")), followup_action_id)
		return
	host.selected_action = action
	host.selected_followup_action_id = followup_action_id
	host.game_screen_controller._clear(host.confirmation_box)
	host.game_screen_controller._clear(host.confirmation_actions_box)
	var eyebrow = host.game_screen_controller._text(host.confirmation_box, "一念将定", true, 13)
	eyebrow.add_theme_color_override("font_color", host.COLORS.accent)
	host.game_screen_controller._text(host.confirmation_box, str(action.get("name", "行动")), false, 27)
	if action.get("id", "") == "wait:next":
		var warning = host.game_screen_controller._text(host.confirmation_box, "你会放下手边的事，直到新的风声找上门来。", false, 15)
		warning.add_theme_color_override("font_color", host.COLORS.accent)
	else:
		host.game_screen_controller._text(host.confirmation_box, str(action.get("description", "")), true, 15)
	var summary_rule = HSeparator.new()
	summary_rule.modulate = Color(host.COLORS.accent, 0.24)
	host.confirmation_box.add_child(summary_rule)
	var outcomes = host.action_panel_controller._joined_action_values(action.get("expected_outcomes", []))
	if outcomes != "":
		var outcome_heading = host.game_screen_controller._text(host.confirmation_box, "可能结果", true, host.TYPE_SCALE.meta)
		outcome_heading.add_theme_color_override("font_color", host.COLORS.accent)
		var outcome_line = host.game_screen_controller._text(host.confirmation_box, outcomes, false, host.TYPE_SCALE.body)
		outcome_line.add_theme_color_override("font_color", host.COLORS.success)
	var timing = str(action.get("timing", ""))
	var has_warnings: bool = warnings is Array and not warnings.is_empty()
	var costs: Dictionary = action.get("costs", {})
	if timing != "" or has_warnings or bool(action.get("irreversible", false)) or not costs.is_empty():
		var consequence_heading = host.game_screen_controller._text(host.confirmation_box, "时机与代价", true, host.TYPE_SCALE.meta)
		consequence_heading.add_theme_color_override("font_color", host.COLORS.accent)
	if timing != "":
		var timing_line = host.game_screen_controller._text(host.confirmation_box, timing, true, 14)
		if timing.contains("挤压") or timing.contains("来不及") or timing.contains("无法预先保证"):
			timing_line.add_theme_color_override("font_color", host.COLORS.danger)
	if warnings is Array:
		for warning_text in warnings:
			var warning_line = host.game_screen_controller._text(host.confirmation_box, "风险 · %s" % warning_text, false, 14)
			warning_line.add_theme_color_override("font_color", host.COLORS.danger)
	if bool(action.get("irreversible", false)):
		var irreversible_line = host.game_screen_controller._text(host.confirmation_box, "不可撤回 · 行动产生的公开信息与交换结果会保留", false, 14)
		irreversible_line.add_theme_color_override("font_color", host.COLORS.danger)
	if not costs.is_empty():
		var cost_parts: Array[String] = []
		for key in costs:
			cost_parts.append("%s %s" % [host.game_screen_controller._resource_label(str(key)), costs[key]])
		var cost_line = host.game_screen_controller._text(host.confirmation_box, "消耗：" + "、".join(cost_parts), false, 15)
		cost_line.add_theme_color_override("font_color", host.COLORS.danger)
	host.confirmation_details_button = host.game_screen_controller._utility_button("展开盘算", host.action_panel_controller._toggle_confirmation_details)
	host.confirmation_details_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	host.confirmation_box.add_child(host.confirmation_details_button)
	host.confirmation_details_box = VBoxContainer.new()
	host.confirmation_details_box.add_theme_constant_override("separation", 6)
	host.confirmation_details_box.hide()
	host.confirmation_box.add_child(host.confirmation_details_box)
	host.action_panel_controller._add_action_decision_context(host.confirmation_details_box, action)
	if kind == "tell":
		host.game_screen_controller._text(host.confirmation_details_box, "%s · %s" % [action.get("target_name", "某人"), action.get("target_role", "可交谈人物")], false, 15)
		var relevance_line = host.game_screen_controller._text(host.confirmation_details_box, str(action.get("relevance", "关联尚不明确")), false, 14)
		relevance_line.add_theme_color_override("font_color", host.COLORS.accent)
		host.game_screen_controller._text(host.confirmation_details_box, "使用倾向 · %s" % action.get("risk", "尚不了解"), true, 14)
	var cancel_button = host.game_screen_controller._utility_button("暂且不动", host.action_panel_controller._cancel_confirmation)
	cancel_button.custom_minimum_size = Vector2(150, 46)
	host.confirmation_actions_box.add_child(cancel_button)
	var button_spacer = Control.new()
	button_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.confirmation_actions_box.add_child(button_spacer)
	var confirm_button = host.game_screen_controller._button(host.action_panel_controller._commitment_label(action), host.action_panel_controller._confirm_selected_action, false)
	confirm_button.custom_minimum_size = Vector2(320, 48)
	host.confirmation_actions_box.add_child(confirm_button)
	if host.action_dock:
		host.action_dock.hide()
	host.confirmation_layer.show()
	host.game_screen_controller._sync_action_canvas_visibility()


func _action_needs_confirmation(action: Dictionary) -> bool:
	var warnings = action.get("warnings", [])
	var has_warnings: bool = warnings is Array and not warnings.is_empty()
	var kind = str(action.get("kind", ""))
	return not action.get("costs", {}).is_empty() or bool(action.get("irreversible", false)) or has_warnings or kind in ["move", "tell", "recover", "escort", "route"] or action.get("id", "") == "wait:next"


func _toggle_confirmation_details() -> void:
	if not host.confirmation_details_box or not host.confirmation_details_button:
		return
	host.confirmation_details_box.visible = not host.confirmation_details_box.visible
	host.confirmation_details_button.text = "收起盘算" if host.confirmation_details_box.visible else "展开盘算"


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
			return "确认这个选择"
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
	host.game_screen_controller._sync_action_canvas_visibility()
