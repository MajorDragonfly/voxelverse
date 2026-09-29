extends SceneTree
## Distant completed shelters must not fill the village view with captions.
const Shelters = preload("res://world/tribe/village_shelters.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.make_current()
	var shelters := Shelters.new()
	stage.add_child(shelters)
	var data: Dictionary = {"id": "label-test", "anchor": [0.0, 0.0, 0.0],
		"housing": {"homes": [{"id": "shelter-test", "kind": "hut", "position": [0.0, 0.0, 0.0]}]}}
	shelters.sync(data, {})
	var building: Node3D = shelters.get_child(0)
	var label: Label3D = building.get_child(building.get_child_count() - 1)
	camera.global_position = Vector3(0, 20, 20)
	await create_timer(0.35).timeout
	_check(label.visible, "Nearby shelter caption disappeared.")
	camera.global_position = Vector3(0, 90, 90)
	await create_timer(0.35).timeout
	_check(not label.visible, "Distant shelter caption still clutters the world view.")
	_check(shelters.get_child_count() == 1 and shelters.get_child(0) == building,
		"Changing caption distance rebuilt the shelter or its collision.")
	camera.global_position = Vector3(0, 20, 20)
	await create_timer(0.35).timeout
	_check(label.visible, "Shelter caption did not return on approach.")
	for message in failures: push_error(message)
	print(JSON.stringify({"test": "tribal_shelter_labels", "passed": failures.is_empty(), "failures": failures}))
	stage.queue_free()
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
