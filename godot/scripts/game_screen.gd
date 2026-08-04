extends RefCounted

const HeaderViewScript = preload("res://ui/screens/game/header_view.gd")
const DashboardViewScript = preload("res://ui/screens/game/dashboard_view.gd")
const FooterViewScript = preload("res://ui/screens/game/footer_view.gd")

var host
var game_layer: Control
var header_brand_label: Label
var header_world_title_label: Label
var day_label: Label
var place_label: Label
var phase_label: Label
var timing_label: Label
var sound_button: Button
var action_canvas: CanvasLayer
var action_dock_host: Control
var action_dock: PanelContainer
var action_dock_title: Label
var objective_label: Label
var location_detail_box: VBoxContainer
var stage_people_box: HFlowContainer
var overview_actions_box: VBoxContainer
var actor_focus_workspace: HBoxContainer
var actor_focus_message_list: VBoxContainer
var actor_focus_detail_scroll: ScrollContainer
var actor_focus_detail_box: VBoxContainer
var fact_action_scroll: ScrollContainer
var actions_box: VBoxContainer
var actor_focus_footer: HBoxContainer
var visual_stack: Control
var map_panel: HBoxContainer
var location_panel: VBoxContainer
var map_detail_box: VBoxContainer
var map_mode_button: Button
var location_mode_button: Button
var world_map_view: Control
var location_stage: Control
var actor_portrait_frame: PanelContainer
var actor_portrait: TextureRect
var actor_portrait_name: Label
var actor_portrait_meta: Label
var footer_label: Label


func _init(value) -> void:
	host = value


func _configure_theme() -> void:
	host.body_font = host.AppVisualThemeScript.BodyFont
	host.medium_font = host.AppVisualThemeScript.MediumFont
	host.display_font = host.AppVisualThemeScript.DisplayFont
	host.narrative_font = host.AppVisualThemeScript.NarrativeFont
	host.theme = host.AppVisualThemeScript.build_theme()


