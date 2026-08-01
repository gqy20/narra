extends Control

const WorldMapViewScript = preload("res://scripts/world_map.gd")
const LocationStageScript = preload("res://scripts/location_stage.gd")
const PresentationDirectorScript = preload("res://scripts/presentation_director.gd")
const PresentationRegistryScript = preload("res://scripts/presentation_registry.gd")
const AudioDirectorScript = preload("res://scripts/audio_director.gd")
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
var presentation_busy := false

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
var ending_layer: Control
var ending_box: VBoxContainer
var confirmation_layer: Control
var confirmation_box: VBoxContainer
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
	game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	game_layer.add_theme_constant_override("separation", 16)
	add_child(game_layer)
	_build_header()
	_build_dashboard()
	_build_footer()
	game_layer.hide()

	_build_start_layer()
	_build_confirmation_layer()
	_build_settings_layer()
	_build_ending_layer()
	presentation_director = PresentationDirectorScript.new()
	add_child(presentation_director)


func _build_header() -> void:
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", _panel_style(COLORS.panel_alt, 1, 10, COLORS.line_soft, 20, 16))
	header.custom_minimum_size.y = 132
	game_layer.add_child(header)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	header.add_child(stack)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	stack.add_child(row)

	var brand := Label.new()
	brand.text = "凡途  /  黑风谷"
	brand.add_theme_font_override("font", display_font)
	brand.add_theme_font_size_override("font_size", TYPE_SCALE.brand)
	brand.add_theme_color_override("font_color", COLORS.accent)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(brand)

	day_label = _header_value(row, "时日")
	place_label = _header_value(row, "所在")
	phase_label = _header_value(row, "局势")
	timing_label = _header_value(row, "已知时机")
	sound_button = _button("声音", _open_audio_settings, true)
	row.add_child(sound_button)
	row.add_child(_button("存档", _save_game, true))
	row.add_child(_button("返回", _return_to_start, true))
	player_summary_label = Label.new()
	player_summary_label.add_theme_font_size_override("font_size", TYPE_SCALE.compact)
	player_summary_label.add_theme_constant_override("line_spacing", 3)
	player_summary_label.add_theme_color_override("font_color", COLORS.ink)
	stack.add_child(player_summary_label)
	objective_label = Label.new()
	objective_label.text = "当前判断 · 正在读取局势"
	objective_label.add_theme_font_size_override("font_size", TYPE_SCALE.detail)
	objective_label.add_theme_constant_override("line_spacing", 4)
	objective_label.add_theme_color_override("font_color", COLORS.muted)
	stack.add_child(objective_label)


