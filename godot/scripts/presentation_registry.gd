extends RefCounted

var manifest: Dictionary = {}
var resource_cache: Dictionary = {}


func configure(value: Dictionary) -> void:
	manifest = value.duplicate(true)
	resource_cache.clear()


func location_profile(scene_key: String) -> LocationVisualProfile:
	return _profile("locations", scene_key) as LocationVisualProfile


func actor_profile(actor_id: String) -> ActorVisualProfile:
	return _profile("actors", actor_id) as ActorVisualProfile


func terrain_texture() -> Texture2D:
	return _resource(str(manifest.get("terrain", ""))) as Texture2D


func location_background(scene_key: String) -> Texture2D:
	var entry := _entry("locations", scene_key)
	return _resource(str(entry.get("background", ""))) as Texture2D


func actor_token_color(actor_id: String, fallback: Color) -> Color:
	var token: Variant = _entry("actors", actor_id).get("map_token", {})
	if token is Dictionary and str(token.get("color", "")) != "":
		return Color.from_string(str(token.get("color")), fallback)
	return fallback


func actor_token_offset(actor_id: String, fallback: Vector2) -> Vector2:
	var token: Variant = _entry("actors", actor_id).get("map_token", {})
	var offset: Variant = token.get("offset", []) if token is Dictionary else []
	if offset is Array and offset.size() == 2:
		return Vector2(float(offset[0]), float(offset[1]))
	return fallback


func has_location(scene_key: String) -> bool:
	return _entry("locations", scene_key).has("profile")


func has_actor(actor_id: String) -> bool:
	return _entry("actors", actor_id).has("profile")


func location_count() -> int:
	return _section("locations").size()


func actor_count() -> int:
	return _section("actors").size()


func _profile(section: String, key: String) -> Resource:
	return _resource(str(_entry(section, key).get("profile", "")))


func _resource(path: String) -> Resource:
	if path == "":
		return null
	if resource_cache.has(path):
		return resource_cache[path]
	if not ResourceLoader.exists(path):
		push_error("Presentation resource is missing: %s" % path)
		return null
	var loaded := ResourceLoader.load(path)
	resource_cache[path] = loaded
	return loaded


func _section(name: String) -> Dictionary:
	var value = manifest.get(name, {})
	return value if value is Dictionary else {}


func _entry(section: String, key: String) -> Dictionary:
	var value = _section(section).get(key, {})
	return value if value is Dictionary else {}
