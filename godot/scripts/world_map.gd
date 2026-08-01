extends Control

signal location_selected(location_id: String)
signal travel_day_changed(day: int)
signal travel_finished

const INK := Color("e9e2d3")
const MUTED := Color("9aa59b")
const ACCENT := Color("d6ae62")
const SAFE := Color("769279")
const DANGER := Color("a85849")
const LINE := Color("465249")
const TERRAIN_TEXTURE = preload("res://assets/locations/valley_edge/background.png")
const LOCATION_TEXTURES := {
	"market": preload("res://assets/locations/market/background.png"),
	"qinglan": preload("res://assets/locations/qinglan/background.png"),
	"apothecary": preload("res://assets/locations/apothecary/background.png"),
	"valley_edge": preload("res://assets/locations/valley_edge/background.png"),
	"inner_valley": preload("res://assets/locations/inner_valley/background.png"),
}

var map_data: Dictionary = {}
var locations: Array = []
var routes: Array = []
var hovered_id := ""
var selected_id := ""
var pulse := 0.0
var motion_enabled := true
var travel_active := false
var travel_from_id := ""
var travel_to_id := ""
var travel_progress := 0.0
var travel_start_day := 0
var travel_end_day := 0
var emitted_travel_day := -1
var travel_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	custom_minimum_size = Vector2(640, 350)
	set_process(true)


func set_map(value: Dictionary, selection := "") -> void:
	map_data = value
	locations = value.get("locations", []) if value.get("locations", []) is Array else []
	routes = value.get("routes", []) if value.get("routes", []) is Array else []
	selected_id = selection
	if selected_id == "":
		for location in locations:
			if bool(location.get("current", false)):
				selected_id = str(location.get("id", ""))
				break
	queue_redraw()


func set_motion_enabled(value: bool) -> void:
	motion_enabled = value
	queue_redraw()


func has_formal_assets() -> bool:
	return TERRAIN_TEXTURE != null and LOCATION_TEXTURES.size() == 5


func select_location(location_id: String) -> void:
	selected_id = location_id
	queue_redraw()


func animate_travel(from_id: String, to_id: String, start_day: int, end_day: int) -> void:
	if travel_tween and travel_tween.is_valid():
		travel_tween.kill()
	if _location_by_id(from_id).is_empty() or _location_by_id(to_id).is_empty():
		travel_finished.emit()
		return
	travel_active = true
	travel_from_id = from_id
	travel_to_id = to_id
	travel_start_day = start_day
	travel_end_day = maxi(start_day + 1, end_day)
	travel_progress = 0.0
	emitted_travel_day = start_day
	travel_day_changed.emit(start_day)
	if not motion_enabled:
		travel_progress = 1.0
		_finish_travel()
		return
	var duration := minf(1.65, 0.82 + 0.20 * (travel_end_day - travel_start_day))
	travel_tween = create_tween()
	travel_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	travel_tween.tween_property(self, "travel_progress", 1.0, duration)
	travel_tween.finished.connect(_finish_travel)


func _process(delta: float) -> void:
	if motion_enabled:
		pulse = fmod(pulse + delta, TAU)
	if travel_active:
		var day := mini(travel_end_day, travel_start_day + int(floor(travel_progress * (travel_end_day - travel_start_day + 0.999))))
		if day != emitted_travel_day:
			emitted_travel_day = day
			travel_day_changed.emit(day)
	if travel_active or motion_enabled and not locations.is_empty():
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var next_hover := _location_at(event.position)
		if next_hover != hovered_id:
			hovered_id = next_hover
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered_id != "" else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var location_id := _location_at(event.position)
		if location_id != "":
			selected_id = location_id
			queue_redraw()
			location_selected.emit(location_id)


func _draw() -> void:
	var bounds := _map_bounds()
	_draw_terrain()
	for route in _display_routes():
		var from := _location_by_id(str(route.get("from_id", "")))
		var to := _location_by_id(str(route.get("to_id", "")))
		if from.is_empty() or to.is_empty():
			continue
		var from_position := _location_position(from, bounds)
		var to_position := _location_position(to, bounds)
		var status := str(route.get("status", "known"))
		var color := LINE
		var width := 1.5
		if status == "available":
			color = Color(ACCENT, 0.92)
			width = 2.5
		elif status == "blocked":
			color = Color(DANGER, 0.78)
		var curve := _route_curve(from_position, to_position)
		draw_polyline(curve, Color("050706b8"), width + 4.0, true)
		draw_polyline(curve, color, width, true)
		_draw_route_mark(curve[int(curve.size() / 2)], route, color)

	for location in locations:
		_draw_location(location, bounds)
	if travel_active:
		_draw_travel_marker(bounds)


func _draw_terrain() -> void:
	var target := Rect2(Vector2.ZERO, size)
	var source := _cover_source_rect(TERRAIN_TEXTURE.get_size(), size)
	draw_texture_rect_region(TERRAIN_TEXTURE, target, source, Color(0.72, 0.68, 0.58, 0.82))
	draw_rect(target, Color("08100b94"), true)
	draw_rect(Rect2(Vector2(18, 18), size - Vector2(36, 36)), Color(ACCENT, 0.16), false, 1.0, true)
	draw_rect(Rect2(Vector2(27, 27), size - Vector2(54, 54)), Color("05080678"), false, 7.0, true)


func _draw_route_mark(position: Vector2, route: Dictionary, color: Color) -> void:
	var duration := int(route.get("duration", 1))
	var font := get_theme_default_font()
	var text := "%d日" % duration
	draw_circle(position, 3.0, color)
	draw_string(font, position + Vector2(-15, -8), text, HORIZONTAL_ALIGNMENT_CENTER, 30, 12, Color("050706"))
	draw_string(font, position + Vector2(-16, -9), text, HORIZONTAL_ALIGNMENT_CENTER, 30, 12, color)


