extends Control

const AppVisualThemeScript = preload("res://ui/theme/app_visual_theme.gd")
const HOLD_SECONDS := 2.15
const REDUCED_MOTION_HOLD_SECONDS := 2.8

var card: PanelContainer
var title_label: Label
var message_label: Label
var accent_line: ColorRect
var wash: TextureRect
var illustration: TextureRect
var text_stack: VBoxContainer
var presentation_registry
var generation := 0
var motion_enabled := true
var active_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20

	card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.clip_contents = true
	add_child(card)

	var clear_panel := StyleBoxFlat.new()
	clear_panel.bg_color = Color.TRANSPARENT
	card.add_theme_stylebox_override("panel", clear_panel)

	wash = TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.78, 1.0])
	gradient.colors = PackedColorArray([
		AppVisualThemeScript.alpha8(AppVisualThemeScript.COLORS.surface_toast, 0xed),
		AppVisualThemeScript.alpha8(AppVisualThemeScript.COLORS.surface_toast, 0xc7),
		AppVisualThemeScript.alpha8(AppVisualThemeScript.COLORS.surface_toast, 0x00),
	])
	var wash_texture := GradientTexture2D.new()
	wash_texture.gradient = gradient
	wash_texture.width = 384
	wash_texture.height = 96
	wash_texture.fill_from = Vector2(0.0, 0.5)
	wash_texture.fill_to = Vector2(1.0, 0.5)
	wash.texture = wash_texture
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(wash)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)
	margin.add_child(row)

	illustration = TextureRect.new()
	illustration.custom_minimum_size = Vector2(142, 86)
	illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	illustration.hide()
	row.add_child(illustration)

	accent_line = ColorRect.new()
	accent_line.color = AppVisualThemeScript.alpha8(AppVisualThemeScript.COLORS.accent, 0xdc)
	accent_line.custom_minimum_size.x = 2
	accent_line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(accent_line)

	text_stack = VBoxContainer.new()
	text_stack.add_theme_constant_override("separation", 3)
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text_stack)

	title_label = Label.new()
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", AppVisualThemeScript.COLORS.accent)
	title_label.add_theme_color_override("font_outline_color", AppVisualThemeScript.alpha8(AppVisualThemeScript.COLORS.bg_deep, 0xe8))
	title_label.add_theme_constant_override("outline_size", 3)
	text_stack.add_child(title_label)

	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	message_label.max_lines_visible = 1
	message_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	message_label.add_theme_font_size_override("font_size", 15)
	message_label.add_theme_color_override("font_color", AppVisualThemeScript.COLORS.ink)
	message_label.add_theme_color_override("font_outline_color", AppVisualThemeScript.alpha8(AppVisualThemeScript.COLORS.bg_deep, 0xed))
	message_label.add_theme_constant_override("outline_size", 3)
	text_stack.add_child(message_label)

	card.hide()


func configure(display_font: Font, medium_font: Font, registry = null, type_scale := {}) -> void:
	presentation_registry = registry
	if title_label:
		title_label.add_theme_font_override("font", display_font)
		title_label.add_theme_font_size_override("font_size", int(type_scale.get("meta", 14)))
	if message_label:
		message_label.add_theme_font_override("font", medium_font)
		message_label.add_theme_font_size_override("font_size", int(type_scale.get("compact", 15)))


func present(feedback: Dictionary, from_location: String, to_location: String) -> void:
	if feedback.is_empty():
		return
	_stop_active_tween()
	generation += 1
	var token := generation
	var echo := _compose_echo(feedback, from_location, to_location)
	title_label.text = str(echo.get("title", "局势回响"))
	message_label.text = str(echo.get("message", "局势已经推进"))
	var action_id := str(feedback.get("action_id", ""))
	illustration.texture = presentation_registry.event_texture_for_action(action_id) if presentation_registry else null
	illustration.visible = illustration.texture != null
	_configure_placement(str(echo.get("placement", "peripheral")), illustration.visible)
	_play_echo(token)


func cancel() -> void:
	_stop_active_tween()
	generation += 1
	if card:
		card.hide()


