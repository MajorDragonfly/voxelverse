extends SceneTree
var started: int
var marks: Dictionary = {}
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	Engine.max_fps = 60
	root.get_node("SaveGameService").autosave_enabled = false
	var seed_value: int = int(OS.get_cmdline_user_args()[0]) if not OS.get_cmdline_user_args().is_empty() else 15838
	root.get_node("GameState").start_world_with_seed(seed_value)
	await process_frame
	started = Time.get_ticks_usec()
	change_scene_to_file("res://main/main.tscn")
	for frame in range(6000):
		await process_frame
		if current_scene == null: continue
		var player: Node = current_scene.get_node("Player")
		player.set_process(false)
		for creature: Node in current_scene.get_node("FaunaStreamerV7").get_children():
			creature.set("predator_attack_damage", 0.0)
		var manager: Node = current_scene.get_node("WorldManager")
		if not manager.world_initialized: continue
		player.set_physics_process(false)
		if not marks.has("terrain_ms"): marks["terrain_ms"]=(Time.get_ticks_usec()-started)/1000.0
		var finished: int=0
		var instances: int=0
		var visible: int=0
		for chunk: Node in manager.loaded_chunks.values():
			var eco: Node=chunk.get_node("ProceduralEcosystemV6")
			finished += int(eco.generation_complete)
			instances += eco.instance_count
			visible += eco.get_child_count()
		if visible>0 and not marks.has("first_assets_ms"): marks["first_assets_ms"]=(Time.get_ticks_usec()-started)/1000.0
		if manager.get_pending_chunk_count()==0 and finished==25:
			marks["all_25_ms"]=(Time.get_ticks_usec()-started)/1000.0
			marks["instances"]=instances
			break
	marks["seed"] = seed_value
	var expected: Vector3 = root.get_node("WorldGenerator").get_scenic_spawn()
	var actual: Vector3 = current_scene.get_node("Player").position
	if Vector2(expected.x - actual.x, expected.z - actual.z).length() > 0.1:
		push_error("Benchmark player left the scenic spawn.")
		quit(1)
		return
	marks["scope"]="Main scene paced at 60 process frames/s, headless CPU only, cold process, stationary review player. Terrain and vegetation changes alter the workload."
	print("PACED_STREAMING ",JSON.stringify(marks))
	current_scene.free()
	current_scene=null
	await process_frame
	quit(0 if marks.has("all_25_ms") else 1)
