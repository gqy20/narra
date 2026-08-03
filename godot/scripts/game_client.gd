class_name GameClient
extends Node

signal request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)

var base_url := ""
var request_node: HTTPRequest


func _init(url := "") -> void:
	base_url = url


func _ready() -> void:
	request_node = HTTPRequest.new()
	add_child(request_node)
	request_node.request_completed.connect(_forward_completed)


func send(method: HTTPClient.Method, path: String, payload := {}) -> Error:
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := "" if method == HTTPClient.METHOD_GET else JSON.stringify(payload)
	return request_node.request(base_url + path, headers, method, body)


func _forward_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	request_completed.emit(result, response_code, headers, body)
