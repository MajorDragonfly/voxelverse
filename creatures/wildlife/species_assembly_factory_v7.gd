extends RefCounted
class_name SpeciesAssemblyFactoryV7

const AssemblyV7 = preload(
	"res://creatures/editor/creature_assembly_blueprint_v7.gd"
)
const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
const PartLibrary = preload("res://creatures/editor/creature_part_library.gd")
const SpineProfile = preload("res://creatures/editor/creature_spine_profile.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const AttachmentNormalizer = preload(
	"res://creatures/editor/creature_attachment_normalizer.gd"
)

const ECOLOGICAL_ROLES: Array[String] = [
	"forager",
	"grazer",
	"scavenger",
	"predator",
	"climber",
	"swimmer",
]


static func create_species(
	species_seed: int,
	region_coordinates: Vector2i = Vector2i.ZERO,
	requested_role: String = "auto"
) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = species_seed
	var blueprint: Dictionary = Blueprint.create_default()
	Blueprint.clear_parts(blueprint)
	var role: String = requested_role
	if role == "auto" or role not in ECOLOGICAL_ROLES:
		role = ECOLOGICAL_ROLES[posmod(species_seed, ECOLOGICAL_ROLES.size())]

	_set_random_body(blueprint, random, role)
	_set_random_spine(blueprint, random, role)
	_set_random_paint(blueprint, random)
	_add_random_part(blueprint, PartLibrary.CATEGORY_MOUTH, random, true)
	_add_random_part(blueprint, PartLibrary.CATEGORY_EYES, random, true)
	if role != "swimmer" or random.randf() < 0.48:
		_add_random_part(blueprint, PartLibrary.CATEGORY_LEGS, random, true)
	if random.randf() < 0.74:
		_add_random_part(blueprint, PartLibrary.CATEGORY_TAIL, random, false)
	if random.randf() < 0.38:
		_add_random_part(blueprint, PartLibrary.CATEGORY_ARMS, random, false)
	if random.randf() < 0.34:
		_add_random_part(blueprint, PartLibrary.CATEGORY_HORNS, random, false)
	if random.randf() < 0.30:
		_add_random_part(blueprint, PartLibrary.CATEGORY_PLATES, random, false)
	if random.randf() < 0.30:
		_add_random_part(blueprint, PartLibrary.CATEGORY_SPIKES, random, false)
	if random.randf() < 0.46:
		_add_random_part(blueprint, PartLibrary.CATEGORY_DECOR, random, false)

	AssemblyV7.normalize(blueprint)
	var assembly: Dictionary = blueprint.get("assembly", {})
	assembly["revision"] = 0
	assembly["symmetry_enabled"] = true
	assembly["snap_to_surface"] = true
	blueprint["assembly"] = assembly
	blueprint["species"] = {
		"species_seed": species_seed,
		"region_x": region_coordinates.x,
		"region_z": region_coordinates.y,
		"ecological_role": role,
		"display_name": _create_species_name(species_seed, role),
	}
	blueprint["name"] = str(blueprint["species"]["display_name"])
	Anatomy.ensure_anchors(blueprint, true)
	AttachmentNormalizer.normalize(blueprint, true)
	Anatomy.rebind_all_parts(blueprint)
	return blueprint


static func get_role(blueprint: Dictionary) -> String:
	var species: Dictionary = blueprint.get("species", {})
	return str(species.get("ecological_role", "forager"))


static func _set_random_body(
	blueprint: Dictionary,
	random: RandomNumberGenerator,
	role: String
) -> void:
	var body_parts: Array = PartLibrary.get_body_parts()
	if body_parts.is_empty():
		return
	var body_definition: Dictionary = body_parts[
		random.randi_range(0, body_parts.size() - 1)
	]
	Blueprint.set_body_part(
		blueprint,
		str(body_definition.get("id", PartLibrary.get_default_body_part_id()))
	)
	var shape: Vector3 = Blueprint.get_body_shape(blueprint)
	shape.x *= random.randf_range(0.76, 1.32)
	shape.y *= random.randf_range(0.72, 1.28)
	shape.z *= random.randf_range(0.78, 1.38)
	match role:
		"predator":
			shape.x *= 0.88
			shape.z *= 1.12
		"grazer":
			shape.x *= 1.12
			shape.y *= 0.90
		"climber":
			shape.x *= 0.80
			shape.y *= 1.14
		"swimmer":
			shape.x *= 0.76
			shape.z *= 1.26
	Blueprint.set_body_shape(blueprint, shape)
	Blueprint.set_body_scale(blueprint, random.randf_range(0.72, 1.24))


