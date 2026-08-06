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
	shade.color = host.AppVisualThemeScript.alpha8(host.COLORS.scrim, 0xdf)
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
	host.journal_panel.anchor_left = 0.05
	host.journal_panel.anchor_right = 0.992
	host.journal_panel.anchor_top = 0.026
	host.journal_panel.anchor_bottom = 0.974
	host.journal_panel.add_theme_stylebox_override("panel", host.ui_factory.panel_style(Color("101612ff"), 1, 3, Color(host.COLORS.accent, 0.44), 26, 22))
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
	title_row.custom_minimum_size.y = 40
	title_row.add_theme_constant_override("separation", 12)
	outer.add_child(title_row)
	var title = Label.new()
	title.text = "随身卷宗"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", host.display_font)
	title.add_theme_font_size_override("font_size", host.TYPE_SCALE.title)
	title.add_theme_color_override("font_color", host.COLORS.accent)
	title_row.add_child(title)
	var close_button = host.ui_factory.utility_button("收起", host.journal_panel_controller._close_journal)
	close_button.custom_minimum_size = Vector2(72, 38)
	title_row.add_child(close_button)
	host.player_summary_label = Label.new()
	host.player_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.player_summary_label.add_theme_font_override("font", host.body_font)
	host.player_summary_label.add_theme_font_size_override("font_size", host.TYPE_SCALE.compact)
	host.player_summary_label.add_theme_constant_override("line_spacing", 4)
	host.player_summary_label.add_theme_color_override("font_color", host.COLORS.ink_soft)
	host.player_resources_box = HFlowContainer.new()
	host.player_resources_box.custom_minimum_size.x = 420
	host.player_resources_box.add_theme_constant_override("h_separation", 7)
	host.player_resources_box.add_theme_constant_override("v_separation", 7)
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
	host.journal_graph_button = host.journal_panel_controller._journal_tab_button("图谱", 4)
	for button in [host.journal_echo_button, host.journal_clues_button, host.journal_people_button, host.journal_travel_button, host.journal_graph_button]:
		navigation.add_child(button)
	var player_status_row := HBoxContainer.new()
	player_status_row.name = "PlayerStatusRow"
	player_status_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_status_row.add_theme_constant_override("separation", 12)
	parent.add_child(player_status_row)
	host.player_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_status_row.add_child(host.player_summary_label)
	host.player_resources_box.size_flags_horizontal = Control.SIZE_SHRINK_END
	player_status_row.add_child(host.player_resources_box)
	host.journal_tabs = TabContainer.new()
	host.journal_tabs.tabs_visible = false
	host.journal_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(host.journal_tabs)
	host.scene_box = host.journal_panel_controller._reference_tab(host.journal_tabs, "回响")
	host.clues_box = host.journal_panel_controller._reference_tab(host.journal_tabs, host._ui_text("term_clues"))
	host.people_box = host.journal_panel_controller._reference_tab(host.journal_tabs, "人物")
	host.travel_box = host.journal_panel_controller._reference_tab(host.journal_tabs, "行装")
	host.journal_panel_controller._build_knowledge_graph_tab(host.journal_tabs)
	host.journal_panel_controller._refresh_journal_tab_styles()


func _build_knowledge_graph_tab(tabs: TabContainer) -> void:
	var workspace := HBoxContainer.new()
	workspace.name = "图谱"
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 16)
	tabs.add_child(workspace)
	var graph_column := VBoxContainer.new()
	graph_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_column.add_theme_constant_override("separation", 9)
	workspace.add_child(graph_column)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	graph_column.add_child(filters)
	for definition in [["all", "全部"], ["actor", "人物"], ["claim", "线索"], ["event", "事件"], ["location", "地点"]]:
		var filter_button: Button = host.ui_factory.utility_button(str(definition[1]), host.journal_panel_controller._select_graph_filter.bind(str(definition[0])))
		filter_button.custom_minimum_size = Vector2(72, 34)
		filter_button.add_theme_font_size_override("font_size", host.TYPE_SCALE.compact)
		filters.add_child(filter_button)
		host.knowledge_graph_filter_buttons[definition[0]] = filter_button
	host.knowledge_graph_scroll = ScrollContainer.new()
	host.knowledge_graph_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.knowledge_graph_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.knowledge_graph_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	graph_column.add_child(host.knowledge_graph_scroll)
	host.knowledge_graph_view = host.KnowledgeGraphViewScript.new()
	host.knowledge_graph_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.knowledge_graph_view.display_font = host.display_font
	host.knowledge_graph_view.body_font = host.body_font
	host.knowledge_graph_view.minimum_font_size = host.MIN_READABLE_TEXT_SIZE
	host.knowledge_graph_view.node_selected.connect(host.journal_panel_controller._on_knowledge_node_selected)
	host.knowledge_graph_scroll.add_child(host.knowledge_graph_view)
	host.knowledge_graph_scroll.resized.connect(host.journal_panel_controller._sync_knowledge_graph_canvas_size)
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(330, 0)
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", host.ui_factory.panel_style(Color(host.COLORS.panel_alt, 0.78), 1, 3, Color(host.COLORS.line, 0.72), 18, 18))
	workspace.add_child(detail_panel)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(detail_scroll)
	host.knowledge_graph_detail_box = VBoxContainer.new()
	host.knowledge_graph_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.knowledge_graph_detail_box.add_theme_constant_override("separation", 0)
	detail_scroll.add_child(host.knowledge_graph_detail_box)
	host.journal_panel_controller._refresh_graph_filter_styles("all")


func _journal_tab_button(label_text: String, index: int) -> Button:
	var button = host.ui_factory.utility_button(label_text, host.journal_panel_controller._select_journal_tab.bind(index))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 38)
	button.add_theme_font_size_override("font_size", host.TYPE_SCALE.compact)
	return button


func _select_journal_tab(index: int) -> void:
	if not host.journal_tabs:
		return
	host.journal_tabs.current_tab = clampi(index, 0, host.journal_tabs.get_tab_count() - 1)
	host.journal_panel_controller._refresh_journal_tab_styles()
	if host.journal_tabs.current_tab == 4 and host.knowledge_graph_view:
		host.journal_panel_controller.call_deferred("_sync_knowledge_graph_canvas_size")
		host.knowledge_graph_view.call_deferred("grab_focus")


func _sync_knowledge_graph_canvas_size() -> void:
	if not host.knowledge_graph_view or not host.knowledge_graph_scroll:
		return
	var available_width := maxf(1.0, host.knowledge_graph_scroll.size.x)
	if not is_equal_approx(host.knowledge_graph_view.custom_minimum_size.x, available_width):
		host.knowledge_graph_view.custom_minimum_size = Vector2(available_width, host.knowledge_graph_view.custom_minimum_size.y)
	host.knowledge_graph_view.call_deferred("_layout_nodes")


