extends RefCounted

var host


func _init(value) -> void:
	host = value


func _configure_theme() -> void:
	host.body_font = host.SourceHanSansFont
	host.medium_font = host.SourceHanSansMediumFont
	host.display_font = host.SourceHanSerifFont
	host.narrative_font = host.WenKaiFont
	var app_theme = Theme.new()
	app_theme.default_font = host.body_font
	app_theme.default_font_size = host.TYPE_SCALE.body
	app_theme.set_font("font", "Button", host.medium_font)
	app_theme.set_font("font", "MenuButton", host.medium_font)
	app_theme.set_font("font", "TabBar", host.medium_font)
	app_theme.set_color("font_color", "Label", host.COLORS.ink)
	app_theme.set_color("font_color", "Button", host.COLORS.ink)
	app_theme.set_color("font_hover_color", "Button", host.COLORS.ink)
	app_theme.set_color("font_pressed_color", "Button", host.COLORS.ink)
	app_theme.set_color("font_focus_color", "Button", host.COLORS.ink)
	app_theme.set_color("font_disabled_color", "Button", Color(host.COLORS.muted, 0.45))
	app_theme.set_color("font_color", "LineEdit", host.COLORS.ink)
	app_theme.set_color("font_placeholder_color", "LineEdit", Color(host.COLORS.muted, 0.62))
	app_theme.set_color("caret_color", "LineEdit", host.COLORS.accent)
	app_theme.set_color("selection_color", "LineEdit", Color(host.COLORS.accent, 0.28))
	app_theme.set_stylebox("panel", "TabContainer", host.game_screen_controller._panel_style(Color.TRANSPARENT, 0, 0))
	app_theme.set_stylebox("tab_selected", "TabBar", host.game_screen_controller._tab_style(host.COLORS.panel_hover, host.COLORS.accent))
	app_theme.set_stylebox("tab_hovered", "TabBar", host.game_screen_controller._tab_style(host.COLORS.panel_alt, host.COLORS.line))
	app_theme.set_stylebox("tab_unselected", "TabBar", host.game_screen_controller._tab_style(Color.TRANSPARENT, Color.TRANSPARENT))
	app_theme.set_color("font_selected_color", "TabBar", host.COLORS.accent)
	app_theme.set_color("font_hovered_color", "TabBar", host.COLORS.ink)
	app_theme.set_color("font_unselected_color", "TabBar", host.COLORS.muted)
	app_theme.set_stylebox("scroll", "VScrollBar", host.game_screen_controller._panel_style(Color.TRANSPARENT, 0, 0, Color.TRANSPARENT, 0, 0))
	app_theme.set_stylebox("grabber", "VScrollBar", host.game_screen_controller._panel_style(Color(host.COLORS.line, 0.82), 0, 4, Color.TRANSPARENT, 0, 0))
	app_theme.set_stylebox("grabber_highlight", "VScrollBar", host.game_screen_controller._panel_style(host.COLORS.accent_pressed, 0, 4, Color.TRANSPARENT, 0, 0))
	app_theme.set_stylebox("grabber_pressed", "VScrollBar", host.game_screen_controller._panel_style(host.COLORS.accent, 0, 4, Color.TRANSPARENT, 0, 0))
	app_theme.set_constant("minimum_grab_thickness", "VScrollBar", 28)
	app_theme.set_stylebox("panel", "TooltipPanel", host.game_screen_controller._panel_style(host.COLORS.panel_alt, 1, 5, host.COLORS.line, 10, 8))
	app_theme.set_color("font_color", "TooltipLabel", host.COLORS.ink)
	app_theme.set_font_size("font_size", "TooltipLabel", host.TYPE_SCALE.meta)
	host.theme = app_theme


func _build_interface() -> void:
	var background = TextureRect.new()
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.46, 1.0])
	gradient.colors = PackedColorArray([host.COLORS.bg_lift, host.COLORS.bg, Color("060806")])
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 1024
	gradient_texture.height = 1024
	gradient_texture.fill_from = Vector2(0.0, 0.0)
	gradient_texture.fill_to = Vector2(1.0, 1.0)
	background.texture = gradient_texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(background)

	var top_rule = ColorRect.new()
	top_rule.color = Color(host.COLORS.accent, 0.45)
	top_rule.custom_minimum_size.y = 2
	top_rule.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(top_rule)

	host.game_layer = VBoxContainer.new()
	host.game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
	host.game_layer.add_theme_constant_override("separation", 10)
	host.add_child(host.game_layer)
	host.game_screen_controller._build_header()
	host.game_screen_controller._build_dashboard()
	host.game_screen_controller._build_footer()
	host.game_layer.hide()

	host.start_settings_screen_controller._build_start_layer()
	host.journal_panel_controller._build_journal_layer()
	host.action_panel_controller._build_confirmation_layer()
	host.start_settings_screen_controller._build_settings_layer()
	host.presentation_controller._build_causal_layer()
	host.presentation_controller._build_ending_layer()
	host.presentation_director = host.PresentationDirectorScript.new()
	host.add_child(host.presentation_director)
	host.presentation_director.configure(host.display_font, host.medium_font, host.presentation_registry)


func _build_header() -> void:
	var header = PanelContainer.new()
	var header_style = host.game_screen_controller._panel_style(Color("090d0ac7"), 0, 0, Color.TRANSPARENT, 18, 6)
	header_style.border_width_bottom = 1
	header_style.border_color = Color(host.COLORS.accent, 0.22)
	header.add_theme_stylebox_override("panel", header_style)
	header.custom_minimum_size.y = 56
	host.game_layer.add_child(header)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	header.add_child(row)

	host.header_brand_label = Label.new()
	host.header_brand_label.text = "游戏"
	host.header_brand_label.add_theme_font_override("font", host.display_font)
	host.header_brand_label.add_theme_font_size_override("font_size", 24)
	host.header_brand_label.add_theme_color_override("font_color", host.COLORS.accent)
	row.add_child(host.header_brand_label)
	host.header_world_title_label = Label.new()
	host.header_world_title_label.text = ""
	host.header_world_title_label.add_theme_font_override("font", host.display_font)
	host.header_world_title_label.add_theme_font_size_override("font_size", 16)
	host.header_world_title_label.add_theme_color_override("font_color", Color(host.COLORS.accent, 0.78))
	row.add_child(host.header_world_title_label)
	var header_spacer = Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(header_spacer)

	host.day_label = host.game_screen_controller._hud_label(row, host.COLORS.accent)
	host.place_label = host.game_screen_controller._hud_label(row, host.COLORS.ink)
	host.phase_label = host.game_screen_controller._hud_label(row, host.COLORS.muted)
	host.timing_label = Label.new()
	host.timing_label.hide()
	header.add_child(host.timing_label)
	var journal_button = host.game_screen_controller._utility_button("卷", host.journal_panel_controller._open_journal)
	journal_button.tooltip_text = "随身卷宗"
	journal_button.custom_minimum_size = Vector2(42, 34)
	row.add_child(journal_button)
	var save_button = host.game_screen_controller._utility_button("存", host._save_game)
	save_button.tooltip_text = "保存当前进度"
	save_button.custom_minimum_size = Vector2(42, 34)
	row.add_child(save_button)
	var tool_divider = Label.new()
	tool_divider.text = "│"
	tool_divider.add_theme_color_override("font_color", Color(host.COLORS.line, 0.72))
	tool_divider.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tool_divider)
	host.sound_button = host.game_screen_controller._utility_button("⚙", host.start_settings_screen_controller._open_audio_settings)
	host.sound_button.tooltip_text = "声音与显示设置"
	host.sound_button.custom_minimum_size = Vector2(42, 34)
	row.add_child(host.sound_button)
	var return_button = host.game_screen_controller._utility_button("↩", host._return_to_start)
	return_button.tooltip_text = "返回卷首"
	return_button.custom_minimum_size = Vector2(42, 34)
	row.add_child(return_button)


