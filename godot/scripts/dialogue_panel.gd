extends RefCounted

var host
var screen


func _init(value, game_screen) -> void:
	host = value
	screen = game_screen


func _render_actor_dialogue_line(actor: Dictionary) -> void:
	var full_history: Array = host.actor_dialogue_history_by_id.get(host.focused_actor_id, [])
	var visible_count: int = int(host.actor_dialogue_visible_count_by_id.get(host.focused_actor_id, 8))
	visible_count = maxi(8, visible_count)
	if full_history.size() > visible_count:
		var hidden_count := full_history.size() - visible_count
		var older_button: Button = host.ui_factory.utility_button("查看更早对话 · %d 条" % hidden_count, host.dialogue_panel_controller._show_older_actor_dialogue.bind(host.focused_actor_id))
		older_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		screen.actor_focus_message_list.add_child(older_button)
	var history: Array = full_history
	if history.size() > visible_count:
		history = history.slice(history.size() - visible_count)
	for exchange in history:
		var from_player = str(exchange.get("speaker", "")) == "player"
		var history_panel = PanelContainer.new()
		var history_color = Color(host.COLORS.panel_hover, 0.34) if from_player else Color(host.COLORS.panel_alt, 0.42)
		var history_style = host.ui_factory.panel_style(history_color, 0, 2, Color.TRANSPARENT, 12, 8)
		history_style.border_width_left = 2
		history_style.border_color = Color(host.COLORS.muted, 0.52) if from_player else Color(host.COLORS.accent, 0.68)
		history_panel.add_theme_stylebox_override("panel", history_style)
		var history_content = VBoxContainer.new()
		history_content.add_theme_constant_override("separation", 4)
		history_panel.add_child(history_content)
		var speaker_name: String = str(host.current_view.get("player", {}).get("name", "你")) if from_player else str(actor.get("name", host.focused_actor_name))
		var history_speaker = host.ui_factory.text(history_content, speaker_name, true, 13)
		history_speaker.add_theme_color_override("font_color", host.COLORS.muted if from_player else host.COLORS.accent)
		var history_line = host.ui_factory.text(history_content, str(exchange.get("text", "")), false, 16)
		history_line.add_theme_font_override("font", host.narrative_font)
		screen.actor_focus_message_list.add_child(history_panel)
	if not history.is_empty() and host.actor_dialogue_loading_id != host.focused_actor_id and not host.actor_dialogue_error_by_id.has(host.focused_actor_id):
		host.dialogue_panel_controller._render_actor_dialogue_input()
		host.dialogue_panel_controller._scroll_dialogue_to_latest()
		return
	var panel = PanelContainer.new()
	var style = host.ui_factory.panel_style(Color(host.COLORS.panel_alt, 0.42), 0, 2, Color.TRANSPARENT, 14, 10)
	style.border_width_left = 2
	style.border_color = Color(host.COLORS.accent, 0.68)
	panel.add_theme_stylebox_override("panel", style)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	panel.add_child(content)
	var utterance = "等待回应"
	var quote_line = false
	if host.actor_dialogue_loading_id == host.focused_actor_id:
		utterance = "等待回应"
	elif host.actor_dialogue_by_id.has(host.focused_actor_id):
		utterance = str(host.actor_dialogue_by_id[host.focused_actor_id].get("utterance", utterance))
		quote_line = true
	elif host.actor_dialogue_error_by_id.has(host.focused_actor_id):
		utterance = "对话生成失败：%s" % str(host.actor_dialogue_error_by_id[host.focused_actor_id])
	var line = host.ui_factory.text(content, "“%s”" % utterance if quote_line else utterance, false, 17)
	line.add_theme_font_override("font", host.narrative_font)
	screen.actor_focus_message_list.add_child(panel)
	host.dialogue_panel_controller._render_actor_dialogue_input()
	host.dialogue_panel_controller._scroll_dialogue_to_latest()