func _refresh_journal_tab_styles() -> void:
	if not host.journal_tabs:
		return
	var show_player_summary: bool = host.journal_tabs.current_tab == 3
	var player_status_row: Node = host.player_summary_label.get_parent()
	if player_status_row:
		player_status_row.visible = show_player_summary
	host.player_summary_label.visible = show_player_summary
	host.player_resources_box.visible = show_player_summary
	host.journal_panel.anchor_left = 0.05
	host.journal_panel.anchor_right = 0.992
	host.journal_panel.offset_left = 0.0
	host.journal_panel.offset_right = 0.0
	var buttons: Array[Button] = [host.journal_echo_button, host.journal_clues_button, host.journal_people_button, host.journal_travel_button, host.journal_graph_button]
	for index in buttons.size():
		var button = buttons[index]
		if not button:
			continue
		var active = host.journal_tabs.current_tab == index
		var viewing_active_tab: bool = active and host.journal_layer.visible
		button.text = ["回响", str(host._ui_text("term_clues")), "人物", "行装", "图谱"][index] if viewing_active_tab else host.journal_tab_labels[index]
		var status_color = host.journal_tab_colors[index]
		button.add_theme_color_override("font_color", host.COLORS.accent if active else status_color)
		button.add_theme_color_override("font_hover_color", host.COLORS.ink)
		var normal = host.ui_factory.panel_style(Color.TRANSPARENT, 0, 0, Color.TRANSPARENT, 8, 7)
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
	host.journal_tab_labels[2] = "人物 · 可谈 %d" % talkable_people if talkable_people > 0 else "人物"
	host.journal_tab_colors[2] = host.COLORS.muted
	host.journal_tab_labels[3] = "行装"
	host.journal_tab_colors[3] = host.COLORS.muted
	host.journal_tab_labels[4] = "图谱"
	host.journal_tab_colors[4] = host.COLORS.muted
	if travel is Dictionary:
		var missing = host.journal_panel_controller._travel_missing_checks(travel).size()
		if missing > 0:
			host.journal_tab_labels[3] = "行装 · 缺 %d" % missing
			host.journal_tab_colors[3] = host.COLORS.danger
		else:
			host.journal_tab_labels[3] = "行装 · 齐"
			host.journal_tab_colors[3] = host.COLORS.success
	host.journal_panel_controller._refresh_journal_tab_styles()


func _render_knowledge_graph(graph, actions: Array) -> void:
	if not host.knowledge_graph_view or not graph is Dictionary:
		return
	host.knowledge_graph_view.set_meta("available_actions", actions)
	host.knowledge_graph_view.set_graph(graph)
	host.journal_panel_controller._refresh_graph_filter_styles(host.knowledge_graph_view.active_filter)


func _select_graph_filter(kind: String) -> void:
	if not host.knowledge_graph_view:
		return
	host.audio_director.play_ui()
	host.knowledge_graph_view.set_filter(kind)
	host.journal_panel_controller._refresh_graph_filter_styles(kind)


func _refresh_graph_filter_styles(active_kind: String) -> void:
	for kind in host.knowledge_graph_filter_buttons:
		var button: Button = host.knowledge_graph_filter_buttons[kind]
		var active := str(kind) == active_kind
		button.add_theme_color_override("font_color", host.COLORS.accent if active else host.COLORS.muted)
		var style: StyleBoxFlat = host.ui_factory.panel_style(Color(host.COLORS.panel_alt, 0.72) if active else Color.TRANSPARENT, 1 if active else 0, 3, Color(host.COLORS.accent, 0.58), 8, 6)
		button.add_theme_stylebox_override("normal", style)


func _on_knowledge_node_selected(node: Dictionary) -> void:
	if not host.knowledge_graph_detail_box:
		return
	host.ui_factory.clear(host.knowledge_graph_detail_box)
	var kind := str(node.get("kind", ""))
	var title: Label = host.ui_factory.text(host.knowledge_graph_detail_box, str(node.get("label", "未命名")), false, host.TYPE_SCALE.headline)
	title.add_theme_font_override("font", host.display_font)
	title.add_theme_constant_override("line_spacing", 6)
	var state := str(node.get("state", ""))
	if state != "":
		host.journal_panel_controller._knowledge_spacer(8)
		var state_row := HBoxContainer.new()
		host.knowledge_graph_detail_box.add_child(state_row)
		host.journal_panel_controller._knowledge_tag(state_row, state, host.journal_panel_controller._knowledge_kind_color(kind), true)
	var summary := str(node.get("summary", ""))
	if summary != "" and summary != str(node.get("label", "")):
		host.journal_panel_controller._knowledge_spacer(18)
		host.ui_factory.text(host.knowledge_graph_detail_box, summary, true, host.TYPE_SCALE.body)
	host.journal_panel_controller._render_knowledge_details(node, state)
	host.journal_panel_controller._render_knowledge_relations(node)
	host.journal_panel_controller._render_knowledge_actions(node)


func _render_knowledge_details(node: Dictionary, state: String) -> void:
	var details = node.get("details", [])
	if not details is Array or details.is_empty():
		return
	var source := ""
	var learned := ""
	var rows: Array[Dictionary] = []
	var identity_tags: Array[String] = []
	var focus_tags: Array[String] = []
	for detail in details:
		if not detail is Dictionary:
			continue
		var label := str(detail.get("label", "详情"))
		var value := str(detail.get("value", ""))
		if value == "" or value == state or value == str(node.get("label", "")):
			continue
		if label == "来源":
			source = value
		elif label == "获知时间":
			learned = value
		elif label == "身份":
			identity_tags.append(value)
		elif label == "关注":
			for focus in value.split("、", false):
				focus_tags.append(str(focus))
		else:
			rows.append({"label": label, "value": value})
	var compact_source := source if source.length() <= 12 else ""
	if source != "" and compact_source == "":
		rows.push_front({"label": "来源", "value": source})
	if compact_source != "" or learned != "":
		host.journal_panel_controller._knowledge_spacer(14)
		var metadata := GridContainer.new()
		metadata.columns = 2
		metadata.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		metadata.add_theme_constant_override("h_separation", 7)
		metadata.add_theme_constant_override("v_separation", 7)
		host.knowledge_graph_detail_box.add_child(metadata)
		if compact_source != "":
			host.journal_panel_controller._knowledge_tag(metadata, "来源 · %s" % compact_source, host.COLORS.muted)
		if learned != "":
			host.journal_panel_controller._knowledge_tag(metadata, "%s获知" % learned, host.COLORS.muted)
	if not identity_tags.is_empty():
		host.journal_panel_controller._render_knowledge_tag_row("身份", identity_tags)
	if not focus_tags.is_empty():
		host.journal_panel_controller._render_knowledge_tag_row("关注", focus_tags)
	if rows.is_empty():
		return
	host.journal_panel_controller._knowledge_spacer(20)
	for row_data in rows:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 10)
		host.knowledge_graph_detail_box.add_child(row)
		var indent := Control.new()
		indent.custom_minimum_size.x = 12
		row.add_child(indent)
		var label: Label = host.ui_factory.text(row, str(row_data.get("label", "详情")), true, host.TYPE_SCALE.meta)
		label.custom_minimum_size.x = 52
		var value: Label = host.ui_factory.text(row, str(row_data.get("value", "")), false, host.TYPE_SCALE.compact)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		host.journal_panel_controller._knowledge_spacer(8)


