extends "res://world/visuals/world_presentation_director.gd"

# Presentation stays intentionally stylised, but each planet now derives its
# atmosphere, horizon, sunlight and cloud density from the same deterministic
# profile that drives terrain and ecology.


func _initialize_presentation() -> void:
	var profile: Dictionary = WorldGenerator.get_planet_profile()
	var flora_scale: float = clampf(
		float(profile.get("flora_scale", 1.0)),
		0.55,
		1.55
	)
	var haze: float = clampf(
		float(profile.get("atmosphere_haze", 0.28)),
		0.12,
		0.55
	)
	cloud_voxel_count = clampi(
		roundi(lerpf(118.0, 224.0, inverse_lerp(0.55, 1.55, flora_scale))),
		96,
		240
	)
	cloud_altitude = lerpf(46.0, 34.0, haze)
	cloud_field_radius = 330.0
	wind_speed = lerpf(0.46, 0.86, haze)
	super._initialize_presentation()


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

	var profile: Dictionary = WorldGenerator.get_planet_profile()
	var palette: Dictionary = profile.get("palette", {})
	var grass: Color = palette.get("grass", Color(0.30, 0.54, 0.28, 1.0))
	var dry: Color = palette.get("dry", Color(0.68, 0.52, 0.28, 1.0))
	var water: Color = palette.get("water", Color(0.04, 0.35, 0.44, 1.0))
	var rock: Color = palette.get("rock", Color(0.38, 0.38, 0.39, 1.0))
	var warmth: float = clampf(float(profile.get("sun_warmth", 0.5)), 0.0, 1.0)
	var haze: float = clampf(float(profile.get("atmosphere_haze", 0.28)), 0.12, 0.55)

	var environment: Environment = world_environment.environment
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.08
	environment.tonemap_agx_contrast = 1.10
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.045
	environment.adjustment_contrast = 1.045
	environment.adjustment_saturation = 1.10

	# Keep contact definition without the black trench effect that the earlier
	# SSAO settings produced on every 0.25 m terrace.
	environment.ssao_enabled = true
	environment.ssao_intensity = 0.42
	environment.ssao_power = 0.78
	environment.ssao_radius = 0.78
	environment.ssao_detail = 0.34
	environment.ssao_light_affect = 0.16

	environment.glow_enabled = true
	environment.glow_intensity = 0.035
	environment.glow_bloom = 0.018

	var fog_color: Color = Color(0.66, 0.78, 0.86, 1.0).lerp(
		dry.lightened(0.24),
		warmth * 0.22
	)
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_density = lerpf(0.14, 0.30, haze)
	environment.fog_depth_begin = lerpf(125.0, 88.0, haze)
	environment.fog_depth_end = lerpf(325.0, 235.0, haze)
	environment.fog_depth_curve = 1.42
	environment.fog_light_color = fog_color
	environment.fog_light_energy = 0.96
	environment.fog_sky_affect = 0.26
	environment.fog_aerial_perspective = 0.74
	environment.fog_sun_scatter = lerpf(0.16, 0.30, warmth)

	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color(0.56, 0.65, 0.72, 1.0).lerp(
		water.lightened(0.36),
		0.18
	)
	environment.ambient_light_energy = 0.84
	environment.ambient_light_sky_contribution = 0.88

	var sky: Sky = environment.sky
	if sky != null:
		var sky_material := sky.sky_material as ProceduralSkyMaterial
		if sky_material != null:
			var sky_top: Color = Color(0.075, 0.25, 0.54, 1.0).lerp(
				water.lightened(0.14),
				0.22
			)
			var sky_horizon: Color = Color(0.69, 0.78, 0.86, 1.0).lerp(
				dry.lightened(0.30),
				warmth * 0.20
			)
			var ground_horizon: Color = dry.lerp(grass, 0.30).darkened(0.05)
			sky_material.sky_top_color = sky_top
			sky_material.sky_horizon_color = sky_horizon
			sky_material.ground_horizon_color = ground_horizon
			sky_material.ground_bottom_color = rock.darkened(0.52)
			sky_material.sky_curve = 0.16
			sky_material.ground_curve = 0.12
			sky_material.energy_multiplier = 1.02
			sky_material.sun_angle_max = lerpf(2.3, 4.1, warmth)
			sky_material.sun_curve = 0.065
			sky_material.use_debanding = true

	var sun := environment_controller.get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		var cool_sun := Color(0.94, 0.97, 1.0, 1.0)
		var warm_sun := Color(1.0, 0.84, 0.64, 1.0)
		sun.light_color = cool_sun.lerp(warm_sun, warmth)
		sun.light_energy = lerpf(1.00, 1.12, warmth)
		sun.light_indirect_energy = 0.92
		sun.shadow_opacity = 0.52
		sun.shadow_bias = 0.10
		sun.shadow_normal_bias = 1.42
		sun.shadow_blur = 1.35
