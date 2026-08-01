extends RefCounted

const LOCATION_PROFILES := {
	"market": preload("res://assets/locations/market/profile.tres"),
	"qinglan": preload("res://assets/locations/qinglan/profile.tres"),
	"apothecary": preload("res://assets/locations/apothecary/profile.tres"),
	"valley_edge": preload("res://assets/locations/valley_edge/profile.tres"),
	"inner_valley": preload("res://assets/locations/inner_valley/profile.tres"),
}
const ACTOR_PROFILES := {
	"N01": preload("res://assets/characters/N01/profile.tres"),
	"N02": preload("res://assets/characters/N02/profile.tres"),
	"N03": preload("res://assets/characters/N03/profile.tres"),
	"N04": preload("res://assets/characters/N04/profile.tres"),
	"N05": preload("res://assets/characters/N05/profile.tres"),
	"N06": preload("res://assets/characters/N06/profile.tres"),
	"N07": preload("res://assets/characters/N07/profile.tres"),
	"N08": preload("res://assets/characters/N08/profile.tres"),
	"N09": preload("res://assets/characters/N09/profile.tres"),
	"N10": preload("res://assets/characters/N10/profile.tres"),
}


func location_profile(scene_key: String) -> LocationVisualProfile:
	return LOCATION_PROFILES.get(scene_key)


func actor_profile(actor_id: String) -> ActorVisualProfile:
	return ACTOR_PROFILES.get(actor_id)


func has_location(scene_key: String) -> bool:
	return LOCATION_PROFILES.has(scene_key)


func has_actor(actor_id: String) -> bool:
	return ACTOR_PROFILES.has(actor_id)