func _render_actor_dialogue_input() -> void:
	host.ui_factory.clear(screen.actor_dialogue_input_host)
	var rule := HSeparator.new()
	rule.modulate = Color(host.COLORS.accent, 0.22)
	screen.actor_dialogue_input_host.add_child(rule)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var input := TextEdit.new()
	input.name = "ActorDialogueInput"
	input.placeholder_text = "输入回复；Enter 发送，Shift+Enter 换行"
	input.custom_minimum_size.y = 72
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.editable = host.actor_dialogue_loading_id != host.focused_actor_id
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input.text_changed.connect(host.dialogue_panel_controller._limit_actor_dialogue_input.bind(input))
	input.gui_input.connect(host.dialogue_panel_controller._on_actor_dialogue_input_gui_input.bind(input))
	row.add_child(input)
	if host.actor_dialogue_loading_id == host.focused_actor_id:
		row.add_child(host.ui_factory.utility_button("取消", host.dialogue_panel_controller._cancel_actor_dialogue_generation))
	else:
		row.add_child(host.ui_factory.utility_button("发送", func(): host.dialogue_panel_controller._submit_actor_dialogue(input.text)))
	screen.actor_dialogue_input_host.add_child(row)


func _limit_actor_dialogue_input(input: TextEdit) -> void:
	if input.text.length() <= 500:
		return
	input.text = input.text.left(500)
	var final_line := maxi(0, input.get_line_count() - 1)
	input.set_caret_line(final_line)
	input.set_caret_column(input.get_line(final_line).length())


func _on_actor_dialogue_input_gui_input(event: InputEvent, input: TextEdit) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode not in [KEY_ENTER, KEY_KP_ENTER] or event.shift_pressed or input.has_ime_text():
		return
	input.accept_event()
	host.dialogue_panel_controller._submit_actor_dialogue(input.text)


func _show_older_actor_dialogue(actor_id: String) -> void:
	var history: Array = host.actor_dialogue_history_by_id.get(actor_id, [])
	var visible_count: int = int(host.actor_dialogue_visible_count_by_id.get(actor_id, 8))
	host.actor_dialogue_visible_count_by_id[actor_id] = mini(history.size(), visible_count + 8)
	host.action_panel_controller._render_actions(host.available_actions_cache)
	screen.actor_focus_message_scroll.set_deferred("scroll_vertical", 0)


func _scroll_dialogue_to_latest() -> void:
	if screen.actor_focus_message_scroll:
		screen.actor_focus_message_scroll.set_deferred("scroll_vertical", 1000000)


func _submit_actor_dialogue(message: String) -> void:
	message = message.strip_edges()
	if host.focused_actor_id == "" or message == "" or host.actor_dialogue_loading_id != "":
		return
	var history: Array = host.actor_dialogue_history_by_id.get(host.focused_actor_id, [])
	history.append({"speaker": "player", "text": message})
	host.actor_dialogue_history_by_id[host.focused_actor_id] = history
	host.actor_dialogue_error_by_id.erase(host.focused_actor_id)
	host.actor_dialogue_loading_id = host.focused_actor_id
	host.dialogue_client.request_turn(host.focused_actor_id, message)
	host.action_panel_controller._render_actions(host.available_actions_cache)


func _cancel_actor_dialogue_generation() -> void:
	if host.focused_actor_id == "":
		return
	host.dialogue_client.cancel()
	host.actor_dialogue_loading_id = ""
	host.actor_dialogue_error_by_id[host.focused_actor_id] = "本次生成已取消"
	host.action_panel_controller._render_actions(host.available_actions_cache)


func _on_ai_dialogue_ready(actor_id: String, dialogue: Dictionary) -> void:
	host.actor_dialogue_by_id[actor_id] = dialogue
	var history: Array = host.actor_dialogue_history_by_id.get(actor_id, [])
	history.append({"speaker": "npc", "text": str(dialogue.get("utterance", ""))})
	host.actor_dialogue_history_by_id[actor_id] = history
	host.actor_dialogue_error_by_id.erase(actor_id)
	if host.actor_dialogue_loading_id == actor_id:
		host.actor_dialogue_loading_id = ""
	if actor_id != host.focused_actor_id:
		return
	var emotion = str(dialogue.get("emotion", ""))
	if emotion in ["neutral", "alert", "troubled", "decisive"]:
		host.actor_expression_by_id[actor_id] = emotion
		screen._focus_portrait(actor_id)
	host.action_panel_controller._render_actions(host.available_actions_cache)


func _on_ai_dialogue_failed(actor_id: String, message: String) -> void:
	host.actor_dialogue_error_by_id[actor_id] = message
	if host.actor_dialogue_loading_id == actor_id:
		host.actor_dialogue_loading_id = ""
	if actor_id == host.focused_actor_id:
		host.action_panel_controller._render_actions(host.available_actions_cache)
