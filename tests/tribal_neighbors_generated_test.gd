extends "tribal_age_world_test.gd"
var evidence: Dictionary = {}

func _run() -> void:
	Engine.time_scale = 3.0
	await super._run()

func _extension(tribe: Node) -> void:
	_expect(tribe.neighbors.contact(), "No reachable neighbor in the real generated world: " + tribe.status)
	if tribe.neighbors.data().is_empty():
		return
	var ids: Array = tribe.neighbors.actors.keys()
	tribe.select_all()
	_expect(tribe.issue_order("food"), "Cannot gather actual food for neighbor help")
	await _until(func() -> bool: return int(tribe.village()["stock"]["food"]) >= 16, 2400)
	_expect(int(tribe.village()["stock"]["food"]) >= 16, "Food cannot physically reach the home warehouse")
	_expect(tribe.issue_order("move", tribe.anchor()), "Cannot finish ordinary cargo before the aid agreement")
	await _until(func() -> bool: return tribe.village()["members"].all(func(m: Dictionary) -> bool: return m["cargo"] == ""), 750)
	_expect(tribe.neighbors.start_aid(), "Real generated world cannot start aid: " + tribe.status)
	await _until(func() -> bool: return tribe.neighbors.data()["aid"]["status"] == "completed", 3600)
	_expect(tribe.neighbors.data()["aid"]["status"] == "completed", "Physical aid route or neighbor work stalled on generated terrain: " + str(tribe.neighbors.data()))
	for actor: CharacterBody3D in tribe.neighbors.actors.values():
		_expect(actor.visible and actor.is_on_floor(), "Neighbor lost physical terrain contact")
	var saves: Node = root.get_node("SaveGameService")
	paused = true
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(tribe.neighbors.data()))
	_expect(saves.save_now() and saves.load_now(), "Generated neighbor campaign cannot save/load")
	_expect(JSON.parse_string(JSON.stringify(tribe.neighbors.data())) == snapshot, "Load changed real neighbor residents or stock")
	paused = false
	await _until(func() -> bool: return tribe.is_active(), 1800)
	_expect(tribe.neighbors.actors.keys() == ids and tribe.actors.size() == 3, "Runtime reload changed or duplicated either group")
	evidence = {"village": tribe.village()["anchor"], "neighbor": tribe.neighbors.data()["anchor"], "received": snapshot["aid"]["received"], "builders": snapshot["aid"]["builders"], "status": snapshot["aid"]["status"]}

func _until(condition: Callable, frames: int) -> void:
	for frame in range(frames):
		if condition.call():
			return
		await physics_frame
		await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("GENERATED NEIGHBOR CHECK FAILED: ", message)

func _finish() -> void:
	print(JSON.stringify({"test": "tribal_neighbors_generated", "passed": failures.is_empty(), "failures": failures, "evidence": evidence}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
