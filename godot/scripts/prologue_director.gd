extends Control

signal playback_finished(skipped: bool)

const BodyFont = preload("res://assets/fonts/SourceHanSansCN-Regular.otf")
const DisplayFont = preload("res://assets/fonts/SourceHanSerifCN-SemiBold.otf")
const NarrativeFont = preload("res://assets/fonts/LXGWWenKaiLite-Regular.ttf")

var background: TextureRect
var beat_label: Label
var progress_label: Label
var prompt_button: Button
var skip_button: Button
var beats: Array = []
var current_beat_index := -1
var active := false
var skippable := true
var start_action := "进入故事"
var completion_callback := Callable()
var beat_tween: Tween
var playback_token := 0
var beat_settled := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 990

	background = TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var veil := ColorRect.new()
	veil.color = Color("080b09a8")
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	var lower_veil := TextureRect.new()
	var lower_gradient := Gradient.new()
	lower_gradient.offsets = PackedFloat32Array([0.0, 0.34, 1.0])
	lower_gradient.colors = PackedColorArray([Color("07090700"), Color("070907b8"), Color("070907f2")])
	var lower_texture := GradientTexture2D.new()
	lower_texture.gradient = lower_gradient
	lower_texture.width = 1
	lower_texture.height = 256
	lower_texture.fill_from = Vector2(0.5, 0.0)
	lower_texture.fill_to = Vector2(0.5, 1.0)
	lower_veil.texture = lower_texture
	lower_veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lower_veil.stretch_mode = TextureRect.STRETCH_SCALE
	lower_veil.anchor_top = 0.34
	lower_veil.anchor_right = 1.0
	lower_veil.anchor_bottom = 1.0
	lower_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lower_veil)

	progress_label = Label.new()
	progress_label.anchor_left = 0.07
	progress_label.anchor_top = 0.07
	progress_label.anchor_right = 0.30
	progress_label.anchor_bottom = 0.12
	progress_label.add_theme_font_override("font", BodyFont)
	progress_label.add_theme_font_size_override("font_size", 15)
	progress_label.add_theme_color_override("font_color", Color("d6ae62"))
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(progress_label)

	beat_label = Label.new()
	beat_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
	beat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	beat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	beat_label.add_theme_color_override("font_color", Color("f2ebdd"))
	beat_label.add_theme_color_override("font_shadow_color", Color("000000d9"))
	beat_label.add_theme_constant_override("shadow_offset_x", 2)
	beat_label.add_theme_constant_override("shadow_offset_y", 3)
	beat_label.add_theme_constant_override("line_spacing", 11)
	beat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(beat_label)

	prompt_button = Button.new()
	prompt_button.anchor_left = 0.68
	prompt_button.anchor_top = 0.89
	prompt_button.anchor_right = 0.94
	prompt_button.anchor_bottom = 0.96
	prompt_button.add_theme_font_override("font", BodyFont)
	prompt_button.add_theme_font_size_override("font_size", 16)
	prompt_button.add_theme_color_override("font_color", Color("e8ddc8"))
	prompt_button.add_theme_color_override("font_hover_color", Color("15110a"))
	var prompt_style := StyleBoxFlat.new()
	prompt_style.bg_color = Color("111713d9")
	prompt_style.border_color = Color("d6ae6299")
	prompt_style.set_border_width_all(1)
	prompt_style.set_corner_radius_all(2)
	prompt_button.add_theme_stylebox_override("normal", prompt_style)
	var prompt_hover: StyleBoxFlat = prompt_style.duplicate()
	prompt_hover.bg_color = Color("d6ae62")
	prompt_button.add_theme_stylebox_override("hover", prompt_hover)
	prompt_button.pressed.connect(advance)
	add_child(prompt_button)

	skip_button = Button.new()
	skip_button.text = "跳过序幕"
	skip_button.anchor_left = 0.84
	skip_button.anchor_top = 0.035
	skip_button.anchor_right = 0.96
	skip_button.anchor_bottom = 0.095
	skip_button.add_theme_font_override("font", BodyFont)
	skip_button.add_theme_font_size_override("font_size", 15)
	skip_button.flat = true
	skip_button.add_theme_color_override("font_color", Color("b8b7ad"))
	skip_button.add_theme_color_override("font_hover_color", Color("f2ebdd"))
	skip_button.pressed.connect(skip)
	add_child(skip_button)
	hide()


