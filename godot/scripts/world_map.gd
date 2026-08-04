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
const PresentationRegistryScript = preload("res://scripts/presentation_registry.gd")

var map_data: Dictionary = {}
var locations: Array = []
var routes: Array = []
var actors: Array = []
var actor_motion_from: Dictionary = {}
var actor_motion_progress := 1.0
var actor_motion_tween: Tween
var hovered_id := ""
var hovered_route_key := ""
var selected_id := ""
var pulse := 0.0
var parallax_target := Vector2.ZERO
var parallax_offset := Vector2.ZERO
var motion_enabled := true
var travel_active := false
var travel_from_id := ""
var travel_to_id := ""
var travel_progress := 0.0
var travel_start_day := 0
var travel_end_day := 0
var emitted_travel_day := -1
var travel_tween: Tween
var presentation_registry = PresentationRegistryScript.new()
var display_font: Font
var minimum_font_size := 14


func _font_size(requested: int) -> int:
	return maxi(requested, minimum_font_size)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	custom_minimum_size = Vector2(640, 350)
	mouse_exited.connect(_reset_parallax)
	set_process(true)


func set_map(value: Dictionary, selection := "") -> void:
	var previous_locations := {}
	for actor in actors:
		previous_locations[str(actor.get("id", ""))] = str(actor.get("location_id", ""))
	map_data = value
	locations = value.get("locations", []) if value.get("locations", []) is Array else []
	routes = value.get("routes", []) if value.get("routes", []) is Array else []
	actors = value.get("actors", []) if value.get("actors", []) is Array else []
	actor_motion_from.clear()
	for actor in actors:
		var actor_id := str(actor.get("id", ""))
		var old_location := str(previous_locations.get(actor_id, ""))
		var new_location := str(actor.get("location_id", ""))
		if old_location != "" and old_location != new_location:
			actor_motion_from[actor_id] = old_location
	if actor_motion_tween and actor_motion_tween.is_valid():
		actor_motion_tween.kill()
	actor_motion_progress = 1.0
	if motion_enabled and not actor_motion_from.is_empty():
		actor_motion_progress = 0.0
		actor_motion_tween = create_tween()
		actor_motion_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		actor_motion_tween.tween_property(self, "actor_motion_progress", 1.0, 0.72)
	selected_id = selection
	if selected_id == "":
		for location in locations:
			if bool(location.get("current", false)):
				selected_id = str(location.get("id", ""))
				break
	queue_redraw()


func set_motion_enabled(value: bool) -> void:
	motion_enabled = value
	if not motion_enabled:
		parallax_target = Vector2.ZERO
		parallax_offset = Vector2.ZERO
	queue_redraw()


func has_formal_assets() -> bool:
	if presentation_registry.terrain_texture() == null:
		return false
	for location in locations:
		var scene_key := str(location.get("scene_key", ""))
		if scene_key != "" and not presentation_registry.has_location(scene_key):
			return false
	return true


func has_actor_plan_presentation() -> bool:
	return not actors.is_empty()


func visible_route_mark_count() -> int:
	return 1 if hovered_route_key != "" else 0


func visible_actor_token_count() -> int:
	if travel_active:
		return 0
	var current_id := _current_location_id()
	if selected_id != current_id:
		return 0
	return mini(_actors_at_location(current_id).size(), 2)


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
	var smoothing := minf(1.0, delta * 5.0)
	parallax_offset = parallax_offset.lerp(parallax_target, smoothing)
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
		var center := size * 0.5
		parallax_target = Vector2(
			clampf((event.position.x - center.x) / maxf(1.0, center.x), -1.0, 1.0),
			clampf((event.position.y - center.y) / maxf(1.0, center.y), -1.0, 1.0)
		) if motion_enabled else Vector2.ZERO
		var next_hover := _location_at(event.position)
		var next_route := _route_at(event.position) if next_hover == "" else {}
		var next_route_key := _route_key(next_route) if not next_route.is_empty() else ""
		if next_hover != hovered_id or next_route_key != hovered_route_key:
			hovered_id = next_hover
			hovered_route_key = next_route_key
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered_id != "" or hovered_route_key != "" else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var location_id := _location_at(event.position)
		if location_id == "":
			var route := _route_at(event.position)
			if not route.is_empty():
				location_id = _route_destination(route)
		if location_id != "":
			selected_id = location_id
			queue_redraw()
			location_selected.emit(location_id)


func _reset_parallax() -> void:
	parallax_target = Vector2.ZERO
	hovered_id = ""
	hovered_route_key = ""
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()