func _build_dashboard() -> void:
	var workspace := HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 16)
	game_layer.add_child(workspace)

	var world_column := VBoxContainer.new()
	world_column.custom_minimum_size.x = 760
	world_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_column.size_flags_stretch_ratio = 1.75
	world_column.add_theme_constant_override("separation", 12)
	workspace.add_child(world_column)
	_build_world_stage(world_column)
	scene_box = _zone(world_column, "行旅回响", 0.38)

	var decision_column := VBoxContainer.new()
	decision_column.custom_minimum_size.x = 430
	decision_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decision_column.size_flags_stretch_ratio = 1.0
	decision_column.add_theme_constant_override("separation", 12)
	workspace.add_child(decision_column)
	actions_box = _zone(decision_column, "下一步", 1.24)
	_build_reference_tabs(decision_column)


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
	map_mode_button = _button("区域地图", _set_visual_mode.bind("map"), true)
	map_mode_button.custom_minimum_size = Vector2(116, 38)
	mode_row.add_child(map_mode_button)
	location_mode_button = _button("当前地点", _set_visual_mode.bind("location"), true)
	location_mode_button.custom_minimum_size = Vector2(116, 38)
	mode_row.add_child(location_mode_button)

	var stage_frame := PanelContainer.new()
	stage_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_frame.size_flags_stretch_ratio = 1.0
	stage_frame.custom_minimum_size.y = 430
	stage_frame.add_theme_stylebox_override("panel", _panel_style(COLORS.panel, 1, 10, COLORS.line_soft, 12, 10))
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
	actor_portrait_frame.anchor_left = 0.70
	actor_portrait_frame.anchor_right = 0.98
	actor_portrait_frame.anchor_top = 0.035
	actor_portrait_frame.anchor_bottom = 0.965
	actor_portrait_frame.add_theme_stylebox_override("panel", _panel_style(Color("101612e8"), 1, 8, Color(COLORS.accent, 0.55), 4, 4))
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
	portrait_caption.anchor_top = 0.73
	portrait_caption.anchor_bottom = 1.0
	portrait_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_caption.add_theme_stylebox_override("panel", _panel_style(Color("0a0f0cde"), 0, 4, Color.TRANSPARENT, 12, 9))
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
	start_layer = CenterContainer.new()
	start_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(start_layer)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(568, 468)
	card.add_theme_stylebox_override("panel", _panel_style(Color("111713"), 1, 18, COLORS.line, 36, 30))
	start_layer.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	card.add_child(content)

	var eyebrow := Label.new()
	eyebrow.text = "黑风谷异动　·　三十日局势"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_color_override("font_color", COLORS.accent)
	eyebrow.add_theme_font_override("font", medium_font)
	eyebrow.add_theme_font_size_override("font_size", TYPE_SCALE.meta)
	content.add_child(eyebrow)
	var title := Label.new()
	title.text = "凡 途"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", display_font)
	title.add_theme_font_size_override("font_size", TYPE_SCALE.display)
	title.add_theme_color_override("font_color", COLORS.ink)
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "三十日内，青髓芝的归属将被决定。\n核验、交易、赶路，或让消息改变他人的选择。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	content.add_child(_button("开始新的旅程", _new_game, false))
	content.add_child(_button("继续上次旅程", _load_game, true))
	retry_button = _button("重新连接本地服务", _retry_connection, true)
	retry_button.hide()
	content.add_child(retry_button)
	connection_label = Label.new()
	connection_label.text = "正在确认本地服务…"
	connection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	connection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	connection_label.add_theme_color_override("font_color", COLORS.muted)
	connection_label.add_theme_font_size_override("font_size", TYPE_SCALE.detail)
	connection_label.add_theme_constant_override("line_spacing", 4)
	content.add_child(connection_label)


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
	card.custom_minimum_size = Vector2(540, 330)
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
	_text(settings_box, "声音设置", false, 25)
	_text(settings_box, "环境声与事件提示不会改变模拟结果。", true, 14)
	_audio_slider(settings_box, "主音量", "Master", 82.0)
	_audio_slider(settings_box, "环境", "Ambient", 64.0)
	_audio_slider(settings_box, "事件", "Event", 78.0)
	_audio_slider(settings_box, "界面", "UI", 70.0)
	settings_box.add_child(_button("全部静音", _toggle_sound, true))
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
	ending_layer = CenterContainer.new()
	ending_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_layer.hide()
	add_child(ending_layer)
	var shade := ColorRect.new()
	shade.color = Color("050706e8")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_layer.add_child(shade)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(680, 520)
	card.add_theme_stylebox_override("panel", _panel_style(COLORS.panel, 1, 18, COLORS.accent_pressed, 32, 28))
	ending_layer.add_child(card)
	ending_box = VBoxContainer.new()
	ending_box.add_theme_constant_override("separation", 16)
	card.add_child(ending_box)


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
	panel.add_theme_stylebox_override("panel", _panel_style(COLORS.panel, 1, 10, COLORS.line_soft, 18, 16))
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
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(COLORS.panel, 1, 10, COLORS.line_soft, 18, 16))
	parent.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var title := Label.new()
	title.text = "随身资料"
	title.add_theme_font_override("font", display_font)
	title.add_theme_font_size_override("font_size", TYPE_SCALE.section)
	title.add_theme_color_override("font_color", COLORS.accent)
	outer.add_child(title)
	var rule := HSeparator.new()
	rule.modulate = Color(COLORS.accent, 0.35)
	outer.add_child(rule)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", TYPE_SCALE.compact)
	outer.add_child(tabs)
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


func _style_menu_button(button: MenuButton) -> void:
	button.add_theme_font_override("font", medium_font)
	button.add_theme_font_size_override("font_size", TYPE_SCALE.button)
	button.add_theme_color_override("font_color", COLORS.ink)
	button.add_theme_color_override("font_hover_color", COLORS.ink)
	button.add_theme_color_override("font_pressed_color", COLORS.accent)
	button.add_theme_stylebox_override("normal", _panel_style(COLORS.panel_alt, 1, 6, COLORS.line, 14, 9))
	button.add_theme_stylebox_override("hover", _panel_style(COLORS.panel_hover, 1, 6, COLORS.accent_pressed, 14, 9))
	button.add_theme_stylebox_override("pressed", _panel_style(COLORS.bg_lift, 1, 6, COLORS.accent, 14, 10))
	button.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, 2, 7, COLORS.accent_hover, 12, 7))
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
		connection_label.text = _operation_label(operation) + "…"
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
		connection_label.text = "本地规则服务已就绪"
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
	presentation_director.present(feedback, str(previous_location.get("name", "")), str(next_location.get("name", "")))


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
	_reset_action_focus()
	_set_visual_mode("map")
	_request("new", HTTPClient.METHOD_POST, "/game/new", {"player_name": player_name})


