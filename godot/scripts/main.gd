extends Control

const API_BASE := "http://127.0.0.1:8787/api/v1"
const AUTOSAVE_SLOT := "autosave"
const COLORS := {
	"bg": Color("0b100e"),
	"panel": Color("141b17"),
	"panel_alt": Color("1b241e"),
	"line": Color("354238"),
	"ink": Color("ece6d5"),
	"muted": Color("a9ad9e"),
	"accent": Color("c69a56"),
	"danger": Color("b96e64"),
	"success": Color("7fa47e"),
}

@onready var http: HTTPRequest = $HTTPRequest

var current_view: Dictionary = {}
var pending_operation := ""
var autosave_after_action := false
var selected_action: Dictionary = {}

var start_layer: Control
var game_layer: Control
var name_input: LineEdit
var connection_label: Label
var retry_button: Button
var day_label: Label
var place_label: Label
var phase_label: Label
var objective_label: Label
var player_box: VBoxContainer
var clues_box: VBoxContainer
var scene_box: VBoxContainer
var people_box: VBoxContainer
var actions_box: VBoxContainer
var feedback_box: VBoxContainer
var footer_label: Label
var ending_layer: Control
var ending_box: VBoxContainer
var confirmation_layer: Control
var confirmation_box: VBoxContainer


func _ready() -> void:
	http.request_completed.connect(_on_request_completed)
	_build_interface()
	_request("health", HTTPClient.METHOD_GET, "/health")


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = COLORS.bg
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	game_layer = VBoxContainer.new()
	game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	game_layer.add_theme_constant_override("separation", 14)
	add_child(game_layer)
	_build_header()
	_build_dashboard()
	_build_footer()
	game_layer.hide()

	_build_start_layer()
	_build_confirmation_layer()
	_build_ending_layer()


func _build_header() -> void:
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", _panel_style(COLORS.panel_alt, 1, 12))
	header.custom_minimum_size.y = 108
	game_layer.add_child(header)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	header.add_child(stack)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	stack.add_child(row)

	var brand := Label.new()
	brand.text = "凡途  /  黑风谷"
	brand.add_theme_font_size_override("font_size", 26)
	brand.add_theme_color_override("font_color", COLORS.accent)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(brand)

	day_label = _header_value(row, "时日")
	place_label = _header_value(row, "所在")
	phase_label = _header_value(row, "局势")
	row.add_child(_button("保存", _save_game, false))
	row.add_child(_button("返回", _return_to_start, true))
	objective_label = Label.new()
	objective_label.text = "本局目标 · 通过调查、传播或亲自入谷影响青髓芝归属"
	objective_label.add_theme_font_size_override("font_size", 14)
	objective_label.add_theme_color_override("font_color", COLORS.muted)
	stack.add_child(objective_label)


func _build_dashboard() -> void:
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	game_layer.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 310
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 14)
	columns.add_child(left)
	player_box = _zone(left, "一 · 自身", 0.42)
	clues_box = _zone(left, "二 · 已知线索", 0.58)

	var center := VBoxContainer.new()
	center.custom_minimum_size.x = 430
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 14)
	columns.add_child(center)
	scene_box = _zone(center, "三 · 当前局势", 0.55)
	feedback_box = _zone(center, "四 · 本回合回响", 0.45)

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 380
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	columns.add_child(right)
	people_box = _zone(right, "五 · 同地人物", 0.4)
	actions_box = _zone(right, "六 · 可行之事", 0.6)


func _build_footer() -> void:
	footer_label = Label.new()
	footer_label.text = "连接本地规则服务…"
	footer_label.add_theme_color_override("font_color", COLORS.muted)
	footer_label.add_theme_font_size_override("font_size", 14)
	game_layer.add_child(footer_label)


