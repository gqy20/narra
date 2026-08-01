extends Control

const WorldMapViewScript = preload("res://scripts/world_map.gd")
const LocationStageScript = preload("res://scripts/location_stage.gd")
const PresentationDirectorScript = preload("res://scripts/presentation_director.gd")
const PresentationRegistryScript = preload("res://scripts/presentation_registry.gd")
const AudioDirectorScript = preload("res://scripts/audio_director.gd")
const CausalSealTexture = preload("res://assets/ui/causal/causal-seal.png")
const DecisionFrameTexture = preload("res://assets/ui/causal/decision-frame.png")
const TimelineArrowTexture = preload("res://assets/ui/causal/timeline-arrow.png")
const StartBackgroundTexture = preload("res://assets/locations/market/background.png")
const API_BASE := "http://127.0.0.1:8787/api/v1"
const AUTOSAVE_SLOT := "autosave"
const TYPE_SCALE := {
	"display": 60,
	"brand": 28,
	"section": 18,
	"metric": 18,
	"body": 16,
	"compact": 15,
	"detail": 14,
	"meta": 13,
	"button": 15,
}
const COLORS := {
	"bg": Color("090c0a"),
	"bg_lift": Color("101712"),
	"panel": Color("121713"),
	"panel_alt": Color("1a231d"),
	"panel_hover": Color("232e26"),
	"line": Color("344039"),
	"line_soft": Color("242e28"),
	"ink": Color("f2ebdd"),
	"muted": Color("a9b3a6"),
	"accent": Color("d6ae62"),
	"accent_hover": Color("e4c079"),
	"accent_pressed": Color("b98e47"),
	"accent_ink": Color("15110a"),
	"danger": Color("c46352"),
	"danger_deep": Color("8f352c"),
	"success": Color("82aa78"),
}

@onready var http: HTTPRequest = $HTTPRequest

var current_view: Dictionary = {}
var pending_operation := ""
var autosave_after_action := false
var selected_action: Dictionary = {}
var available_actions_cache: Array = []
var focused_actor_id := ""
var focused_actor_name := ""
var focused_fact_id := ""
var focused_fact_claim := ""
var stage_actor_id := ""
var stage_actor_name := ""
var actor_expression_by_id := {}
var selected_map_location_id := ""
var rendered_location_id := ""
var visual_mode := "map"
var view_before_action: Dictionary = {}
var presentation_registry = PresentationRegistryScript.new()
var sound_enabled := true
var motion_enabled := true
var presentation_busy := false
var active_action_category := ""
var focused_actor_details_visible := false
var causal_change_count_by_actor := {}
var causal_actor_id_by_name := {}
var last_causal_actor_id := ""

var start_layer: Control
var game_layer: Control
var name_input: LineEdit
var connection_label: Label
var retry_button: Button
var day_label: Label
var place_label: Label
var phase_label: Label
var timing_label: Label
var objective_label: Label
var player_summary_label: Label
var clues_box: VBoxContainer
var scene_box: VBoxContainer
var people_box: VBoxContainer
var actions_box: VBoxContainer
var footer_label: Label
var journal_layer: Control
var journal_panel: PanelContainer
var ending_layer: Control
var ending_box: VBoxContainer
var ending_background: TextureRect
var ending_portrait: TextureRect
var ending_annex_box: VBoxContainer
var ending_annex_button: Button
var causal_layer: Control
var causal_background: TextureRect
var causal_portrait: TextureRect
var causal_message: Label
var causal_actor_meta: Label
var causal_original: Label
var causal_now: Label
var causal_day: Label
var confirmation_layer: Control
var confirmation_box: VBoxContainer
var confirmation_details_box: VBoxContainer
var confirmation_details_button: Button
var visual_stack: Control
var map_panel: VBoxContainer
var location_panel: VBoxContainer
var map_detail_box: VBoxContainer
var location_detail_box: VBoxContainer
var stage_people_box: HFlowContainer
var map_mode_button: Button
var location_mode_button: Button
var world_map_view: Control
var location_stage: Control
var presentation_director: Control
var audio_director: Node
var actor_portrait_frame: PanelContainer
var actor_portrait: TextureRect
var actor_portrait_name: Label
var actor_portrait_meta: Label
var sound_button: Button
var motion_button: Button
var settings_layer: Control
var settings_box: VBoxContainer
var body_font: SystemFont
var medium_font: SystemFont
var display_font: SystemFont


func _ready() -> void:
	_configure_theme()
	audio_director = AudioDirectorScript.new()
	add_child(audio_director)
	http.request_completed.connect(_on_request_completed)
	_build_interface()
	_request("health", HTTPClient.METHOD_GET, "/health")


func _configure_theme() -> void:
	body_font = SystemFont.new()
	body_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	body_font.font_weight = 400
	medium_font = SystemFont.new()
	medium_font.font_names = body_font.font_names
	medium_font.font_weight = 500
	display_font = SystemFont.new()
	display_font.font_names = PackedStringArray(["STZhongsong", "SimSun", "Noto Serif CJK SC"])
	display_font.font_weight = 600
	var app_theme := Theme.new()
	app_theme.default_font = body_font
	app_theme.default_font_size = TYPE_SCALE.body
	app_theme.set_font("font", "Button", medium_font)
	app_theme.set_font("font", "MenuButton", medium_font)
	app_theme.set_font("font", "TabBar", medium_font)
	app_theme.set_color("font_color", "Label", COLORS.ink)
	app_theme.set_color("font_color", "Button", COLORS.ink)
	app_theme.set_color("font_hover_color", "Button", COLORS.ink)
	app_theme.set_color("font_pressed_color", "Button", COLORS.ink)
	app_theme.set_color("font_focus_color", "Button", COLORS.ink)
	app_theme.set_color("font_disabled_color", "Button", Color(COLORS.muted, 0.45))
	app_theme.set_color("font_color", "LineEdit", COLORS.ink)
	app_theme.set_color("font_placeholder_color", "LineEdit", Color(COLORS.muted, 0.62))
	app_theme.set_color("caret_color", "LineEdit", COLORS.accent)
	app_theme.set_color("selection_color", "LineEdit", Color(COLORS.accent, 0.28))
	app_theme.set_stylebox("panel", "TabContainer", _panel_style(Color.TRANSPARENT, 0, 0))
	app_theme.set_stylebox("tab_selected", "TabBar", _tab_style(COLORS.panel_hover, COLORS.accent))
	app_theme.set_stylebox("tab_hovered", "TabBar", _tab_style(COLORS.panel_alt, COLORS.line))
	app_theme.set_stylebox("tab_unselected", "TabBar", _tab_style(Color.TRANSPARENT, Color.TRANSPARENT))
	app_theme.set_color("font_selected_color", "TabBar", COLORS.accent)
	app_theme.set_color("font_hovered_color", "TabBar", COLORS.ink)
	app_theme.set_color("font_unselected_color", "TabBar", COLORS.muted)
	app_theme.set_stylebox("scroll", "VScrollBar", _panel_style(Color.TRANSPARENT, 0, 0, Color.TRANSPARENT, 0, 0))
	app_theme.set_stylebox("grabber", "VScrollBar", _panel_style(Color(COLORS.line, 0.82), 0, 4, Color.TRANSPARENT, 0, 0))
	app_theme.set_stylebox("grabber_highlight", "VScrollBar", _panel_style(COLORS.accent_pressed, 0, 4, Color.TRANSPARENT, 0, 0))
	app_theme.set_stylebox("grabber_pressed", "VScrollBar", _panel_style(COLORS.accent, 0, 4, Color.TRANSPARENT, 0, 0))
	app_theme.set_constant("minimum_grab_thickness", "VScrollBar", 28)
	app_theme.set_stylebox("panel", "TooltipPanel", _panel_style(COLORS.panel_alt, 1, 5, COLORS.line, 10, 8))
	app_theme.set_color("font_color", "TooltipLabel", COLORS.ink)
	app_theme.set_font_size("font_size", "TooltipLabel", TYPE_SCALE.meta)
	theme = app_theme


func _build_interface() -> void:
	var background := TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.46, 1.0])
	gradient.colors = PackedColorArray([COLORS.bg_lift, COLORS.bg, Color("060806")])
	var gradient_texture := GradientTexture2D.new()
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
	add_child(background)

	var top_rule := ColorRect.new()
	top_rule.color = Color(COLORS.accent, 0.45)
	top_rule.custom_minimum_size.y = 2
	top_rule.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_rule)

	game_layer = VBoxContainer.new()
	game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
	game_layer.add_theme_constant_override("separation", 10)
	add_child(game_layer)
	_build_header()
	_build_dashboard()
	_build_footer()
	game_layer.hide()

	_build_start_layer()
	_build_journal_layer()
	_build_confirmation_layer()
	_build_settings_layer()
	_build_causal_layer()
	_build_ending_layer()
	presentation_director = PresentationDirectorScript.new()
	add_child(presentation_director)


func _build_header() -> void:
	var header := PanelContainer.new()
	var header_style := _panel_style(Color("0b100ddd"), 0, 0, Color.TRANSPARENT, 16, 9)
	header_style.border_width_bottom = 1
	header_style.border_color = Color(COLORS.accent, 0.34)
	header.add_theme_stylebox_override("panel", header_style)
	header.custom_minimum_size.y = 74
	game_layer.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	header.add_child(row)

	var brand := Label.new()
	brand.text = "凡途 · 黑风谷"
	brand.add_theme_font_override("font", display_font)
	brand.add_theme_font_size_override("font_size", 24)
	brand.add_theme_color_override("font_color", COLORS.accent)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(brand)

	day_label = _header_value(row, "时日")
	place_label = _header_value(row, "所在")
	phase_label = _header_value(row, "局势")
	timing_label = _header_value(row, "已知时机")
	var journal_button := _utility_button("随身卷宗", _open_journal)
	journal_button.custom_minimum_size = Vector2(104, 38)
	row.add_child(journal_button)
	sound_button = _utility_button("声音", _open_audio_settings)
	sound_button.custom_minimum_size = Vector2(66, 38)
	row.add_child(sound_button)
	var save_button := _utility_button("存档", _save_game)
	save_button.custom_minimum_size = Vector2(62, 38)
	row.add_child(save_button)
	var return_button := _utility_button("返回", _return_to_start)
	return_button.custom_minimum_size = Vector2(62, 38)
	row.add_child(return_button)


func _build_dashboard() -> void:
	var workspace := HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 14)
	game_layer.add_child(workspace)

	var world_column := VBoxContainer.new()
	world_column.custom_minimum_size.x = 820
	world_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_column.size_flags_stretch_ratio = 2.05
	world_column.add_theme_constant_override("separation", 8)
	workspace.add_child(world_column)
	_build_world_stage(world_column)

	var decision_column := VBoxContainer.new()
	decision_column.custom_minimum_size.x = 360
	decision_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decision_column.size_flags_stretch_ratio = 0.95
	decision_column.add_theme_constant_override("separation", 8)
	workspace.add_child(decision_column)
	var decision_eyebrow := Label.new()
	decision_eyebrow.text = "此刻如何落子"
	decision_eyebrow.add_theme_font_override("font", display_font)
	decision_eyebrow.add_theme_font_size_override("font_size", TYPE_SCALE.section)
	decision_eyebrow.add_theme_color_override("font_color", COLORS.accent)
	decision_column.add_child(decision_eyebrow)
	objective_label = Label.new()
	objective_label.text = "正在读取局势"
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_size_override("font_size", TYPE_SCALE.detail)
	objective_label.add_theme_constant_override("line_spacing", 4)
	objective_label.add_theme_color_override("font_color", COLORS.muted)
	decision_column.add_child(objective_label)
	actions_box = _zone(decision_column, "可行之事", 1.0)