func _retry_connection() -> void:
	connection_label.text = "正在重新连接…"
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


func _open_audio_settings() -> void:
	audio_director.play_ui()
	settings_layer.show()


func _close_audio_settings() -> void:
	audio_director.play_ui()
	settings_layer.hide()


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
	_reset_action_focus()
	game_layer.hide()
	confirmation_layer.hide()
	settings_layer.hide()
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
	objective_label.text = "当前判断 · %s" % (guidance[0] if not guidance.is_empty() else "根据已知线索选择调查、交涉、准备或等待")
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
		map_mode_button.text = "区域地图 · 当前" if mode == "map" else "区域地图"
	if location_mode_button:
		location_mode_button.text = "当前地点 · 当前" if mode == "location" else "当前地点"
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
		var enter_button := _button("进入当前地点场景", _set_visual_mode.bind("location"), true)
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
		var button := _button(button_text, _focus_actor_from_stage.bind(actor_id, actor_name), true)
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
	player_summary_label.text = "%s　%s　战力 %s　助力 %s　伤势 %d　灵石 %s　持有：%s" % [
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
			var link := _button("传播 · %d 名可选人物" % target_count, _focus_fact_actions.bind(fact_id, str(clue.get("claim", "未知传言"))), true)
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
		var link := _button(link_text, _focus_actor_from_reference.bind(actor_id, actor_name), true)
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
		_render_recent_interaction_result()
		actions_box.add_child(_button("返回全部行动", _clear_action_focus, true))
		if focused_actions.is_empty():
			_text(actions_box, "目前没有新的线索可告知；已经送达的内容不会重复出现。", true)
			return
		_add_focused_information_actions(focused_actions)
		return
	if focused_fact_id != "":
		_text(actions_box, "传播线索", false, 18)
		_text(actions_box, focused_fact_claim, true, 14)
		_render_recent_interaction_result()
		actions_box.add_child(_button("返回全部行动", _clear_action_focus, true))
		if focused_actions.is_empty():
			_text(actions_box, "当前地点已没有尚未收到这条线索的人。", true)
			return
		_add_focused_information_actions(focused_actions)
		return
	if actions.is_empty():
		_render_recent_interaction_result()
		_text(actions_box, "当前没有可执行行动。", true)
		return
	_render_recent_interaction_result()
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
	for category in order:
		if not grouped.has(category):
			continue
		var heading := _text(actions_box, str(category_names[category]), true, 13)
		heading.add_theme_color_override("font_color", COLORS.accent)
		if category == "information":
			_add_information_actions(grouped[category])
		else:
			for action in grouped[category]:
				_add_action_button(action)


func _render_focused_actor_summary(focused_actions: Array) -> void:
	var actor := _actor_by_id(current_view.get("known_actors", []), focused_actor_id)
	if actor.is_empty():
		return
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(COLORS.panel_alt, 1, 7, COLORS.line, 13, 11))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	var role_line := _text(content, "%s · %s" % [actor.get("public_role", "可交谈人物"), actor.get("faction", "散修")], true, 13)
	role_line.add_theme_color_override("font_color", COLORS.accent)
	_text(content, str(actor.get("public_profile", "公开资料尚未收集")), false, 14)
	var focus: Array = actor.get("public_focus", [])
	if not focus.is_empty():
		_text(content, "关注 · %s" % "、".join(focus), true, 13)
	_text(content, "传播风险 · %s" % actor.get("public_risk", "尚不了解"), true, 13)
	var state_names := {"neutral": "平静", "alert": "正在留意你", "troubled": "正在权衡消息", "decisive": "已经形成决断"}
	var expression := str(actor_expression_by_id.get(focused_actor_id, "alert"))
	var state_line := _text(content, "当前状态 · %s · 可谈线索 %d 条" % [state_names.get(expression, expression), focused_actions.size()], false, 13)
	state_line.add_theme_color_override("font_color", COLORS.success if expression == "decisive" else COLORS.muted)
	actions_box.add_child(panel)


