class_name APIResponseAdapter
extends RefCounted

const SUPPORTED_VERSION := "v1"


func decode(response_code: int, body: PackedByteArray) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK:
		return _failure("invalid_response", "本地服务返回了无法识别的数据。")
	var parsed = parser.data
	if not parsed is Dictionary:
		return _failure("invalid_response", "本地服务返回了无法识别的数据。")
	var payload: Dictionary = parsed
	if str(payload.get("api_version", "")) != SUPPORTED_VERSION:
		return _failure("unsupported_api_version", "本地服务协议版本不兼容，请重新启动并更新客户端。")
	var api_error: Dictionary = payload.get("error", {}) if payload.get("error", {}) is Dictionary else {}
	if response_code < 200 or response_code >= 300:
		return _failure(str(api_error.get("code", "http_error")), str(api_error.get("message", "本地服务请求失败。")), payload)
	if payload.has("view"):
		if not payload["view"] is Dictionary:
			return _failure("invalid_player_view", "本地服务返回的玩家视图无效。", payload)
		payload["view"] = _normalize_view(payload["view"])
	if payload.has("scenario") and not payload["scenario"] is Dictionary:
		return _failure("invalid_scenario", "本地服务返回的场景信息无效。", payload)
	return {"ok": true, "error_code": "", "message": "", "payload": payload}


func _normalize_view(source: Dictionary) -> Dictionary:
	var view := source.duplicate(true)
	for key in ["known_actors", "known_facts", "recent_events", "causal_threads", "available_actions", "guidance"]:
		if not view.has(key) or not view.get(key) is Array:
			view[key] = []
	for key in ["player", "location", "world_map", "metrics", "preparation", "presentation"]:
		if not view.has(key) or not view.get(key) is Dictionary:
			view[key] = {}
	view["scenario_id"] = str(view.get("scenario_id", ""))
	view["title"] = str(view.get("title", ""))
	view["phase"] = str(view.get("phase", ""))
	view["day"] = int(view.get("day", 0))
	view["duration"] = int(view.get("duration", 0))
	view["ended"] = bool(view.get("ended", false))
	view["resolved"] = bool(view.get("resolved", false))
	return view


func _failure(code: String, message: String, payload := {}) -> Dictionary:
	return {"ok": false, "error_code": code, "message": message, "payload": payload}