func _build_interface() -> void:
	var background = TextureRect.new()
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.46, 1.0])
	gradient.colors = PackedColorArray([host.COLORS.bg_lift, host.COLORS.bg, host.COLORS.bg_deep])
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 1024
	gradient_texture.height = 1024
	gradient_texture.fill_from = Vector2(0.0, 0.0)
	gradient_texture.fill_to = Vector2(1.0, 1.0)
	background.texture = gradient_texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(background)

	var top_rule = ColorRect.new()
	top_rule.color = Color(host.COLORS.accent, 0.45)
	top_rule.custom_minimum_size.y = 2
	top_rule.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(top_rule)

	game_layer = VBoxContainer.new()
	game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
	game_layer.add_theme_constant_override("separation", 10)
	host.add_child(game_layer)
	var header_refs := HeaderViewScript.new().build(game_layer, host.ui_factory, {
		"journal": host.journal_panel_controller._open_journal,
		"save": host._save_game,
		"settings": host.start_settings_screen_controller._open_audio_settings,
		"return_to_start": host._return_to_start,
	})
	header_brand_label = header_refs.brand_label
	header_world_title_label = header_refs.world_title_label
	day_label = header_refs.day_label
	place_label = header_refs.place_label
	phase_label = header_refs.phase_label
	timing_label = header_refs.timing_label
	sound_button = header_refs.settings_button
	var dashboard_refs := DashboardViewScript.new().build(host, game_layer, host.ui_factory, {
		"world_map_script": host.WorldMapViewScript,
		"location_stage_script": host.LocationStageScript,
		"presentation_registry": host.presentation_registry,
	}, {
		"show_location": host.game_screen_controller._set_visual_mode.bind("location"),
		"show_map": host.game_screen_controller._set_visual_mode.bind("map"),
		"map_location_selected": host.game_screen_controller._on_map_location_selected,
		"travel_day_changed": host.presentation_controller._on_travel_day_changed,
	})
	action_canvas = dashboard_refs.action_canvas
	action_dock_host = dashboard_refs.action_dock_host
	action_dock = dashboard_refs.action_dock
	action_dock_title = dashboard_refs.action_dock_title
	objective_label = dashboard_refs.objective_label
	location_detail_box = dashboard_refs.location_detail_box
	stage_people_box = dashboard_refs.stage_people_box
	overview_actions_box = dashboard_refs.overview_actions_box
	actor_focus_workspace = dashboard_refs.actor_focus_workspace
	actor_focus_message_list = dashboard_refs.actor_focus_message_list
	actor_focus_detail_scroll = dashboard_refs.actor_focus_detail_scroll
	actor_focus_detail_box = dashboard_refs.actor_focus_detail_box
	fact_action_scroll = dashboard_refs.fact_action_scroll
	actions_box = dashboard_refs.actions_box
	actor_focus_footer = dashboard_refs.actor_focus_footer
	visual_stack = dashboard_refs.visual_stack
	map_panel = dashboard_refs.map_panel
	location_panel = dashboard_refs.location_panel
	map_detail_box = dashboard_refs.map_detail_box
	map_mode_button = dashboard_refs.map_mode_button
	location_mode_button = dashboard_refs.location_mode_button
	world_map_view = dashboard_refs.world_map_view
	location_stage = dashboard_refs.location_stage
	actor_portrait_frame = dashboard_refs.actor_portrait_frame
	actor_portrait = dashboard_refs.actor_portrait
	actor_portrait_name = dashboard_refs.actor_portrait_name
	actor_portrait_meta = dashboard_refs.actor_portrait_meta
	footer_label = FooterViewScript.new().build(game_layer, host.ui_factory)
	_set_visual_mode("map")
	game_layer.hide()

	host.start_settings_screen_controller._build_start_layer()
	host.journal_panel_controller._build_journal_layer()
	host.action_panel_controller._build_confirmation_layer()
	host.start_settings_screen_controller._build_settings_layer()
	host.presentation_controller._build_causal_layer()
	host.presentation_controller._build_ending_layer()
	host.presentation_director = host.PresentationDirectorScript.new()
	host.add_child(host.presentation_director)
	host.presentation_director.configure(host.display_font, host.medium_font, host.presentation_registry, host.TYPE_SCALE)


func _render_view() -> void:
	var player: Dictionary = host.current_view.get("player", {})
	var location: Dictionary = host.current_view.get("location", {})
	var day = int(host.current_view.get("day", 0))
	day_label.text = _header_day(day, int(host.current_view.get("duration", 0)))
	place_label.text = _header_place(str(location.get("name", "未知")))
	phase_label.text = _header_phase_label(_phase_display(str(host.current_view.get("phase", ""))))
	var travel = host.current_view.get("travel", null)
	footer_label.add_theme_color_override("font_color", host.COLORS.muted)
	var available_actions = host.current_view.get("available_actions", [])
	if not available_actions is Array:
		available_actions = []
	host.available_actions_cache = available_actions
	var known_actors: Array = host.current_view.get("known_actors", [])
	var known_facts: Array = host.current_view.get("known_facts", [])
	var guidance: Array = host.current_view.get("guidance", [])
	host.action_panel_controller._reconcile_action_focus(known_actors, known_facts)
	var location_id = str(location.get("id", ""))
	if host.rendered_location_id != location_id:
		host.selected_map_location_id = location_id
		host.rendered_location_id = location_id
		host.stage_actor_id = ""
		host.stage_actor_name = ""
	host.game_screen_controller._reconcile_stage_actor(known_actors)
	timing_label.text = _known_timing(known_facts)
	objective_label.text = str(guidance[0]) if not guidance.is_empty() else "风声未定，先看清眼前的人和路。"
	host.game_screen_controller._render_player(player)
	host.journal_panel_controller._render_clues(known_facts, host.available_actions_cache)
	host.journal_panel_controller._render_scene(host.current_view.get("recent_events", []), guidance.slice(1), travel, host.current_view.get("last_turn", null), host.current_view.get("causal_threads", []), str(player.get("name", "旅人")))
	host.journal_panel_controller._render_people(known_actors, host.available_actions_cache)
	host.journal_panel_controller._render_travel_readiness(travel, host.current_view.get("preparation", {}))
	host.journal_panel_controller._render_journal_tab_states(known_facts, known_actors, travel, host.current_view.get("last_turn", null), host.available_actions_cache)
	host.action_panel_controller._render_actions(host.available_actions_cache)
	host.game_screen_controller._render_world_map(host.current_view.get("world_map", {}), location, host.available_actions_cache)
	host.game_screen_controller._render_location_stage(location, known_actors, host.available_actions_cache)
	host.game_screen_controller._sync_action_canvas_visibility()
	var ending = host.current_view.get("ending", null)
	if bool(host.current_view.get("resolved", false)) or bool(host.current_view.get("ended", false)) or ending is Dictionary:
		host.presentation_controller._render_ending(ending if ending is Dictionary else {})


