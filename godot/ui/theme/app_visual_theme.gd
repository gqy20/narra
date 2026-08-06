extends RefCounted

const BodyFont = preload("res://assets/fonts/SourceHanSansCN-Regular.otf")
const MediumFont = preload("res://assets/fonts/SourceHanSansCN-Medium.otf")
const DisplayFont = preload("res://assets/fonts/SourceHanSerifCN-SemiBold.otf")
const NarrativeFont = preload("res://assets/fonts/LXGWWenKaiLite-Regular.ttf")

const MIN_READABLE_TEXT_SIZE := 14

const TYPE_SCALE := {
	"display": 60,
	"brand": 28,
	"title": 28,
	"headline": 22,
	"section": 20,
	"metric": 18,
	"body": 17,
	"compact": 15,
	"detail": 14,
	"meta": 14,
	"caption": 14,
	"button": 16,
}

# These tokens describe stable interface semantics. Scene artwork and procedural
# illustrations keep their own local palettes instead of extending this table.
const COLORS := {
	"bg": Color("090c0a"),
	"bg_deep": Color("060806"),
	"bg_lift": Color("101712"),
	"scrim": Color("030504"),
	"overlay": Color("050706"),
	"surface_cinematic": Color("070907"),
	"surface_glass": Color("080b09"),
	"surface_toast": Color("09100b"),
	"surface_dock": Color("0b100d"),
	"panel": Color("121713"),
	"panel_alt": Color("1a231d"),
	"panel_hover": Color("232e26"),
	"line": Color("344039"),
	"line_soft": Color("242e28"),
	"ink": Color("f2ebdd"),
	"ink_warm": Color("ead6a8"),
	"ink_soft": Color("ded4c1"),
	"ink_prompt": Color("e8ddc8"),
	"ink_subtle": Color("b8b7ad"),
	"muted": Color("a9b3a6"),
	"accent": Color("d6ae62"),
	"accent_hover": Color("e4c079"),
	"accent_pressed": Color("b98e47"),
	"accent_ink": Color("15110a"),
	"danger": Color("c46352"),
	"danger_deep": Color("8f352c"),
	"success": Color("82aa78"),
	"shadow": Color("000000"),
}


