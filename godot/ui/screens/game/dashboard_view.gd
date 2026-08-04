extends RefCounted


func build(root: Control, parent: VBoxContainer, factory, dependencies: Dictionary, callbacks: Dictionary) -> Dictionary:
	var colors: Dictionary = factory.colors
	var type_scale: Dictionary = factory.type_scale
	var refs := {}
	var workspace := Control.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(workspace)
	var world_column := VBoxContainer.new()
	world_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world_column.add_theme_constant_override("separation", 8)
	workspace.add_child(world_column)
	_build_world_stage(world_column, factory, dependencies, callbacks, refs)

	var action_dock_host := Control.new()
	action_dock_host.anchor_left = 0.025
	action_dock_host.anchor_right = 0.60
	action_dock_host.anchor_top = 0.52
	action_dock_host.anchor_bottom = 0.965
	action_dock_host.clip_contents = true
	var action_canvas := CanvasLayer.new()
	action_canvas.layer = 1
	root.add_child(action_canvas)
	action_canvas.add_child(action_dock_host)
	var action_dock := PanelContainer.new()
	action_dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dock_style: StyleBoxFlat = factory.panel_style(factory.theme_script.alpha8(colors.surface_dock, 0xea), 0, 2, Color.TRANSPARENT, 24, 18)
	dock_style.border_width_left = 2
	dock_style.border_color = Color(colors.accent, 0.68)
	action_dock.add_theme_stylebox_override("panel", dock_style)
	action_dock_host.add_child(action_dock)
	var content_host := Control.new()
	content_host.clip_contents = true
	content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_dock.add_child(content_host)
	var decision_column := VBoxContainer.new()
	decision_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	decision_column.grow_vertical = Control.GROW_DIRECTION_END
	decision_column.add_theme_constant_override("separation", 7)
	content_host.add_child(decision_column)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	decision_column.add_child(title_row)
	var action_dock_title := Label.new()
	action_dock_title.text = "眼前"
	action_dock_title.add_theme_font_override("font", factory.display_font)
	action_dock_title.add_theme_font_size_override("font_size", type_scale.headline)
	action_dock_title.add_theme_color_override("font_color", colors.accent)
	action_dock_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(action_dock_title)
	var objective_label := Label.new()
	objective_label.text = "风声未定，先看清眼前的人和路。"
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.max_lines_visible = 2
	objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objective_label.add_theme_font_size_override("font_size", type_scale.meta)
	objective_label.add_theme_constant_override("line_spacing", 3)
	objective_label.add_theme_color_override("font_color", colors.muted)
	decision_column.add_child(objective_label)
	var location_detail_box := VBoxContainer.new()
	location_detail_box.add_theme_constant_override("separation", 2)
	decision_column.add_child(location_detail_box)
	var stage_people_box := HFlowContainer.new()
	stage_people_box.add_theme_constant_override("h_separation", 7)
	stage_people_box.add_theme_constant_override("v_separation", 5)
	decision_column.add_child(stage_people_box)
	var rule := HSeparator.new()
	rule.modulate = Color(colors.accent, 0.24)
	decision_column.add_child(rule)
	var overview_actions_box := VBoxContainer.new()
	overview_actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview_actions_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overview_actions_box.add_theme_constant_override("separation", 5)
	decision_column.add_child(overview_actions_box)
	var actor_focus_workspace := HBoxContainer.new()
	actor_focus_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actor_focus_workspace.add_theme_constant_override("separation", 14)
	decision_column.add_child(actor_focus_workspace)
	var message_panel := PanelContainer.new()
	message_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_panel.size_flags_stretch_ratio = 0.38
	message_panel.add_theme_stylebox_override("panel", factory.panel_style(Color(colors.panel_alt, 0.24), 0, 1, Color.TRANSPARENT, 8, 8))
	actor_focus_workspace.add_child(message_panel)
	var actor_focus_message_list := VBoxContainer.new()
	actor_focus_message_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actor_focus_message_list.add_theme_constant_override("separation", 6)
	message_panel.add_child(actor_focus_message_list)
	var actor_focus_detail_scroll := ScrollContainer.new()
	actor_focus_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actor_focus_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actor_focus_detail_scroll.size_flags_stretch_ratio = 0.62
	actor_focus_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	actor_focus_workspace.add_child(actor_focus_detail_scroll)
	var actor_focus_detail_box := VBoxContainer.new()
	actor_focus_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actor_focus_detail_box.add_theme_constant_override("separation", 9)
	actor_focus_detail_scroll.add_child(actor_focus_detail_box)
	var fact_action_scroll := ScrollContainer.new()
	fact_action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fact_action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	decision_column.add_child(fact_action_scroll)
	var actions_box := VBoxContainer.new()
	actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_box.add_theme_constant_override("separation", 7)
	fact_action_scroll.add_child(actions_box)
	var actor_focus_footer := HBoxContainer.new()
	actor_focus_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actor_focus_footer.add_theme_constant_override("separation", 12)
	decision_column.add_child(actor_focus_footer)
	overview_actions_box.hide()
	actor_focus_workspace.hide()
	fact_action_scroll.hide()
	actor_focus_footer.hide()
	action_dock.hide()
	refs.merge({
		"action_canvas": action_canvas, "action_dock_host": action_dock_host,
		"action_dock": action_dock, "action_dock_title": action_dock_title,
		"objective_label": objective_label, "location_detail_box": location_detail_box,
		"stage_people_box": stage_people_box, "overview_actions_box": overview_actions_box,
		"actor_focus_workspace": actor_focus_workspace,
		"actor_focus_message_list": actor_focus_message_list,
		"actor_focus_detail_scroll": actor_focus_detail_scroll,
		"actor_focus_detail_box": actor_focus_detail_box,
		"fact_action_scroll": fact_action_scroll, "actions_box": actions_box,
		"actor_focus_footer": actor_focus_footer,
	})
	return refs


