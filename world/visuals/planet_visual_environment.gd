class_name PlanetVisualEnvironment

extends Node3D


signal visual_mode_changed(mode: int)


enum VisualMode {
	SURFACE,
	UPPER_ATMOSPHERE,
	ORBIT,
	DEEP_SPACE
}


@export_category("Startup")

@export_enum(
	"Surface",
	"Upper Atmosphere",
	"Orbit",
	"Deep Space"
)
var startup_mode: int = VisualMode.SURFACE

@export
var enable_debug_mode_keys: bool = true


@export_category("Sun")

@export_range(-90.0, 90.0, 1.0)
var sun_elevation_degrees: float = 48.0

@export_range(-180.0, 180.0, 1.0)
var sun_azimuth_degrees: float = -35.0

@export_range(0.0, 5.0, 0.05)
var surface_sun_energy: float = 1.25

@export
var surface_sun_color: Color = Color(
	1.0,
	0.86,
	0.68,
	1.0
)

@export_range(20.0, 500.0, 5.0)
var surface_shadow_distance: float = 180.0

@export_range(0.0, 2.0, 0.05)
var sun_angular_distance: float = 0.35


@export_category("Surface Atmosphere")

@export_range(10.0, 500.0, 5.0)
var surface_fog_begin: float = 70.0

@export_range(20.0, 1000.0, 5.0)
var surface_fog_end: float = 210.0

@export_range(0.0, 1.0, 0.01)
var surface_fog_strength: float = 0.88

@export
var enable_surface_volumetric_fog: bool = false

@export_range(0.0, 0.05, 0.0005)
var surface_volumetric_fog_density: float = 0.003

@export_range(16.0, 512.0, 8.0)
var surface_volumetric_fog_length: float = 160.0


var _environment: Environment
var _sky: Sky
var _sky_material: ProceduralSkyMaterial

var _current_visual_mode: int = VisualMode.SURFACE


@onready
var world_environment: WorldEnvironment = $WorldEnvironment

@onready
var sun: DirectionalLight3D = $Sun


func _ready() -> void:
	add_to_group(&"planet_visual_environment")

	_create_environment_resources()
	_configure_sun()
	set_visual_mode(startup_mode)

	print(
		"Planet visual environment initialized in mode: ",
		get_visual_mode_name()
	)


func _create_environment_resources() -> void:
	_environment = Environment.new()
	_sky = Sky.new()
	_sky_material = ProceduralSkyMaterial.new()

	_sky.sky_material = _sky_material

	_environment.background_mode = Environment.BG_SKY
	_environment.sky = _sky

	_environment.ambient_light_source = (
		Environment.AMBIENT_SOURCE_SKY
	)

	_environment.reflected_light_source = (
		Environment.REFLECTION_SOURCE_SKY
	)

	_environment.tonemap_mode = (
		Environment.TONE_MAPPER_AGX
	)

	_environment.tonemap_exposure = 1.0
	_environment.tonemap_agx_contrast = 1.2

	_environment.adjustment_enabled = true
	_environment.adjustment_brightness = 1.0
	_environment.adjustment_contrast = 1.05
	_environment.adjustment_saturation = 1.05

	_environment.ssao_enabled = true
	_environment.ssao_intensity = 1.6
	_environment.ssao_power = 1.35
	_environment.ssao_radius = 1.8
	_environment.ssao_detail = 0.65
	_environment.ssao_light_affect = 0.08

	_environment.glow_enabled = true
	_environment.glow_blend_mode = (
		Environment.GLOW_BLEND_MODE_SCREEN
	)

	_environment.glow_intensity = 0.08
	_environment.glow_bloom = 0.04
	_environment.glow_hdr_threshold = 1.15
	_environment.glow_hdr_scale = 2.0

	_environment.set_glow_level(
		1,
		0.12
	)

	_environment.set_glow_level(
		2,
		0.45
	)

	_environment.set_glow_level(
		3,
		0.28
	)

	_environment.set_glow_level(
		4,
		0.08
	)

	_environment.set_glow_level(
		5,
		0.0
	)

	_environment.set_glow_level(
		6,
		0.0
	)

	world_environment.environment = _environment


func _configure_sun() -> void:
	sun.sky_mode = (
		DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	)

	sun.shadow_enabled = true

	sun.directional_shadow_mode = (
		DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	)

	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85

	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.50

	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.0

	sun.light_angular_distance = sun_angular_distance
	sun.light_volumetric_fog_energy = 1.0

	set_sun_angles(
		sun_elevation_degrees,
		sun_azimuth_degrees
	)


