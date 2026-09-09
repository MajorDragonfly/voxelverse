extends RefCounted
## Authored voxel anatomy, with explicit directions instead of treating every
## detail as an upright cone. End pieces belong to their moving limb socket.
const Surface = preload("res://creatures/editor/creature_sculpt_surface.gd")
const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
const Skin = preload("res://creatures/editor/creature_skin_style.gd")
const Rig = preload("res://creatures/runtime/creature_limb_rig.gd")


static func build(root: Node3D, definition: Dictionary, placement: Dictionary, blueprint: Dictionary) -> void:
	root.set_meta("part_shape", Blueprint.get_part_shape(placement))
	root.set_meta("skin_blueprint", blueprint)
	var id: String = str(definition["id"])
	var category: String = str(placement["category"])
	var skin: Color = Surface.colors(blueprint)[0]
	var accent: Color = Surface.colors(blueprint)[1]
	var horn: Color = Skin.color(blueprint, "horn_color", Color("e3d5b0"))
	match category:
		"legs", "arms":
			_limb(root, id, placement, blueprint)
		"eyes":
			var size := Vector3(0.25, 0.25, 0.23)
			if id == "eyes_wide":
				size = Vector3(0.34, 0.30, 0.23)
			if id == "eyes_stalks":
				_bone(root, "EyeStalk", Vector3.ZERO, Vector3(0, 0.32, 0), 0.085, skin)
				_eye(root, Vector3(0, 0.34, -0.02), size, blueprint, "StalkEye")
			elif id == "eyes_cluster":
				for index in range(3):
					_eye(root, Vector3(float(index - 1) * 0.13, 0.07 if index != 1 else -0.07, 0), size * 0.64, blueprint, "Eye%d" % index)
			else:
				_eye(root, Vector3.ZERO, size, blueprint, "Eye")
		"mouth":
			if id == "mouth_broad_beak":
				_cone(root, "UpperBeak", Vector3(0, 0.03, 0.04), Vector3(0, 0.0, -0.48), 0.43, horn)
				_cone(root, "LowerBeak", Vector3(0, -0.095, 0.02), Vector3(0, -0.075, -0.39), 0.32, horn.darkened(0.16))
			else:
				var long_snout: bool = id == "mouth_filter_snout"
				var predator: bool = id == "mouth_predator_jaws"
				var length: float = 0.68 if long_snout else 0.38
				_piece(root, "Muzzle", Vector3(0, 0.025, -length * 0.35), Vector3(0.35 if long_snout else 0.60, 0.24, length), skin, true)
				_piece(root, "MouthLine", Vector3(0, -0.085, -length * 0.65), Vector3(0.36 if long_snout else 0.50, 0.035, length * 0.6), Color("23312c"))
				_piece(root, "LowerJaw", Vector3(0, -0.145, -length * 0.4), Vector3(0.36 if long_snout else 0.54, 0.10, length * 0.95), skin.darkened(0.12), true)
				for side: float in [-1.0, 1.0]:
					_piece(root, "Nostril%d" % int(side), Vector3(side * (0.11 if long_snout else 0.18), 0.09, -length * 0.70), Vector3(0.055, 0.045, 0.045), accent.darkened(0.45))
				if predator:
					for index in range(4):
						_cone(root, "Tooth%d" % index, Vector3(float(index) * 0.13 - 0.195, -0.035, -0.28), Vector3(float(index) * 0.13 - 0.195, -0.16, -0.29), 0.075, horn)
		"tail":
			_bone(root, "TailBase", Vector3(0, 0, -0.02), Vector3(0, -0.025, 0.38), 0.23, skin)
			_bone(root, "TailTip", Vector3(0, -0.025, 0.35), Vector3(0, 0.04, 0.78), 0.14, skin)
			if id == "tail_club":
				_piece(root, "TailClub", Vector3(0, 0.04, 0.77), Vector3(0.47, 0.39, 0.47), accent, true)
			elif id == "tail_fin":
				_piece(root, "TailFin", Vector3(0, 0.14, 0.72), Vector3(0.08, 0.60, 0.42), accent, true)
				for index in range(3):
					_bone(root, "FinRay%d" % index, Vector3(0, 0, 0.55), Vector3(0, float(index - 1) * 0.22 + 0.14, 0.85), 0.025, skin.lightened(0.25))
			elif id == "tail_stinger":
				_cone(root, "Stinger", Vector3(0, 0.04, 0.73), Vector3(0, 0.25, 1.01), 0.24, horn)
			else:
				_cone(root, "TailPoint", Vector3(0, 0.04, 0.72), Vector3(0, 0.12, 1.0), 0.14, skin)
		"horns":
			_piece(root, "HornSocket", Vector3(0, 0.015, 0), Vector3(0.25, 0.10, 0.23), skin, true)
			if id == "horns_antlers":
				_bone(root, "AntlerStem", Vector3.ZERO, Vector3(0.14, 0.46, 0.02), 0.105, horn, false)
				for index in range(3):
					var start := Vector3(0.07 + float(index) * 0.03, 0.18 + float(index) * 0.13, 0.01)
					_cone(root, "AntlerBranch%d" % index, start, start + Vector3(0.19, 0.22, -0.07 - float(index) * 0.02), 0.09, horn)
				_cone(root, "AntlerTip", Vector3(0.14, 0.44, 0.02), Vector3(0.18, 0.75, -0.07), 0.10, horn)
			elif id == "horns_crest":
				for index in range(3):
					_cone(root, "Crest%d" % index, Vector3(0, 0, float(index) * 0.12), Vector3(0, 0.54 - float(index) * 0.08, float(index) * 0.12 - 0.10), 0.17, horn)
			else:
				_bone(root, "HornBase", Vector3.ZERO, Vector3(0, 0.22, -0.03), 0.14, horn, false)
				_cone(root, "HornTip", Vector3(0, 0.18, -0.025), Vector3(0, 0.51, -0.16), 0.15, horn)
		"spikes":
			for index in range(3):
				var base := Vector3(0, 0, float(index - 1) * 0.31)
				_piece(root, "SpikeSocket%d" % index, base, Vector3(0.19, 0.085, 0.21), skin, true)
				var direction := Vector3(0.44, 0.08, -0.05) if id == "spikes_side" else Vector3(0.025, 0.38 + (0.12 if index == 1 else 0), -0.09)
				_cone(root, "Spike%d" % index, base, base + direction, 0.16, horn)
		"plates":
			for index in range(3 if id == "plates_dorsal" else 4):
				var position := Vector3(0, 0.16, float(index - 1) * 0.30) if id == "plates_dorsal" else Vector3(-0.18 if index % 2 == 0 else 0.18, 0.045, -0.18 if index < 2 else 0.18)
				var size := Vector3(0.12, 0.43, 0.30) if id == "plates_dorsal" else Vector3(0.42, 0.19, 0.44)
				_piece(root, "Armor%d" % index, position, size, accent, true)
				_piece(root, "ArmorRidge%d" % index, position + Vector3(0, size.y * 0.27, 0), size * Vector3(0.68, 0.48, 0.80), skin.lightened(0.12), true)
		"decor":
			for index in range(3):
				var position := Vector3(float(index - 1) * 0.16, 0.18 + (0.05 if index == 1 else 0), 0)
				var color: Color = skin.lerp(accent, float(index) * 0.4)
				if id == "decor_crystals":
					_piece(root, "Crystal%d" % index, position, Vector3(0.19, 0.46, 0.19), color, false, "diamond")
				else:
					_piece(root, "Feather%d" % index, position, Vector3(0.11, 0.49, 0.055), color, true)
					_bone(root, "FeatherStem%d" % index, position - Vector3.UP * 0.23, position + Vector3.UP * 0.22, 0.024, horn, false)