func _set_visual_mode(mode: String) -> void:
	var previous_mode = host.visual_mode
	host.visual_mode = mode
	if mode == "map" and (host.focused_actor_id != "" or host.focused_fact_id != ""):
		host.action_panel_controller._reset_action_focus()
		if actions_box:
			host.action_panel_controller._render_actions(host.available_actions_cache)
	if map_panel:
		map_panel.visible = mode == "map"
	if location_panel:
		location_panel.visible = mode == "location"
	host.game_screen_controller._sync_action_canvas_visibility()
	if map_mode_button:
		map_mode_button.text = "◇ 地图"
		map_mode_button.tooltip_text = "查看公开地点、路线与行程"
		host.ui_factory.style_mode_state(map_mode_button, mode == "map")
	if location_mode_button:
		location_mode_button.text = "◉ 当前地点"
		location_mode_button.tooltip_text = "返回当前位置、人物与行动"
		host.ui_factory.style_mode_state(location_mode_button, mode == "location")
	if mode == "location" and previous_mode != "location" and location_stage:
		location_stage.play_establish.call_deferred()
	if actions_box:
		host.action_panel_controller._render_actions(host.available_actions_cache)


func _sync_action_canvas_visibility() -> void:
	if not action_canvas or not action_dock:
		return
	var should_show = (
		game_layer
		and game_layer.visible
		and host.visual_mode == "location"
		and not host.start_layer.visible
		and not host.journal_layer.visible
		and not host.confirmation_layer.visible
		and not host.settings_layer.visible
		and not host.causal_layer.visible
		and not host.ending_layer.visible
		and not (host.cinematic_director and host.cinematic_director.active)
		and not (host.prologue_director and host.prologue_director.active)
	)
	action_canvas.visible = should_show
	action_dock.visible = should_show


func _render_world_map(world_map, current_location: Dictionary, actions: Array) -> void:
	if not world_map is Dictionary:
		world_map = {}
	world_map_view.set_map(world_map, host.selected_map_location_id)
	host.game_screen_controller._render_map_detail(world_map, current_location, actions)


func _on_map_location_selected(location_id: String) -> void:
	host.selected_map_location_id = location_id
	host.game_screen_controller._render_map_detail(host.current_view.get("world_map", {}), host.current_view.get("location", {}), host.available_actions_cache)