func _build_dashboard() -> void:
	var workspace = Control.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.game_layer.add_child(workspace)

	var world_column = VBoxContainer.new()
	world_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world_column.add_theme_constant_override("separation", 8)
	workspace.add_child(world_column)
	host.game_screen_controller._build_world_stage(world_column)

	host.action_dock_host = Control.new()
	host.action_dock_host.anchor_left = 0.025
	host.action_dock_host.anchor_right = 0.62
	host.action_dock_host.anchor_top = 0.50
	host.action_dock_host.anchor_bottom = 0.985
	host.action_dock_host.clip_contents = true
	# Keep the decision layer on its own canvas so focused content can never
	# enlarge either the dashboard workspace or the root interface.
	host.action_canvas = CanvasLayer.new()
	host.action_canvas.layer = 1
	host.add_child(host.action_canvas)
	host.action_canvas.add_child(host.action_dock_host)

	host.action_dock = PanelContainer.new()
	host.action_dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dock_style = host.game_screen_controller._panel_style(Color("0b100ddf"), 0, 2, Color.TRANSPARENT, 22, 16)
	dock_style.border_width_left = 2
	dock_style.border_color = Color(host.COLORS.accent, 0.68)
	host.action_dock.add_theme_stylebox_override("panel", dock_style)
	host.action_dock_host.add_child(host.action_dock)
	var action_content_host = Control.new()
	action_content_host.clip_contents = true
	action_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.action_dock.add_child(action_content_host)
	var decision_column = VBoxContainer.new()
	decision_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	decision_column.grow_vertical = Control.GROW_DIRECTION_END
	decision_column.add_theme_constant_override("separation", 7)
	action_content_host.add_child(decision_column)
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	decision_column.add_child(title_row)
	host.action_dock_title = Label.new()
	host.action_dock_title.text = "眼前"
	host.action_dock_title.add_theme_font_override("font", host.display_font)
	host.action_dock_title.add_theme_font_size_override("font_size", 22)
	host.action_dock_title.add_theme_color_override("font_color", host.COLORS.accent)
	host.action_dock_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(host.action_dock_title)
	host.objective_label = Label.new()
	host.objective_label.text = "风声未定，先看清眼前的人和路。"
	host.objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.objective_label.max_lines_visible = 2
	host.objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	host.objective_label.add_theme_font_size_override("font_size", host.TYPE_SCALE.meta)
	host.objective_label.add_theme_constant_override("line_spacing", 3)
	host.objective_label.add_theme_color_override("font_color", host.COLORS.muted)
	decision_column.add_child(host.objective_label)
	host.location_detail_box = VBoxContainer.new()
	host.location_detail_box.add_theme_constant_override("separation", 2)
	decision_column.add_child(host.location_detail_box)
	host.stage_people_box = HFlowContainer.new()
	host.stage_people_box.add_theme_constant_override("h_separation", 7)
	host.stage_people_box.add_theme_constant_override("v_separation", 5)
	decision_column.add_child(host.stage_people_box)
	var rule = HSeparator.new()
	rule.modulate = Color(host.COLORS.accent, 0.24)
	decision_column.add_child(rule)
	host.overview_actions_box = VBoxContainer.new()
	host.overview_actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.overview_actions_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.overview_actions_box.add_theme_constant_override("separation", 5)
	decision_column.add_child(host.overview_actions_box)

	host.actor_focus_workspace = HBoxContainer.new()
	host.actor_focus_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.actor_focus_workspace.add_theme_constant_override("separation", 14)
	decision_column.add_child(host.actor_focus_workspace)
	var message_panel = PanelContainer.new()
	message_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_panel.size_flags_stretch_ratio = 0.38
	message_panel.add_theme_stylebox_override("panel", host.game_screen_controller._panel_style(Color(host.COLORS.panel_alt, 0.24), 0, 1, Color.TRANSPARENT, 8, 8))
	host.actor_focus_workspace.add_child(message_panel)
	host.actor_focus_message_list = VBoxContainer.new()
	host.actor_focus_message_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.actor_focus_message_list.add_theme_constant_override("separation", 6)
	message_panel.add_child(host.actor_focus_message_list)
	host.actor_focus_detail_scroll = ScrollContainer.new()
	host.actor_focus_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.actor_focus_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.actor_focus_detail_scroll.size_flags_stretch_ratio = 0.62
	host.actor_focus_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.actor_focus_workspace.add_child(host.actor_focus_detail_scroll)
	host.actor_focus_detail_box = VBoxContainer.new()
	host.actor_focus_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.actor_focus_detail_box.add_theme_constant_override("separation", 9)
	host.actor_focus_detail_scroll.add_child(host.actor_focus_detail_box)

	host.fact_action_scroll = ScrollContainer.new()
	host.fact_action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.fact_action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	decision_column.add_child(host.fact_action_scroll)
	host.actions_box = VBoxContainer.new()
	host.actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.actions_box.add_theme_constant_override("separation", 7)
	host.fact_action_scroll.add_child(host.actions_box)

	host.actor_focus_footer = HBoxContainer.new()
	host.actor_focus_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.actor_focus_footer.add_theme_constant_override("separation", 12)
	decision_column.add_child(host.actor_focus_footer)
	host.overview_actions_box.hide()
	host.actor_focus_workspace.hide()
	host.fact_action_scroll.hide()
	host.actor_focus_footer.hide()
	host.action_dock.hide()


