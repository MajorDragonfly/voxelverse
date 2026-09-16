extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var saves := root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://world_map_test.json"
	if not saves.load_now(): quit(1); return
	var state := root.get_node("GameState")
	var atlas := preload("res://core/map/exploration_atlas.gd").new()
	if not atlas.bind(state.get_current_body_record().exploration_atlas): quit(1); return
	var query := preload("res://ui/world_map/atlas_place_query.gd").new()
	query.begin(atlas, "nadelöhr", true, true, 64,
		func(p: Dictionary) -> bool: return preload("res://ui/world_map/world_map_source.gd").place_is_visible(p, atlas.data.body_id, self),
		preload("res://ui/world_map/atlas_presentation.gd").place_name)
	for tick in range(10000):
		if not query.active: break
		query.step()
	var passed: bool = not query.active and not query.failed and query.results.size() == 1 and query.results[0].id == "search-place-384" and not query.has_next
	print("ATLAS_SEARCH_RESTART_OK" if passed else "ATLAS_SEARCH_RESTART_FAILED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if passed else 1)