func _build_world_stage(parent: VBoxContainer) -> void:
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	parent.add_child(mode_row)
	var heading := Label.new()
	heading.text = "行旅视野"
	heading.add_theme_font_override("font", display_font)
	heading.add_theme_font_size_override("font_size", TYPE_SCALE.section)
	heading.add_theme_color_override("font_color", COLORS.accent)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_child(heading)
	map_mode_button = _mode_button("区域地图", _set_visual_mode.bind("map"))
	map_mode_button.custom_minimum_size = Vector2(116, 38)
	mode_row.add_child(map_mode_button)
	location_mode_button = _mode_button("当前地点", _set_visual_mode.bind("location"))
	location_mode_button.custom_minimum_size = Vector2(116, 38)
	mode_row.add_child(location_mode_button)

	var stage_frame := PanelContainer.new()
	stage_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_frame.size_flags_stretch_ratio = 1.0
	stage_frame.custom_minimum_size.y = 560
	stage_frame.add_theme_stylebox_override("panel", _panel_style(Color(COLORS.panel, 0.66), 0, 2, Color.TRANSPARENT, 8, 8))
	parent.add_child(stage_frame)
	visual_stack = Control.new()
	visual_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	visual_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_frame.add_child(visual_stack)

	map_panel = VBoxContainer.new()
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_panel.add_theme_constant_override("separation", 8)
	visual_stack.add_child(map_panel)
	world_map_view = WorldMapViewScript.new()
	world_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	world_map_view.location_selected.connect(_on_map_location_selected)
	world_map_view.travel_day_changed.connect(_on_travel_day_changed)
	map_panel.add_child(world_map_view)
	map_detail_box = VBoxContainer.new()
	map_detail_box.custom_minimum_size.y = 88
	map_detail_box.add_theme_constant_override("separation", 5)
	map_panel.add_child(map_detail_box)

	location_panel = VBoxContainer.new()
	location_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	location_panel.add_theme_constant_override("separation", 8)
	visual_stack.add_child(location_panel)
	var stage_canvas := Control.new()
	stage_canvas.custom_minimum_size = Vector2(640, 320)
	stage_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_canvas.clip_contents = true
	location_panel.add_child(stage_canvas)
	location_stage = LocationStageScript.new()
	location_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_canvas.add_child(location_stage)
	actor_portrait_frame = PanelContainer.new()
	actor_portrait_frame.anchor_left = 0.67
	actor_portrait_frame.anchor_right = 0.98
	actor_portrait_frame.anchor_top = 0.015
	actor_portrait_frame.anchor_bottom = 0.985
	actor_portrait_frame.add_theme_stylebox_override("panel", _panel_style(Color("080b0966"), 0, 0, Color.TRANSPARENT, 0, 0))
	actor_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_canvas.add_child(actor_portrait_frame)
	var portrait_stack := Control.new()
	portrait_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor_portrait_frame.add_child(portrait_stack)
	actor_portrait = TextureRect.new()
	actor_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	actor_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	actor_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	actor_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_stack.add_child(actor_portrait)
	var portrait_caption := PanelContainer.new()
	portrait_caption.anchor_left = 0.0
	portrait_caption.anchor_right = 1.0
	portrait_caption.anchor_top = 0.76
	portrait_caption.anchor_bottom = 1.0
	portrait_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_caption.add_theme_stylebox_override("panel", _panel_style(Color("070b08d6"), 0, 0, Color.TRANSPARENT, 14, 10))
	portrait_stack.add_child(portrait_caption)
	var portrait_caption_content := VBoxContainer.new()
	portrait_caption_content.add_theme_constant_override("separation", 2)
	portrait_caption.add_child(portrait_caption_content)
	actor_portrait_name = _text(portrait_caption_content, "", false, 17)
	actor_portrait_name.add_theme_color_override("font_color", COLORS.accent)
	actor_portrait_meta = _text(portrait_caption_content, "", true, 12)
	actor_portrait_frame.hide()
	location_detail_box = VBoxContainer.new()
	location_detail_box.add_theme_constant_override("separation", 3)
	location_panel.add_child(location_detail_box)
	stage_people_box = HFlowContainer.new()
	stage_people_box.add_theme_constant_override("h_separation", 8)
	stage_people_box.add_theme_constant_override("v_separation", 7)
	location_panel.add_child(stage_people_box)
	_set_visual_mode("map")


func _build_footer() -> void:
	footer_label = Label.new()
	footer_label.text = ""
	footer_label.add_theme_color_override("font_color", COLORS.muted)
	footer_label.add_theme_font_override("font", medium_font)
	footer_label.add_theme_font_size_override("font_size", TYPE_SCALE.meta)
	footer_label.custom_minimum_size.y = 20
	game_layer.add_child(footer_label)


func _build_start_layer() -> void:
	start_layer = Control.new()
	start_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(start_layer)
	var scene := TextureRect.new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.texture = StartBackgroundTexture
	scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_layer.add_child(scene)
	var shade := ColorRect.new()
	shade.color = Color("030504a8")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_layer.add_child(shade)
	var center := CenterContainer.new()
	center.anchor_left = 0.39
	center.anchor_right = 0.95
	center.anchor_top = 0.04
	center.anchor_bottom = 0.98
	start_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(610, 536)
	card.add_theme_stylebox_override("panel", _panel_style(Color("070a08a8"), 0, 0, Color.TRANSPARENT, 44, 36))
	center.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	card.add_child(content)

	var eyebrow := Label.new()
	eyebrow.text = "黑风谷异动　·　三十日局势"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	eyebrow.add_theme_color_override("font_color", COLORS.accent)
	eyebrow.add_theme_font_override("font", medium_font)
	eyebrow.add_theme_font_size_override("font_size", TYPE_SCALE.meta)
	content.add_child(eyebrow)
	var title := Label.new()
	title.text = "凡 途"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_override("font", display_font)
	title.add_theme_font_size_override("font_size", TYPE_SCALE.display)
	title.add_theme_color_override("font_color", COLORS.ink)
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "三十日内，青髓芝的归属将被决定。\n你未必亲手夺取它，也能让一条消息改写别人的去向。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle.add_theme_color_override("font_color", COLORS.muted)
	subtitle.add_theme_font_size_override("font_size", TYPE_SCALE.body)
	subtitle.add_theme_constant_override("line_spacing", 7)
	content.add_child(subtitle)
	var divider := HSeparator.new()
	divider.modulate = Color(COLORS.accent, 0.48)
	content.add_child(divider)

	name_input = LineEdit.new()
	name_input.placeholder_text = "输入角色名"
	name_input.text = "无名修士"
	name_input.add_theme_font_size_override("font_size", TYPE_SCALE.metric)
	name_input.custom_minimum_size.y = 52
	name_input.add_theme_stylebox_override("normal", _input_style(COLORS.panel_alt, COLORS.line))
	name_input.add_theme_stylebox_override("focus", _input_style(COLORS.panel_hover, COLORS.accent))
	name_input.add_theme_constant_override("minimum_character_width", 8)
	content.add_child(name_input)
	var begin_button := _ornate_button("踏入黑风谷", _new_game)
	begin_button.custom_minimum_size.y = 66
	content.add_child(begin_button)
	content.add_child(_action_button("继续上次旅程", _load_game))
	retry_button = _action_button("重新连接本地服务", _retry_connection)
	retry_button.hide()
	content.add_child(retry_button)
	connection_label = Label.new()
	connection_label.text = ""
	connection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	connection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	connection_label.add_theme_color_override("font_color", COLORS.muted)
	connection_label.add_theme_font_size_override("font_size", TYPE_SCALE.meta)
	connection_label.add_theme_constant_override("line_spacing", 4)
	content.add_child(connection_label)


func _build_journal_layer() -> void:
	journal_layer = Control.new()
	journal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	journal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	journal_layer.hide()
	add_child(journal_layer)
	var shade := ColorRect.new()
	shade.color = Color("030504b8")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	journal_layer.add_child(shade)
	var dismiss_area := Button.new()
	dismiss_area.flat = true
	dismiss_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dismiss_area.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	dismiss_area.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	dismiss_area.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	dismiss_area.pressed.connect(_close_journal)
	journal_layer.add_child(dismiss_area)
	journal_panel = PanelContainer.new()
	journal_panel.anchor_left = 0.64
	journal_panel.anchor_right = 0.992
	journal_panel.anchor_top = 0.026
	journal_panel.anchor_bottom = 0.974
	journal_panel.add_theme_stylebox_override("panel", _panel_style(Color("101612f5"), 1, 3, Color(COLORS.accent, 0.44), 24, 20))
	journal_layer.add_child(journal_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	journal_panel.add_child(outer)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	outer.add_child(title_row)
	var title := Label.new()
	title.text = "随身卷宗"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", display_font)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLORS.accent)
	title_row.add_child(title)
	var close_button := _utility_button("收起", _close_journal)
	close_button.custom_minimum_size = Vector2(72, 38)
	title_row.add_child(close_button)
	player_summary_label = Label.new()
	player_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_summary_label.add_theme_font_size_override("font_size", TYPE_SCALE.compact)
	player_summary_label.add_theme_constant_override("line_spacing", 4)
	player_summary_label.add_theme_color_override("font_color", COLORS.ink)
	outer.add_child(player_summary_label)
	var rule := HSeparator.new()
	rule.modulate = Color(COLORS.accent, 0.35)
	outer.add_child(rule)
	_build_reference_tabs(outer)


func _build_confirmation_layer() -> void:
	confirmation_layer = Control.new()
	confirmation_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	confirmation_layer.hide()
	add_child(confirmation_layer)
	var shade := ColorRect.new()
	shade.color = Color("050706d9")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(620, 390)
	card.add_theme_stylebox_override("panel", _panel_style(COLORS.panel, 1, 16, COLORS.accent_pressed, 28, 24))
	center.add_child(card)
	confirmation_box = VBoxContainer.new()
	confirmation_box.add_theme_constant_override("separation", 14)
	card.add_child(confirmation_box)


func _build_settings_layer() -> void:
	settings_layer = Control.new()
	settings_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_layer.hide()
	add_child(settings_layer)
	var shade := ColorRect.new()
	shade.color = Color("050706dc")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(500, 420)
	card.add_theme_stylebox_override("panel", _panel_style(COLORS.panel, 1, 14, COLORS.accent_pressed, 28, 24))
	center.add_child(card)
	settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 13)
	card.add_child(settings_box)
	_text(settings_box, "体验设置", false, 25)
	_text(settings_box, "声音与动态效果只影响呈现，不会改变推演结果。", true, 14)
	_audio_slider(settings_box, "主音量", "Master", 82.0)
	_audio_slider(settings_box, "环境", "Ambient", 64.0)
	_audio_slider(settings_box, "事件", "Event", 78.0)
	_audio_slider(settings_box, "界面", "UI", 70.0)
	motion_button = _action_button("动态效果 · 开启", _toggle_motion)
	settings_box.add_child(motion_button)
	settings_box.add_child(_action_button("全部静音", _toggle_sound))
	settings_box.add_child(_button("返回游戏", _close_audio_settings, false))


