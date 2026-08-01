extends SceneTree

var app
var output_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	output_dir = ProjectSettings.globalize_path("res://../artifacts/audits/playability-2026-08-01")
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		return _fail("could not create audit output directory")
	if not await _wait_until_idle():
		return _fail("health request timed out")

	app.name_input.text = "初见修士"
	app._new_game()
	if not await _wait_until_idle():
		return _fail("new game request timed out")
	app._set_visual_mode("location")
	await _capture("01-opening-overview.png")

	if not await _execute("verify:F02"):
		return
	if not await _execute("wait:complete"):
		return
	await _capture("02-verified-overview.png")

	app._set_visual_mode("map")
	app._on_map_location_selected("L02")
	await _capture("03-route-decision.png")
	if not await _execute("move:L02"):
		return

	app._set_visual_mode("location")
	app._focus_actor_actions("N03", "沈砚秋")
	await _capture("04-actor-message-choice.png")

	var tell_action := _find_action("tell:N03:F01:trust")
	if tell_action.is_empty():
		return _fail("missing tell action")
	app._consider_action(tell_action)
	await _settle_layout()
	if not app.confirmation_layer.visible:
		return _fail("tell action did not open confirmation")
	await _capture("05-irreversible-confirmation.png")
	app._confirm_selected_action()
	if not await _wait_until_idle(15000):
		return _fail("tell action timed out")

	if not await _execute("wait:next"):
		return
	if not app.causal_layer.visible:
		return _fail("causal theatre did not open")
	await _capture("06-visible-causal-change.png")
	app._dismiss_causal()
	app._open_journal()
	await _capture("07-causal-record.png")
	app._close_journal()

	app._clear_action_focus()
	for index in 8:
		if bool(app.current_view.get("resolved", false)):
			break
		if not await _execute("wait:next"):
			return
	if not app.ending_layer.visible:
		return _fail("ending did not open")
	await _capture("08-ending-summary.png")
	print("Playability audit screenshots captured.")
	quit(0)


func _execute(action_id: String) -> bool:
	var action := _find_action(action_id)
	if action.is_empty():
		_fail("missing action: " + action_id)
		return false
	app._consider_action(action)
	if app.confirmation_layer.visible:
		await _settle_layout()
		app._confirm_selected_action()
	if not await _wait_until_idle(15000):
		_fail("action timed out: " + action_id)
		return false
	return true


func _find_action(action_id: String) -> Dictionary:
	var actions = app.current_view.get("available_actions", [])
	if not actions is Array:
		return {}
	for action in actions:
		if action.get("id", "") == action_id:
			return action
	return {}


func _capture(file_name: String) -> void:
	await _settle_layout()
	await RenderingServer.frame_post_draw
	var image: Image = app.get_viewport().get_texture().get_image()
	var save_error := image.save_png(output_dir.path_join(file_name))
	if save_error != OK:
		_fail("could not save screenshot: " + file_name)


func _settle_layout() -> void:
	for index in 4:
		await process_frame


func _wait_until_idle(timeout_ms := 10000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if app.pending_operation == "" and not app.presentation_busy:
			await process_frame
			if app.pending_operation == "" and not app.presentation_busy:
				return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
