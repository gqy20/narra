extends RefCounted


func build(parent: VBoxContainer, factory, callbacks: Dictionary) -> Dictionary:
	var colors: Dictionary = factory.colors
	var type_scale: Dictionary = factory.type_scale
	var header := PanelContainer.new()
	var header_style: StyleBoxFlat = factory.panel_style(Color("090d0ac7"), 0, 0, Color.TRANSPARENT, 18, 6)
	header_style.border_width_bottom = 1
	header_style.border_color = Color(colors.accent, 0.22)
	header.add_theme_stylebox_override("panel", header_style)
	header.custom_minimum_size.y = 62
	parent.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	header.add_child(row)

	var brand_label := Label.new()
	brand_label.text = "游戏"
	brand_label.add_theme_font_override("font", factory.display_font)
	brand_label.add_theme_font_size_override("font_size", type_scale.brand)
	brand_label.add_theme_color_override("font_color", colors.accent)
	row.add_child(brand_label)
	var world_title_label := Label.new()
	world_title_label.text = ""
	world_title_label.add_theme_font_override("font", factory.display_font)
	world_title_label.add_theme_font_size_override("font_size", type_scale.body)
	world_title_label.add_theme_color_override("font_color", Color(colors.accent, 0.78))
	row.add_child(world_title_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var day_label: Label = factory.hud_label(row, colors.accent)
	var place_label: Label = factory.hud_label(row, colors.ink)
	place_label.hide()
	var phase_label: Label = factory.hud_label(row, colors.muted)
	var timing_label := Label.new()
	timing_label.hide()
	header.add_child(timing_label)
	var journal_button: Button = factory.utility_button("卷宗", callbacks.journal)
	journal_button.tooltip_text = "随身卷宗"
	journal_button.custom_minimum_size = Vector2(64, 36)
	row.add_child(journal_button)
	var save_button: Button = factory.utility_button("保存", callbacks.save)
	save_button.tooltip_text = "保存当前进度"
	save_button.custom_minimum_size = Vector2(64, 36)
	row.add_child(save_button)
	var divider := Label.new()
	divider.text = "│"
	divider.add_theme_color_override("font_color", Color(colors.line, 0.72))
	divider.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(divider)
	var settings_button: Button = factory.utility_button("设置", callbacks.settings)
	settings_button.tooltip_text = "声音与显示设置"
	settings_button.custom_minimum_size = Vector2(64, 36)
	row.add_child(settings_button)
	var return_button: Button = factory.utility_button("卷首", callbacks.return_to_start)
	return_button.tooltip_text = "返回卷首"
	return_button.custom_minimum_size = Vector2(64, 36)
	row.add_child(return_button)
	return {
		"brand_label": brand_label,
		"world_title_label": world_title_label,
		"day_label": day_label,
		"place_label": place_label,
		"phase_label": phase_label,
		"timing_label": timing_label,
		"settings_button": settings_button,
	}