func _build_world_stage(parent: VBoxContainer) -> void:
	var mode_row = HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	parent.add_child(mode_row)
	var mode_spacer = Control.new()
	mode_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_child(mode_spacer)
	var mode_switch = PanelContainer.new()
	mode_switch.add_theme_stylebox_override("panel", host.game_screen_controller._panel_style(Color(host.COLORS.panel_alt, 0.52), 1, 5, Color(host.COLORS.line, 0.74), 2, 2))
	mode_row.add_child(mode_switch)
	var mode_buttons = HBoxContainer.new()
	mode_buttons.add_theme_constant_override("separation", 0)
	mode_switch.add_child(mode_buttons)
	host.location_mode_button = host.game_screen_controller._mode_button("◉ 当前地点", host.game_screen_controller._set_visual_mode.bind("location"))
	host.location_mode_button.custom_minimum_size = Vector2(118, 34)
	mode_buttons.add_child(host.location_mode_button)
	host.map_mode_button = host.game_screen_controller._mode_button("◇ 地图", host.game_screen_controller._set_visual_mode.bind("map"))
	host.map_mode_button.custom_minimum_size = Vector2(82, 34)
	mode_buttons.add_child(host.map_mode_button)

	var stage_frame = PanelContainer.new()
	stage_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_frame.size_flags_stretch_ratio = 1.0
	stage_frame.custom_minimum_size.y = 560
	stage_frame.add_theme_stylebox_override("panel", host.game_screen_controller._panel_style(Color(host.COLORS.panel, 0.66), 0, 2, Color.TRANSPARENT, 8, 8))
	parent.add_child(stage_frame)
	host.visual_stack = Control.new()
	host.visual_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.visual_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_frame.add_child(host.visual_stack)

	host.map_panel = HBoxContainer.new()
	host.map_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.map_panel.add_theme_constant_override("separation", 0)
	host.visual_stack.add_child(host.map_panel)
	host.world_map_view = host.WorldMapViewScript.new()
	host.world_map_view.presentation_registry = host.presentation_registry
	host.world_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.world_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.world_map_view.size_flags_stretch_ratio = 1.0
	host.world_map_view.location_selected.connect(host.game_screen_controller._on_map_location_selected)
	host.world_map_view.travel_day_changed.connect(host.presentation_controller._on_travel_day_changed)
	host.map_panel.add_child(host.world_map_view)
	var map_detail_frame = PanelContainer.new()
	map_detail_frame.custom_minimum_size.x = 310
	map_detail_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var map_detail_style = host.game_screen_controller._panel_style(Color("08100be8"), 0, 0, Color.TRANSPARENT, 18, 18)
	map_detail_style.border_width_left = 1
	map_detail_style.border_color = Color(host.COLORS.accent, 0.42)
	map_detail_frame.add_theme_stylebox_override("panel", map_detail_style)
	host.map_panel.add_child(map_detail_frame)
	host.map_detail_box = VBoxContainer.new()
	host.map_detail_box.custom_minimum_size = Vector2(274, 88)
	host.map_detail_box.add_theme_constant_override("separation", 9)
	map_detail_frame.add_child(host.map_detail_box)

	host.location_panel = VBoxContainer.new()
	host.location_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.location_panel.add_theme_constant_override("separation", 8)
	host.visual_stack.add_child(host.location_panel)
	var stage_canvas = Control.new()
	stage_canvas.custom_minimum_size = Vector2(640, 320)
	stage_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_canvas.clip_contents = true
	host.location_panel.add_child(stage_canvas)
	host.location_stage = host.LocationStageScript.new()
	host.location_stage.registry = host.presentation_registry
	host.location_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_canvas.add_child(host.location_stage)
	host.actor_portrait_frame = PanelContainer.new()
	host.actor_portrait_frame.anchor_left = 0.56
	host.actor_portrait_frame.anchor_right = 0.965
	host.actor_portrait_frame.anchor_top = 0.005
	host.actor_portrait_frame.anchor_bottom = 1.02
	host.actor_portrait_frame.add_theme_stylebox_override("panel", host.game_screen_controller._panel_style(Color("080b0966"), 0, 0, Color.TRANSPARENT, 0, 0))
	host.actor_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_canvas.add_child(host.actor_portrait_frame)
	var portrait_stack = Control.new()
	portrait_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.actor_portrait_frame.add_child(portrait_stack)
	host.actor_portrait = TextureRect.new()
	host.actor_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.actor_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.actor_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.actor_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait_shader = Shader.new()
	portrait_shader.code = "shader_type canvas_item; void fragment(){ vec4 c = texture(TEXTURE, UV); float l = smoothstep(0.0, 0.28, UV.x); float r = 1.0 - smoothstep(0.92, 1.0, UV.x); float b = 1.0 - smoothstep(0.94, 1.0, UV.y); COLOR = vec4(c.rgb, c.a * l * r * b); }"
	var portrait_material = ShaderMaterial.new()
	portrait_material.shader = portrait_shader
	host.actor_portrait.material = portrait_material
	portrait_stack.add_child(host.actor_portrait)
	var portrait_caption = PanelContainer.new()
	portrait_caption.anchor_left = 0.18
	portrait_caption.anchor_right = 0.94
	portrait_caption.anchor_top = 0.79
	portrait_caption.anchor_bottom = 0.96
	portrait_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption_style = host.game_screen_controller._panel_style(Color("070b08a6"), 0, 0, Color.TRANSPARENT, 14, 8)
	caption_style.border_width_left = 1
	caption_style.border_color = Color(host.COLORS.accent, 0.48)
	portrait_caption.add_theme_stylebox_override("panel", caption_style)
	portrait_stack.add_child(portrait_caption)
	var portrait_caption_content = VBoxContainer.new()
	portrait_caption_content.add_theme_constant_override("separation", 2)
	portrait_caption.add_child(portrait_caption_content)
	host.actor_portrait_name = host.game_screen_controller._text(portrait_caption_content, "", false, 17)
	host.actor_portrait_name.add_theme_color_override("font_color", host.COLORS.accent)
	host.actor_portrait_meta = host.game_screen_controller._text(portrait_caption_content, "", true, 12)
	host.actor_portrait_frame.hide()
	host.game_screen_controller._set_visual_mode("map")


func _build_footer() -> void:
	host.footer_label = Label.new()
	host.footer_label.text = ""
	host.footer_label.add_theme_color_override("font_color", host.COLORS.muted)
	host.footer_label.add_theme_font_override("font", host.medium_font)
	host.footer_label.add_theme_font_size_override("font_size", host.TYPE_SCALE.meta)
	host.footer_label.custom_minimum_size.y = 20
	host.game_layer.add_child(host.footer_label)


func _header_value(parent: Container, caption: String) -> Label:
	var group = VBoxContainer.new()
	var small = Label.new()
	small.text = caption
	small.add_theme_font_override("font", host.medium_font)
	small.add_theme_font_size_override("font_size", host.TYPE_SCALE.meta)
	small.add_theme_color_override("font_color", host.COLORS.muted)
	group.add_child(small)
	var value = Label.new()
	value.text = "—"
	value.add_theme_font_override("font", host.medium_font)
	value.add_theme_font_size_override("font_size", host.TYPE_SCALE.metric)
	value.add_theme_color_override("font_color", host.COLORS.ink)
	group.add_child(value)
	parent.add_child(group)
	return value


func _hud_label(parent: Container, color: Color) -> Label:
	var value = Label.new()
	value.text = "—"
	value.add_theme_font_override("font", host.medium_font)
	value.add_theme_font_size_override("font_size", host.TYPE_SCALE.compact)
	value.add_theme_color_override("font_color", color)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(value)
	return value


func _zone(parent: VBoxContainer, title_text: String, ratio: float) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.add_theme_stylebox_override("panel", host.game_screen_controller._panel_style(Color(host.COLORS.panel, 0.62), 0, 2, Color.TRANSPARENT, 16, 14))
	parent.add_child(panel)
	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var title = Label.new()
	title.text = title_text
	title.add_theme_font_override("font", host.display_font)
	title.add_theme_font_size_override("font_size", host.TYPE_SCALE.section)
	title.add_theme_color_override("font_color", host.COLORS.accent)
	outer.add_child(title)
	var rule = HSeparator.new()
	rule.modulate = Color(host.COLORS.accent, 0.35)
	outer.add_child(rule)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	return box