func _render_knowledge_relations(node: Dictionary) -> void:
	var graph: Dictionary = host.current_view.get("knowledge_graph", {})
	var edges: Array = graph.get("edges", []) if graph.get("edges", []) is Array else []
	var nodes: Array = graph.get("nodes", []) if graph.get("nodes", []) is Array else []
	var node_id := str(node.get("id", ""))
	var relations: Array[Dictionary] = []
	var relation_indexes := {}
	for edge in edges:
		var source_id := str(edge.get("source_id", ""))
		var target_id := str(edge.get("target_id", ""))
		if source_id != node_id and target_id != node_id:
			continue
		var other_id := target_id if source_id == node_id else source_id
		var other_node: Dictionary = host.journal_panel_controller._knowledge_node(nodes, other_id)
		if other_node.is_empty():
			continue
		var relation_label := str(edge.get("label", ""))
		if not relation_indexes.has(other_id):
			relation_indexes[other_id] = relations.size()
			relations.append({"id": other_id, "label": str(other_node.get("label", "")), "kind": str(other_node.get("kind", "")), "relations": []})
		relation_label = host.journal_panel_controller._knowledge_relation_label(relation_label, str(node.get("kind", "")), str(other_node.get("kind", "")))
		if relation_label != "":
			var relation_values: Array = relations[int(relation_indexes[other_id])]["relations"]
			if relation_label not in relation_values:
				relation_values.append(relation_label)
	if relations.is_empty():
		return
	for related_kind in ["actor", "claim", "event", "location"]:
		var group: Array[Dictionary] = []
		for relation in relations:
			if str(relation.get("kind", "")) == related_kind:
				group.append(relation)
		if group.is_empty():
			continue
		host.journal_panel_controller._knowledge_section_heading(host.journal_panel_controller._knowledge_relation_heading(related_kind))
		for relation in group.slice(0, 6):
			var row := HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 10)
			host.knowledge_graph_detail_box.add_child(row)
			var relation_button: Button = host.journal_panel_controller._knowledge_relation_button(relation)
			relation_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(relation_button)
			var relation_values: Array = relation.get("relations", [])
			if not relation_values.is_empty():
				var tag_row := HBoxContainer.new()
				row.add_child(tag_row)
				host.journal_panel_controller._knowledge_tag(tag_row, "、".join(relation_values), host.COLORS.muted)
			host.journal_panel_controller._knowledge_spacer(8)


func _render_knowledge_actions(node: Dictionary) -> void:
	var action_ids = node.get("action_ids", [])
	if not action_ids is Array or action_ids.is_empty():
		return
	var actions: Array = host.knowledge_graph_view.get_meta("available_actions", [])
	var primary_actions: Array[Dictionary] = []
	var tell_actions: Array[Dictionary] = []
	var other_actions: Array[Dictionary] = []
	for action_id in action_ids:
		var action: Dictionary = host.journal_panel_controller._action_by_id(actions, str(action_id))
		if action.is_empty():
			continue
		if str(action.get("kind", "")) == "tell":
			tell_actions.append(action)
		elif str(action.get("kind", "")) == "verify" and str(node.get("kind", "")) == "claim":
			primary_actions.append(action)
		else:
			other_actions.append(action)
	host.journal_panel_controller._knowledge_section_heading("下一步")
	for action in primary_actions:
		var button: Button = host.ui_factory.button(host.journal_panel_controller._knowledge_action_label(action, node), host.journal_panel_controller._consider_action_from_journal.bind(action), false)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 40
		host.knowledge_graph_detail_box.add_child(button)
		host.journal_panel_controller._knowledge_spacer(8)
	for action in other_actions:
		var button: Button = host.ui_factory.action_button(host.journal_panel_controller._knowledge_action_label(action, node), host.journal_panel_controller._consider_action_from_journal.bind(action))
		button.custom_minimum_size.y = 38
		host.knowledge_graph_detail_box.add_child(button)
		host.journal_panel_controller._knowledge_spacer(8)
	if not tell_actions.is_empty():
		var tell_heading: Label = host.ui_factory.text(host.knowledge_graph_detail_box, "告知对象", true, host.TYPE_SCALE.meta)
		tell_heading.add_theme_color_override("font_color", Color(host.COLORS.muted, 0.92))
		host.journal_panel_controller._knowledge_spacer(8)
		var tell_flow := GridContainer.new()
		tell_flow.columns = 2
		tell_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tell_flow.add_theme_constant_override("h_separation", 7)
		tell_flow.add_theme_constant_override("v_separation", 7)
		host.knowledge_graph_detail_box.add_child(tell_flow)
		for action in tell_actions:
			var tell_button: Button = host.journal_panel_controller._knowledge_compact_action_button(str(action.get("target_name", "对方")), host.journal_panel_controller._consider_action_from_journal.bind(action))
			tell_flow.add_child(tell_button)