func _audio_slider(parent: VBoxContainer, label_text: String, bus_name: String, initial_value: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 78
	label.add_theme_font_override("font", medium_font)
	label.add_theme_color_override("font_color", COLORS.ink)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 32
	slider.value_changed.connect(_set_bus_volume.bind(bus_name))
	row.add_child(slider)
	_set_bus_volume(initial_value, bus_name)


func _build_ending_layer() -> void:
	ending_layer = Control.new()
	ending_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	ending_layer.hide()
	add_child(ending_layer)
	ending_background = TextureRect.new()
	ending_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ending_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ending_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ending_layer.add_child(ending_background)
	var shade := ColorRect.new()
	shade.color = Color("030504a8")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_layer.add_child(shade)
	ending_portrait = TextureRect.new()
	ending_portrait.anchor_left = 0.015
	ending_portrait.anchor_right = 0.42
	ending_portrait.anchor_top = 0.04
	ending_portrait.anchor_bottom = 1.0
	ending_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ending_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ending_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ending_layer.add_child(ending_portrait)
	var seal := TextureRect.new()
	seal.anchor_left = 0.70
	seal.anchor_right = 0.92
	seal.anchor_top = 0.05
	seal.anchor_bottom = 0.39
	seal.texture = CausalSealTexture
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seal.modulate = Color(1, 1, 1, 0.24)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ending_layer.add_child(seal)
	ending_box = VBoxContainer.new()
	ending_box.anchor_left = 0.38
	ending_box.anchor_right = 0.93
	ending_box.anchor_top = 0.13
	ending_box.anchor_bottom = 0.94
	ending_box.add_theme_constant_override("separation", 12)
	ending_layer.add_child(ending_box)


func _build_causal_layer() -> void:
	causal_layer = Control.new()
	causal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	causal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	causal_layer.hide()
	add_child(causal_layer)
	causal_background = TextureRect.new()
	causal_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	causal_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	causal_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	causal_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	causal_layer.add_child(causal_background)
	var shade := ColorRect.new()
	shade.color = Color("030504a8")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	causal_layer.add_child(shade)

	causal_portrait = TextureRect.new()
	causal_portrait.anchor_left = 0.015
	causal_portrait.anchor_right = 0.42
	causal_portrait.anchor_top = 0.035
	causal_portrait.anchor_bottom = 1.0
	causal_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	causal_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	causal_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	causal_layer.add_child(causal_portrait)

	var content := VBoxContainer.new()
	content.anchor_left = 0.12
	content.anchor_right = 0.88
	content.anchor_top = 0.34
	content.anchor_bottom = 0.94
	content.add_theme_constant_override("separation", 20)
	causal_layer.add_child(content)
	causal_actor_meta = _text(content, "一念入局", true, 14)
	causal_actor_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	causal_actor_meta.add_theme_color_override("font_color", COLORS.accent)
	causal_actor_meta.hide()
	causal_message = _text(content, "你送出的消息改变了一个人的判断", false, 30)
	causal_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	causal_message.add_theme_font_override("font", display_font)
	causal_message.add_theme_color_override("font_color", Color("ead6a8"))
	causal_message.add_theme_constant_override("line_spacing", 8)

	var timeline := Control.new()
	timeline.custom_minimum_size.y = 190
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(timeline)
	var arrow := TextureRect.new()
	arrow.anchor_left = 0.13
	arrow.anchor_right = 0.87
	arrow.anchor_top = 0.28
	arrow.anchor_bottom = 0.70
	arrow.texture = TimelineArrowTexture
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timeline.add_child(arrow)
	var before_stack := VBoxContainer.new()
	before_stack.anchor_left = 0.0
	before_stack.anchor_right = 0.47
	before_stack.anchor_top = 0.0
	before_stack.anchor_bottom = 1.0
	timeline.add_child(before_stack)
	var before_heading := _text(before_stack, "原本", false, 28)
	before_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	causal_original = _text(before_stack, "原本的安排", false, 18)
	causal_original.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	causal_original.size_flags_vertical = Control.SIZE_EXPAND_FILL
	causal_original.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var now_stack := VBoxContainer.new()
	now_stack.anchor_left = 0.53
	now_stack.anchor_right = 1.0
	now_stack.anchor_top = 0.0
	now_stack.anchor_bottom = 1.0
	timeline.add_child(now_stack)
	now_stack.z_index = 1
	var seal := TextureRect.new()
	seal.anchor_left = 0.67
	seal.anchor_right = 0.91
	seal.anchor_top = -0.12
	seal.anchor_bottom = 0.90
	seal.texture = CausalSealTexture
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seal.modulate = Color(1, 1, 1, 0.74)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timeline.add_child(seal)
	var now_heading := _text(now_stack, "", false, 28)
	now_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	causal_now = _text(now_stack, "新的安排", false, 18)
	causal_now.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	causal_now.size_flags_vertical = Control.SIZE_EXPAND_FILL
	causal_now.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	causal_day = _text(content, "已有决断", true, 15)
	causal_day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	causal_day.add_theme_color_override("font_color", COLORS.accent)
	var continue_button := _ornate_button("记下这次变化", _dismiss_causal)
	continue_button.custom_minimum_size = Vector2(430, 74)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(continue_button)


func _header_value(parent: Container, caption: String) -> Label:
	var group := VBoxContainer.new()
	var small := Label.new()
	small.text = caption
	small.add_theme_font_override("font", medium_font)
	small.add_theme_font_size_override("font_size", TYPE_SCALE.meta)
	small.add_theme_color_override("font_color", COLORS.muted)
	group.add_child(small)
	var value := Label.new()
	value.text = "—"
	value.add_theme_font_override("font", medium_font)
	value.add_theme_font_size_override("font_size", TYPE_SCALE.metric)
	value.add_theme_color_override("font_color", COLORS.ink)
	group.add_child(value)
	parent.add_child(group)
	return value


func _zone(parent: VBoxContainer, title_text: String, ratio: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.add_theme_stylebox_override("panel", _panel_style(Color(COLORS.panel, 0.62), 0, 2, Color.TRANSPARENT, 16, 14))
	parent.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_override("font", display_font)
	title.add_theme_font_size_override("font_size", TYPE_SCALE.section)
	title.add_theme_color_override("font_color", COLORS.accent)
	outer.add_child(title)
	var rule := HSeparator.new()
	rule.modulate = Color(COLORS.accent, 0.35)
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


func _build_reference_tabs(parent: VBoxContainer) -> void:
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", TYPE_SCALE.compact)
	parent.add_child(tabs)
	scene_box = _reference_tab(tabs, "回响")
	clues_box = _reference_tab(tabs, "线索")
	people_box = _reference_tab(tabs, "人物")


func _reference_tab(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 9)
	scroll.add_child(box)
	return box


func _panel_style(color: Color, border: int, radius: int, border_color := COLORS.line, horizontal_margin := 16, vertical_margin := 14) -> StyleBoxFlat:
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


func _tab_style(color: Color, border_color: Color) -> StyleBoxFlat:
	var style := _panel_style(color, 0, 5, border_color, 12, 8)
	style.border_width_bottom = 2 if border_color.a > 0.0 else 0
	return style


func _input_style(color: Color, border_color: Color) -> StyleBoxFlat:
	return _panel_style(color, 1, 6, border_color, 16, 11)


func _button(text_value: String, callback: Callable, secondary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 46
	button.add_theme_font_override("font", medium_font)
	button.add_theme_font_size_override("font_size", TYPE_SCALE.button)
	if secondary:
		button.add_theme_color_override("font_color", COLORS.ink)
		button.add_theme_color_override("font_hover_color", COLORS.ink)
		button.add_theme_color_override("font_pressed_color", COLORS.accent)
		button.add_theme_stylebox_override("normal", _panel_style(COLORS.panel_alt, 1, 6, COLORS.line, 14, 10))
		button.add_theme_stylebox_override("hover", _panel_style(COLORS.panel_hover, 1, 6, COLORS.accent_pressed, 14, 10))
		button.add_theme_stylebox_override("pressed", _panel_style(COLORS.bg_lift, 1, 6, COLORS.accent, 14, 11))
	else:
		button.add_theme_color_override("font_color", COLORS.accent_ink)
		button.add_theme_color_override("font_hover_color", COLORS.accent_ink)
		button.add_theme_color_override("font_pressed_color", COLORS.accent_ink)
		button.add_theme_stylebox_override("normal", _panel_style(COLORS.accent, 0, 6, COLORS.accent, 14, 11))
		button.add_theme_stylebox_override("hover", _panel_style(COLORS.accent_hover, 0, 6, COLORS.accent_hover, 14, 10))
		button.add_theme_stylebox_override("pressed", _panel_style(COLORS.accent_pressed, 0, 6, COLORS.accent_pressed, 14, 12))
	button.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, 2, 7, COLORS.accent_hover, 12, 8))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(COLORS.panel_alt, 0.58), 1, 6, Color(COLORS.line, 0.5), 14, 10))
	button.pressed.connect(callback)
	return button


func _utility_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 36
	button.add_theme_font_override("font", medium_font)
	button.add_theme_font_size_override("font_size", TYPE_SCALE.detail)
	button.add_theme_color_override("font_color", COLORS.muted)
	button.add_theme_color_override("font_hover_color", COLORS.ink)
	button.add_theme_color_override("font_pressed_color", COLORS.accent)
	button.add_theme_stylebox_override("normal", _panel_style(Color.TRANSPARENT, 0, 2, Color.TRANSPARENT, 10, 7))
	button.add_theme_stylebox_override("hover", _panel_style(Color(COLORS.panel_alt, 0.72), 0, 2, Color.TRANSPARENT, 10, 7))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(COLORS.bg_lift, 0.92), 0, 2, Color.TRANSPARENT, 10, 8))
	button.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, 1, 2, COLORS.accent, 9, 6))
	button.add_theme_stylebox_override("disabled", _panel_style(Color.TRANSPARENT, 0, 2, Color.TRANSPARENT, 10, 7))
	button.pressed.connect(callback)
	return button


func _mode_button(text_value: String, callback: Callable) -> Button:
	var button := _utility_button(text_value, callback)
	button.add_theme_font_size_override("font_size", TYPE_SCALE.compact)
	button.custom_minimum_size.y = 38
	return button


func _style_mode_state(button: Button, active: bool) -> void:
	button.add_theme_color_override("font_color", COLORS.accent if active else COLORS.muted)
	var normal := _panel_style(Color.TRANSPARENT, 0, 0, Color.TRANSPARENT, 12, 7)
	normal.border_width_bottom = 2 if active else 0
	normal.border_color = COLORS.accent
	button.add_theme_stylebox_override("normal", normal)


