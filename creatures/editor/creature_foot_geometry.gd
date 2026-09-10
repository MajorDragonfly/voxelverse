extends RefCounted
## Revision 1 recipes preserve both shipped sculpted feet and the historical
## block adapter. No catalog stats, progression, role or save writes here.
const Catalog = preload("res://creatures/catalog/creature_foot_catalog.gd")


static func recipe(part_id: String, skin: Color, horn: Color, revision: int = 1) -> Array[Dictionary]:
	if Catalog.get_profile(part_id, revision).is_empty(): return []
	var result: Array[Dictionary] = []
	if part_id == "feet_hooves":
		for side: float in [-1.0, 1.0]:
			result.append(_piece("Hoof%d" % int(side), Vector3(side * 0.08, -0.055, -0.035), Vector3(0.14, 0.16, 0.29), horn.darkened(0.42)))
		return result
	result.append(_piece("FootPad", Vector3(0, -0.015, -0.055), Vector3(0.31, 0.15, 0.32), skin, true))
	if part_id == "feet_webbed":
		result.append(_piece("Webbing", Vector3(0, -0.055, -0.15), Vector3(0.41, 0.045, 0.28), skin.lightened(0.18), true))
	for index in range(3):
		var point := Vector3(float(index - 1) * 0.115, -0.045, -0.18)
		result.append(_piece("Toe%d" % index, point, Vector3(0.10, 0.09, 0.16), skin, true))
		if part_id == "feet_claws":
			result.append({"kind": "cone", "name": "Claw%d" % index,
				"start": point - Vector3(0, 0, 0.015), "end": point + Vector3(0, -0.008, -0.16), "width": 0.062, "color": horn})
	return result


static func legacy_voxels(part_id: String, revision: int = 1) -> Array:
	if Catalog.get_profile(part_id, revision).is_empty(): return []
	var skin := Color("8fb39b")
	var horn := Color("e5d5ab")
	var result: Array = []
	if part_id == "feet_hooves":
		for side: float in [-1.0, 1.0]:
			result.append(_voxel(Vector3(side * 0.095, -0.04, -0.04), Vector3(0.14, 0.17, 0.22), horn.darkened(0.32)))
		return result
	result.append(_voxel(Vector3.ZERO, Vector3(0.29, 0.10, 0.18), skin))
	if part_id == "feet_webbed":
		result.append(_voxel(Vector3(0, -0.02, -0.15), Vector3(0.44, 0.035, 0.23), skin.lightened(0.3)))
	for index in range(3):
		var tip := Vector3(float(index - 1) * 0.13, -0.035, -0.17)
		result.append(_voxel(tip, Vector3(0.06, 0.065, 0.15), skin.lightened(0.12)))
		if part_id == "feet_claws":
			result.append(_voxel(tip + Vector3.FORWARD * 0.13, Vector3(0.045, 0.045, 0.13), horn))
	return result


static func _piece(name: String, position: Vector3, size: Vector3, color: Color, skin: bool = false) -> Dictionary:
	return {"kind": "piece", "name": name, "position": position, "size": size, "color": color, "skin": skin}


static func _voxel(position: Vector3, size: Vector3, color: Color) -> Dictionary:
	return {"position": position, "size": size, "color": color}
