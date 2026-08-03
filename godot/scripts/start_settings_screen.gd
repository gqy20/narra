extends RefCounted

var host


func _init(value) -> void:
	host = value


func _build_start_layer() -> void:
	host.start_layer = Control.new()
	host.start_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(host.start_layer)
	host.start_scene = TextureRect.new()
	host.start_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.start_scene.texture = host.StartBackgroundTexture
	host.start_scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.start_scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	host.start_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.start_layer.add_child(host.start_scene)
	host.start_vignette = TextureRect.new()
	host.start_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.start_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.start_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	host.start_vignette.modulate = Color(0.18, 0.2, 0.18, 0.34)
	host.start_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.start_vignette.hide()
	host.start_layer.add_child(host.start_vignette)
	var shade = ColorRect.new()
	shade.color = Color("0305048f")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.start_layer.add_child(shade)
	var center = CenterContainer.new()
	center.anchor_left = 0.48
	center.anchor_right = 0.94
	center.anchor_top = 0.04
	center.anchor_bottom = 0.98
	host.start_layer.add_child(center)
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 520)
	var start_style = host.game_screen_controller._panel_style(Color("070a0875"), 0, 0, Color.TRANSPARENT, 38, 34)
	start_style.border_width_left = 2
	start_style.border_color = Color(host.COLORS.accent, 0.46)
	card.add_theme_stylebox_override("panel", start_style)
	center.add_child(card)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	card.add_child(content)

	host.start_eyebrow_label = Label.new()
	host.start_eyebrow_label.text = "正在读取场景"
	host.start_eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	host.start_eyebrow_label.add_theme_color_override("font_color", host.COLORS.accent)
	host.start_eyebrow_label.add_theme_font_override("font", host.medium_font)
	host.start_eyebrow_label.add_theme_font_size_override("font_size", host.TYPE_SCALE.meta)
	content.add_child(host.start_eyebrow_label)
	host.start_title_label = Label.new()
	host.start_title_label.text = "游戏"
	host.start_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	host.start_title_label.add_theme_font_override("font", host.display_font)
	host.start_title_label.add_theme_font_size_override("font_size", 62)
	host.start_title_label.add_theme_color_override("font_color", host.COLORS.ink)
	content.add_child(host.start_title_label)
	host.start_seal = TextureRect.new()
	host.start_seal.custom_minimum_size = Vector2(78, 78)
	host.start_seal.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	host.start_seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.start_seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.start_seal.modulate = Color(1, 1, 1, 0.72)
	host.start_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.start_seal.hide()
	content.add_child(host.start_seal)
	host.start_intro_label = Label.new()
	host.start_intro_label.text = "等待本地服务载入场景内容。"
	host.start_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	host.start_intro_label.add_theme_color_override("font_color", host.COLORS.muted)
	host.start_intro_label.add_theme_font_size_override("font_size", host.TYPE_SCALE.body)
	host.start_intro_label.add_theme_constant_override("line_spacing", 7)
	host.start_intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(host.start_intro_label)
	var divider = HSeparator.new()
	divider.modulate = Color(host.COLORS.accent, 0.48)
	content.add_child(divider)

	host.name_input = LineEdit.new()
	var name_prompt = host.game_screen_controller._text(content, host._ui_text("player_name_prompt"), true, 13)
	name_prompt.add_theme_color_override("font_color", Color(host.COLORS.accent, 0.84))
	host.name_input.placeholder_text = "留下名号"
	host.name_input.text = host._ui_text("default_player_name")
	host.name_input.add_theme_font_size_override("font_size", host.TYPE_SCALE.metric)
	host.name_input.custom_minimum_size.y = 52
	var name_style = host.game_screen_controller._input_style(Color("111812c2"), Color(host.COLORS.line, 0.58))
	name_style.set_corner_radius_all(1)
	host.name_input.add_theme_stylebox_override("normal", name_style)
	var name_focus_style = host.game_screen_controller._input_style(Color("151d17dc"), host.COLORS.accent)
	name_focus_style.set_corner_radius_all(1)
	host.name_input.add_theme_stylebox_override("focus", name_focus_style)
	host.name_input.add_theme_constant_override("minimum_character_width", 8)
	content.add_child(host.name_input)
	host.start_begin_button = host.game_screen_controller._ornate_button("开始新故事", host._new_game)
	host.start_begin_button.custom_minimum_size.y = 66
	content.add_child(host.start_begin_button)
	var continue_button = host.game_screen_controller._utility_button("翻开旧卷", host._load_game)
	continue_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(continue_button)
	var start_settings_button = host.game_screen_controller._utility_button("大模型与体验设置", host.start_settings_screen_controller._open_audio_settings)
	start_settings_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(start_settings_button)
	host.retry_button = host.game_screen_controller._action_button("重新连接本地服务", host._retry_connection)
	host.retry_button.hide()
	content.add_child(host.retry_button)
	host.connection_label = Label.new()
	host.connection_label.text = ""
	host.connection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	host.connection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.connection_label.add_theme_color_override("font_color", host.COLORS.muted)
	host.connection_label.add_theme_font_size_override("font_size", host.TYPE_SCALE.meta)
	host.connection_label.add_theme_constant_override("line_spacing", 4)
	content.add_child(host.connection_label)