func _draw() -> void:
	var bounds := _map_bounds()
	var current_id := _current_location_id()
	_draw_terrain()
	for route in _display_routes():
		var from := _location_by_id(str(route.get("from_id", "")))
		var to := _location_by_id(str(route.get("to_id", "")))
		if from.is_empty() or to.is_empty():
			continue
		var from_position := _location_position(from, bounds)
		var to_position := _location_position(to, bounds)
		var status := str(route.get("status", "known"))
		var touches_current := _route_touches_location(route, current_id)
		var color := Color(LINE, 0.56)
		var width := 1.6
		if status == "available" and touches_current:
			color = Color(ACCENT, 0.92)
			width = 3.2
		elif status == "blocked":
			color = Color(LINE, 0.46)
		var curve := _route_curve(from_position, to_position)
		var hovered := _route_key(route) == hovered_route_key
		if hovered:
			color = Color(ACCENT, 0.96) if status != "blocked" else Color(DANGER, 0.84)
			width = maxf(width + 1.4, 3.0)
		var shadow_curve := PackedVector2Array()
		for point in curve:
			shadow_curve.append(point + Vector2(1, 4))
		draw_polyline(shadow_curve, Color("0204038f"), width + 3.0, true)
		draw_polyline(curve, Color(color, 0.16), width + 2.0, true)
		draw_polyline(curve, color, width, true)
		if width >= 3.0:
			draw_polyline(curve, Color(color.lightened(0.28), 0.56), 1.0, true)
		if status == "available" and touches_current:
			_draw_route_flow(curve, color)
		elif status == "blocked":
			_draw_blocked_route(curve, Color(DANGER, 0.76))
		if hovered:
			_draw_route_mark(curve, route, color)

	for location in locations:
		_draw_location(location, bounds)
	if travel_active:
		_draw_travel_marker(bounds)


func _draw_terrain() -> void:
	var target := Rect2(Vector2.ZERO, size)
	var terrain_texture: Texture2D = presentation_registry.terrain_texture()
	if terrain_texture == null:
		return
	var source := _cover_source_rect(terrain_texture.get_size(), size)
	var max_shift := Vector2(maxf(0.0, (terrain_texture.get_size().x - source.size.x) * 0.5), maxf(0.0, (terrain_texture.get_size().y - source.size.y) * 0.5))
	source.position += Vector2(parallax_offset.x * max_shift.x * 0.16, parallax_offset.y * max_shift.y * 0.10)
	draw_texture_rect_region(terrain_texture, target, source, Color(0.70, 0.66, 0.57, 0.88))
	draw_rect(target, Color("08100b94"), true)
	_draw_depth_plane()
	draw_rect(Rect2(Vector2(18, 18), size - Vector2(36, 36)), Color(ACCENT, 0.16), false, 1.0, true)
	draw_rect(Rect2(Vector2(27, 27), size - Vector2(54, 54)), Color("05080678"), false, 7.0, true)


func _draw_depth_plane() -> void:
	var horizon_y := size.y * 0.24
	draw_rect(Rect2(0, 0, size.x, horizon_y + 42), Color("0b130f30"), true)
	for index in 6:
		var t := float(index + 1) / 7.0
		var y := lerpf(horizon_y, size.y - 22.0, pow(t, 1.35))
		var inset := lerpf(size.x * 0.31, 24.0, t)
		draw_line(Vector2(inset, y), Vector2(size.x - inset, y), Color(ACCENT, 0.045 + t * 0.025), 1.0, true)
	for side in [-1.0, 1.0]:
		var near_x: float = 24.0 if side < 0.0 else size.x - 24.0
		var far_x: float = size.x * 0.5 + side * size.x * 0.19
		draw_line(Vector2(far_x, horizon_y), Vector2(near_x, size.y - 22.0), Color(ACCENT, 0.08), 1.0, true)
	var fog_height := maxf(34.0, size.y * 0.10)
	for band in 5:
		var alpha := 0.09 * (1.0 - float(band) / 5.0)
		draw_rect(Rect2(0, horizon_y + band * fog_height / 5.0, size.x, fog_height / 5.0 + 1.0), Color(INK, alpha), true)


