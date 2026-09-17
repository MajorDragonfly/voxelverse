extends RefCounted
## Authored mouth recipes shared by workshop, journal and runtime. Opening is a
## authored rest pose. Cosmetic joints do not grant new gameplay capabilities.
const SurfaceV2 = preload("res://creatures/editor/creature_mouth_surface_v2.gd")
const Catalog = preload("res://creatures/catalog/creature_mouth_catalog.gd")


static func articulation(id: String, revision: int = 1) -> Array[Dictionary]:
	if revision == 2: return SurfaceV2.articulation(id)
	if revision != 1: return []
	if id == "mouth_octopus_beak":
		return [
			_joint(["UpperBeak"], Vector3(0, 0.09, -0.14), 12.0),
			_joint(["LowerBeak"], Vector3(0, -0.10, -0.13), -20.0),
		]
	if id == "mouth_broad_beak":
		return [_joint(["LowerBeak"], Vector3(0, -0.095, 0.02), -24.0)]
	if id in Catalog.LEGACY_IDS:
		return [_joint(["LowerJaw"], Vector3(0, -0.145, 0.025), -25.0)]
	if id == "mouth_canine_snout":
		return [_joint(["LowerJaw"], Vector3(0, -0.17, -0.015), -28.0)]
	if id == "mouth_crocodile_snout":
		return [_joint(["LowerJaw", "LowerTooth"], Vector3(0, -0.19, -0.015), -28.0)]
	if id == "mouth_feline_snout":
		return [_joint(["LowerJaw"], Vector3(0, -0.16, 0.015), -25.0)]
	if id == "mouth_bear_snout":
		return [_joint(["LowerJaw", "LowerMolar"], Vector3(0, -0.24, 0.01), -25.0)]
	if id == "mouth_pig_snout":
		return [_joint(["LowerJaw"], Vector3(0, -0.19, -0.02), -24.0)]
	return []


static func _joint(prefixes: Array, pivot: Vector3, degrees: float) -> Dictionary:
	return {"channel": "mouth", "prefixes": prefixes, "pivot": pivot,
		"axis": Vector3.RIGHT, "degrees": degrees}


static func recipe(id: String, skin: Color, accent: Color, horn: Color, revision: int = 1) -> Array[Dictionary]:
	if revision != 1 or Catalog.get_profile(id, revision).is_empty(): return []
	match id:
		"mouth_canine_snout": return _canine(skin, accent, horn)
		"mouth_crocodile_snout": return _crocodile(skin, accent, horn)
		"mouth_octopus_beak": return _octopus(skin, accent, horn)
		"head_elephant_trunk": return _trunk(skin, accent)
		"mouth_feline_snout": return _feline(skin, accent, horn)
		"mouth_bear_snout": return _bear(skin, accent, horn)
		"mouth_pig_snout": return _pig(skin, accent)
	return []


static func _trunk(skin: Color, accent: Color) -> Array[Dictionary]:
	# Overlapping voxel sections form one continuous, tapered nose. The bridge
	# clears the independent mouth below; the tip is a nose, not another mouth.
	var result: Array[Dictionary] = [
		_piece("TrunkRoot", Vector3(0, 0, 0), Vector3(0.42, 0.30, 0.30), skin, true),
		_piece("TrunkBridge", Vector3(0, 0.005, -0.23), Vector3(0.37, 0.29, 0.34), skin, true),
		_piece("TrunkBend", Vector3(0, -0.045, -0.45), Vector3(0.32, 0.29, 0.29), skin, true),
		_piece("TrunkUpper", Vector3(0, -0.20, -0.60), Vector3(0.28, 0.30, 0.25), skin, true),
		_piece("TrunkMiddle", Vector3(0, -0.41, -0.69), Vector3(0.24, 0.30, 0.23), skin, true),
		_piece("TrunkLower", Vector3(0, -0.62, -0.75), Vector3(0.20, 0.28, 0.20), skin, true),
		_piece("TrunkCurl", Vector3(0, -0.79, -0.84), Vector3(0.18, 0.20, 0.25), skin, true),
		_piece("TrunkTip", Vector3(0, -0.77, -1.01), Vector3(0.17, 0.17, 0.23), skin.lightened(0.05), true),
		_piece("TipFinger", Vector3(0, -0.685, -1.06), Vector3(0.10, 0.085, 0.15), skin, true),
	]
	for side: float in [-1.0, 1.0]:
		result.append(_piece("TrunkNostril" + ("Left" if side < 0 else "Right"),
			Vector3(side * 0.043, -0.77, -1.128), Vector3(0.046, 0.075, 0.019), accent.darkened(0.65)))
	return result


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


