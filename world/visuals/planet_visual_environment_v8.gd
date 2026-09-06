extends "res://world/visuals/planet_visual_environment.gd"


func _ready() -> void:
	super._ready()
	_apply_planet_identity()


func _apply_planet_identity() -> void:
	var profile: Dictionary = WorldGenerator.get_planet_profile()
	var palette: Dictionary = profile.get("palette", {})
	var water: Color = palette.get("water", Color(0.04, 0.35, 0.44, 1.0))
	var grass: Color = palette.get("grass", Color(0.30, 0.54, 0.28, 1.0))
	var dry: Color = palette.get("dry", Color(0.64, 0.50, 0.24, 1.0))
	var warmth: float = float(profile.get("sun_warmth", 0.5))
	var haze: float = float(profile.get("atmosphere_haze", 0.28))

	_sky_material.sky_top_color = water.darkened(0.18).lerp(Color(0.18, 0.40, 0.72, 1.0), 0.62)
	_sky_material.sky_horizon_color = Color(0.72, 0.82, 0.90, 1.0).lerp(dry.lightened(0.35), warmth * 0.18)
	_sky_material.ground_horizon_color = grass.lerp(dry, 0.32).darkened(0.08)
	_sky_material.ground_bottom_color = grass.darkened(0.72)

	_environment.ambient_light_color = _sky_material.sky_horizon_color.lerp(Color.WHITE, 0.18)
	_environment.ambient_light_energy = 0.78
	_environment.adjustment_brightness = 1.02
	_environment.adjustment_contrast = 1.07
	_environment.adjustment_saturation = 1.10
	# Strong SSAO was producing near-black creases on stepped terrain.
	_environment.ssao_enabled = true
	_environment.ssao_intensity = 0.82
	_environment.ssao_power = 1.08
	_environment.ssao_radius = 1.15
	_environment.ssao_detail = 0.42
	_environment.ssao_light_affect = 0.05
	_environment.glow_intensity = 0.055
	_environment.glow_bloom = 0.025
	_environment.fog_density = clampf(haze, 0.12, 0.45)
	_environment.fog_depth_begin = 105.0
	_environment.fog_depth_end = 300.0
	_environment.fog_depth_curve = 1.18
	_environment.fog_light_color = _sky_material.sky_horizon_color
	_environment.fog_sun_scatter = 0.16
	_environment.fog_aerial_perspective = 0.72

	var cool_sun := Color(1.0, 0.96, 0.90, 1.0)
	var warm_sun := Color(1.0, 0.82, 0.64, 1.0)
	sun.light_color = cool_sun.lerp(warm_sun, warmth * 0.62)
	sun.light_energy = 1.02
	sun.light_indirect_energy = 0.92
	sun.shadow_bias = 0.11
	sun.shadow_normal_bias = 1.55
	sun.shadow_blur = 1.35
	sun.directional_shadow_max_distance = 165.0
