extends Control

const PresentationRegistryScript = preload("res://scripts/presentation_registry.gd")
const INK := Color("efe7d7")
const ACCENT := Color("d6ae62")
const MIST := Color("8fa69a")

var location: Dictionary = {}
var drift := 0.0
var registry = PresentationRegistryScript.new()
var visual_profile: LocationVisualProfile


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size = Vector2(640, 320)
	set_process(true)


func set_location(value: Dictionary) -> void:
	location = value
	visual_profile = registry.location_profile(str(value.get("scene_key", "")))
	queue_redraw()


func has_formal_asset() -> bool:
	return visual_profile != null and visual_profile.background != null


func play_establish() -> void:
	pivot_offset = size * 0.5
	scale = Vector2(1.035, 1.035)
	modulate = Color(0.72, 0.76, 0.73, 0.25)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.72)
	tween.tween_property(self, "modulate", Color.WHITE, 0.46)


func play_reveal(intensity := 1) -> void:
	pivot_offset = size * 0.5
	var zoom := 1.012 + 0.008 * intensity
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", Vector2(zoom, zoom), 0.24)
	tween.tween_property(self, "scale", Vector2.ONE, 0.42)


func _process(delta: float) -> void:
	drift = fmod(drift + delta * 5.0, 160.0)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101814"), true)
	var key := str(location.get("scene_key", "market"))
	if has_formal_asset():
		_draw_cover_texture(visual_profile.background)
		_draw_mist(key)
		_draw_vignette()
		return
	_draw_sky(key)
	_draw_mountains(key)
	match key:
		"market":
			_draw_market()
		"qinglan":
			_draw_camp()
		"apothecary":
			_draw_apothecary()
		"valley_edge":
			_draw_valley(false)
		"inner_valley":
			_draw_valley(true)
		_:
			_draw_market()
	_draw_mist(key)
	_draw_vignette()


func _draw_cover_texture(texture: Texture2D) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0 or texture_size.y <= 0 or size.x <= 0 or size.y <= 0:
		return
	var target_ratio := size.x / size.y
	var source_ratio := texture_size.x / texture_size.y
	var source := Rect2(Vector2.ZERO, texture_size)
	if source_ratio > target_ratio:
		var cropped_width := texture_size.y * target_ratio
		source.position.x = (texture_size.x - cropped_width) * 0.5
		source.size.x = cropped_width
	else:
		var cropped_height := texture_size.x / target_ratio
		source.position.y = (texture_size.y - cropped_height) * 0.5
		source.size.y = cropped_height
	draw_texture_rect_region(texture, Rect2(Vector2.ZERO, size), source)


func _draw_sky(key: String) -> void:
	var top := Color("15221b")
	var bottom := Color("2b2b20")
	if key in ["valley_edge", "inner_valley"]:
		top = Color("0c1513")
		bottom = Color("202725")
	for index in 12:
		var ratio := float(index) / 11.0
		draw_rect(Rect2(0, size.y * ratio / 1.8, size.x, size.y / 11.0 + 2), top.lerp(bottom, ratio), true)
	draw_circle(Vector2(size.x * 0.78, size.y * 0.19), 38.0, Color(ACCENT, 0.16))
	draw_circle(Vector2(size.x * 0.78, size.y * 0.19), 27.0, Color("d9c68d"))


func _draw_mountains(key: String) -> void:
	var rear := PackedVector2Array([
		Vector2(0, size.y * 0.58), Vector2(size.x * 0.14, size.y * 0.25),
		Vector2(size.x * 0.29, size.y * 0.56), Vector2(size.x * 0.48, size.y * 0.18),
		Vector2(size.x * 0.67, size.y * 0.55), Vector2(size.x * 0.84, size.y * 0.27),
		Vector2(size.x, size.y * 0.54), Vector2(size.x, size.y), Vector2(0, size.y),
	])
	draw_colored_polygon(rear, Color("18251e") if key not in ["valley_edge", "inner_valley"] else Color("121b1a"))
	var front := PackedVector2Array([
		Vector2(0, size.y * 0.70), Vector2(size.x * 0.22, size.y * 0.43),
		Vector2(size.x * 0.40, size.y * 0.68), Vector2(size.x * 0.64, size.y * 0.38),
		Vector2(size.x * 0.82, size.y * 0.64), Vector2(size.x, size.y * 0.45),
		Vector2(size.x, size.y), Vector2(0, size.y),
	])
	draw_colored_polygon(front, Color("111a15"))


func _draw_market() -> void:
	_draw_ground(Color("29271d"))
	for index in 5:
		var x := size.x * (0.03 + index * 0.21)
		var height := size.y * (0.22 + 0.04 * (index % 2))
		_draw_building(Rect2(x, size.y * 0.74 - height, size.x * 0.17, height), Color("302b20"), index % 2 == 0)
	for index in 7:
		var lantern := Vector2(size.x * (0.09 + index * 0.135), size.y * (0.56 + 0.025 * sin(index)))
		draw_line(lantern - Vector2(0, 18), lantern, Color("5d5135"), 1.0)
		draw_circle(lantern, 5.0, Color("d18b45"))
		draw_circle(lantern, 13.0, Color("d18b45", 0.08))


