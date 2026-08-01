extends Control

signal location_selected(location_id: String)

const INK := Color("e9e2d3")
const MUTED := Color("879188")
const ACCENT := Color("d6ae62")
const SAFE := Color("769279")
const DANGER := Color("a85849")
const LINE := Color("3a463e")

var map_data: Dictionary = {}
var locations: Array = []
var routes: Array = []
var hovered_id := ""
var selected_id := ""
var pulse := 0.0


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


func select_location(location_id: String) -> void:
	selected_id = location_id
	queue_redraw()


func _process(delta: float) -> void:
	pulse = fmod(pulse + delta, TAU)
	if not locations.is_empty():
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
	_draw_terrain(bounds)
	var edge_routes := _display_routes()
	for route in edge_routes:
		var from := _location_by_id(str(route.get("from_id", "")))
		var to := _location_by_id(str(route.get("to_id", "")))
		if from.is_empty() or to.is_empty():
			continue
		var from_position := _location_position(from, bounds)
		var to_position := _location_position(to, bounds)
		var status := str(route.get("status", "known"))
		var color := LINE
		var width := 2.0
		if status == "available":
			color = Color(ACCENT, 0.88)
			width = 3.0
		elif status == "blocked":
			color = Color(DANGER, 0.72)
		draw_line(from_position, to_position, color, width, true)
		_draw_route_mark(from_position.lerp(to_position, 0.5), route, color)

	for location in locations:
		_draw_location(location, bounds)


func _draw_terrain(bounds: Rect2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0d1410"), true)
	for index in 7:
		var center := Vector2(bounds.position.x + bounds.size.x * (0.08 + index * 0.15), bounds.position.y + bounds.size.y * (0.25 + 0.12 * sin(index * 1.7)))
		draw_circle(center, 120.0 + index * 17.0, Color("111a14"), false, 1.0, true)
	var ridge := PackedVector2Array([
		Vector2(bounds.position.x, bounds.position.y + bounds.size.y * 0.33),
		Vector2(bounds.position.x + bounds.size.x * 0.18, bounds.position.y + bounds.size.y * 0.20),
		Vector2(bounds.position.x + bounds.size.x * 0.36, bounds.position.y + bounds.size.y * 0.42),
		Vector2(bounds.position.x + bounds.size.x * 0.58, bounds.position.y + bounds.size.y * 0.23),
		Vector2(bounds.position.x + bounds.size.x * 0.78, bounds.position.y + bounds.size.y * 0.44),
		Vector2(bounds.end.x, bounds.position.y + bounds.size.y * 0.18),
	])
	draw_polyline(ridge, Color("26332a"), 1.2, true)
	for index in 18:
		var dot := Vector2(bounds.position.x + fmod(float(index * 83), bounds.size.x), bounds.position.y + fmod(float(index * 47), bounds.size.y))
		draw_circle(dot, 1.2, Color(INK, 0.08))


func _draw_route_mark(position: Vector2, route: Dictionary, color: Color) -> void:
	var duration := int(route.get("duration", 1))
	var font := get_theme_default_font()
	var text := "%d日" % duration
	draw_circle(position, 15.0, Color("111713"))
	draw_circle(position, 15.0, Color(color, 0.7), false, 1.0, true)
	draw_string(font, position + Vector2(-12, 5), text, HORIZONTAL_ALIGNMENT_CENTER, 24, 12, color)


func _draw_location(location: Dictionary, bounds: Rect2) -> void:
	var position := _location_position(location, bounds)
	var location_id := str(location.get("id", ""))
	var current := bool(location.get("current", false))
	var contest := bool(location.get("contest", false))
	var hovered := location_id == hovered_id
	var selected := location_id == selected_id
	var base_color := SAFE if bool(location.get("safe", false)) else DANGER
	if current:
		var radius := 25.0 + sin(pulse * 2.0) * 2.0
		draw_circle(position, radius, Color(ACCENT, 0.12))
		draw_circle(position, radius, Color(ACCENT, 0.65), false, 1.5, true)
	if selected or hovered:
		draw_circle(position, 21.0, Color(ACCENT, 0.16))
		draw_circle(position, 21.0, ACCENT, false, 1.5, true)
	if contest:
		var diamond := PackedVector2Array([position + Vector2(0, -13), position + Vector2(13, 0), position + Vector2(0, 13), position + Vector2(-13, 0)])
		draw_colored_polygon(diamond, base_color)
	else:
		draw_circle(position, 11.0, base_color)
	draw_circle(position, 4.0, Color("121713"))
	var font := get_theme_default_font()
	var name := str(location.get("name", "未知地点"))
	var label_color := ACCENT if current or selected else INK
	draw_string(font, position + Vector2(-54, 38), name, HORIZONTAL_ALIGNMENT_CENTER, 108, 14, label_color)
	if current:
		draw_string(font, position + Vector2(-42, -29), "你在这里", HORIZONTAL_ALIGNMENT_CENTER, 84, 12, ACCENT)
	var actor_count := int(location.get("actor_count", 0))
	if actor_count > 0:
		draw_string(font, position + Vector2(-38, 54), "%d 人可见" % actor_count, HORIZONTAL_ALIGNMENT_CENTER, 76, 11, MUTED)


func _display_routes() -> Array:
	var by_edge := {}
	for route in routes:
		var first := str(route.get("from_id", ""))
		var second := str(route.get("to_id", ""))
		var key := first + ":" + second if first < second else second + ":" + first
		if not by_edge.has(key) or str(route.get("status", "known")) != "known":
			by_edge[key] = route
	return by_edge.values()


func _map_bounds() -> Rect2:
	return Rect2(Vector2(52, 38), Vector2(maxf(1.0, size.x - 104), maxf(1.0, size.y - 90)))


func _location_position(location: Dictionary, bounds: Rect2) -> Vector2:
	return bounds.position + Vector2(float(location.get("x", 0.5)) * bounds.size.x, float(location.get("y", 0.5)) * bounds.size.y)


func _location_at(position: Vector2) -> String:
	var bounds := _map_bounds()
	for location in locations:
		if position.distance_to(_location_position(location, bounds)) <= 28.0:
			return str(location.get("id", ""))
	return ""


func _location_by_id(location_id: String) -> Dictionary:
	for location in locations:
		if str(location.get("id", "")) == location_id:
			return location
	return {}
