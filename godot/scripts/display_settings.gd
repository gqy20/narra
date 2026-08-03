extends RefCounted

var host


func _init(value) -> void:
	host = value


func _load_user_settings() -> void:
	var loaded = host.settings_store.load_all(host.runtime_root, {
		"log_level": host.log_level, "display_mode": host.display_mode, "display_resolution": host.display_resolution, "ui_scale": host.ui_scale,
		"ai_enabled": host.ai_enabled, "ai_model": host.ai_model, "ai_base_url": host.ai_base_url, "ai_api_key": host.ai_api_key, "ai_file": host.AI_SETTINGS_FILE,
	}, {
		"log_levels": host.LOG_LEVELS, "display_modes": host.DISPLAY_MODE_KEYS, "resolutions": host.DISPLAY_RESOLUTION_PRESETS, "ui_scales": host.UI_SCALE_PRESETS,
	})
	host.log_level = str(loaded.log_level)
	host.display_mode = str(loaded.display_mode)
	host.display_resolution = loaded.display_resolution
	host.ui_scale = float(loaded.ui_scale)
	host.ai_enabled = bool(loaded.ai_enabled)
	host.ai_model = str(loaded.ai_model)
	host.ai_base_url = str(loaded.ai_base_url)
	host.ai_api_key = str(loaded.ai_api_key)
	if str(loaded.get("ai_error", "")) != "":
		host.runtime_logger_controller._log_event("ERROR", "ai_settings_load_failed", str(loaded.ai_error), {"path": host.runtime_root.path_join(host.AI_SETTINGS_FILE)})


func _save_ai_settings() -> Error:
	return host.settings_store.save_ai(host.runtime_root, host.AI_SETTINGS_FILE, {
		"enabled": host.ai_enabled, "api_key": host.ai_api_key, "model": host.ai_model, "base_url": host.ai_base_url,
	})


func _save_user_settings() -> void:
	var settings_path = host.runtime_root.path_join("settings.cfg")
	var save_error = host.settings_store.save_user(host.runtime_root, {
		"log_level": host.log_level, "display_mode": host.display_mode, "display_resolution": host.display_resolution, "ui_scale": host.ui_scale,
	})
	if save_error != OK:
		host.runtime_logger_controller._log_event("ERROR", "settings_save_failed", "could not save user settings", {"error": save_error, "path": settings_path})


func _display_option(parent: VBoxContainer, label_text: String, tooltip: String) -> OptionButton:
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
	var option = OptionButton.new()
	option.custom_minimum_size = Vector2(220, 42)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_theme_font_override("font", host.medium_font)
	option.add_theme_font_size_override("font_size", host.TYPE_SCALE.detail)
	option.tooltip_text = tooltip
	row.add_child(option)
	return option


func _on_display_mode_selected(index: int) -> void:
	if not host.display_mode_option or index < 0:
		return
	host.display_mode = str(host.display_mode_option.get_item_metadata(index))
	host.ui_scale = host.display_settings_controller._nearest_available_ui_scale(host.ui_scale)
	host.display_settings_controller._apply_display_settings(true)


func _on_display_resolution_selected(index: int) -> void:
	if not host.display_resolution_option or host.display_resolution_option.disabled or index < 0:
		return
	var selected_resolution = host.display_resolution_option.get_item_metadata(index)
	if selected_resolution is Vector2i:
		host.display_resolution = selected_resolution
	host.ui_scale = host.display_settings_controller._nearest_available_ui_scale(host.ui_scale)
	host.display_settings_controller._apply_display_settings(true)


func _on_ui_scale_selected(index: int) -> void:
	if not host.ui_scale_option or index < 0:
		return
	host.ui_scale = float(host.ui_scale_option.get_item_metadata(index))
	host.display_settings_controller._apply_display_settings(true)


func _apply_display_settings(persist := true) -> void:
	if not host.DISPLAY_MODE_KEYS.has(host.display_mode):
		host.display_mode = "windowed"
	if not host.display_settings_controller._available_windowed_resolutions().has(host.display_resolution):
		host.display_resolution = host.display_settings_controller._available_windowed_resolutions()[0]
	host.ui_scale = host.display_settings_controller._nearest_available_ui_scale(host.ui_scale)
	if DisplayServer.get_name() != "headless":
		var window = host.get_window()
		window.content_scale_size = host.display_settings_controller._current_output_size()
		window.content_scale_factor = host.ui_scale
		match host.display_mode:
			"borderless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			"exclusive":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			_:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
				DisplayServer.window_set_min_size(Vector2i(960, 600))
				DisplayServer.window_set_size(host.display_resolution)
				host.display_settings_controller._center_window_on_current_screen(host.display_resolution)
	host.display_settings_controller._refresh_display_controls()
	if persist:
		host.display_settings_controller._save_user_settings()
		host.runtime_logger_controller._log_event("INFO", "display_settings_changed", "display settings applied", {
			"mode": host.display_mode,
			"resolution": "%dx%d" % [host.display_resolution.x, host.display_resolution.y],
			"ui_scale": host.ui_scale,
		})


