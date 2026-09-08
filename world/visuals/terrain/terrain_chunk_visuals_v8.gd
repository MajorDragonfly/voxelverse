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
