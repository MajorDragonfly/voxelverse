extends Node3D

@export_category("Atmosphere")
@export_range(0, 160, 1)
var cloud_voxel_count: int = 72

@export_range(10.0, 120.0, 1.0)
var cloud_altitude: float = 34.0

@export_range(50.0, 800.0, 10.0)
var cloud_field_radius: float = 310.0

@export var wind_direction: Vector2 = Vector2(0.72, 0.36)

@export_range(0.0, 10.0, 0.05)
var wind_speed: float = 0.85

var _player: Node3D
var _cloud_layer: MultiMeshInstance3D
var _wind_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_player = get_node_or_null("../Player") as Node3D
	call_deferred("_initialize_presentation")


func _process(delta: float) -> void:
	if _cloud_layer == null or not is_instance_valid(_cloud_layer):
		return

	var normalized_wind: Vector2 = wind_direction.normalized()
	_wind_offset += normalized_wind * wind_speed * delta

	if _player != null:
		_cloud_layer.global_position = Vector3(
			_player.global_position.x + _wind_offset.x,
			cloud_altitude,
			_player.global_position.z + _wind_offset.y
		)

	if _wind_offset.length() > cloud_field_radius * 0.35:
		_wind_offset = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo:
		return

	if event.keycode == KEY_F7:
		var new_seed: int = WorldGenerator.regenerate_with_random_seed()
		print("Generating new Voxelverse world with seed: ", new_seed)
		get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F9:
		print("Reloading Voxelverse world seed: ", WorldGenerator.get_world_seed())
		get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()


func _initialize_presentation() -> void:
	_tune_environment()
	_create_voxel_cloud_layer()


func _tune_environment() -> void:
	var environment_controller: Node = get_tree().get_first_node_in_group(
		"planet_visual_environment"
	)
	if environment_controller == null:
		return

	var world_environment := environment_controller.get_node_or_null(
		"WorldEnvironment"
	) as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		return

	var environment: Environment = world_environment.environment
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.03
	environment.tonemap_agx_contrast = 1.24
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.01
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.10
	environment.ssao_enabled = true
	environment.ssao_intensity = 1.55
	environment.ssao_power = 1.25
	environment.ssao_radius = 2.1
	environment.glow_enabled = true
	environment.glow_intensity = 0.10
	environment.glow_bloom = 0.055
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.63, 0.72, 0.76, 1.0)
	environment.fog_sky_affect = 0.72


func _create_voxel_cloud_layer() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = WorldGenerator.get_world_seed() + 914_771_223

	var cloud_mesh := BoxMesh.new()
	cloud_mesh.size = Vector3.ONE

	var cloud_material := StandardMaterial3D.new()
	cloud_material.albedo_color = Color.WHITE
	cloud_material.vertex_color_use_as_albedo = true
	cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_material.roughness = 1.0
	cloud_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloud_mesh.material = cloud_material

	var cloud_multimesh := MultiMesh.new()
	cloud_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	cloud_multimesh.use_colors = true
	cloud_multimesh.mesh = cloud_mesh
	cloud_multimesh.instance_count = cloud_voxel_count

	for index in range(cloud_voxel_count):
		var angle: float = random.randf_range(0.0, TAU)
		var distance: float = sqrt(random.randf()) * cloud_field_radius
		var width: float = random.randf_range(12.0, 38.0)
		var height: float = random.randf_range(1.2, 4.8)
		var depth: float = random.randf_range(5.0, 18.0)
		var basis := Basis(Vector3.UP, random.randf_range(-0.18, 0.18)).scaled(
			Vector3(width, height, depth)
		)
		var transform := Transform3D(
			basis,
			Vector3(
				cos(angle) * distance,
				random.randf_range(-5.0, 7.0),
				sin(angle) * distance
			)
		)
		var brightness: float = random.randf_range(0.72, 1.0)
		var alpha: float = random.randf_range(0.10, 0.26)

		cloud_multimesh.set_instance_transform(index, transform)
		cloud_multimesh.set_instance_color(
			index,
			Color(brightness, brightness, brightness * 1.03, alpha)
		)

	_cloud_layer = MultiMeshInstance3D.new()
	_cloud_layer.name = "ProceduralVoxelClouds"
	_cloud_layer.multimesh = cloud_multimesh
	_cloud_layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cloud_layer.visibility_range_end = cloud_field_radius * 1.35
	add_child(_cloud_layer)

	if _player != null:
		_cloud_layer.global_position = Vector3(
			_player.global_position.x,
			cloud_altitude,
			_player.global_position.z
		)
