extends RefCounted

var host


func _init(value) -> void:
	host = value


func _build_ending_layer() -> void:
	host.ending_layer = Control.new()
	host.ending_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.ending_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	host.ending_layer.hide()
	host.add_child(host.ending_layer)
	host.ending_background = TextureRect.new()
	host.ending_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.ending_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.ending_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	host.ending_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.ending_layer.add_child(host.ending_background)
	var shade = ColorRect.new()
	shade.color = Color("030504a8")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.ending_layer.add_child(shade)
	host.ending_portrait = TextureRect.new()
	host.ending_portrait.anchor_left = 0.015
	host.ending_portrait.anchor_right = 0.42
	host.ending_portrait.anchor_top = 0.04
	host.ending_portrait.anchor_bottom = 1.0
	host.ending_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.ending_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.ending_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.ending_layer.add_child(host.ending_portrait)
	host.ending_seal = TextureRect.new()
	host.ending_seal.anchor_left = 0.775
	host.ending_seal.anchor_right = 0.925
	host.ending_seal.anchor_top = 0.085
	host.ending_seal.anchor_bottom = 0.31
	host.ending_seal.texture = host.CausalSealTexture
	host.ending_seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.ending_seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.ending_seal.modulate = Color(1, 1, 1, 0.17)
	host.ending_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.ending_layer.add_child(host.ending_seal)
	host.ending_box = VBoxContainer.new()
	host.ending_box.anchor_left = 0.445
	host.ending_box.anchor_right = 0.925
	host.ending_box.anchor_top = 0.13
	host.ending_box.anchor_bottom = 0.91
	host.ending_box.add_theme_constant_override("separation", 14)
	host.ending_layer.add_child(host.ending_box)


func _build_causal_layer() -> void:
	host.causal_layer = Control.new()
	host.causal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.causal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	host.causal_layer.hide()
	host.add_child(host.causal_layer)
	host.causal_background = TextureRect.new()
	host.causal_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.causal_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.causal_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	host.causal_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.causal_layer.add_child(host.causal_background)
	var shade = ColorRect.new()
	shade.color = Color("030504a8")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.causal_layer.add_child(shade)

	host.causal_portrait = TextureRect.new()
	host.causal_portrait.anchor_left = 0.015
	host.causal_portrait.anchor_right = 0.34
	host.causal_portrait.anchor_top = 0.035
	host.causal_portrait.anchor_bottom = 1.0
	host.causal_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.causal_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.causal_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.causal_layer.add_child(host.causal_portrait)

	var content = VBoxContainer.new()
	content.anchor_left = 0.39
	content.anchor_right = 0.94
	content.anchor_top = 0.13
	content.anchor_bottom = 0.94
	content.add_theme_constant_override("separation", 13)
	host.causal_layer.add_child(content)
	host.causal_actor_meta = host.game_screen_controller._text(content, "一念入局", true, 14)
	host.causal_actor_meta.add_theme_color_override("font_color", host.COLORS.accent)
	host.causal_message = host.game_screen_controller._text(content, "你送出的消息改变了一个人的判断", false, 27)
	host.causal_message.add_theme_font_override("font", host.narrative_font)
	host.causal_message.add_theme_color_override("font_color", Color("ead6a8"))
	host.causal_message.add_theme_constant_override("line_spacing", 6)

	var timeline = VBoxContainer.new()
	timeline.custom_minimum_size.y = 300
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.add_theme_constant_override("separation", 7)
	content.add_child(timeline)
	var before_heading = host.game_screen_controller._text(timeline, "改写之前", true, host.TYPE_SCALE.meta)
	before_heading.add_theme_color_override("font_color", host.COLORS.muted)
	host.causal_original = host.game_screen_controller._text(timeline, "原本的安排", false, 16)
	var arrow = TextureRect.new()
	arrow.custom_minimum_size = Vector2(0, 38)
	arrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arrow.texture = host.TimelineArrowTexture
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.modulate = Color(1, 1, 1, 0.78)
	timeline.add_child(arrow)
	var now_row = HBoxContainer.new()
	now_row.custom_minimum_size.y = 126
	now_row.add_theme_constant_override("separation", 16)
	timeline.add_child(now_row)
	var now_stack = VBoxContainer.new()
	now_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	now_stack.add_theme_constant_override("separation", 7)
	now_row.add_child(now_stack)
	var now_heading = host.game_screen_controller._text(now_stack, "现在", true, host.TYPE_SCALE.meta)
	now_heading.add_theme_color_override("font_color", host.COLORS.accent)
	host.causal_now = host.game_screen_controller._text(now_stack, "新的安排", false, 18)
	host.causal_now.add_theme_color_override("font_color", host.COLORS.ink)
	var seal = TextureRect.new()
	seal.custom_minimum_size = Vector2(128, 116)
	seal.texture = host.CausalSealTexture
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seal.modulate = Color(1, 1, 1, 0.48)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	now_row.add_child(seal)

	host.causal_day = host.game_screen_controller._text(content, "已有决断", true, 15)
	host.causal_day.add_theme_color_override("font_color", host.COLORS.accent)
	var continue_button = host.game_screen_controller._ornate_button("记下这次变化", host.presentation_controller._dismiss_causal)
	continue_button.custom_minimum_size = Vector2(380, 68)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	content.add_child(continue_button)