static func _eye(root: Node3D, position: Vector3, size: Vector3, blueprint: Dictionary, prefix: String) -> void:
	var iris: Color = Skin.color(blueprint, "eye_color", Surface.colors(blueprint)[1].lightened(0.15))
	_piece(root, prefix + "Sclera", position, size, Color("f4eedf"))
	_piece(root, prefix + "Iris", position + Vector3(0, 0, -size.z * 0.43), size * Vector3(0.67, 0.71, 0.27), iris)
	_piece(root, prefix + "Pupil", position + Vector3(0, 0, -size.z * 0.54), size * Vector3(0.32, 0.44, 0.14), Color("0e1b22"))
	_piece(root, prefix + "Glint", position + Vector3(-size.x * 0.08, size.y * 0.12, -size.z * 0.59), size * 0.12, Color.WHITE)
	_piece(root, prefix + "Lid", position + Vector3(0, size.y * 0.39, 0.01), size * Vector3(1.06, 0.19, 0.90), Surface.colors(blueprint)[0], true)


static func _limb(root: Node3D, id: String, placement: Dictionary, blueprint: Dictionary) -> void:
	var is_leg: bool = str(placement["category"]) == "legs"
	var shape: Vector3 = Blueprint.get_part_shape(placement)
	var length: float = {"legs_stubby": 0.43, "legs_walker": 0.64, "legs_sprinter": 0.85, "legs_spider": 0.68, "legs_hoof": 0.77, "arms_grasping": 0.52, "arms_climber": 0.77, "arms_claws": 0.60}.get(id, 0.62)
	length *= shape.y
	var width: float = (0.22 if id == "legs_stubby" else 0.15) * shape.x
	var ankle := Vector3((0.36 if id == "legs_spider" else 0.0) * shape.x * float(root.get_meta("creature_part_side", 1.0)), -length, -0.055 * shape.z)
	var knee := Node3D.new()
	knee.name = "RuntimeKneePivot"
	knee.position = ankle * 0.5 + Vector3(0, 0, length * 0.20)
	root.add_child(knee)
	var skin: Color = Surface.colors(blueprint)[0]
	var upper: MeshInstance3D = Surface.bone(root, "UpperLimb", Vector3.ZERO, knee.position, width, skin)
	var lower: MeshInstance3D = Surface.bone(knee, "LowerLimb", Vector3.ZERO, ankle - knee.position, width * 0.82, skin.darkened(0.05))
	upper.material_override = Surface.material(skin, true, blueprint)
	lower.material_override = Surface.material(skin.darkened(0.05), true, blueprint)
	var joint: MeshInstance3D = Surface.ellipsoid(root, "Joint", knee.position, Vector3.ONE * width * 1.16, skin)
	joint.material_override = Surface.material(skin, true, blueprint)
	var socket := Node3D.new()
	socket.name = "LimbEnd"
	socket.position = ankle - knee.position
	socket.set_meta("creature_part_side", root.get_meta("creature_part_side", 1.0))
	socket.set_meta("part_shape", Blueprint.get_part_shape(placement, "end_shape_scale") * float(placement.get("end_scale", 1.0)))
	socket.set_meta("skin_blueprint", blueprint)
	knee.add_child(socket)
	var default_end: String = ("feet_hooves" if id == "legs_hoof" else ("feet_claws" if id in ["legs_spider", "legs_sprinter"] else "feet_pads")) if is_leg else ("hands_claws" if id == "arms_claws" else "hands_grasp")
	var end_id: String = str(placement.get("end_part_id", ""))
	_terminal(socket, default_end if end_id.is_empty() else end_id, skin, Skin.color(blueprint, "horn_color", Color("d7cba9")))
	var rotation: Vector3 = Blueprint._as_vector3(placement.get("end_rotation", Vector3.ZERO)) * Vector3(1, float(root.get_meta("creature_part_side", 1.0)), float(root.get_meta("creature_part_side", 1.0)))
	Rig.configure(root, upper, lower, knee, joint, socket, width, rotation * PI / 180.0)


