extends Node

const BUS_NAMES := ["Music", "Ambient", "Event", "UI"]

var ambient_players: Array[AudioStreamPlayer] = []
var event_player: AudioStreamPlayer
var ui_player: AudioStreamPlayer
var active_ambient := 0
var current_scene_key := ""
var enabled := true
var output_available := true


func _ready() -> void:
	output_available = DisplayServer.get_name() != "headless"
	_ensure_buses()
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Ambient"
		player.volume_db = -60.0
		add_child(player)
		ambient_players.append(player)
	event_player = AudioStreamPlayer.new()
	event_player.bus = "Event"
	add_child(event_player)
	ui_player = AudioStreamPlayer.new()
	ui_player.bus = "UI"
	add_child(ui_player)


func set_scene(scene_key: String) -> void:
	if scene_key == current_scene_key:
		return
	current_scene_key = scene_key
	if not output_available:
		return
	var next := 1 - active_ambient
	var incoming := ambient_players[next]
	var outgoing := ambient_players[active_ambient]
	incoming.stream = _ambient_stream(scene_key)
	incoming.volume_db = -60.0
	incoming.play()
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(incoming, "volume_db", -31.0 if enabled else -60.0, 1.1)
	if outgoing.playing:
		tween.tween_property(outgoing, "volume_db", -60.0, 0.8)
	active_ambient = next


func play_cue(kind: String, intensity := 1) -> void:
	if not enabled or not output_available:
		return
	var frequency: float = float({
		"travel": 340.0,
		"reveal": 620.0,
		"actor_focus": 440.0,
		"acquire": 520.0,
		"danger": 155.0,
		"time": 285.0,
	}.get(kind, 400.0))
	event_player.stream = _tone_stream(frequency, 0.20 + 0.05 * intensity, kind == "danger")
	event_player.volume_db = -20.0
	event_player.play()


func play_ui() -> void:
	if not enabled or not output_available:
		return
	ui_player.stream = _tone_stream(480.0, 0.07, false)
	ui_player.volume_db = -28.0
	ui_player.play()


func set_enabled(value: bool) -> void:
	enabled = value
	var target := -31.0 if enabled else -60.0
	if not ambient_players.is_empty():
		create_tween().tween_property(ambient_players[active_ambient], "volume_db", target, 0.3)


func _ensure_buses() -> void:
	for bus_name in BUS_NAMES:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _ambient_stream(scene_key: String) -> AudioStreamWAV:
	var frequency: float
	var air: float
	match scene_key:
		"qinglan":
			frequency = 72.0
			air = 0.16
		"apothecary":
			frequency = 64.0
			air = 0.08
		"valley_edge":
			frequency = 48.0
			air = 0.20
		"inner_valley":
			frequency = 42.0
			air = 0.24
		_:
			frequency = 58.0
			air = 0.10
	return _generated_wave(frequency, 4.0, air, true)


func _tone_stream(frequency: float, duration: float, dark: bool) -> AudioStreamWAV:
	return _generated_wave(frequency, duration, 0.02 if not dark else 0.08, false)


func _generated_wave(frequency: float, duration: float, noise_amount: float, looped: bool) -> AudioStreamWAV:
	const SAMPLE_RATE := 22050
	var sample_count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var random_state := 1731
	for index in sample_count:
		random_state = int((random_state * 1103515245 + 12345) & 0x7fffffff)
		var noise := (float(random_state % 2000) / 1000.0 - 1.0) * noise_amount
		var time := float(index) / SAMPLE_RATE
		var envelope := 1.0 if looped else sin(PI * minf(1.0, time / duration))
		var sample := (sin(TAU * frequency * time) * 0.09 + sin(TAU * frequency * 0.5 * time) * 0.04 + noise) * envelope
		data.encode_s16(index * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = sample_count
	return stream