func _play_action_presentation(previous_view: Dictionary, next_view: Dictionary) -> void:
	host.presentation_director.cancel()
	if host.ending_layer.visible:
		host.causal_layer.hide()
		return
	var feedback: Dictionary = next_view.get("last_turn", {})
	var cue: Dictionary = feedback.get("presentation", {})
	var previous_location: Dictionary = previous_view.get("location", {})
	var next_location: Dictionary = next_view.get("location", {})
	var from_id = str(previous_location.get("id", ""))
	var to_id = str(next_location.get("id", ""))
	if from_id != "" and to_id != "" and from_id != to_id:
		host.presentation_busy = true
		host.game_screen_controller._set_buttons_disabled(host, true)
		host.game_screen_controller._set_visual_mode("map")
		host.place_label.text = host.game_screen_controller._header_place("%s → %s" % [previous_location.get("name", ""), next_location.get("name", "")])
		host.phase_label.text = host.game_screen_controller._header_phase_label("赶路中")
		host.audio_director.play_cue("travel", int(cue.get("intensity", 2)))
		var callback = host.presentation_controller._finish_travel_presentation.bind(feedback, previous_location, next_location)
		host.world_map_view.travel_finished.connect(callback, CONNECT_ONE_SHOT)
		host.world_map_view.animate_travel(from_id, to_id, int(previous_view.get("day", 0)), int(next_view.get("day", 0)))
		return
	host.presentation_controller._apply_presentation_cue(cue)
	if host.presentation_controller._has_causal_change(feedback):
		host.presentation_controller._present_causal_change(feedback, next_location)
		return
	host.presentation_director.present(feedback, str(previous_location.get("name", "")), str(next_location.get("name", "")))


