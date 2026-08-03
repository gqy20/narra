extends RefCounted

var manifest: Dictionary = {}
var resource_cache: Dictionary = {}
var generated_profile_cache: Dictionary = {}


func configure(value: Dictionary) -> void:
	manifest = value.duplicate(true)
	resource_cache.clear()
	generated_profile_cache.clear()


func location_profile(scene_key: String) -> LocationVisualProfile:
	var explicit := _profile("locations", scene_key) as LocationVisualProfile
	if explicit:
		return explicit
	var cache_key := "location:%s" % scene_key
	if generated_profile_cache.has(cache_key):
		return generated_profile_cache[cache_key] as LocationVisualProfile
	var background := _conventional_texture("locations/%s/background.png" % scene_key)
	if background == null:
		return null
	var generated := LocationVisualProfile.new()
	generated.scene_key = scene_key
	generated.background = background
	generated.ambient_key = scene_key
	generated_profile_cache[cache_key] = generated
	return generated


func actor_profile(actor_id: String) -> ActorVisualProfile:
	var explicit := _profile("actors", actor_id) as ActorVisualProfile
	if explicit:
		return explicit
	var cache_key := "actor:%s" % actor_id
	if generated_profile_cache.has(cache_key):
		return generated_profile_cache[cache_key] as ActorVisualProfile
	var neutral := _conventional_texture("characters/%s/neutral.png" % actor_id)
	if neutral == null:
		return null
	var generated := ActorVisualProfile.new()
	generated.actor_id = actor_id
	generated.neutral = neutral
	generated.alert = _conventional_texture("characters/%s/alert.png" % actor_id)
	generated.troubled = _conventional_texture("characters/%s/troubled.png" % actor_id)
	generated.decisive = _conventional_texture("characters/%s/decisive.png" % actor_id)
	var entry := _entry("actors", actor_id)
	if str(entry.get("accent_color", "")) != "":
		generated.accent_color = Color.from_string(str(entry.get("accent_color")), generated.accent_color)
	generated_profile_cache[cache_key] = generated
	return generated


func terrain_texture() -> Texture2D:
	var explicit := _resource(str(manifest.get("terrain", ""))) as Texture2D
	return explicit if explicit else ui_texture("district_map")


func location_background(scene_key: String) -> Texture2D:
	var entry := _entry("locations", scene_key)
	var explicit := _resource(str(entry.get("background", ""))) as Texture2D
	if explicit:
		return explicit
	var profile := location_profile(scene_key)
	return profile.background if profile else null


func location_fallback_kind(scene_key: String) -> String:
	return str(_entry("locations", scene_key).get("fallback_kind", "generic"))


func location_stage_label(scene_key: String) -> String:
	return str(_entry("locations", scene_key).get("stage_label", ""))


func location_ambient(scene_key: String) -> Dictionary:
	var entry := _entry("locations", scene_key)
	return {
		"frequency": float(entry.get("ambient_frequency", 58.0)),
		"air": float(entry.get("ambient_air", 0.10)),
	}


func evidence_texture(evidence_id: String) -> Texture2D:
	var entry := _entry("evidence", evidence_id)
	var explicit := _resource(str(entry.get("image", ""))) as Texture2D
	return explicit if explicit else _conventional_texture("evidence/%s/closeup.png" % evidence_id)


func fact_texture(fact_id: String) -> Texture2D:
	var value: Variant = _section("facts").get(fact_id, "")
	var evidence_id := ""
	if value is Dictionary:
		var explicit := _resource(str(value.get("image", ""))) as Texture2D
		if explicit:
			return explicit
		evidence_id = str(value.get("evidence", ""))
	else:
		evidence_id = str(value)
	return evidence_texture(evidence_id) if evidence_id != "" else null


func event_texture(event_key: String) -> Texture2D:
	var value: Variant = _section("events").get(event_key, "")
	if value is Dictionary:
		var explicit := _resource(str(value.get("image", ""))) as Texture2D
		if explicit:
			return explicit
	elif str(value) != "":
		var explicit := _resource(str(value)) as Texture2D
		if explicit:
			return explicit
	return _conventional_texture("events/%s.png" % event_key)


func event_texture_for_action(action_id: String) -> Texture2D:
	var best_key := ""
	var best_event := ""
	for raw_key in _section("event_cues"):
		var prefix := str(raw_key)
		if action_id.begins_with(prefix) and prefix.length() > best_key.length():
			best_key = prefix
			best_event = str(_section("event_cues")[raw_key])
	return event_texture(best_event) if best_event != "" else null


func event_video(event_key: String) -> VideoStream:
	if event_key == "":
		return null
	return _conventional_resource("videos/events/%s.ogv" % event_key) as VideoStream


func background_music() -> AudioStream:
	var audio := _section("audio")
	var value := str(audio.get("music", "")).strip_edges()
	if value == "":
		return null
	if ResourceLoader.exists(value):
		return _resource(value) as AudioStream
	return _conventional_resource("audio/music/%s.ogg" % value.trim_suffix(".ogg")) as AudioStream


func music_volume_db(fallback := -10.0) -> float:
	return float(_section("audio").get("music_volume_db", fallback))


func ui_texture(key: String) -> Texture2D:
	var value: Variant = _section("ui").get(key, "")
	if str(value) != "":
		var explicit := _resource(str(value)) as Texture2D
		if explicit:
			return explicit
	var conventional := {
		"district_map": "ui/map/district-map.png",
		"archive_paper": "ui/textures/archive-paper.png",
		"ink_vignette": "ui/textures/ink-vignette.png",
		"title_seal": "ui/brand/title-seal.png",
	}
	return _conventional_texture(str(conventional.get(key, "")))


func ui_text(key: String) -> String:
	var value := str(_section("ui").get(key, "")).strip_edges()
	if value == "":
		push_error("Missing required presentation UI text: %s" % key)
	return value


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
	return location_profile(scene_key) != null


func has_actor(actor_id: String) -> bool:
	return actor_profile(actor_id) != null


func location_count() -> int:
	return maxi(_section("locations").size(), _conventional_entry_count("locations", "background.png"))


func actor_count() -> int:
	return maxi(_section("actors").size(), _conventional_entry_count("characters", "neutral.png"))


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


func _conventional_texture(relative_path: String) -> Texture2D:
	return _conventional_resource(relative_path) as Texture2D


func _conventional_resource(relative_path: String) -> Resource:
	var root := str(manifest.get("asset_root", "")).trim_suffix("/")
	if root == "" or relative_path == "":
		return null
	var path := "%s/%s" % [root, relative_path.trim_prefix("/")]
	if not ResourceLoader.exists(path):
		return null
	return _resource(path)


func _conventional_entry_count(section_path: String, required_file: String) -> int:
	var root := str(manifest.get("asset_root", "")).trim_suffix("/")
	if root == "":
		return 0
	var directory_path := "%s/%s" % [root, section_path]
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return 0
	var count := 0
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while entry_name != "":
		if directory.current_is_dir() and not entry_name.begins_with("."):
			var candidate := "%s/%s/%s" % [directory_path, entry_name, required_file]
			if ResourceLoader.exists(candidate):
				count += 1
		entry_name = directory.get_next()
	directory.list_dir_end()
	return count


func _section(name: String) -> Dictionary:
	var value = manifest.get(name, {})
	return value if value is Dictionary else {}


func _entry(section: String, key: String) -> Dictionary:
	var value = _section(section).get(key, {})
	return value if value is Dictionary else {}
