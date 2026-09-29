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
		var species: String = str(colony.get("name", ""))
		if species.is_empty(): species = Text.text("LIVING_NEST_SPECIES_UNKNOWN")
		label.text = Text.format_text("LIVING_NEST", {"species": species, "count": living}) if scanner.known else Text.text("LIVING_NEST_UNKNOWN")