static func _feline(skin: Color, accent: Color, horn: Color) -> Array[Dictionary]:
	var pad: Color = skin.lightened(0.20)
	var result: Array[Dictionary] = [
		_piece("MuzzleBase", Vector3(0, 0.015, -0.08), Vector3(0.52, 0.25, 0.25), skin, true),
		_piece("NoseBridge", Vector3(0, 0.075, -0.19), Vector3(0.19, 0.18, 0.24), skin, true),
		_piece("MouthCavity", Vector3(0, -0.092, -0.18), Vector3(0.34, 0.045, 0.27), Color("172a29")),
		_piece("LowerJaw", Vector3(0, -0.16, -0.135), Vector3(0.36, 0.085, 0.30), pad.darkened(0.12), true),
		_piece("Nose", Vector3(0, 0.057, -0.315), Vector3(0.16, 0.065, 0.065), accent.darkened(0.5)),
		_piece("NosePoint", Vector3(0, 0.014, -0.319), Vector3(0.075, 0.03, 0.065), accent.darkened(0.5)),
	]
	for side: float in [-1.0, 1.0]:
		var suffix: String = "Left" if side < 0 else "Right"
		result.append(_piece("WhiskerPad" + suffix, Vector3(side * 0.12, -0.018, -0.21), Vector3(0.235, 0.145, 0.24), pad, true))
		result.append(_cone("Canine" + suffix, Vector3(side * 0.145, -0.055, -0.24), Vector3(side * 0.135, -0.105, -0.25), 0.045, horn))
		for index in range(3):
			result.append(_piece("Follicle%s%d" % [suffix, index], Vector3(side * (0.105 + float(index) * 0.052), -0.004 - float(index % 2) * 0.036, -0.333), Vector3(0.017, 0.017, 0.017), accent.darkened(0.45)))
	return result


static func _bear(skin: Color, accent: Color, horn: Color) -> Array[Dictionary]:
	var muzzle: Color = skin.lightened(0.16)
	var result: Array[Dictionary] = [
		_piece("MuzzleBase", Vector3(0, 0.025, -0.10), Vector3(0.72, 0.36, 0.34), skin, true),
		_piece("MuzzleBridge", Vector3(0, 0.055, -0.275), Vector3(0.53, 0.29, 0.36), muzzle, true),
		_piece("Nose", Vector3(0, 0.105, -0.465), Vector3(0.34, 0.18, 0.11), accent.darkened(0.6)),
		_piece("NoseRidge", Vector3(0, 0.19, -0.44), Vector3(0.24, 0.05, 0.11), accent.darkened(0.45)),
		_piece("MouthCavity", Vector3(0, -0.133, -0.225), Vector3(0.52, 0.062, 0.46), Color("172a29")),
		_piece("LowerJaw", Vector3(0, -0.24, -0.235), Vector3(0.58, 0.115, 0.49), muzzle.darkened(0.13), true),
	]
	for side: float in [-1.0, 1.0]:
		var suffix: String = "Left" if side < 0 else "Right"
		result.append(_piece("CheekPad" + suffix, Vector3(side * 0.225, -0.025, -0.29), Vector3(0.24, 0.20, 0.29), muzzle, true))
		result.append(_piece("Nostril" + suffix, Vector3(side * 0.10, 0.084, -0.523), Vector3(0.07, 0.06, 0.018), Color("111f22")))
		result.append(_cone("Canine" + suffix, Vector3(side * 0.245, -0.104, -0.37), Vector3(side * 0.225, -0.167, -0.385), 0.070, horn))
		for index in range(2):
			var z: float = -0.07 - float(index) * 0.12
			result.append(_piece("UpperMolar%s%d" % [suffix, index], Vector3(side * 0.24, -0.122, z), Vector3(0.075, 0.032, 0.075), horn))
			result.append(_piece("LowerMolar%s%d" % [suffix, index], Vector3(side * 0.23, -0.172, z - 0.035), Vector3(0.07, 0.028, 0.07), horn.darkened(0.07)))
	return result


static func _pig(skin: Color, accent: Color) -> Array[Dictionary]:
	var nose: Color = skin.lightened(0.14).lerp(accent, 0.12)
	var result: Array[Dictionary] = [
		_piece("SnoutBase", Vector3(0, 0.035, -0.09), Vector3(0.47, 0.28, 0.30), skin, true),
		_piece("SnoutBridge", Vector3(0, 0.04, -0.255), Vector3(0.43, 0.265, 0.31), skin, true),
		# Disjoint stepped bands form a flattened disc without coplanar faces.
		_piece("NoseDisc", Vector3(0, 0.045, -0.435), Vector3(0.51, 0.20, 0.11), nose),
		_piece("NoseDiscUpper", Vector3(0, 0.165, -0.435), Vector3(0.47, 0.04, 0.11), nose),
		_piece("NoseDiscLower", Vector3(0, -0.075, -0.435), Vector3(0.47, 0.04, 0.11), nose),
		_piece("NoseDiscTop", Vector3(0, 0.20, -0.435), Vector3(0.37, 0.03, 0.11), nose),
		_piece("NoseDiscBottom", Vector3(0, -0.11, -0.435), Vector3(0.37, 0.03, 0.11), nose),
		_piece("MouthCavity", Vector3(0, -0.122, -0.22), Vector3(0.34, 0.045, 0.30), Color("172a29")),
		_piece("LowerJaw", Vector3(0, -0.19, -0.20), Vector3(0.38, 0.095, 0.36), skin.darkened(0.12), true),
	]
	for side: float in [-1.0, 1.0]:
		var suffix: String = "Left" if side < 0 else "Right"
		result.append(_piece("Nostril" + suffix, Vector3(side * 0.115, 0.055, -0.498), Vector3(0.075, 0.105, 0.025), accent.darkened(0.6)))
		result.append(_piece("NostrilUpper" + suffix, Vector3(side * 0.115, 0.105, -0.492), Vector3(0.05, 0.03, 0.03), accent.darkened(0.5)))
	return result


static func _piece(name: String, position: Vector3, size: Vector3, color: Color, skin: bool = false) -> Dictionary:
	return {"kind": "piece", "name": name, "position": position, "size": size, "color": color, "skin": skin}


static func _cone(name: String, start: Vector3, end: Vector3, width: float, color: Color) -> Dictionary:
	return {"kind": "cone", "name": name, "start": start, "end": end, "width": width, "color": color}
