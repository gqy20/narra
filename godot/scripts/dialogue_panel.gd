extends RefCounted

var host


func _init(value) -> void:
	host = value


func _render_actor_dialogue_line(actor: Dictionary) -> void:
	var history: Array = host.actor_dialogue_history_by_id.get(host.focused_actor_id, [])
	if history.size() > 8:
		history = history.slice(history.size() - 8)
	for exchange in history:
		var from_player = str(exchange.get("speaker", "")) == "player"
		var history_panel = PanelContainer.new()
		var history_color = Color(host.COLORS.panel_hover, 0.34) if from_player else Color(host.COLORS.panel_alt, 0.42)
		var history_style = host.game_screen_controller._panel_style(history_color, 0, 2, Color.TRANSPARENT, 12, 8)
		history_style.border_width_left = 2
		history_style.border_color = Color(host.COLORS.muted, 0.52) if from_player else Color(host.COLORS.accent, 0.68)
		history_panel.add_theme_stylebox_override("panel", history_style)
		var history_content = VBoxContainer.new()
		history_content.add_theme_constant_override("separation", 4)
		history_panel.add_child(history_content)
		var speaker_name: String = str(host.current_view.get("player", {}).get("name", "你")) if from_player else str(actor.get("name", host.focused_actor_name))
		var history_speaker = host.game_screen_controller._text(history_content, speaker_name, true, 13)
		history_speaker.add_theme_color_override("font_color", host.COLORS.muted if from_player else host.COLORS.accent)
		var history_line = host.game_screen_controller._text(history_content, str(exchange.get("text", "")), false, 16)
		history_line.add_theme_font_override("font", host.narrative_font)
		host.actor_focus_message_list.add_child(history_panel)
	if not history.is_empty() and host.actor_dialogue_loading_id != host.focused_actor_id and not host.actor_dialogue_error_by_id.has(host.focused_actor_id):
		host.dialogue_panel_controller._render_actor_dialogue_input()
		return
	var panel = PanelContainer.new()
	var style = host.game_screen_controller._panel_style(Color(host.COLORS.panel_alt, 0.42), 0, 2, Color.TRANSPARENT, 14, 10)
	style.border_width_left = 2
	style.border_color = Color(host.COLORS.accent, 0.68)
	panel.add_theme_stylebox_override("panel", style)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	panel.add_child(content)
	var speaker = host.game_screen_controller._text(content, str(actor.get("name", host.focused_actor_name)), true, 13)
	speaker.add_theme_color_override("font_color", host.COLORS.accent)
	var utterance = "正在等待人物回应……"
	var quote_line = false
	if host.actor_dialogue_loading_id == host.focused_actor_id:
		utterance = "正在等待人物回应……"
	elif host.actor_dialogue_by_id.has(host.focused_actor_id):
		utterance = str(host.actor_dialogue_by_id[host.focused_actor_id].get("utterance", utterance))
		quote_line = true
	elif host.actor_dialogue_error_by_id.has(host.focused_actor_id):
		utterance = "对话生成失败：%s" % str(host.actor_dialogue_error_by_id[host.focused_actor_id])
	var line = host.game_screen_controller._text(content, "“%s”" % utterance if quote_line else utterance, false, 17)
	line.add_theme_font_override("font", host.narrative_font)
	host.actor_focus_message_list.add_child(panel)
	host.dialogue_panel_controller._render_actor_dialogue_input()


func _render_actor_dialogue_input() -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var input = LineEdit.new()
	input.placeholder_text = "直接回复，最多 500 字"
	input.max_length = 500
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.editable = host.actor_dialogue_loading_id != host.focused_actor_id
	input.text_submitted.connect(host.dialogue_panel_controller._submit_actor_dialogue)
	row.add_child(input)
	if host.actor_dialogue_loading_id == host.focused_actor_id:
		row.add_child(host.game_screen_controller._utility_button("取消", host.dialogue_panel_controller._cancel_actor_dialogue_generation))
	else:
		row.add_child(host.game_screen_controller._utility_button("发送", func(): host.dialogue_panel_controller._submit_actor_dialogue(input.text)))
	host.actor_focus_message_list.add_child(row)


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
		host.game_screen_controller._focus_portrait(actor_id)
	host.action_panel_controller._render_actions(host.available_actions_cache)


func _on_ai_dialogue_failed(actor_id: String, message: String) -> void:
	host.actor_dialogue_error_by_id[actor_id] = message
	if host.actor_dialogue_loading_id == actor_id:
		host.actor_dialogue_loading_id = ""
	if actor_id == host.focused_actor_id:
		host.action_panel_controller._render_actions(host.available_actions_cache)