func _draw_location(location: Dictionary, bounds: Rect2) -> void:
	var position := _location_position(location, bounds)
	var location_id := str(location.get("id", ""))
	var current := bool(location.get("current", false))
	var contest := bool(location.get("contest", false))
	var hovered := location_id == hovered_id
	var selected := location_id == selected_id
	var state_color := SAFE if bool(location.get("safe", false)) else DANGER
	var border_color := ACCENT if current or selected or hovered else Color(state_color, 0.82)
	var radius := 11.0 if selected or hovered else 8.0
	draw_circle(position, radius + 6.0, Color("050706c8"))
	draw_circle(position, radius + 2.0, Color(border_color, 0.34))
	draw_circle(position, radius, Color("111812"))
	draw_circle(position, radius, border_color, false, 2.0, true)
	draw_circle(position, 3.0, border_color)
	if current and not travel_active:
		var halo_radius := radius + 13.0 + (sin(pulse * 2.0) * 2.0 if motion_enabled else 0.0)
		draw_circle(position, halo_radius, Color(ACCENT, 0.44), false, 1.5, true)
	if contest:
		draw_arc(position, radius + 18.0, -PI * 0.85, PI * 0.75, 28, Color(DANGER, 0.72), 2.0, true)

	var font := get_theme_default_font()
	var name := str(location.get("name", "未知地点"))
	var label_color := ACCENT if current or selected else INK
	var label_width := 132.0
	var label_position := position + Vector2(-label_width * 0.5, 34)
	draw_string(font, label_position + Vector2(1, 1), name, HORIZONTAL_ALIGNMENT_CENTER, label_width, 15, Color("030504"))
	draw_string(font, label_position, name, HORIZONTAL_ALIGNMENT_CENTER, label_width, 15, label_color)
	if current and not travel_active:
		draw_string(font, position + Vector2(-26, -25), "此刻", HORIZONTAL_ALIGNMENT_CENTER, 52, 12, ACCENT)
	elif contest:
		draw_string(font, position + Vector2(-30, -25), "争夺地", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color("d87761"))
	var actor_count := int(location.get("actor_count", 0))
	if actor_count > 0 and not travel_active:
		draw_string(font, position + Vector2(-36, 51), "%d 人在场" % actor_count, HORIZONTAL_ALIGNMENT_CENTER, 72, 11, MUTED)


func _route_curve(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	var delta := to_position - from_position
	var normal := Vector2(-delta.y, delta.x).normalized()
	var direction := 1.0 if from_position.x <= to_position.x else -1.0
	var control := from_position.lerp(to_position, 0.5) + normal * minf(34.0, delta.length() * 0.10) * direction
	var points := PackedVector2Array()
	for index in 17:
		var t := float(index) / 16.0
		points.append(from_position * pow(1.0 - t, 2.0) + control * 2.0 * (1.0 - t) * t + to_position * t * t)
	return points


func _draw_travel_marker(bounds: Rect2) -> void:
	var from := _location_by_id(travel_from_id)
	var to := _location_by_id(travel_to_id)
	if from.is_empty() or to.is_empty():
		return
	var position := _location_position(from, bounds).lerp(_location_position(to, bounds), travel_progress)
	draw_circle(position, 18.0, Color("080b09d9"))
	draw_circle(position, 12.0, ACCENT)
	draw_circle(position, 4.0, Color("19140a"))


func _finish_travel() -> void:
	travel_active = false
	travel_progress = 1.0
	travel_day_changed.emit(travel_end_day)
	queue_redraw()
	travel_finished.emit()


func _display_routes() -> Array:
	var by_edge := {}
	for route in routes:
		var from_id := str(route.get("from_id", ""))
		var to_id := str(route.get("to_id", ""))
		var key := from_id + ":" + to_id if from_id < to_id else to_id + ":" + from_id
		if not by_edge.has(key) or str(route.get("status", "known")) != "known":
			by_edge[key] = route
	return by_edge.values()


func _map_bounds() -> Rect2:
	return Rect2(Vector2(100, 72), Vector2(maxf(1.0, size.x - 200), maxf(1.0, size.y - 170)))


func _location_position(location: Dictionary, bounds: Rect2) -> Vector2:
	return bounds.position + Vector2(float(location.get("x", 0.5)) * bounds.size.x, float(location.get("y", 0.5)) * bounds.size.y)


func _location_at(position: Vector2) -> String:
	var bounds := _map_bounds()
	for location in locations:
		var tile := Rect2(_location_position(location, bounds) - Vector2(64, 38), Vector2(128, 88))
		if tile.has_point(position):
			return str(location.get("id", ""))
	return ""


func _location_by_id(location_id: String) -> Dictionary:
	for location in locations:
		if str(location.get("id", "")) == location_id:
			return location
	return {}


func _cover_source_rect(texture_size: Vector2, target_size: Vector2) -> Rect2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or target_size.x <= 0.0 or target_size.y <= 0.0:
		return Rect2(Vector2.ZERO, texture_size)
	var source_aspect := texture_size.x / texture_size.y
	var target_aspect := target_size.x / target_size.y
	if source_aspect > target_aspect:
		var source_width := texture_size.y * target_aspect
		return Rect2(Vector2((texture_size.x - source_width) * 0.5, 0), Vector2(source_width, texture_size.y))
	var source_height := texture_size.x / target_aspect
	return Rect2(Vector2(0, (texture_size.y - source_height) * 0.5), Vector2(texture_size.x, source_height))
