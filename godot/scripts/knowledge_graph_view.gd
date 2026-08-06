class_name KnowledgeGraphView
extends Control

signal node_selected(node: Dictionary)

const COLORS := {
	"ink": Color("e9e2d3"),
	"muted": Color("9aa59b"),
	"accent": Color("d6ae62"),
	"success": Color("789b78"),
	"danger": Color("b45d4f"),
	"line": Color("465249"),
	"surface": Color("101612"),
	"surface_alt": Color("172019"),
}

var graph: Dictionary = {"nodes": [], "edges": []}
var nodes: Array = []
var edges: Array = []
var visible_nodes: Array = []
var node_rects: Dictionary = {}
var selected_id := ""
var hovered_id := ""
var active_filter := "all"
var display_font: Font
var body_font: Font
var minimum_font_size := 14
var layout_in_progress := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	custom_minimum_size = Vector2(0, 460)


func set_graph(value: Dictionary) -> void:
	graph = value
	nodes = value.get("nodes", []) if value.get("nodes", []) is Array else []
	edges = value.get("edges", []) if value.get("edges", []) is Array else []
	if not _node_exists(selected_id):
		selected_id = _preferred_node_id()
	call_deferred("_layout_nodes")
	_emit_selected()


func set_filter(kind: String) -> void:
	active_filter = kind
	if active_filter != "all" and _node_kind(selected_id) != active_filter:
		selected_id = ""
	_layout_nodes()
	if selected_id == "" and not visible_nodes.is_empty():
		selected_id = str(visible_nodes[0].get("id", ""))
	_emit_selected()


func selected_node() -> Dictionary:
	return _node_by_id(selected_id)


func visible_node_count() -> int:
	return visible_nodes.size()


func focus_node(node_id: String) -> bool:
	if not _node_exists(node_id):
		return false
	var kind := _node_kind(node_id)
	if active_filter != "all" and active_filter != kind:
		active_filter = "all"
		_layout_nodes()
	_select_node(node_id)
	return true


func selected_node_rect() -> Rect2:
	return node_rects.get(selected_id, Rect2())


func _layout_nodes() -> void:
	if layout_in_progress:
		return
	layout_in_progress = true
	visible_nodes.clear()
	node_rects.clear()
	for node in nodes:
		if active_filter == "all" or str(node.get("kind", "")) == active_filter:
			visible_nodes.append(node)
	var by_kind := {"actor": [], "claim": [], "event": [], "location": []}
	for node in visible_nodes:
		var kind := str(node.get("kind", ""))
		if not by_kind.has(kind):
			by_kind[kind] = []
		by_kind[kind].append(node)
	var columns: Array = []
	for kind in ["actor", "claim", "event", "location"]:
		if not by_kind[kind].is_empty():
			columns.append(kind)
	_order_columns_by_relationships(by_kind, columns)
	var column_count: int = maxi(1, columns.size())
	var horizontal_padding := 28.0
	var column_width := (size.x - horizontal_padding * 2.0) / column_count
	var node_width := clampf(column_width - 34.0, 152.0, 236.0)
	var max_rows := 1
	for kind in columns:
		max_rows = maxi(max_rows, by_kind[kind].size())
	var required_height := maxf(460.0, 82.0 + float(max_rows) * 82.0)
	if not is_equal_approx(custom_minimum_size.y, required_height):
		custom_minimum_size = Vector2(custom_minimum_size.x, required_height)
	var content_height := maxf(size.y, custom_minimum_size.y)
	for column_index in columns.size():
		var kind: String = columns[column_index]
		var column_nodes: Array = by_kind[kind]
		var x := horizontal_padding + float(column_index) * column_width + (column_width - node_width) * 0.5
		var available_height := content_height - 116.0
		var step := clampf(available_height / maxf(1.0, float(column_nodes.size())), 82.0, 148.0)
		var group_height := step * float(column_nodes.size())
		var group_top := 62.0 + maxf(0.0, (available_height - group_height) * 0.5)
		for row_index in column_nodes.size():
			var y := group_top + float(row_index) * step + maxf(0.0, (step - 62.0) * 0.5)
			var node_id := str(column_nodes[row_index].get("id", ""))
			node_rects[node_id] = Rect2(Vector2(x, y), Vector2(node_width, 62.0))
	layout_in_progress = false
	queue_redraw()


func _draw() -> void:
	var font := body_font if body_font else get_theme_default_font()
	var title_font := display_font if display_font else font
	var label_counts := _focused_edge_label_counts()
	_draw_edges(font, false, label_counts)
	_draw_edges(font, true, label_counts)
	_draw_nodes(title_font, font)


