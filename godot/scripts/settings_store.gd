class_name SettingsStore
extends RefCounted


func load_all(runtime_root: String, defaults: Dictionary, allowed: Dictionary) -> Dictionary:
	var result := defaults.duplicate(true)
	var config := ConfigFile.new()
	if config.load(runtime_root.path_join("settings.cfg")) == OK:
		var level := str(config.get_value("diagnostics", "log_level", result.log_level)).to_upper()
		if level in allowed.log_levels:
			result.log_level = level
		var mode := str(config.get_value("display", "mode", result.display_mode))
		if mode in allowed.display_modes:
			result.display_mode = mode
		var resolution: Variant = config.get_value("display", "resolution", result.display_resolution)
		if resolution is Vector2i and resolution in allowed.resolutions:
			result.display_resolution = resolution
		var scale := float(config.get_value("display", "ui_scale", result.ui_scale))
		for preset in allowed.ui_scales:
			if is_equal_approx(scale, preset):
				result.ui_scale = preset
				break
	var ai_path := runtime_root.path_join(str(defaults.ai_file))
	if FileAccess.file_exists(ai_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ai_path))
		if parsed is Dictionary:
			result.ai_enabled = bool(parsed.get("enabled", false))
			result.ai_model = str(parsed.get("model", result.ai_model)).strip_edges()
			result.ai_base_url = str(parsed.get("base_url", result.ai_base_url)).strip_edges()
			result.ai_api_key = str(parsed.get("api_key", "")).strip_edges()
		else:
			result.ai_error = "AI settings file is not valid JSON"
	return result


func save_user(runtime_root: String, values: Dictionary) -> Error:
	var config := ConfigFile.new()
	var path := runtime_root.path_join("settings.cfg")
	config.load(path)
	config.set_value("diagnostics", "log_level", values.log_level)
	config.set_value("display", "mode", values.display_mode)
	config.set_value("display", "resolution", values.display_resolution)
	config.set_value("display", "ui_scale", values.ui_scale)
	return config.save(path)


func save_ai(runtime_root: String, file_name: String, values: Dictionary) -> Error:
	var file := FileAccess.open(runtime_root.path_join(file_name), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({
		"enabled": values.enabled,
		"api_key": values.api_key,
		"model": values.model,
		"base_url": values.base_url,
	}, "\t"))
	file.flush()
	return OK