func _action_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 42
	button.add_theme_font_override("font", medium_font)
	button.add_theme_font_size_override("font_size", TYPE_SCALE.button)
	button.add_theme_color_override("font_color", COLORS.ink)
	button.add_theme_color_override("font_hover_color", COLORS.ink)
	button.add_theme_color_override("font_pressed_color", COLORS.accent)
	var normal := _panel_style(Color(COLORS.panel_alt, 0.38), 0, 2, Color.TRANSPARENT, 14, 9)
	normal.border_width_left = 2
	normal.border_color = Color(COLORS.line, 0.84)
	var hover := _panel_style(Color(COLORS.panel_hover, 0.78), 0, 2, Color.TRANSPARENT, 14, 9)
	hover.border_width_left = 2
	hover.border_color = COLORS.accent
	var pressed := _panel_style(Color(COLORS.bg_lift, 0.92), 0, 2, Color.TRANSPARENT, 14, 10)
	pressed.border_width_left = 2
	pressed.border_color = COLORS.accent_pressed
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, 1, 2, COLORS.accent_hover, 12, 7))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(COLORS.panel_alt, 0.26), 0, 2, Color.TRANSPARENT, 14, 9))
	button.pressed.connect(callback)
	return button


func _category_button(text_value: String, category: String, active: bool) -> Button:
	var marker := "当前" if active else "展开"
	var button := _utility_button("%s　·　%s" % [text_value, marker], _set_action_category.bind(category))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 34
	button.add_theme_color_override("font_color", COLORS.accent if active else COLORS.muted)
	return button


func _ornate_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.add_theme_font_override("font", display_font)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("e5c47d"))
	button.add_theme_color_override("font_hover_color", COLORS.ink)
	button.add_theme_color_override("font_pressed_color", COLORS.accent_pressed)
	button.add_theme_stylebox_override("normal", _panel_style(Color("080b09b8"), 0, 0, Color.TRANSPARENT, 20, 14))
	button.add_theme_stylebox_override("hover", _panel_style(Color("171c16e6"), 0, 0, Color.TRANSPARENT, 20, 14))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("050706f2"), 0, 0, Color.TRANSPARENT, 20, 15))
	button.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, 1, 2, COLORS.accent_hover, 18, 12))
	var frame := TextureRect.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.texture = DecisionFrameTexture
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.modulate = Color(1, 1, 1, 0.90)
	button.add_child(frame)
	button.move_child(frame, 0)
	button.pressed.connect(callback)
	return button


func _style_menu_button(button: MenuButton) -> void:
	button.add_theme_font_override("font", medium_font)
	button.add_theme_font_size_override("font_size", TYPE_SCALE.button)
	button.add_theme_color_override("font_color", COLORS.ink)
	button.add_theme_color_override("font_hover_color", COLORS.ink)
	button.add_theme_color_override("font_pressed_color", COLORS.accent)
	var normal := _panel_style(Color(COLORS.panel_alt, 0.38), 0, 2, Color.TRANSPARENT, 14, 9)
	normal.border_width_left = 2
	normal.border_color = Color(COLORS.line, 0.84)
	var hover := _panel_style(Color(COLORS.panel_hover, 0.78), 0, 2, Color.TRANSPARENT, 14, 9)
	hover.border_width_left = 2
	hover.border_color = COLORS.accent
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, 1, 2, COLORS.accent_hover, 12, 7))
	var popup := button.get_popup()
	popup.add_theme_color_override("font_color", COLORS.ink)
	popup.add_theme_color_override("font_hover_color", COLORS.accent_ink)
	popup.add_theme_stylebox_override("panel", _panel_style(COLORS.panel_alt, 1, 7, COLORS.line, 8, 8))
	popup.add_theme_stylebox_override("hover", _panel_style(COLORS.accent, 0, 4, COLORS.accent, 8, 6))


func _text(parent: Container, value: String, muted := false, size := TYPE_SCALE.body) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if size >= 24:
		label.add_theme_font_override("font", display_font)
	elif size >= 17 or size <= TYPE_SCALE.meta:
		label.add_theme_font_override("font", medium_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", COLORS.muted if muted else COLORS.ink)
	if size <= TYPE_SCALE.body:
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
	for child in node.get_children():
		_set_buttons_disabled(child, disabled)


func _operation_label(operation: String) -> String:
	var labels := {
		"health": "正在连接规则服务",
		"new": "正在进入黑风谷",
		"load": "正在读取旅程",
		"save": "正在保存",
		"autosave": "正在自动保存",
		"action": "正在推演行动结果",
		"quit": "正在返回",
	}
	return str(labels.get(operation, "处理中"))


func _request(operation: String, method: HTTPClient.Method, path: String, payload := {}) -> void:
	if pending_operation != "" or operation == "action" and presentation_busy:
		return
	pending_operation = operation
	_set_buttons_disabled(self, true)
	if footer_label:
		footer_label.text = _operation_label(operation) + "…"
	if start_layer.visible and connection_label:
		connection_label.text = "正在确认旅途入口…"
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := "" if method == HTTPClient.METHOD_GET else JSON.stringify(payload)
	var error := http.request(API_BASE + path, headers, method, body)
	if error != OK:
		pending_operation = ""
		_set_buttons_disabled(self, false)
		_show_error("无法发送请求（%s）" % error)


func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var operation := pending_operation
	pending_operation = ""
	_set_buttons_disabled(self, presentation_busy)
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if response_code < 200 or response_code >= 300 or not parsed is Dictionary:
		var message := "本地服务无响应，请先运行项目启动脚本。"
		if parsed is Dictionary and parsed.get("error", {}) is Dictionary:
			message = str(parsed.get("error", {}).get("message", message))
		_show_error(message)
		return

	if connection_label:
		connection_label.text = ""
		connection_label.add_theme_color_override("font_color", COLORS.success)
		retry_button.hide()
	if operation == "health":
		if footer_label:
			footer_label.text = ""
		return
	if operation == "quit":
		_show_start()
		return
	if parsed.has("view") and operation not in ["autosave", "save"]:
		var previous_view := view_before_action if operation == "action" else current_view
		current_view = parsed["view"]
		if operation == "action":
			_apply_feedback_actor_state(current_view.get("last_turn", {}))
		_show_game()
		_render_view()
		if operation == "action":
			_play_action_presentation(previous_view, current_view)
		view_before_action = {}
	if operation == "action" and autosave_after_action:
		autosave_after_action = false
		_request("autosave", HTTPClient.METHOD_POST, "/game/save", {"slot": AUTOSAVE_SLOT})
	elif operation == "autosave":
		_show_footer_message("已自动保存")
	elif operation == "save":
		_show_footer_message("存档已保存")
	else:
		footer_label.text = ""


func _show_footer_message(message: String) -> void:
	footer_label.text = message
	footer_label.add_theme_color_override("font_color", COLORS.muted)
	_clear_footer_message_later(message)


func _play_action_presentation(previous_view: Dictionary, next_view: Dictionary) -> void:
	presentation_director.cancel()
	if ending_layer.visible:
		causal_layer.hide()
		return
	var feedback: Dictionary = next_view.get("last_turn", {})
	var cue: Dictionary = feedback.get("presentation", {})
	var previous_location: Dictionary = previous_view.get("location", {})
	var next_location: Dictionary = next_view.get("location", {})
	var from_id := str(previous_location.get("id", ""))
	var to_id := str(next_location.get("id", ""))
	if from_id != "" and to_id != "" and from_id != to_id:
		presentation_busy = true
		_set_buttons_disabled(self, true)
		_set_visual_mode("map")
		place_label.text = "%s → %s" % [previous_location.get("name", ""), next_location.get("name", "")]
		phase_label.text = "赶路中"
		audio_director.play_cue("travel", int(cue.get("intensity", 2)))
		var callback := _finish_travel_presentation.bind(feedback, previous_location, next_location)
		world_map_view.travel_finished.connect(callback, CONNECT_ONE_SHOT)
		world_map_view.animate_travel(from_id, to_id, int(previous_view.get("day", 0)), int(next_view.get("day", 0)))
		return
	_apply_presentation_cue(cue)
	if _has_causal_change(feedback):
		_present_causal_change(feedback, next_location)
		return
	presentation_director.present(feedback, str(previous_location.get("name", "")), str(next_location.get("name", "")))


func _finish_travel_presentation(feedback: Dictionary, previous_location: Dictionary, next_location: Dictionary) -> void:
	presentation_busy = false
	_set_buttons_disabled(self, pending_operation != "")
	_set_visual_mode("location")
	day_label.text = "第 %d / %d 日" % [maxi(1, int(current_view.get("day", 0))), int(current_view.get("duration", 0))]
	place_label.text = str(next_location.get("name", "未知"))
	var phase := str(current_view.get("phase", ""))
	phase_label.text = "准备" if phase == "" else phase
	location_stage.play_establish()
	if _has_causal_change(feedback):
		_present_causal_change(feedback, next_location)
	else:
		presentation_director.present(feedback, str(previous_location.get("name", "")), str(next_location.get("name", "")))


func _has_causal_change(feedback: Dictionary) -> bool:
	var influences = feedback.get("influence", [])
	if not influences is Array or influences.is_empty():
		return false
	for influence in influences:
		if influence.get("changes", []) is Array and not influence.get("changes", []).is_empty():
			return true
	return false


func _present_causal_change(feedback: Dictionary, location: Dictionary) -> void:
	var influences: Array = feedback.get("influence", [])
	if influences.is_empty():
		return
	var influence: Dictionary = influences[0]
	var changes: Array = influence.get("changes", [])
	if changes.is_empty():
		return
	var change: Dictionary = changes[0]
	var actor_name := str(influence.get("actor_name", "有人"))
	var actor_id := _actor_id_by_name(actor_name)
	if actor_id != "":
		causal_actor_id_by_name[actor_name] = actor_id
		last_causal_actor_id = actor_id
	elif causal_actor_id_by_name.has(actor_name):
		actor_id = str(causal_actor_id_by_name[actor_name])
	var fact_claim := str(influence.get("fact_claim", "你送出的消息"))
	var causal_key := actor_name
	var previous_count := int(causal_change_count_by_actor.get(causal_key, 0))
	causal_change_count_by_actor[causal_key] = previous_count + 1
	var change_day := int(change.get("day", feedback.get("day", current_view.get("day", 0))))
	if previous_count > 0:
		var ripple := feedback.duplicate(true)
		ripple["action"] = "余波继续 · %s" % actor_name
		ripple["messages"] = ["第 %d 日 · %s不再%s，转而%s。" % [change_day, actor_name, change.get("without_information", "照原计划行事"), change.get("with_information", "改变安排")]]
		presentation_director.present(ripple, "", "")
		audio_director.play_cue("focus", 2)
		return
	var profile: ActorVisualProfile = presentation_registry.actor_profile(actor_id)
	var location_profile: LocationVisualProfile = presentation_registry.location_profile(str(location.get("scene_key", "")))
	causal_background.texture = location_profile.background if location_profile and location_profile.background else null
	causal_portrait.texture = profile.portrait("decisive") if profile else null
	causal_actor_meta.text = "%s · 已有决断" % actor_name
	causal_message.text = "你告知%s：%s" % [actor_name, fact_claim]
	causal_original.text = str(change.get("without_information", "原有安排"))
	causal_now.text = str(change.get("with_information", "新的安排"))
	causal_day.text = "第 %d 日 · 由原本到现在，已有决断" % change_day
	causal_layer.modulate = Color(1, 1, 1, 0) if motion_enabled else Color.WHITE
	causal_layer.show()
	var portrait_tint := Color(0.78, 0.78, 0.74, 1.0)
	causal_portrait.modulate = Color(portrait_tint, 0) if motion_enabled else portrait_tint
	causal_portrait.position.x = -32 if motion_enabled else 0
	if motion_enabled:
		var tween := create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(causal_layer, "modulate", Color.WHITE, 0.34)
		tween.tween_property(causal_portrait, "modulate", portrait_tint, 0.48).set_delay(0.10)
		tween.tween_property(causal_portrait, "position:x", 0.0, 0.62).set_delay(0.08)
	audio_director.play_cue("focus", 3)


func _dismiss_causal() -> void:
	audio_director.play_ui()
	causal_layer.hide()
	causal_layer.modulate = Color.WHITE


func _apply_presentation_cue(cue: Dictionary) -> void:
	if cue.is_empty():
		return
	var kind := str(cue.get("kind", "time"))
	var intensity := int(cue.get("intensity", 1))
	audio_director.play_cue(kind, intensity)
	if kind in ["reveal", "danger", "focus", "acquire"]:
		location_stage.play_reveal(intensity)
	if kind == "actor_focus":
		_focus_portrait(str(cue.get("subject_id", "")))


func _apply_feedback_actor_state(feedback: Dictionary) -> void:
	if feedback.is_empty():
		return
	var action_id := str(feedback.get("action_id", ""))
	if action_id.begins_with("tell:"):
		var parts := action_id.split(":")
		if parts.size() >= 2:
			actor_expression_by_id[str(parts[1])] = "troubled"
	for influence in feedback.get("influence", []):
		var actor_id := _actor_id_by_name(str(influence.get("actor_name", "")))
		if actor_id != "":
			actor_expression_by_id[actor_id] = "decisive"


func _on_travel_day_changed(day: int) -> void:
	day_label.text = "第 %d / %d 日" % [maxi(1, day), int(current_view.get("duration", 0))]


func _clear_footer_message_later(expected: String) -> void:
	await get_tree().create_timer(2.5).timeout
	if footer_label.text == expected:
		footer_label.text = ""


func _new_game() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name == "":
		player_name = "无名修士"
	actor_expression_by_id.clear()
	causal_change_count_by_actor.clear()
	causal_actor_id_by_name.clear()
	last_causal_actor_id = ""
	active_action_category = ""
	_reset_action_focus()
	_set_visual_mode("map")
	_request("new", HTTPClient.METHOD_POST, "/game/new", {"player_name": player_name})


func _retry_connection() -> void:
	connection_label.text = "正在重新确认旅途入口…"
	connection_label.add_theme_color_override("font_color", COLORS.muted)
	_request("health", HTTPClient.METHOD_GET, "/health")


func _load_game() -> void:
	_set_visual_mode("map")
	_request("load", HTTPClient.METHOD_POST, "/game/load", {"slot": AUTOSAVE_SLOT})


func _save_game() -> void:
	_request("save", HTTPClient.METHOD_POST, "/game/save", {"slot": AUTOSAVE_SLOT})


func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	sound_button.text = "声音" if sound_enabled else "声音 · 静音"
	audio_director.set_enabled(sound_enabled)


func _toggle_motion() -> void:
	motion_enabled = not motion_enabled
	if motion_button:
		motion_button.text = "动态效果 · 开启" if motion_enabled else "动态效果 · 精简"
	if world_map_view:
		world_map_view.set_motion_enabled(motion_enabled)
	if presentation_director:
		presentation_director.motion_enabled = motion_enabled


func _open_audio_settings() -> void:
	audio_director.play_ui()
	settings_layer.show()


func _close_audio_settings() -> void:
	audio_director.play_ui()
	settings_layer.hide()


func _open_journal() -> void:
	audio_director.play_ui()
	if not motion_enabled:
		journal_panel.position.x = 0
		journal_layer.modulate = Color.WHITE
		journal_layer.show()
		return
	journal_panel.position.x = 42
	journal_layer.modulate = Color(1, 1, 1, 0)
	journal_layer.show()
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(journal_layer, "modulate", Color.WHITE, 0.22)
	tween.tween_property(journal_panel, "position:x", 0.0, 0.28)


func _close_journal() -> void:
	audio_director.play_ui()
	journal_layer.hide()
	journal_panel.position.x = 0


func _set_bus_volume(value: float, bus_name: String) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, value <= 0.0)
	if value > 0.0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value / 100.0))