func _center_window_on_current_screen(window_size: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var screen = DisplayServer.window_get_current_screen()
	var usable = DisplayServer.screen_get_usable_rect(screen)
	var centered = usable.position + (usable.size - window_size) / 2
	DisplayServer.window_set_position(Vector2i(maxi(usable.position.x, centered.x), maxi(usable.position.y, centered.y)))


func _refresh_display_controls() -> void:
	if not host.display_mode_option or not host.display_resolution_option or not host.ui_scale_option:
		return
	host.display_mode_option.clear()
	for key in host.DISPLAY_MODE_KEYS:
		var mode_index = host.display_mode_option.item_count
		host.display_mode_option.add_item(str(host.DISPLAY_MODE_LABELS[key]))
		host.display_mode_option.set_item_metadata(mode_index, key)
		if key == host.display_mode:
			host.display_mode_option.select(mode_index)

	host.display_resolution_option.clear()
	if host.display_mode == "windowed":
		host.display_resolution_option.disabled = false
		for resolution in host.display_settings_controller._available_windowed_resolutions():
			var resolution_index = host.display_resolution_option.item_count
			host.display_resolution_option.add_item(host.display_settings_controller._resolution_label(resolution))
			host.display_resolution_option.set_item_metadata(resolution_index, resolution)
			if resolution == host.display_resolution:
				host.display_resolution_option.select(resolution_index)
	else:
		host.display_resolution_option.disabled = true
		host.display_resolution_option.add_item("原生 · %s" % host.display_settings_controller._resolution_label(host.display_settings_controller._current_screen_size()))

	host.ui_scale_option.clear()
	for scale_value in host.display_settings_controller._available_ui_scales():
		var scale_index = host.ui_scale_option.item_count
		host.ui_scale_option.add_item("%d%%" % int(round(scale_value * 100.0)))
		host.ui_scale_option.set_item_metadata(scale_index, scale_value)
		if is_equal_approx(scale_value, host.ui_scale):
			host.ui_scale_option.select(scale_index)
	if host.display_status_label:
		var screen_size = host.display_settings_controller._current_screen_size()
		var quality_note = "已支持 4K 原生输出" if screen_size.x >= 3840 and screen_size.y >= 2160 else "4K 选项会在兼容显示器上出现"
		host.display_status_label.text = "当前显示器 %d × %d\n%s；场景素材仍按现有清晰度放大。" % [screen_size.x, screen_size.y, quality_note]


func _available_windowed_resolutions() -> Array[Vector2i]:
	var available: Array[Vector2i] = []
	if DisplayServer.get_name() == "headless":
		return host.DISPLAY_RESOLUTION_PRESETS.duplicate()
	var usable_size = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	for resolution in host.DISPLAY_RESOLUTION_PRESETS:
		if resolution.x <= usable_size.x and resolution.y <= usable_size.y:
			available.append(resolution)
	if available.is_empty():
		available.append(Vector2i(1280, 800))
	return available


func _available_ui_scales() -> Array[float]:
	var available: Array[float] = []
	var output_size = host.display_settings_controller._current_output_size()
	for scale_value in host.UI_SCALE_PRESETS:
		var virtual_size = Vector2i(roundi(output_size.x / scale_value), roundi(output_size.y / scale_value))
		if scale_value == 1.0 or (virtual_size.x >= host.MINIMUM_UI_CANVAS.x and virtual_size.y >= host.MINIMUM_UI_CANVAS.y):
			available.append(scale_value)
	return available


func _nearest_available_ui_scale(requested: float) -> float:
	var result = 1.0
	for scale_value in host.display_settings_controller._available_ui_scales():
		if scale_value <= requested or is_equal_approx(scale_value, requested):
			result = scale_value
	return result


func _current_output_size() -> Vector2i:
	return host.display_resolution if host.display_mode == "windowed" else host.display_settings_controller._current_screen_size()


func _current_screen_size() -> Vector2i:
	var screen_size = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	if screen_size.x <= 0 or screen_size.y <= 0:
		return Vector2i(3840, 2160)
	return screen_size


func _resolution_label(resolution: Vector2i) -> String:
	var suffix = ""
	match resolution:
		Vector2i(1280, 800):
			suffix = " · 基础"
		Vector2i(1920, 1080):
			suffix = " · 1080p"
		Vector2i(2560, 1440):
			suffix = " · 1440p"
		Vector2i(3840, 2160):
			suffix = " · 4K"
	return "%d × %d%s" % [resolution.x, resolution.y, suffix]


func _cycle_log_level() -> void:
	var level_index = host.LOG_LEVELS.find(host.log_level)
	host.log_level = host.LOG_LEVELS[(level_index + 1) % host.LOG_LEVELS.size()]
	if host.log_level_button:
		host.log_level_button.text = "日志等级 · %s" % host.log_level
	host.display_settings_controller._save_user_settings()
	host.runtime_logger_controller._log_event(host.log_level, "log_level_changed", "client log level changed", {"new_level": host.log_level, "server_effect": "next_start"})


func _audio_slider(parent: VBoxContainer, label_text: String, bus_name: String, initial_value: float) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 78
	label.add_theme_font_override("font", host.medium_font)
	label.add_theme_color_override("font_color", host.COLORS.ink)
	row.add_child(label)
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 32
	slider.value_changed.connect(host.display_settings_controller._set_bus_volume.bind(bus_name))
	row.add_child(slider)
	host.display_settings_controller._set_bus_volume(initial_value, bus_name)


func _set_bus_volume(value: float, bus_name: String) -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, value <= 0.0)
	if value > 0.0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value / 100.0))