static func _terminal(root: Node3D, id: String, skin: Color, horn: Color) -> void:
	if id == "feet_hooves":
		for side: float in [-1.0, 1.0]:
			_piece(root, "Hoof%d" % int(side), Vector3(side * 0.08, -0.055, -0.035), Vector3(0.14, 0.16, 0.29), horn.darkened(0.42))
	elif id.begins_with("feet_"):
		_piece(root, "FootPad", Vector3(0, -0.015, -0.055), Vector3(0.31, 0.15, 0.32), skin, true)
		if id == "feet_webbed":
			_piece(root, "Webbing", Vector3(0, -0.055, -0.15), Vector3(0.41, 0.045, 0.28), skin.lightened(0.18), true)
		for index in range(3):
			var point := Vector3(float(index - 1) * 0.115, -0.045, -0.18)
			_piece(root, "Toe%d" % index, point, Vector3(0.10, 0.09, 0.16), skin, true)
			if id == "feet_claws":
				_cone(root, "Claw%d" % index, point - Vector3(0, 0, 0.015), point + Vector3(0, -0.008, -0.16), 0.062, horn)
	else:
		_piece(root, "Palm", Vector3(0, -0.05, 0), Vector3(0.25, 0.22, 0.13), skin, true)
		if id == "hands_pincers":
			for side: float in [-1.0, 1.0]:
				_cone(root, "Pincer%d" % int(side), Vector3(side * 0.10, -0.09, 0), Vector3(side * 0.045, -0.38, -0.07), 0.16, horn)
		else:
			for index in range(3):
				var start := Vector3(float(index - 1) * 0.083, -0.12, 0)
				var tip: Vector3 = start + Vector3(0, -0.17 - (0.03 if index == 1 else 0), -0.05)
				_bone(root, "Finger%d" % index, start, tip, 0.065, skin)
				if id == "hands_claws":
					_cone(root, "Nail%d" % index, tip, tip + Vector3(0, -0.075, -0.055), 0.050, horn)
			_bone(root, "Thumb", Vector3(-0.10, -0.055, 0), Vector3(-0.19, -0.18, -0.055), 0.08, skin)