func _build_settings_layer() -> void:
	host.settings_layer = Control.new()
	host.settings_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.settings_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	host.settings_layer.hide()
	host.add_child(host.settings_layer)
	var shade = ColorRect.new()
	shade.color = Color("050706dc")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.settings_layer.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.settings_layer.add_child(center)
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(900, 690)
	card.add_theme_stylebox_override("panel", host.game_screen_controller._panel_style(host.COLORS.panel, 1, 14, host.COLORS.accent_pressed, 28, 24))
	center.add_child(card)
	host.settings_box = VBoxContainer.new()
	host.settings_box.add_theme_constant_override("separation", 12)
	card.add_child(host.settings_box)
	host.game_screen_controller._text(host.settings_box, "体验设置", false, 25)
	host.game_screen_controller._text(host.settings_box, "管理显示、声音、诊断、人物对话与世界导演。", true, 14)
	var tabs = TabContainer.new()
	tabs.custom_minimum_size.y = 500
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_override("font", host.medium_font)
	host.settings_box.add_child(tabs)
	var presentation_tab = VBoxContainer.new()
	presentation_tab.name = "显示与声音"
	presentation_tab.add_theme_constant_override("separation", 12)
	tabs.add_child(presentation_tab)
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 34)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	presentation_tab.add_child(columns)
	var display_box = VBoxContainer.new()
	display_box.custom_minimum_size.x = 350
	display_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_box.add_theme_constant_override("separation", 12)
	columns.add_child(display_box)
	var display_heading = host.game_screen_controller._text(display_box, "显示", false, host.TYPE_SCALE.section)
	display_heading.add_theme_font_override("font", host.display_font)
	display_heading.add_theme_color_override("font_color", host.COLORS.accent)
	host.display_mode_option = host.display_settings_controller._display_option(display_box, "窗口模式", "无边框全屏会使用当前显示器的原生分辨率。")
	host.display_mode_option.item_selected.connect(host.display_settings_controller._on_display_mode_selected)
	host.display_resolution_option = host.display_settings_controller._display_option(display_box, "输出分辨率", "窗口模式可选择输出尺寸；全屏模式始终使用显示器原生分辨率。")
	host.display_resolution_option.item_selected.connect(host.display_settings_controller._on_display_resolution_selected)
	host.ui_scale_option = host.display_settings_controller._display_option(display_box, "界面缩放", "高分辨率下可以放大文字与控件；不适合当前画布的比例会自动隐藏。")
	host.ui_scale_option.item_selected.connect(host.display_settings_controller._on_ui_scale_selected)
	host.display_status_label = host.game_screen_controller._text(display_box, "", true, host.TYPE_SCALE.meta)
	host.display_status_label.add_theme_color_override("font_color", host.COLORS.muted)
	host.display_status_label.add_theme_constant_override("line_spacing", 4)
	host.motion_button = host.game_screen_controller._action_button("动态效果 · 开启", host.start_settings_screen_controller._toggle_motion)
	display_box.add_child(host.motion_button)

	var audio_box = VBoxContainer.new()
	audio_box.custom_minimum_size.x = 350
	audio_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_box.add_theme_constant_override("separation", 10)
	columns.add_child(audio_box)
	var audio_heading = host.game_screen_controller._text(audio_box, "声音", false, host.TYPE_SCALE.section)
	audio_heading.add_theme_font_override("font", host.display_font)
	audio_heading.add_theme_color_override("font_color", host.COLORS.accent)
	host.display_settings_controller._audio_slider(audio_box, "主音量", "Master", 82.0)
	host.display_settings_controller._audio_slider(audio_box, "环境", "Ambient", 64.0)
	host.display_settings_controller._audio_slider(audio_box, "事件", "Event", 78.0)
	host.display_settings_controller._audio_slider(audio_box, "界面", "UI", 70.0)
	audio_box.add_child(host.game_screen_controller._action_button("全部静音", host.start_settings_screen_controller._toggle_sound))

	var rule = HSeparator.new()
	rule.modulate = Color(host.COLORS.accent, 0.30)
	presentation_tab.add_child(rule)
	var diagnostic_row = HBoxContainer.new()
	diagnostic_row.add_theme_constant_override("separation", 8)
	presentation_tab.add_child(diagnostic_row)
	host.log_level_button = host.game_screen_controller._action_button("日志等级 · %s" % host.log_level, host.display_settings_controller._cycle_log_level)
	host.log_level_button.tooltip_text = "DEBUG 记录更多诊断信息；INFO 适合正式版。服务端会在下次启动时应用新等级。"
	host.log_level_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diagnostic_row.add_child(host.log_level_button)
	var log_folder_button = host.game_screen_controller._action_button("打开日志", host.runtime_logger_controller._open_log_folder)
	log_folder_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diagnostic_row.add_child(log_folder_button)
	var diagnostics_button = host.game_screen_controller._action_button("导出诊断包", host.runtime_logger_controller._export_diagnostics)
	diagnostics_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diagnostic_row.add_child(diagnostics_button)

	var ai_tab = VBoxContainer.new()
	ai_tab.name = "大模型"
	ai_tab.add_theme_constant_override("separation", 12)
	tabs.add_child(ai_tab)
	var ai_intro = host.game_screen_controller._text(ai_tab, "大模型人物对话与世界导演使用 Anthropic Messages 兼容接口。关闭时完全不调用模型；开启后超时、空响应、结构错误或非法导演指令都会直接报错并回滚当日推进。", true, host.TYPE_SCALE.detail)
	ai_intro.custom_minimum_size.y = 42
	host.ai_enabled_check = CheckButton.new()
	host.ai_enabled_check.text = "启用大模型人物对话与世界导演"
	host.ai_enabled_check.button_pressed = host.ai_enabled
	host.ai_enabled_check.add_theme_font_override("font", host.medium_font)
	host.ai_enabled_check.add_theme_font_size_override("font_size", host.TYPE_SCALE.body)
	ai_tab.add_child(host.ai_enabled_check)
	host.ai_model_input = host.start_settings_screen_controller._ai_settings_input(ai_tab, "模型", host.ai_model, "例如 step-3.7-flash")
	host.ai_base_url_input = host.start_settings_screen_controller._ai_settings_input(ai_tab, "接口地址", host.ai_base_url, "Anthropic Messages 兼容地址")
	host.ai_api_key_input = host.start_settings_screen_controller._ai_settings_input(ai_tab, "API Key", host.ai_api_key, "密钥仅保存在本机运行目录")
	host.ai_api_key_input.secret = true
	host.ai_api_key_input.secret_character = "●"
	var ai_actions = HBoxContainer.new()
	ai_actions.add_theme_constant_override("separation", 10)
	ai_tab.add_child(ai_actions)
	var apply_ai_button = host.game_screen_controller._button("保存并立即应用", host.start_settings_screen_controller._apply_ai_settings, false)
	apply_ai_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_actions.add_child(apply_ai_button)
	var clear_ai_button = host.game_screen_controller._button("清除密钥并关闭", host.start_settings_screen_controller._clear_ai_settings, true)
	clear_ai_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_actions.add_child(clear_ai_button)
	host.ai_status_label = host.game_screen_controller._text(ai_tab, "", true, host.TYPE_SCALE.detail)
	host.ai_status_label.add_theme_color_override("font_color", host.COLORS.muted)
	host.start_settings_screen_controller._refresh_ai_settings_status()
	host.settings_box.add_child(host.game_screen_controller._button("返回游戏", host.start_settings_screen_controller._close_audio_settings, false))
	host.display_settings_controller._refresh_display_controls()