func set_sun_angles(
	elevation_degrees: float,
	azimuth_degrees: float
) -> void:
	sun_elevation_degrees = clampf(
		elevation_degrees,
		-90.0,
		90.0
	)

	sun_azimuth_degrees = wrapf(
		azimuth_degrees,
		-180.0,
		180.0
	)

	sun.rotation_degrees = Vector3(
		-sun_elevation_degrees,
		sun_azimuth_degrees,
		0.0
	)


func set_visual_mode(mode: int) -> void:
	var safe_mode: int = clampi(
		mode,
		VisualMode.SURFACE,
		VisualMode.DEEP_SPACE
	)

	match safe_mode:
		VisualMode.SURFACE:
			_apply_surface_profile()

		VisualMode.UPPER_ATMOSPHERE:
			_apply_upper_atmosphere_profile()

		VisualMode.ORBIT:
			_apply_orbit_profile()

		VisualMode.DEEP_SPACE:
			_apply_deep_space_profile()

	_current_visual_mode = safe_mode

	visual_mode_changed.emit(
		_current_visual_mode
	)

	print(
		"Planet visual mode changed to: ",
		get_visual_mode_name()
	)


func set_surface_mode() -> void:
	set_visual_mode(
		VisualMode.SURFACE
	)


func set_upper_atmosphere_mode() -> void:
	set_visual_mode(
		VisualMode.UPPER_ATMOSPHERE
	)


func set_orbit_mode() -> void:
	set_visual_mode(
		VisualMode.ORBIT
	)


func set_deep_space_mode() -> void:
	set_visual_mode(
		VisualMode.DEEP_SPACE
	)


func get_visual_mode() -> int:
	return _current_visual_mode


func get_visual_mode_name() -> String:
	match _current_visual_mode:
		VisualMode.SURFACE:
			return "Surface"

		VisualMode.UPPER_ATMOSPHERE:
			return "Upper Atmosphere"

		VisualMode.ORBIT:
			return "Orbit"

		VisualMode.DEEP_SPACE:
			return "Deep Space"

		_:
			return "Unknown"


func update_visual_mode_from_altitude(
	altitude: float,
	atmosphere_height: float
) -> void:
	var safe_atmosphere_height: float = maxf(
		atmosphere_height,
		0.001
	)

	var safe_altitude: float = maxf(
		altitude,
		0.0
	)

	if (
		safe_altitude
		<= safe_atmosphere_height * 0.04
	):
		set_surface_mode()
		return

	if safe_altitude <= safe_atmosphere_height:
		set_upper_atmosphere_mode()
		return

	if (
		safe_altitude
		<= safe_atmosphere_height * 3.0
	):
		set_orbit_mode()
		return

	set_deep_space_mode()