func _compose_echo(feedback: Dictionary, from_location: String, to_location: String) -> Dictionary:
	var action_id := str(feedback.get("action_id", ""))
	var action := str(feedback.get("action", "行动结果"))
	var cue_value = feedback.get("presentation", {})
	var cue: Dictionary = cue_value if cue_value is Dictionary else {}
	var kind := str(cue.get("kind", "time"))
	var messages := _feedback_messages(feedback)

	if action.begins_with("余波继续"):
		return {
			"title": action,
			"message": _first_meaningful_message(messages, "人物的选择仍在改变局势"),
			"placement": "actor",
		}

	if kind == "actor_focus" or action_id.begins_with("tell:"):
		var actor_name := _delivered_actor(messages)
		return {
			"title": actor_name if actor_name != "" else "消息已送达",
			"message": "记下了这句话" if actor_name != "" else "这句话已经被听见",
			"placement": "actor",
		}

	if kind == "focus":
		if action_id.begins_with("verify:"):
			return {"title": presentation_registry.ui_text("cue_verify_title"), "message": presentation_registry.ui_text("cue_verify_message"), "placement": "peripheral"}
		if action_id.begins_with("cultivate"):
			return {"title": presentation_registry.ui_text("cue_growth_title"), "message": _first_meaningful_message(messages, presentation_registry.ui_text("cue_growth_message")), "placement": "peripheral"}
		return {"title": action, "message": _first_meaningful_message(messages, "行动已经开始"), "placement": "peripheral"}

	if kind == "reveal":
		return {
			"title": presentation_registry.ui_text("cue_reveal_title"),
			"message": _preferred_message(messages, [presentation_registry.ui_text("term_clue"), presentation_registry.ui_text("confidence_confirmed"), presentation_registry.ui_text("confidence_plausible")], presentation_registry.ui_text("cue_reveal_message")),
			"placement": "peripheral",
		}

	if kind == "acquire":
		return {
			"title": presentation_registry.ui_text("cue_acquire_title"),
			"message": _first_meaningful_message(messages, presentation_registry.ui_text("cue_acquire_message")),
			"placement": "peripheral",
		}

	if kind == "recovery":
		return {
			"title": presentation_registry.ui_text("cue_recovery_title"),
			"message": _first_meaningful_message(messages, presentation_registry.ui_text("cue_recovery_message")),
			"placement": "peripheral",
		}

	if kind == "danger":
		return {
			"title": presentation_registry.ui_text("cue_danger_title"),
			"message": _first_meaningful_message(messages, presentation_registry.ui_text("cue_danger_message")),
			"placement": "peripheral",
		}

	if kind == "travel" and from_location != "" and to_location != "":
		return {
			"title": "抵达%s" % to_location,
			"message": "%s → %s" % [from_location, to_location],
			"placement": "peripheral",
		}

	var day := int(feedback.get("day", 0))
	var title := "第 %d 日" % day if day > 0 else action
	return {
		"title": title,
		"message": _first_meaningful_message(messages, action),
		"placement": "peripheral",
	}


func _feedback_messages(feedback: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var raw_messages = feedback.get("messages", [])
	if not raw_messages is Array:
		return result
	for raw_message in raw_messages:
		var message := str(raw_message).strip_edges()
		if message != "":
			result.append(message)
	return result


func _delivered_actor(messages: Array[String]) -> String:
	var prefix: String = str(presentation_registry.ui_text("feedback_delivery_prefix"))
	for message in messages:
		if message.begins_with(prefix):
			return message.trim_prefix(prefix).trim_suffix("。").strip_edges()
	return ""


func _preferred_message(messages: Array[String], needles: Array[String], fallback: String) -> String:
	for needle in needles:
		for message in messages:
			if message.contains(needle) and not _is_system_explanation(message):
				return _clean_message(message)
	return _first_meaningful_message(messages, fallback)


func _first_meaningful_message(messages: Array[String], fallback: String) -> String:
	for message in messages:
		if not _is_system_explanation(message):
			return _clean_message(message)
	return fallback


func _is_system_explanation(message: String) -> bool:
	return (
		message.contains("对方是否改变行动")
		or message.contains("会在后续局势变化时显现")
		or message.contains("已经结算")
	)


func _clean_message(message: String) -> String:
	var result := message.strip_edges().trim_suffix("。")
	if result.begins_with("物品 "):
		result = result.trim_prefix("物品 ")
	if result.length() > 42:
		result = result.left(41) + "…"
	return result


func _configure_placement(placement: String, has_illustration := false) -> void:
	wash.modulate.a = 0.44 if placement == "actor" else 0.66
	card.anchor_left = 1.0 if placement == "actor" else 0.0
	card.anchor_right = card.anchor_left
	card.anchor_top = 1.0 if placement == "actor" else 0.0
	card.anchor_bottom = card.anchor_top
	if placement == "actor":
		card.offset_left = -520 if has_illustration else -368
		card.offset_right = -58
		card.offset_top = -292 if has_illustration else -268
		card.offset_bottom = -192
	else:
		card.offset_left = 48
		card.offset_right = 820 if has_illustration else 760
		card.offset_top = 145
		card.offset_bottom = 251 if has_illustration else 223


func _play_echo(token: int) -> void:
	card.show()
	card.modulate = Color.WHITE
	text_stack.modulate = Color.WHITE
	accent_line.modulate = Color.WHITE
	accent_line.scale.y = 1.0
	if not motion_enabled:
		await get_tree().create_timer(REDUCED_MOTION_HOLD_SECONDS).timeout
		if token == generation:
			card.hide()
		return

	card.modulate.a = 0.0
	text_stack.modulate.a = 0.0
	accent_line.modulate.a = 0.0
	accent_line.scale.y = 0.12
	var resting_x := card.position.x
	card.position.x = resting_x + 10.0
	var enter := create_tween().set_parallel(true)
	active_tween = enter
	enter.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	enter.tween_property(card, "modulate:a", 1.0, 0.18)
	enter.tween_property(card, "position:x", resting_x, 0.30)
	enter.tween_property(accent_line, "modulate:a", 1.0, 0.16)
	enter.tween_property(accent_line, "scale:y", 1.0, 0.16)
	enter.tween_property(text_stack, "modulate:a", 1.0, 0.20).set_delay(0.12)
	await get_tree().create_timer(0.32).timeout
	if token != generation:
		return
	await get_tree().create_timer(HOLD_SECONDS).timeout
	if token != generation:
		return
	var leave := create_tween().set_parallel(true)
	active_tween = leave
	leave.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	leave.tween_property(card, "modulate:a", 0.0, 0.24)
	leave.tween_property(card, "position:x", resting_x + 6.0, 0.24)
	await get_tree().create_timer(0.25).timeout
	if token == generation:
		card.position.x = resting_x
		card.hide()


func _stop_active_tween() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = null