func _return_to_start() -> void:
	_request("quit", HTTPClient.METHOD_POST, "/game/quit")


func _execute_action(action_id: String) -> void:
	view_before_action = current_view.duplicate(true)
	autosave_after_action = true
	_request("action", HTTPClient.METHOD_POST, "/game/action", {"action_id": action_id})


func _show_start() -> void:
	current_view = {}
	selected_action = {}
	available_actions_cache = []
	selected_map_location_id = ""
	rendered_location_id = ""
	view_before_action = {}
	presentation_busy = false
	causal_change_count_by_actor.clear()
	causal_actor_id_by_name.clear()
	last_causal_actor_id = ""
	active_action_category = ""
	_reset_action_focus()
	game_layer.hide()
	journal_layer.hide()
	confirmation_layer.hide()
	settings_layer.hide()
	causal_layer.hide()
	ending_layer.hide()
	if presentation_director:
		presentation_director.cancel()
	start_layer.show()


func _show_game() -> void:
	start_layer.hide()
	game_layer.show()


func _show_error(message: String) -> void:
	if start_layer.visible:
		connection_label.text = message
		connection_label.add_theme_color_override("font_color", COLORS.danger)
		retry_button.show()
	else:
		footer_label.text = message
		footer_label.add_theme_color_override("font_color", COLORS.danger)


func _render_view() -> void:
	var player: Dictionary = current_view.get("player", {})
	var location: Dictionary = current_view.get("location", {})
	var day := int(current_view.get("day", 0))
	day_label.text = "第 %d / %d 日" % [maxi(1, day), int(current_view.get("duration", 0))]
	place_label.text = str(location.get("name", "未知"))
	var phase := str(current_view.get("phase", ""))
	phase_label.text = "准备" if phase == "" else phase
	var travel = current_view.get("travel", null)
	footer_label.add_theme_color_override("font_color", COLORS.muted)
	var available_actions = current_view.get("available_actions", [])
	if not available_actions is Array:
		available_actions = []
	available_actions_cache = available_actions
	var known_actors: Array = current_view.get("known_actors", [])
	var known_facts: Array = current_view.get("known_facts", [])
	var guidance: Array = current_view.get("guidance", [])
	_reconcile_action_focus(known_actors, known_facts)
	var location_id := str(location.get("id", ""))
	if rendered_location_id != location_id:
		selected_map_location_id = location_id
		rendered_location_id = location_id
		stage_actor_id = ""
		stage_actor_name = ""
	_reconcile_stage_actor(known_actors)
	timing_label.text = _known_timing(known_facts)
	objective_label.text = "下一节点 · %s" % (guidance[0] if not guidance.is_empty() else "根据已知线索选择调查、交涉、准备或等待")
	_render_player(player)
	_render_clues(known_facts, available_actions_cache)
	_render_scene(current_view.get("recent_events", []), guidance.slice(1), travel, current_view.get("last_turn", null), str(player.get("name", "旅人")))
	_render_people(known_actors, available_actions_cache)
	_render_actions(available_actions_cache)
	_render_world_map(current_view.get("world_map", {}), location, available_actions_cache)
	_render_location_stage(location, known_actors, available_actions_cache)
	var ending = current_view.get("ending", null)
	if bool(current_view.get("resolved", false)) or bool(current_view.get("ended", false)) or ending is Dictionary:
		_render_ending(ending if ending is Dictionary else {})


func _set_visual_mode(mode: String) -> void:
	var previous_mode := visual_mode
	visual_mode = mode
	if mode == "map" and (focused_actor_id != "" or focused_fact_id != ""):
		_reset_action_focus()
		if actions_box:
			_render_actions(available_actions_cache)
	if map_panel:
		map_panel.visible = mode == "map"
	if location_panel:
		location_panel.visible = mode == "location"
	if map_mode_button:
		map_mode_button.text = "区域地图"
		_style_mode_state(map_mode_button, mode == "map")
	if location_mode_button:
		location_mode_button.text = "当前地点"
		_style_mode_state(location_mode_button, mode == "location")
	if mode == "location" and previous_mode != "location" and location_stage:
		location_stage.play_establish.call_deferred()


func _render_world_map(world_map, current_location: Dictionary, actions: Array) -> void:
	if not world_map is Dictionary:
		world_map = {}
	world_map_view.set_map(world_map, selected_map_location_id)
	_render_map_detail(world_map, current_location, actions)


func _on_map_location_selected(location_id: String) -> void:
	selected_map_location_id = location_id
	_render_map_detail(current_view.get("world_map", {}), current_view.get("location", {}), available_actions_cache)


func _render_map_detail(world_map: Dictionary, current_location: Dictionary, actions: Array) -> void:
	_clear(map_detail_box)
	var selected := _map_location(world_map.get("locations", []), selected_map_location_id)
	if selected.is_empty():
		_text(map_detail_box, "选择地点查看路线", true, 14)
		return
	var title_line := _text(map_detail_box, "%s · %s" % [selected.get("name", "未知地点"), "安全落脚点" if bool(selected.get("safe", false)) else "危险区域"], false, 16)
	title_line.add_theme_color_override("font_color", COLORS.accent if bool(selected.get("current", false)) else COLORS.ink)
	_text(map_detail_box, str(selected.get("description", "尚无公开地点资料")), true, 13)
	if bool(selected.get("contest", false)):
		var contest_line := _text(map_detail_box, "核心目标 · 青髓芝争夺将在这里落定", false, 13)
		contest_line.add_theme_color_override("font_color", COLORS.accent)
	match str(selected.get("scene_key", "")):
		"valley_edge":
			_text(map_detail_box, "推进阶段 · 第一段：谷口判断", true, 13)
		"inner_valley":
			_text(map_detail_box, "推进阶段 · 第二段：核心争夺", true, 13)
	if bool(selected.get("current", false)):
		var enter_button := _action_button("进入当前地点场景", _set_visual_mode.bind("location"))
		enter_button.custom_minimum_size.y = 38
		map_detail_box.add_child(enter_button)
		return
	var route := _current_map_route(world_map.get("routes", []), str(current_location.get("id", "")), selected_map_location_id)
	if route.is_empty():
		_text(map_detail_box, "这里不与当前位置直接相连，需要从相邻地点转进。", true, 13)
		return
	var route_status := str(route.get("status", "known"))
	if route_status == "available":
		var action := _action_by_id(actions, str(route.get("action_id", "")))
		if not action.is_empty():
			var move_button := _button("动身 · %d 日 · 危险 %d" % [int(route.get("duration", 1)), int(route.get("danger", 0))], _consider_action.bind(action), false)
			move_button.custom_minimum_size.y = 40
			map_detail_box.add_child(move_button)
	elif route_status == "blocked":
		var blockers := _joined_action_values(route.get("blockers", []))
		var blocked_line := _text(map_detail_box, "路线受阻 · %s" % blockers, false, 13)
		blocked_line.add_theme_color_override("font_color", COLORS.danger)


