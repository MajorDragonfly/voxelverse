extends SceneTree
const Atmosphere = preload("res://world/visuals/atmosphere/campaign_atmosphere.gd")
const Water = preload("res://world/visuals/underwater_view.gd")
const Profile = preload("res://world/generation/planet_profile_v9.gd")
var failures: Array[String] = []
var sample: Dictionary = {"up": Vector3.UP, "height": 30.0, "moisture": 0.6, "seconds": 72.0}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var settings := root.get_node("DisplaySettings")
	if "--atmosphere-restart" in OS.get_cmdline_user_args():
		_expect(settings.atmosphere_quality == 2, "Fresh process lost quality preference.")
		print("ATMOSPHERE_FRESH_PROCESS_PASSED" if failures.is_empty() else "ATMOSPHERE_RESTART_FAILED")
		await _finish()
		return
	await process_frame
	var scene := Node3D.new()
	root.add_child(scene)
	var air := Atmosphere.new()
	scene.add_child(air)
	var profile: Dictionary = Profile.create(15838)
	var before: Dictionary = profile.duplicate(true)
	air.configure(profile, 15838, Vector3.UP, func(): return sample)
	_expect(profile == before, "Atmosphere changed the planet profile.")
	_expect(air.environment.background_mode == Environment.BG_SKY, "Campaign sky is not connected.")
	_expect(air.sun.global_basis.z.dot(air._sun_direction) > 0.999, "Visible sun and actual light disagree.")
	var day_energy: float = air.sun.light_energy
	for up: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		sample.up = up
		air.update_view(0.1, true)
		_expect(air.sky_material.get_shader_parameter("radial_up").is_equal_approx(up), "Sky horizon ignores radial up.")
		_expect(air.environment.fog_height_density == 0.0 and air.sun.basis.is_finite(), "Global Y fog or invalid radial lighting.")
	sample.up = -air._sun_direction
	air.update_view(0.1, true)
	_expect(air.sun.light_energy == 0.0 and air.environment.ambient_light_energy > 0.0, "Night side has daylight or unreadable black shadows.")
	sample.up = Vector3.UP
	air.update_view(0.1, true)
	_expect(is_equal_approx(air.sun.light_energy, day_energy), "Returning to home changed sun energy.")
	var offset: Vector3 = air.sky_material.get_shader_parameter("cloud_offset")
	paused = true
	for i in range(5): await process_frame
	_expect(air.sky_material.get_shader_parameter("cloud_offset") == offset, "Paused sky animated.")
	paused = false
	sample.seconds += 120.0
	air.update_view(0.1)
	_expect(not air.sky_material.get_shader_parameter("cloud_offset").is_equal_approx(offset), "Clouds do not move with active time.")
	sample.seconds = 7199.999
	air.update_view(0.1)
	var end_offset: Vector3 = air.sky_material.get_shader_parameter("cloud_offset")
	sample.seconds = 7200.001
	air.update_view(0.1)
	_expect(end_offset.distance_to(air.sky_material.get_shader_parameter("cloud_offset")) < 0.0001, "Cloud animation jumps at clock wrap.")
	sample.moisture = 0.0
	air.update_view(0.1,true)
	var dry_density: float = air.environment.fog_density
	sample.moisture = 1.0
	air.update_view(0.1)
	_expect(air.environment.fog_density > dry_density and air._moisture < 0.1, "Biome mist changes abruptly.")
	var low_density: float = air.environment.fog_density
	sample.height = 18000.0
	air.update_view(0.1,true)
	_expect(air.environment.fog_density < low_density, "High altitude retains dense surface fog.")
	sample.height = 30.0
	# Integration: the same weather snapshot drives rain clouds, light and haze.
	sample.weather = {"cloud_cover": 0.16, "precipitation": 0.0, "visibility_m": 18000.0}
	air.update_view(0.1,true)
	var clear_energy: float = air.sun.light_energy
	var clear_distance: float = air.environment.fog_depth_end
	sample.weather = {"cloud_cover": 0.96, "precipitation": 0.65, "visibility_m": 8000.0}
	air.update_view(0.1,true)
	_expect(float(air.sky_material.get_shader_parameter("cloud_cover")) > 0.9, "Rain weather did not reach the shader sky.")
	_expect(air.sun.light_energy < clear_energy and air.environment.fog_depth_end < clear_distance, "Rain did not soften light and visibility.")
	# The persisted climate's vacuum flag must reach the shared sky, not only rain.
	sample.weather = {"atmosphere_present": false, "cloud_cover": 0.0, "precipitation": 0.0}
	for quality in [0, 1, 2]:
		air.set_quality(quality)
		_expect(not air.environment.fog_enabled and not air.environment.volumetric_fog_enabled, "Vacuum retained atmospheric fog after graphics change.")
		_expect(is_zero_approx(air.environment.fog_density) and is_zero_approx(air.environment.volumetric_fog_density), "Vacuum retained fog density.")
		_expect(not air.sky_material.get_shader_parameter("atmosphere_present") and not air.sky_material.get_shader_parameter("clouds_enabled"), "Vacuum retained sky scattering/clouds.")
		_expect(air.sun.light_energy > 0.0, "Vacuum incorrectly extinguished the sun.")
	sample.weather = {"atmosphere_present": true, "cloud_cover": 0.5}
	air.update_view(0.1, true)
	_expect(air.environment.fog_enabled and air.sky_material.get_shader_parameter("atmosphere_present") and air.sky_material.get_shader_parameter("clouds_enabled"), "Returning to an atmosphere did not restore the sky.")
	sample.erase("weather")
	for quality in [2,0,1,2,0]:
		air.set_quality(quality)
		var supported: bool = RenderingServer.get_current_rendering_method() == "forward_plus"
		_expect(air.environment.volumetric_fog_enabled == (quality == 2 and supported), "Quality does not disable unsupported/expensive fog.")
		_expect(air.environment.ssao_enabled == (quality >= 1 and supported), "AO quality switch is sticky.")
		_expect(air.environment.glow_enabled == (quality >= 1 and supported), "Glow quality switch is sticky.")
	# Actual settings control, persistence and group broadcast while paused.
	var option: OptionButton = settings._menu_layer.find_child("AtmosphereQuality",true,false)
	_expect(option != null and option.item_count == 4, "F8 has no usable atmosphere choice.")
	settings.open_menu()
	settings._tabs.current_tab = settings._tabs.get_node("GRAPHICS_TAB").get_index()
	option.select(2)
	option.item_selected.emit(2)
	settings._apply_menu_selection()
	_expect(paused and settings.atmosphere_quality == 2 and air.quality == 2, "Applying graphics preference did not reach paused campaign.")
	settings.close_menu()
	settings.open_menu()
	settings._tabs.current_tab = settings._tabs.get_node("GRAPHICS_TAB").get_index()
	option.select(0)
	option.item_selected.emit(0)
	option.get_popup().popup()
	settings.close_menu()
	_expect(not option.get_popup().visible and not paused, "Closing graphics settings left popup or pause active.")
	_expect(settings.atmosphere_quality == 2 and air.quality == 2, "Unapplied graphics selection changed active effects.")
	settings.open_menu()
	_expect(option.selected == 2 and settings._atmosphere_description.text == "ATMOSPHERE_CINEMATIC_DESCRIPTION", "Reopening did not discard unapplied selection and explanation.")
	settings.close_menu()
	var config := ConfigFile.new()
	_expect(config.load(settings.CONFIG_PATH) == OK and config.get_value("display","atmosphere_quality",-1) == 2, "Quality was not written alongside display settings.")
	# Camera override must remain owned by UnderwaterView across changing air/quality.
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.make_current()
	var water := Water.new()
	water.sample_water = func(_point: Vector3): return {"water": true,"depth": 3.0}
	scene.add_child(water)
	water.update_view()
	var underwater: Environment = camera.environment
	air.set_quality(0)
	air.update_view(0.1,true)
	_expect(camera.environment == underwater and not underwater.volumetric_fog_enabled and not underwater.glow_enabled, "Air effects overwrote underwater atmosphere.")
	water.sample_water = func(_point: Vector3): return {"water": false,"depth": -1.0}
	water.update_view()
	_expect(camera.environment == null and camera.get_world_3d().environment == air.environment, "Surfacing did not restore current air.")
	# Reconstruct at identical canonical inputs, as after travel/reload; no global RNG.
	var second := Atmosphere.new()
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	scene.add_child(viewport)
	viewport.add_child(second)
	second.configure(profile,15838,Vector3.UP,func(): return sample)
	_expect(second.sky_material != air.sky_material and second.environment != air.environment, "Atmosphere resources are shared across scenes.")
	_expect(second.sky_material.get_shader_parameter("cloud_offset") == air.sky_material.get_shader_parameter("cloud_offset"), "Revisit changed canonical clouds.")
	second.free()
	scene.free()
	await process_frame
	_expect(get_nodes_in_group(&"campaign_atmosphere").is_empty(), "Scene teardown leaked atmosphere owner.")
	var output: Array = []
	var command: PackedStringArray = ["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/campaign_atmosphere_test.gd","--","--atmosphere-restart"]
	var code: int = OS.execute(OS.get_executable_path(),command,output,true)
	_expect(code == 0 and str(output).contains("ATMOSPHERE_FRESH_PROCESS_PASSED"),"Fresh preference process failed: "+str(output))
	print("CAMPAIGN_ATMOSPHERE_PASSED" if failures.is_empty() else "CAMPAIGN_ATMOSPHERE_FAILED")
	await _finish()

func _expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _finish() -> void:
	for message in failures: push_error(message)
	await preload("res://core/runtime_shutdown.gd").finish(self,0 if failures.is_empty() else 1)
