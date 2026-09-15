extends RefCounted
## Authored mouth recipes shared by workshop, journal and runtime. Opening is a
## fixed model pose; it grants no underwater breathing or independent jaw action.
const Catalog = preload("res://creatures/catalog/creature_mouth_catalog.gd")


static func recipe(id: String, skin: Color, accent: Color, horn: Color, revision: int = 1) -> Array[Dictionary]:
	if Catalog.get_profile(id, revision).is_empty(): return []
	match id:
		"mouth_canine_snout": return _canine(skin, accent, horn)
		"mouth_crocodile_snout": return _crocodile(skin, accent, horn)
		"mouth_octopus_beak": return _octopus(skin, accent, horn)
	return []


static func legacy_voxels(id: String, revision: int = 1) -> Array:
	var result: Array = []
	for part: Dictionary in recipe(id, Color("8fb39b"), Color("426058"), Color("e5d5ab"), revision):
		if part.kind == "cone":
			result.append({"position": (part.start + part.end) * 0.5,
				"size": (part.end - part.start).abs() + Vector3.ONE * float(part.width), "color": part.color})
		else:
			result.append({"position": part.position, "size": part.size, "color": part.color})
	return result


static func _canine(skin: Color, accent: Color, horn: Color) -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		_piece("MuzzleBase", Vector3(0, 0.035, -0.12), Vector3(0.57, 0.30, 0.38), skin, true),
		_piece("MuzzleBridge", Vector3(0, 0.055, -0.35), Vector3(0.37, 0.22, 0.44), skin, true),
		_piece("Nose", Vector3(0, 0.04, -0.575), Vector3(0.28, 0.14, 0.12), accent.darkened(0.55)),
		_piece("MouthCavity", Vector3(0, -0.086, -0.33), Vector3(0.39, 0.075, 0.45), Color("172a29")),
		_piece("LowerJaw", Vector3(0, -0.17, -0.28), Vector3(0.39, 0.105, 0.53), skin.darkened(0.12), true),
	]
	for side: float in [-1.0, 1.0]:
		var suffix: String = "Left" if side < 0 else "Right"
		result.append(_piece("Lip" + suffix, Vector3(side * 0.16, -0.01, -0.37), Vector3(0.12, 0.11, 0.32), skin.lightened(0.06), true))
		result.append(_piece("Nostril" + suffix, Vector3(side * 0.072, 0.04, -0.63), Vector3(0.055, 0.045, 0.027), Color("111f22")))
		result.append(_cone("Canine" + suffix, Vector3(side * 0.18, -0.035, -0.30), Vector3(side * 0.16, -0.16, -0.32), 0.065, horn))
	return result


static func _crocodile(skin: Color, accent: Color, horn: Color) -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		_piece("SnoutBase", Vector3(0, 0.03, -0.14), Vector3(0.62, 0.23, 0.40), skin, true),
		_piece("SnoutBridge", Vector3(0, 0.035, -0.49), Vector3(0.47, 0.16, 0.71), skin, true),
		_piece("SnoutTip", Vector3(0, 0.045, -0.80), Vector3(0.39, 0.16, 0.28), skin.lightened(0.06), true),
		_piece("MouthCavity", Vector3(0, -0.084, -0.47), Vector3(0.45, 0.10, 0.78), Color("172a29")),
		_piece("LowerJaw", Vector3(0, -0.19, -0.45), Vector3(0.43, 0.11, 0.87), skin.darkened(0.12), true),
	]
	for side: float in [-1.0, 1.0]:
		var suffix: String = "Left" if side < 0 else "Right"
		result.append(_piece("NostrilRidge" + suffix, Vector3(side * 0.105, 0.115, -0.79), Vector3(0.125, 0.09, 0.15), skin, true))
		result.append(_piece("Nostril" + suffix, Vector3(side * 0.105, 0.153, -0.82), Vector3(0.055, 0.025, 0.055), accent.darkened(0.6)))
		for index in range(4):
			var z: float = -0.22 - float(index) * 0.155
			var x: float = side * (0.23 - float(index) * 0.018)
			result.append(_cone("UpperTooth%s%d" % [suffix, index], Vector3(x, -0.005, z), Vector3(x, -0.13, z - 0.018), 0.064, horn))
			result.append(_cone("LowerTooth%s%d" % [suffix, index], Vector3(x * 0.92, -0.175, z - 0.07), Vector3(x * 0.92, -0.075, z - 0.05), 0.055, horn))
	return result


static func _octopus(skin: Color, accent: Color, horn: Color) -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		# Recessed dark backing, leaving the inner hooked beak clearly exposed.
		_piece("MouthCavity", Vector3(0, 0, -0.13), Vector3(0.49, 0.49, 0.13), Color("172a29")),
		_piece("UpperBeakBase", Vector3(0, 0.09, -0.225), Vector3(0.19, 0.13, 0.17), horn.darkened(0.38)),
		_cone("UpperBeakHook", Vector3(0, 0.10, -0.255), Vector3(0, -0.035, -0.375), 0.18, horn.darkened(0.30)),
		_piece("LowerBeakBase", Vector3(0, -0.10, -0.20), Vector3(0.17, 0.11, 0.14), horn.darkened(0.25)),
		_cone("LowerBeakHook", Vector3(0, -0.12, -0.22), Vector3(0, -0.025, -0.285), 0.14, horn.darkened(0.15)),
	]
	for index in range(12):
		var angle: float = TAU * float(index) / 12.0
		var position := Vector3(cos(angle) * 0.275, sin(angle) * 0.275, -0.18)
		result.append(_piece("OralRing%02d" % index, position, Vector3(0.165, 0.165, 0.30), skin.lerp(accent, 0.12), true))
	return result


static func _piece(name: String, position: Vector3, size: Vector3, color: Color, skin: bool = false) -> Dictionary:
	return {"kind": "piece", "name": name, "position": position, "size": size, "color": color, "skin": skin}


static func _cone(name: String, start: Vector3, end: Vector3, width: float, color: Color) -> Dictionary:
	return {"kind": "cone", "name": name, "start": start, "end": end, "width": width, "color": color}