static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = BodyFont
	theme.default_font_size = TYPE_SCALE.body
	theme.set_font("font", "Button", MediumFont)
	theme.set_font("font", "MenuButton", MediumFont)
	theme.set_font("font", "TabBar", MediumFont)
	theme.set_color("font_color", "Label", COLORS.ink)
	theme.set_color("font_color", "Button", COLORS.ink)
	theme.set_color("font_hover_color", "Button", COLORS.ink)
	theme.set_color("font_pressed_color", "Button", COLORS.ink)
	theme.set_color("font_focus_color", "Button", COLORS.ink)
	theme.set_color("font_disabled_color", "Button", Color(COLORS.muted, 0.45))
	theme.set_color("font_color", "LineEdit", COLORS.ink)
	theme.set_color("font_placeholder_color", "LineEdit", Color(COLORS.muted, 0.62))
	theme.set_color("caret_color", "LineEdit", COLORS.accent)
	theme.set_color("selection_color", "LineEdit", Color(COLORS.accent, 0.28))
	theme.set_color("font_color", "TextEdit", COLORS.ink)
	theme.set_color("font_placeholder_color", "TextEdit", Color(COLORS.muted, 0.62))
	theme.set_color("caret_color", "TextEdit", COLORS.accent)
	theme.set_color("selection_color", "TextEdit", Color(COLORS.accent, 0.28))
	theme.set_constant("line_spacing", "TextEdit", 3)
	theme.set_stylebox("normal", "TextEdit", panel_style(Color(COLORS.panel_alt, 0.68), 1, 5, Color(COLORS.line, 0.82), 10, 8))
	theme.set_stylebox("focus", "TextEdit", panel_style(Color(COLORS.panel_alt, 0.82), 1, 5, Color(COLORS.accent, 0.88), 10, 8))
	theme.set_stylebox("read_only", "TextEdit", panel_style(Color(COLORS.panel, 0.54), 1, 5, Color(COLORS.line_soft, 0.66), 10, 8))
	theme.set_stylebox("panel", "TabContainer", panel_style(Color.TRANSPARENT, 0, 0, Color.TRANSPARENT, 0, 0))
	theme.set_type_variation("NarraFoldable", "FoldableContainer")
	theme.set_font("font", "NarraFoldable", MediumFont)
	theme.set_font_size("font_size", "NarraFoldable", TYPE_SCALE.body)
	theme.set_color("font_color", "NarraFoldable", COLORS.ink)
	theme.set_color("collapsed_font_color", "NarraFoldable", COLORS.muted)
	theme.set_color("hover_font_color", "NarraFoldable", COLORS.accent)
	theme.set_constant("h_separation", "NarraFoldable", 8)
	var foldable_title := panel_style(Color.TRANSPARENT, 0, 2, Color.TRANSPARENT, 8, 8)
	var foldable_title_hover := panel_style(Color(COLORS.panel_hover, 0.52), 0, 2, Color.TRANSPARENT, 8, 8)
	theme.set_stylebox("title_panel", "NarraFoldable", foldable_title)
	theme.set_stylebox("title_collapsed_panel", "NarraFoldable", foldable_title)
	theme.set_stylebox("title_hover_panel", "NarraFoldable", foldable_title_hover)
	theme.set_stylebox("title_collapsed_hover_panel", "NarraFoldable", foldable_title_hover)
	theme.set_stylebox("panel", "NarraFoldable", panel_style(Color.TRANSPARENT, 0, 0, Color.TRANSPARENT, 10, 8))
	theme.set_stylebox("focus", "NarraFoldable", panel_style(Color.TRANSPARENT, 1, 2, Color(COLORS.accent, 0.82), 7, 7))
	theme.set_stylebox("tab_selected", "TabBar", tab_style(COLORS.panel_hover, COLORS.accent))
	theme.set_stylebox("tab_hovered", "TabBar", tab_style(COLORS.panel_alt, COLORS.line))
	theme.set_stylebox("tab_unselected", "TabBar", tab_style(Color.TRANSPARENT, Color.TRANSPARENT))
	theme.set_color("font_selected_color", "TabBar", COLORS.accent)
	theme.set_color("font_hovered_color", "TabBar", COLORS.ink)
	theme.set_color("font_unselected_color", "TabBar", COLORS.muted)
	theme.set_stylebox("scroll", "VScrollBar", panel_style(Color.TRANSPARENT, 0, 0, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("grabber", "VScrollBar", panel_style(Color(COLORS.line, 0.82), 0, 4, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("grabber_highlight", "VScrollBar", panel_style(COLORS.accent_pressed, 0, 4, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("grabber_pressed", "VScrollBar", panel_style(COLORS.accent, 0, 4, Color.TRANSPARENT, 0, 0))
	theme.set_constant("minimum_grab_thickness", "VScrollBar", 28)
	theme.set_stylebox("panel", "TooltipPanel", panel_style(COLORS.panel_alt, 1, 5, COLORS.line, 10, 8))
	theme.set_color("font_color", "TooltipLabel", COLORS.ink)
	theme.set_font_size("font_size", "TooltipLabel", TYPE_SCALE.meta)
	return theme


static func panel_style(color: Color, border: int, radius: int, border_color: Color, horizontal_margin: int, vertical_margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal_margin
	style.content_margin_right = horizontal_margin
	style.content_margin_top = vertical_margin
	style.content_margin_bottom = vertical_margin
	return style


static func tab_style(color: Color, border_color: Color) -> StyleBoxFlat:
	var style := panel_style(color, 0, 5, border_color, 12, 8)
	style.border_width_bottom = 2 if border_color.a > 0.0 else 0
	return style


static func input_style(color: Color, border_color: Color) -> StyleBoxFlat:
	return panel_style(color, 1, 6, border_color, 16, 11)


static func alpha8(color: Color, alpha_byte: int) -> Color:
	var resolved := color
	resolved.a = float(clampi(alpha_byte, 0, 255)) / 255.0
	return resolved
