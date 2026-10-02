extends SceneTree
## Isolates the production tool; also runs in the normal autoload environment.
const Tool = preload("res://world/tribe/village_work_motion.gd")
class Clock extends Node:
	var speed: float = 1.0
	func simulation_delta(delta: float) -> float: return maxf(delta, 0.0) * speed
	func set_simulation_speed(value: float) -> bool:
		speed = value
		return true
class Resident extends Node3D:
	var member_id: String = ""
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node_or_null("GameState")
	var owns_clock: bool = state == null
	if owns_clock:
		state = Clock.new()
		state.name = "GameState"
		root.add_child(state)
	state.set_process(false)
	state.set_simulation_speed(1.0)
	var a := _resident("resident-a")
	var b := _resident("resident-b")
	var first: Node3D = a.get_node("TribeWorkTool")
	var second: Node3D = b.get_node("TribeWorkTool")
	first.pulse("wood")
	second.pulse("wood")
	first.set_process(false)
	second.set_process(false)
	first._process(0.1)
	second._process(0.1)
	_expect(not is_equal_approx(first.rotation.z, second.rotation.z), "Simultaneous residents swing in exactly the same phase.")
	var visual: Node3D = a.get_node("CreatureRuntimeVisual")
	visual.rotation.y = PI * 0.5
	first._process(0.01)
	_expect(first.position.distance_to(visual.basis * Vector3(0.55, 1.25, -0.32)) < 0.0001
		and is_equal_approx(first.rotation.y, visual.rotation.y), "Tool stays behind when its resident turns.")
	var before: Dictionary = _motion(first)
	state.set_simulation_speed(0.0)
	first._process(0.2)
	_expect(_motion(first) == before, "Tempo pause advances or expires the actual work tool.")
	state.set_simulation_speed(2.0)
	first._process(0.05)
	_expect(is_equal_approx(first._remaining, float(before.remaining) - 0.1), "Tool lifetime does not follow the existing simulation_delta port.")
	state.set_simulation_speed(1.0)
	first.pulse("stone")
	first.set_process(true)
	before = _motion(first)
	paused = true
	for frame in range(5): await process_frame
	_expect(_motion(first) == before, "SceneTree pause advances the work tool.")
	paused = false
	first.set_process(false)
	var head: MeshInstance3D = first._head
	var material: Material = head.material_override
	for repeat in range(30): first.pulse("stone")
	_expect(a.get_child_count() == 2 and first._head == head and head.material_override == material, "Repeated work allocates another tool, head or unchanged material.")
	first._process(1.0)
	_expect(not first.visible and not first.is_processing() and first._remaining == 0.0, "Finished tool remains visible/processing.")
	_expect(is_zero_approx(first.rotation.z), "Finished tool retains a tilted rest pose.")
	first.pulse("wood")
	first.set_process(false)
	first._process(0.1)
	var angle: float = first.rotation.z
	first._process(-0.1)
	_expect(is_equal_approx(first.rotation.z, angle), "Negative delta rewinds presentation.")
	# Reload-like replacement: stable resident identity recovers the same phase.
	var replacement := _resident("resident-a")
	var restored: Node3D = replacement.get_node("TribeWorkTool")
	restored.pulse("wood")
	restored.set_process(false)
	restored._process(0.1)
	_expect(is_equal_approx(restored.rotation.z, angle), "Recreated resident changes its presentation phase.")
	for node in [a, b, replacement]: node.queue_free()
	if owns_clock: state.queue_free()
	await process_frame
	print(JSON.stringify({"test": "r32_17_work_motion", "passed": failures.is_empty(), "checks": checks, "failures": failures,
		"scope": "production tool and existing simulation_delta contract; no campaign/render/FPS acceptance"}))
	var code: int = 0 if failures.is_empty() else 1
	if owns_clock:
		quit(code)
	else:
		await load("res://core/runtime_shutdown.gd").finish(self, code)

func _resident(identity: String) -> Node3D:
	var actor := Resident.new()
	actor.member_id = identity
	root.add_child(actor)
	var visual := Node3D.new()
	visual.name = "CreatureRuntimeVisual"
	actor.add_child(visual)
	var tool := Tool.new()
	actor.add_child(tool)
	return actor

func _motion(tool: Node3D) -> Dictionary:
	return {"remaining": tool._remaining, "clock": tool._clock, "angle": tool.rotation.z, "visible": tool.visible}

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
