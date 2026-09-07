extends "res://world/visuals/terrain/terrain_chunk_visuals_v7_runtime.gd"


func _apply_terrain_material(terrain_mesh: MeshInstance3D) -> void:
	super._apply_terrain_material(terrain_mesh)
	var material := terrain_mesh.material_override as ShaderMaterial
	if material == null:
		return
	var profile: Dictionary = WorldGenerator.get_planet_profile()
	var palette: Dictionary = profile.get("palette", {})
	var slots: Dictionary = profile.get("material_slots", {})
	var rock: Color = palette.get("rock", Color(0.37, 0.38, 0.39, 1.0))
	var snow: Color = palette.get("snow", Color(0.86, 0.90, 0.91, 1.0))
	var grass: Color = palette.get("grass", Color(0.30, 0.54, 0.28, 1.0))
	material.set_shader_parameter(&"rock_color", Vector3(rock.r, rock.g, rock.b))
	var strata: Color = slots.get("rock_light", rock.lightened(0.12))
	material.set_shader_parameter(&"rock_strata_color", Vector3(strata.r, strata.g, strata.b))
	material.set_shader_parameter(&"snow_color", Vector3(snow.r, snow.g, snow.b))
	var wet: Color = slots.get("ground_shadow", grass.darkened(0.44))
	material.set_shader_parameter(&"wet_ground_color", Vector3(wet.r, wet.g, wet.b))
	material.set_shader_parameter(
		&"snow_start_altitude",
		float(profile.get("snow_start_altitude", 18.0))
	)
	material.set_shader_parameter(
		&"snow_end_altitude",
		float(profile.get("snow_end_altitude", 23.0))
	)
	material.set_shader_parameter(&"rocky_height", 6.0)
	material.set_shader_parameter(&"rock_slope_start", 0.22)
	material.set_shader_parameter(&"rock_slope_end", 0.58)
	material.set_shader_parameter(&"strata_strength", 0.14)


func _apply_water_material(chunk: Node, water_mesh: MeshInstance3D) -> void:
	super._apply_water_material(chunk, water_mesh)
	var material := water_mesh.material_override as ShaderMaterial
	if material == null:
		return
	var profile: Dictionary = WorldGenerator.get_planet_profile()
	var slots: Dictionary = profile.get("material_slots", {})
	var deep: Color = slots.get("water_deep", deep_water_color)
	var shallow: Color = slots.get("water_shallow", shallow_water_color)
	# Palette RGB describes pigment; preserve the water renderer's opacity.
	deep.a = deep_water_color.a
	shallow.a = shallow_water_color.a
	material.set_shader_parameter("deep_color", deep)
	material.set_shader_parameter("shallow_color", shallow)
	var atmosphere: Dictionary = profile.get("atmosphere", {})
	var horizon: Color = atmosphere.get("sky_horizon", Color(0.7, 0.8, 0.9))
	material.set_shader_parameter("reflection_tint", Vector3(horizon.r, horizon.g, horizon.b))
	var stillness: float = 0.0
	if WorldGenerator.has_method("get_biome_composition"):
		var composition: Dictionary = WorldGenerator.call("get_biome_composition", chunk.global_position.x, chunk.global_position.z)
		stillness = float(composition.get("water_style", {}).get("still", 0.0))
	material.set_shader_parameter("wave_height", wave_height * lerpf(1.0, 0.25, stillness))
	material.set_shader_parameter("wave_speed", wave_speed * lerpf(1.0, 0.4, stillness))