static func _point(root: Node3D, point: Vector3) -> Vector3:
	var result: Vector3 = point * root.get_meta("part_shape", Vector3.ONE)
	result.x *= float(root.get_meta("creature_part_side", 1.0))
	return result


static func _piece(root: Node3D, name: String, position: Vector3, size: Vector3, color: Color, skin: bool = false, kind: String = "ellipsoid") -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.position = _point(root, position)
	node.mesh = Surface.Voxels.primitive(size * root.get_meta("part_shape", Vector3.ONE), kind)
	node.material_override = Surface.material(color, true, root.get_meta("skin_blueprint", {}) if skin else {})
	root.add_child(node)
	return node


static func _bone(root: Node3D, name: String, start: Vector3, end: Vector3, width: float, color: Color, skin: bool = true) -> void:
	var shape: Vector3 = root.get_meta("part_shape", Vector3.ONE)
	var node: MeshInstance3D = Surface.bone(root, name, _point(root, start), _point(root, end), width * minf(shape.x, shape.z), color)
	node.material_override = Surface.material(color, true, root.get_meta("skin_blueprint", {}) if skin else {})


static func _cone(root: Node3D, name: String, base: Vector3, tip: Vector3, width: float, color: Color) -> void:
	var start: Vector3 = _point(root, base)
	var end: Vector3 = _point(root, tip)
	var shape: Vector3 = root.get_meta("part_shape", Vector3.ONE)
	var node := MeshInstance3D.new()
	node.name = name
	node.position = (start + end) * 0.5
	node.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	node.mesh = Surface.Voxels.primitive(Vector3(width * shape.x, start.distance_to(end), width * shape.z), "cone")
	node.material_override = Surface.material(color, true)
	root.add_child(node)
