extends RefCounted
## Pure deterministic identity. Uses its own RNG, never the game's RNG.

static func build(species_seed: int, role: String, body_size: float = 1.0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = species_seed
	var family := "chirp"
	if role in ["predator", "scavenger"]:
		family = "rasp"
	elif role in ["grazer", "swimmer"]:
		family = "throat"
	elif posmod(species_seed, 3) == 1:
		family = "throat"
	var size := clampf(body_size, 0.25, 4.0) if is_finite(body_size) else 1.0
	var pitch := clampf(pow(size, -0.35) * rng.randf_range(0.93, 1.07), 0.65, 1.6)
	return {"family": family, "pitch": pitch, "size": size}


static func from_creature(source: Node3D) -> Dictionary:
	var seed_value: Variant = source.get("species_seed")
	var species_seed := int(seed_value) if seed_value != null else int(source.get_meta(&"species_seed", 1))
	var role_value: Variant = source.get("ecological_role")
	var role := String(role_value) if role_value != null else String(source.get_meta(&"ecological_role", "forager"))
	var size := 1.0
	var blueprint: Variant = source.get("blueprint")
	if blueprint is Dictionary:
		var body: Dictionary = blueprint.get("body", {})
		var shape: Variant = body.get("shape", Vector3(1.3, 1.0, 2.1))
		if shape is Vector3:
			size = pow(maxf(shape.x * shape.y * shape.z / 2.73, 0.01), 1.0 / 3.0)
		size *= float(body.get("scale", 1.0))
	var preview := source.get_node_or_null("SpeciesVisual/ModularWildlifeCreature") as Node3D
	if preview != null:
		size *= preview.scale.abs().length() / sqrt(3.0) / 0.57
	size *= source.scale.abs().length() / sqrt(3.0)
	# Optional public overrides for future editors/other creature implementations.
	size = float(source.get_meta(&"audio_body_size", size))
	return build(species_seed, role, size)