func _render_location_stage(location: Dictionary, actors: Array, actions: Array) -> void:
	location_stage.set_location(location)
	audio_director.set_scene(str(location.get("scene_key", "")))
	_render_actor_portrait(actors)
	_clear(location_detail_box)
	var phase_marker := ""
	match str(location.get("scene_key", "")):
		"valley_edge":
			phase_marker = "第一段 · 谷口判断"
		"inner_valley":
			phase_marker = "第二段 · 核心争夺"
	var place_title := "%s · %s" % [location.get("name", "未知地点"), "安稳" if bool(location.get("safe", false)) else "险地"]
	if phase_marker != "":
		place_title += " · %s" % phase_marker
	if not actors.is_empty():
		place_title += " · 在场 %d 人" % actors.size()
	var place_line := _text(location_detail_box, place_title, false, 17)
	place_line.add_theme_color_override("font_color", COLORS.accent)
	_text(location_detail_box, str(location.get("atmosphere", location.get("description", ""))), true, 13)
	_render_stage_people(actors, actions)


func _render_stage_people(actors: Array, actions: Array) -> void:
	_clear(stage_people_box)
	if actors.is_empty():
		_text(stage_people_box, "此地暂时无人可交涉", true, 13)
		return
	for index in actors.size():
		var actor: Dictionary = actors[index]
		var actor_id := str(actor.get("id", ""))
		var actor_name := str(actor.get("name", "无名者"))
		var clue_count := _count_tell_actions(actions, actor_id, "")
		var selected := actor_id == stage_actor_id
		var button_text := ("◆ " if selected else "") + actor_name
		if clue_count > 0:
			button_text += " · %d 条" % clue_count
		var button := _action_button(button_text, _focus_actor_from_stage.bind(actor_id, actor_name))
		button.custom_minimum_size = Vector2(148, 40)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = "%s\n%s" % [actor.get("public_role", "可交谈人物"), actor.get("public_profile", "")]
		if selected:
			var profile: ActorVisualProfile = presentation_registry.actor_profile(actor_id)
			var actor_accent := profile.accent_color if profile else COLORS.accent
			button.add_theme_color_override("font_color", COLORS.ink)
			button.add_theme_stylebox_override("normal", _panel_style(COLORS.panel_hover, 1, 6, actor_accent.lerp(COLORS.accent, 0.35), 12, 7))
		stage_people_box.add_child(button)


func _render_actor_portrait(actors: Array) -> void:
	actor_portrait_frame.hide()
	actor_portrait.texture = null
	var actor := _selected_stage_actor(actors)
	if actor.is_empty():
		return
	var actor_id := str(actor.get("id", ""))
	_show_actor_portrait(actor, str(actor_expression_by_id.get(actor_id, "neutral")))


func _focus_portrait(actor_id: String, expression_override := "") -> void:
	var actor := _actor_by_id(current_view.get("known_actors", []), actor_id)
	if actor.is_empty():
		actor = {"id": actor_id, "name": stage_actor_name, "public_role": "可交谈人物"}
	stage_actor_id = actor_id
	stage_actor_name = str(actor.get("name", stage_actor_name))
	var expression := expression_override
	if expression == "":
		expression = str(actor_expression_by_id.get(actor_id, "alert"))
	_show_actor_portrait(actor, expression)


