extends Control

const RuntimeLoggerScript = preload("res://scripts/runtime_logger.gd")
const DisplaySettingsScript = preload("res://scripts/display_settings.gd")
const StartSettingsScreenScript = preload("res://scripts/start_settings_screen.gd")
const GameScreenScript = preload("res://scripts/game_screen.gd")
const JournalPanelScript = preload("res://scripts/journal_panel.gd")
const ActionPanelScript = preload("res://scripts/action_panel.gd")
const DialoguePanelScript = preload("res://scripts/dialogue_panel.gd")
const PresentationControllerScript = preload("res://scripts/presentation_controller.gd")

const WorldMapViewScript = preload("res://scripts/world_map.gd")
const LocationStageScript = preload("res://scripts/location_stage.gd")
const PresentationDirectorScript = preload("res://scripts/presentation_director.gd")
const PresentationRegistryScript = preload("res://scripts/presentation_registry.gd")
const AudioDirectorScript = preload("res://scripts/audio_director.gd")
const CinematicDirectorScript = preload("res://scripts/cinematic_director.gd")
const CausalSealTexture = preload("res://assets/ui/causal/causal-seal.png")
const DecisionFrameTexture = preload("res://assets/ui/causal/decision-frame.png")
const TimelineArrowTexture = preload("res://assets/ui/causal/timeline-arrow.png")
const StartBackgroundTexture = preload("res://assets/locations/market/background.png")
const SourceHanSansFont = preload("res://assets/fonts/SourceHanSansCN-Regular.otf")
const SourceHanSansMediumFont = preload("res://assets/fonts/SourceHanSansCN-Medium.otf")
const SourceHanSerifFont = preload("res://assets/fonts/SourceHanSerifCN-SemiBold.otf")
const WenKaiFont = preload("res://assets/fonts/LXGWWenKaiLite-Regular.ttf")
const AIDialogueClientScript = preload("res://scripts/ai/dialogue_client.gd")
const APIResponseAdapterScript = preload("res://scripts/api_response_adapter.gd")
const LocalServerProcessScript = preload("res://scripts/local_server_process.gd")
const SettingsStoreScript = preload("res://scripts/settings_store.gd")
const GameClientScript = preload("res://scripts/game_client.gd")
const GameViewModelScript = preload("res://scripts/game_view_model.gd")
const DiagnosticsExporterScript = preload("res://scripts/diagnostics_exporter.gd")
const API_BASE := "http://127.0.0.1:8787/api/v1"
const AUTOSAVE_SLOT := "autosave"
const AI_SETTINGS_FILE := "ai-settings.json"
const BUNDLED_SERVER_STARTUP_DELAY := 0.4
const PORTABLE_USER_ARG := "--portable"
const SCENARIO_ARG_PREFIX := "--scenario="
const DATA_DIR_ARG_PREFIX := "--data-dir="
const RECORDING_OUTPUT_ARG_PREFIX := "--recording-output="
const LOG_MAX_MIB := 5
const LOG_BACKUPS := 5
const LOG_LEVELS: Array[String] = ["DEBUG", "INFO", "WARN", "ERROR"]
const LOG_LEVEL_RANK := {"DEBUG": 0, "INFO": 1, "WARN": 2, "ERROR": 3}
const DISPLAY_MODE_KEYS: Array[String] = ["windowed", "borderless", "exclusive"]
const DISPLAY_MODE_LABELS := {
	"windowed": "窗口",
	"borderless": "无边框全屏",
	"exclusive": "独占全屏",
}
const DISPLAY_RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1280, 800),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
const UI_SCALE_PRESETS: Array[float] = [1.0, 1.25, 1.5, 1.75]
const MINIMUM_UI_CANVAS := Vector2i(1100, 700)
const MIN_READABLE_TEXT_SIZE := 14
const DIAGNOSTIC_FILE_MAX_BYTES := 25 * 1024 * 1024
const TYPE_SCALE := {
	"display": 60,
	"brand": 28,
	"title": 28,
	"headline": 22,
	"section": 20,
	"metric": 18,
	"body": 17,
	"compact": 15,
	"detail": 14,
	"meta": 14,
	"caption": 14,
	"button": 16,
}
const COLORS := {
	"bg": Color("090c0a"),
	"bg_lift": Color("101712"),
	"panel": Color("121713"),
	"panel_alt": Color("1a231d"),
	"panel_hover": Color("232e26"),
	"line": Color("344039"),
	"line_soft": Color("242e28"),
	"ink": Color("f2ebdd"),
	"muted": Color("a9b3a6"),
	"accent": Color("d6ae62"),
	"accent_hover": Color("e4c079"),
	"accent_pressed": Color("b98e47"),
	"accent_ink": Color("15110a"),
	"danger": Color("c46352"),
	"danger_deep": Color("8f352c"),
	"success": Color("82aa78"),
}


