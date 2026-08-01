class_name ActorVisualProfile
extends Resource

@export var actor_id: String
@export var neutral: Texture2D
@export var alert: Texture2D
@export var troubled: Texture2D
@export var decisive: Texture2D
@export var accent_color := Color("d6ae62")


func portrait(expression := "neutral") -> Texture2D:
	match expression:
		"alert":
			return alert if alert else neutral
		"troubled":
			return troubled if troubled else neutral
		"decisive":
			return decisive if decisive else neutral
		_:
			return neutral
