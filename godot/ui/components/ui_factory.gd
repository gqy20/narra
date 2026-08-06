extends RefCounted

var theme_script
var decision_frame_texture: Texture2D
var colors: Dictionary
var type_scale: Dictionary
var body_font: Font
var medium_font: Font
var display_font: Font
var narrative_font: Font
var minimum_text_size: int


func _init(theme_source, decision_frame: Texture2D) -> void:
	theme_script = theme_source
	decision_frame_texture = decision_frame
	colors = theme_script.COLORS
	type_scale = theme_script.TYPE_SCALE
	body_font = theme_script.BodyFont
	medium_font = theme_script.MediumFont
	display_font = theme_script.DisplayFont
	narrative_font = theme_script.NarrativeFont
	minimum_text_size = theme_script.MIN_READABLE_TEXT_SIZE


func apply_root_theme(root: Control) -> void:
	root.theme = theme_script.build_theme()


func header_value(parent: Container, caption: String) -> Label:
	var group := VBoxContainer.new()
	var small := Label.new()
	small.text = caption
	small.add_theme_font_override("font", medium_font)
	small.add_theme_font_size_override("font_size", type_scale.meta)
	small.add_theme_color_override("font_color", colors.muted)
	group.add_child(small)
	var value := Label.new()
	value.text = "—"
	value.add_theme_font_override("font", medium_font)
	value.add_theme_font_size_override("font_size", type_scale.metric)
	value.add_theme_color_override("font_color", colors.ink)
	group.add_child(value)
	parent.add_child(group)
	return value


func hud_label(parent: Container, color: Color) -> Label:
	var value := Label.new()
	value.text = "—"
	value.add_theme_font_override("font", medium_font)
	value.add_theme_font_size_override("font_size", type_scale.compact)
	value.add_theme_color_override("font_color", color)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(value)
	return value


