extends SceneTree
## A streamed actor must construct its frozen body once on arrival.
const Surface = preload("res://creatures/editor/creature_sculpt_surface.gd")
const Shutdown = preload("res://core/runtime_shutdown.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	root.get_node("SaveGameService")._loaded_once = true
	root.get_node("GameState").start_world_with_seed(15838)
	await process_frame
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var player := Node3D.new()
	player.add_to_group(&"player")
	scene.add_child(player)
	var actor: CharacterBody3D = load("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
	actor.configure(15838, 21, Vector2i.ZERO, "grazer")
	actor.position = Vector3(0.0, 100.0, 0.0)
	scene.add_child(actor)
	var bodies: int = 0
	for child: Node in actor._preview.get_children():
		if str(child.name).begins_with("BodyV4"): bodies += 1
	_expect(bodies == 1, "Wildlife created a disposable default body before the frozen species body.")
	var skin: MeshInstance3D = actor._preview.get_node_or_null("BodyV4/SculptedSkin")
	_expect(skin != null, "Live wildlife has no sculpted body.")
	if skin != null:
		var expected: Mesh = Surface.build_skin(actor.blueprint)
		_expect(skin.mesh.surface_get_arrays(0) == expected.surface_get_arrays(0), "First build does not match frozen species geometry and colors.")
	scene.queue_free()
	await process_frame
	print(JSON.stringify({"test": "wildlife_spawn_budget", "failures": failures}))
	await Shutdown.finish(self, 0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
