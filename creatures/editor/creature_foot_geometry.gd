extends RefCounted
## Revision 1 recipes preserve both shipped sculpted feet and the historical
## block adapter. No catalog stats, progression, role or save writes here.
const Catalog = preload("res://creatures/catalog/creature_foot_catalog.gd")


static func recipe(part_id: String, skin: Color, horn: Color, revision: int = 1) -> Array[Dictionary]:
	if Catalog.get_profile(part_id, revision).is_empty(): return []
	match part_id:
		"feet_feline_paws": return _feline(skin)
		"feet_bear_paws": return _bear(skin, horn)
		"feet_horse_hooves": return _horse(skin, horn)
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
	if part_id in ["feet_feline_paws", "feet_bear_paws", "feet_horse_hooves"]:
		return _legacy_from_recipe(recipe(part_id, skin, horn, revision))
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


static func _feline(skin: Color) -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		_piece("PawPalm", Vector3(0, -0.005, -0.035), Vector3(0.29, 0.17, 0.26), skin, true),
		_piece("PawHeel", Vector3(0, 0.045, 0.055), Vector3(0.21, 0.19, 0.19), skin, true),
		_piece("CentralPad", Vector3(0, -0.09, -0.025), Vector3(0.19, 0.05, 0.16), skin.darkened(0.38)),
	]
	for index in range(4):
		var outside: bool = index == 0 or index == 3
		var point := Vector3((float(index) - 1.5) * 0.09, -0.035, -0.14 if outside else -0.18)
		result.append(_piece("PawToe%d" % index, point, Vector3(0.10, 0.13, 0.16), skin, true))
		result.append(_piece("ToePad%d" % index, point + Vector3(0, -0.065, 0.005), Vector3(0.063, 0.03, 0.09), skin.darkened(0.38)))
	return result


static func _bear(skin: Color, horn: Color) -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		_piece("BearPalm", Vector3(0, -0.015, -0.07), Vector3(0.48, 0.20, 0.40), skin, true),
		_piece("BearHeel", Vector3(0, 0.035, 0.11), Vector3(0.33, 0.24, 0.29), skin, true),
		_piece("BearSole", Vector3(0, -0.11, -0.055), Vector3(0.34, 0.045, 0.32), skin.darkened(0.42)),
	]
	for index in range(5):
		var point := Vector3(float(index - 2) * 0.103, -0.035, -0.27 + absf(float(index - 2)) * 0.026)
		result.append(_piece("BearToe%d" % index, point, Vector3(0.113, 0.15, 0.21), skin, true))
		result.append({"kind": "cone", "name": "BearClaw%d" % index,
			"start": point + Vector3(0, 0.015, -0.065), "end": point + Vector3(0, -0.035, -0.21), "width": 0.065, "color": horn})
	return result


static func _horse(skin: Color, horn: Color) -> Array[Dictionary]:
	# One continuous hoof wall, unlike the retained cloven hoof pair.
	return [
		_piece("Pastern", Vector3(0, 0.055, 0.025), Vector3(0.19, 0.24, 0.21), skin, true),
		_piece("HoofWall", Vector3(0, -0.065, -0.045), Vector3(0.34, 0.26, 0.40), horn.darkened(0.52)),
		_piece("HoofToe", Vector3(0, -0.105, -0.13), Vector3(0.34, 0.14, 0.25), horn.darkened(0.46)),
		_piece("Coronet", Vector3(0, 0.05, -0.025), Vector3(0.28, 0.10, 0.32), skin.darkened(0.15), true),
		_piece("HoofSole", Vector3(0, -0.185, -0.06), Vector3(0.285, 0.035, 0.34), horn.darkened(0.68)),
	]


static func _legacy_from_recipe(parts: Array[Dictionary]) -> Array:
	# Only the historical block adapter needs boxes. New anatomy has one source.
	var result: Array = []
	for part: Dictionary in parts:
		if part.kind == "cone":
			var delta: Vector3 = (part.end - part.start).abs()
			result.append(_voxel((part.start + part.end) * 0.5, delta + Vector3.ONE * float(part.width), part.color))
		else:
			result.append(_voxel(part.position, part.size, part.color))
	return result


static func _piece(name: String, position: Vector3, size: Vector3, color: Color, skin: bool = false) -> Dictionary:
	return {"kind": "piece", "name": name, "position": position, "size": size, "color": color, "skin": skin}


static func _voxel(position: Vector3, size: Vector3, color: Color) -> Dictionary:
	return {"position": position, "size": size, "color": color}
