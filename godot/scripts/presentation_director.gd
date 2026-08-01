extends Control

var card: PanelContainer
var title_label: Label
var message_label: Label
var generation := 0
var motion_enabled := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	card = PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.offset_left = -250
	card.offset_right = 250
	card.offset_top = -154
	card.offset_bottom = -42
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("151c17f2")
	panel.border_color = Color("866b38")
	panel.set_border_width_all(1)
	panel.corner_radius_top_left = 8
	panel.corner_radius_top_right = 8
	panel.corner_radius_bottom_left = 8
	panel.corner_radius_bottom_right = 8
	panel.content_margin_left = 20
	panel.content_margin_right = 20
	panel.content_margin_top = 15
	panel.content_margin_bottom = 15
	card.add_theme_stylebox_override("panel", panel)
	add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	card.add_child(content)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color("d6ae62"))
	content.add_child(title_label)
	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_color_override("font_color", Color("f2ebdd"))
	content.add_child(message_label)
	card.hide()


func present(feedback: Dictionary, from_location: String, to_location: String) -> void:
	if feedback.is_empty():
		return
	generation += 1
	var token := generation
	var entries: Array[String] = []
	if from_location != "" and to_location != "" and from_location != to_location:
		entries.append("%s → %s" % [from_location, to_location])
	for message in feedback.get("messages", []):
		entries.append(str(message))
	if entries.is_empty():
		entries.append(str(feedback.get("action", "局势已经推进")))
	_play_entries(entries, feedback, token)


func cancel() -> void:
	generation += 1
	card.hide()


func _play_entries(entries: Array[String], feedback: Dictionary, token: int) -> void:
	for entry in entries.slice(0, 4):
		if token != generation:
			return
		title_label.text = "第 %d 日 · %s" % [int(feedback.get("day", 0)), feedback.get("action", "行动结果")]
		message_label.text = entry
		card.show()
		if not motion_enabled:
			card.modulate = Color.WHITE
			card.offset_top = -154
			card.offset_bottom = -42
			await get_tree().create_timer(0.82).timeout
			if token != generation:
				return
			card.hide()
			continue
		card.modulate = Color(1, 1, 1, 0)
		card.offset_top = -132
		card.offset_bottom = -20
		var enter := create_tween().set_parallel(true)
		enter.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		enter.tween_property(card, "modulate:a", 1.0, 0.22)
		enter.tween_property(card, "offset_top", -154.0, 0.28)
		enter.tween_property(card, "offset_bottom", -42.0, 0.28)
		await enter.finished
		await get_tree().create_timer(0.82).timeout
		if token != generation:
			return
		var leave := create_tween().set_parallel(true)
		leave.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		leave.tween_property(card, "modulate:a", 0.0, 0.18)
		leave.tween_property(card, "offset_top", -166.0, 0.18)
		leave.tween_property(card, "offset_bottom", -54.0, 0.18)
		await leave.finished
	card.hide()