func _render_map_detail(world_map: Dictionary, current_location: Dictionary, actions: Array) -> void:
	host.ui_factory.clear(map_detail_box)
	var selected = host.game_screen_controller._map_location(world_map.get("locations", []), host.selected_map_location_id)
	if selected.is_empty():
		host.ui_factory.text(map_detail_box, "选择一个地点", true, host.TYPE_SCALE.body)
		return
	var title_line = host.ui_factory.text(map_detail_box, str(selected.get("name", "未知地点")), false, host.TYPE_SCALE.headline)
	title_line.add_theme_font_override("font", host.display_font)
	title_line.add_theme_color_override("font_color", host.COLORS.accent if bool(selected.get("current", false)) else host.COLORS.ink)
	if not bool(selected.get("current", false)):
		var place_state = "安全落脚点" if bool(selected.get("safe", false)) else "危险区域"
		var state_line = host.ui_factory.text(map_detail_box, place_state, true, host.TYPE_SCALE.meta)
		state_line.add_theme_color_override("font_color", host.COLORS.success if bool(selected.get("safe", false)) else host.COLORS.danger)
	var description = host.ui_factory.text(map_detail_box, str(selected.get("description", "尚无公开地点资料")), true, host.TYPE_SCALE.compact)
	description.add_theme_constant_override("line_spacing", 6)
	if bool(selected.get("contest", false)):
		var contest_line = host.ui_factory.text(map_detail_box, "核心目标 · %s" % host.scenario_presentation.get("objective", "目标将在这里落定"), false, 13)
		contest_line.add_theme_color_override("font_color", host.COLORS.accent)
	_render_map_actor_plans(map_detail_box, world_map.get("actors", []), host.selected_map_location_id)
	if bool(selected.get("current", false)):
		host.journal_panel_controller._render_route_progresses(map_detail_box, host.current_view.get("route_progresses", []), true)
		var current_spacer = Control.new()
		current_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		map_detail_box.add_child(current_spacer)
		var hint = host.ui_factory.text(map_detail_box, "金色路线 · 当前可通行", true, host.TYPE_SCALE.meta)
		hint.add_theme_color_override("font_color", Color(host.COLORS.accent, 0.72))
		var enter_button = host.ui_factory.utility_button("回到眼前", host.game_screen_controller._set_visual_mode.bind("location"))
		enter_button.custom_minimum_size.y = 42
		map_detail_box.add_child(enter_button)
		return
	var route = host.game_screen_controller._current_map_route(world_map.get("routes", []), str(current_location.get("id", "")), host.selected_map_location_id)
	if route.is_empty():
		host.ui_factory.text(map_detail_box, "这里不与当前位置直接相连，需要从相邻地点转进。", true, 13)
		return
	var route_status = str(route.get("status", "known"))
	var route_labels = {"available": "可以通行", "blocked": "道路受阻", "known": "尚未打通"}
	var route_line = host.ui_factory.text(map_detail_box, "道路状态 · %s" % route_labels.get(route_status, "尚不明确"), false, 13)
	route_line.add_theme_color_override("font_color", host.COLORS.accent if route_status == "available" else (host.COLORS.danger if route_status == "blocked" else host.COLORS.muted))
	host.ui_factory.text(map_detail_box, "耗时 %d 日 · 危险 %d" % [int(route.get("duration", 1)), int(route.get("danger", 0))], true, 13)
	if route_status == "available":
		var action = host.game_screen_controller._action_by_id(actions, str(route.get("action_id", "")))
		if not action.is_empty():
			var route_spacer = Control.new()
			route_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			map_detail_box.add_child(route_spacer)
			var move_button = host.ui_factory.button("前往%s · %d 日" % [selected.get("name", "目的地"), int(route.get("duration", 1))], host.action_panel_controller._consider_action.bind(action), false)
			move_button.custom_minimum_size.y = 46
			move_button.tooltip_text = "危险 %d · 途中局势会继续推进" % int(route.get("danger", 0))
			map_detail_box.add_child(move_button)
	elif route_status == "blocked":
		var blockers = host.action_panel_controller._joined_action_values(route.get("blockers", []))
		var blocked_line = host.ui_factory.text(map_detail_box, "路线受阻 · %s" % blockers, false, 13)
		blocked_line.add_theme_color_override("font_color", host.COLORS.danger)


