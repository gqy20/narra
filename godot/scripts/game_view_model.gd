class_name GameViewModel
extends RefCounted

var current: Dictionary = {}
var previous: Dictionary = {}


func accept(view: Dictionary, track_previous := false) -> Dictionary:
	previous = current if track_previous else {}
	current = view.duplicate(true)
	return current


func clear_previous() -> void:
	previous = {}