func _ai_settings_input(parent: VBoxContainer, label_text: String, value: String, tooltip: String) -> LineEdit:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 92
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", host.medium_font)
	label.add_theme_color_override("font_color", host.COLORS.ink)
	row.add_child(label)
	var input = LineEdit.new()
	input.text = value
	input.placeholder_text = tooltip
	input.tooltip_text = tooltip
	input.custom_minimum_size = Vector2(560, 42)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.add_theme_font_override("font", host.medium_font)
	input.add_theme_font_size_override("font_size", host.TYPE_SCALE.detail)
	input.add_theme_stylebox_override("normal", host.game_screen_controller._input_style(host.COLORS.panel_alt, host.COLORS.line))
	input.add_theme_stylebox_override("focus", host.game_screen_controller._input_style(host.COLORS.bg_lift, host.COLORS.accent))
	row.add_child(input)
	return input


func _toggle_sound() -> void:
	host.sound_enabled = not host.sound_enabled
	host.sound_button.text = "声音" if host.sound_enabled else "声音 · 静音"
	host.audio_director.set_enabled(host.sound_enabled)


func _toggle_motion() -> void:
	host.motion_enabled = not host.motion_enabled
	if host.motion_button:
		host.motion_button.text = "动态效果 · 开启" if host.motion_enabled else "动态效果 · 精简"
	if host.world_map_view:
		host.world_map_view.set_motion_enabled(host.motion_enabled)
	if host.presentation_director:
		host.presentation_director.motion_enabled = host.motion_enabled
	if host.cinematic_director:
		host.cinematic_director.set_enabled(host.motion_enabled)


