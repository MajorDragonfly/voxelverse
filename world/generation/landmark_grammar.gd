extends RefCounted

const CELL_SIZE: float = 192.0
const MAX_RADIUS: float = 92.0


static func create_cell(seed_value: int, cell: Vector2i, profile: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 1_000_003 + cell.x * 73_856_093 + cell.y * 19_349_663 + 731_117
	if rng.randf() > 0.88:
		return {}
	var kinds: Array[String] = ["ridge", "ridge", "mesa", "basin", "rock_spire", "ancient_grove", "coastal_teeth"]
	var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
	var style: int = int(profile.get("terrain_style", 0))
	if style == 2 and rng.randf() < 0.65:
		kind = "mesa"
	elif style in [1, 5] and rng.randf() < 0.65:
		kind = "ridge"
	elif style == 3 and rng.randf() < 0.55:
		kind = "coastal_teeth"
	elif style == 4 and rng.randf() < 0.45:
		kind = "basin"
	var center := Vector2(cell) * CELL_SIZE + Vector2(rng.randf_range(44.0, 148.0), rng.randf_range(44.0, 148.0))
	return {"id": "%d:%d:%d" % [seed_value, cell.x, cell.y], "kind": kind,
		"center": center, "angle": rng.randf_range(0.0, TAU),
		"radius": rng.randf_range(68.0, MAX_RADIUS), "height": rng.randf_range(32.0, 58.0) if kind == "ridge" else rng.randf_range(20.0, 36.0),
		"asymmetry": rng.randf_range(-0.22, 0.22)}


static func height_offset(landmark: Dictionary, point: Vector2) -> float:
	if landmark.is_empty():
		return 0.0
	var delta: Vector2 = (point - (landmark["center"] as Vector2)).rotated(-float(landmark["angle"]))
	var radius: float = float(landmark["radius"])
	var distance: float = delta.length() / radius
	if distance >= 1.0:
		return 0.0
	var edge: float = 1.0 - smoothstep(0.55, 1.0, distance)
	var elevation: float = float(landmark["height"])
	match str(landmark["kind"]):
		"ridge":
			var spine: float = 1.0 - smoothstep(0.0, radius * 0.48, absf(delta.y + sin(delta.x / radius * 5.0) * radius * 0.06))
			var peaks: float = 0.72 + 0.28 * pow(cos(delta.x / radius * 5.0), 2.0)
			return elevation * spine * peaks * edge
		"mesa":
			var radius_warp: float = distance + sin(delta.x * 0.045) * 0.08 + float(landmark["asymmetry"]) * delta.y / radius
			return elevation * (1.0 - smoothstep(0.32, 0.58, radius_warp)) * edge
		"basin":
			return elevation * (0.22 * exp(-pow((distance - 0.65) / 0.16, 2.0)) - 0.22 * (1.0 - smoothstep(0.1, 0.55, distance))) * edge
		"rock_spire":
			return elevation * pow(1.0 - smoothstep(0.0, 0.32, distance), 1.4)
		"coastal_teeth":
			var teeth: float = 0.0
			for offset in [-0.4, 0.0, 0.4]:
				var d: float = (delta - Vector2(radius * offset, 0.0)).length() / radius
				teeth = maxf(teeth, (1.0 - smoothstep(0.0, 0.24, d)) * elevation * 0.64)
			return teeth * edge
		"ancient_grove":
			return 1.6 * (1.0 - smoothstep(0.0, 0.8, distance))
	return 0.0
