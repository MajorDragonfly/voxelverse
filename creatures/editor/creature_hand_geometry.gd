extends RefCounted
## Pure hand geometry. Old recipes are retained exactly; new anatomy has one
## recipe shared by the voxel renderer and its historical block adapter.
const Catalog = preload("res://creatures/catalog/creature_hand_catalog.gd")


static func recipe(id: String, skin: Color, horn: Color, revision: int = 1) -> Array[Dictionary]:
	if Catalog.get_profile(id, revision).is_empty(): return []
	if id == "hands_crab_claws": return _crab(skin, horn)
	var result: Array[Dictionary] = []
	result.append(_piece("Palm", Vector3(0, -0.05, 0), Vector3(0.25, 0.22, 0.13), skin, true))
	if id == "hands_pincers":
		for side: float in [-1.0, 1.0]:
			result.append(_cone("Pincer%d" % int(side), Vector3(side * 0.10, -0.09, 0), Vector3(side * 0.045, -0.38, -0.07), 0.16, horn))
	else:
		for index in range(3):
			var start := Vector3(float(index - 1) * 0.083, -0.12, 0)
			var tip: Vector3 = start + Vector3(0, -0.17 - (0.03 if index == 1 else 0), -0.05)
			result.append(_bone("Finger%d" % index, start, tip, 0.065, skin))
			if id == "hands_claws":
				result.append(_cone("Nail%d" % index, tip, tip + Vector3(0, -0.075, -0.055), 0.050, horn))
		result.append(_bone("Thumb", Vector3(-0.10, -0.055, 0), Vector3(-0.19, -0.18, -0.055), 0.08, skin))
	return result


static func legacy_voxels(id: String, revision: int = 1) -> Array:
	if Catalog.get_profile(id, revision).is_empty(): return []
	if id == "hands_crab_claws":
		return _legacy_from_recipe(recipe(id, Color("8fb39b"), Color("e5d5ab"), revision))
	var skin := Color("8fb39b")
	var horn := Color("e5d5ab")
	var voxels: Array = []
	if id == "hands_pincers":
		voxels.append(_voxel(Vector3.ZERO, Vector3(0.22, 0.17, 0.06), skin))
		for side: float in [-1.0, 1.0]:
			voxels.append(_voxel(Vector3(side * 0.14, -0.15, 0), Vector3(0.075, 0.22, 0.055), horn))
			voxels.append(_voxel(Vector3(side * 0.095, -0.27, 0), Vector3(0.07, 0.055, 0.04), horn))
	else:
		voxels.append(_voxel(Vector3.ZERO, Vector3(0.29, 0.21, 0.055), skin))
		for index in range(3):
			var tip := Vector3(float(index - 1) * 0.13, -0.21, 0)
			voxels.append(_voxel(tip, Vector3(0.06, 0.18, 0.035), skin.lightened(0.12)))
			if id == "hands_claws":
				voxels.append(_voxel(tip + Vector3.DOWN * 0.13, Vector3(0.045, 0.095, 0.025), horn))
		voxels.append(_voxel(Vector3(-0.22, -0.075, 0), Vector3(0.09, 0.07, 0.04), skin))
	return voxels


static func _crab(skin: Color, horn: Color) -> Array[Dictionary]:
	var shell: Color = skin.darkened(0.10)
	var result: Array[Dictionary] = [
		_piece("CrabWrist", Vector3(0, 0.07, 0), Vector3(0.19, 0.18, 0.18), skin, true),
		_piece("CrabPalm", Vector3(0, -0.08, 0), Vector3(0.40, 0.30, 0.23), shell, true),
		_piece("CarapaceRidge", Vector3(-0.02, -0.075, -0.10), Vector3(0.29, 0.21, 0.07), skin.lightened(0.10), true),
		_piece("FixedKnuckle", Vector3(-0.15, -0.17, 0), Vector3(0.18, 0.17, 0.20), shell, true),
		_piece("MovableHinge", Vector3(0.16, -0.17, 0), Vector3(0.17, 0.17, 0.18), skin.lightened(0.12), true),
		_bone("FixedFinger", Vector3(-0.14, -0.17, 0), Vector3(-0.25, -0.34, -0.01), 0.16, shell),
		_cone("FixedTip", Vector3(-0.25, -0.33, -0.01), Vector3(-0.045, -0.62, -0.02), 0.18, horn.darkened(0.24)),
		_bone("MovableFinger", Vector3(0.15, -0.18, 0), Vector3(0.24, -0.33, -0.01), 0.13, skin),
		_cone("MovableTip", Vector3(0.24, -0.32, -0.01), Vector3(0.09, -0.59, -0.02), 0.145, horn.darkened(0.12)),
	]
	for index in range(3):
		var y: float = -0.35 - float(index) * 0.057
		var left: float = -0.17 + float(index) * 0.035
		var right: float = 0.175 - float(index) * 0.022
		result.append(_cone("FixedTooth%d" % index, Vector3(left, y, -0.02), Vector3(left + 0.062, y - 0.018, -0.02), 0.055, horn))
		result.append(_cone("MovableTooth%d" % index, Vector3(right, y - 0.02, -0.02), Vector3(right - 0.055, y - 0.033, -0.02), 0.045, horn))
	return result


static func _legacy_from_recipe(parts: Array[Dictionary]) -> Array:
	var result: Array = []
	for part: Dictionary in parts:
		if part.kind in ["cone", "bone"]:
			result.append(_voxel((part.start + part.end) * 0.5, (part.end - part.start).abs() + Vector3.ONE * float(part.width), part.color))
		else:
			result.append(_voxel(part.position, part.size, part.color))
	return result


static func _piece(name: String, position: Vector3, size: Vector3, color: Color, skin: bool = false) -> Dictionary:
	return {"kind": "piece", "name": name, "position": position, "size": size, "color": color, "skin": skin}


static func _cone(name: String, start: Vector3, end: Vector3, width: float, color: Color) -> Dictionary:
	return {"kind": "cone", "name": name, "start": start, "end": end, "width": width, "color": color}


static func _bone(name: String, start: Vector3, end: Vector3, width: float, color: Color) -> Dictionary:
	return {"kind": "bone", "name": name, "start": start, "end": end, "width": width, "color": color, "skin": true}


static func _voxel(position: Vector3, size: Vector3, color: Color) -> Dictionary:
	return {"position": position, "size": size, "color": color}
