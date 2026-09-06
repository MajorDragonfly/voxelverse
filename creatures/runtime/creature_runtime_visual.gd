extends Node3D
class_name CreatureRuntimeVisual

const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
const AssemblyV7 = preload(
	"res://creatures/editor/creature_assembly_blueprint_v7.gd"
)
const AttachmentNormalizer = preload(
	"res://creatures/editor/creature_attachment_normalizer.gd"
)
const RuntimePreview = preload(
	"res://creatures/runtime/creature_runtime_preview.gd"
)

const CREATURE_EDITOR_SCENE := "res://creatures/editor/creature_editor.tscn"

@export var runtime_visual_scale: float = 0.86
@export var runtime_visual_height: float = 0.82
@export var apply_blueprint_stats: bool = true

var blueprint: Dictionary = {}
var _preview: Node3D


func _ready() -> void:
	call_deferred("_install_runtime_creature")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo or event.keycode != KEY_F2:
		return
	var save_service := get_node_or_null("/root/SaveGameService")
	if save_service != null and save_service.has_method("save_now"):
		save_service.call("save_now")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_viewport().set_input_as_handled()
	var change_error: Error = get_tree().change_scene_to_file(CREATURE_EDITOR_SCENE)
	if change_error != OK:
		push_error("Could not open Creature Builder: %s" % change_error)


func _install_runtime_creature() -> void:
	blueprint = AssemblyV7.load_best_available()
	if blueprint.is_empty():
		blueprint = AssemblyV7.create_default()
	AssemblyV7.normalize(blueprint)
	var migrated: bool = AttachmentNormalizer.normalize(blueprint)
	if migrated:
		AssemblyV7.save_to_file(blueprint)
	_sync_progression_from_creature()
	_build_runtime_preview()
	_disable_preview_collisions(self)
	if apply_blueprint_stats:
		_apply_stats_to_player()


func reload_from_save() -> void:
	_install_runtime_creature()


func _sync_progression_from_creature() -> void:
	var progression := get_node_or_null("/root/ProgressionService")
	if progression == null or not progression.has_method("merge_unlocked_parts"):
		return
	var progression_data: Dictionary = blueprint.get("progression", {})
	var unlocked: Array = progression_data.get("unlocked_parts", [])
	progression.call("merge_unlocked_parts", unlocked)


func _build_runtime_preview() -> void:
	if is_instance_valid(_preview):
		_preview.queue_free()
	_preview = RuntimePreview.new()
	_preview.name = "BlueprintCreatureVisual"
	_preview.position = Vector3(0.0, runtime_visual_height, 0.0)
	_preview.scale = Vector3.ONE * runtime_visual_scale
	add_child(_preview)
	if _preview.has_method("set_editor_state"):
		_preview.call("set_editor_state", blueprint, -1, -1, false)
	else:
		_preview.call("set_blueprint", blueprint)


func _disable_preview_collisions(root: Node) -> void:
	var collision_object := root as CollisionObject3D
	if collision_object != null:
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
		collision_object.input_ray_pickable = false
	for child in root.get_children():
		_disable_preview_collisions(child)


func _apply_stats_to_player() -> void:
	var player: Node = get_parent()
	if player == null:
		return
	var stats: Dictionary = Blueprint.calculate_stats(blueprint)
	var old_maximum_health: float = maxf(float(player.get("maximum_health")), 1.0)
	var health_ratio: float = clampf(
		float(player.get("current_health")) / old_maximum_health,
		0.0,
		1.0
	)
	var new_maximum_health: float = maxf(float(stats.get("health", 100.0)), 25.0)
	player.set("move_speed", clampf(float(stats.get("speed", 5.0)), 2.2, 11.5))
	player.set("jump_velocity", clampf(float(stats.get("jump", 6.0)), 3.0, 9.0))
	player.set("maximum_health", new_maximum_health)
	player.set("current_health", new_maximum_health * health_ratio)
	player.set("attack_power", maxf(float(stats.get("attack", 1.0)), 0.1))
	player.set("defense_rating", maxf(float(stats.get("defense", 1.0)), 0.0))
	player.set("diet_plant", maxf(float(stats.get("diet_plant", 0.0)), 0.0))
	player.set("diet_meat", maxf(float(stats.get("diet_meat", 0.0)), 0.0))
	player.set(
		"hunger_loss_per_second",
		clampf(float(stats.get("hunger_drain", 0.20)), 0.03, 2.0)
	)
	if player.has_method("_initialize_hud"):
		player.call("_initialize_hud")
	if player.has_method("_update_hud"):
		player.call("_update_hud")