var runtime_logger_controller
var display_settings_controller
var start_settings_screen_controller
var game_screen_controller
var journal_panel_controller
var action_panel_controller
var dialogue_panel_controller
var presentation_controller

var current_view: Dictionary = {}
var scenario_info: Dictionary = {}
var scenario_presentation: Dictionary = {}
var interface_built := false
var dialogue_client
var api_response_adapter = APIResponseAdapterScript.new()
var local_server_process
var settings_store = SettingsStoreScript.new()
var game_client
var view_model = GameViewModelScript.new()
var diagnostics_exporter = DiagnosticsExporterScript.new()
var actor_dialogue_by_id := {}
var actor_dialogue_error_by_id := {}
var actor_dialogue_history_by_id := {}
var actor_dialogue_loading_id := ""
var pending_operation := ""
var autosave_after_action := false
var selected_action: Dictionary = {}
var selected_followup_action_id := ""
var queued_followup_action_id := ""
var available_actions_cache: Array = []
var focused_actor_id := ""
var focused_actor_name := ""
var focused_actor_action_id := ""
var focused_fact_id := ""
var focused_fact_claim := ""
var stage_actor_id := ""
var stage_actor_name := ""
var actor_expression_by_id := {}
var actor_portrait_tween: Tween
var selected_map_location_id := ""
var rendered_location_id := ""
var visual_mode := "map"
var view_before_action: Dictionary = {}
var presentation_registry = PresentationRegistryScript.new()
var sound_enabled := true
var motion_enabled := true
var display_mode := "windowed"
var display_resolution := Vector2i(1600, 900)
var ui_scale := 1.0
var recording_output_size := Vector2i.ZERO
var ai_enabled := false
var ai_server_enabled := false
var ai_server_mode := "disabled"
var ai_model := "step-3.7-flash"
var ai_base_url := "https://api.stepfun.com/step_plan/v1/messages"
var ai_api_key := ""
var presentation_busy := false
var opening_cinematic_active := false
var ending_cinematic_presented := false
var active_action_category := ""
var show_all_actions := false
var focused_actor_details_visible := false
var causal_change_count_by_actor := {}
var causal_actor_id_by_name := {}
var last_causal_actor_id := ""
var journal_feedback_details_visible := false
var journal_travel_details_visible := false
var journal_seen_feedback_signature := ""
var journal_current_feedback_signature := ""
var journal_tab_labels: Array[String] = ["回响", "线索", "人物", "行装"]
var journal_tab_colors: Array[Color] = [COLORS.muted, COLORS.muted, COLORS.muted, COLORS.muted]
var runtime_root := ""
var logs_dir := ""
var archived_logs_dir := ""
var saves_dir := ""
var crash_dir := ""
var client_log_path := ""
var portable_mode := false
var scenario_selector := ""
var scenario_data_dir := ""
var session_id := ""
var shutdown_token := ""
var build_version := "dev"
var pending_request_path := ""
var pending_request_method := ""
var request_started_msec := 0
var shutdown_in_progress := false
var log_level := "INFO"
var runtime_warning := ""
var recovery_log_path := ""
var session_marker_path := ""
var build_info: Dictionary = {}
var last_server_http_status := 0
var client_log_failure_reported := false