func _finish_travel_presentation(feedback: Dictionary, previous_location: Dictionary, next_location: Dictionary) -> void:
	host.presentation_busy = false
	host.game_screen_controller._set_buttons_disabled(host, host.pending_operation != "")
	host.game_screen_controller._set_visual_mode("location")
	host.day_label.text = host.game_screen_controller._header_day(int(host.current_view.get("day", 0)), int(host.current_view.get("duration", 0)))
	host.place_label.text = host.game_screen_controller._header_place(str(next_location.get("name", "未知")))
	host.phase_label.text = host.game_screen_controller._header_phase_label(host.game_screen_controller._phase_display(str(host.current_view.get("phase", ""))))
	host.location_stage.play_establish()
	if host.presentation_controller._has_causal_change(feedback):
		host.presentation_controller._present_causal_change(feedback, next_location)
	else:
		host.presentation_director.present(feedback, str(previous_location.get("name", "")), str(next_location.get("name", "")))


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
	var actor_name = str(influence.get("actor_name", "有人"))
	var actor_id = host.game_screen_controller._actor_id_by_name(actor_name)
	if actor_id != "":
		host.causal_actor_id_by_name[actor_name] = actor_id
		host.last_causal_actor_id = actor_id
	elif host.causal_actor_id_by_name.has(actor_name):
		actor_id = str(host.causal_actor_id_by_name[actor_name])
	var fact_claim = str(influence.get("fact_claim", "你送出的消息"))
	var causal_key = actor_name
	var previous_count = int(host.causal_change_count_by_actor.get(causal_key, 0))
	host.causal_change_count_by_actor[causal_key] = previous_count + 1
	var change_day = int(change.get("day", feedback.get("day", host.current_view.get("day", 0))))
	if previous_count > 0:
		var ripple = feedback.duplicate(true)
		ripple["action"] = "余波继续 · %s" % actor_name
		ripple["messages"] = ["第 %d 日 · %s不再%s，转而%s。" % [change_day, actor_name, change.get("without_information", "照原计划行事"), change.get("with_information", "改变安排")]]
		host.presentation_director.present(ripple, "", "")
		host.audio_director.play_cue("focus", 2)
		return
	var profile: ActorVisualProfile = host.presentation_registry.actor_profile(actor_id)
	var location_profile: LocationVisualProfile = host.presentation_registry.location_profile(str(location.get("scene_key", "")))
	host.causal_background.texture = location_profile.background if location_profile and location_profile.background else null
	host.causal_portrait.texture = profile.portrait("decisive") if profile else null
	host.causal_actor_meta.text = "%s · 已有决断" % actor_name
	host.causal_message.text = "你告知%s：%s" % [actor_name, fact_claim]
	host.causal_original.text = str(change.get("without_information", "原有安排"))
	host.causal_now.text = str(change.get("with_information", "新的安排"))
	host.causal_day.text = "第 %d 日 · 由原本到现在，已有决断" % change_day
	host.causal_layer.modulate = Color(1, 1, 1, 0) if host.motion_enabled else Color.WHITE
	host.causal_layer.show()
	host.game_screen_controller._sync_action_canvas_visibility()
	var portrait_tint = Color(0.78, 0.78, 0.74, 1.0)
	host.causal_portrait.modulate = Color(portrait_tint, 0) if host.motion_enabled else portrait_tint
	host.causal_portrait.position.x = -32 if host.motion_enabled else 0
	if host.motion_enabled:
		var tween = host.create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(host.causal_layer, "modulate", Color.WHITE, 0.34)
		tween.tween_property(host.causal_portrait, "modulate", portrait_tint, 0.48).set_delay(0.10)
		tween.tween_property(host.causal_portrait, "position:x", 0.0, 0.62).set_delay(0.08)
	host.audio_director.play_cue("focus", 3)


func _dismiss_causal() -> void:
	host.audio_director.play_ui()
	host.causal_layer.hide()
	host.causal_layer.modulate = Color.WHITE
	host.game_screen_controller._sync_action_canvas_visibility()


func _apply_presentation_cue(cue: Dictionary) -> void:
	if cue.is_empty():
		return
	var kind = str(cue.get("kind", "time"))
	var intensity = int(cue.get("intensity", 1))
	host.audio_director.play_cue(kind, intensity)
	if kind in ["reveal", "danger", "focus", "acquire"]:
		host.location_stage.play_reveal(intensity)
	if kind == "actor_focus":
		host.game_screen_controller._focus_portrait(str(cue.get("subject_id", "")))


func _apply_feedback_actor_state(feedback: Dictionary) -> void:
	if feedback.is_empty():
		return
	var action_id = str(feedback.get("action_id", ""))
	if action_id.begins_with("tell:"):
		var parts = action_id.split(":")
		if parts.size() >= 2:
			host.actor_expression_by_id[str(parts[1])] = "troubled"
	for influence in feedback.get("influence", []):
		var actor_id = host.game_screen_controller._actor_id_by_name(str(influence.get("actor_name", "")))
		if actor_id != "":
			host.actor_expression_by_id[actor_id] = "decisive"


func _on_travel_day_changed(day: int) -> void:
	host.day_label.text = host.game_screen_controller._header_day(day, int(host.current_view.get("duration", 0)))


func _clear_footer_message_later(expected: String) -> void:
	await host.get_tree().create_timer(2.5).timeout
	if host.footer_label.text == expected:
		host.footer_label.text = ""


