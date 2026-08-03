extends SceneTree

var app


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if not await _wait_until_idle():
		return _fail("tianqi health request timed out")
	if app.scenario_info.get("id", "") != "tianqi_t00":
		return _fail("client did not connect to the selected tianqi scenario")
	if app.header_brand_label.text != "天变邸抄":
		return _fail("scenario brand was not applied to the header")
	if app.start_title_label.text != "天变邸抄":
		return _fail("scenario brand was not applied to the start screen")
	if app.start_begin_button.text != "从王恭厂外街开始记录":
		return _fail("scenario start action was not applied")
	if "灾变之后" not in app.start_intro_label.text:
		return _fail("scenario introduction was not applied")
	if app.scenario_presentation.get("asset_root", "") != "res://assets/tianqi":
		return _fail("tianqi asset root was not applied")
	if app.start_scene.texture == null or "opening-blast.png" not in app.start_scene.texture.resource_path:
		return _fail("tianqi opening illustration was not auto-loaded")
	if app.start_seal.texture == null or app.start_vignette.texture == null or app.journal_paper.texture == null:
		return _fail("tianqi UI textures were not auto-loaded")
	if app.presentation_registry.terrain_texture() == null or "district-map.png" not in app.presentation_registry.terrain_texture().resource_path:
		return _fail("tianqi district map was not auto-loaded")
	for scene_key in ["disaster_street", "apothecary", "inquiry_office", "archive", "warehouse", "study"]:
		var location_profile = app.presentation_registry.location_profile(scene_key)
		if location_profile == null or location_profile.background == null:
			return _fail("missing auto-loaded tianqi location: " + scene_key)
	for actor_id in ["N01", "N02", "N03", "N04", "N05", "N06", "N07", "N08", "N09", "N10"]:
		var actor_profile = app.presentation_registry.actor_profile(actor_id)
		if actor_profile == null or actor_profile.portrait("neutral") == null:
			return _fail("missing auto-loaded tianqi actor: " + actor_id)
	if app.presentation_registry.location_count() != 6 or app.presentation_registry.actor_count() != 10:
		return _fail("auto-loaded tianqi asset counts are invalid")
	if app.presentation_registry.actor_profile("N01").portrait("alert") == app.presentation_registry.actor_profile("N01").portrait("neutral"):
		return _fail("core tianqi expression variant was not auto-loaded")
	if app.presentation_registry.actor_profile("N04").portrait("alert") != app.presentation_registry.actor_profile("N04").portrait("neutral"):
		return _fail("missing tianqi expression did not fall back to neutral")
	for fact_id in ["F01", "F02", "F03", "F04", "F05", "F06", "F07", "F08", "F09", "F10"]:
		if app.presentation_registry.fact_texture(fact_id) == null:
			return _fail("missing auto-loaded tianqi evidence: " + fact_id)
	if app.presentation_registry.event_texture_for_action("route:e01:keep-original") == null:
		return _fail("three-claims event cue was not auto-loaded")
	if app.presentation_registry.event_texture_for_action("route:e09:format-check") == null:
		return _fail("forged-ledger event cue was not auto-loaded")
	var opening_video: VideoStream = app.presentation_registry.event_video("opening-blast")
	var ending_video: VideoStream = app.presentation_registry.event_video("final-verdict")
	if opening_video == null or "opening-blast.ogv" not in opening_video.resource_path:
		return _fail("tianqi opening video was not auto-loaded")
	if ending_video == null or "final-verdict.ogv" not in ending_video.resource_path:
		return _fail("tianqi ending video was not auto-loaded")
	var music: AudioStream = app.presentation_registry.background_music()
	if music == null or "tianqi-investigation-theme-loop.ogg" not in music.resource_path:
		return _fail("tianqi background music was not auto-loaded")
	if app.audio_director.music_player.stream != music or app.audio_director.music_target_db != -10.0:
		return _fail("tianqi background music was not configured on the music bus")
	if app.cinematic_director.video_player == null or app.cinematic_director.skip_button == null:
		return _fail("cinematic playback overlay was not initialized")
	if app.actor_portrait.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		return _fail("stage portrait still crops the actor's head")
	if app.causal_portrait.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED or app.ending_portrait.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		return _fail("overlay portraits still crop the actor's head")

	app.name_input.text = "切换测试抄手"
	app._new_game()
	if not await _wait_until_idle():
		return _fail("tianqi new game request timed out")
	if app.current_view.get("scenario_id", "") != "tianqi_t00":
		return _fail("new game returned the wrong scenario")
	if app.current_view.get("presentation", {}).get("world_title", "") != "京师灾变与会勘":
		return _fail("player view did not carry tianqi presentation metadata")
	var internal_story_id_pattern := RegEx.new()
	internal_story_id_pattern.compile("(^|[^A-Za-z0-9_])[EFN][0-9]{2}([^A-Za-z0-9_]|$)")
	var leaked_story_id := internal_story_id_pattern.search(_descendant_text(app))
	if leaked_story_id != null:
		return _fail("internal story id leaked into player-visible text: " + leaked_story_id.get_string())
	var resource_text := _descendant_text(app.player_resources_box)
	for expected in ["权势", "证据", "盟援"]:
		if expected not in resource_text:
			return _fail("resource presentation is missing: " + expected)
	for forbidden in ["战力", "灵石", "助力", "解瘴丹", "黑风谷"]:
		if forbidden in resource_text:
			return _fail("blackwind content leaked into tianqi resources: " + forbidden)
	app.game_screen_controller._set_visual_mode("map")
	for location in app.current_view.get("world_map", {}).get("locations", []):
		if bool(location.get("contest", false)):
			app.game_screen_controller._on_map_location_selected(str(location.get("id", "")))
			break
	var map_text := _descendant_text(app.map_detail_box)
	if "第十四日前，决定哪些材料进入会勘定稿" not in map_text:
		return _fail("scenario objective was not applied to the world map")
	if app.world_map_view.locations.size() != 7:
		return _fail("tianqi world map did not render all seven locations")

	var actions: Array = app.current_view.get("available_actions", [])
	if actions.is_empty():
		return _fail("tianqi new game returned no actions")
	var action_id := str(actions[0].get("id", ""))
	app._execute_action(action_id)
	if not await _wait_until_idle():
		return _fail("tianqi action or autosave timed out")
	if app.current_view.get("last_turn", null) == null:
		return _fail("tianqi action returned no turn feedback")
	print("Scenario switch smoke test passed: %s via %s" % [app.current_view.get("scenario_id", ""), action_id])
	quit(0)


func _wait_until_idle(timeout_ms := 10000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if app.pending_operation == "" and not app.presentation_busy:
			await process_frame
			if app.pending_operation == "" and not app.presentation_busy:
				return true
	return false


func _descendant_text(node: Node) -> String:
	var result := ""
	if node is Label or node is Button:
		result += str(node.text) + "\n"
	for child in node.get_children():
		result += _descendant_text(child)
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