var start_layer: Control
var start_scene: TextureRect
var start_vignette: TextureRect
var start_seal: TextureRect
var game_layer: Control
var header_brand_label: Label
var header_world_title_label: Label
var start_eyebrow_label: Label
var start_title_label: Label
var start_intro_label: Label
var start_begin_button: Button
var name_input: LineEdit
var connection_label: Label
var retry_button: Button
var day_label: Label
var place_label: Label
var phase_label: Label
var timing_label: Label
var objective_label: Label
var player_summary_label: Label
var player_resources_box: HFlowContainer
var journal_tabs: TabContainer
var journal_echo_button: Button
var journal_clues_button: Button
var journal_people_button: Button
var journal_travel_button: Button
var clues_box: VBoxContainer
var scene_box: VBoxContainer
var people_box: VBoxContainer
var travel_box: VBoxContainer
var journal_feedback_details_box: VBoxContainer
var journal_feedback_details_button: Button
var journal_travel_details_box: VBoxContainer
var journal_travel_details_button: Button
var actions_box: VBoxContainer
var overview_actions_box: VBoxContainer
var fact_action_scroll: ScrollContainer
var actor_focus_workspace: HBoxContainer
var actor_focus_message_list: VBoxContainer
var actor_focus_detail_scroll: ScrollContainer
var actor_focus_detail_box: VBoxContainer
var actor_focus_footer: HBoxContainer
var action_canvas: CanvasLayer
var action_dock_host: Control
var action_dock: PanelContainer
var action_dock_title: Label
var footer_label: Label
var journal_layer: Control
var journal_panel: PanelContainer
var journal_paper: TextureRect
var ending_layer: Control
var ending_box: VBoxContainer
var ending_background: TextureRect
var ending_portrait: TextureRect
var ending_seal: TextureRect
var ending_annex_box: VBoxContainer
var ending_annex_button: Button
var causal_layer: Control
var causal_background: TextureRect
var causal_portrait: TextureRect
var causal_message: Label
var causal_actor_meta: Label
var causal_original: Label
var causal_now: Label
var causal_day: Label
var confirmation_layer: Control
var confirmation_box: VBoxContainer
var confirmation_actions_box: HBoxContainer
var confirmation_details_box: VBoxContainer
var confirmation_details_button: Button
var visual_stack: Control
var map_panel: HBoxContainer
var location_panel: VBoxContainer
var map_detail_box: VBoxContainer
var location_detail_box: VBoxContainer
var stage_people_box: HFlowContainer
var map_mode_button: Button
var location_mode_button: Button
var world_map_view: Control
var location_stage: Control
var presentation_director: Control
var audio_director: Node
var cinematic_director: Control
var actor_portrait_frame: PanelContainer
var actor_portrait: TextureRect
var actor_portrait_name: Label
var actor_portrait_meta: Label
var sound_button: Button
var motion_button: Button
var settings_layer: Control
var settings_box: VBoxContainer
var log_level_button: Button
var display_mode_option: OptionButton
var display_resolution_option: OptionButton
var ui_scale_option: OptionButton
var display_status_label: Label
var ai_enabled_check: CheckButton
var ai_model_input: LineEdit
var ai_base_url_input: LineEdit
var ai_api_key_input: LineEdit
var ai_status_label: Label
var body_font: Font
var medium_font: Font
var display_font: Font
var narrative_font: Font


func _initialize_responsibility_controllers() -> void:
	runtime_logger_controller = RuntimeLoggerScript.new(self)
	display_settings_controller = DisplaySettingsScript.new(self)
	start_settings_screen_controller = StartSettingsScreenScript.new(self)
	game_screen_controller = GameScreenScript.new(self)
	journal_panel_controller = JournalPanelScript.new(self)
	action_panel_controller = ActionPanelScript.new(self)
	dialogue_panel_controller = DialoguePanelScript.new(self)
	presentation_controller = PresentationControllerScript.new(self)