func _draw_route_mark(curve: PackedVector2Array, route: Dictionary, color: Color) -> void:
	if curve.size() < 3:
		return
	var duration := int(route.get("duration", 1))
	var font := get_theme_default_font()
	var text := "%d日" % duration
	var middle := int(curve.size() / 2)
	var anchor := curve[middle]
	var tangent := (curve[mini(middle + 2, curve.size() - 1)] - curve[maxi(middle - 2, 0)]).normalized()
	var normal := Vector2(-tangent.y, tangent.x)
	var outward := anchor - Vector2(size.x * 0.5, size.y * 0.52)
	if normal.dot(outward) < 0.0:
		normal = -normal
	var label_center := anchor + normal * 27.0
	label_center.x = clampf(label_center.x, 28.0, size.x - 28.0)
	label_center.y = clampf(label_center.y, 34.0, size.y - 36.0)
	var plaque := Rect2(label_center + Vector2(-20, -11), Vector2(40, 22))
	draw_rect(Rect2(plaque.position + Vector2(3, 5), plaque.size), Color("020403a6"), true)
	draw_rect(plaque, Color("0c130ff4"), true)
	draw_rect(plaque, Color(color, 0.76), false, 1.0, true)
	draw_string(font, plaque.position + Vector2(5, 16), text, HORIZONTAL_ALIGNMENT_CENTER, 30, _font_size(12), color)


func _draw_route_flow(curve: PackedVector2Array, color: Color) -> void:
	var phase := fmod(pulse * 0.22, 1.0) if motion_enabled else 0.42
	for index in 4:
		var t := fmod(phase + float(index) * 0.25, 1.0)
		var position := _sample_curve(curve, t)
		draw_circle(position + Vector2(2, 5), 5.0, Color("02040388"))
		draw_circle(position, 3.0, color.lightened(0.28))


func _draw_blocked_route(curve: PackedVector2Array, color: Color) -> void:
	var center := _sample_curve(curve, 0.5)
	draw_arc(center, 6.0, -0.72, 0.72, 8, color, 2.0, true)


func _draw_location(location: Dictionary, bounds: Rect2) -> void:
	var position := _location_position(location, bounds)
	var location_id := str(location.get("id", ""))
	var current := bool(location.get("current", false))
	var contest := bool(location.get("contest", false))
	var unsafe := not bool(location.get("safe", false))
	var hovered := location_id == hovered_id
	var selected := location_id == selected_id
	var state_color := LINE if unsafe else SAFE
	var border_color := ACCENT if current or selected or hovered else Color(state_color, 0.82)
	var radius := 11.0 if selected or hovered else 8.0
	var beacon := position - Vector2(0, 15.0 if selected or hovered else 11.0)
	var pedestal := _ellipse_points(position + Vector2(4, 12), Vector2(radius + 16, 7))
	draw_colored_polygon(pedestal, Color("020403b5"))
	draw_polyline(pedestal, Color(border_color, 0.34), 1.0, true)
	draw_line(position + Vector2(0, 7), beacon, Color(border_color, 0.72), 2.0, true)
	draw_circle(beacon + Vector2(3, 7), radius + 6.0, Color("050706c8"))
	draw_circle(beacon, radius + 3.0, Color(border_color, 0.30))
	draw_circle(beacon, radius, Color("111812"))
	draw_circle(beacon, radius, border_color, false, 2.0, true)
	draw_circle(beacon, 3.0, border_color)
	if current and not travel_active:
		var halo_radius := radius + 10.0 + (sin(pulse * 2.0) * 1.5 if motion_enabled else 0.0)
		draw_circle(beacon, halo_radius, Color(ACCENT, 0.38), false, 1.5, true)
	if contest or unsafe:
		draw_arc(beacon, radius + 7.0, 0.10, 0.82, 9, Color(DANGER, 0.82), 2.0, true)

	var font := get_theme_default_font()
	var name := str(location.get("name", "未知地点"))
	if current and selected and not travel_active:
		_draw_location_plate(location, beacon, bounds)
		return
	var label_color := ACCENT if current or selected else INK
	var label_width := 124.0
	var label_position := position + Vector2(-label_width * 0.5, 40)
	draw_string(font, label_position + Vector2(1, 1), name, HORIZONTAL_ALIGNMENT_CENTER, label_width, _font_size(15), Color("030504"))
	draw_string(font, label_position, name, HORIZONTAL_ALIGNMENT_CENTER, label_width, _font_size(15), label_color)