static func _set_random_spine(
	blueprint: Dictionary,
	random: RandomNumberGenerator,
	role: String
) -> void:
	var segments: Array = SpineProfile.create_default()
	var phase: float = random.randf_range(0.0, TAU)
	var curve_strength: float = random.randf_range(0.02, 0.24)
	if role == "swimmer":
		curve_strength *= 1.35
	for index in range(segments.size()):
		var t: float = float(index) / maxf(float(segments.size() - 1), 1.0)
		var center_weight: float = 1.0 - absf(t - 0.5) * 1.25
		segments[index]["width_scale"] = clampf(
			random.randf_range(0.82, 1.18) * lerpf(0.88, 1.12, center_weight),
			SpineProfile.MIN_WIDTH_SCALE,
			SpineProfile.MAX_WIDTH_SCALE
		)
		segments[index]["height_scale"] = clampf(
			random.randf_range(0.84, 1.16),
			SpineProfile.MIN_HEIGHT_SCALE,
			SpineProfile.MAX_HEIGHT_SCALE
		)
		segments[index]["y_offset"] = clampf(
			sin(t * TAU + phase) * curve_strength,
			SpineProfile.MIN_Y_OFFSET,
			SpineProfile.MAX_Y_OFFSET
		)
	var body: Dictionary = blueprint.get("body", {})
	body["spine"] = segments
	body["spine_length_scale"] = clampf(
		random.randf_range(0.82, 1.34),
		SpineProfile.MIN_BODY_LENGTH_SCALE,
		SpineProfile.MAX_BODY_LENGTH_SCALE
	)
	blueprint["body"] = body


static func _set_random_paint(
	blueprint: Dictionary,
	random: RandomNumberGenerator
) -> void:
	var paints: Array = PartLibrary.get_paint_parts()
	if paints.is_empty():
		return
	var paint: Dictionary = paints[random.randi_range(0, paints.size() - 1)]
	Blueprint.set_paint_part(blueprint, str(paint.get("id", "paint_plain")))
	Blueprint.set_paint_intensity(blueprint, random.randf_range(0.55, 1.0))


static func _add_random_part(
	blueprint: Dictionary,
	category_id: String,
	random: RandomNumberGenerator,
	required: bool
) -> void:
	var parts: Array = PartLibrary.get_parts_for_category(category_id)
	if parts.is_empty():
		return
	if not required and random.randf() < 0.12:
		return
	var part: Dictionary = parts[random.randi_range(0, parts.size() - 1)]
	var index: int = Blueprint.add_part(blueprint, str(part.get("id", "")))
	if index < 0:
		return
	var placement: Dictionary = Blueprint.get_part_placement(blueprint, index)
	placement["scale"] = clampf(
		float(placement.get("scale", 1.0)) * random.randf_range(0.72, 1.28),
		0.25,
		3.0
	)
	placement["rotation"] = Vector3(
		random.randf_range(-8.0, 8.0),
		random.randf_range(-12.0, 12.0),
		random.randf_range(-8.0, 8.0)
	)
	Blueprint.set_part_placement(blueprint, index, placement)


static func _create_species_name(species_seed: int, role: String) -> String:
	var prefixes: Array[String] = [
		"Aru",
		"Koro",
		"Vexa",
		"Mira",
		"Talo",
		"Senu",
		"Orbi",
		"Naka",
	]
	var suffixes: Array[String] = [
		"don",
		"ra",
		"vek",
		"lume",
		"tari",
		"nox",
		"poda",
		"saur",
	]
	return "%s%s · %s" % [
		prefixes[posmod(species_seed, prefixes.size())],
		suffixes[posmod(species_seed / 17, suffixes.size())],
		role.capitalize(),
	]