func _render_recent_interaction_result() -> void:
	var feedback = current_view.get("last_turn", null)
	if not feedback is Dictionary:
		return
	var action_id := str(feedback.get("action_id", ""))
	var influences: Array = feedback.get("influence", [])
	if not action_id.begins_with("tell:") and influences.is_empty():
		return
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("172019"), 1, 7, Color(COLORS.accent, 0.58), 13, 11))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	panel.add_child(content)
	var heading := _text(content, "最近一次交涉", true, 13)
	heading.add_theme_color_override("font_color", COLORS.accent)
	if action_id.begins_with("tell:"):
		_text(content, "%s · 消息已送达" % feedback.get("action", "传递线索"), false, 15)
	if influences.is_empty():
		_text(content, "对方正在权衡；当前尚未观察到计划变化。推进局势后会在这里核对结果。", true, 13)
	else:
		for influence in influences:
			_text(content, "%s因“%s”改变判断" % [influence.get("actor_name", "有人"), influence.get("fact_claim", "消息")], false, 14)
			for change in influence.get("changes", []):
				_text(content, "原本 · %s" % change.get("without_information", "其他安排"), true, 13)
				var changed := _text(content, "现在 · %s" % change.get("with_information", "新的安排"), false, 13)
				changed.add_theme_color_override("font_color", COLORS.success)
	actions_box.add_child(panel)


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
		var risk := str(action.get("risk", ""))
		if risk != "":
			_text(actions_box, "使用倾向 · %s" % risk, true, 14)
		for warning_text in action.get("warnings", []):
			var warning := _text(actions_box, "注意 · %s" % warning_text, false, 14)
			warning.add_theme_color_override("font_color", COLORS.accent)
		_add_action_decision_context(actions_box, action, true)
		var button_label := "传递这条线索" if focused_actor_id != "" else "告知%s" % action.get("target_name", "对方")
		actions_box.add_child(_button(button_label, _consider_action.bind(action), true))
		if index < actions.size() - 1:
			var separator := HSeparator.new()
			separator.modulate = COLORS.line
			actions_box.add_child(separator)


func _focus_actor_actions(actor_id: String, actor_name: String) -> void:
	focused_actor_id = actor_id
	focused_actor_name = actor_name
	focused_fact_id = ""
	focused_fact_claim = ""
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
			var button := _button("向%s传递线索" % target, _consider_action.bind(action), true)
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
	var button := _button(label, _consider_action.bind(action), true)
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
	if resolves != "":
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
	_text(confirmation_box, "确认这次选择？", false, 24)
	_text(confirmation_box, str(action.get("name", "行动")), false, 19)
	if action.get("id", "") == "wait:next":
		var warning := _text(confirmation_box, "将逐日推演并在下一次值得关注的变化处停下，实际可能跨越多个平静日。", false, 15)
		warning.add_theme_color_override("font_color", COLORS.accent)
	else:
		_text(confirmation_box, str(action.get("description", "")), true, 15)
	_add_action_decision_context(confirmation_box, action)
	if kind == "tell":
		_text(confirmation_box, "%s · %s" % [action.get("target_name", "某人"), action.get("target_role", "可交谈人物")], false, 15)
		var relevance_line := _text(confirmation_box, str(action.get("relevance", "关联尚不明确")), false, 14)
		relevance_line.add_theme_color_override("font_color", COLORS.accent)
		_text(confirmation_box, "使用倾向 · %s" % action.get("risk", "尚不了解"), true, 14)
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
	confirmation_box.add_child(_button("确认执行", _confirm_selected_action, false))
	confirmation_box.add_child(_button("再想想", _cancel_confirmation, true))
	confirmation_layer.show()


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
	var eyebrow := _text(ending_box, "尘埃落定", true, 15)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var outcome_heading := _text(ending_box, "最终归属", true, 13)
	outcome_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outcome_heading.add_theme_color_override("font_color", COLORS.accent)
	var title := _text(ending_box, str(ending.get("outcome", current_view.get("outcome", "旅程结束"))), false, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var influences: Array = ending.get("influence", [])
	if not influences.is_empty():
		var impact_heading := _text(ending_box, "你的介入", true, 14)
		impact_heading.add_theme_color_override("font_color", COLORS.accent)
	for influence in influences:
		_text(ending_box, "你将“%s”告诉了%s。" % [influence.get("fact_claim", "消息"), influence.get("actor_name", "某人")], false, 15)
		for change in influence.get("changes", []):
			_text(ending_box, "第 %d 日 · 原本%s，后来%s。" % [int(change.get("day", 0)), change.get("without_information", "另有安排"), change.get("with_information", "改变计划")], true, 14)
	var record_heading := _text(ending_box, "余波记录", true, 14)
	record_heading.add_theme_color_override("font_color", COLORS.accent)
	for highlight in ending.get("highlights", []):
		if str(highlight).begins_with("你传递的消息改变了"):
			continue
		_text(ending_box, "· %s" % highlight)
	if influences.is_empty():
		_text(ending_box, "这一次没有观察到你传递的消息改写他人计划。", true, 14)
	else:
		_text(ending_box, "局势已经落定，但被你改变的计划会成为下一段旅途的起点。", true, 14)
	ending_box.add_child(_button("返回起点", _return_to_start, false))
	ending_layer.show()
