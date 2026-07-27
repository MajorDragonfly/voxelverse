extends RefCounted
class_name CreatureEvolutionGenerator

const Blueprint = preload(
	"res://creatures/editor/creature_blueprint.gd"
)
const PartLibrary = preload(
	"res://creatures/editor/creature_part_library.gd"
)
const SpineProfile = preload(
	"res://creatures/editor/creature_spine_profile.gd"
)
const Anatomy = preload(
	"res://creatures/editor/creature_anatomy.gd"
)
const BlueprintV5 = preload(
	"res://creatures/editor/creature_blueprint_v5.gd"
)

const ARCHETYPES: Array[String] = [
	"random",
	"grazer",
	"predator",
	"sprinter",
	"armored",
	"insectoid",
	"serpent",
]

const OPTIONAL_CATEGORIES: Array[String] = [
	PartLibrary.CATEGORY_ARMS,
	PartLibrary.CATEGORY_TAIL,
	PartLibrary.CATEGORY_HORNS,
	PartLibrary.CATEGORY_PLATES,
	PartLibrary.CATEGORY_SPIKES,
	PartLibrary.CATEGORY_DECOR,
]

const NAME_PREFIXES: Array[String] = [
	"Astra", "Braka", "Cinder", "Doru", "Eko", "Fera", "Glim",
	"Hedra", "Ixo", "Jara", "Koru", "Luma", "Mora", "Nex",
	"Orbi", "Ptera", "Quill", "Rava", "Sora", "Tera", "Uru",
	"Vexa", "Wisp", "Xeno", "Yara", "Zora",
]

const NAME_SUFFIXES: Array[String] = [
	"back", "bloom", "claw", "crest", "drifter", "fang", "fin",
	"foot", "glider", "hide", "horn", "jaw", "runner", "shell",
	"snout", "spine", "stalker", "tail", "walker", "wing",
]


static func create_seed() -> int:
	return int(Time.get_unix_time_from_system()) ^ int(Time.get_ticks_usec())