func _build_start_layer() -> void:
	start_layer = CenterContainer.new()
	start_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(start_layer)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 430)
	card.add_theme_stylebox_override("panel", _panel_style(COLORS.panel, 1, 24))
	start_layer.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	card.add_child(content)

	var eyebrow := Label.new()
	eyebrow.text = "确定性局势模拟 · MVP"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_color_override("font_color", COLORS.accent)
	content.add_child(eyebrow)
	var title := Label.new()
	title.text = "凡 途"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", COLORS.ink)
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "三十日内，青髓芝的归属将被决定。\n核验、交易、赶路，或让消息改变他人的选择。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", COLORS.muted)
	content.add_child(subtitle)

	name_input = LineEdit.new()
	name_input.placeholder_text = "输入角色名"
	name_input.text = "无名修士"
	name_input.add_theme_font_size_override("font_size", 18)
	content.add_child(name_input)
	content.add_child(_button("踏入黑风谷", _new_game, false))
	content.add_child(_button("继续上次旅程", _load_game, true))
	retry_button = _button("重新连接本地服务", _retry_connection, true)
	retry_button.hide()
	content.add_child(retry_button)
	connection_label = Label.new()
	connection_label.text = "正在确认本地服务…"
	connection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	connection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	connection_label.add_theme_color_override("font_color", COLORS.muted)
	content.add_child(connection_label)