func _render_map_actor_plans(parent: VBoxContainer, actor_plans, location_id: String) -> void:
	var visible: Array = []
	for plan in actor_plans:
		if str(plan.get("location_id", "")) == location_id:
			visible.append(plan)
	if visible.is_empty():
		return
	var separator = HSeparator.new()
	separator.modulate = Color(host.COLORS.accent, 0.28)
	parent.add_child(separator)
	var heading = host.ui_factory.text(parent, "人物动向 · %d" % visible.size(), true, host.TYPE_SCALE.meta)
	heading.add_theme_color_override("font_color", host.COLORS.accent)
	var shared_plan: String = host.game_screen_controller._shared_actor_plan_value(visible, "plan")
	var shared_reason: String = host.game_screen_controller._shared_actor_plan_value(visible, "reason")
	for plan in visible:
		var card = PanelContainer.new()
		card.add_theme_stylebox_override("panel", host.ui_factory.panel_style(Color(host.COLORS.panel_alt, 0.34), 1, 4, Color(host.COLORS.line, 0.34), 12, 10))
		parent.add_child(card)
		var content = VBoxContainer.new()
		content.add_theme_constant_override("separation", 4)
		card.add_child(content)
		var status_line = host.ui_factory.text(content, str(plan.get("status", "观望")), true, host.TYPE_SCALE.meta)
		status_line.add_theme_color_override("font_color", host.COLORS.success if str(plan.get("status", "")) == "行动中" else host.COLORS.muted)
		var name_line = host.ui_factory.text(content, str(plan.get("name", "无名者")), false, host.TYPE_SCALE.body)
		name_line.add_theme_font_override("font", host.medium_font)
		if shared_plan == "":
			host.ui_factory.text(content, str(plan.get("plan", "观察局势")), true, host.TYPE_SCALE.compact)
		if shared_reason == "":
			host.ui_factory.text(content, "缘由 · %s" % plan.get("reason", "尚未公开"), true, host.TYPE_SCALE.meta)
		if str(plan.get("destination_name", "")) != "":
			host.ui_factory.text(content, "去向 · %s · 预计第 %d 日" % [plan.get("destination_name", "未知地点"), int(plan.get("expected_day", 0))], true, host.TYPE_SCALE.meta)
		if bool(plan.get("changed_by_player", false)):
			var changed = host.ui_factory.text(content, "因你改变 · 原本%s" % plan.get("previous_plan", "另有安排"), true, host.TYPE_SCALE.meta)
			changed.add_theme_color_override("font_color", host.COLORS.accent)
	if shared_plan != "":
		host.ui_factory.text(parent, "共同动向 · %s" % shared_plan, true, host.TYPE_SCALE.meta)
	if shared_reason != "":
		host.ui_factory.text(parent, "共同判断 · %s" % shared_reason, true, host.TYPE_SCALE.meta)


func _shared_actor_plan_value(plans: Array, key: String) -> String:
	if plans.size() < 2:
		return ""
	var shared := str(plans[0].get(key, ""))
	if shared == "":
		return ""
	for plan in plans:
		if str(plan.get(key, "")) != shared:
			return ""
	return shared


func _render_location_stage(location: Dictionary, actors: Array, actions: Array) -> void:
	location_stage.set_location(location)
	host.audio_director.set_scene(str(location.get("scene_key", "")))
	host.game_screen_controller._render_actor_portrait(actors)
	host.ui_factory.clear(location_detail_box)
	var phase_marker: String = str(host.presentation_registry.location_stage_label(str(location.get("scene_key", ""))))
	var place_title = "%s" % ["安稳" if bool(location.get("safe", false)) else "险地"]
	if phase_marker != "":
		place_title += " · %s" % phase_marker
	if not actors.is_empty():
		place_title += " · 在场 %d 人" % actors.size()
	var place_line = host.ui_factory.text(location_detail_box, place_title, false, 13)
	place_line.add_theme_color_override("font_color", host.COLORS.accent)
	host.ui_factory.text(location_detail_box, str(location.get("atmosphere", location.get("description", ""))), true, 13)
	host.game_screen_controller._render_stage_people(actors, actions)


