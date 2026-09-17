extends Node3D
## A wildlife landmark, never a player respawn point or a second group owner.
const Visuals = preload("res://world/visuals/scenery/resource_visual_factory.gd")
const Text = preload("res://core/localization/ui_text.gd")
var label: Label3D
var colony: Dictionary

func setup(value: Dictionary, profile: Dictionary, biome: String) -> void:
	colony = value
	add_to_group(&"wildlife_nest")
	var mesh := MeshInstance3D.new()
	mesh.mesh = Visuals.nest(int(value.seed), 1.7, 0.25, 32, 2, 0.12, profile, biome)
	add_child(mesh)
	label = Label3D.new()
	label.position.y = 2.1
	label.font_size = 28
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.modulate = Color(0.98, 0.84, 0.56)
	add_child(label)

func refresh(player: Node3D, living: int) -> void:
	label.visible = is_instance_valid(player) and global_position.distance_to(player.global_position) < 25.0
	if label.visible:
		label.text = Text.format_text("LIVING_NEST", {"species": colony.name, "count": living})