func _ready() -> void:
	_initialize_responsibility_controllers()
	_configure_scenario_selection()
	runtime_logger_controller._configure_runtime_paths()
	runtime_logger_controller._configure_runtime_identity()
	runtime_logger_controller._initialize_crash_tracking()
	local_server_process = LocalServerProcessScript.new()
	add_child(local_server_process)
	local_server_process.log_event.connect(runtime_logger_controller._log_event)
	diagnostics_exporter.log_event.connect(runtime_logger_controller._log_event)
	get_tree().auto_accept_quit = false
	runtime_logger_controller._log_event("INFO", "startup", "client starting", {
		"pid": OS.get_process_id(),
		"os": OS.get_name(),
		"portable": portable_mode,
	})
	game_screen_controller._configure_theme()
	display_settings_controller._apply_display_settings(false)
	audio_director = AudioDirectorScript.new()
	add_child(audio_director)
	dialogue_client = AIDialogueClientScript.new()
	add_child(dialogue_client)
	dialogue_client.dialogue_ready.connect(dialogue_panel_controller._on_ai_dialogue_ready)
	dialogue_client.dialogue_failed.connect(dialogue_panel_controller._on_ai_dialogue_failed)
	game_client = GameClientScript.new(API_BASE)
	add_child(game_client)
	game_client.request_completed.connect(_on_request_completed)
	cinematic_director = CinematicDirectorScript.new()
	add_child(cinematic_director)
	cinematic_director.set_enabled(motion_enabled)
	if runtime_warning != "":
		_show_error(runtime_warning)
	local_server_process.start({
		"scenario": scenario_selector,
		"data_dir": scenario_data_dir,
		"runtime_root": runtime_root,
		"logs_dir": logs_dir,
		"saves_dir": saves_dir,
		"crash_dir": crash_dir,
		"log_max_mib": LOG_MAX_MIB,
		"log_backups": LOG_BACKUPS,
		"log_level": log_level,
		"build_version": build_version,
		"session_id": session_id,
		"shutdown_token": shutdown_token,
		"ai_settings_file": AI_SETTINGS_FILE,
	})
	if local_server_process.pid > 0:
		await get_tree().create_timer(BUNDLED_SERVER_STARTUP_DELAY).timeout
	_request("health", HTTPClient.METHOD_GET, "/health")


func _exit_tree() -> void:
	if local_server_process != null:
		local_server_process.force_stop()
	runtime_logger_controller._log_event("INFO", "stopped", "client stopped")
	runtime_logger_controller._clear_crash_marker()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_begin_graceful_shutdown()


func _begin_graceful_shutdown() -> void:
	if shutdown_in_progress:
		return
	shutdown_in_progress = true
	runtime_logger_controller._log_event("INFO", "shutdown_requested", "window close requested")
	if local_server_process == null or local_server_process.pid <= 0:
		get_tree().quit()
		return
	await local_server_process.shutdown(API_BASE, shutdown_token)
	get_tree().quit()


func _configure_scenario_selection() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(SCENARIO_ARG_PREFIX):
			var requested := argument.trim_prefix(SCENARIO_ARG_PREFIX).strip_edges()
			if requested != "" and requested.get_file() == requested and requested not in [".", ".."]:
				scenario_selector = requested
		elif argument.begins_with(DATA_DIR_ARG_PREFIX):
			scenario_data_dir = argument.trim_prefix(DATA_DIR_ARG_PREFIX).strip_edges().simplify_path()
		elif argument.begins_with(RECORDING_OUTPUT_ARG_PREFIX):
			var dimensions := argument.trim_prefix(RECORDING_OUTPUT_ARG_PREFIX).to_lower().split("x", false, 1)
			if dimensions.size() == 2 and dimensions[0].is_valid_int() and dimensions[1].is_valid_int():
				var requested_size := Vector2i(int(dimensions[0]), int(dimensions[1]))
				if requested_size.x > 0 and requested_size.y > 0:
					recording_output_size = requested_size
					display_resolution = requested_size
					ui_scale = 1.0


func _operation_label(operation: String) -> String:
	var labels := {
		"health": "正在连接规则服务",
		"new": "正在进入当前世界",
		"load": "正在读取旅程",
		"save": "正在保存",
		"autosave": "正在自动保存",
		"action": "正在推演行动结果",
		"quit": "正在返回",
		"ai_settings": "正在应用大模型配置",
	}
	return str(labels.get(operation, "处理中"))


