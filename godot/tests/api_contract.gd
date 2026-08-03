extends SceneTree


func _initialize() -> void:
	var adapter = load("res://scripts/api_response_adapter.gd").new()
	var valid: Dictionary = adapter.decode(200, JSON.stringify({
		"api_version": "v1",
		"view": {
			"scenario_id": "sample", "title": "Sample", "phase": "opening", "day": 1, "duration": 30,
			"ended": false, "resolved": false, "known_actors": [], "known_facts": [], "recent_events": [],
			"available_actions": [], "player": {}, "location": {}, "world_map": {}, "metrics": {},
			"preparation": {}, "presentation": {},
		},
	}).to_utf8_buffer())
	if not valid.get("ok", false):
		return _fail("valid response was rejected")
	var view: Dictionary = valid.get("payload", {}).get("view", {})
	if view.get("scenario_id", "") != "sample" or not view.get("known_actors", null) is Array or not view.get("player", null) is Dictionary:
		return _fail("valid player view changed during decoding")

	var incomplete: Dictionary = adapter.decode(200, JSON.stringify({
		"api_version": "v1", "view": {"scenario_id": "sample", "day": 1, "available_actions": []},
	}).to_utf8_buffer())
	if incomplete.get("ok", true) or incomplete.get("error_code", "") != "invalid_player_view":
		return _fail("incomplete player view was accepted")

	var wrong_version: Dictionary = adapter.decode(200, JSON.stringify({"api_version": "v2"}).to_utf8_buffer())
	if wrong_version.get("ok", true) or wrong_version.get("error_code", "") != "unsupported_api_version":
		return _fail("unsupported API version was accepted")

	var api_error: Dictionary = adapter.decode(409, JSON.stringify({
		"api_version": "v1",
		"error": {"code": "no_session", "message": "missing"},
	}).to_utf8_buffer())
	if api_error.get("ok", true) or api_error.get("error_code", "") != "no_session" or api_error.get("message", "") != "missing":
		return _fail("structured API error was not preserved")

	var malformed: Dictionary = adapter.decode(200, "not-json".to_utf8_buffer())
	if malformed.get("ok", true) or malformed.get("error_code", "") != "invalid_response":
		return _fail("malformed response was accepted")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