func _build_confirmation_layer() -> void:
	confirmation_layer = Control.new()
	confirmation_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	confirmation_layer.hide()
	add_child(confirmation_layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(540, 330)
	card.add_theme_stylebox_override("panel", _panel_style(COLORS.panel, 2, 22))
	center.add_child(card)
	confirmation_box = VBoxContainer.new()
	confirmation_box.add_theme_constant_override("separation", 14)
	card.add_child(confirmation_box)


func _build_ending_layer() -> void:
	ending_layer = CenterContainer.new()
	ending_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_layer.hide()
	add_child(ending_layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_layer.add_child(shade)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(680, 520)
	card.add_theme_stylebox_override("panel", _panel_style(COLORS.panel, 2, 26))
	ending_layer.add_child(card)
	ending_box = VBoxContainer.new()
	ending_box.add_theme_constant_override("separation", 16)
	card.add_child(ending_box)


func _header_value(parent: Container, caption: String) -> Label:
	var group := VBoxContainer.new()
	var small := Label.new()
	small.text = caption
	small.add_theme_font_size_override("font_size", 12)
	small.add_theme_color_override("font_color", COLORS.muted)
	group.add_child(small)
	var value := Label.new()
	value.text = "—"
	value.add_theme_font_size_override("font_size", 18)
	value.add_theme_color_override("font_color", COLORS.ink)
	group.add_child(value)
	parent.add_child(group)
	return value


func _zone(parent: VBoxContainer, title_text: String, ratio: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.add_theme_stylebox_override("panel", _panel_style(COLORS.panel, 1, 14))
	parent.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", COLORS.accent)
	outer.add_child(title)
	var rule := HSeparator.new()
	rule.modulate = COLORS.line
	outer.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	return box


func _panel_style(color: Color, border: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = COLORS.line
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _button(text_value: String, callback: Callable, secondary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 42
	button.add_theme_font_size_override("font_size", 16)
	var normal_color: Color = COLORS.panel_alt if secondary else Color("5b462d")
	button.add_theme_stylebox_override("normal", _panel_style(normal_color, 1, 8))
	button.add_theme_stylebox_override("hover", _panel_style(Color("745a38"), 1, 8))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("3e3122"), 1, 8))
	button.pressed.connect(callback)
	return button


func _text(parent: Container, value: String, muted := false, size := 15) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", COLORS.muted if muted else COLORS.ink)
	parent.add_child(label)
	return label


func _clear(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()


func _set_buttons_disabled(node: Node, disabled: bool) -> void:
	if node is BaseButton:
		node.disabled = disabled
	for child in node.get_children():
		_set_buttons_disabled(child, disabled)


func _operation_label(operation: String) -> String:
	var labels := {
		"health": "正在连接规则服务",
		"new": "正在进入黑风谷",
		"load": "正在读取旅程",
		"save": "正在保存",
		"autosave": "正在自动保存",
		"action": "正在推演行动结果",
		"quit": "正在返回",
	}
	return str(labels.get(operation, "处理中"))


func _request(operation: String, method: HTTPClient.Method, path: String, payload := {}) -> void:
	if pending_operation != "":
		return
	pending_operation = operation
	_set_buttons_disabled(self, true)
	if footer_label:
		footer_label.text = _operation_label(operation) + "…"
	if start_layer.visible and connection_label:
		connection_label.text = _operation_label(operation) + "…"
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := "" if method == HTTPClient.METHOD_GET else JSON.stringify(payload)
	var error := http.request(API_BASE + path, headers, method, body)
	if error != OK:
		pending_operation = ""
		_set_buttons_disabled(self, false)
		_show_error("无法发送请求（%s）" % error)


func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var operation := pending_operation
	pending_operation = ""
	_set_buttons_disabled(self, false)
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if response_code < 200 or response_code >= 300 or not parsed is Dictionary:
		var message := "本地服务无响应，请先运行项目启动脚本。"
		if parsed is Dictionary and parsed.get("error", {}) is Dictionary:
			message = str(parsed.get("error", {}).get("message", message))
		_show_error(message)
		return

	if connection_label:
		connection_label.text = "本地规则服务已就绪"
		connection_label.add_theme_color_override("font_color", COLORS.success)
		retry_button.hide()
	if operation == "health":
		footer_label.text = "规则服务已连接" if footer_label else ""
		return
	if operation == "quit":
		_show_start()
		return
	if parsed.has("view"):
		current_view = parsed["view"]
		_show_game()
		_render_view()
	if operation == "action" and autosave_after_action:
		autosave_after_action = false
		_request("autosave", HTTPClient.METHOD_POST, "/game/save", {"slot": AUTOSAVE_SLOT})
	elif operation == "autosave":
		footer_label.text = "已自动保存 · 存档槽 %s" % AUTOSAVE_SLOT
	else:
		footer_label.text = "规则服务已连接"


func _new_game() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name == "":
		player_name = "无名修士"
	_request("new", HTTPClient.METHOD_POST, "/game/new", {"player_name": player_name})


func _retry_connection() -> void:
	connection_label.text = "正在重新连接…"
	connection_label.add_theme_color_override("font_color", COLORS.muted)
	_request("health", HTTPClient.METHOD_GET, "/health")


func _load_game() -> void:
	_request("load", HTTPClient.METHOD_POST, "/game/load", {"slot": AUTOSAVE_SLOT})


func _save_game() -> void:
	_request("save", HTTPClient.METHOD_POST, "/game/save", {"slot": AUTOSAVE_SLOT})


func _return_to_start() -> void:
	_request("quit", HTTPClient.METHOD_POST, "/game/quit")


func _execute_action(action_id: String) -> void:
	autosave_after_action = true
	_request("action", HTTPClient.METHOD_POST, "/game/action", {"action_id": action_id})


func _show_start() -> void:
	current_view = {}
	selected_action = {}
	game_layer.hide()
	confirmation_layer.hide()
	ending_layer.hide()
	start_layer.show()


func _show_game() -> void:
	start_layer.hide()
	game_layer.show()


func _show_error(message: String) -> void:
	if start_layer.visible:
		connection_label.text = message
		connection_label.add_theme_color_override("font_color", COLORS.danger)
		retry_button.show()
	else:
		footer_label.text = message
		footer_label.add_theme_color_override("font_color", COLORS.danger)


func _render_view() -> void:
	var player: Dictionary = current_view.get("player", {})
	var location: Dictionary = current_view.get("location", {})
	var day := int(current_view.get("day", 0))
	day_label.text = "第 %d / %d 日" % [maxi(1, day), int(current_view.get("duration", 0))]
	place_label.text = str(location.get("name", "未知"))
	var phase := str(current_view.get("phase", ""))
	phase_label.text = "准备" if phase == "" else phase
	var travel = current_view.get("travel", null)
	objective_label.text = "本局目标 · 通过调查、传播或亲自入谷影响青髓芝归属"
	footer_label.add_theme_color_override("font_color", COLORS.muted)
	_render_player(player)
	_render_clues(current_view.get("known_facts", []))
	_render_scene(current_view.get("recent_events", []), current_view.get("guidance", []), travel)
	_render_people(current_view.get("known_actors", []))
	var available_actions = current_view.get("available_actions", [])
	if not available_actions is Array:
		available_actions = []
	_render_actions(available_actions)
	_render_feedback(current_view.get("last_turn", null))
	var ending = current_view.get("ending", null)
	if bool(current_view.get("resolved", false)) or bool(current_view.get("ended", false)) or ending is Dictionary:
		_render_ending(ending if ending is Dictionary else {})


func _render_player(player: Dictionary) -> void:
	_clear(player_box)
	_text(player_box, str(player.get("name", "旅人")), false, 22)
	var state := "空闲"
	if bool(player.get("busy", false)):
		state = "%s · 至第 %d 日" % [str(player.get("busy_action", "行动中")), int(player.get("busy_until", 0))]
	_text(player_box, "状态：%s　伤势：%d" % [state, int(player.get("injury", 0))], true)
	var resources: Dictionary = player.get("resources", {})
	_text(player_box, "战力 %s　助力 %s" % [resources.get("combat", 0), resources.get("support", 0)])
	_text(player_box, "灵石 %s　信用 %s" % [resources.get("spirit_stones", 0), resources.get("credit", 0)])
	var items: Array = player.get("items", [])
	if not items.is_empty():
		_text(player_box, "持有", true, 13)
		for item in items:
			_text(player_box, "· %s × %d" % [item.get("name", "物品"), int(item.get("amount", 1))])


func _render_clues(clues: Array) -> void:
	_clear(clues_box)
	if clues.is_empty():
		_text(clues_box, "尚未掌握可用线索。", true)
		return
	for clue in clues:
		_text(clues_box, str(clue.get("claim", "未知传言")), false, 16)
		var confidence := int(clue.get("confidence", 0))
		var status := "已核实" if confidence >= 3 else ("较可信" if confidence == 2 else "未经核实")
		if bool(clue.get("contested", false)):
			status += " · 与旧说法冲突"
		_text(clues_box, "%s · 来源：%s" % [status, clue.get("source", "未知")], true, 13)


func _render_scene(events: Array, guidance: Array, travel) -> void:
	_clear(scene_box)
	if travel is Dictionary:
		var readiness := "可以动身" if bool(travel.get("ready", false)) else "尚有阻碍"
		_text(scene_box, "个人入谷准备 · %s" % readiness, false, 16)
		_text(scene_box, "目的地：%s" % travel.get("destination", "未知"), true, 13)
		for blocker in travel.get("blockers", []):
			_text(scene_box, "· %s" % blocker, true)
	for tip in guidance:
		_text(scene_box, "指引 · %s" % tip, true)
	if events.is_empty():
		_text(scene_box, "四下暂时没有新的公开动静。", true)
		return
	for index in range(events.size() - 1, -1, -1):
		var event = events[index]
		_text(scene_box, "第 %d 日 · %s" % [int(event.get("day", 0)), event.get("description", "局势变化")])


func _render_people(actors: Array) -> void:
	_clear(people_box)
	if actors.is_empty():
		_text(people_box, "此地没有可交谈的人。", true)
		return
	for actor in actors:
		_text(people_box, "%s · %s" % [actor.get("name", "无名者"), actor.get("faction", "散修")], false, 16)
		_text(people_box, str(actor.get("public_profile", "公开资料尚未收集")), true, 13)


func _render_actions(actions: Array) -> void:
	_clear(actions_box)
	if actions.is_empty():
		_text(actions_box, "当前没有可执行行动。", true)
		return
	var grouped := {}
	for action in actions:
		var category := str(action.get("category", "other"))
		if not grouped.has(category):
			grouped[category] = []
		grouped[category].append(action)
	var order := ["investigate", "trade", "move", "information", "self", "time", "other"]
	var category_names := {
		"investigate": "查证与探索",
		"information": "交涉与消息",
		"trade": "坊市交易",
		"move": "动身前往",
		"self": "自身安排",
		"time": "等待与推进",
		"other": "其他",
	}
	for category in order:
		if not grouped.has(category):
			continue
		var heading := _text(actions_box, str(category_names[category]), true, 13)
		heading.add_theme_color_override("font_color", COLORS.accent)
		if category == "information":
			_add_information_actions(grouped[category])
		else:
			for action in grouped[category]:
				_add_action_button(action)


func _add_information_actions(actions: Array) -> void:
	var tell_groups := {}
	for action in actions:
		if action.get("kind", "") != "tell":
			_add_action_button(action)
			continue
		var target := str(action.get("target_name", "某人"))
		if not tell_groups.has(target):
			tell_groups[target] = []
		tell_groups[target].append(action)
	for target in tell_groups:
		var facts: Array = tell_groups[target]
		if facts.size() == 1:
			var action: Dictionary = facts[0]
			var button := _button("向%s传递线索" % target, _consider_action.bind(action), true)
			button.tooltip_text = str(action.get("description", ""))
			actions_box.add_child(button)
		else:
			var menu := MenuButton.new()
			menu.text = "向%s传递线索…（%d 条）" % [target, facts.size()]
			menu.custom_minimum_size.y = 42
			menu.get_popup().id_pressed.connect(_on_tell_fact_selected.bind(facts))
			for index in facts.size():
				menu.get_popup().add_item(str(facts[index].get("fact_claim", "一条线索")), index)
			actions_box.add_child(menu)


func _add_action_button(action: Dictionary) -> void:
	var duration := int(action.get("duration", 1))
	var kind := str(action.get("kind", ""))
	var label := str(action.get("name", "行动"))
	if action.get("id", "") == "wait:next":
		label += "　· 直至新变化"
	elif kind == "advance":
		label += "　· 最多 %d 日" % duration
	else:
		label += "　· %d 日" % duration
	var secondary: bool = action.get("category", "") in ["self", "time"]
	var button := _button(label, _consider_action.bind(action), secondary)
	button.tooltip_text = str(action.get("description", ""))
	actions_box.add_child(button)
	_text(actions_box, str(action.get("description", "")), true, 13)


func _on_tell_fact_selected(index: int, facts: Array) -> void:
	if index >= 0 and index < facts.size():
		_consider_action(facts[index])


func _consider_action(action: Dictionary) -> void:
	var kind := str(action.get("kind", ""))
	var needs_confirmation: bool = int(action.get("duration", 1)) > 1 or not action.get("costs", {}).is_empty() or kind in ["advance", "move", "tell"]
	if not needs_confirmation:
		_execute_action(str(action.get("id", "")))
		return
	selected_action = action
	_clear(confirmation_box)
	_text(confirmation_box, "确认这次选择？", false, 24)
	_text(confirmation_box, str(action.get("name", "行动")), false, 19)
	if action.get("id", "") == "wait:next":
		var warning := _text(confirmation_box, "将逐日推演并在下一次值得关注的变化处停下，实际可能跨越多个平静日。", false, 15)
		warning.add_theme_color_override("font_color", COLORS.accent)
	else:
		_text(confirmation_box, str(action.get("description", "")), true, 15)
		_text(confirmation_box, "预计占用 %d 日" % int(action.get("duration", 1)), true)
	var warnings = action.get("warnings", [])
	if warnings is Array:
		for warning_text in warnings:
			var warning_line := _text(confirmation_box, "注意 · %s" % warning_text, false, 14)
			warning_line.add_theme_color_override("font_color", COLORS.accent)
	var costs: Dictionary = action.get("costs", {})
	if not costs.is_empty():
		var cost_names := {"spirit_stones": "灵石", "credit": "信用", "combat": "战力", "support": "助力"}
		var cost_parts: Array[String] = []
		for key in costs:
			cost_parts.append("%s %s" % [cost_names.get(key, key), costs[key]])
		_text(confirmation_box, "消耗：" + "、".join(cost_parts), false, 15)
	confirmation_box.add_child(_button("确认执行", _confirm_selected_action, false))
	confirmation_box.add_child(_button("再想想", _cancel_confirmation, true))
	confirmation_layer.show()


func _confirm_selected_action() -> void:
	var action_id := str(selected_action.get("id", ""))
	selected_action = {}
	confirmation_layer.hide()
	_execute_action(action_id)


func _cancel_confirmation() -> void:
	selected_action = {}
	confirmation_layer.hide()


func _render_feedback(feedback) -> void:
	_clear(feedback_box)
	if not feedback is Dictionary:
		_text(feedback_box, "选择行动后，这里会分开显示时间、直接结果和人物判断变化。", true)
		return
	var status_names := {"completed": "已经完成", "started": "已经开始", "failed": "未能完成", "advanced": "已经推进"}
	var status := str(status_names.get(feedback.get("status", ""), feedback.get("status", "已结算")))
	_text(feedback_box, "%s · %s" % [feedback.get("action", "行动"), status], false, 17)
	var days := int(feedback.get("days_advanced", 0))
	if days > 0:
		var time_line := _text(feedback_box, "时日推进 · %d 日" % days, false, 15)
		time_line.add_theme_color_override("font_color", COLORS.accent if days > 1 else COLORS.ink)
	var quiet_days := int(feedback.get("quiet_days", 0))
	if quiet_days > 0:
		_text(feedback_box, "其中 %d 日没有出现需要你处理的变化" % quiet_days, true, 13)
	var influences: Array = feedback.get("influence", [])
	if not influences.is_empty():
		var influence_heading := _text(feedback_box, "你的消息改变了人物判断", true, 13)
		influence_heading.add_theme_color_override("font_color", COLORS.accent)
	for influence in influences:
		_text(feedback_box, "%s因“%s”改变了判断" % [influence.get("actor_name", "有人"), influence.get("fact_claim", "消息")], false, 14)
		for change in influence.get("changes", []):
			_text(feedback_box, "原本：%s" % change.get("without_information", "其他安排"), true, 13)
			_text(feedback_box, "现在：%s" % change.get("with_information", "新的安排"), false, 13)
	var messages: Array = feedback.get("messages", [])
	if not messages.is_empty():
		var result_heading := _text(feedback_box, "可见结果", true, 13)
		result_heading.add_theme_color_override("font_color", COLORS.accent)
	for message in messages:
		_text(feedback_box, "· %s" % message)


func _render_ending(ending: Dictionary) -> void:
	_clear(ending_box)
	var eyebrow := _text(ending_box, "尘埃落定", true, 15)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := _text(ending_box, str(ending.get("outcome", current_view.get("outcome", "旅程结束"))), false, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for highlight in ending.get("highlights", []):
		_text(ending_box, "· %s" % highlight)
	for influence in ending.get("influence", []):
		_text(ending_box, "%s 收到了你传递的“%s”" % [influence.get("actor_name", "有人"), influence.get("fact_claim", "消息")], true)
	ending_box.add_child(_button("返回起点", _return_to_start, false))
	ending_layer.show()