func _apply_surface_profile() -> void:
	_sky_material.sky_top_color = Color(
		0.17,
		0.39,
		0.69,
		1.0
	)

	_sky_material.sky_horizon_color = Color(
		0.72,
		0.78,
		0.84,
		1.0
	)

	_sky_material.ground_horizon_color = Color(
		0.63,
		0.53,
		0.41,
		1.0
	)

	_sky_material.ground_bottom_color = Color(
		0.10,
		0.085,
		0.075,
		1.0
	)

	_sky_material.sky_curve = 0.12
	_sky_material.ground_curve = 0.08

	_sky_material.energy_multiplier = 1.0
	_sky_material.sky_energy_multiplier = 1.0
	_sky_material.ground_energy_multiplier = 0.55

	_sky_material.sun_angle_max = 3.5
	_sky_material.sun_curve = 0.08
	_sky_material.use_debanding = true

	_environment.background_energy_multiplier = 0.9

	_environment.ambient_light_color = Color(
		0.43,
		0.50,
		0.62,
		1.0
	)

	_environment.ambient_light_energy = 0.72
	_environment.ambient_light_sky_contribution = 0.82

	_environment.tonemap_exposure = 1.05
	_environment.tonemap_agx_contrast = 1.22

	_environment.adjustment_brightness = 1.01
	_environment.adjustment_contrast = 1.08
	_environment.adjustment_saturation = 1.08

	_environment.ssao_enabled = true
	_environment.ssao_intensity = 1.65
	_environment.ssao_power = 1.35
	_environment.ssao_radius = 1.8

	_environment.glow_enabled = true
	_environment.glow_intensity = 0.08
	_environment.glow_bloom = 0.04

	_environment.fog_enabled = true
	_environment.fog_mode = Environment.FOG_MODE_DEPTH

	_environment.fog_density = clampf(
		surface_fog_strength,
		0.0,
		1.0
	)

	_environment.fog_depth_begin = minf(
		surface_fog_begin,
		surface_fog_end - 1.0
	)

	_environment.fog_depth_end = maxf(
		surface_fog_end,
		surface_fog_begin + 1.0
	)

	_environment.fog_depth_curve = 1.35

	_environment.fog_light_color = Color(
		0.68,
		0.73,
		0.78,
		1.0
	)

	_environment.fog_light_energy = 0.9
	_environment.fog_sun_scatter = 0.22
	_environment.fog_sky_affect = 0.38
	_environment.fog_aerial_perspective = 0.65

	_environment.volumetric_fog_enabled = (
		enable_surface_volumetric_fog
	)

	_environment.volumetric_fog_density = (
		surface_volumetric_fog_density
	)

	_environment.volumetric_fog_length = (
		surface_volumetric_fog_length
	)

	_environment.volumetric_fog_albedo = Color(
		0.88,
		0.90,
		0.94,
		1.0
	)

	_environment.volumetric_fog_emission = Color(
		0.10,
		0.12,
		0.16,
		1.0
	)

	_environment.volumetric_fog_emission_energy = 0.35
	_environment.volumetric_fog_ambient_inject = 0.75
	_environment.volumetric_fog_anisotropy = 0.45
	_environment.volumetric_fog_sky_affect = 0.65

	sun.light_color = surface_sun_color
	sun.light_energy = surface_sun_energy
	sun.light_indirect_energy = 0.85
	sun.shadow_enabled = true

	sun.directional_shadow_max_distance = (
		surface_shadow_distance
	)


func _apply_upper_atmosphere_profile() -> void:
	_sky_material.sky_top_color = Color(
		0.025,
		0.08,
		0.20,
		1.0
	)

	_sky_material.sky_horizon_color = Color(
		0.28,
		0.52,
		0.78,
		1.0
	)

	_sky_material.ground_horizon_color = Color(
		0.42,
		0.31,
		0.25,
		1.0
	)

	_sky_material.ground_bottom_color = Color(
		0.025,
		0.025,
		0.035,
		1.0
	)

	_sky_material.sky_curve = 0.09
	_sky_material.ground_curve = 0.04

	_sky_material.energy_multiplier = 0.82
	_sky_material.sky_energy_multiplier = 0.9
	_sky_material.ground_energy_multiplier = 0.25

	_sky_material.sun_angle_max = 2.5
	_sky_material.sun_curve = 0.06

	_environment.background_energy_multiplier = 0.75

	_environment.ambient_light_color = Color(
		0.16,
		0.24,
		0.40,
		1.0
	)

	_environment.ambient_light_energy = 0.45
	_environment.ambient_light_sky_contribution = 0.68

	_environment.tonemap_exposure = 1.0
	_environment.tonemap_agx_contrast = 1.25

	_environment.adjustment_brightness = 1.0
	_environment.adjustment_contrast = 1.10
	_environment.adjustment_saturation = 1.02

	_environment.ssao_enabled = true
	_environment.ssao_intensity = 1.35
	_environment.ssao_power = 1.25
	_environment.ssao_radius = 2.0

	_environment.glow_enabled = true
	_environment.glow_intensity = 0.12
	_environment.glow_bloom = 0.07

	_environment.fog_enabled = true
	_environment.fog_mode = (
		Environment.FOG_MODE_EXPONENTIAL
	)

	_environment.fog_density = 0.0015

	_environment.fog_light_color = Color(
		0.30,
		0.47,
		0.70,
		1.0
	)

	_environment.fog_light_energy = 0.75
	_environment.fog_sun_scatter = 0.42
	_environment.fog_sky_affect = 0.20
	_environment.fog_aerial_perspective = 0.85

	_environment.volumetric_fog_enabled = false

	sun.light_color = Color(
		1.0,
		0.88,
		0.72,
		1.0
	)

	sun.light_energy = 1.32
	sun.light_indirect_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0


