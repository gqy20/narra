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

var start_layer: Control
var game_layer: Control
var name_input: LineEdit
var connection_label: Label
var day_label: Label
var place_label: Label
var phase_label: Label
var player_box: VBoxContainer
var clues_box: VBoxContainer
var scene_box: VBoxContainer
var people_box: VBoxContainer
var actions_box: VBoxContainer
var feedback_box: VBoxContainer
var footer_label: Label
var ending_layer: Control
var ending_box: VBoxContainer


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
	_build_ending_layer()


func _build_header() -> void:
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", _panel_style(COLORS.panel_alt, 1, 12))
	header.custom_minimum_size.y = 82
	game_layer.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	header.add_child(row)

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
	player_box = _zone(left, "一 · 自身", 0.43)
	clues_box = _zone(left, "二 · 已知线索", 0.57)

	var center := VBoxContainer.new()
	center.custom_minimum_size.x = 430
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 14)
	columns.add_child(center)
	scene_box = _zone(center, "三 · 当前局势", 0.62)
	feedback_box = _zone(center, "四 · 本回合回响", 0.38)

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 380
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	columns.add_child(right)
	people_box = _zone(right, "五 · 同地人物", 0.36)
	actions_box = _zone(right, "六 · 可行之事", 0.64)


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
	subtitle.text = "你带着一则不完全可靠的传言走入黑风谷。\n这里的人会记住消息，也会因消息改变选择。"
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
	content.add_child(_button("重新连接本地服务", _retry_connection, true))
	connection_label = Label.new()
	connection_label.text = "正在确认本地服务…"
	connection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	connection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	connection_label.add_theme_color_override("font_color", COLORS.muted)
	content.add_child(connection_label)


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


func _request(operation: String, method: HTTPClient.Method, path: String, payload := {}) -> void:
	if pending_operation != "":
		return
	pending_operation = operation
	footer_label.text = "处理中：%s" % operation if footer_label else ""
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := "" if method == HTTPClient.METHOD_GET else JSON.stringify(payload)
	var error := http.request(API_BASE + path, headers, method, body)
	if error != OK:
		pending_operation = ""
		_show_error("无法发送请求（%s）" % error)


func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var operation := pending_operation
	pending_operation = ""
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
	game_layer.hide()
	ending_layer.hide()
	start_layer.show()


func _show_game() -> void:
	start_layer.hide()
	game_layer.show()


func _show_error(message: String) -> void:
	if start_layer.visible:
		connection_label.text = message
		connection_label.add_theme_color_override("font_color", COLORS.danger)
	else:
		footer_label.text = message
		footer_label.add_theme_color_override("font_color", COLORS.danger)


func _render_view() -> void:
	var player: Dictionary = current_view.get("player", {})
	var location: Dictionary = current_view.get("location", {})
	day_label.text = "第 %d / %d 日" % [int(current_view.get("day", 0)), int(current_view.get("duration", 0))]
	place_label.text = str(location.get("name", "未知"))
	phase_label.text = str(current_view.get("phase", "进行中"))
	footer_label.add_theme_color_override("font_color", COLORS.muted)
	_render_player(player)
	_render_clues(current_view.get("known_facts", []))
	_render_scene(current_view.get("recent_events", []), current_view.get("guidance", []), current_view.get("travel", null))
	_render_people(current_view.get("known_actors", []))
	_render_actions(current_view.get("available_actions", []))
	_render_feedback(current_view.get("last_turn", null))
	if bool(current_view.get("ended", false)):
		_render_ending(current_view.get("ending", {}))


func _render_player(player: Dictionary) -> void:
	_clear(player_box)
	_text(player_box, str(player.get("name", "旅人")), false, 22)
	var state := "空闲"
	if bool(player.get("busy", false)):
		state = "%s · 至第 %d 日" % [str(player.get("busy_action", "行动中")), int(player.get("busy_until", 0))]
	_text(player_box, "状态：%s　伤势：%d" % [state, int(player.get("injury", 0))], true)
	var resources: Dictionary = player.get("resources", {})
	var labels := {"combat": "战力", "support": "助力", "spirit_stones": "灵石", "credit": "信用"}
	for key in ["combat", "support", "spirit_stones", "credit"]:
		_text(player_box, "%s　%s" % [labels[key], resources.get(key, 0)])
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
		var status := "存疑" if bool(clue.get("contested", false)) else "置信 %d" % int(clue.get("confidence", 0))
		_text(clues_box, "%s · 来源：%s" % [status, clue.get("source", "未知")], true, 13)


func _render_scene(events: Array, guidance: Array, travel) -> void:
	_clear(scene_box)
	if travel is Dictionary:
		var readiness := "可以动身" if bool(travel.get("ready", false)) else "尚有阻碍"
		_text(scene_box, "目标：%s · %s" % [travel.get("destination", "未知"), readiness], false, 16)
		for blocker in travel.get("blockers", []):
			_text(scene_box, "· %s" % blocker, true)
	for tip in guidance:
		_text(scene_box, "指引 · %s" % tip, true)
	if events.is_empty():
		_text(scene_box, "四下暂时没有新的公开动静。", true)
		return
	for event in events:
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
	var tell_groups := {}
	for action in actions:
		if action.get("kind", "") == "tell":
			var target := str(action.get("target_name", "某人"))
			if not tell_groups.has(target):
				tell_groups[target] = []
			tell_groups[target].append(action)
		else:
			_add_action_button(action)
	for target in tell_groups:
		var facts: Array = tell_groups[target]
		if facts.size() == 1:
			_add_action_button(facts[0])
		else:
			var menu := MenuButton.new()
			menu.text = "告知%s…（%d 条线索）" % [target, facts.size()]
			menu.custom_minimum_size.y = 42
			menu.get_popup().id_pressed.connect(_on_tell_fact_selected.bind(facts))
			for index in facts.size():
				menu.get_popup().add_item(str(facts[index].get("fact_claim", "一条线索")), index)
			actions_box.add_child(menu)


func _add_action_button(action: Dictionary) -> void:
	var duration := int(action.get("duration", 1))
	var label := "%s　· %d 日" % [action.get("name", "行动"), duration]
	var button := _button(label, _execute_action.bind(str(action.get("id", ""))), false)
	button.tooltip_text = str(action.get("description", ""))
	actions_box.add_child(button)
	_text(actions_box, str(action.get("description", "")), true, 13)


func _on_tell_fact_selected(index: int, facts: Array) -> void:
	if index >= 0 and index < facts.size():
		_execute_action(str(facts[index].get("id", "")))


func _render_feedback(feedback) -> void:
	_clear(feedback_box)
	if not feedback is Dictionary:
		_text(feedback_box, "做出选择后，这里会记录直接结果与可观察影响。", true)
		return
	_text(feedback_box, "%s · 推进 %d 日" % [feedback.get("action", "行动"), int(feedback.get("days_advanced", 0))], false, 16)
	for message in feedback.get("messages", []):
		_text(feedback_box, "· %s" % message)
	for influence in feedback.get("influence", []):
		_text(feedback_box, "%s因“%s”改变了判断" % [influence.get("actor_name", "有人"), influence.get("fact_claim", "消息")], false, 14)


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