func _panel_style(color: Color, border: int, radius: int, border_color := Color("344039"), horizontal_margin := 16, vertical_margin := 14) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal_margin
	style.content_margin_right = horizontal_margin
	style.content_margin_top = vertical_margin
	style.content_margin_bottom = vertical_margin
	return style


func _tab_style(color: Color, border_color: Color) -> StyleBoxFlat:
	var style = host.game_screen_controller._panel_style(color, 0, 5, border_color, 12, 8)
	style.border_width_bottom = 2 if border_color.a > 0.0 else 0
	return style


func _input_style(color: Color, border_color: Color) -> StyleBoxFlat:
	return host.game_screen_controller._panel_style(color, 1, 6, border_color, 16, 11)


func _button(text_value: String, callback: Callable, secondary: bool) -> Button:
	var button = Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 46
	button.add_theme_font_override("font", host.medium_font)
	button.add_theme_font_size_override("font_size", host.TYPE_SCALE.button)
	if secondary:
		button.add_theme_color_override("font_color", host.COLORS.ink)
		button.add_theme_color_override("font_hover_color", host.COLORS.ink)
		button.add_theme_color_override("font_pressed_color", host.COLORS.accent)
		button.add_theme_stylebox_override("normal", host.game_screen_controller._panel_style(host.COLORS.panel_alt, 1, 6, host.COLORS.line, 14, 10))
		button.add_theme_stylebox_override("hover", host.game_screen_controller._panel_style(host.COLORS.panel_hover, 1, 6, host.COLORS.accent_pressed, 14, 10))
		button.add_theme_stylebox_override("pressed", host.game_screen_controller._panel_style(host.COLORS.bg_lift, 1, 6, host.COLORS.accent, 14, 11))
	else:
		button.add_theme_color_override("font_color", host.COLORS.accent_ink)
		button.add_theme_color_override("font_hover_color", host.COLORS.accent_ink)
		button.add_theme_color_override("font_pressed_color", host.COLORS.accent_ink)
		button.add_theme_stylebox_override("normal", host.game_screen_controller._panel_style(host.COLORS.accent, 0, 6, host.COLORS.accent, 14, 11))
		button.add_theme_stylebox_override("hover", host.game_screen_controller._panel_style(host.COLORS.accent_hover, 0, 6, host.COLORS.accent_hover, 14, 10))
		button.add_theme_stylebox_override("pressed", host.game_screen_controller._panel_style(host.COLORS.accent_pressed, 0, 6, host.COLORS.accent_pressed, 14, 12))
	button.add_theme_stylebox_override("focus", host.game_screen_controller._panel_style(Color.TRANSPARENT, 2, 7, host.COLORS.accent_hover, 12, 8))
	button.add_theme_stylebox_override("disabled", host.game_screen_controller._panel_style(Color(host.COLORS.panel_alt, 0.58), 1, 6, Color(host.COLORS.line, 0.5), 14, 10))
	button.pressed.connect(callback)
	return button