static func generate(
	seed_value: int,
	requested_archetype: String = "random"
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var archetype: String = _resolve_archetype(requested_archetype, rng)
	var blueprint: Dictionary = Blueprint.create_default()
	Blueprint.clear_parts(blueprint)

	var config: Dictionary = _get_archetype_config(archetype)
	var body_id: String = _pick_part_id(
		PartLibrary.CATEGORY_BODY,
		config.get("body_tokens", []),
		rng
	)

	if body_id != "":
		Blueprint.set_body_part(blueprint, body_id)

	var shape: Vector3 = Blueprint.get_body_shape(blueprint)
	var width_range: Vector2 = config.get(
		"width_range", Vector2(0.78, 1.32)
	)
	var height_range: Vector2 = config.get(
		"height_range", Vector2(0.78, 1.28)
	)
	var depth_range: Vector2 = config.get(
		"depth_range", Vector2(0.82, 1.35)
	)
	shape.x *= rng.randf_range(width_range.x, width_range.y)
	shape.y *= rng.randf_range(height_range.x, height_range.y)
	shape.z *= rng.randf_range(depth_range.x, depth_range.y)
	Blueprint.set_body_shape(blueprint, shape)
	Blueprint.set_body_scale(blueprint, rng.randf_range(0.82, 1.18))

	_generate_spine(blueprint, rng, archetype, config)

	var paint_id: String = _pick_part_id(
		PartLibrary.CATEGORY_PAINT,
		config.get("paint_tokens", []),
		rng
	)

	if paint_id != "":
		Blueprint.set_paint_part(blueprint, paint_id)
		Blueprint.set_paint_intensity(
			blueprint,
			rng.randf_range(0.62, 1.0)
		)

	_add_required_parts(blueprint, rng, archetype, config)
	_add_optional_parts(blueprint, rng, archetype, config)

	Anatomy.reset_all_anchors(blueprint)
	_randomize_part_transforms(blueprint, rng, archetype)
	_trim_to_complexity_limit(blueprint)
	Anatomy.ensure_anchors(blueprint, true)
	Anatomy.rebind_all_parts(blueprint)

	blueprint["name"] = _generate_name(rng, archetype)
	blueprint["generation"] = {
		"seed": seed_value,
		"generation": 0,
		"parent_seed": 0,
		"archetype": archetype,
		"mutation_strength": 0.0,
	}
	BlueprintV5.normalize(blueprint)
	return blueprint


static func mutate(
	source_blueprint: Dictionary,
	mutation_seed: int,
	strength: float = 0.22
) -> Dictionary:
	if source_blueprint.is_empty():
		return generate(mutation_seed, "random")

	var rng := RandomNumberGenerator.new()
	rng.seed = mutation_seed
	var safe_strength: float = clampf(strength, 0.02, 1.0)
	var blueprint: Dictionary = source_blueprint.duplicate(true)
	BlueprintV5.normalize(blueprint)
	Anatomy.ensure_anchors(blueprint, true)

	var generation_data: Dictionary = blueprint.get("generation", {})
	var parent_seed: int = int(generation_data.get("seed", 0))
	var archetype: String = str(
		generation_data.get("archetype", "custom")
	)

	_mutate_body_shape(blueprint, rng, safe_strength)
	_mutate_spine(blueprint, rng, safe_strength)
	_mutate_parts(blueprint, rng, safe_strength)

	if rng.randf() < 0.28 + safe_strength * 0.35:
		var paint_parts: Array = PartLibrary.get_paint_parts()

		if not paint_parts.is_empty():
			var paint_part: Dictionary = paint_parts[
				rng.randi_range(0, paint_parts.size() - 1)
			]
			Blueprint.set_paint_part(
				blueprint,
				str(paint_part.get("id", "paint_plain"))
			)

	Blueprint.set_paint_intensity(
		blueprint,
		Blueprint.get_paint_intensity(blueprint)
		+ rng.randf_range(-0.22, 0.22) * safe_strength
	)

	_trim_to_complexity_limit(blueprint)
	Anatomy.rebind_all_parts(blueprint)

	var next_generation: int = int(
		generation_data.get("generation", 0)
	) + 1
	blueprint["name"] = "%s G%d" % [
		_strip_generation_suffix(str(blueprint.get("name", "Creature"))),
		next_generation,
	]
	blueprint["generation"] = {
		"seed": mutation_seed,
		"generation": next_generation,
		"parent_seed": parent_seed,
		"archetype": archetype,
		"mutation_strength": safe_strength,
	}
	BlueprintV5.normalize(blueprint)
	return blueprint


static func _resolve_archetype(
	requested_archetype: String,
	rng: RandomNumberGenerator
) -> String:
	var normalized: String = requested_archetype.to_lower().strip_edges()

	if normalized == "random" or not ARCHETYPES.has(normalized):
		return ARCHETYPES[rng.randi_range(1, ARCHETYPES.size() - 1)]

	return normalized


static func _get_archetype_config(archetype: String) -> Dictionary:
	match archetype:
		"grazer":
			return {
				"body_tokens": ["grazer", "balanced"],
				"paint_tokens": ["forest", "sand", "plain"],
				"mouth_tokens": ["grazer", "filter"],
				"eyes_tokens": ["wide", "beady"],
				"legs_tokens": ["hoof", "walker", "stubby"],
				"tail_tokens": ["balance"],
				"width_range": Vector2(0.88, 1.24),
				"height_range": Vector2(0.82, 1.16),
				"depth_range": Vector2(1.02, 1.48),
				"length_range": Vector2(0.96, 1.52),
				"curve_strength": 0.16,
				"optional_chance": 0.42,
			}
		"predator":
			return {
				"body_tokens": ["balanced", "serpent"],
				"paint_tokens": ["warning", "forest", "plain"],
				"mouth_tokens": ["predator"],
				"eyes_tokens": ["wide", "cluster", "beady"],
				"legs_tokens": ["sprinter", "walker", "spider"],
				"tail_tokens": ["balance", "club"],
				"horn_tokens": ["horn", "crest"],
				"width_range": Vector2(0.82, 1.16),
				"height_range": Vector2(0.86, 1.28),
				"depth_range": Vector2(0.92, 1.30),
				"length_range": Vector2(0.90, 1.36),
				"curve_strength": 0.25,
				"optional_chance": 0.62,
			}
		"sprinter":
			return {
				"body_tokens": ["long", "balanced"],
				"paint_tokens": ["sand", "warning", "plain"],
				"mouth_tokens": ["broad", "grazer"],
				"eyes_tokens": ["wide", "beady"],
				"legs_tokens": ["sprinter", "hoof"],
				"tail_tokens": ["balance"],
				"width_range": Vector2(0.70, 0.98),
				"height_range": Vector2(0.88, 1.20),
				"depth_range": Vector2(1.04, 1.42),
				"length_range": Vector2(1.04, 1.48),
				"curve_strength": 0.20,
				"optional_chance": 0.48,
			}
		"armored":
			return {
				"body_tokens": ["heavy", "insectoid"],
				"paint_tokens": ["crystal", "warning", "plain"],
				"mouth_tokens": ["broad", "grazer"],
				"eyes_tokens": ["beady", "cluster"],
				"legs_tokens": ["stubby", "walker", "spider"],
				"tail_tokens": ["club", "balance"],
				"horn_tokens": ["horn", "crest"],
				"plate_tokens": ["plate", "shell"],
				"width_range": Vector2(1.02, 1.42),
				"height_range": Vector2(0.90, 1.24),
				"depth_range": Vector2(0.88, 1.22),
				"length_range": Vector2(0.86, 1.24),
				"curve_strength": 0.12,
				"optional_chance": 0.78,
			}
		"insectoid":
			return {
				"body_tokens": ["insectoid"],
				"paint_tokens": ["warning", "crystal", "forest"],
				"mouth_tokens": ["predator", "filter"],
				"eyes_tokens": ["cluster", "stalk"],
				"legs_tokens": ["spider"],
				"spike_tokens": ["spike"],
				"width_range": Vector2(0.76, 1.08),
				"height_range": Vector2(0.72, 1.02),
				"depth_range": Vector2(1.02, 1.46),
				"length_range": Vector2(1.02, 1.52),
				"curve_strength": 0.30,
				"optional_chance": 0.72,
			}
		"serpent":
			return {
				"body_tokens": ["serpent"],
				"paint_tokens": ["warning", "forest", "crystal"],
				"mouth_tokens": ["predator", "filter"],
				"eyes_tokens": ["cluster", "beady", "stalk"],
				"tail_tokens": ["balance"],
				"spike_tokens": ["spike"],
				"width_range": Vector2(0.64, 0.92),
				"height_range": Vector2(0.64, 0.94),
				"depth_range": Vector2(1.18, 1.65),
				"length_range": Vector2(1.34, 2.05),
				"curve_strength": 0.48,
				"optional_chance": 0.50,
			}
		_:
			return {
				"body_tokens": [],
				"paint_tokens": [],
				"mouth_tokens": [],
				"eyes_tokens": [],
				"legs_tokens": [],
				"width_range": Vector2(0.76, 1.30),
				"height_range": Vector2(0.76, 1.28),
				"depth_range": Vector2(0.82, 1.42),
				"length_range": Vector2(0.82, 1.56),
				"curve_strength": 0.30,
				"optional_chance": 0.55,
			}


static func _generate_spine(
	blueprint: Dictionary,
	rng: RandomNumberGenerator,
	archetype: String,
	config: Dictionary
) -> void:
	SpineProfile.ensure_profile(blueprint)
	var length_range: Vector2 = config.get(
		"length_range", Vector2(0.82, 1.56)
	)
	SpineProfile.set_body_length_scale(
		blueprint,
		rng.randf_range(length_range.x, length_range.y)
	)

	var curve_strength: float = float(config.get("curve_strength", 0.28))
	var phase: float = rng.randf_range(-PI, PI)
	var wave_count: float = rng.randf_range(0.65, 1.45)
	var width_walk: float = rng.randf_range(-0.08, 0.08)
	var height_walk: float = rng.randf_range(-0.08, 0.08)

	for segment_index in range(SpineProfile.SEGMENT_COUNT):
		var t: float = float(segment_index) / float(
			SpineProfile.SEGMENT_COUNT - 1
		)
		width_walk = clampf(
			width_walk + rng.randf_range(-0.11, 0.11), -0.28, 0.28
		)
		height_walk = clampf(
			height_walk + rng.randf_range(-0.09, 0.09), -0.24, 0.24
		)
		var end_taper: float = absf(t - 0.5) * 0.22
		var y_offset: float = sin(
			phase + t * TAU * wave_count
		) * curve_strength

		if archetype == "sprinter":
			y_offset += sin(t * PI) * 0.10
		elif archetype == "armored":
			y_offset *= 0.45
		elif archetype == "serpent":
			y_offset += sin(phase * 0.7 + t * TAU * 1.8) * 0.18

		SpineProfile.set_segment(
			blueprint,
			segment_index,
			{
				"width_scale": 1.0 + width_walk - end_taper,
				"height_scale": 1.0 + height_walk - end_taper * 0.55,
				"y_offset": y_offset,
			}
		)


static func _add_required_parts(
	blueprint: Dictionary,
	rng: RandomNumberGenerator,
	archetype: String,
	config: Dictionary
) -> void:
	_add_generated_part(
		blueprint,
		PartLibrary.CATEGORY_MOUTH,
		config.get("mouth_tokens", []),
		rng
	)
	_add_generated_part(
		blueprint,
		PartLibrary.CATEGORY_EYES,
		config.get("eyes_tokens", []),
		rng
	)

	if archetype != "serpent":
		_add_generated_part(
			blueprint,
			PartLibrary.CATEGORY_LEGS,
			config.get("legs_tokens", []),
			rng
		)

	if archetype in ["insectoid", "sprinter"] and rng.randf() < 0.70:
		_add_generated_part(
			blueprint,
			PartLibrary.CATEGORY_LEGS,
			config.get("legs_tokens", []),
			rng
		)


static func _add_optional_parts(
	blueprint: Dictionary,
	rng: RandomNumberGenerator,
	archetype: String,
	config: Dictionary
) -> void:
	var base_chance: float = float(config.get("optional_chance", 0.55))

	for category_id in OPTIONAL_CATEGORIES:
		var chance: float = base_chance
		var tokens: Array = []

		match category_id:
			PartLibrary.CATEGORY_TAIL:
				chance += 0.18
				tokens = config.get("tail_tokens", [])
			PartLibrary.CATEGORY_HORNS:
				chance -= 0.12
				tokens = config.get("horn_tokens", [])
			PartLibrary.CATEGORY_PLATES:
				chance = 0.78 if archetype == "armored" else chance - 0.20
				tokens = config.get("plate_tokens", [])
			PartLibrary.CATEGORY_SPIKES:
				chance = 0.72 if archetype in ["insectoid", "serpent"] else chance - 0.18
				tokens = config.get("spike_tokens", [])
			PartLibrary.CATEGORY_ARMS:
				chance = 0.18 if archetype == "serpent" else chance - 0.08
			PartLibrary.CATEGORY_DECOR:
				chance -= 0.24

		if rng.randf() > clampf(chance, 0.0, 0.92):
			continue

		_add_generated_part(blueprint, category_id, tokens, rng)

		if (
			category_id in [
				PartLibrary.CATEGORY_PLATES,
				PartLibrary.CATEGORY_SPIKES,
				PartLibrary.CATEGORY_DECOR,
			]
			and rng.randf() < 0.42
		):
			_add_generated_part(blueprint, category_id, tokens, rng)


static func _add_generated_part(
	blueprint: Dictionary,
	category_id: String,
	preferred_tokens: Array,
	rng: RandomNumberGenerator
) -> int:
	var part_id: String = _pick_part_id(
		category_id, preferred_tokens, rng
	)

	if part_id == "":
		return -1

	return Blueprint.add_part(blueprint, part_id)


static func _pick_part_id(
	category_id: String,
	preferred_tokens: Array,
	rng: RandomNumberGenerator
) -> String:
	var candidates: Array = PartLibrary.get_parts_for_category(category_id)

	if candidates.is_empty():
		return ""

	var preferred: Array = []

	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue

		var candidate: Dictionary = candidate_value
		var search_text: String = (
			str(candidate.get("id", ""))
			+ " "
			+ str(candidate.get("name", ""))
		).to_lower()

		for token_value in preferred_tokens:
			var token: String = str(token_value).to_lower()

			if token != "" and search_text.contains(token):
				preferred.append(candidate)
				break

	var pool: Array = preferred if not preferred.is_empty() else candidates
	var chosen: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	return str(chosen.get("id", ""))


static func _randomize_part_transforms(
	blueprint: Dictionary,
	rng: RandomNumberGenerator,
	archetype: String
) -> void:
	var parts: Array = blueprint.get("parts", [])

	for index in range(parts.size()):
		if not (parts[index] is Dictionary):
			continue

		var placement: Dictionary = parts[index]
		var category_id: String = str(placement.get("category", ""))
		var scale_variation: float = rng.randf_range(-0.16, 0.25)

		if archetype == "armored" and category_id in [
			PartLibrary.CATEGORY_HORNS,
			PartLibrary.CATEGORY_PLATES,
			PartLibrary.CATEGORY_TAIL,
		]:
			scale_variation += 0.18

		placement["scale"] = clampf(
			float(placement.get("scale", 1.0)) + scale_variation,
			0.35,
			2.2
		)
		var rotation: Vector3 = Blueprint._as_vector3(
			placement.get("rotation", Vector3.ZERO)
		)
		rotation.y += rng.randf_range(-10.0, 10.0)
		rotation.x += rng.randf_range(-5.0, 5.0)
		placement["rotation"] = rotation
		parts[index] = placement

	blueprint["parts"] = parts


static func _mutate_body_shape(
	blueprint: Dictionary,
	rng: RandomNumberGenerator,
	strength: float
) -> void:
	var shape: Vector3 = Blueprint.get_body_shape(blueprint)
	shape.x *= 1.0 + rng.randf_range(-0.22, 0.22) * strength
	shape.y *= 1.0 + rng.randf_range(-0.20, 0.20) * strength
	shape.z *= 1.0 + rng.randf_range(-0.24, 0.24) * strength
	Blueprint.set_body_shape(blueprint, shape)
	Blueprint.set_body_scale(
		blueprint,
		Blueprint.get_body_scale(blueprint)
		+ rng.randf_range(-0.14, 0.14) * strength
	)


static func _mutate_spine(
	blueprint: Dictionary,
	rng: RandomNumberGenerator,
	strength: float
) -> void:
	SpineProfile.ensure_profile(blueprint)
	var mutation_count: int = clampi(
		ceili(float(SpineProfile.SEGMENT_COUNT) * strength),
		1,
		SpineProfile.SEGMENT_COUNT
	)

	for _mutation_index in range(mutation_count):
		var segment_index: int = rng.randi_range(
			0, SpineProfile.SEGMENT_COUNT - 1
		)
		SpineProfile.adjust_segment(
			blueprint,
			segment_index,
			rng.randf_range(-0.20, 0.20) * strength,
			rng.randf_range(-0.18, 0.18) * strength,
			rng.randf_range(-0.28, 0.28) * strength
		)

	SpineProfile.adjust_body_length(
		blueprint,
		rng.randf_range(-0.28, 0.28) * strength
	)


static func _mutate_parts(
	blueprint: Dictionary,
	rng: RandomNumberGenerator,
	strength: float
) -> void:
	var parts: Array = blueprint.get("parts", [])

	for index in range(parts.size()):
		if not (parts[index] is Dictionary):
			continue

		if rng.randf() > 0.25 + strength * 0.45:
			continue

		var placement: Dictionary = parts[index]
		placement["scale"] = clampf(
			float(placement.get("scale", 1.0))
			+ rng.randf_range(-0.25, 0.25) * strength,
			0.25,
			3.0
		)
		var manual_offset: Vector3 = Blueprint._as_vector3(
			placement.get("manual_offset", Vector3.ZERO)
		)
		manual_offset += Vector3(
			rng.randf_range(-0.12, 0.12),
			rng.randf_range(-0.10, 0.10),
			rng.randf_range(-0.12, 0.12)
		) * strength
		placement["manual_offset"] = manual_offset
		parts[index] = placement

	blueprint["parts"] = parts

	if rng.randf() < 0.34 + strength * 0.30:
		_replace_random_part(blueprint, rng)

	if rng.randf() < 0.16 + strength * 0.28:
		var category_id: String = OPTIONAL_CATEGORIES[
			rng.randi_range(0, OPTIONAL_CATEGORIES.size() - 1)
		]
		var new_index: int = _add_generated_part(
			blueprint, category_id, [], rng
		)

		if new_index >= 0:
			Anatomy.ensure_anchors(blueprint, false)
			Anatomy.reset_part_anchor(blueprint, new_index)


static func _replace_random_part(
	blueprint: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var parts: Array = blueprint.get("parts", [])

	if parts.is_empty():
		return

	var index: int = rng.randi_range(0, parts.size() - 1)

	if not (parts[index] is Dictionary):
		return

	var placement: Dictionary = parts[index]
	var category_id: String = str(placement.get("category", ""))
	var replacement_id: String = _pick_part_id(category_id, [], rng)

	if replacement_id == "":
		return

	placement["part_id"] = replacement_id
	placement["scale"] = clampf(
		float(placement.get("scale", 1.0))
		+ rng.randf_range(-0.12, 0.18),
		0.25,
		3.0
	)
	parts[index] = placement
	blueprint["parts"] = parts


static func _trim_to_complexity_limit(blueprint: Dictionary) -> void:
	var safety: int = 32

	while (
		Blueprint.calculate_complexity(blueprint)
		> Blueprint.COMPLEXITY_LIMIT
		and safety > 0
	):
		safety -= 1
		var parts: Array = blueprint.get("parts", [])
		var removable_index: int = -1

		for index in range(parts.size() - 1, -1, -1):
			if not (parts[index] is Dictionary):
				continue

			var category_id: String = str(parts[index].get("category", ""))

			if category_id in OPTIONAL_CATEGORIES:
				removable_index = index
				break

		if removable_index < 0:
			break

		Blueprint.remove_part(blueprint, removable_index)


static func _generate_name(
	rng: RandomNumberGenerator,
	archetype: String
) -> String:
	var prefix: String = NAME_PREFIXES[
		rng.randi_range(0, NAME_PREFIXES.size() - 1)
	]
	var suffix: String = NAME_SUFFIXES[
		rng.randi_range(0, NAME_SUFFIXES.size() - 1)
	]
	return "%s%s · %s" % [prefix, suffix, archetype.capitalize()]


static func _strip_generation_suffix(value: String) -> String:
	var marker_index: int = value.rfind(" G")

	if marker_index <= 0:
		return value

	var suffix: String = value.substr(marker_index + 2)

	if suffix.is_valid_int():
		return value.substr(0, marker_index)

	return value
