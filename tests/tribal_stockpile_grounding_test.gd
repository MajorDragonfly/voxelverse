extends SceneTree
## A lot may appear before its ground collider has streamed in.
const Stockpiles = preload("res://world/tribe/village_stockpiles.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var piles := Stockpiles.new()
	stage.add_child(piles)
	var data: Dictionary = {"id": "grounding-test", "anchor": [0.0, 1.0, 0.0],
		"members": [], "stock": {"wood": 8}, "economy": {"incoming": []}, "project": {}}
	piles.sync(data)
	var wood: Node3D = piles.lots.wood.root
	var mesh: MultiMesh = piles.lots.wood.stored.multimesh
	var node_count: int = piles.get_child_count()
	_check(absf(wood.global_position.y - 1.0) < 0.01, "Fixture has an unexpected early floor.")
	_check(piles.is_physics_processing(), "Missing ground did not schedule a bounded retry.")
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(12, 1, 12)
	collision.shape = shape
	floor.position.y = -0.5
	floor.add_child(collision)
	stage.add_child(floor)
	for frame in range(40):
		await physics_frame
		if absf(wood.global_position.y) < 0.03: break
	_check(absf(wood.global_position.y) < 0.03, "Stored lot stayed suspended after the floor appeared.")
	_check(piles.lots.wood.stored.multimesh == mesh and piles.snapshot.wood.stored == 8,
		"Grounding rebuilt the stock mesh or changed its inventory view.")
	_check(piles.get_child_count() == node_count and not piles.is_physics_processing(),
		"Grounding added objects or kept polling after every lot found its floor.")
	for message in failures: push_error(message)
	print(JSON.stringify({"test": "tribal_stockpile_grounding", "passed": failures.is_empty(), "failures": failures}))
	stage.queue_free()
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
