extends Node3D
## A wildlife landmark, never a player respawn point or a second group owner.
const Visuals = preload("res://world/visuals/scenery/resource_visual_factory.gd")
const Text = preload("res://core/localization/ui_text.gd")
var label: Label3D
var colony: Dictionary
var living_members: int = 0

func setup(value: Dictionary, profile: Dictionary, biome: String) -> void:
	colony = value
	add_to_group(&"wildlife_nest")
	var mesh := MeshInstance3D.new()
	mesh.mesh = Visuals.nest(int(value.seed), 1.7, 0.25, 32, 2, 0.12, profile, biome)
	add_child(mesh)
	# A query-only body lets the same center ray and occlusion rules scan nests.
	var hitbox := StaticBody3D.new()
	hitbox.collision_layer = 4
	hitbox.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 1.55
	cylinder.height = 0.9
	shape.shape = cylinder
	shape.position.y = 0.45
	hitbox.add_child(shape)
	add_child(hitbox)
	label = Label3D.new()
	label.position.y = 2.1
	label.font_size = 28
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.modulate = Color(0.98, 0.84, 0.56)
	add_child(label)

func refresh(player: Node3D, living: int) -> void:
	living_members = living
	var scanner: Node = player.get_node_or_null("CreatureScanner") if is_instance_valid(player) else null
	label.visible = scanner != null and scanner.active() and scanner.target == self
	if label.visible:
		var species: String = _species_name()
		label.text = Text.format_text("LIVING_NEST", {"species": species, "count": living}) if scanner.known else Text.text("LIVING_NEST_UNKNOWN")

func _species_name() -> String:
	# Legacy generated display names append the dietary/AI role. Present the
	# species only; never rewrite the authoritative colony or resident blueprint.
	var species: String = str(colony.get("name", "")).strip_edges()
	var separator: int = species.rfind(" · ")
	if separator >= 0 and _is_role(species.substr(separator + 3)):
		species = species.left(separator).strip_edges()
	return Text.text("LIVING_NEST_SPECIES_UNKNOWN") if _is_role(species) else species

static func _is_role(value: String) -> bool:
	return value.strip_edges().to_lower() in ["", "grazer", "predator", "scavenger", "forager", "herbivore", "carnivore", "pflanzenfresser", "fleischfresser", "aggressiv"]