func _knowledge_spacer(height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.knowledge_graph_detail_box.add_child(spacer)


func _knowledge_section_heading(value: String) -> void:
	host.journal_panel_controller._knowledge_spacer(24)
	var heading: Label = host.ui_factory.text(host.knowledge_graph_detail_box, value, true, host.TYPE_SCALE.meta)
	heading.add_theme_color_override("font_color", Color(host.COLORS.accent, 0.88))
	host.journal_panel_controller._knowledge_spacer(9)


func _knowledge_tag(parent: Container, value: String, color: Color, emphasized := false) -> void:
	var panel := PanelContainer.new()
	var style: StyleBoxFlat = host.ui_factory.panel_style(Color(host.COLORS.panel_alt, 0.62 if emphasized else 0.38), 1, 2, Color(color, 0.62 if emphasized else 0.28), 9, 5)
	if emphasized:
		style.border_width_left = 3
		style.border_color = Color(color, 0.82)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", host.medium_font)
	label.add_theme_font_size_override("font_size", host.TYPE_SCALE.meta)
	label.add_theme_color_override("font_color", color)
	panel.add_child(label)


func _render_knowledge_tag_row(label_text: String, values: Array[String]) -> void:
	host.journal_panel_controller._knowledge_spacer(14)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	host.knowledge_graph_detail_box.add_child(row)
	var label: Label = host.ui_factory.text(row, label_text, true, host.TYPE_SCALE.meta)
	label.custom_minimum_size.x = 42
	var tags := GridContainer.new()
	tags.columns = 2
	tags.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tags.add_theme_constant_override("h_separation", 6)
	tags.add_theme_constant_override("v_separation", 6)
	row.add_child(tags)
	for value in values:
		host.journal_panel_controller._knowledge_tag(tags, value, host.COLORS.muted)


func _knowledge_relation_button(relation: Dictionary) -> Button:
	var kind := str(relation.get("kind", ""))
	var color: Color = host.journal_panel_controller._knowledge_kind_color(kind)
	var button := Button.new()
	button.text = "%s　›" % str(relation.get("label", "未命名"))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 36
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_override("font", host.medium_font)
	button.add_theme_font_size_override("font_size", host.TYPE_SCALE.compact)
	button.add_theme_color_override("font_color", host.COLORS.ink)
	button.add_theme_color_override("font_hover_color", host.COLORS.ink)
	button.add_theme_color_override("font_pressed_color", color)
	var normal: StyleBoxFlat = host.ui_factory.panel_style(Color(host.COLORS.panel_alt, 0.26), 0, 2, Color.TRANSPARENT, 10, 7)
	normal.border_width_left = 2
	normal.border_color = Color(color, 0.42)
	var hover: StyleBoxFlat = host.ui_factory.panel_style(Color(host.COLORS.panel_hover, 0.72), 0, 2, Color.TRANSPARENT, 10, 7)
	hover.border_width_left = 2
	hover.border_color = color
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", host.ui_factory.panel_style(Color(host.COLORS.bg_lift, 0.94), 1, 2, color, 9, 6))
	button.add_theme_stylebox_override("focus", host.ui_factory.panel_style(Color.TRANSPARENT, 1, 2, host.COLORS.accent, 9, 6))
	button.tooltip_text = "在图谱中查看%s" % str(relation.get("label", "该条目"))
	button.set_meta("knowledge_relation_id", str(relation.get("id", "")))
	button.pressed.connect(host.journal_panel_controller._focus_knowledge_node.bind(str(relation.get("id", ""))))
	return button


func _knowledge_compact_action_button(value: String, callback: Callable) -> Button:
	var button: Button = host.ui_factory.utility_button(value, callback)
	button.custom_minimum_size.y = 34
	button.add_theme_color_override("font_color", host.COLORS.ink)
	button.add_theme_stylebox_override("normal", host.ui_factory.panel_style(Color(host.COLORS.panel_alt, 0.52), 1, 2, Color(host.COLORS.line, 0.62), 11, 6))
	button.add_theme_stylebox_override("hover", host.ui_factory.panel_style(Color(host.COLORS.panel_hover, 0.86), 1, 2, host.COLORS.accent, 11, 6))
	return button


func _focus_knowledge_node(node_id: String) -> void:
	if not host.knowledge_graph_view or not host.knowledge_graph_view.focus_node(node_id):
		return
	host.audio_director.play_ui()
	host.journal_panel_controller._refresh_graph_filter_styles(host.knowledge_graph_view.active_filter)
	host.journal_panel_controller.call_deferred("_scroll_knowledge_selection_into_view")


func _scroll_knowledge_selection_into_view() -> void:
	if not host.knowledge_graph_scroll or not host.knowledge_graph_view:
		return
	var rect: Rect2 = host.knowledge_graph_view.selected_node_rect()
	if rect.size == Vector2.ZERO:
		return
	var target: float = rect.get_center().y - float(host.knowledge_graph_scroll.size.y) * 0.5
	host.knowledge_graph_scroll.scroll_vertical = maxi(0, int(target))


func _knowledge_relation_heading(kind: String) -> String:
	return str({"actor": "相关人物", "claim": "相关线索", "event": "相关事件", "location": "相关地点"}.get(kind, "已知关联"))


func _knowledge_relation_label(label: String, selected_kind: String, related_kind: String) -> String:
	match label:
		"可告知":
			return ""
		"位于":
			return "所在" if selected_kind == "actor" and related_kind == "location" else "在此"
		"通路":
			return "相连"
		"提供":
			return "来源" if selected_kind == "claim" else "提供"
		_:
			return label


func _knowledge_action_label(action: Dictionary, node: Dictionary) -> String:
	match str(action.get("kind", "")):
		"verify":
			return "核验这条线索" if str(node.get("kind", "")) == "claim" else str(action.get("name", "核验"))
		"tell":
			return "告知%s" % str(action.get("target_name", "对方"))
		"move":
			return "前往%s" % str(action.get("target_name", "目的地"))
		_:
			return str(action.get("name", "继续"))


func _action_by_id(actions: Array, action_id: String) -> Dictionary:
	for action in actions:
		if str(action.get("id", "")) == action_id:
			return action
	return {}


func _knowledge_node(nodes: Array, node_id: String) -> Dictionary:
	for node in nodes:
		if str(node.get("id", "")) == node_id:
			return node
	return {}


func _knowledge_kind_color(kind: String) -> Color:
	match kind:
		"claim": return host.COLORS.accent
		"event": return host.COLORS.danger
		"location": return host.COLORS.success
		_: return host.COLORS.muted


func _reference_tab(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.name = tab_name
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Scroll tabs are reading surfaces: keep their contents packed at the top
	# instead of distributing short sections across the available viewport.
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_theme_constant_override("separation", 9)
	scroll.add_child(box)
	return box


func _open_journal() -> void:
	host.audio_director.play_ui()
	if not host.motion_enabled:
		host.journal_panel.position.x = 0
		host.journal_layer.modulate = Color.WHITE
		host.journal_layer.show()
		host.journal_panel_controller._refresh_journal_tab_styles()
		host.game_screen_controller._sync_action_canvas_visibility()
		return
	host.journal_panel.position.x = 42
	host.journal_layer.modulate = Color(1, 1, 1, 0)
	host.journal_layer.show()
	host.journal_panel_controller._refresh_journal_tab_styles()
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
	host.ui_factory.clear(host.clues_box)
	if clues.is_empty():
		var empty_card = host.journal_panel_controller._journal_info_card(host.clues_box, "尚无线索", host.COLORS.muted)
		host.ui_factory.text(empty_card, host._ui_text("journal_empty_clues"), true, host.TYPE_SCALE.compact)
		return
	for index in clues.size():
		var clue: Dictionary = clues[index]
		var fact_id = str(clue.get("fact_id", ""))
		var confidence = int(clue.get("confidence", 0))
		var tone: Color = host.COLORS.success if confidence >= 3 else host.COLORS.accent
		var clue_card := PanelContainer.new()
		var clue_style: StyleBoxFlat = host.ui_factory.panel_style(Color(host.COLORS.panel_alt, 0.42), 1, 3, Color(host.COLORS.line, 0.62), 14, 12)
		clue_style.border_width_left = 3
		clue_style.border_color = Color(tone, 0.72)
		clue_card.add_theme_stylebox_override("panel", clue_style)
		host.clues_box.add_child(clue_card)
		var card_row := HBoxContainer.new()
		card_row.add_theme_constant_override("separation", 14)
		clue_card.add_child(card_row)
		var clue_texture: Texture2D = host.presentation_registry.fact_texture(fact_id)
		if clue_texture:
			var preview := TextureRect.new()
			preview.custom_minimum_size = Vector2(132, 104)
			preview.texture = clue_texture
			preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_row.add_child(preview)
		var clue_content := VBoxContainer.new()
		clue_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clue_content.add_theme_constant_override("separation", 7)
		card_row.add_child(clue_content)
		var clue_header := HBoxContainer.new()
		clue_header.name = "ClueHeader"
		clue_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clue_header.add_theme_constant_override("separation", 8)
		clue_content.add_child(clue_header)
		var claim = host.ui_factory.text(clue_header, str(clue.get("claim", "未知传言")), false, host.TYPE_SCALE.body)
		claim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		claim.add_theme_font_override("font", host.medium_font)
		var status = "已核实" if confidence >= 3 else ("较可信" if confidence == 2 else "待核验")
		var status_tags: Array[String] = [status, str(clue.get("source", "来源未知"))]
		if bool(clue.get("contested", false)):
			status_tags.append("与旧线索冲突")
		var clue_meta = host.ui_factory.text(clue_header, " · ".join(status_tags), false, host.TYPE_SCALE.meta)
		clue_meta.autowrap_mode = TextServer.AUTOWRAP_OFF
		clue_meta.add_theme_color_override("font_color", Color(tone, 0.90))
		var verify_action = host.journal_panel_controller._action_for_fact(actions, fact_id, "verify")
		var target_count = host.action_panel_controller._count_tell_actions(actions, "", fact_id)
		if not verify_action.is_empty() and confidence < 3:
			var verify_link = host.ui_factory.button(host._ui_text("journal_verify_clue"), host.action_panel_controller._consider_action.bind(verify_action), true)
			verify_link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			verify_link.custom_minimum_size = Vector2(180, 38)
			clue_content.add_child(verify_link)
		elif target_count > 0:
			var link = host.ui_factory.button("选择告知对象 · %d 人" % target_count, host.action_panel_controller._focus_fact_actions.bind(fact_id, str(clue.get("claim", "未知传言"))), true)
			link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			link.custom_minimum_size = Vector2(190, 38)
			clue_content.add_child(link)


func _journal_info_card(parent: Container, title_text: String, tone: Color) -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = host.ui_factory.panel_style(Color(host.COLORS.panel_alt, 0.22), 0, 2, Color.TRANSPARENT, 14, 11)
	style.border_width_left = 2
	style.border_color = Color(tone, 0.62)
	frame.add_theme_stylebox_override("panel", style)
	parent.add_child(frame)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	frame.add_child(content)
	if title_text != "":
		var title = host.ui_factory.text(content, title_text, true, host.TYPE_SCALE.meta)
		title.add_theme_color_override("font_color", tone)
	return content


func _journal_header_row(parent: Container, title_text: String, tone: Color, tags: Array, node_name := "") -> HBoxContainer:
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 8)
	parent.add_child(header)
	if node_name != "":
		header.name = node_name
	var title = host.ui_factory.text(header, title_text, true, host.TYPE_SCALE.meta)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", tone)
	var tag_parts: Array[String] = []
	for tag_value in tags:
		var text_value := str(tag_value).strip_edges()
		if text_value != "":
			tag_parts.append(text_value)
	if not tag_parts.is_empty():
		var meta = host.ui_factory.text(header, " · ".join(tag_parts), false, host.TYPE_SCALE.meta)
		meta.autowrap_mode = TextServer.AUTOWRAP_OFF
		meta.add_theme_color_override("font_color", Color(tone, 0.90))
	return header


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
	host.ui_factory.clear(host.scene_box)
	var has_public_change := feedback is Dictionary or not causal_threads.is_empty() or not events.is_empty()
	if not has_public_change:
		var empty_card = host.journal_panel_controller._journal_info_card(host.scene_box, "暂无新动静", host.COLORS.muted)
		if not guidance.is_empty():
			host.ui_factory.text(empty_card, str(guidance[0]), true, host.TYPE_SCALE.compact)
		else:
			host.ui_factory.text(empty_card, "先处理眼前的准备，新的变化会记录在这里。", true, host.TYPE_SCALE.compact)
		return
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
		var guidance_heading = host.ui_factory.text(host.scene_box, "接下来", true, host.TYPE_SCALE.meta)
		guidance_heading.add_theme_color_override("font_color", host.COLORS.accent)
		for index in range(mini(guidance.size(), 2)):
			host.ui_factory.text(host.scene_box, str(guidance[index]), true, 14)
	if events.is_empty():
		return
	var event_heading = host.ui_factory.text(host.scene_box, "近来风声", true, host.TYPE_SCALE.meta)
	event_heading.add_theme_color_override("font_color", host.COLORS.accent)
	var rendered_events = 0
	for index in range(events.size() - 1, -1, -1):
		var event = events[index]
		if str(event.get("actor_name", "")) == player_name:
			continue
		host.ui_factory.text(host.scene_box, "第 %d 日 · %s" % [int(event.get("day", 0)), event.get("description", "局势变化")], true, 14)
		rendered_events += 1
		if rendered_events >= 3:
			break


func _render_causal_threads(parent: VBoxContainer, threads: Array) -> void:
	if threads.is_empty():
		return
	var heading = host.ui_factory.text(parent, host._ui_text("information_causal_heading"), true, host.TYPE_SCALE.meta)
	heading.add_theme_color_override("font_color", host.COLORS.accent)
	var first = maxi(0, threads.size() - 2)
	for index in range(threads.size() - 1, first - 1, -1):
		var thread: Dictionary = threads[index]
		var stage = str(thread.get("stage", "delivered"))
		var stage_line = host.ui_factory.text(parent, "%s · %s" % [thread.get("actor_name", "有人"), thread.get("stage_label", "已送达")], false, 14)
		stage_line.add_theme_color_override("font_color", host.COLORS.success if stage == "changed" else host.COLORS.accent)
		var fact_line = host.ui_factory.text(parent, "“%s”" % thread.get("fact_claim", "一条消息"), true, 16)
		fact_line.add_theme_font_override("font", host.narrative_font)
		fact_line.add_theme_constant_override("line_spacing", 4)
		host.ui_factory.text(parent, str(thread.get("summary", "尚无公开回响")), true, 13)


func _render_feedback_summary(parent: VBoxContainer, feedback: Dictionary) -> void:
	var status_names = {"completed": "已结算", "started": "进行中", "failed": "未能完成", "advanced": "已推进"}
	var status_key = str(feedback.get("status", ""))
	var status = str(status_names.get(status_key, "已结算"))
	var day = int(feedback.get("day", host.current_view.get("day", 0)))
	var meta = host.ui_factory.text(parent, "第 %d 日 · %s" % [day, status], true, host.TYPE_SCALE.meta)
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
	var title = host.ui_factory.text(parent, headline, false, 18)
	title.add_theme_font_override("font", host.display_font)
	if cause != "":
		host.ui_factory.text(parent, cause, true, 14)
	var messages: Array = feedback.get("messages", [])
	var stop_reason = str(feedback.get("stop_reason", ""))
	if stop_reason != "":
		var stop_line = host.ui_factory.text(parent, "为何停下 · %s" % stop_reason, false, 14)
		stop_line.add_theme_color_override("font_color", host.COLORS.accent)
	for index in range(mini(messages.size(), 2)):
		host.ui_factory.text(parent, "· %s" % messages[index], false, 14)
	var journal: Array = feedback.get("journal", [])
	if not journal.is_empty():
		var journal_heading = host.ui_factory.text(parent, "记入卷宗", true, host.TYPE_SCALE.meta)
		journal_heading.add_theme_color_override("font_color", host.COLORS.accent)
		for entry in journal:
			host.ui_factory.text(parent, "· %s" % entry, false, 14)
	var disclosure: Dictionary = host.ui_factory.foldable_section(parent, "推演过程", not host.journal_feedback_details_visible)
	host.journal_feedback_details_fold = disclosure.container
	host.journal_feedback_details_box = disclosure.content
	host.journal_feedback_details_fold.folding_changed.connect(host.journal_panel_controller._on_journal_feedback_folded)
	host.presentation_controller._render_feedback_evidence_into(host.journal_feedback_details_box, feedback)


func _on_journal_feedback_folded(is_folded: bool) -> void:
	host.journal_feedback_details_visible = not is_folded


func _feedback_signature(feedback) -> String:
	if not feedback is Dictionary:
		return ""
	return "%s|%s|%s" % [feedback.get("day", ""), feedback.get("action_id", ""), feedback.get("status", "")]


func _render_travel_readiness(travel, preparation = {}) -> void:
	host.ui_factory.clear(host.travel_box)
	if not travel is Dictionary:
		var empty_card = host.journal_panel_controller._journal_info_card(host.travel_box, "尚无远行目标", host.COLORS.muted)
		host.ui_factory.text(empty_card, "先从地点、人物或线索中确定下一段路。", true, host.TYPE_SCALE.compact)
		return
	var route: Array = travel.get("route", [])
	var destination = str(travel.get("destination", "目标地点"))
	if destination == "" and not route.is_empty():
		destination = str(route[route.size() - 1])
	var destination_row := HBoxContainer.new()
	destination_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	destination_row.add_theme_constant_override("separation", 10)
	host.travel_box.add_child(destination_row)
	var destination_title = host.ui_factory.text(destination_row, destination, false, host.TYPE_SCALE.section)
	destination_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	destination_title.add_theme_color_override("font_color", host.COLORS.accent)
	var destination_duration = host.ui_factory.text(destination_row, "约 %d 日" % int(travel.get("travel_days", 0)), false, host.TYPE_SCALE.meta)
	destination_duration.add_theme_color_override("font_color", host.COLORS.accent)
	var missing = host.journal_panel_controller._travel_missing_checks(travel)
	var ready_checks = host.journal_panel_controller._travel_ready_checks(travel)
	if missing.is_empty():
		var ready_card = host.journal_panel_controller._journal_info_card(host.travel_box, "已经可以成行", host.COLORS.success)
		host.ui_factory.text(ready_card, "路线和必需物资均已就绪。", true, host.TYPE_SCALE.compact)
	else:
		var missing_title = host.ui_factory.text(host.travel_box, "尚缺 %d 项" % missing.size(), false, host.TYPE_SCALE.body)
		missing_title.add_theme_font_override("font", host.medium_font)
		missing_title.add_theme_color_override("font_color", host.COLORS.danger)
		var missing_list := VBoxContainer.new()
		missing_list.name = "TravelBlockerList"
		missing_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		missing_list.add_theme_constant_override("separation", 0)
		host.travel_box.add_child(missing_list)
		for check in missing:
			var check_label = str(check.get("label", "路线条件"))
			var blocker_row := HBoxContainer.new()
			blocker_row.custom_minimum_size.y = 50
			blocker_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			blocker_row.add_theme_constant_override("separation", 12)
			missing_list.add_child(blocker_row)
			var blocker_label = host.ui_factory.text(blocker_row, host.journal_panel_controller._travel_blocker_text(check_label), false, host.TYPE_SCALE.compact)
			blocker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			blocker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			blocker_label.add_theme_color_override("font_color", host.COLORS.danger)
			var resolution_action = host.journal_panel_controller._travel_resolution_action(host.available_actions_cache, check_label)
			if not resolution_action.is_empty():
				var resolution_button = host.ui_factory.button(host.journal_panel_controller._travel_resolution_label(resolution_action), host.journal_panel_controller._consider_action_from_journal.bind(resolution_action), true)
				resolution_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				resolution_button.custom_minimum_size = Vector2(190, 36)
				blocker_row.add_child(resolution_button)
			var blocker_rule := HSeparator.new()
			blocker_rule.modulate = Color(host.COLORS.danger, 0.24)
			missing_list.add_child(blocker_rule)
	if preparation is Dictionary:
		var score_sources: Array = preparation.get("score_sources", [])
		if not score_sources.is_empty():
			var rating = str(preparation.get("rating", "尚未判断"))
			var total_score = int(preparation.get("total_score", 0))
			var target_score = int(preparation.get("target_score", 0))
			var preparation_tone: Color = host.COLORS.success if total_score >= target_score else host.COLORS.danger
			var preparation_section := VBoxContainer.new()
			preparation_section.name = "PreparationSection"
			preparation_section.add_theme_constant_override("separation", 5)
			host.travel_box.add_child(preparation_section)
			host.journal_panel_controller._journal_header_row(preparation_section, "准备度", preparation_tone, ["%d / %d" % [total_score, target_score], rating], "PreparationHeader")
			var rating_detail: String = host.journal_panel_controller._first_sentence(str(preparation.get("rating_detail", "")))
			if rating_detail != "":
				host.ui_factory.text(preparation_section, rating_detail, true, host.TYPE_SCALE.compact)
	var timing = str(travel.get("timing", ""))
	if timing != "":
		var timing_line = host.ui_factory.text(host.travel_box, timing, false, host.TYPE_SCALE.meta)
		timing_line.add_theme_color_override("font_color", host.COLORS.danger if timing.contains("来不及") else host.COLORS.accent)
	var disclosure: Dictionary = host.ui_factory.foldable_section(host.travel_box, "路线与依据", not host.journal_travel_details_visible)
	host.journal_travel_details_fold = disclosure.container
	host.journal_travel_details_box = disclosure.content
	host.journal_travel_details_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	host.journal_travel_details_box.add_theme_constant_override("separation", 9)
	host.journal_travel_details_fold.folding_changed.connect(host.journal_panel_controller._on_journal_travel_folded)
	var ready_texts: Array[String] = []
	for check in ready_checks:
		ready_texts.append(host.journal_panel_controller._travel_ready_text(str(check.get("label", "路线条件"))))
	var route_ready_tags: Array[String] = []
	for ready_text in ready_texts:
		if ready_text.contains("路线"):
			route_ready_tags.append(ready_text)
	if not route.is_empty():
		var route_rule := HSeparator.new()
		route_rule.modulate = Color(host.COLORS.accent, 0.24)
		host.journal_travel_details_box.add_child(route_rule)
		var route_section := VBoxContainer.new()
		route_section.add_theme_constant_override("separation", 5)
		host.journal_travel_details_box.add_child(route_section)
		host.journal_panel_controller._journal_header_row(route_section, "路线", host.COLORS.accent, route_ready_tags, "RouteHeader")
		host.ui_factory.text(route_section, " → ".join(route), true, host.TYPE_SCALE.compact)
	var remaining_ready_texts: Array[String] = []
	for ready_text in ready_texts:
		if not ready_text.contains("路线"):
			remaining_ready_texts.append(ready_text)
	if not remaining_ready_texts.is_empty():
		host.journal_panel_controller._journal_header_row(host.journal_travel_details_box, "已备条件", host.COLORS.success, remaining_ready_texts, "ReadyChecksHeader")
	if ready_checks.is_empty():
		host.ui_factory.text(host.journal_travel_details_box, "尚无已满足的准备项。", true, host.TYPE_SCALE.compact)
	if preparation is Dictionary:
		var detail_sources: Array = preparation.get("score_sources", [])
		if not detail_sources.is_empty():
			var basis_section := VBoxContainer.new()
			basis_section.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			basis_section.add_theme_constant_override("separation", 5)
			host.journal_travel_details_box.add_child(basis_section)
			var basis_title = host.ui_factory.text(basis_section, "准备依据", false, host.TYPE_SCALE.meta)
			basis_title.add_theme_color_override("font_color", host.COLORS.muted)
			for factor in detail_sources:
				var factor_tone: Color = host.COLORS.success if bool(factor.get("ready", false)) else host.COLORS.muted
				var factor_row := HBoxContainer.new()
				factor_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				factor_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
				basis_section.add_child(factor_row)
				var factor_label = host.ui_factory.text(factor_row, "%s %d" % [factor.get("label", "准备"), int(factor.get("value", 0))], false, host.TYPE_SCALE.meta)
				factor_label.autowrap_mode = TextServer.AUTOWRAP_OFF
				factor_label.custom_minimum_size.x = 260
				factor_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				factor_label.add_theme_color_override("font_color", factor_tone)
				var factor_status = host.ui_factory.text(factor_row, str(factor.get("status", "")), false, host.TYPE_SCALE.meta)
				factor_status.autowrap_mode = TextServer.AUTOWRAP_OFF
				factor_status.size_flags_horizontal = Control.SIZE_SHRINK_END
				factor_status.add_theme_color_override("font_color", factor_tone)
			host.ui_factory.text(basis_section, host._ui_text("preparation_explanation"), true, host.TYPE_SCALE.meta)
	host.journal_panel_controller._render_route_progresses(host.journal_travel_details_box, host.current_view.get("route_progresses", []), false)


func _first_sentence(value: String) -> String:
	var normalized := value.strip_edges()
	if normalized == "":
		return ""
	var end := normalized.find("。")
	return normalized if end < 0 else normalized.substr(0, end + 1)


func _render_route_progress(parent: VBoxContainer, route_progress, compact: bool) -> void:
	if not route_progress is Dictionary or route_progress.is_empty():
		return
	var heading = host.ui_factory.text(parent, "当前路线 · %s" % route_progress.get("label", "未命名路线"), true, host.TYPE_SCALE.meta)
	heading.add_theme_color_override("font_color", host.COLORS.accent)
	var status = str(route_progress.get("status", "推进中"))
	var next_step = str(route_progress.get("next_step", "等待下一次变化"))
	var status_line = host.ui_factory.text(parent, "%s · %s" % [status, next_step], false, 14 if compact else 15)
	status_line.add_theme_color_override("font_color", host.COLORS.danger if bool(route_progress.get("urgent", false)) else (host.COLORS.success if bool(route_progress.get("complete", false)) else host.COLORS.ink))
	if compact:
		return
	var window = str(route_progress.get("window", ""))
	var location = str(route_progress.get("location", ""))
	if window != "" or location != "":
		host.ui_factory.text(parent, "窗口 · %s%s" % [window, (" · " + location) if location != "" else ""], true, 13)
	var personal_return = str(route_progress.get("personal_return", ""))
	if personal_return != "":
		host.ui_factory.text(parent, "关系到 · %s" % personal_return, true, 13)
	var if_ignored = str(route_progress.get("if_ignored", ""))
	if if_ignored != "":
		var ignored_line = host.ui_factory.text(parent, "若未处理 · %s" % if_ignored, true, 13)
		ignored_line.add_theme_color_override("font_color", host.COLORS.danger)


func _render_route_progresses(parent: VBoxContainer, route_progresses, compact: bool = false) -> void:
	if route_progresses is Array and not route_progresses.is_empty():
		var heading = host.ui_factory.text(parent, "并行路线 · %d 项" % route_progresses.size(), true, host.TYPE_SCALE.meta)
		heading.add_theme_color_override("font_color", host.COLORS.accent)
		var visible_count: int = mini(3, route_progresses.size()) if compact else route_progresses.size()
		for index in visible_count:
			_render_route_progress(parent, route_progresses[index], compact)
		if compact and route_progresses.size() > visible_count:
			host.ui_factory.text(parent, "另有 %d 条路线，详见卷宗。" % (route_progresses.size() - visible_count), true, 12)


func _on_journal_travel_folded(is_folded: bool) -> void:
	host.journal_travel_details_visible = not is_folded


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
	host.ui_factory.clear(host.people_box)
	var tracked_plans: Array = host.current_view.get("world_map", {}).get("actors", [])
	if actors.is_empty() and tracked_plans.is_empty():
		var empty_card = host.journal_panel_controller._journal_info_card(host.people_box, "此地无人", host.COLORS.muted)
		host.ui_factory.text(empty_card, "暂时没有可以交谈或追踪的人物。", true, host.TYPE_SCALE.compact)
		return
	var talkable_people = 0
	for actor in actors:
		if host.action_panel_controller._count_tell_actions(actions, str(actor.get("id", "")), "") > 0:
			talkable_people += 1
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	host.people_box.add_child(columns)
	if not tracked_plans.is_empty():
		var tracking_column := VBoxContainer.new()
		tracking_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tracking_column.add_theme_constant_override("separation", 9)
		columns.add_child(tracking_column)
		var tracking_heading = host.ui_factory.text(tracking_column, "局势人物", false, host.TYPE_SCALE.section)
		tracking_heading.add_theme_color_override("font_color", host.COLORS.accent)
		var common_location: String = host.journal_panel_controller._common_plan_value(tracked_plans, "location_name")
		var common_status: String = host.journal_panel_controller._common_plan_value(tracked_plans, "status")
		var common_plan: String = host.journal_panel_controller._common_plan_value(tracked_plans, "plan")
		var common_reason: String = host.journal_panel_controller._common_plan_value(tracked_plans, "reason")
		var summary_title := "%d 人" % tracked_plans.size()
		if common_location != "":
			summary_title = "%s · %s" % [common_location, summary_title]
		if common_status != "":
			summary_title += common_status
		var shared_card = host.journal_panel_controller._journal_info_card(tracking_column, "", host.COLORS.accent)
		host.journal_panel_controller._journal_header_row(shared_card, summary_title, host.COLORS.accent, [common_plan] if common_plan != "" else [], "SituationHeader")
		if common_reason != "":
			host.ui_factory.text(shared_card, common_reason, true, host.TYPE_SCALE.compact)
		for plan in tracked_plans:
			var plan_card = host.journal_panel_controller._journal_info_card(tracking_column, str(plan.get("name", "无名者")), host.COLORS.muted)
			host.ui_factory.text(plan_card, str(plan.get("public_goal", "目标尚未公开")), true, host.TYPE_SCALE.compact)
			var difference_tags: Array[String] = []
			if common_location == "":
				difference_tags.append(str(plan.get("location_name", "位置不明")))
			if common_status == "":
				difference_tags.append(str(plan.get("status", "观望")))
			if common_plan == "":
				difference_tags.append(str(plan.get("plan", "观察局势")))
			if not difference_tags.is_empty():
				host.action_panel_controller._render_action_tag_row(plan_card, difference_tags, host.COLORS.muted)
			if common_reason == "":
				host.ui_factory.text(plan_card, str(plan.get("reason", "缘由尚未公开")), true, host.TYPE_SCALE.meta)
			if str(plan.get("destination_name", "")) != "":
				host.action_panel_controller._render_action_tag_row(plan_card, ["前往%s" % plan.get("destination_name", "未知地点"), "预计第 %d 日" % int(plan.get("expected_day", 0))], host.COLORS.accent)
			if bool(plan.get("changed_by_player", false)):
				var intervention = host.ui_factory.text(plan_card, "因你改变，原本%s。" % plan.get("previous_plan", "另有安排"), true, host.TYPE_SCALE.meta)
				intervention.add_theme_color_override("font_color", host.COLORS.accent)
	var local_column := VBoxContainer.new()
	local_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	local_column.add_theme_constant_override("separation", 9)
	columns.add_child(local_column)
	var local_header := HBoxContainer.new()
	local_header.name = "LocalPeopleHeader"
	local_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	local_header.add_theme_constant_override("separation", 8)
	local_column.add_child(local_header)
	var local_heading = host.ui_factory.text(local_header, "此地人物", false, host.TYPE_SCALE.section)
	local_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	local_heading.add_theme_color_override("font_color", host.COLORS.accent)
	var local_counts: Array[String] = ["在场 %d" % actors.size()]
	if talkable_people > 0:
		local_counts.append("可交谈 %d" % talkable_people)
	var local_meta = host.ui_factory.text(local_header, " · ".join(local_counts), false, host.TYPE_SCALE.meta)
	local_meta.autowrap_mode = TextServer.AUTOWRAP_OFF
	local_meta.add_theme_color_override("font_color", host.COLORS.accent if talkable_people > 0 else host.COLORS.muted)
	for index in actors.size():
		var actor: Dictionary = actors[index]
		var actor_name = str(actor.get("name", "无名者"))
		var actor_card = host.journal_panel_controller._journal_info_card(local_column, "", host.COLORS.muted)
		var focus: Array = actor.get("public_focus", [])
		var actor_header_tags: Array[String] = []
		if not focus.is_empty():
			actor_header_tags.append("关注 %s" % str(focus[0]))
		host.journal_panel_controller._journal_header_row(actor_card, "%s · %s" % [actor_name, actor.get("public_role", "可交谈人物")], host.COLORS.muted, actor_header_tags, "ActorSummaryHeader")
		var local_plan: Dictionary = actor.get("plan", {}) if actor.get("plan", {}) is Dictionary else {}
		if not local_plan.is_empty():
			host.ui_factory.text(actor_card, str(local_plan.get("plan", "观察局势")), true, host.TYPE_SCALE.compact)
		var actor_id = str(actor.get("id", ""))
		var clue_count = host.action_panel_controller._count_tell_actions(actions, actor_id, "")
		var action_row := HBoxContainer.new()
		action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_row.add_theme_constant_override("separation", 8)
		actor_card.add_child(action_row)
		if clue_count > 0:
			host.action_panel_controller._action_tag(action_row, "%d 条线索" % clue_count, host.COLORS.accent)
		var link_text: String = "交谈" if clue_count > 0 else str(host._ui_text("people_view"))
		var link = host.ui_factory.button(link_text, host.action_panel_controller._focus_actor_from_reference.bind(actor_id, actor_name), true)
		link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		link.custom_minimum_size = Vector2(108, 36)
		action_row.add_child(link)


func _common_plan_value(plans: Array, key: String) -> String:
	if plans.is_empty():
		return ""
	var common := str(plans[0].get(key, "")).strip_edges()
	if common == "":
		return ""
	for plan in plans:
		if str(plan.get(key, "")).strip_edges() != common:
			return ""
	return common
