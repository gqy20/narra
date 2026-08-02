class_name AIDialogueClient
extends Node

signal dialogue_ready(actor_id: String, dialogue: Dictionary)
signal dialogue_failed(actor_id: String, message: String)

var api_base := "http://127.0.0.1:8787/api/v1"
var http: HTTPRequest
var active_actor_id := ""
var request_generation := 0


func _ready() -> void:
	pass


func request_focus(actor_id: String) -> void:
	if actor_id == "":
		return
	cancel()
	active_actor_id = actor_id
	request_generation += 1
	var generation := request_generation
	http = HTTPRequest.new()
	http.timeout = 32.0
	add_child(http)
	http.request_completed.connect(_on_request_completed.bind(actor_id, generation))
	var payload := JSON.stringify({"actor_id": actor_id, "situation": "focus"})
	var error := http.request(
		api_base + "/game/dialogue",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		payload
	)
	if error != OK and generation == request_generation:
		active_actor_id = ""
		http.queue_free()
		http = null
		dialogue_failed.emit(actor_id, "无法启动人物对话请求")


func cancel() -> void:
	request_generation += 1
	active_actor_id = ""
	if http != null:
		if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			http.cancel_request()
		http.queue_free()
		http = null


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, actor_id: String, generation: int) -> void:
	if generation != request_generation:
		return
	active_actor_id = ""
	if http != null:
		http.queue_free()
		http = null
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var message := "人物回应生成失败，请重试"
		var error_response = JSON.parse_string(body.get_string_from_utf8())
		if error_response is Dictionary and error_response.get("error", {}) is Dictionary:
			message = str(error_response.get("error", {}).get("message", message))
		dialogue_failed.emit(actor_id, message)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary or not parsed.get("dialogue", {}) is Dictionary:
		dialogue_failed.emit(actor_id, "人物回应不是有效的结构化数据")
		return
	var dialogue: Dictionary = parsed.get("dialogue", {})
	if str(dialogue.get("actor_id", "")) != actor_id:
		dialogue_failed.emit(actor_id, "人物回应与当前交谈对象不一致")
		return
	dialogue_ready.emit(actor_id, dialogue)