func _draw_location_plate(location: Dictionary, beacon: Vector2, bounds: Rect2) -> void:
	var actor_count := _actors_at_location(str(location.get("id", ""))).size()
	var available_count := _available_route_count(str(location.get("id", "")))
	var plate_size := Vector2(204, 82)
	var left_space := beacon.x - 30.0
	var right_space := size.x - beacon.x - 30.0
	var place_left := left_space >= plate_size.x or left_space > right_space
	var plate_position := Vector2(beacon.x - plate_size.x - 28.0, beacon.y - 48.0) if place_left else Vector2(beacon.x + 28.0, beacon.y - 48.0)
	plate_position.x = clampf(plate_position.x, bounds.position.x - 72.0, size.x - plate_size.x - 22.0)
	plate_position.y = clampf(plate_position.y, 24.0, size.y - plate_size.y - 26.0)
	var plate_rect := Rect2(plate_position, plate_size)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0a100ded")
	style.border_color = Color(ACCENT, 0.46)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.shadow_color = Color("020403a8")
	style.shadow_size = 7
	style.shadow_offset = Vector2(3, 6)
	draw_style_box(style, plate_rect)
	var connector_start := Vector2(plate_rect.end.x, beacon.y) if place_left else Vector2(plate_rect.position.x, beacon.y)
	draw_line(connector_start, beacon + Vector2(-10 if place_left else 10, 0), Color(ACCENT, 0.62), 1.0, true)
	var font := get_theme_default_font()
	var title_font := display_font if display_font != null else font
	draw_string(font, plate_position + Vector2(14, 20), "当前据点", HORIZONTAL_ALIGNMENT_LEFT, 112, _font_size(12), Color(ACCENT, 0.86))
	draw_string(title_font, plate_position + Vector2(14, 49), str(location.get("name", "未知地点")), HORIZONTAL_ALIGNMENT_LEFT, 158, _font_size(21), ACCENT)
	var summary := "%d人在场 · 可通行路线 %d" % [actor_count, available_count]
	draw_string(font, plate_position + Vector2(14, 71), summary, HORIZONTAL_ALIGNMENT_LEFT, 166, _font_size(12), MUTED)
	_draw_plate_actor_chips(str(location.get("id", "")), plate_rect)


func _draw_plate_actor_chips(location_id: String, plate_rect: Rect2) -> void:
	var local_actors := _actors_at_location(location_id)
	var visible_count := mini(local_actors.size(), 2)
	for index in visible_count:
		var actor: Dictionary = local_actors[index]
		var actor_id := str(actor.get("id", ""))
		var position := plate_rect.position + Vector2(plate_rect.size.x - 17.0, 24.0 + index * 28.0)
		var color := presentation_registry.actor_token_color(actor_id, ACCENT)
		draw_circle(position + Vector2(1, 3), 11.0, Color("020403a6"))
		draw_circle(position, 10.0, Color("0b110edf"))
		draw_circle(position, 10.0, color, false, 1.5, true)
		var name := str(actor.get("name", "?"))
		var mark := name.substr(0, 1) if not name.is_empty() else "?"
		draw_string(get_theme_default_font(), position + Vector2(-9, 5), mark, HORIZONTAL_ALIGNMENT_CENTER, 18, _font_size(12), color.lightened(0.24))


func _draw_actor_plan(actor: Dictionary, bounds: Rect2, index: int) -> void:
	if travel_active:
		return
	var actor_id := str(actor.get("id", ""))
	var location := _location_by_id(str(actor.get("location_id", "")))
	if location.is_empty():
		return
	var destination := _location_position(location, bounds)
	var origin := destination
	if actor_motion_progress < 1.0 and actor_motion_from.has(actor_id):
		var old_location := _location_by_id(str(actor_motion_from[actor_id]))
		if not old_location.is_empty():
			origin = _location_position(old_location, bounds)
	var position := origin.lerp(destination, actor_motion_progress)
	position += _actor_token_offset(actor_id, index)
	var color := presentation_registry.actor_token_color(actor_id, ACCENT)
	var shadow := PackedVector2Array([
		position + Vector2(-10, 6), position + Vector2(0, 12),
		position + Vector2(10, 6), position + Vector2(0, 1),
	])
	draw_colored_polygon(shadow, Color("020403b8"))
	draw_circle(position, 11.0, Color("09100ceb"))
	draw_circle(position, 11.0, color, false, 2.0, true)
	if bool(actor.get("changed_by_player", false)):
		var halo := 15.0 + (sin(pulse * 2.2 + index) * 1.5 if motion_enabled else 0.0)
		draw_circle(position, halo, Color(ACCENT, 0.62), false, 1.5, true)
	var name := str(actor.get("name", "?"))
	var mark := name.substr(0, 1) if not name.is_empty() else "?"
	draw_string(get_theme_default_font(), position + Vector2(-7, 5), mark, HORIZONTAL_ALIGNMENT_CENTER, 14, _font_size(12), color.lightened(0.28))
	if str(actor.get("destination_id", "")) != "" and str(actor.get("destination_id", "")) != str(actor.get("location_id", "")):
		draw_string(get_theme_default_font(), position + Vector2(11, -8), "↗", HORIZONTAL_ALIGNMENT_LEFT, 18, _font_size(13), ACCENT)