func _draw_camp() -> void:
	_draw_ground(Color("202920"))
	for index in 5:
		var center := Vector2(size.x * (0.12 + index * 0.19), size.y * (0.73 - 0.03 * (index % 2)))
		var tent := PackedVector2Array([center + Vector2(-44, 18), center + Vector2(0, -42), center + Vector2(44, 18)])
		draw_colored_polygon(tent, Color("354339"))
		draw_polyline(PackedVector2Array([tent[0], tent[1], tent[2]]), Color("73806f"), 1.2)
	for x in [0.18, 0.54, 0.84]:
		var pole_x: float = size.x * float(x)
		draw_line(Vector2(pole_x, size.y * 0.35), Vector2(pole_x, size.y * 0.73), Color("6e6450"), 2.0)
		var flag := PackedVector2Array([Vector2(pole_x, size.y * 0.36), Vector2(pole_x + 48, size.y * 0.39), Vector2(pole_x, size.y * 0.48)])
		draw_colored_polygon(flag, Color("607b70"))


func _draw_apothecary() -> void:
	_draw_ground(Color("25281d"))
	var building := Rect2(size.x * 0.18, size.y * 0.34, size.x * 0.64, size.y * 0.43)
	_draw_building(building, Color("343126"), true)
	for index in 6:
		var x := size.x * (0.09 + index * 0.16)
		draw_line(Vector2(x, size.y * 0.66), Vector2(x + 38, size.y * 0.66), Color("756c4c"), 2.0)
		for herb in 4:
			draw_line(Vector2(x + 8 + herb * 9, size.y * 0.66), Vector2(x + 5 + herb * 9, size.y * 0.61 - herb * 2), Color("7c8d63"), 2.0)


func _draw_valley(inner: bool) -> void:
	_draw_ground(Color("151b18"))
	var left_wall := PackedVector2Array([Vector2(0, 0), Vector2(size.x * 0.32, 0), Vector2(size.x * 0.42, size.y), Vector2(0, size.y)])
	var right_wall := PackedVector2Array([Vector2(size.x * 0.73, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(size.x * 0.60, size.y)])
	draw_colored_polygon(left_wall, Color("0b100e"))
	draw_colored_polygon(right_wall, Color("0c1110"))
	for index in 7:
		var crack_x := size.x * (0.08 + index * 0.13)
		draw_line(Vector2(crack_x, size.y * 0.22), Vector2(crack_x + 18, size.y * 0.56), Color("29332f"), 1.0)
	if inner:
		var herb := Vector2(size.x * 0.52, size.y * 0.77)
		for index in 5:
			var angle := -PI * 0.85 + index * PI * 0.18
			draw_line(herb, herb + Vector2(cos(angle), sin(angle)) * 38.0, Color("6ca69d"), 3.0)
		draw_circle(herb, 30.0, Color("6ca69d", 0.09))


func _draw_ground(color: Color) -> void:
	var ground := PackedVector2Array([Vector2(0, size.y * 0.68), Vector2(size.x, size.y * 0.61), Vector2(size.x, size.y), Vector2(0, size.y)])
	draw_colored_polygon(ground, color)


func _draw_building(rect: Rect2, color: Color, tall_roof: bool) -> void:
	draw_rect(rect, color, true)
	var roof_height := 34.0 if tall_roof else 24.0
	var roof := PackedVector2Array([rect.position + Vector2(-14, 0), rect.position + Vector2(rect.size.x * 0.5, -roof_height), rect.position + Vector2(rect.size.x + 14, 0)])
	draw_colored_polygon(roof, Color("171914"))
	draw_line(rect.position + Vector2(-20, 2), rect.position + Vector2(rect.size.x + 20, 2), Color("6a6047"), 2.0)
	for window_index in 2:
		var window_rect := Rect2(rect.position + Vector2(rect.size.x * (0.24 + window_index * 0.42), rect.size.y * 0.40), Vector2(18, 24))
		draw_rect(window_rect, Color("bd8d4d", 0.58), true)


func _draw_mist(key: String) -> void:
	var opacity := 0.05 if key not in ["valley_edge", "inner_valley"] else 0.11
	for index in 6:
		var x := fmod(drift + index * size.x * 0.21, size.x + 180.0) - 90.0
		var y := size.y * (0.58 + 0.055 * sin(index * 1.8))
		draw_circle(Vector2(x, y), 76.0 + index * 4.0, Color(MIST, opacity))


func _draw_vignette() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("050806", 0.18), false, 18.0)
