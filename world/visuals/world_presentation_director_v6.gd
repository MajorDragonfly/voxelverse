extends "res://world/visuals/world_presentation_director.gd"

# V6 keeps the inexpensive clustered voxel clouds but replaces the over-strong
# contact shading that turned every micro terrace into a black trench.

func _tune_environment() -> void:
	var environment_controller: Node = get_tree().get_first_node_in_group(
		&"planet_visual_environment"
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
	environment.tonemap_exposure = 1.04
	environment.tonemap_agx_contrast = 1.18
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.03
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.12
	environment.ssao_enabled = true
	environment.ssao_intensity = 0.58
	environment.ssao_power = 0.88
	environment.ssao_radius = 1.05
	environment.glow_enabled = true
	environment.glow_intensity = 0.045
	environment.glow_bloom = 0.025
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.72, 0.82, 0.90, 1.0)
	environment.fog_sky_affect = 0.28

	var sun := environment_controller.get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_energy = 0.92
		sun.shadow_opacity = 0.62
		sun.shadow_bias = 0.08
		sun.shadow_normal_bias = 1.25