func _render_stage_people(actors: Array, actions: Array) -> void:
	host.ui_factory.clear(stage_people_box)
	if actors.is_empty():
		host.ui_factory.text(stage_people_box, "此地暂时无人可交涉", true, 13)
		return
	for index in actors.size():
		var actor: Dictionary = actors[index]
		var actor_id = str(actor.get("id", ""))
		var actor_name = str(actor.get("name", "无名者"))
		var clue_count = host.action_panel_controller._count_tell_actions(actions, actor_id, "")
		var selected = actor_id == host.stage_actor_id
		var button_text = ("◆ " if selected else "") + actor_name
		if clue_count > 0:
			button_text += " · %d 条" % clue_count
		var button = host.ui_factory.action_button(button_text, host.game_screen_controller._focus_actor_from_stage.bind(actor_id, actor_name))
		button.custom_minimum_size = Vector2(132, 36)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = "%s\n%s" % [actor.get("public_role", "可交谈人物"), actor.get("public_profile", "")]
		if selected:
			var profile: ActorVisualProfile = host.presentation_registry.actor_profile(actor_id)
			var actor_accent = profile.accent_color if profile else host.COLORS.accent
			button.add_theme_color_override("font_color", host.COLORS.ink)
			button.add_theme_stylebox_override("normal", host.ui_factory.panel_style(host.COLORS.panel_hover, 1, 6, actor_accent.lerp(host.COLORS.accent, 0.35), 12, 7))
		stage_people_box.add_child(button)


func _render_actor_portrait(actors: Array) -> void:
	var actor = host.game_screen_controller._selected_stage_actor(actors)
	if actor.is_empty():
		actor_portrait_frame.hide()
		actor_portrait.texture = null
		actor_portrait.remove_meta("presentation_key")
		return
	var actor_id = str(actor.get("id", ""))
	host.game_screen_controller._show_actor_portrait(actor, str(host.actor_expression_by_id.get(actor_id, "neutral")))


func _focus_portrait(actor_id: String, expression_override := "") -> void:
	var actor = host.game_screen_controller._actor_by_id(host.current_view.get("known_actors", []), actor_id)
	if actor.is_empty():
		actor = {"id": actor_id, "name": host.stage_actor_name, "public_role": "可交谈人物"}
	host.stage_actor_id = actor_id
	host.stage_actor_name = str(actor.get("name", host.stage_actor_name))
	var expression = expression_override
	if expression == "":
		expression = str(host.actor_expression_by_id.get(actor_id, "alert"))
	host.game_screen_controller._show_actor_portrait(actor, expression)