func _render_feedback_evidence_into(parent: VBoxContainer, feedback: Dictionary) -> void:
	var days = int(feedback.get("days_advanced", 0))
	if days > 0:
		var time_line = host.game_screen_controller._text(parent, "经过 · %d 日" % days, true, 13)
		time_line.add_theme_color_override("font_color", host.COLORS.accent)
	var quiet_days = int(feedback.get("quiet_days", 0))
	if quiet_days > 0:
		host.game_screen_controller._text(parent, "其中 %d 日没有新的公开变化" % quiet_days, true, 13)
	var influences: Array = feedback.get("influence", [])
	for influence in influences:
		for change in influence.get("changes", []):
			host.game_screen_controller._text(parent, "原本 · %s" % change.get("without_information", "其他安排"), true, 13)
			var current_line = host.game_screen_controller._text(parent, "改为 · %s" % change.get("with_information", "新的安排"), false, 14)
			current_line.add_theme_color_override("font_color", host.COLORS.success)


func _render_ending(ending: Dictionary) -> void:
	host.game_screen_controller._clear(host.ending_box)
	var location_profile: LocationVisualProfile = host.presentation_registry.location_profile(str(host.current_view.get("location", {}).get("scene_key", "")))
	var ending_event_key := str(host.scenario_presentation.get("ending_event", ""))
	var ending_event_texture: Texture2D = host.presentation_registry.event_texture(ending_event_key) if ending_event_key != "" else null
	host.ending_background.texture = ending_event_texture if ending_event_texture else (location_profile.background if location_profile and location_profile.background else null)
	var outcome = str(ending.get("outcome", host.current_view.get("outcome", "旅程结束")))
	var influences: Array = ending.get("influence", [])
	var ending_actor_id = ""
	for actor in host.current_view.get("known_actors", []):
		var actor_name = str(actor.get("name", ""))
		if actor_name != "" and outcome.contains(actor_name):
			ending_actor_id = str(actor.get("id", ""))
			break
	if ending_actor_id == "":
		ending_actor_id = host.last_causal_actor_id
	if ending_actor_id == "" and not influences.is_empty():
		ending_actor_id = host.game_screen_controller._actor_id_by_name(str(influences[0].get("actor_name", "")))
	var actor_profile: ActorVisualProfile = host.presentation_registry.actor_profile(ending_actor_id)
	host.ending_portrait.texture = actor_profile.portrait("decisive") if actor_profile else null
	host.ending_portrait.visible = host.ending_portrait.texture != null
	host.ending_box.anchor_left = 0.445 if host.ending_portrait.visible else 0.225
	var eyebrow = host.game_screen_controller._text(host.ending_box, "尘埃落定", true, 16)
	eyebrow.add_theme_color_override("font_color", host.COLORS.accent)
	var outcome_parts: PackedStringArray = outcome.split("。", false)
	var outcome_title = str(outcome_parts[0]).strip_edges() if not outcome_parts.is_empty() else outcome
	var title = host.game_screen_controller._text(host.ending_box, outcome_title, false, 40)
	title.add_theme_font_override("font", host.display_font)
	title.add_theme_color_override("font_color", Color("ead6a8"))
	for index in range(1, outcome_parts.size()):
		var outcome_body = host.game_screen_controller._text(host.ending_box, str(outcome_parts[index]).strip_edges(), false, 21)
		outcome_body.add_theme_color_override("font_color", Color("ded4c1"))
	var rule = HSeparator.new()
	rule.modulate = Color(host.COLORS.accent, 0.46)
	host.ending_box.add_child(rule)
	var consequences: Array = ending.get("player_consequences", [])
	var review: Array = ending.get("review", [])
	host.ending_annex_button = host.game_screen_controller._action_button("回看本局选择与余波", host.presentation_controller._toggle_ending_annex)
	host.ending_annex_button.custom_minimum_size.y = 42
	host.ending_annex_button.add_theme_font_size_override("font_size", 16)
	host.ending_box.add_child(host.ending_annex_button)
	host.ending_annex_box = VBoxContainer.new()
	host.ending_annex_box.add_theme_constant_override("separation", 6)
	host.ending_annex_box.hide()
	host.ending_box.add_child(host.ending_annex_box)
	if not consequences.is_empty():
		var consequence_heading = host.game_screen_controller._text(host.ending_annex_box, "本局余波", true, 16)
		consequence_heading.add_theme_color_override("font_color", host.COLORS.accent)
		for consequence in consequences:
			host.game_screen_controller._text(host.ending_annex_box, "· %s" % consequence, true, 15)
	if not review.is_empty():
		var review_heading = host.game_screen_controller._text(host.ending_annex_box, "结算依据", true, 16)
		review_heading.add_theme_color_override("font_color", host.COLORS.accent)
		for review_line in review:
			host.game_screen_controller._text(host.ending_annex_box, "· %s" % review_line, true, 15)
	if not influences.is_empty():
		var impact_heading = host.game_screen_controller._text(host.ending_annex_box, "你的介入", true, 16)
		impact_heading.add_theme_color_override("font_color", host.COLORS.accent)
		for influence in influences:
			host.game_screen_controller._text(host.ending_annex_box, "· 你将“%s”告诉了%s。" % [influence.get("fact_claim", "消息"), influence.get("actor_name", "某人")], true, 15)
			for change in influence.get("changes", []):
				host.game_screen_controller._text(host.ending_annex_box, "  第 %d 日：原本%s；后来%s。" % [int(change.get("day", 0)), change.get("without_information", "另有安排"), change.get("with_information", "改变计划")], true, 14)
	var record_heading = host.game_screen_controller._text(host.ending_annex_box, "本局记录", true, 16)
	record_heading.add_theme_color_override("font_color", host.COLORS.accent)
	for highlight in ending.get("highlights", []):
		if str(highlight).begins_with("你传递的消息改变了"):
			continue
		host.game_screen_controller._text(host.ending_annex_box, "· %s" % highlight, true, 15)
	var plan_changes: Array = ending.get("actor_plan_changes", [])
	if not plan_changes.is_empty():
		var plan_heading = host.game_screen_controller._text(host.ending_annex_box, "人物计划改写", true, 16)
		plan_heading.add_theme_color_override("font_color", host.COLORS.accent)
		for change in plan_changes:
			host.game_screen_controller._text(host.ending_annex_box, "· %s" % change, true, 15)
	var ending_actions = HBoxContainer.new()
	ending_actions.add_theme_constant_override("separation", 12)
	host.ending_box.add_child(ending_actions)
	var restart_button = host.game_screen_controller._ornate_button("换一条路 · 重新入局", host._restart_from_ending)
	restart_button.custom_minimum_size = Vector2(330, 62)
	restart_button.add_theme_font_size_override("font_size", 22)
	restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ending_actions.add_child(restart_button)
	var return_button = host.game_screen_controller._utility_button("返回卷首", host._return_to_start)
	return_button.custom_minimum_size = Vector2(132, 62)
	return_button.add_theme_font_size_override("font_size", 16)
	ending_actions.add_child(return_button)
	host.audio_director.stop_music(2.4)
	if not host.ending_cinematic_presented:
		host.ending_cinematic_presented = true
		var ending_video: VideoStream = host.presentation_registry.event_video(ending_event_key) if ending_event_key != "" else null
		if host.cinematic_director.play(ending_video, ending_event_key, host.presentation_controller._show_ending_after_cinematic):
			host.ending_layer.hide()
			host.game_screen_controller._sync_action_canvas_visibility()
			return
	if host.cinematic_director.active and host.cinematic_director.current_event_key == ending_event_key:
		host.ending_layer.hide()
		return
	host.presentation_controller._show_ending_after_cinematic(false)


func _show_ending_after_cinematic(_skipped: bool) -> void:
	host.ending_layer.show()
	host.game_screen_controller._sync_action_canvas_visibility()


func _toggle_ending_annex() -> void:
	if not host.ending_annex_box or not host.ending_annex_button:
		return
	host.ending_annex_box.visible = not host.ending_annex_box.visible
	host.ending_annex_button.text = "收起本局选择与余波" if host.ending_annex_box.visible else "回看本局选择与余波"