func zone(parent: VBoxContainer, title_text: String, ratio: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.add_theme_stylebox_override("panel", panel_style(Color(colors.panel, 0.62), 0, 2, Color.TRANSPARENT, 16, 14))
	parent.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_override("font", display_font)
	title.add_theme_font_size_override("font_size", type_scale.section)
	title.add_theme_color_override("font_color", colors.accent)
	outer.add_child(title)
	var rule := HSeparator.new()
	rule.modulate = Color(colors.accent, 0.35)
	outer.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	return box


func panel_style(color: Color, border: int, radius: int, border_color: Variant = null, horizontal_margin := 16, vertical_margin := 14) -> StyleBoxFlat:
	var resolved_border_color: Color = colors.line if border_color == null else border_color
	return theme_script.panel_style(color, border, radius, resolved_border_color, horizontal_margin, vertical_margin)


func tab_style(color: Color, border_color: Color) -> StyleBoxFlat:
	return theme_script.tab_style(color, border_color)


func input_style(color: Color, border_color: Color) -> StyleBoxFlat:
	return theme_script.input_style(color, border_color)


func button(text_value: String, callback: Callable, secondary: bool) -> Button:
	var control := Button.new()
	control.text = text_value
	control.custom_minimum_size.y = 46
	control.add_theme_font_override("font", medium_font)
	control.add_theme_font_size_override("font_size", type_scale.button)
	if secondary:
		control.add_theme_color_override("font_color", colors.ink)
		control.add_theme_color_override("font_hover_color", colors.ink)
		control.add_theme_color_override("font_pressed_color", colors.accent)
		control.add_theme_stylebox_override("normal", panel_style(colors.panel_alt, 1, 6, colors.line, 14, 10))
		control.add_theme_stylebox_override("hover", panel_style(colors.panel_hover, 1, 6, colors.accent_pressed, 14, 10))
		control.add_theme_stylebox_override("pressed", panel_style(colors.bg_lift, 1, 6, colors.accent, 14, 11))
	else:
		control.add_theme_color_override("font_color", colors.accent_ink)
		control.add_theme_color_override("font_hover_color", colors.accent_ink)
		control.add_theme_color_override("font_pressed_color", colors.accent_ink)
		control.add_theme_stylebox_override("normal", panel_style(colors.accent, 0, 6, colors.accent, 14, 11))
		control.add_theme_stylebox_override("hover", panel_style(colors.accent_hover, 0, 6, colors.accent_hover, 14, 10))
		control.add_theme_stylebox_override("pressed", panel_style(colors.accent_pressed, 0, 6, colors.accent_pressed, 14, 12))
	control.add_theme_stylebox_override("focus", panel_style(Color.TRANSPARENT, 2, 7, colors.accent_hover, 12, 8))
	control.add_theme_stylebox_override("disabled", panel_style(Color(colors.panel_alt, 0.58), 1, 6, Color(colors.line, 0.5), 14, 10))
	control.pressed.connect(callback)
	return control


func utility_button(text_value: String, callback: Callable) -> Button:
	var control := Button.new()
	control.text = text_value
	control.custom_minimum_size.y = 36
	control.add_theme_font_override("font", medium_font)
	control.add_theme_font_size_override("font_size", type_scale.detail)
	control.add_theme_color_override("font_color", colors.muted)
	control.add_theme_color_override("font_hover_color", colors.ink)
	control.add_theme_color_override("font_pressed_color", colors.accent)
	control.add_theme_stylebox_override("normal", panel_style(Color.TRANSPARENT, 0, 2, Color.TRANSPARENT, 10, 7))
	control.add_theme_stylebox_override("hover", panel_style(Color(colors.panel_alt, 0.72), 0, 2, Color.TRANSPARENT, 10, 7))
	control.add_theme_stylebox_override("pressed", panel_style(Color(colors.bg_lift, 0.92), 0, 2, Color.TRANSPARENT, 10, 8))
	control.add_theme_stylebox_override("focus", panel_style(Color.TRANSPARENT, 1, 2, colors.accent, 9, 6))
	control.add_theme_stylebox_override("disabled", panel_style(Color.TRANSPARENT, 0, 2, Color.TRANSPARENT, 10, 7))
	control.pressed.connect(callback)
	return control


func mode_button(text_value: String, callback: Callable) -> Button:
	var control := utility_button(text_value, callback)
	control.add_theme_font_size_override("font_size", type_scale.compact)
	control.custom_minimum_size.y = 38
	return control


func style_mode_state(control: Button, active: bool) -> void:
	control.add_theme_color_override("font_color", colors.accent if active else colors.muted)
	control.add_theme_color_override("font_hover_color", colors.ink)
	var normal := panel_style(Color(colors.bg_lift, 0.92) if active else Color.TRANSPARENT, 1 if active else 0, 4, Color(colors.accent, 0.62), 11, 6)
	control.add_theme_stylebox_override("normal", normal)


func action_button(text_value: String, callback: Callable) -> Button:
	var control := Button.new()
	control.text = text_value
	control.alignment = HORIZONTAL_ALIGNMENT_LEFT
	control.custom_minimum_size.y = 42
	control.add_theme_font_override("font", medium_font)
	control.add_theme_font_size_override("font_size", type_scale.button)
	control.add_theme_color_override("font_color", colors.ink)
	control.add_theme_color_override("font_hover_color", colors.ink)
	control.add_theme_color_override("font_pressed_color", colors.accent)
	var normal := panel_style(Color(colors.panel_alt, 0.38), 0, 2, Color.TRANSPARENT, 14, 9)
	normal.border_width_left = 2
	normal.border_color = Color(colors.line, 0.84)
	var hover := panel_style(Color(colors.panel_hover, 0.78), 0, 2, Color.TRANSPARENT, 14, 9)
	hover.border_width_left = 2
	hover.border_color = colors.accent
	var pressed := panel_style(Color(colors.bg_lift, 0.92), 0, 2, Color.TRANSPARENT, 14, 10)
	pressed.border_width_left = 2
	pressed.border_color = colors.accent_pressed
	control.add_theme_stylebox_override("normal", normal)
	control.add_theme_stylebox_override("hover", hover)
	control.add_theme_stylebox_override("pressed", pressed)
	control.add_theme_stylebox_override("focus", panel_style(Color.TRANSPARENT, 1, 2, colors.accent_hover, 12, 7))
	control.add_theme_stylebox_override("disabled", panel_style(Color(colors.panel_alt, 0.26), 0, 2, Color.TRANSPARENT, 14, 9))
	control.pressed.connect(callback)
	return control


func category_button(text_value: String, active: bool, callback: Callable) -> Button:
	var marker := "当前" if active else "展开"
	var control := utility_button("%s　·　%s" % [text_value, marker], callback)
	control.alignment = HORIZONTAL_ALIGNMENT_LEFT
	control.custom_minimum_size.y = 34
	control.add_theme_color_override("font_color", colors.accent if active else colors.muted)
	return control


func ornate_button(text_value: String, callback: Callable) -> Button:
	var control := Button.new()
	control.text = text_value
	control.add_theme_font_override("font", display_font)
	control.add_theme_font_size_override("font_size", 20)
	control.add_theme_color_override("font_color", Color("e5c47d"))
	control.add_theme_color_override("font_hover_color", colors.ink)
	control.add_theme_color_override("font_pressed_color", colors.accent_pressed)
	control.add_theme_stylebox_override("normal", panel_style(theme_script.alpha8(colors.surface_glass, 0xb8), 0, 0, Color.TRANSPARENT, 20, 14))
	control.add_theme_stylebox_override("hover", panel_style(Color("171c16e6"), 0, 0, Color.TRANSPARENT, 20, 14))
	control.add_theme_stylebox_override("pressed", panel_style(theme_script.alpha8(colors.overlay, 0xf2), 0, 0, Color.TRANSPARENT, 20, 15))
	control.add_theme_stylebox_override("focus", panel_style(Color.TRANSPARENT, 1, 2, colors.accent_hover, 18, 12))
	var frame := TextureRect.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.texture = decision_frame_texture
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.modulate = Color(1, 1, 1, 0.90)
	control.add_child(frame)
	control.move_child(frame, 0)
	control.pressed.connect(callback)
	return control


func style_menu_button(control: MenuButton) -> void:
	control.add_theme_font_override("font", medium_font)
	control.add_theme_font_size_override("font_size", type_scale.button)
	control.add_theme_color_override("font_color", colors.ink)
	control.add_theme_color_override("font_hover_color", colors.ink)
	control.add_theme_color_override("font_pressed_color", colors.accent)
	var normal := panel_style(Color(colors.panel_alt, 0.38), 0, 2, Color.TRANSPARENT, 14, 9)
	normal.border_width_left = 2
	normal.border_color = Color(colors.line, 0.84)
	var hover := panel_style(Color(colors.panel_hover, 0.78), 0, 2, Color.TRANSPARENT, 14, 9)
	hover.border_width_left = 2
	hover.border_color = colors.accent
	control.add_theme_stylebox_override("normal", normal)
	control.add_theme_stylebox_override("hover", hover)
	control.add_theme_stylebox_override("pressed", hover)
	control.add_theme_stylebox_override("focus", panel_style(Color.TRANSPARENT, 1, 2, colors.accent_hover, 12, 7))
	var popup := control.get_popup()
	popup.add_theme_color_override("font_color", colors.ink)
	popup.add_theme_color_override("font_hover_color", colors.accent_ink)
	popup.add_theme_stylebox_override("panel", panel_style(colors.panel_alt, 1, 7, colors.line, 8, 8))
	popup.add_theme_stylebox_override("hover", panel_style(colors.accent, 0, 4, colors.accent, 8, 6))


func text(parent: Container, value: String, muted := false, size := 16) -> Label:
	var resolved_size := maxi(size, minimum_text_size)
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if resolved_size >= 24:
		label.add_theme_font_override("font", display_font)
	elif resolved_size >= 17 or resolved_size <= type_scale.meta:
		label.add_theme_font_override("font", medium_font)
	label.add_theme_font_size_override("font_size", resolved_size)
	label.add_theme_color_override("font_color", colors.muted if muted else colors.ink)
	if resolved_size <= type_scale.body:
		label.add_theme_constant_override("line_spacing", 4)
	elif resolved_size < 24:
		label.add_theme_constant_override("line_spacing", 3)
	parent.add_child(label)
	return label


func clear(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()


func set_buttons_disabled(node: Node, disabled: bool) -> void:
	if node is BaseButton:
		node.disabled = disabled
		if disabled:
			node.add_theme_color_override("font_disabled_color", Color(colors.ink, 0.76))
		else:
			node.remove_theme_color_override("font_disabled_color")
	for child in node.get_children():
		set_buttons_disabled(child, disabled)


func status_chip(parent: Container, value: String, color: Color) -> void:
	if parent.get_child_count() > 0:
		var separator := Label.new()
		separator.text = "·"
		separator.add_theme_font_override("font", body_font)
		separator.add_theme_font_size_override("font_size", type_scale.meta)
		separator.add_theme_color_override("font_color", Color(colors.muted, 0.58))
		parent.add_child(separator)
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", body_font)
	label.add_theme_font_size_override("font_size", type_scale.meta)
	label.add_theme_color_override("font_color", Color(color, 0.92))
	parent.add_child(label)