func _show_actor_portrait(actor: Dictionary, expression: String) -> void:
	var actor_id = str(actor.get("id", ""))
	var profile: ActorVisualProfile = host.presentation_registry.actor_profile(actor_id)
	if profile == null or profile.neutral == null:
		return
	var portrait_texture = profile.portrait(expression)
	if portrait_texture == null:
		return
	var presentation_key := "%s:%s" % [actor_id, expression]
	var should_animate := str(actor_portrait.get_meta("presentation_key", "")) != presentation_key
	actor_portrait.texture = portrait_texture
	actor_portrait.set_meta("presentation_key", presentation_key)
	actor_portrait_name.text = str(actor.get("name", "无名者"))
	var role = str(actor.get("public_role", "可交谈人物"))
	var expression_names = {"neutral": "平静", "alert": "警觉", "troubled": "权衡中", "decisive": "已有决断"}
	var meta_parts: Array[String] = [role]
	if expression != "neutral":
		meta_parts.append(str(expression_names.get(expression, expression)))
	actor_portrait_meta.text = " · ".join(meta_parts)
	actor_portrait_frame.tooltip_text = "%s · %s" % [actor_portrait_name.text, role]
	actor_portrait_frame.add_theme_stylebox_override("panel", host.ui_factory.panel_style(Color.TRANSPARENT, 0, 0, Color.TRANSPARENT, 0, 0))
	actor_portrait_frame.show()
	var target_modulate = Color.WHITE
	match expression:
		"alert":
			target_modulate = Color("f0eadf")
		"troubled":
			target_modulate = Color("cbd3cb")
		"decisive":
			target_modulate = Color("fff0c8")
	actor_portrait.scale = Vector2.ONE
	if host.actor_portrait_tween and host.actor_portrait_tween.is_valid():
		host.actor_portrait_tween.kill()
	if should_animate and host.motion_enabled:
		actor_portrait.modulate = Color(target_modulate, 0.25)
		host.actor_portrait_tween = host.create_tween()
		host.actor_portrait_tween.tween_property(actor_portrait, "modulate", target_modulate, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		actor_portrait.modulate = target_modulate


func _selected_stage_actor(actors: Array) -> Dictionary:
	var selected = host.game_screen_controller._actor_by_id(actors, host.stage_actor_id)
	if not selected.is_empty() and host.presentation_registry.has_actor(host.stage_actor_id):
		return selected
	for actor in actors:
		var actor_id = str(actor.get("id", ""))
		if host.presentation_registry.has_actor(actor_id):
			host.stage_actor_id = actor_id
			host.stage_actor_name = str(actor.get("name", "无名者"))
			return actor
	return {}


func _actor_by_id(actors, actor_id: String) -> Dictionary:
	if not actors is Array:
		return {}
	for actor in actors:
		if str(actor.get("id", "")) == actor_id:
			return actor
	return {}


func _actor_id_by_name(actor_name: String) -> String:
	for actor in host.current_view.get("known_actors", []):
		if str(actor.get("name", "")) == actor_name:
			return str(actor.get("id", ""))
	return ""


func _reconcile_stage_actor(actors: Array) -> void:
	if host.stage_actor_id != "" and not host.game_screen_controller._actor_by_id(actors, host.stage_actor_id).is_empty():
		return
	host.stage_actor_id = ""
	host.stage_actor_name = ""
	host.game_screen_controller._selected_stage_actor(actors)
	actor_portrait_frame.scale = Vector2.ONE
	actor_portrait_frame.modulate = Color.WHITE


func _focus_actor_from_stage(actor_id: String, actor_name: String) -> void:
	host.game_screen_controller._set_visual_mode("location")
	host.audio_director.play_ui()
	host.action_panel_controller._focus_actor_actions(actor_id, actor_name)


func _map_location(locations, location_id: String) -> Dictionary:
	if not locations is Array:
		return {}
	for location in locations:
		if str(location.get("id", "")) == location_id:
			return location
	return {}


func _current_map_route(routes, from_id: String, to_id: String) -> Dictionary:
	if not routes is Array:
		return {}
	for route in routes:
		if str(route.get("from_id", "")) == from_id and str(route.get("to_id", "")) == to_id:
			return route
	return {}


func _action_by_id(actions: Array, action_id: String) -> Dictionary:
	for action in actions:
		if str(action.get("id", "")) == action_id:
			return action
	return {}


func _render_player(player: Dictionary) -> void:
	var state = "空闲"
	if bool(player.get("busy", false)):
		state = "%s · 至第 %d 日" % [str(player.get("busy_action", "行动中")), int(player.get("busy_until", 0))]
	var resources: Dictionary = player.get("resources", {})
	var items: Array = player.get("items", [])
	host.player_summary_label.text = "%s · %s" % [player.get("name", "旅人"), state]
	host.ui_factory.clear(host.player_resources_box)
	var rendered_resources = {}
	for definition in host.scenario_presentation.get("resources", []):
		if not definition is Dictionary:
			continue
		var resource_id = str(definition.get("id", ""))
		if resource_id == "" or not resources.has(resource_id):
			continue
		rendered_resources[resource_id] = true
		var amount = float(resources.get(resource_id, 0))
		if bool(definition.get("hide_zero", false)) and amount == 0.0:
			continue
		host.ui_factory.status_chip(host.player_resources_box, "%s %s" % [definition.get("label", resource_id), host.game_screen_controller._compact_number(amount)], host.game_screen_controller._resource_emphasis_color(str(definition.get("emphasis", "normal"))))
	var extra_resource_ids: Array = resources.keys()
	extra_resource_ids.sort()
	for resource_id in extra_resource_ids:
		if not rendered_resources.has(resource_id):
			host.ui_factory.status_chip(host.player_resources_box, "%s %s" % [host.game_screen_controller._resource_label(str(resource_id)), host.game_screen_controller._compact_number(resources[resource_id])], host.COLORS.ink)
	var injury = int(player.get("injury", 0))
	if injury > 0:
		host.ui_factory.status_chip(host.player_resources_box, "伤势 %d" % injury, host.COLORS.danger)
	for index in range(mini(items.size(), 2)):
		var item: Dictionary = items[index]
		var item_name = str(item.get("name", "物品"))
		host.ui_factory.status_chip(host.player_resources_box, "%s ×%d" % [item_name, int(item.get("amount", 1))], host.COLORS.muted)
	if items.size() > 2:
		host.ui_factory.status_chip(host.player_resources_box, "行囊 %d 种" % items.size(), host.COLORS.muted)


func _compact_number(value: Variant) -> String:
	var numeric = float(value)
	if is_equal_approx(numeric, round(numeric)):
		return str(int(round(numeric)))
	return "%.1f" % numeric


func _resource_label(resource_id: String) -> String:
	for definition in host.scenario_presentation.get("resources", []):
		if definition is Dictionary and str(definition.get("id", "")) == resource_id:
			return str(definition.get("label", resource_id))
	return resource_id


func _resource_emphasis_color(emphasis: String) -> Color:
	match emphasis:
		"accent":
			return host.COLORS.accent
		"success":
			return host.COLORS.success
	return host.COLORS.ink


func _known_timing(clues: Array) -> String:
	var best: Dictionary = {}
	var configured_keyword: String = str(host._ui_text("timing_keyword"))
	for clue in clues:
		if configured_keyword != "" and configured_keyword not in str(clue.get("claim", "")):
			continue
		if best.is_empty() or int(clue.get("confidence", 0)) > int(best.get("confidence", 0)):
			best = clue
	if best.is_empty():
		return "尚未查明"
	var timing := str(best.get("claim", "未知"))
	var timing_start := timing.find("第")
	var timing_keyword: String = str(host._ui_text("timing_keyword"))
	var timing_end := timing.find(timing_keyword, timing_start + 1) if timing_start >= 0 and timing_keyword != "" else -1
	if timing_start >= 0 and timing_end > timing_start:
		timing = timing.substr(timing_start, timing_end - timing_start)
	var confidence := int(best.get("confidence", 0))
	var status: String = str(host._ui_text("timing_status_confirmed") if confidence >= 3 else (host._ui_text("timing_status_plausible") if confidence == 2 else host._ui_text("timing_status_rumored")))
	return "%s · %s" % [timing, status]


func _phase_display(phase: String) -> String:
	var configured: String = host._ui_text("phase_" + phase) if host.scenario_presentation.get("ui", {}).has("phase_" + phase) else host._ui_text("phase_default")
	return configured


func _header_day(day: int, duration: int) -> String:
	return "◷ %d / %d" % [maxi(1, day), duration]


func _header_place(place_name: String) -> String:
	return "◆ %s" % place_name


func _header_phase_label(phase_name: String) -> String:
	return "◌ %s" % phase_name.trim_suffix("期")
