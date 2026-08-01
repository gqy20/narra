extends RefCounted

const LOCATION_PROFILES := {
	"market": preload("res://assets/locations/market/profile.tres"),
	"qinglan": preload("res://assets/locations/qinglan/profile.tres"),
}
const ACTOR_PROFILES := {
	"N03": preload("res://assets/characters/N03/profile.tres"),
}


func location_profile(scene_key: String) -> LocationVisualProfile:
	return LOCATION_PROFILES.get(scene_key)


func actor_profile(actor_id: String) -> ActorVisualProfile:
	return ACTOR_PROFILES.get(actor_id)


func has_location(scene_key: String) -> bool:
	return LOCATION_PROFILES.has(scene_key)


func has_actor(actor_id: String) -> bool:
	return ACTOR_PROFILES.has(actor_id)