func _show_actor_portrait(actor: Dictionary, expression: String) -> void:
	var actor_id := str(actor.get("id", ""))
	var profile: ActorVisualProfile = presentation_registry.actor_profile(actor_id)
	if profile == null or profile.neutral == null:
		return
	var portrait_texture := profile.portrait(expression)
	if portrait_texture == null:
		return
	actor_portrait.texture = portrait_texture
	actor_portrait_name.text = str(actor.get("name", "无名者"))
	var role := str(actor.get("public_role", "可交谈人物"))
	var faction := str(actor.get("faction", ""))
	var expression_names := {"neutral": "平静", "alert": "警觉", "troubled": "权衡中", "decisive": "已有决断"}
	var meta_parts: Array[String] = [role]
	if faction != "":
		meta_parts.append(faction)
	if expression != "neutral":
		meta_parts.append(str(expression_names.get(expression, expression)))
	actor_portrait_meta.text = " · ".join(meta_parts)
	actor_portrait_frame.tooltip_text = "%s · %s" % [actor_portrait_name.text, role]
	actor_portrait_frame.add_theme_stylebox_override("panel", _panel_style(Color("101612e8"), 1, 8, profile.accent_color.lerp(COLORS.accent, 0.4), 4, 4))
	actor_portrait_frame.show()
	var target_modulate := Color.WHITE
	match expression:
		"alert":
			target_modulate = Color("f0eadf")
		"troubled":
			target_modulate = Color("cbd3cb")
		"decisive":
			target_modulate = Color("fff0c8")
	actor_portrait.modulate = Color(target_modulate, 0.25)
	actor_portrait.scale = Vector2(0.985, 0.985)
	var portrait_tween := create_tween().set_parallel(true)
	portrait_tween.tween_property(actor_portrait, "modulate", target_modulate, 0.28)
	portrait_tween.tween_property(actor_portrait, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _selected_stage_actor(actors: Array) -> Dictionary:
	var selected := _actor_by_id(actors, stage_actor_id)
	if not selected.is_empty() and presentation_registry.has_actor(stage_actor_id):
		return selected
	for actor in actors:
		var actor_id := str(actor.get("id", ""))
		if presentation_registry.has_actor(actor_id):
			stage_actor_id = actor_id
			stage_actor_name = str(actor.get("name", "无名者"))
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
	for actor in current_view.get("known_actors", []):
		if str(actor.get("name", "")) == actor_name:
			return str(actor.get("id", ""))
	return ""


func _reconcile_stage_actor(actors: Array) -> void:
	if stage_actor_id != "" and not _actor_by_id(actors, stage_actor_id).is_empty():
		return
	stage_actor_id = ""
	stage_actor_name = ""
	_selected_stage_actor(actors)
	actor_portrait_frame.pivot_offset = actor_portrait_frame.size * 0.5
	actor_portrait_frame.scale = Vector2(0.965, 0.965)
	actor_portrait_frame.modulate = Color(1, 1, 1, 0.45)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(actor_portrait_frame, "scale", Vector2.ONE, 0.28)
	tween.tween_property(actor_portrait_frame, "modulate", Color.WHITE, 0.22)


func _focus_actor_from_stage(actor_id: String, actor_name: String) -> void:
	_set_visual_mode("location")
	audio_director.play_ui()
	_focus_actor_actions(actor_id, actor_name)


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
	var state := "空闲"
	if bool(player.get("busy", false)):
		state = "%s · 至第 %d 日" % [str(player.get("busy_action", "行动中")), int(player.get("busy_until", 0))]
	var resources: Dictionary = player.get("resources", {})
	var items: Array = player.get("items", [])
	var item_parts: Array[String] = []
	for item in items:
		item_parts.append("%s×%d" % [item.get("name", "物品"), int(item.get("amount", 1))])
	var inventory := "无关键物品" if item_parts.is_empty() else "、".join(item_parts)
	player_summary_label.text = "%s　·　%s\n战力 %s　助力 %s　伤势 %d　灵石 %s\n随身所持　%s" % [
		player.get("name", "旅人"), state, resources.get("combat", 0), resources.get("support", 0),
		int(player.get("injury", 0)), resources.get("spirit_stones", 0), inventory,
	]


func _known_timing(clues: Array) -> String:
	var best: Dictionary = {}
	for clue in clues:
		if "成熟" not in str(clue.get("claim", "")):
			continue
		if best.is_empty() or int(clue.get("confidence", 0)) > int(best.get("confidence", 0)):
			best = clue
	if best.is_empty():
		return "尚未查明"
	var timing := str(best.get("claim", "未知"))
	timing = timing.replace("青髓芝将在", "").replace("成熟", "")
	var confidence := int(best.get("confidence", 0))
	var status := "已核实" if confidence >= 3 else ("较可信" if confidence == 2 else "传闻")
	return "%s · %s" % [timing, status]


func _render_clues(clues: Array, actions: Array) -> void:
	_clear(clues_box)
	if clues.is_empty():
		_text(clues_box, "尚未掌握可用线索。", true)
		return
	for clue in clues:
		_text(clues_box, str(clue.get("claim", "未知传言")), false, 16)
		var confidence := int(clue.get("confidence", 0))
		var status := "已核实" if confidence >= 3 else ("较可信" if confidence == 2 else "未经核实")
		if bool(clue.get("contested", false)):
			status += " · 与旧说法冲突"
		_text(clues_box, "%s · 来源：%s" % [status, clue.get("source", "未知")], true, 14)
		var fact_id := str(clue.get("fact_id", ""))
		var target_count := _count_tell_actions(actions, "", fact_id)
		if target_count > 0:
			var link := _action_button("传播 · %d 名可选人物" % target_count, _focus_fact_actions.bind(fact_id, str(clue.get("claim", "未知传言"))))
			clues_box.add_child(link)
		else:
			_text(clues_box, "当前地点没有新的传播对象", true, TYPE_SCALE.meta)


func _render_scene(events: Array, guidance: Array, travel, feedback, player_name: String) -> void:
	_clear(scene_box)
	if feedback is Dictionary:
		var change_heading := _text(scene_box, "刚刚发生", true, 14)
		change_heading.add_theme_color_override("font_color", COLORS.accent)
		_render_feedback_into(scene_box, feedback)
		var separator := HSeparator.new()
		separator.modulate = COLORS.line
		scene_box.add_child(separator)
	if travel is Dictionary:
		_render_travel_readiness(travel)
	for tip in guidance:
		_text(scene_box, "指引 · %s" % tip, true)
	if events.is_empty():
		if not feedback is Dictionary:
			_text(scene_box, "四下暂时没有新的公开动静。", true)
		return
	var event_heading := _text(scene_box, "最近变化", true, 14)
	event_heading.add_theme_color_override("font_color", COLORS.accent)
	for index in range(events.size() - 1, -1, -1):
		var event = events[index]
		if feedback is Dictionary and int(event.get("day", -1)) == int(feedback.get("day", -2)) and str(event.get("actor_name", "")) == player_name:
			continue
		_text(scene_box, "第 %d 日 · %s" % [int(event.get("day", 0)), event.get("description", "局势变化")])


func _render_travel_readiness(travel: Dictionary) -> void:
	var panel := PanelContainer.new()
	var ready := bool(travel.get("ready", false))
	panel.add_theme_stylebox_override("panel", _panel_style(COLORS.panel_alt, 1, 7, Color(COLORS.success if ready else COLORS.danger, 0.7), 13, 11))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	panel.add_child(content)
	var readiness := "行装已齐" if ready else "仍需准备"
	var readiness_line := _text(content, "黑风谷行装 · %s" % readiness, false, 17)
	readiness_line.add_theme_color_override("font_color", COLORS.success if ready else COLORS.danger)
	var route: Array = travel.get("route", [])
	if not route.is_empty():
		_text(content, "路线 · %s · 约 %d 日" % [" → ".join(route), int(travel.get("travel_days", 0))], true, 13)
	else:
		_text(content, "目的地 · %s" % travel.get("destination", "未知"), true, 13)
	var checks: Array = travel.get("checks", [])
	for check in checks:
		var check_ready := bool(check.get("ready", false))
		var marker := "已备" if check_ready else "未备"
		var check_line := _text(content, "%s · %s" % [marker, check.get("label", "路线条件")], false, 13)
		check_line.add_theme_color_override("font_color", COLORS.success if check_ready else COLORS.danger)
	var timing := str(travel.get("timing", ""))
	if timing != "":
		var timing_line := _text(content, "时机 · %s" % timing, true, 13)
		if timing.contains("来不及"):
			timing_line.add_theme_color_override("font_color", COLORS.danger)
	scene_box.add_child(panel)


func _render_people(actors: Array, actions: Array) -> void:
	_clear(people_box)
	if actors.is_empty():
		_text(people_box, "此地没有可交谈的人。", true)
		return
	for index in actors.size():
		var actor: Dictionary = actors[index]
		_text(people_box, "%s · %s" % [actor.get("name", "无名者"), actor.get("public_role", "可交谈人物")], false, 16)
		_text(people_box, str(actor.get("faction", "散修")), true, 14)
		_text(people_box, str(actor.get("public_profile", "公开资料尚未收集")), true, 14)
		var focus: Array = actor.get("public_focus", [])
		if not focus.is_empty():
			_text(people_box, "公开关注 · %s" % "、".join(focus), false, 14)
		_text(people_box, "传播风险 · %s" % actor.get("public_risk", "尚不了解"), true, 14)
		var actor_id := str(actor.get("id", ""))
		var actor_name := str(actor.get("name", "无名者"))
		var clue_count := _count_tell_actions(actions, actor_id, "")
		var link_text := "查看并交涉 · %d 条可用线索" % clue_count if clue_count > 0 else "查看人物 · 暂无线索可告知"
		var link := _action_button(link_text, _focus_actor_from_reference.bind(actor_id, actor_name))
		people_box.add_child(link)
		if index < actors.size() - 1:
			var separator := HSeparator.new()
			separator.modulate = Color(COLORS.line, 0.7)
			people_box.add_child(separator)


func _render_actions(actions: Array) -> void:
	_clear(actions_box)
	var focused_actions := _focused_information_actions(actions)
	if focused_actor_id != "":
		_text(actions_box, "与%s交涉" % focused_actor_name, false, 18)
		_render_focused_actor_summary(focused_actions)
		actions_box.add_child(_utility_button("返回全部行动", _clear_action_focus))
		if focused_actions.is_empty():
			_text(actions_box, "目前没有新的线索可告知；已经送达的内容不会重复出现。", true)
			return
		_add_focused_information_actions(focused_actions)
		return
	if focused_fact_id != "":
		_text(actions_box, "传播线索", false, 18)
		_text(actions_box, focused_fact_claim, true, 14)
		actions_box.add_child(_utility_button("返回全部行动", _clear_action_focus))
		if focused_actions.is_empty():
			_text(actions_box, "当前地点已没有尚未收到这条线索的人。", true)
			return
		_add_focused_information_actions(focused_actions)
		return
	if actions.is_empty():
		_text(actions_box, "当前没有可执行行动。", true)
		return
	var grouped := {}
	for action in actions:
		var category := str(action.get("category", "other"))
		if not grouped.has(category):
			grouped[category] = []
		grouped[category].append(action)
	var order := ["investigate", "trade", "move", "information", "self", "time", "other"]
	var category_names := {
		"investigate": "查证与探索",
		"information": "交涉与消息",
		"trade": "坊市交易",
		"move": "动身前往",
		"self": "自身安排",
		"time": "等待与推进",
		"other": "其他",
	}
	var first_category := ""
	for category in order:
		if grouped.has(category):
			first_category = category
			break
	if active_action_category != "" and not grouped.has(active_action_category):
		active_action_category = ""
	if active_action_category == "":
		active_action_category = first_category
	for category in order:
		if not grouped.has(category):
			continue
		var category_actions: Array = grouped[category]
		actions_box.add_child(_category_button("%s　%d" % [category_names[category], category_actions.size()], category, active_action_category == category))
		if active_action_category != category:
			continue
		if category == "information":
			_add_information_actions(category_actions)
		else:
			for action in category_actions:
				_add_action_button(action)


func _render_focused_actor_summary(focused_actions: Array) -> void:
	var actor := _actor_by_id(current_view.get("known_actors", []), focused_actor_id)
	if actor.is_empty():
		return
	var panel := PanelContainer.new()
	var summary_style := _panel_style(Color(COLORS.panel_alt, 0.34), 0, 2, Color.TRANSPARENT, 13, 10)
	summary_style.border_width_left = 2
	summary_style.border_color = Color(COLORS.accent, 0.56)
	panel.add_theme_stylebox_override("panel", summary_style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	var role_line := _text(content, "%s · %s" % [actor.get("public_role", "可交谈人物"), actor.get("faction", "散修")], true, 13)
	role_line.add_theme_color_override("font_color", COLORS.accent)
	_text(content, str(actor.get("public_profile", "公开资料尚未收集")), false, 14)
	var state_names := {"neutral": "平静", "alert": "正在留意你", "troubled": "正在权衡消息", "decisive": "已经形成决断"}
	var expression := str(actor_expression_by_id.get(focused_actor_id, "alert"))
	var state_line := _text(content, "当前状态 · %s · 可谈线索 %d 条" % [state_names.get(expression, expression), focused_actions.size()], false, 13)
	state_line.add_theme_color_override("font_color", COLORS.success if expression == "decisive" else COLORS.muted)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 5)
	content.add_child(details)
	var focus: Array = actor.get("public_focus", [])
	if not focus.is_empty():
		_text(details, "关注 · %s" % "、".join(focus), true, 13)
	_text(details, "传播风险 · %s" % actor.get("public_risk", "尚不了解"), true, 13)
	details.visible = focused_actor_details_visible
	content.add_child(_utility_button("收起判断依据" if focused_actor_details_visible else "查看判断依据", _toggle_focused_actor_details))
	actions_box.add_child(panel)


func _toggle_focused_actor_details() -> void:
	focused_actor_details_visible = not focused_actor_details_visible
	_render_actions(available_actions_cache)


func _set_action_category(category: String) -> void:
	active_action_category = category
	_render_actions(available_actions_cache)


func _count_tell_actions(actions: Array, actor_id: String, fact_id: String) -> int:
	var count := 0
	for action in actions:
		if action.get("kind", "") != "tell":
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
		if action.get("kind", "") != "tell":
			continue
		if focused_actor_id != "" and str(action.get("target_id", "")) != focused_actor_id:
			continue
		if focused_fact_id != "" and str(action.get("fact_id", "")) != focused_fact_id:
			continue
		result.append(action)
	return result


func _add_focused_information_actions(actions: Array) -> void:
	for index in actions.size():
		var action: Dictionary = actions[index]
		if focused_actor_id != "":
			_text(actions_box, str(action.get("fact_claim", "未知线索")), false, 16)
		else:
			_text(actions_box, "%s · %s" % [action.get("target_name", "某人"), action.get("target_role", "可交谈人物")], false, 16)
		var relevance := _text(actions_box, str(action.get("relevance", "尚不了解这条线索与对方的关联")), false, 14)
		relevance.add_theme_color_override("font_color", COLORS.accent)
		_add_action_decision_context(actions_box, action, true)
		var button_label := "传递这条线索" if focused_actor_id != "" else "告知%s" % action.get("target_name", "对方")
		actions_box.add_child(_action_button(button_label, _consider_action.bind(action)))
		if index < actions.size() - 1:
			var separator := HSeparator.new()
			separator.modulate = COLORS.line
			actions_box.add_child(separator)


func _focus_actor_actions(actor_id: String, actor_name: String) -> void:
	focused_actor_id = actor_id
	focused_actor_name = actor_name
	focused_fact_id = ""
	focused_fact_claim = ""
	focused_actor_details_visible = false
	stage_actor_id = actor_id
	stage_actor_name = actor_name
	_focus_portrait(actor_id)
	_render_stage_people(current_view.get("known_actors", []), available_actions_cache)
	_render_actions(available_actions_cache)


func _focus_actor_from_reference(actor_id: String, actor_name: String) -> void:
	_set_visual_mode("location")
	audio_director.play_ui()
	_focus_actor_actions(actor_id, actor_name)


func _focus_fact_actions(fact_id: String, fact_claim: String) -> void:
	focused_fact_id = fact_id
	focused_fact_claim = fact_claim
	focused_actor_id = ""
	focused_actor_name = ""
	_render_actions(available_actions_cache)


func _clear_action_focus() -> void:
	_reset_action_focus()
	_render_actions(available_actions_cache)


func _reset_action_focus() -> void:
	focused_actor_id = ""
	focused_actor_name = ""
	focused_fact_id = ""
	focused_fact_claim = ""
	focused_actor_details_visible = false


func _reconcile_action_focus(actors: Array, clues: Array) -> void:
	if focused_actor_id != "":
		var actor_still_here := false
		for actor in actors:
			if str(actor.get("id", "")) == focused_actor_id:
				actor_still_here = true
				break
		if not actor_still_here:
			focused_actor_id = ""
			focused_actor_name = ""
	if focused_fact_id != "":
		var fact_still_known := false
		for clue in clues:
			if str(clue.get("fact_id", "")) == focused_fact_id:
				fact_still_known = true
				break
		if not fact_still_known:
			focused_fact_id = ""
			focused_fact_claim = ""


func _add_information_actions(actions: Array) -> void:
	var tell_groups := {}
	for action in actions:
		if action.get("kind", "") != "tell":
			_add_action_button(action)
			continue
		var target := str(action.get("target_name", "某人"))
		if not tell_groups.has(target):
			tell_groups[target] = []
		tell_groups[target].append(action)
	for target in tell_groups:
		var facts: Array = tell_groups[target]
		if facts.size() == 1:
			var action: Dictionary = facts[0]
			var button := _action_button("向%s传递线索" % target, _consider_action.bind(action))
			button.tooltip_text = "%s\n%s\n%s" % [action.get("description", ""), action.get("relevance", ""), action.get("risk", "")]
			actions_box.add_child(button)
			_text(actions_box, "“%s”" % action.get("fact_claim", "未知线索"), true, 14)
			_add_action_decision_context(actions_box, action, true)
		else:
			var menu := MenuButton.new()
			menu.text = "向%s传递线索…（%d 条）" % [target, facts.size()]
			menu.custom_minimum_size.y = 42
			_style_menu_button(menu)
			menu.get_popup().id_pressed.connect(_on_tell_fact_selected.bind(facts))
			for index in facts.size():
				menu.get_popup().add_item(str(facts[index].get("fact_claim", "一条线索")), index)
			actions_box.add_child(menu)


func _add_action_button(action: Dictionary) -> void:
	var duration := int(action.get("duration", 1))
	var label := str(action.get("name", "行动"))
	if action.get("id", "") == "wait:next":
		label += "　· 直至新变化"
	elif int(action.get("completion_day", 0)) > 0:
		label += "　· 第 %d 日完成" % int(action.get("completion_day", 0))
	else:
		label += "　· %d 日" % duration
	var button := _action_button(label, _consider_action.bind(action))
	button.tooltip_text = str(action.get("description", ""))
	actions_box.add_child(button)
	_add_action_decision_context(actions_box, action, true)


func _add_action_decision_context(parent: VBoxContainer, action: Dictionary, compact: bool = false) -> void:
	if not compact and int(action.get("completion_day", 0)) > 0:
		_text(parent, "完成 · 第 %d 日结束时" % int(action.get("completion_day", 0)), false, 15)
	var outcomes := _joined_action_values(action.get("expected_outcomes", []))
	if outcomes != "":
		var outcome_line := _text(parent, "预期 · %s" % outcomes, false, 14)
		outcome_line.add_theme_color_override("font_color", COLORS.success)
	var resolves := _joined_action_values(action.get("resolves", []))
	if resolves != "" and not compact:
		_text(parent, "解决 · %s" % resolves, true, 14)
	var timing := str(action.get("timing", ""))
	if timing != "":
		var timing_line := _text(parent, "时间 · %s" % timing, true, 14)
		if timing.contains("挤压") or timing.contains("来不及") or timing.contains("无法预先保证"):
			timing_line.add_theme_color_override("font_color", COLORS.danger)
		else:
			timing_line.add_theme_color_override("font_color", COLORS.accent)


func _joined_action_values(values: Variant) -> String:
	if not values is Array:
		return ""
	var parts: Array[String] = []
	for value in values:
		parts.append(str(value))
	return "、".join(parts)


func _on_tell_fact_selected(index: int, facts: Array) -> void:
	if index >= 0 and index < facts.size():
		_consider_action(facts[index])


func _consider_action(action: Dictionary) -> void:
	var kind := str(action.get("kind", ""))
	var needs_confirmation: bool = int(action.get("duration", 1)) > 1 or not action.get("costs", {}).is_empty() or kind in ["advance", "move", "tell"]
	if not needs_confirmation:
		_execute_action(str(action.get("id", "")))
		return
	selected_action = action
	_clear(confirmation_box)
	var eyebrow := _text(confirmation_box, "落子之前", true, 13)
	eyebrow.add_theme_color_override("font_color", COLORS.accent)
	_text(confirmation_box, str(action.get("name", "行动")), false, 27)
	if action.get("id", "") == "wait:next":
		var warning := _text(confirmation_box, "时间会连续推进，直到下一次值得关注的变化出现。", false, 15)
		warning.add_theme_color_override("font_color", COLORS.accent)
	else:
		_text(confirmation_box, str(action.get("description", "")), true, 15)
	var outcomes := _joined_action_values(action.get("expected_outcomes", []))
	if outcomes != "":
		var outcome_line := _text(confirmation_box, "将带来 · %s" % outcomes, false, 15)
		outcome_line.add_theme_color_override("font_color", COLORS.success)
	var timing := str(action.get("timing", ""))
	if timing != "":
		var timing_line := _text(confirmation_box, "时机 · %s" % timing, true, 14)
		if timing.contains("挤压") or timing.contains("来不及") or timing.contains("无法预先保证"):
			timing_line.add_theme_color_override("font_color", COLORS.danger)
	var warnings = action.get("warnings", [])
	if warnings is Array:
		for warning_text in warnings:
			var warning_line := _text(confirmation_box, "注意 · %s" % warning_text, false, 14)
			warning_line.add_theme_color_override("font_color", COLORS.danger)
	var costs: Dictionary = action.get("costs", {})
	if not costs.is_empty():
		var cost_names := {"spirit_stones": "灵石", "credit": "信用", "combat": "战力", "support": "助力"}
		var cost_parts: Array[String] = []
		for key in costs:
			cost_parts.append("%s %s" % [cost_names.get(key, key), costs[key]])
		var cost_line := _text(confirmation_box, "消耗：" + "、".join(cost_parts), false, 15)
		cost_line.add_theme_color_override("font_color", COLORS.danger)
	confirmation_details_button = _utility_button("查看判断依据", _toggle_confirmation_details)
	confirmation_box.add_child(confirmation_details_button)
	confirmation_details_box = VBoxContainer.new()
	confirmation_details_box.add_theme_constant_override("separation", 6)
	confirmation_details_box.hide()
	confirmation_box.add_child(confirmation_details_box)
	_add_action_decision_context(confirmation_details_box, action)
	if kind == "tell":
		_text(confirmation_details_box, "%s · %s" % [action.get("target_name", "某人"), action.get("target_role", "可交谈人物")], false, 15)
		var relevance_line := _text(confirmation_details_box, str(action.get("relevance", "关联尚不明确")), false, 14)
		relevance_line.add_theme_color_override("font_color", COLORS.accent)
		_text(confirmation_details_box, "使用倾向 · %s" % action.get("risk", "尚不了解"), true, 14)
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	confirmation_box.add_child(button_row)
	var cancel_button := _utility_button("再想想", _cancel_confirmation)
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(cancel_button)
	var confirm_button := _button("确认执行", _confirm_selected_action, false)
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(confirm_button)
	confirmation_layer.show()


func _toggle_confirmation_details() -> void:
	if not confirmation_details_box or not confirmation_details_button:
		return
	confirmation_details_box.visible = not confirmation_details_box.visible
	confirmation_details_button.text = "收起判断依据" if confirmation_details_box.visible else "查看判断依据"


func _confirm_selected_action() -> void:
	var action_id := str(selected_action.get("id", ""))
	selected_action = {}
	confirmation_layer.hide()
	_execute_action(action_id)


func _cancel_confirmation() -> void:
	selected_action = {}
	confirmation_layer.hide()


func _render_feedback_into(parent: VBoxContainer, feedback: Dictionary) -> void:
	var status_names := {"completed": "已经完成", "started": "已经开始", "failed": "未能完成", "advanced": "已经推进"}
	var status_key := str(feedback.get("status", ""))
	var status := str(status_names.get(status_key, feedback.get("status", "已结算")))
	var status_line := _text(parent, "%s · %s" % [feedback.get("action", "行动"), status], false, 17)
	if status_key == "failed":
		status_line.add_theme_color_override("font_color", COLORS.danger)
	elif status_key == "completed":
		status_line.add_theme_color_override("font_color", COLORS.success)
	var days := int(feedback.get("days_advanced", 0))
	if days > 0:
		var time_line := _text(parent, "时日推进 · %d 日" % days, false, 15)
		time_line.add_theme_color_override("font_color", COLORS.accent if days > 1 else COLORS.ink)
	var quiet_days := int(feedback.get("quiet_days", 0))
	if quiet_days > 0:
		_text(parent, "其中 %d 日没有出现需要你处理的变化" % quiet_days, true, 14)
	var influences: Array = feedback.get("influence", [])
	if not influences.is_empty():
		var influence_heading := _text(parent, "你的消息改变了人物判断", true, 14)
		influence_heading.add_theme_color_override("font_color", COLORS.accent)
	for influence in influences:
		_text(parent, "%s因“%s”改变了判断" % [influence.get("actor_name", "有人"), influence.get("fact_claim", "消息")], false, 15)
		for change in influence.get("changes", []):
			_text(parent, "原本：%s" % change.get("without_information", "其他安排"), true, 14)
			_text(parent, "现在：%s" % change.get("with_information", "新的安排"), false, 14)
	var messages: Array = feedback.get("messages", [])
	if not messages.is_empty():
		var result_heading := _text(parent, "可见结果", true, 14)
		result_heading.add_theme_color_override("font_color", COLORS.accent)
	for message in messages:
		_text(parent, "· %s" % message)


func _render_ending(ending: Dictionary) -> void:
	_clear(ending_box)
	var location_profile: LocationVisualProfile = presentation_registry.location_profile(str(current_view.get("location", {}).get("scene_key", "")))
	ending_background.texture = location_profile.background if location_profile and location_profile.background else null
	var outcome := str(ending.get("outcome", current_view.get("outcome", "旅程结束")))
	var influences: Array = ending.get("influence", [])
	var ending_actor_id := ""
	for actor in current_view.get("known_actors", []):
		var actor_name := str(actor.get("name", ""))
		if actor_name != "" and outcome.contains(actor_name):
			ending_actor_id = str(actor.get("id", ""))
			break
	if ending_actor_id == "":
		ending_actor_id = last_causal_actor_id
	if ending_actor_id == "" and not influences.is_empty():
		ending_actor_id = _actor_id_by_name(str(influences[0].get("actor_name", "")))
	var actor_profile: ActorVisualProfile = presentation_registry.actor_profile(ending_actor_id)
	ending_portrait.texture = actor_profile.portrait("decisive") if actor_profile else null
	ending_portrait.visible = ending_portrait.texture != null
	ending_box.anchor_left = 0.38 if ending_portrait.visible else 0.23
	var eyebrow := _text(ending_box, "尘埃落定", true, 15)
	eyebrow.add_theme_color_override("font_color", COLORS.accent)
	var title := _text(ending_box, outcome, false, 34)
	title.add_theme_color_override("font_color", Color("ead6a8"))
	var rule := HSeparator.new()
	rule.modulate = Color(COLORS.accent, 0.46)
	ending_box.add_child(rule)
	if not influences.is_empty():
		var impact_heading := _text(ending_box, "你的介入留下了这些痕迹", true, 14)
		impact_heading.add_theme_color_override("font_color", COLORS.accent)
	for influence in influences:
		_text(ending_box, "你将“%s”告诉了%s。" % [influence.get("fact_claim", "消息"), influence.get("actor_name", "某人")], false, 15)
		for change in influence.get("changes", []):
			var change_row := HBoxContainer.new()
			change_row.add_theme_constant_override("separation", 14)
			ending_box.add_child(change_row)
			var day_mark := _text(change_row, "第 %d 日" % int(change.get("day", 0)), false, 14)
			day_mark.custom_minimum_size.x = 66
			day_mark.add_theme_color_override("font_color", COLORS.accent)
			var change_line := _text(change_row, "原本%s；后来%s。" % [change.get("without_information", "另有安排"), change.get("with_information", "改变计划")], true, 14)
			change_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if influences.is_empty():
		_text(ending_box, "这一次没有观察到你传递的消息改写他人计划。", true, 14)
	else:
		_text(ending_box, "局势已经落定，但被你改变的计划会成为下一段旅途的起点。", true, 14)
	ending_annex_button = _utility_button("展开局势附录", _toggle_ending_annex)
	ending_box.add_child(ending_annex_button)
	ending_annex_box = VBoxContainer.new()
	ending_annex_box.add_theme_constant_override("separation", 6)
	ending_annex_box.hide()
	ending_box.add_child(ending_annex_box)
	var record_heading := _text(ending_annex_box, "余波记录", true, 14)
	record_heading.add_theme_color_override("font_color", COLORS.accent)
	for highlight in ending.get("highlights", []):
		if str(highlight).begins_with("你传递的消息改变了"):
			continue
		_text(ending_annex_box, "· %s" % highlight, true, 14)
	var return_button := _ornate_button("收卷 · 返回起点", _return_to_start)
	return_button.custom_minimum_size = Vector2(380, 68)
	return_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ending_box.add_child(return_button)
	ending_layer.show()


func _toggle_ending_annex() -> void:
	if not ending_annex_box or not ending_annex_button:
		return
	ending_annex_box.visible = not ending_annex_box.visible
	ending_annex_button.text = "收起局势附录" if ending_annex_box.visible else "展开局势附录"
