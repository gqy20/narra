extends RefCounted


func build(parent: VBoxContainer, factory) -> Label:
	var footer_panel := PanelContainer.new()
	footer_panel.custom_minimum_size.y = 30
	footer_panel.add_theme_stylebox_override("panel", factory.panel_style(Color(factory.colors.bg_lift, 0.76), 0, 0, Color.TRANSPARENT, 10, 4))
	parent.add_child(footer_panel)
	var footer_label := Label.new()
	footer_label.text = ""
	footer_label.add_theme_color_override("font_color", factory.colors.muted)
	footer_label.add_theme_font_override("font", factory.medium_font)
	footer_label.add_theme_font_size_override("font_size", factory.type_scale.detail)
	footer_label.custom_minimum_size.y = 22
	footer_panel.add_child(footer_label)
	return footer_label