func play(config: Dictionary, texture: Texture2D, action_text: String, callback := Callable()) -> bool:
	if active or DisplayServer.get_name() == "headless":
		return false
	var configured_beats: Variant = config.get("beats", [])
	if not configured_beats is Array or configured_beats.is_empty():
		return false
	beats = configured_beats.duplicate(true)
	skippable = bool(config.get("skippable", true))
	start_action = action_text.strip_edges() if action_text.strip_edges() != "" else "进入故事"
	completion_callback = callback
	background.texture = texture
	skip_button.visible = skippable
	current_beat_index = -1
	active = true
	playback_token += 1
	show()
	move_to_front()
	_show_next_beat()
	return true


func advance() -> void:
	if not active:
		return
	if not beat_settled:
		_settle_current_beat()
		return
	_show_next_beat()


func skip() -> void:
	if active and skippable:
		_finish(true)


func cancel() -> void:
	if active:
		_finish(true, false)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("ui_cancel") and skippable:
		skip()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		get_viewport().set_input_as_handled()


func _show_next_beat() -> void:
	current_beat_index += 1
	if current_beat_index >= beats.size():
		_finish(false)
		return
	playback_token += 1
	var token := playback_token
	var beat: Dictionary = beats[current_beat_index]
	beat_label.text = str(beat.get("text", ""))
	progress_label.text = "%02d  /  %02d" % [current_beat_index + 1, beats.size()]
	_apply_typography(beat)
	var awaits_input := bool(beat.get("await_input", false))
	prompt_button.text = start_action if current_beat_index == beats.size() - 1 else "继续  ·  空格"
	prompt_button.visible = awaits_input or current_beat_index == beats.size() - 1
	beat_settled = false
	beat_label.modulate.a = 0.0
	if beat_tween and beat_tween.is_valid():
		beat_tween.kill()
	beat_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	beat_tween.tween_property(beat_label, "modulate:a", 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	beat_tween.finished.connect(func():
		if active and token == playback_token:
			beat_settled = true
	)
	var duration := float(beat.get("duration", 0.0))
	if not awaits_input and duration > 0.0:
		_auto_advance(token, duration)


func _auto_advance(token: int, duration: float) -> void:
	await get_tree().create_timer(duration, true, false, true).timeout
	if active and token == playback_token:
		_settle_current_beat()
		_show_next_beat()


func _settle_current_beat() -> void:
	if beat_tween and beat_tween.is_valid():
		beat_tween.kill()
	beat_label.modulate.a = 1.0
	beat_settled = true


func _apply_typography(beat: Dictionary) -> void:
	var font_role := str(beat.get("font", "body"))
	var font: Font = BodyFont
	if font_role == "display":
		font = DisplayFont
	elif font_role == "narrative":
		font = NarrativeFont
	beat_label.add_theme_font_override("font", font)
	var viewport_height := get_viewport_rect().size.y
	var responsive_scale := clampf(viewport_height / 800.0, 1.0, 1.25)
	beat_label.add_theme_font_size_override("font_size", roundi(float(beat.get("font_size", 28)) * responsive_scale))
	var position := str(beat.get("position", "lower_center"))
	if position == "center":
		beat_label.anchor_left = 0.17
		beat_label.anchor_top = 0.26
		beat_label.anchor_right = 0.83
		beat_label.anchor_bottom = 0.68
		beat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif position == "lower_left":
		beat_label.anchor_left = 0.075
		beat_label.anchor_top = 0.53
		beat_label.anchor_right = 0.66
		beat_label.anchor_bottom = 0.85
		beat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		beat_label.anchor_left = 0.15
		beat_label.anchor_top = 0.55
		beat_label.anchor_right = 0.85
		beat_label.anchor_bottom = 0.86
		beat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	beat_label.offset_left = 0.0
	beat_label.offset_top = 0.0
	beat_label.offset_right = 0.0
	beat_label.offset_bottom = 0.0


func _finish(skipped: bool, notify := true) -> void:
	if not active:
		return
	var callback := completion_callback
	active = false
	playback_token += 1
	completion_callback = Callable()
	if beat_tween and beat_tween.is_valid():
		beat_tween.kill()
	hide()
	if notify:
		playback_finished.emit(skipped)
		if callback.is_valid():
			callback.call(skipped)