func _actor_token_offset(actor_id: String, fallback_index: int) -> Vector2:
	var fallback := Vector2((fallback_index % 3 - 1) * 27, -42 - (fallback_index / 3) * 22)
	return presentation_registry.actor_token_offset(actor_id, fallback)


func _route_curve(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	var delta := to_position - from_position
	var normal := Vector2(-delta.y, delta.x).normalized()
	var direction := 1.0 if from_position.x <= to_position.x else -1.0
	var curvature := minf(42.0, delta.length() * 0.14)
	if absf(delta.x) < 72.0 and absf(delta.y) > 140.0:
		curvature = minf(72.0, delta.length() * 0.24)
	var control := from_position.lerp(to_position, 0.5) + normal * curvature * direction
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


func _current_location_id() -> String:
	for location in locations:
		if bool(location.get("current", false)):
			return str(location.get("id", ""))
	return ""


func _route_touches_location(route: Dictionary, location_id: String) -> bool:
	if location_id == "":
		return false
	return str(route.get("from_id", "")) == location_id or str(route.get("to_id", "")) == location_id


func _available_route_count(location_id: String) -> int:
	var count := 0
	for route in _display_routes():
		if str(route.get("status", "known")) == "available" and _route_touches_location(route, location_id):
			count += 1
	return count


func _actors_at_location(location_id: String) -> Array:
	var result: Array = []
	for actor in actors:
		if str(actor.get("location_id", "")) == location_id:
			result.append(actor)
	return result


func _map_bounds() -> Rect2:
	return Rect2(Vector2(100, 72), Vector2(maxf(1.0, size.x - 200), maxf(1.0, size.y - 170)))


func _location_position(location: Dictionary, bounds: Rect2) -> Vector2:
	var raw := bounds.position + Vector2(float(location.get("x", 0.5)) * bounds.size.x, float(location.get("y", 0.5)) * bounds.size.y)
	var depth := clampf(float(location.get("y", 0.5)), 0.0, 1.0)
	var center_x := bounds.get_center().x
	var perspective_scale := lerpf(0.78, 1.06, depth)
	raw.x = center_x + (raw.x - center_x) * perspective_scale
	raw.y = bounds.position.y + pow(depth, 1.12) * bounds.size.y
	var drift_strength := lerpf(12.0, 3.0, depth)
	return raw + Vector2(parallax_offset.x * drift_strength, parallax_offset.y * drift_strength * 0.42)


func _location_at(position: Vector2) -> String:
	var bounds := _map_bounds()
	for location in locations:
		var tile := Rect2(_location_position(location, bounds) - Vector2(64, 38), Vector2(128, 88))
		if tile.has_point(position):
			return str(location.get("id", ""))
	return ""


func _route_at(position: Vector2) -> Dictionary:
	var bounds := _map_bounds()
	for route in _display_routes():
		var from := _location_by_id(str(route.get("from_id", "")))
		var to := _location_by_id(str(route.get("to_id", "")))
		if from.is_empty() or to.is_empty():
			continue
		var curve := _route_curve(_location_position(from, bounds), _location_position(to, bounds))
		for index in curve.size() - 1:
			var closest := Geometry2D.get_closest_point_to_segment(position, curve[index], curve[index + 1])
			if closest.distance_to(position) <= 13.0:
				return route
	return {}


func _route_key(route: Dictionary) -> String:
	if route.is_empty():
		return ""
	return "%s:%s" % [route.get("from_id", ""), route.get("to_id", "")]


func _route_destination(route: Dictionary) -> String:
	var current_id := ""
	for location in locations:
		if bool(location.get("current", false)):
			current_id = str(location.get("id", ""))
			break
	var from_id := str(route.get("from_id", ""))
	var to_id := str(route.get("to_id", ""))
	return to_id if from_id == current_id else from_id if to_id == current_id else to_id


func _sample_curve(curve: PackedVector2Array, t: float) -> Vector2:
	if curve.is_empty():
		return Vector2.ZERO
	var scaled := clampf(t, 0.0, 1.0) * float(curve.size() - 1)
	var index := mini(int(floor(scaled)), curve.size() - 1)
	var next_index := mini(index + 1, curve.size() - 1)
	return curve[index].lerp(curve[next_index], scaled - float(index))


func _ellipse_points(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in 24:
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	points.append(points[0])
	return points


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