func _draw_edges(font: Font, focused_pass: bool, label_counts: Dictionary) -> void:
	for edge in edges:
		var source_id := str(edge.get("source_id", ""))
		var target_id := str(edge.get("target_id", ""))
		if not node_rects.has(source_id) or not node_rects.has(target_id):
			continue
		var focused := selected_id in [source_id, target_id]
		if focused != focused_pass:
			continue
		var source_rect: Rect2 = node_rects[source_id]
		var target_rect: Rect2 = node_rects[target_id]
		var path := _edge_path(source_rect, target_rect)
		var edge_color := _edge_color(str(edge.get("status", "normal")))
		var hovered := hovered_id in [source_id, target_id]
		edge_color.a = 0.88 if focused else (0.42 if hovered else 0.11)
		draw_polyline(path, edge_color, 2.2 if focused else (1.5 if hovered else 1.0), true)
		if focused:
			var label := str(edge.get("label", ""))
			if label != "" and int(label_counts.get(label, 0)) == 1:
				_draw_edge_label(font, path, label, edge_color)


func _draw_nodes(title_font: Font, font: Font) -> void:
	for node in visible_nodes:
		var node_id := str(node.get("id", ""))
		if not node_rects.has(node_id):
			continue
		var rect: Rect2 = node_rects[node_id]
		var selected := node_id == selected_id
		var hovered := node_id == hovered_id
		var related := selected or _is_related_to_selection(node_id)
		var kind := str(node.get("kind", ""))
		var accent := _kind_color(kind)
		var fill := Color(COLORS.surface_alt, 0.98 if selected or hovered else (0.86 if related else 0.62))
		draw_style_box(_node_style(fill, accent, selected or hovered), rect)
		draw_rect(Rect2(rect.position, Vector2(5, rect.size.y)), accent, true)
		var label := _ellipsize(str(node.get("label", "未命名")), maxi(9, int((rect.size.x - 28.0) / 15.0)))
		draw_string(title_font, rect.position + Vector2(16, 24), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24, _font_size(16), COLORS.ink)
		var state := _ellipsize(str(node.get("state", _kind_label(kind))), maxi(9, int((rect.size.x - 28.0) / 12.0)))
		draw_string(font, rect.position + Vector2(16, 48), state, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24, _font_size(13), accent.lightened(0.12))


func _order_columns_by_relationships(by_kind: Dictionary, columns: Array) -> void:
	var ranks := {}
	for kind in columns:
		_record_column_ranks(by_kind[kind], ranks)
	for _iteration in 3:
		for column_index in range(1, columns.size()):
			var kind: String = columns[column_index]
			by_kind[kind] = _ordered_by_neighbor_rank(by_kind[kind], ranks)
			_record_column_ranks(by_kind[kind], ranks)
		for column_index in range(columns.size() - 2, -1, -1):
			var kind: String = columns[column_index]
			by_kind[kind] = _ordered_by_neighbor_rank(by_kind[kind], ranks)
			_record_column_ranks(by_kind[kind], ranks)


func _record_column_ranks(column_nodes: Array, ranks: Dictionary) -> void:
	for index in column_nodes.size():
		ranks[str(column_nodes[index].get("id", ""))] = float(index)


func _ordered_by_neighbor_rank(column_nodes: Array, ranks: Dictionary) -> Array:
	var pending := column_nodes.duplicate()
	var ordered: Array = []
	while not pending.is_empty():
		var best_index := 0
		var best_score := _neighbor_rank(str(pending[0].get("id", "")), ranks)
		for index in range(1, pending.size()):
			var score := _neighbor_rank(str(pending[index].get("id", "")), ranks)
			if score < best_score - 0.001:
				best_score = score
				best_index = index
		ordered.append(pending.pop_at(best_index))
	return ordered


func _neighbor_rank(node_id: String, ranks: Dictionary) -> float:
	var total := 0.0
	var count := 0
	for edge in edges:
		var source_id := str(edge.get("source_id", ""))
		var target_id := str(edge.get("target_id", ""))
		var neighbor_id := ""
		if source_id == node_id:
			neighbor_id = target_id
		elif target_id == node_id:
			neighbor_id = source_id
		if neighbor_id != "" and ranks.has(neighbor_id):
			total += float(ranks[neighbor_id])
			count += 1
	if count == 0:
		return float(ranks.get(node_id, 10000.0))
	return total / float(count)


func _edge_path(source_rect: Rect2, target_rect: Rect2) -> PackedVector2Array:
	var source_center := source_rect.get_center()
	var target_center := target_rect.get_center()
	var start: Vector2
	var finish: Vector2
	var control_a: Vector2
	var control_b: Vector2
	if absf(target_center.x - source_center.x) > 24.0:
		var direction := 1.0 if target_center.x > source_center.x else -1.0
		start = Vector2(source_rect.end.x + 6.0, source_center.y) if direction > 0.0 else Vector2(source_rect.position.x - 6.0, source_center.y)
		finish = Vector2(target_rect.position.x - 6.0, target_center.y) if direction > 0.0 else Vector2(target_rect.end.x + 6.0, target_center.y)
		var handle := clampf(absf(finish.x - start.x) * 0.42, 8.0, 128.0)
		control_a = start + Vector2(handle * direction, 0.0)
		control_b = finish - Vector2(handle * direction, 0.0)
	else:
		var direction := 1.0 if target_center.y > source_center.y else -1.0
		start = Vector2(source_center.x, source_rect.end.y + 6.0) if direction > 0.0 else Vector2(source_center.x, source_rect.position.y - 6.0)
		finish = Vector2(target_center.x, target_rect.position.y - 6.0) if direction > 0.0 else Vector2(target_center.x, target_rect.end.y + 6.0)
		control_a = start + Vector2(0.0, (finish.y - start.y) * 0.34)
		control_b = finish - Vector2(0.0, (finish.y - start.y) * 0.34)
	var points := PackedVector2Array()
	for index in 25:
		var t := float(index) / 24.0
		points.append(start.bezier_interpolate(control_a, control_b, finish, t))
	return points


