extends RefCounted
## Deterministic turntable / wildlife posing. The gameplay player continues to
## use the adaptive terrain-contact animator; both use the same knee builder.

const Animator = preload("res://creatures/runtime/adaptive_locomotion_animator.gd")
var _preview: Node3D
var _base_position := Vector3.ZERO
var _parts: Array[Dictionary] = []
var _legs: Array[Dictionary] = []


func bind(preview: Node3D) -> void:
	_preview = preview
	_base_position = preview.position
	_parts.clear()
	_legs.clear()
	for child in preview.get_children():
		if child is Node3D and child.has_meta("creature_part_category"):
			_parts.append({"node": child, "position": child.position, "rotation": child.rotation})
	var legs: Array[Node3D] = []
	for part in _parts:
		if str(part["node"].get_meta("creature_part_category")) == "legs":
			legs.append(part["node"])
	legs.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.position.z < b.position.z)
	var animator := Animator.new()
	var ranks: Dictionary = {1: 0, -1: 0}
	for leg in legs:
		var side: int = 1 if float(leg.get_meta("creature_part_side", 1.0)) > 0.0 else -1
		var record: Dictionary = animator._create_runtime_leg_rig(leg)
		record["phase"] = PI * float((int(ranks[side]) + (1 if side < 0 else 0)) % 2)
		ranks[side] += 1
		_legs.append(record)
	animator.free()


func reset() -> void:
	if is_instance_valid(_preview):
		_preview.position = _base_position
	for part in _parts:
		if is_instance_valid(part["node"]):
			part["node"].position = part["position"]
			part["node"].rotation = part["rotation"]
	for leg in _legs:
		if is_instance_valid(leg.get("knee")):
			leg["knee"].rotation = leg.get("knee_base_rotation", Vector3.ZERO)


func sample(mode: String, time: float) -> void:
	if not is_instance_valid(_preview):
		return
	var moving: float = 1.0 if mode in ["walk", "run"] else 0.0
	var pace: float = 8.0 if mode == "run" else 4.6
	var phase: float = time * pace
	_preview.position = _base_position + Vector3.UP * (sin(time * 2.0) * 0.012 + absf(sin(phase)) * 0.035 * moving)
	for part in _parts:
		var node: Node3D = part["node"]
		if not is_instance_valid(node):
			continue
		node.position = part["position"]
		node.rotation = part["rotation"]
		var category: String = str(node.get_meta("creature_part_category", ""))
		var side: float = float(node.get_meta("creature_part_side", 1.0))
		if category == "tail":
			node.rotation.y += sin(time * 2.5) * 0.20
		elif category == "arms":
			node.rotation.x += sin(phase + side * PI * 0.5) * 0.32 * moving
		elif category in ["mouth", "eyes"]:
			node.rotation.x += sin(time * 1.8) * 0.025
	for leg in _legs:
		if not is_instance_valid(leg["root"]):
			continue
		var stride: float = phase + float(leg["phase"])
		leg["root"].rotation.x += cos(stride) * (0.50 if mode == "run" else 0.32) * moving
		if is_instance_valid(leg.get("knee")):
			leg["knee"].rotation = leg.get("knee_base_rotation", Vector3.ZERO)
			leg["knee"].rotation.x += maxf(0.0, sin(stride)) * 0.55 * moving
