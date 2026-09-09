extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var saves := root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://world_map_test.json"
	var loaded: bool = saves.load_now()
	var state := root.get_node("GameState")
	var atlas := preload("res://core/map/exploration_atlas.gd").new()
	var record: Dictionary = state.campaign.data.bodies[str(state.get_world_seed())].get("exploration_atlas", {})
	var okay: bool = loaded and atlas.bind(record) and record.places.size() == 2
	if okay:
		okay = atlas.known(preload("res://core/map/surface_map_projection.gd").plane_address(record.body_id, Vector3(240, 100, 0)))
	if not okay: push_error("Fresh process lost the saved exploration or known places.")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if okay else 1)