func _apply_orbit_profile() -> void:
	_sky_material.sky_top_color = Color(
		0.001,
		0.003,
		0.012,
		1.0
	)

	_sky_material.sky_horizon_color = Color(
		0.015,
		0.045,
		0.12,
		1.0
	)

	_sky_material.ground_horizon_color = Color(
		0.005,
		0.012,
		0.025,
		1.0
	)

	_sky_material.ground_bottom_color = Color(
		0.001,
		0.001,
		0.003,
		1.0
	)

	_sky_material.sky_curve = 0.04
	_sky_material.ground_curve = 0.02

	_sky_material.energy_multiplier = 0.35
	_sky_material.sky_energy_multiplier = 0.45
	_sky_material.ground_energy_multiplier = 0.10

	_sky_material.sun_angle_max = 1.2
	_sky_material.sun_curve = 0.035

	_environment.background_energy_multiplier = 0.35

	_environment.ambient_light_color = Color(
		0.055,
		0.075,
		0.12,
		1.0
	)

	_environment.ambient_light_energy = 0.22
	_environment.ambient_light_sky_contribution = 0.35

	_environment.tonemap_exposure = 0.92
	_environment.tonemap_agx_contrast = 1.28

	_environment.adjustment_brightness = 0.98
	_environment.adjustment_contrast = 1.12
	_environment.adjustment_saturation = 0.98

	_environment.ssao_enabled = true
	_environment.ssao_intensity = 1.2
	_environment.ssao_power = 1.2
	_environment.ssao_radius = 2.5

	_environment.glow_enabled = true
	_environment.glow_intensity = 0.14
	_environment.glow_bloom = 0.08

	_environment.fog_enabled = false
	_environment.volumetric_fog_enabled = false

	sun.light_color = Color(
		1.0,
		0.96,
		0.88,
		1.0
	)

	sun.light_energy = 1.4
	sun.light_indirect_energy = 0.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 350.0


func _apply_deep_space_profile() -> void:
	_sky_material.sky_top_color = Color(
		0.0002,
		0.0003,
		0.001,
		1.0
	)

	_sky_material.sky_horizon_color = Color(
		0.0004,
		0.0006,
		0.0015,
		1.0
	)

	_sky_material.ground_horizon_color = Color(
		0.0002,
		0.0002,
		0.0004,
		1.0
	)

	_sky_material.ground_bottom_color = Color(
		0.0001,
		0.0001,
		0.0002,
		1.0
	)

	_sky_material.sky_curve = 0.01
	_sky_material.ground_curve = 0.01

	_sky_material.energy_multiplier = 0.08
	_sky_material.sky_energy_multiplier = 0.08
	_sky_material.ground_energy_multiplier = 0.02

	_sky_material.sun_angle_max = 0.65
	_sky_material.sun_curve = 0.02

	_environment.background_energy_multiplier = 0.08

	_environment.ambient_light_color = Color(
		0.015,
		0.020,
		0.035,
		1.0
	)

	_environment.ambient_light_energy = 0.12
	_environment.ambient_light_sky_contribution = 0.18

	_environment.tonemap_exposure = 0.85
	_environment.tonemap_agx_contrast = 1.30

	_environment.adjustment_brightness = 0.96
	_environment.adjustment_contrast = 1.15
	_environment.adjustment_saturation = 0.92

	_environment.ssao_enabled = true
	_environment.ssao_intensity = 1.05
	_environment.ssao_power = 1.15
	_environment.ssao_radius = 2.5

	_environment.glow_enabled = true
	_environment.glow_intensity = 0.16
	_environment.glow_bloom = 0.10

	_environment.fog_enabled = false
	_environment.volumetric_fog_enabled = false

	sun.light_color = Color(
		1.0,
		0.98,
		0.92,
		1.0
	)

	sun.light_energy = 1.25
	sun.light_indirect_energy = 0.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 400.0


func _unhandled_key_input(
	event: InputEvent
) -> void:
	if not enable_debug_mode_keys:
		return

	if event is not InputEventKey:
		return

	var key_event: InputEventKey = (
		event as InputEventKey
	)

	if not key_event.pressed:
		return

	if key_event.echo:
		return

	match key_event.keycode:
		KEY_1:
			set_surface_mode()

		KEY_2:
			set_upper_atmosphere_mode()

		KEY_3:
			set_orbit_mode()

		KEY_4:
			set_deep_space_mode()