func _request(operation: String, method: HTTPClient.Method, path: String, payload := {}) -> void:
	if pending_operation != "" or operation == "action" and presentation_busy:
		return
	pending_operation = operation
	pending_request_path = path
	pending_request_method = _http_method_name(method)
	request_started_msec = Time.get_ticks_msec()
	runtime_logger_controller._log_event("INFO", "http_request", "request started", {
		"method": pending_request_method,
		"operation": operation,
		"path": path,
	})
	game_screen_controller._set_buttons_disabled(self, true)
	if action_dock and action_dock.visible:
		action_dock_title.text = _operation_label(operation) + "…"
	if footer_label:
		footer_label.text = "◆  " + _operation_label(operation) + "…"
		footer_label.add_theme_color_override("font_color", COLORS.accent)
	if start_layer and start_layer.visible and connection_label:
		connection_label.text = "正在确认旅途入口…"
	var error: Error = game_client.send(method, path, payload)
	if error != OK:
		runtime_logger_controller._log_event("ERROR", "http_send_failed", "request could not be sent", {
			"error": error,
			"method": pending_request_method,
			"operation": operation,
			"path": path,
		})
		pending_operation = ""
		pending_request_path = ""
		pending_request_method = ""
		game_screen_controller._set_buttons_disabled(self, false)
		_show_error("无法发送请求（%s）" % error)


func _http_method_name(method: HTTPClient.Method) -> String:
	match method:
		HTTPClient.METHOD_GET:
			return "GET"
		HTTPClient.METHOD_POST:
			return "POST"
		HTTPClient.METHOD_PUT:
			return "PUT"
		HTTPClient.METHOD_DELETE:
			return "DELETE"
		_:
			return str(method)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	last_server_http_status = response_code
	var operation := pending_operation
	var request_path := pending_request_path
	var request_method := pending_request_method
	var duration_msec := maxi(0, Time.get_ticks_msec() - request_started_msec)
	pending_operation = ""
	pending_request_path = ""
	pending_request_method = ""
	game_screen_controller._set_buttons_disabled(self, presentation_busy)
	var adapted: Dictionary = api_response_adapter.decode(response_code, body)
	var parsed: Dictionary = adapted.get("payload", {})
	var error_code := str(adapted.get("error_code", ""))
	runtime_logger_controller._log_event("INFO" if response_code >= 200 and response_code < 300 else "ERROR", "http_response", "request completed", {
		"duration_ms": duration_msec,
		"error_code": error_code,
		"method": request_method,
		"operation": operation,
		"path": request_path,
		"result": result,
		"status": response_code,
	})
	if not adapted.get("ok", false):
		queued_followup_action_id = ""
		var message := str(adapted.get("message", "本地服务无响应，请先运行项目启动脚本。"))
		if operation == "ai_settings" and ai_status_label:
			ai_status_label.text = "应用失败：%s" % message
			ai_status_label.add_theme_color_override("font_color", COLORS.danger)
		_show_error(message)
		return

	if connection_label:
		connection_label.text = ""
		connection_label.add_theme_color_override("font_color", COLORS.success)
		retry_button.hide()
	if operation == "health":
		_apply_scenario_info(parsed.get("scenario", {}))
		if not interface_built:
			game_screen_controller._build_interface()
			interface_built = true
			_apply_scenario_info(parsed.get("scenario", {}))
		var capabilities: Dictionary = parsed.get("capabilities", {})
		ai_server_enabled = bool(capabilities.get("ai_dialogue", false))
		var server_ai_settings: Dictionary = parsed.get("ai_settings", {})
		ai_server_mode = str(server_ai_settings.get("mode", "disabled"))
		start_settings_screen_controller._refresh_ai_settings_status()
		if footer_label:
			footer_label.text = ""
		return
	if operation == "ai_settings":
		var ai_capabilities: Dictionary = parsed.get("capabilities", {})
		ai_server_enabled = bool(ai_capabilities.get("ai_dialogue", false))
		var applied_ai_settings: Dictionary = parsed.get("ai_settings", {})
		ai_server_mode = str(applied_ai_settings.get("mode", "disabled"))
		var save_error: Error = display_settings_controller._save_ai_settings()
		if save_error != OK:
			ai_status_label.text = "模型已应用，但本地配置保存失败（%s）" % save_error
			ai_status_label.add_theme_color_override("font_color", COLORS.danger)
			return
		start_settings_screen_controller._refresh_ai_settings_status("配置已保存并立即生效")
		return
	if operation == "quit":
		_show_start()
		return
	if parsed.has("view") and operation not in ["autosave", "save"]:
		var previous_view := view_before_action if operation == "action" else current_view
		current_view = view_model.accept(parsed["view"], operation == "action")
		_apply_scenario_presentation(current_view.get("presentation", {}))
		if operation == "action":
			presentation_controller._apply_feedback_actor_state(current_view.get("last_turn", {}))
		_show_game()
		game_screen_controller._render_view()
		if operation == "action":
			presentation_controller._play_action_presentation(previous_view, current_view)
		view_before_action = {}
	if operation == "action" and autosave_after_action:
		autosave_after_action = false
		_request("autosave", HTTPClient.METHOD_POST, "/game/save", {"slot": AUTOSAVE_SLOT})
	elif operation == "autosave":
		if _continue_queued_followup():
			return
		_show_footer_message("已自动保存")
		action_panel_controller._render_actions(available_actions_cache)
	elif operation == "save":
		_show_footer_message("存档已保存")
		action_panel_controller._render_actions(available_actions_cache)
	else:
		footer_label.text = ""


