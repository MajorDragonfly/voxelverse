extends SceneTree

const AuthoredAssets = preload("res://world/visuals/scenery/authored_environment_assets.gd")

var _seed_value: int = 15838
var _stage: String = "complete"
var _frames: int = 0
var _started: bool = false
var _finished: bool = false


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 2 or not arguments[0].is_valid_int() or arguments[1] not in ["terrain", "placement", "resources", "complete", "cluster_build", "cluster_complete"]:
		push_error("Expected main shutdown probe arguments: <seed> <terrain|placement|resources|complete|cluster_build|cluster_complete>")
		await preload("res://core/runtime_shutdown.gd").finish(self, 1)
		return
	_seed_value = int(arguments[0])
	_stage = arguments[1]
	root.get_node("GameState").call("start_world_with_seed", _seed_value)
	# GameState defers the generator rebuild. Load the scene after that rebuild.
	call_deferred("_load_main")


func _load_main() -> void:
	if change_scene_to_file("res://core/diagnostics/legacy_world.tscn") != OK:
		push_error("Could not load the real main scene for shutdown probe.")
		await preload("res://core/runtime_shutdown.gd").finish(self, 1)
		return
	_started = true


func _process(_delta: float) -> bool:
	if not _started or _finished:
		return false
	_frames += 1
	if _frames > (12000 if _stage.begins_with("cluster_") else 3600):
		push_error("Main never reached shutdown stage %s for seed %d." % [_stage, _seed_value])
		_finished = true
		preload("res://core/runtime_shutdown.gd").finish(self, 1)
		return false
	if current_scene == null:
		return false
	var manager: Node = current_scene.get_node_or_null("WorldManager")
	if manager == null:
		return false
	var chunks: Dictionary = manager.get("loaded_chunks")
	for chunk: Node in chunks.values():
		var ecology: Node = chunk.get_node("ProceduralEcosystemV6")
		var reached: bool = false
		match _stage:
			"terrain":
				reached = not bool(chunk.get("generation_complete"))
			"placement":
				reached = int(ecology.get("_phase")) == 1 and int(ecology.get("_placement_task")) >= 0
			"resources":
				reached = int(ecology.get("_phase")) == 2 and not AuthoredAssets._requests.is_empty()
			"complete":
				reached = bool(ecology.get("generation_complete")) and ecology.get_child_count() > 0
			"cluster_build":
				reached = not (ecology.get("_cluster_builders") as Dictionary).is_empty()
			"cluster_complete":
				reached = int(ecology.call("get_generation_stats")["cluster_nodes"]) > 0
		if reached:
			_finished = true
			var generator: Node = root.get_node("WorldGenerator")
			if int(generator.call("get_world_seed")) != _seed_value:
				push_error("Shutdown probe ran on a different planet seed.")
				preload("res://core/runtime_shutdown.gd").finish(self, 1)
			else:
				print("Main shutdown probe reached seed=%d stage=%s frame=%d." % [_seed_value, _stage, _frames])
				# Leave the active scene in place: ordinary engine shutdown must own
				# cancellation, worker joins and resource cleanup.
				preload("res://core/runtime_shutdown.gd").finish(self, 0)
			return false
	return false
