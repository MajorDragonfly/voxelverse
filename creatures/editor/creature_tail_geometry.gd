extends RefCounted
## Shared revision-1 recipes for workshop, journal and moving creature bodies.
## The four shipped recipes retain their exact meshes, ordering and materials.
const Catalog = preload("res://creatures/catalog/creature_tail_catalog.gd")


static func recipe(id: String, skin: Color, accent: Color, horn: Color, revision: int = 1) -> Array[Dictionary]:
	if Catalog.get_profile(id, revision).is_empty(): return []
	if id in Catalog.LEGACY_IDS: return _legacy(id, skin, accent, horn)
	match id:
		"tail_stump": return [
			_piece("StumpRoot", Vector3(0, 0, 0.06), Vector3(0.26, 0.25, 0.24), skin),
			_piece("StumpTip", Vector3(0, 0.025, 0.20), Vector3(0.22, 0.20, 0.22), skin),
		]
		"tail_reptile": return _reptile(skin, accent)
		"tail_beaver_paddle": return _paddle(skin, accent)
		"tail_horizontal_fluke": return _fluke(skin)
	return []


static func _legacy(id: String, skin: Color, accent: Color, horn: Color) -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		_bone("TailBase", Vector3(0, 0, -0.02), Vector3(0, -0.025, 0.38), 0.23, skin),
		_bone("TailTip", Vector3(0, -0.025, 0.35), Vector3(0, 0.04, 0.78), 0.14, skin),
	]
	if id == "tail_club":
		result.append(_piece("TailClub", Vector3(0, 0.04, 0.77), Vector3(0.47, 0.39, 0.47), accent))
	elif id == "tail_fin":
		result.append(_piece("TailFin", Vector3(0, 0.14, 0.72), Vector3(0.08, 0.60, 0.42), accent))
		for index in range(3):
			result.append(_bone("FinRay%d" % index, Vector3(0, 0, 0.55), Vector3(0, float(index - 1) * 0.22 + 0.14, 0.85), 0.025, skin.lightened(0.25)))
	elif id == "tail_stinger":
		result.append(_cone("Stinger", Vector3(0, 0.04, 0.73), Vector3(0, 0.25, 1.01), 0.24, horn))
	else:
		result.append(_cone("TailPoint", Vector3(0, 0.04, 0.72), Vector3(0, 0.12, 1.0), 0.14, skin))
	return result


static func _reptile(skin: Color, accent: Color) -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		_piece("ReptileRoot", Vector3(0, 0, 0.12), Vector3(0.42, 0.32, 0.40), skin),
		_bone("ReptileBase", Vector3(0, 0, 0.18), Vector3(0, -0.02, 0.57), 0.29, skin),
		_bone("ReptileMiddle", Vector3(0, -0.02, 0.54), Vector3(0.10, 0.01, 0.93), 0.21, skin),
		_bone("ReptileBend", Vector3(0.10, 0.01, 0.90), Vector3(0.24, 0.08, 1.22), 0.13, skin),
		_cone("ReptileTip", Vector3(0.24, 0.08, 1.17), Vector3(0.39, 0.12, 1.48), 0.16, skin),
	]
	for index in range(4):
		var t: float = float(index)
		result.append(_piece("DorsalScale%d" % index, Vector3(maxf(0, t - 1) * 0.055, 0.145 - t * 0.025, 0.16 + t * 0.24), Vector3(0.10 - t * 0.012, 0.075, 0.14), accent))
	return result


static func _paddle(skin: Color, accent: Color) -> Array[Dictionary]:
	var paddle: Color = skin.lerp(accent, 0.55)
	var result: Array[Dictionary] = [
		_bone("PaddleRoot", Vector3(0, 0, -0.02), Vector3(0, -0.01, 0.42), 0.21, skin),
		_piece("PaddleNeck", Vector3(0, -0.005, 0.43), Vector3(0.30, 0.17, 0.32), skin),
		_piece("PaddleBase", Vector3(0, 0, 0.70), Vector3(0.50, 0.13, 0.57), paddle),
		_piece("PaddleBlade", Vector3(0, 0, 0.90), Vector3(0.65, 0.12, 0.52), paddle),
		_piece("PaddleTip", Vector3(0, 0, 1.075), Vector3(0.50, 0.10, 0.25), paddle),
	]
	for side: float in [-1.0, 1.0]:
		for index in range(3):
			result.append(_piece("PaddleScale%d_%d" % [int(side), index], Vector3(side * 0.105, 0.061, 0.68 + float(index) * 0.14), Vector3(0.14, 0.022, 0.12), paddle.darkened(0.18)))
	return result


static func _fluke(skin: Color) -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		_bone("FlukeRoot", Vector3(0, 0, -0.02), Vector3(0, 0.025, 0.55), 0.21, skin),
		_piece("FlukeNeck", Vector3(0, 0.025, 0.52), Vector3(0.24, 0.19, 0.27), skin),
	]
	for side: float in [-1.0, 1.0]:
		var suffix: String = "Left" if side < 0 else "Right"
		result.append(_piece("FlukeLobe" + suffix, Vector3(side * 0.19, 0.025, 0.73), Vector3(0.43, 0.13, 0.42), skin))
		result.append(_piece("FlukeOuter" + suffix, Vector3(side * 0.40, 0.025, 0.73), Vector3(0.35, 0.09, 0.30), skin))
		result.append(_piece("FlukeTip" + suffix, Vector3(side * 0.56, 0.025, 0.65), Vector3(0.22, 0.065, 0.16), skin))
	return result


static func legacy_voxels(id: String, revision: int = 1) -> Array:
	var result: Array = []
	for part: Dictionary in recipe(id, Color("8fb39b"), Color("426058"), Color("e5d5ab"), revision):
		if part.kind in ["bone", "cone"]:
			result.append({"position": (part.start + part.end) * 0.5,
				"size": (part.end - part.start).abs() + Vector3.ONE * float(part.width), "color": part.color})
		else:
			result.append({"position": part.position, "size": part.size, "color": part.color})
	return result


static func _piece(name: String, position: Vector3, size: Vector3, color: Color) -> Dictionary:
	return {"kind": "piece", "name": name, "position": position, "size": size, "color": color, "skin": true}


static func _bone(name: String, start: Vector3, end: Vector3, width: float, color: Color) -> Dictionary:
	return {"kind": "bone", "name": name, "start": start, "end": end, "width": width, "color": color, "skin": true}


static func _cone(name: String, start: Vector3, end: Vector3, width: float, color: Color) -> Dictionary:
	return {"kind": "cone", "name": name, "start": start, "end": end, "width": width, "color": color}
