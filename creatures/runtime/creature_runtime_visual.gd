extends Node3D
class_name CreatureRuntimeVisual

const Blueprint = preload(
	"res://creatures/editor/creature_blueprint.gd"
)
const BlueprintV5 = preload(
	"res://creatures/editor/creature_blueprint_v5.gd"
)
const Anatomy = preload(
	"res://creatures/editor/creature_anatomy.gd"
)
const EvolutionGenerator = preload(
	"res://creatures/editor/creature_evolution_generator.gd"
)
const RuntimePreview = preload(
	"res://creatures/runtime/creature_runtime_preview.gd"
)

const CREATURE_EDITOR_SCENE: String = (
	"res://creatures/editor/creature_editor.tscn"
)

@export var runtime_visual_scale: float = 0.86
@export var runtime_visual_height: float = 0.82
@export var apply_blueprint_stats: bool = true
@export var show_runtime_hint: bool = true

var blueprint: Dictionary = {}
var _preview: Node3D
var _runtime_label: Label


func _ready() -> void:
	call_deferred("_install_runtime_creature")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	if not event.pressed or event.echo:
		return

	if event.keycode == KEY_F2:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		var change_error: Error = get_tree().change_scene_to_file(
			CREATURE_EDITOR_SCENE
		)

		if change_error != OK:
			push_error(
				"Could not open Creature Lab V5: %s"
				% change_error
			)


func _install_runtime_creature() -> void:
	blueprint = BlueprintV5.load_best_available()

	if blueprint.is_empty():
		blueprint = EvolutionGenerator.generate(
			_get_world_seed(),
			"random"
		)

	BlueprintV5.normalize(blueprint)
	Anatomy.ensure_anchors(blueprint, true)
	Anatomy.rebind_all_parts(blueprint)

	_hide_legacy_player_visuals()
	_build_runtime_preview()
	_disable_preview_collisions(self)

	if apply_blueprint_stats:
		_apply_stats_to_player()

	if show_runtime_hint:
		_create_runtime_hud_label()

	var generation: Dictionary = blueprint.get("generation", {})
	print(
		"Runtime creature loaded: ",
		str(blueprint.get("name", "Creature")),
		" | Seed: ",
		int(generation.get("seed", 0))
	)


func _build_runtime_preview() -> void:
	if is_instance_valid(_preview):
		_preview.queue_free()

	_preview = RuntimePreview.new()
	_preview.name = "BlueprintCreatureVisual"
	_preview.position = Vector3(0.0, runtime_visual_height, 0.0)
	_preview.scale = Vector3.ONE * runtime_visual_scale
	add_child(_preview)

	if _preview.has_method("set_editor_state"):
		_preview.call(
			"set_editor_state",
			blueprint,
			-1,
			-1,
			false
		)
	else:
		_preview.call("set_blueprint", blueprint)


func _hide_legacy_player_visuals() -> void:
	var player: Node = get_parent()

	if player == null:
		return

	var body_mesh: VisualInstance3D = (
		player.get_node_or_null("BodyMesh") as VisualInstance3D
	)

	if body_mesh != null:
		body_mesh.visible = false

	var legacy_root: Node3D = (
		player.get_node_or_null("CreaturePartVisuals") as Node3D
	)

	if legacy_root != null:
		legacy_root.visible = false

	player.set("enable_creature_builder_debug_keys", false)


func _disable_preview_collisions(root: Node) -> void:
	var collision_object: CollisionObject3D = root as CollisionObject3D

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
	var old_maximum_health: float = maxf(
		float(player.get("maximum_health")),
		1.0
	)
	var old_health: float = float(player.get("current_health"))
	var health_ratio: float = clampf(
		old_health / old_maximum_health,
		0.0,
		1.0
	)
	var new_maximum_health: float = maxf(
		float(stats.get("health", 100.0)),
		25.0
	)

	player.set(
		"move_speed",
		clampf(float(stats.get("speed", 5.0)), 2.2, 11.5)
	)
	player.set(
		"jump_velocity",
		clampf(float(stats.get("jump", 6.0)), 3.0, 11.0)
	)
	player.set("maximum_health", new_maximum_health)
	player.set(
		"current_health",
		new_maximum_health * health_ratio
	)
	player.set(
		"hunger_loss_per_second",
		clampf(
			float(stats.get("hunger_drain", 0.20)),
			0.03,
			2.0
		)
	)

	if player.has_method("_initialize_hud"):
		player.call("_initialize_hud")

	if player.has_method("_update_hud"):
		player.call("_update_hud")

	if player.has_method("_update_development_debug_overlay"):
		player.call(
			"_update_development_debug_overlay",
			0.0,
			true
		)


func _create_runtime_hud_label() -> void:
	var player: Node = get_parent()

	if player == null:
		return

	var hud: Node = player.get_node_or_null("HUD")

	if hud == null:
		return

	_runtime_label = Label.new()
	_runtime_label.name = "CreatureRuntimeLabel"
	_runtime_label.offset_left = 12.0
	_runtime_label.offset_top = 104.0
	_runtime_label.offset_right = 560.0
	_runtime_label.offset_bottom = 154.0
	_runtime_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var generation: Dictionary = blueprint.get("generation", {})
	_runtime_label.text = (
		"%s · %s · Seed %d · Gen %d\n"
		+ "F2: Creature Lab  |  Editor changes are now used in play mode"
	) % [
		str(blueprint.get("name", "Creature")),
		str(generation.get("archetype", "custom")).capitalize(),
		int(generation.get("seed", 0)),
		int(generation.get("generation", 0)),
	]
	hud.add_child(_runtime_label)


func _get_world_seed() -> int:
	if GameState.has_method("get_world_seed"):
		return int(GameState.call("get_world_seed"))

	var seed_value: Variant = GameState.get("world_seed")

	if seed_value != null:
		return int(seed_value)

	return 1