func _build_world_stage(parent: VBoxContainer, factory, dependencies: Dictionary, callbacks: Dictionary, refs: Dictionary) -> void:
	var colors: Dictionary = factory.colors
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	parent.add_child(mode_row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_child(spacer)
	var mode_switch := PanelContainer.new()
	mode_switch.add_theme_stylebox_override("panel", factory.panel_style(Color(colors.panel_alt, 0.52), 1, 5, Color(colors.line, 0.74), 2, 2))
	mode_row.add_child(mode_switch)
	var mode_buttons := HBoxContainer.new()
	mode_buttons.add_theme_constant_override("separation", 0)
	mode_switch.add_child(mode_buttons)
	var location_mode_button: Button = factory.mode_button("◉ 当前地点", callbacks.show_location)
	location_mode_button.custom_minimum_size = Vector2(118, 34)
	mode_buttons.add_child(location_mode_button)
	var map_mode_button: Button = factory.mode_button("◇ 地图", callbacks.show_map)
	map_mode_button.custom_minimum_size = Vector2(82, 34)
	mode_buttons.add_child(map_mode_button)
	var stage_frame := PanelContainer.new()
	stage_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_frame.size_flags_stretch_ratio = 1.0
	stage_frame.custom_minimum_size.y = 560
	stage_frame.add_theme_stylebox_override("panel", factory.panel_style(Color(colors.panel, 0.66), 0, 2, Color.TRANSPARENT, 8, 8))
	parent.add_child(stage_frame)
	var visual_stack := Control.new()
	visual_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	visual_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_frame.add_child(visual_stack)
	var map_panel := HBoxContainer.new()
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_panel.add_theme_constant_override("separation", 0)
	visual_stack.add_child(map_panel)
	var world_map_view: Control = dependencies.world_map_script.new()
	world_map_view.presentation_registry = dependencies.presentation_registry
	world_map_view.display_font = factory.display_font
	world_map_view.minimum_font_size = factory.minimum_text_size
	world_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	world_map_view.size_flags_stretch_ratio = 1.0
	world_map_view.location_selected.connect(callbacks.map_location_selected)
	world_map_view.travel_day_changed.connect(callbacks.travel_day_changed)
	map_panel.add_child(world_map_view)
	var map_detail_frame := PanelContainer.new()
	map_detail_frame.custom_minimum_size.x = 360
	map_detail_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var map_detail_style: StyleBoxFlat = factory.panel_style(Color("08100bf0"), 0, 0, Color.TRANSPARENT, 22, 20)
	map_detail_style.border_width_left = 1
	map_detail_style.border_color = Color(colors.accent, 0.42)
	map_detail_frame.add_theme_stylebox_override("panel", map_detail_style)
	map_panel.add_child(map_detail_frame)
	var map_detail_box := VBoxContainer.new()
	map_detail_box.custom_minimum_size = Vector2(316, 88)
	map_detail_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_detail_box.add_theme_constant_override("separation", 10)
	map_detail_frame.add_child(map_detail_box)
	var location_panel := VBoxContainer.new()
	location_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	location_panel.add_theme_constant_override("separation", 8)
	visual_stack.add_child(location_panel)
	var stage_canvas := Control.new()
	stage_canvas.custom_minimum_size = Vector2(640, 320)
	stage_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_canvas.clip_contents = true
	location_panel.add_child(stage_canvas)
	var location_stage: Control = dependencies.location_stage_script.new()
	location_stage.registry = dependencies.presentation_registry
	location_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_canvas.add_child(location_stage)
	var actor_portrait_frame := PanelContainer.new()
	actor_portrait_frame.anchor_left = 0.56
	actor_portrait_frame.anchor_right = 0.965
	actor_portrait_frame.anchor_top = 0.005
	actor_portrait_frame.anchor_bottom = 1.02
	actor_portrait_frame.add_theme_stylebox_override("panel", factory.panel_style(Color("080b0966"), 0, 0, Color.TRANSPARENT, 0, 0))
	actor_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_canvas.add_child(actor_portrait_frame)
	var portrait_stack := Control.new()
	portrait_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor_portrait_frame.add_child(portrait_stack)
	var actor_portrait := TextureRect.new()
	actor_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	actor_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	actor_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	actor_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait_shader := Shader.new()
	portrait_shader.code = "shader_type canvas_item; void fragment(){ vec4 c = texture(TEXTURE, UV); float l = smoothstep(0.0, 0.28, UV.x); float r = 1.0 - smoothstep(0.92, 1.0, UV.x); float b = 1.0 - smoothstep(0.94, 1.0, UV.y); COLOR = vec4(c.rgb, c.a * l * r * b); }"
	var portrait_material := ShaderMaterial.new()
	portrait_material.shader = portrait_shader
	actor_portrait.material = portrait_material
	portrait_stack.add_child(actor_portrait)
	var portrait_caption := PanelContainer.new()
	portrait_caption.anchor_left = 0.18
	portrait_caption.anchor_right = 0.94
	portrait_caption.anchor_top = 0.815
	portrait_caption.anchor_bottom = 0.955
	portrait_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption_style: StyleBoxFlat = factory.panel_style(Color("070b08b8"), 0, 0, Color.TRANSPARENT, 16, 10)
	caption_style.border_width_left = 1
	caption_style.border_color = Color(colors.accent, 0.48)
	portrait_caption.add_theme_stylebox_override("panel", caption_style)
	portrait_stack.add_child(portrait_caption)
	var caption_content := VBoxContainer.new()
	caption_content.add_theme_constant_override("separation", 4)
	portrait_caption.add_child(caption_content)
	var actor_portrait_name: Label = factory.text(caption_content, "", false, factory.type_scale.section)
	actor_portrait_name.add_theme_color_override("font_color", colors.accent)
	var actor_portrait_meta: Label = factory.text(caption_content, "", true, factory.type_scale.compact)
	actor_portrait_frame.hide()
	location_panel.hide()
	refs.merge({
		"visual_stack": visual_stack, "map_panel": map_panel,
		"location_panel": location_panel, "map_detail_box": map_detail_box,
		"map_mode_button": map_mode_button, "location_mode_button": location_mode_button,
		"world_map_view": world_map_view, "location_stage": location_stage,
		"actor_portrait_frame": actor_portrait_frame, "actor_portrait": actor_portrait,
		"actor_portrait_name": actor_portrait_name, "actor_portrait_meta": actor_portrait_meta,
	})