func _apply_scenario_info(value: Variant) -> void:
	if not value is Dictionary:
		return
	scenario_info = value.duplicate(true)
	_apply_scenario_presentation(scenario_info.get("presentation", {}))
	var title := str(scenario_info.get("title", ""))
	if start_eyebrow_label:
		start_eyebrow_label.text = _start_eyebrow_text(title)


func _start_eyebrow_text(scenario_title: String) -> String:
	if scenario_title == "":
		return str(scenario_info.get("id", "场景内容"))
	var brand := str(scenario_presentation.get("brand", "")).strip_edges()
	for separator: String in ["：", ":"]:
		var prefix: String = brand + separator
		if brand != "" and scenario_title.begins_with(prefix):
			return scenario_title.trim_prefix(prefix).strip_edges()
	return scenario_title


func _apply_scenario_presentation(value: Variant) -> void:
	if not value is Dictionary or value.is_empty():
		return
	scenario_presentation = value.duplicate(true)
	journal_tab_labels[1] = _ui_text("term_clues")
	presentation_registry.configure(scenario_presentation)
	audio_director.configure_locations(scenario_presentation.get("locations", {}))
	if audio_director:
		audio_director.configure_music(presentation_registry.background_music(), presentation_registry.music_volume_db())
	if start_scene:
		var opening_key := str(scenario_presentation.get("opening_event", ""))
		var opening_texture: Texture2D = presentation_registry.event_texture(opening_key) if opening_key != "" else null
		start_scene.texture = opening_texture if opening_texture else StartBackgroundTexture
	if start_vignette:
		start_vignette.texture = presentation_registry.ui_texture("ink_vignette")
		start_vignette.visible = start_vignette.texture != null
	if start_seal:
		start_seal.texture = presentation_registry.ui_texture("title_seal")
		start_seal.visible = start_seal.texture != null
	if journal_paper:
		journal_paper.texture = presentation_registry.ui_texture("archive_paper")
		journal_paper.visible = journal_paper.texture != null
	if ending_seal:
		var scenario_seal: Texture2D = presentation_registry.ui_texture("title_seal")
		ending_seal.texture = scenario_seal if scenario_seal else CausalSealTexture
	if location_stage:
		location_stage.registry = presentation_registry
	if header_brand_label:
		header_brand_label.text = str(scenario_presentation.get("brand", "游戏"))
	if header_world_title_label:
		var world_title := str(scenario_presentation.get("world_title", ""))
		header_world_title_label.text = ("·  " + world_title) if world_title != "" else ""
	if start_title_label:
		start_title_label.text = str(scenario_presentation.get("brand", "游戏"))
	if start_intro_label:
		start_intro_label.text = str(scenario_presentation.get("intro", scenario_presentation.get("objective", "开始一段新的故事。")))
	if start_begin_button:
		start_begin_button.text = str(scenario_presentation.get("start_action", "开始新故事"))


func _show_footer_message(message: String) -> void:
	footer_label.text = message
	footer_label.add_theme_color_override("font_color", COLORS.muted)
	presentation_controller._clear_footer_message_later(message)


func _ui_text(key: String) -> String:
	var ui: Dictionary = scenario_presentation.get("ui", {})
	var value := str(ui.get(key, "")).strip_edges()
	if value == "":
		push_error("Missing required presentation UI text: %s" % key)
	return value