func _focused_edge_label_counts() -> Dictionary:
	var counts := {}
	for edge in edges:
		var source_id := str(edge.get("source_id", ""))
		var target_id := str(edge.get("target_id", ""))
		var label := str(edge.get("label", ""))
		if label != "" and selected_id in [source_id, target_id] and node_rects.has(source_id) and node_rects.has(target_id):
			counts[label] = int(counts.get(label, 0)) + 1
	return counts


func _draw_edge_label(font: Font, path: PackedVector2Array, label: String, color: Color) -> void:
	var anchor: Vector2 = path[mini(path.size() - 1, int(float(path.size()) * 0.68))]
	var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size(13)).x + 16.0
	var rect := Rect2(anchor - Vector2(label_width * 0.5, 12.0), Vector2(label_width, 24.0))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLORS.surface, 0.94)
	style.border_color = Color(color, 0.32)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	draw_style_box(style, rect)
	draw_string(font, rect.position + Vector2(8.0, 17.0), label, HORIZONTAL_ALIGNMENT_LEFT, label_width - 16.0, _font_size(13), color.lightened(0.18))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var next_hover := _node_at(event.position)
		if next_hover != hovered_id:
			hovered_id = next_hover
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered_id != "" else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var node_id := _node_at(event.position)
		if node_id != "":
			_select_node(node_id)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_UP]:
			_move_selection(-1)
			accept_event()
		elif event.keycode in [KEY_RIGHT, KEY_DOWN]:
			_move_selection(1)
			accept_event()


func _move_selection(direction: int) -> void:
	if visible_nodes.is_empty():
		return
	var index := 0
	for candidate_index in visible_nodes.size():
		if str(visible_nodes[candidate_index].get("id", "")) == selected_id:
			index = candidate_index
			break
	index = posmod(index + direction, visible_nodes.size())
	_select_node(str(visible_nodes[index].get("id", "")))


func _select_node(node_id: String) -> void:
	selected_id = node_id
	queue_redraw()
	_emit_selected()


func _emit_selected() -> void:
	var node := selected_node()
	if not node.is_empty():
		node_selected.emit(node)


func _preferred_node_id() -> String:
	for preferred_kind in ["claim", "actor", "event", "location"]:
		for node in nodes:
			if str(node.get("kind", "")) == preferred_kind:
				return str(node.get("id", ""))
	return ""


func _node_at(point: Vector2) -> String:
	for node_id in node_rects:
		if (node_rects[node_id] as Rect2).has_point(point):
			return str(node_id)
	return ""


func _node_exists(node_id: String) -> bool:
	return not _node_by_id(node_id).is_empty()


func _node_by_id(node_id: String) -> Dictionary:
	for node in nodes:
		if str(node.get("id", "")) == node_id:
			return node
	return {}


func _node_kind(node_id: String) -> String:
	return str(_node_by_id(node_id).get("kind", ""))


func _is_related_to_selection(node_id: String) -> bool:
	if selected_id == "":
		return true
	for edge in edges:
		var source_id := str(edge.get("source_id", ""))
		var target_id := str(edge.get("target_id", ""))
		if source_id == selected_id and target_id == node_id or target_id == selected_id and source_id == node_id:
			return true
	return false


func _node_style(fill: Color, accent: Color, emphasized: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(accent, 0.92 if emphasized else 0.38)
	style.set_border_width_all(2 if emphasized else 1)
	style.set_corner_radius_all(3)
	style.shadow_color = Color("02040399")
	style.shadow_size = 8 if emphasized else 3
	return style


func _edge_color(status: String) -> Color:
	match status:
		"risk": return COLORS.danger
		"focus": return COLORS.accent
		"confirmed": return COLORS.success
		"unconfirmed": return COLORS.muted
		_: return COLORS.line


func _kind_color(kind: String) -> Color:
	match kind:
		"claim": return COLORS.accent
		"event": return COLORS.danger
		"location": return COLORS.success
		_: return COLORS.muted


func _kind_label(kind: String) -> String:
	match kind:
		"actor": return "人物"
		"claim": return "线索"
		"event": return "事件"
		"location": return "地点"
		_: return "信息"


func _font_size(requested: int) -> int:
	return maxi(requested, minimum_font_size)


func _ellipsize(value: String, limit: int) -> String:
	if value.length() <= limit:
		return value
	return value.left(maxi(1, limit - 1)) + "…"
