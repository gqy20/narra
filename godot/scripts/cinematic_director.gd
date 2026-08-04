extends Control

signal playback_finished(event_key: String, skipped: bool)

var video_player: VideoStreamPlayer
var skip_button: Button
var active := false
var enabled := true
var current_event_key := ""
var completion_callback := Callable()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 1000

	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var frame := AspectRatioContainer.new()
	frame.ratio = 16.0 / 9.0
	frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	video_player = VideoStreamPlayer.new()
	video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video_player.expand = true
	video_player.loop = false
	video_player.bus = "Event"
	video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_player.finished.connect(_on_video_finished)
	frame.add_child(video_player)

	skip_button = Button.new()
	skip_button.text = "跳过镜头"
	skip_button.anchor_left = 1.0
	skip_button.anchor_right = 1.0
	skip_button.offset_left = -178.0
	skip_button.offset_right = -24.0
	skip_button.offset_top = 24.0
	skip_button.offset_bottom = 72.0
	skip_button.focus_mode = Control.FOCUS_ALL
	skip_button.add_theme_font_size_override("font_size", 16)
	skip_button.add_theme_color_override("font_color", Color("f2ebdd"))
	skip_button.add_theme_color_override("font_hover_color", Color("15110a"))
	var skip_normal := StyleBoxFlat.new()
	skip_normal.bg_color = Color("0b100dd9")
	skip_normal.border_color = Color("d6ae6299")
	skip_normal.set_border_width_all(1)
	skip_normal.set_corner_radius_all(2)
	skip_normal.content_margin_left = 12.0
	skip_normal.content_margin_top = 9.0
	skip_normal.content_margin_right = 12.0
	skip_normal.content_margin_bottom = 9.0
	skip_button.add_theme_stylebox_override("normal", skip_normal)
	var skip_hover: StyleBoxFlat = skip_normal.duplicate()
	skip_hover.bg_color = Color("d6ae62")
	skip_hover.border_color = Color("e4c079")
	skip_button.add_theme_stylebox_override("hover", skip_hover)
	var skip_focus: StyleBoxFlat = skip_normal.duplicate()
	skip_focus.border_color = Color("e4c079")
	skip_focus.set_border_width_all(2)
	skip_button.add_theme_stylebox_override("focus", skip_focus)
	skip_button.pressed.connect(skip)
	add_child(skip_button)
	hide()


func play(stream: VideoStream, event_key: String, callback := Callable()) -> bool:
	if active or not enabled or stream == null or DisplayServer.get_name() == "headless":
		return false
	active = true
	current_event_key = event_key
	completion_callback = callback
	video_player.stream = stream
	show()
	move_to_front()
	skip_button.grab_focus()
	video_player.play()
	return true


func skip() -> void:
	if active:
		_finish(true)


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled and active:
		_finish(true)


func _unhandled_input(event: InputEvent) -> void:
	if active and event.is_action_pressed("ui_cancel"):
		skip()
		get_viewport().set_input_as_handled()


func _on_video_finished() -> void:
	_finish(false)


func _finish(skipped: bool) -> void:
	if not active:
		return
	var finished_key := current_event_key
	var callback := completion_callback
	active = false
	current_event_key = ""
	completion_callback = Callable()
	video_player.stop()
	video_player.stream = null
	hide()
	playback_finished.emit(finished_key, skipped)
	if callback.is_valid():
		callback.call(skipped)