func _new_game() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name == "":
		player_name = _ui_text("default_player_name")
	actor_expression_by_id.clear()
	causal_change_count_by_actor.clear()
	causal_actor_id_by_name.clear()
	last_causal_actor_id = ""
	journal_seen_feedback_signature = ""
	journal_current_feedback_signature = ""
	journal_feedback_details_visible = false
	journal_travel_details_visible = false
	active_action_category = ""
	selected_followup_action_id = ""
	queued_followup_action_id = ""
	ending_cinematic_presented = false
	action_panel_controller._reset_action_focus()
	ending_layer.hide()
	game_screen_controller._set_visual_mode("location")
	var opening_event_key := str(scenario_presentation.get("opening_event", ""))
	var opening_video: VideoStream = presentation_registry.event_video(opening_event_key) if opening_event_key != "" else null
	opening_cinematic_active = cinematic_director != null and cinematic_director.play(opening_video, opening_event_key, _on_opening_cinematic_finished)
	_request("new", HTTPClient.METHOD_POST, "/game/new", {"player_name": player_name})


func _on_opening_cinematic_finished(_skipped: bool) -> void:
	opening_cinematic_active = false
	game_screen_controller._sync_action_canvas_visibility()
	if game_layer.visible:
		audio_director.play_music()


func _retry_connection() -> void:
	connection_label.text = "正在重新确认旅途入口…"
	connection_label.add_theme_color_override("font_color", COLORS.muted)
	_request("health", HTTPClient.METHOD_GET, "/health")


func _load_game() -> void:
	game_screen_controller._set_visual_mode("map")
	_request("load", HTTPClient.METHOD_POST, "/game/load", {"slot": AUTOSAVE_SLOT})


func _save_game() -> void:
	_request("save", HTTPClient.METHOD_POST, "/game/save", {"slot": AUTOSAVE_SLOT})


func _return_to_start() -> void:
	_request("quit", HTTPClient.METHOD_POST, "/game/quit")


func _restart_from_ending() -> void:
	_new_game()


func _execute_action(action_id: String, followup_action_id := "") -> void:
	view_before_action = current_view.duplicate(true)
	autosave_after_action = true
	queued_followup_action_id = followup_action_id
	_request("action", HTTPClient.METHOD_POST, "/game/action", {"action_id": action_id})


func _continue_queued_followup() -> bool:
	if queued_followup_action_id == "":
		return false
	var followup_id := queued_followup_action_id
	queued_followup_action_id = ""
	if game_screen_controller._action_by_id(available_actions_cache, followup_id).is_empty():
		_show_footer_message("局势提前变化，已停下等待你的判断")
		action_panel_controller._render_actions(available_actions_cache)
		return true
	footer_label.text = "继续推进到这一阶段结束…"
	footer_label.add_theme_color_override("font_color", COLORS.accent)
	_execute_action(followup_id)
	return true


func _show_start() -> void:
	current_view = {}
	selected_action = {}
	selected_followup_action_id = ""
	queued_followup_action_id = ""
	available_actions_cache = []
	selected_map_location_id = ""
	rendered_location_id = ""
	view_before_action = {}
	presentation_busy = false
	opening_cinematic_active = false
	ending_cinematic_presented = false
	causal_change_count_by_actor.clear()
	causal_actor_id_by_name.clear()
	last_causal_actor_id = ""
	active_action_category = ""
	action_panel_controller._reset_action_focus()
	game_layer.hide()
	journal_layer.hide()
	confirmation_layer.hide()
	settings_layer.hide()
	causal_layer.hide()
	ending_layer.hide()
	if cinematic_director and cinematic_director.active:
		cinematic_director.skip()
	audio_director.stop_music(0.8)
	if presentation_director:
		presentation_director.cancel()
	start_layer.show()
	game_screen_controller._sync_action_canvas_visibility()


func _show_game() -> void:
	start_layer.hide()
	game_layer.show()
	if not opening_cinematic_active:
		audio_director.play_music()
	game_screen_controller._sync_action_canvas_visibility()


func _show_error(message: String) -> void:
	if start_layer.visible:
		connection_label.text = message
		connection_label.add_theme_color_override("font_color", COLORS.danger)
		retry_button.show()
	else:
		footer_label.text = message
		footer_label.add_theme_color_override("font_color", COLORS.danger)