func _open_audio_settings() -> void:
	host.audio_director.play_ui()
	host.start_settings_screen_controller._sync_ai_settings_controls()
	host.settings_layer.show()
	host.game_screen_controller._sync_action_canvas_visibility()


func _close_audio_settings() -> void:
	host.audio_director.play_ui()
	host.settings_layer.hide()
	host.game_screen_controller._sync_action_canvas_visibility()


func _sync_ai_settings_controls() -> void:
	if not host.ai_enabled_check:
		return
	host.ai_enabled_check.button_pressed = host.ai_enabled
	host.ai_model_input.text = host.ai_model
	host.ai_base_url_input.text = host.ai_base_url
	host.ai_api_key_input.text = host.ai_api_key
	host.start_settings_screen_controller._refresh_ai_settings_status()


func _apply_ai_settings() -> void:
	host.ai_enabled = host.ai_enabled_check.button_pressed
	host.ai_model = host.ai_model_input.text.strip_edges()
	host.ai_base_url = host.ai_base_url_input.text.strip_edges()
	host.ai_api_key = host.ai_api_key_input.text.strip_edges()
	if host.ai_enabled and host.ai_model == "":
		host.ai_status_label.text = "启用大模型时必须填写模型名称"
		host.ai_status_label.add_theme_color_override("font_color", host.COLORS.danger)
		return
	if host.ai_enabled and host.ai_api_key == "":
		host.ai_status_label.text = "启用大模型时必须填写 API Key"
		host.ai_status_label.add_theme_color_override("font_color", host.COLORS.danger)
		return
	if host.ai_base_url != "" and not (host.ai_base_url.begins_with("https://") or host.ai_base_url.begins_with("http://")):
		host.ai_status_label.text = "接口地址必须以 https:// 或 http:// 开头"
		host.ai_status_label.add_theme_color_override("font_color", host.COLORS.danger)
		return
	host.ai_status_label.text = "正在应用大模型配置……"
	host.ai_status_label.add_theme_color_override("font_color", host.COLORS.accent)
	host._request("ai_settings", HTTPClient.METHOD_PUT, "/settings/ai", {
		"enabled": host.ai_enabled,
		"api_key": host.ai_api_key,
		"model": host.ai_model,
		"base_url": host.ai_base_url,
	})


func _clear_ai_settings() -> void:
	host.ai_enabled_check.button_pressed = false
	host.ai_api_key_input.text = ""
	host.start_settings_screen_controller._apply_ai_settings()


func _refresh_ai_settings_status(message := "") -> void:
	if not host.ai_status_label:
		return
	if message != "":
		host.ai_status_label.text = message
		host.ai_status_label.add_theme_color_override("font_color", host.COLORS.success)
	elif host.ai_server_enabled:
		var active_model = host.ai_server_mode.trim_prefix("anthropic:")
		host.ai_status_label.text = "运行状态：人物对话与世界导演已启用 · %s" % active_model
		host.ai_status_label.add_theme_color_override("font_color", host.COLORS.success)
	elif host.ai_enabled:
		host.ai_status_label.text = "运行状态：配置已保存，但当前服务尚未启用模型"
		host.ai_status_label.add_theme_color_override("font_color", host.COLORS.muted)
	else:
		host.ai_status_label.text = "运行状态：人物对话与世界导演未启用"
		host.ai_status_label.add_theme_color_override("font_color", host.COLORS.muted)