func _utility_button(text_value: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 36
	button.add_theme_font_override("font", host.medium_font)
	button.add_theme_font_size_override("font_size", host.TYPE_SCALE.detail)
	button.add_theme_color_override("font_color", host.COLORS.muted)
	button.add_theme_color_override("font_hover_color", host.COLORS.ink)
	button.add_theme_color_override("font_pressed_color", host.COLORS.accent)
	button.add_theme_stylebox_override("normal", host.game_screen_controller._panel_style(Color.TRANSPARENT, 0, 2, Color.TRANSPARENT, 10, 7))
	button.add_theme_stylebox_override("hover", host.game_screen_controller._panel_style(Color(host.COLORS.panel_alt, 0.72), 0, 2, Color.TRANSPARENT, 10, 7))
	button.add_theme_stylebox_override("pressed", host.game_screen_controller._panel_style(Color(host.COLORS.bg_lift, 0.92), 0, 2, Color.TRANSPARENT, 10, 8))
	button.add_theme_stylebox_override("focus", host.game_screen_controller._panel_style(Color.TRANSPARENT, 1, 2, host.COLORS.accent, 9, 6))
	button.add_theme_stylebox_override("disabled", host.game_screen_controller._panel_style(Color.TRANSPARENT, 0, 2, Color.TRANSPARENT, 10, 7))
	button.pressed.connect(callback)
	return button


func _mode_button(text_value: String, callback: Callable) -> Button:
	var button = host.game_screen_controller._utility_button(text_value, callback)
	button.add_theme_font_size_override("font_size", host.TYPE_SCALE.compact)
	button.custom_minimum_size.y = 38
	return button


func _style_mode_state(button: Button, active: bool) -> void:
	button.add_theme_color_override("font_color", host.COLORS.accent if active else host.COLORS.muted)
	button.add_theme_color_override("font_hover_color", host.COLORS.ink)
	var normal = host.game_screen_controller._panel_style(Color(host.COLORS.bg_lift, 0.92) if active else Color.TRANSPARENT, 1 if active else 0, 4, Color(host.COLORS.accent, 0.62), 11, 6)
	button.add_theme_stylebox_override("normal", normal)


func _action_button(text_value: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text_value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 42
	button.add_theme_font_override("font", host.medium_font)
	button.add_theme_font_size_override("font_size", host.TYPE_SCALE.button)
	button.add_theme_color_override("font_color", host.COLORS.ink)
	button.add_theme_color_override("font_hover_color", host.COLORS.ink)
	button.add_theme_color_override("font_pressed_color", host.COLORS.accent)
	var normal = host.game_screen_controller._panel_style(Color(host.COLORS.panel_alt, 0.38), 0, 2, Color.TRANSPARENT, 14, 9)
	normal.border_width_left = 2
	normal.border_color = Color(host.COLORS.line, 0.84)
	var hover = host.game_screen_controller._panel_style(Color(host.COLORS.panel_hover, 0.78), 0, 2, Color.TRANSPARENT, 14, 9)
	hover.border_width_left = 2
	hover.border_color = host.COLORS.accent
	var pressed = host.game_screen_controller._panel_style(Color(host.COLORS.bg_lift, 0.92), 0, 2, Color.TRANSPARENT, 14, 10)
	pressed.border_width_left = 2
	pressed.border_color = host.COLORS.accent_pressed
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", host.game_screen_controller._panel_style(Color.TRANSPARENT, 1, 2, host.COLORS.accent_hover, 12, 7))
	button.add_theme_stylebox_override("disabled", host.game_screen_controller._panel_style(Color(host.COLORS.panel_alt, 0.26), 0, 2, Color.TRANSPARENT, 14, 9))
	button.pressed.connect(callback)
	return button


func _category_button(text_value: String, category: String, active: bool) -> Button:
	var marker = "当前" if active else "展开"
	var button = host.game_screen_controller._utility_button("%s　·　%s" % [text_value, marker], host.action_panel_controller._set_action_category.bind(category))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 34
	button.add_theme_color_override("font_color", host.COLORS.accent if active else host.COLORS.muted)
	return button


func _ornate_button(text_value: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text_value
	button.add_theme_font_override("font", host.display_font)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("e5c47d"))
	button.add_theme_color_override("font_hover_color", host.COLORS.ink)
	button.add_theme_color_override("font_pressed_color", host.COLORS.accent_pressed)
	button.add_theme_stylebox_override("normal", host.game_screen_controller._panel_style(Color("080b09b8"), 0, 0, Color.TRANSPARENT, 20, 14))
	button.add_theme_stylebox_override("hover", host.game_screen_controller._panel_style(Color("171c16e6"), 0, 0, Color.TRANSPARENT, 20, 14))
	button.add_theme_stylebox_override("pressed", host.game_screen_controller._panel_style(Color("050706f2"), 0, 0, Color.TRANSPARENT, 20, 15))
	button.add_theme_stylebox_override("focus", host.game_screen_controller._panel_style(Color.TRANSPARENT, 1, 2, host.COLORS.accent_hover, 18, 12))
	var frame = TextureRect.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.texture = host.DecisionFrameTexture
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.modulate = Color(1, 1, 1, 0.90)
	button.add_child(frame)
	button.move_child(frame, 0)
	button.pressed.connect(callback)
	return button


func _style_menu_button(button: MenuButton) -> void:
	button.add_theme_font_override("font", host.medium_font)
	button.add_theme_font_size_override("font_size", host.TYPE_SCALE.button)
	button.add_theme_color_override("font_color", host.COLORS.ink)
	button.add_theme_color_override("font_hover_color", host.COLORS.ink)
	button.add_theme_color_override("font_pressed_color", host.COLORS.accent)
	var normal = host.game_screen_controller._panel_style(Color(host.COLORS.panel_alt, 0.38), 0, 2, Color.TRANSPARENT, 14, 9)
	normal.border_width_left = 2
	normal.border_color = Color(host.COLORS.line, 0.84)
	var hover = host.game_screen_controller._panel_style(Color(host.COLORS.panel_hover, 0.78), 0, 2, Color.TRANSPARENT, 14, 9)
	hover.border_width_left = 2
	hover.border_color = host.COLORS.accent
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", host.game_screen_controller._panel_style(Color.TRANSPARENT, 1, 2, host.COLORS.accent_hover, 12, 7))
	var popup = button.get_popup()
	popup.add_theme_color_override("font_color", host.COLORS.ink)
	popup.add_theme_color_override("font_hover_color", host.COLORS.accent_ink)
	popup.add_theme_stylebox_override("panel", host.game_screen_controller._panel_style(host.COLORS.panel_alt, 1, 7, host.COLORS.line, 8, 8))
	popup.add_theme_stylebox_override("hover", host.game_screen_controller._panel_style(host.COLORS.accent, 0, 4, host.COLORS.accent, 8, 6))


func _text(parent: Container, value: String, muted := false, size := 16) -> Label:
	var label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if size >= 24:
		label.add_theme_font_override("font", host.display_font)
	elif size >= 17 or size <= host.TYPE_SCALE.meta:
		label.add_theme_font_override("font", host.medium_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", host.COLORS.muted if muted else host.COLORS.ink)
	if size <= host.TYPE_SCALE.body:
		label.add_theme_constant_override("line_spacing", 4)
	elif size < 24:
		label.add_theme_constant_override("line_spacing", 3)
	parent.add_child(label)
	return label


func _clear(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()


func _set_buttons_disabled(node: Node, disabled: bool) -> void:
	if node is BaseButton:
		node.disabled = disabled
		if disabled:
			# 全局请求中的按钮只是暂时忙碌，不应看起来像永久不可用。
			node.add_theme_color_override("font_disabled_color", Color(host.COLORS.ink, 0.76))
		else:
			node.remove_theme_color_override("font_disabled_color")
	for child in node.get_children():
		host.game_screen_controller._set_buttons_disabled(child, disabled)


func _render_view() -> void:
	var player: Dictionary = host.current_view.get("player", {})
	var location: Dictionary = host.current_view.get("location", {})
	var day = int(host.current_view.get("day", 0))
	host.day_label.text = host.game_screen_controller._header_day(day, int(host.current_view.get("duration", 0)))
	host.place_label.text = host.game_screen_controller._header_place(str(location.get("name", "未知")))
	host.phase_label.text = host.game_screen_controller._header_phase_label(host.game_screen_controller._phase_display(str(host.current_view.get("phase", ""))))
	var travel = host.current_view.get("travel", null)
	host.footer_label.add_theme_color_override("font_color", host.COLORS.muted)
	var available_actions = host.current_view.get("available_actions", [])
	if not available_actions is Array:
		available_actions = []
	host.available_actions_cache = available_actions
	var known_actors: Array = host.current_view.get("known_actors", [])
	var known_facts: Array = host.current_view.get("known_facts", [])
	var guidance: Array = host.current_view.get("guidance", [])
	host.action_panel_controller._reconcile_action_focus(known_actors, known_facts)
	var location_id = str(location.get("id", ""))
	if host.rendered_location_id != location_id:
		host.selected_map_location_id = location_id
		host.rendered_location_id = location_id
		host.stage_actor_id = ""
		host.stage_actor_name = ""
	host.game_screen_controller._reconcile_stage_actor(known_actors)
	host.timing_label.text = host.game_screen_controller._known_timing(known_facts)
	host.objective_label.text = str(guidance[0]) if not guidance.is_empty() else "风声未定，先看清眼前的人和路。"
	host.game_screen_controller._render_player(player)
	host.journal_panel_controller._render_clues(known_facts, host.available_actions_cache)
	host.journal_panel_controller._render_scene(host.current_view.get("recent_events", []), guidance.slice(1), travel, host.current_view.get("last_turn", null), host.current_view.get("causal_threads", []), str(player.get("name", "旅人")))
	host.journal_panel_controller._render_people(known_actors, host.available_actions_cache)
	host.journal_panel_controller._render_travel_readiness(travel, host.current_view.get("preparation", {}))
	host.journal_panel_controller._render_journal_tab_states(known_facts, known_actors, travel, host.current_view.get("last_turn", null), host.available_actions_cache)
	host.action_panel_controller._render_actions(host.available_actions_cache)
	host.game_screen_controller._render_world_map(host.current_view.get("world_map", {}), location, host.available_actions_cache)
	host.game_screen_controller._render_location_stage(location, known_actors, host.available_actions_cache)
	host.game_screen_controller._sync_action_canvas_visibility()
	var ending = host.current_view.get("ending", null)
	if bool(host.current_view.get("resolved", false)) or bool(host.current_view.get("ended", false)) or ending is Dictionary:
		host.presentation_controller._render_ending(ending if ending is Dictionary else {})


func _set_visual_mode(mode: String) -> void:
	var previous_mode = host.visual_mode
	host.visual_mode = mode
	if mode == "map" and (host.focused_actor_id != "" or host.focused_fact_id != ""):
		host.action_panel_controller._reset_action_focus()
		if host.actions_box:
			host.action_panel_controller._render_actions(host.available_actions_cache)
	if host.map_panel:
		host.map_panel.visible = mode == "map"
	if host.location_panel:
		host.location_panel.visible = mode == "location"
	host.game_screen_controller._sync_action_canvas_visibility()
	if host.map_mode_button:
		host.map_mode_button.text = "◇ 地图"
		host.map_mode_button.tooltip_text = "查看公开地点、路线与行程"
		host.game_screen_controller._style_mode_state(host.map_mode_button, mode == "map")
	if host.location_mode_button:
		host.location_mode_button.text = "◉ 当前地点"
		host.location_mode_button.tooltip_text = "返回当前位置、人物与行动"
		host.game_screen_controller._style_mode_state(host.location_mode_button, mode == "location")
	if mode == "location" and previous_mode != "location" and host.location_stage:
		host.location_stage.play_establish.call_deferred()
	if host.actions_box:
		host.action_panel_controller._render_actions(host.available_actions_cache)


func _sync_action_canvas_visibility() -> void:
	if not host.action_canvas or not host.action_dock:
		return
	var should_show = (
		host.game_layer
		and host.game_layer.visible
		and host.visual_mode == "location"
		and not host.start_layer.visible
		and not host.journal_layer.visible
		and not host.confirmation_layer.visible
		and not host.settings_layer.visible
		and not host.causal_layer.visible
		and not host.ending_layer.visible
		and not (host.cinematic_director and host.cinematic_director.active)
	)
	host.action_canvas.visible = should_show
	host.action_dock.visible = should_show


func _render_world_map(world_map, current_location: Dictionary, actions: Array) -> void:
	if not world_map is Dictionary:
		world_map = {}
	host.world_map_view.set_map(world_map, host.selected_map_location_id)
	host.game_screen_controller._render_map_detail(world_map, current_location, actions)


func _on_map_location_selected(location_id: String) -> void:
	host.selected_map_location_id = location_id
	host.game_screen_controller._render_map_detail(host.current_view.get("world_map", {}), host.current_view.get("location", {}), host.available_actions_cache)


func _render_map_detail(world_map: Dictionary, current_location: Dictionary, actions: Array) -> void:
	host.game_screen_controller._clear(host.map_detail_box)
	var map_title = str(host.scenario_presentation.get("world_title", host.current_view.get("title", "世界地图")))
	var eyebrow = host.game_screen_controller._text(host.map_detail_box, "%s · 立体路线沙盘" % map_title, true, 12)
	eyebrow.add_theme_color_override("font_color", host.COLORS.accent)
	var guidance = host.game_screen_controller._text(host.map_detail_box, "点击地点或发光路径，查看目的地、耗时与阻碍。", true, 12)
	guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var map_separator = HSeparator.new()
	map_separator.add_theme_color_override("separator", Color(host.COLORS.accent, 0.24))
	host.map_detail_box.add_child(map_separator)
	var selected = host.game_screen_controller._map_location(world_map.get("locations", []), host.selected_map_location_id)
	if selected.is_empty():
		host.game_screen_controller._text(host.map_detail_box, "选择地点查看路线", false, 18)
		return
	var title_line = host.game_screen_controller._text(host.map_detail_box, str(selected.get("name", "未知地点")), false, 22)
	title_line.add_theme_color_override("font_color", host.COLORS.accent if bool(selected.get("current", false)) else host.COLORS.ink)
	var place_state = "当前据点" if bool(selected.get("current", false)) else ("安全落脚点" if bool(selected.get("safe", false)) else "危险区域")
	var state_line = host.game_screen_controller._text(host.map_detail_box, place_state, false, 13)
	state_line.add_theme_color_override("font_color", host.COLORS.success if bool(selected.get("safe", false)) else host.COLORS.danger)
	host.game_screen_controller._text(host.map_detail_box, str(selected.get("description", "尚无公开地点资料")), true, 13)
	if bool(selected.get("contest", false)):
		var contest_line = host.game_screen_controller._text(host.map_detail_box, "核心目标 · %s" % host.scenario_presentation.get("objective", "目标将在这里落定"), false, 13)
		contest_line.add_theme_color_override("font_color", host.COLORS.accent)
	host.game_screen_controller._render_map_actor_plans(host.map_detail_box, world_map.get("actors", []), host.selected_map_location_id)
	if bool(selected.get("current", false)):
		host.journal_panel_controller._render_route_progresses(host.map_detail_box, host.current_view.get("route_progresses", []), true)
		var hint = host.game_screen_controller._text(host.map_detail_box, "沙盘上的金色道路当前可以通行。", true, 12)
		hint.add_theme_color_override("font_color", host.COLORS.muted)
		var enter_button = host.game_screen_controller._utility_button("回到眼前", host.game_screen_controller._set_visual_mode.bind("location"))
		enter_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		enter_button.custom_minimum_size.y = 42
		host.map_detail_box.add_child(enter_button)
		return
	var route = host.game_screen_controller._current_map_route(world_map.get("routes", []), str(current_location.get("id", "")), host.selected_map_location_id)
	if route.is_empty():
		host.game_screen_controller._text(host.map_detail_box, "这里不与当前位置直接相连，需要从相邻地点转进。", true, 13)
		return
	var route_status = str(route.get("status", "known"))
	var route_labels = {"available": "可以通行", "blocked": "道路受阻", "known": "尚未打通"}
	var route_line = host.game_screen_controller._text(host.map_detail_box, "道路状态 · %s" % route_labels.get(route_status, "尚不明确"), false, 13)
	route_line.add_theme_color_override("font_color", host.COLORS.accent if route_status == "available" else (host.COLORS.danger if route_status == "blocked" else host.COLORS.muted))
	host.game_screen_controller._text(host.map_detail_box, "耗时 %d 日 · 危险 %d" % [int(route.get("duration", 1)), int(route.get("danger", 0))], true, 13)
	if route_status == "available":
		var action = host.game_screen_controller._action_by_id(actions, str(route.get("action_id", "")))
		if not action.is_empty():
			var move_button = host.game_screen_controller._button("前往%s · %d 日" % [selected.get("name", "目的地"), int(route.get("duration", 1))], host.action_panel_controller._consider_action.bind(action), false)
			move_button.custom_minimum_size.y = 46
			move_button.tooltip_text = "危险 %d · 途中局势会继续推进" % int(route.get("danger", 0))
			host.map_detail_box.add_child(move_button)
	elif route_status == "blocked":
		var blockers = host.action_panel_controller._joined_action_values(route.get("blockers", []))
		var blocked_line = host.game_screen_controller._text(host.map_detail_box, "路线受阻 · %s" % blockers, false, 13)
		blocked_line.add_theme_color_override("font_color", host.COLORS.danger)


func _render_map_actor_plans(parent: VBoxContainer, actor_plans, location_id: String) -> void:
	var visible: Array = []
	for plan in actor_plans:
		if str(plan.get("location_id", "")) == location_id:
			visible.append(plan)
	if visible.is_empty():
		return
	var separator = HSeparator.new()
	separator.modulate = Color(host.COLORS.accent, 0.28)
	parent.add_child(separator)
	var heading = host.game_screen_controller._text(parent, "此地人物动向 · %d" % visible.size(), true, 13)
	heading.add_theme_color_override("font_color", host.COLORS.accent)
	for plan in visible:
		var status_line = host.game_screen_controller._text(parent, "%s · %s" % [plan.get("name", "无名者"), plan.get("status", "观望")], false, 14)
		status_line.add_theme_color_override("font_color", host.COLORS.success if str(plan.get("status", "")) == "行动中" else host.COLORS.ink)
		host.game_screen_controller._text(parent, str(plan.get("plan", "观察局势")), true, 13)
		host.game_screen_controller._text(parent, "缘由 · %s" % plan.get("reason", "尚未公开"), true, 12)
		if str(plan.get("destination_name", "")) != "":
			host.game_screen_controller._text(parent, "去向 · %s · 预计第 %d 日" % [plan.get("destination_name", "未知地点"), int(plan.get("expected_day", 0))], true, 12)
		if bool(plan.get("changed_by_player", false)):
			var changed = host.game_screen_controller._text(parent, "因你改变 · 原本%s" % plan.get("previous_plan", "另有安排"), true, 12)
			changed.add_theme_color_override("font_color", host.COLORS.accent)


func _render_location_stage(location: Dictionary, actors: Array, actions: Array) -> void:
	host.location_stage.set_location(location)
	host.audio_director.set_scene(str(location.get("scene_key", "")))
	host.game_screen_controller._render_actor_portrait(actors)
	host.game_screen_controller._clear(host.location_detail_box)
	var phase_marker: String = str(host.presentation_registry.location_stage_label(str(location.get("scene_key", ""))))
	var place_title = "%s" % ["安稳" if bool(location.get("safe", false)) else "险地"]
	if phase_marker != "":
		place_title += " · %s" % phase_marker
	if not actors.is_empty():
		place_title += " · 在场 %d 人" % actors.size()
	var place_line = host.game_screen_controller._text(host.location_detail_box, place_title, false, 13)
	place_line.add_theme_color_override("font_color", host.COLORS.accent)
	host.game_screen_controller._text(host.location_detail_box, str(location.get("atmosphere", location.get("description", ""))), true, 13)
	host.game_screen_controller._render_stage_people(actors, actions)


func _render_stage_people(actors: Array, actions: Array) -> void:
	host.game_screen_controller._clear(host.stage_people_box)
	if actors.is_empty():
		host.game_screen_controller._text(host.stage_people_box, "此地暂时无人可交涉", true, 13)
		return
	for index in actors.size():
		var actor: Dictionary = actors[index]
		var actor_id = str(actor.get("id", ""))
		var actor_name = str(actor.get("name", "无名者"))
		var clue_count = host.action_panel_controller._count_tell_actions(actions, actor_id, "")
		var selected = actor_id == host.stage_actor_id
		var button_text = ("◆ " if selected else "") + actor_name
		if clue_count > 0:
			button_text += " · %d 条" % clue_count
		var button = host.game_screen_controller._action_button(button_text, host.game_screen_controller._focus_actor_from_stage.bind(actor_id, actor_name))
		button.custom_minimum_size = Vector2(132, 36)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = "%s\n%s" % [actor.get("public_role", "可交谈人物"), actor.get("public_profile", "")]
		if selected:
			var profile: ActorVisualProfile = host.presentation_registry.actor_profile(actor_id)
			var actor_accent = profile.accent_color if profile else host.COLORS.accent
			button.add_theme_color_override("font_color", host.COLORS.ink)
			button.add_theme_stylebox_override("normal", host.game_screen_controller._panel_style(host.COLORS.panel_hover, 1, 6, actor_accent.lerp(host.COLORS.accent, 0.35), 12, 7))
		host.stage_people_box.add_child(button)


func _render_actor_portrait(actors: Array) -> void:
	host.actor_portrait_frame.hide()
	host.actor_portrait.texture = null
	var actor = host.game_screen_controller._selected_stage_actor(actors)
	if actor.is_empty():
		return
	var actor_id = str(actor.get("id", ""))
	host.game_screen_controller._show_actor_portrait(actor, str(host.actor_expression_by_id.get(actor_id, "neutral")))


func _focus_portrait(actor_id: String, expression_override := "") -> void:
	var actor = host.game_screen_controller._actor_by_id(host.current_view.get("known_actors", []), actor_id)
	if actor.is_empty():
		actor = {"id": actor_id, "name": host.stage_actor_name, "public_role": "可交谈人物"}
	host.stage_actor_id = actor_id
	host.stage_actor_name = str(actor.get("name", host.stage_actor_name))
	var expression = expression_override
	if expression == "":
		expression = str(host.actor_expression_by_id.get(actor_id, "alert"))
	host.game_screen_controller._show_actor_portrait(actor, expression)


func _show_actor_portrait(actor: Dictionary, expression: String) -> void:
	var actor_id = str(actor.get("id", ""))
	var profile: ActorVisualProfile = host.presentation_registry.actor_profile(actor_id)
	if profile == null or profile.neutral == null:
		return
	var portrait_texture = profile.portrait(expression)
	if portrait_texture == null:
		return
	host.actor_portrait.texture = portrait_texture
	host.actor_portrait_name.text = str(actor.get("name", "无名者"))
	var role = str(actor.get("public_role", "可交谈人物"))
	var faction = str(actor.get("faction", ""))
	var expression_names = {"neutral": "平静", "alert": "警觉", "troubled": "权衡中", "decisive": "已有决断"}
	var meta_parts: Array[String] = [role]
	if faction != "":
		meta_parts.append(faction)
	if expression != "neutral":
		meta_parts.append(str(expression_names.get(expression, expression)))
	host.actor_portrait_meta.text = " · ".join(meta_parts)
	host.actor_portrait_frame.tooltip_text = "%s · %s" % [host.actor_portrait_name.text, role]
	host.actor_portrait_frame.add_theme_stylebox_override("panel", host.game_screen_controller._panel_style(Color.TRANSPARENT, 0, 0, Color.TRANSPARENT, 0, 0))
	host.actor_portrait_frame.show()
	var target_modulate = Color.WHITE
	match expression:
		"alert":
			target_modulate = Color("f0eadf")
		"troubled":
			target_modulate = Color("cbd3cb")
		"decisive":
			target_modulate = Color("fff0c8")
	host.actor_portrait.modulate = Color(target_modulate, 0.25)
	host.actor_portrait.scale = Vector2(0.985, 0.985)
	var portrait_tween = host.create_tween().set_parallel(true)
	portrait_tween.tween_property(host.actor_portrait, "modulate", target_modulate, 0.28)
	portrait_tween.tween_property(host.actor_portrait, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _selected_stage_actor(actors: Array) -> Dictionary:
	var selected = host.game_screen_controller._actor_by_id(actors, host.stage_actor_id)
	if not selected.is_empty() and host.presentation_registry.has_actor(host.stage_actor_id):
		return selected
	for actor in actors:
		var actor_id = str(actor.get("id", ""))
		if host.presentation_registry.has_actor(actor_id):
			host.stage_actor_id = actor_id
			host.stage_actor_name = str(actor.get("name", "无名者"))
			return actor
	return {}


func _actor_by_id(actors, actor_id: String) -> Dictionary:
	if not actors is Array:
		return {}
	for actor in actors:
		if str(actor.get("id", "")) == actor_id:
			return actor
	return {}


func _actor_id_by_name(actor_name: String) -> String:
	for actor in host.current_view.get("known_actors", []):
		if str(actor.get("name", "")) == actor_name:
			return str(actor.get("id", ""))
	return ""


func _reconcile_stage_actor(actors: Array) -> void:
	if host.stage_actor_id != "" and not host.game_screen_controller._actor_by_id(actors, host.stage_actor_id).is_empty():
		return
	host.stage_actor_id = ""
	host.stage_actor_name = ""
	host.game_screen_controller._selected_stage_actor(actors)
	host.actor_portrait_frame.pivot_offset = host.actor_portrait_frame.size * 0.5
	host.actor_portrait_frame.scale = Vector2(0.965, 0.965)
	host.actor_portrait_frame.modulate = Color(1, 1, 1, 0.45)
	var tween = host.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(host.actor_portrait_frame, "scale", Vector2.ONE, 0.28)
	tween.tween_property(host.actor_portrait_frame, "modulate", Color.WHITE, 0.22)


func _focus_actor_from_stage(actor_id: String, actor_name: String) -> void:
	host.game_screen_controller._set_visual_mode("location")
	host.audio_director.play_ui()
	host.action_panel_controller._focus_actor_actions(actor_id, actor_name)


func _map_location(locations, location_id: String) -> Dictionary:
	if not locations is Array:
		return {}
	for location in locations:
		if str(location.get("id", "")) == location_id:
			return location
	return {}


func _current_map_route(routes, from_id: String, to_id: String) -> Dictionary:
	if not routes is Array:
		return {}
	for route in routes:
		if str(route.get("from_id", "")) == from_id and str(route.get("to_id", "")) == to_id:
			return route
	return {}


func _action_by_id(actions: Array, action_id: String) -> Dictionary:
	for action in actions:
		if str(action.get("id", "")) == action_id:
			return action
	return {}


func _render_player(player: Dictionary) -> void:
	var state = "空闲"
	if bool(player.get("busy", false)):
		state = "%s · 至第 %d 日" % [str(player.get("busy_action", "行动中")), int(player.get("busy_until", 0))]
	var resources: Dictionary = player.get("resources", {})
	var items: Array = player.get("items", [])
	host.player_summary_label.text = "%s · %s" % [player.get("name", "旅人"), state]
	host.game_screen_controller._clear(host.player_resources_box)
	var rendered_resources = {}
	for definition in host.scenario_presentation.get("resources", []):
		if not definition is Dictionary:
			continue
		var resource_id = str(definition.get("id", ""))
		if resource_id == "" or not resources.has(resource_id):
			continue
		rendered_resources[resource_id] = true
		var amount = float(resources.get(resource_id, 0))
		if bool(definition.get("hide_zero", false)) and amount == 0.0:
			continue
		host.game_screen_controller._add_status_chip(host.player_resources_box, "%s %s" % [definition.get("label", resource_id), host.game_screen_controller._compact_number(amount)], host.game_screen_controller._resource_emphasis_color(str(definition.get("emphasis", "normal"))))
	var extra_resource_ids: Array = resources.keys()
	extra_resource_ids.sort()
	for resource_id in extra_resource_ids:
		if not rendered_resources.has(resource_id):
			host.game_screen_controller._add_status_chip(host.player_resources_box, "%s %s" % [host.game_screen_controller._resource_label(str(resource_id)), host.game_screen_controller._compact_number(resources[resource_id])], host.COLORS.ink)
	var injury = int(player.get("injury", 0))
	if injury > 0:
		host.game_screen_controller._add_status_chip(host.player_resources_box, "伤势 %d" % injury, host.COLORS.danger)
	for index in range(mini(items.size(), 2)):
		var item: Dictionary = items[index]
		var item_name = str(item.get("name", "物品"))
		host.game_screen_controller._add_status_chip(host.player_resources_box, "%s ×%d" % [item_name, int(item.get("amount", 1))], host.COLORS.muted)
	if items.size() > 2:
		host.game_screen_controller._add_status_chip(host.player_resources_box, "行囊 %d 种" % items.size(), host.COLORS.muted)


func _compact_number(value: Variant) -> String:
	var numeric = float(value)
	if is_equal_approx(numeric, round(numeric)):
		return str(int(round(numeric)))
	return "%.1f" % numeric


func _resource_label(resource_id: String) -> String:
	for definition in host.scenario_presentation.get("resources", []):
		if definition is Dictionary and str(definition.get("id", "")) == resource_id:
			return str(definition.get("label", resource_id))
	return resource_id


func _resource_emphasis_color(emphasis: String) -> Color:
	match emphasis:
		"accent":
			return host.COLORS.accent
		"success":
			return host.COLORS.success
	return host.COLORS.ink


func _add_status_chip(parent: Container, value: String, color: Color) -> void:
	var panel = PanelContainer.new()
	var style = host.game_screen_controller._panel_style(Color(host.COLORS.panel_alt, 0.46), 0, 2, Color.TRANSPARENT, 9, 5)
	style.border_width_left = 2
	style.border_color = Color(color, 0.72)
	panel.add_theme_stylebox_override("panel", style)
	var label = Label.new()
	label.text = value
	label.add_theme_font_override("font", host.medium_font)
	label.add_theme_font_size_override("font_size", host.TYPE_SCALE.meta)
	label.add_theme_color_override("font_color", color)
	panel.add_child(label)
	parent.add_child(panel)


func _known_timing(clues: Array) -> String:
	var best: Dictionary = {}
	var configured_keyword: String = str(host._ui_text("timing_keyword"))
	for clue in clues:
		if configured_keyword != "" and configured_keyword not in str(clue.get("claim", "")):
			continue
		if best.is_empty() or int(clue.get("confidence", 0)) > int(best.get("confidence", 0)):
			best = clue
	if best.is_empty():
		return "尚未查明"
	var timing := str(best.get("claim", "未知"))
	var timing_start := timing.find("第")
	var timing_keyword: String = str(host._ui_text("timing_keyword"))
	var timing_end := timing.find(timing_keyword, timing_start + 1) if timing_start >= 0 and timing_keyword != "" else -1
	if timing_start >= 0 and timing_end > timing_start:
		timing = timing.substr(timing_start, timing_end - timing_start)
	var confidence := int(best.get("confidence", 0))
	var status: String = str(host._ui_text("timing_status_confirmed") if confidence >= 3 else (host._ui_text("timing_status_plausible") if confidence == 2 else host._ui_text("timing_status_rumored")))
	return "%s · %s" % [timing, status]


func _phase_display(phase: String) -> String:
	var configured: String = host._ui_text("phase_" + phase) if host.scenario_presentation.get("ui", {}).has("phase_" + phase) else host._ui_text("phase_default")
	return configured


func _header_day(day: int, duration: int) -> String:
	return "◷ %d / %d" % [maxi(1, day), duration]


func _header_place(place_name: String) -> String:
	return "◆ %s" % place_name


func _header_phase_label(phase_name: String) -> String:
	return "◌ %s" % phase_name.trim_suffix("期")
