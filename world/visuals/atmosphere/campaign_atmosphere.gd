extends Node3D
## Presentation-only owner. Reads the campaign clock and canonical radial frame;
## never writes terrain, saves, camera overrides or simulation state.
const Cube = preload("res://world/space/cube_sphere.gd")
const SKY_SHADER = preload("res://world/visuals/atmosphere/campaign_sky.gdshader")
var environment: Environment
var sun: DirectionalLight3D
var sky_material: ShaderMaterial
var quality: int = 1
var source: Callable
var _profile: Dictionary = {}
var _seed: int = 0
var _elapsed: float = 0.0
var _moisture: float = 0.5
var _sun_direction := Vector3(0, 0.6, 0.8).normalized()
var _tick: float = 0.0
var _configured: bool = false
var _forward_plus: bool = false
var _weather: Node
var _previous_weather_clouds: bool = true

func _ready() -> void:
	name = "CampaignAtmosphere"
	add_to_group(&"campaign_atmosphere")
	process_priority = 90 # Before the camera-owned underwater override.
	environment = Environment.new()
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	add_child(world)
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_height_density = 0.0 # A global Y-height fog is wrong on a sphere.
	environment.fog_sky_affect = 0.0
	environment.fog_depth_curve = 1.25
	environment.fog_sun_scatter = 0.18
	environment.ssao_radius = 1.4
	environment.ssao_intensity = 0.9
	environment.ssao_power = 1.15
	environment.ssao_light_affect = 0.03
	environment.glow_intensity = 0.16
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.15
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	environment.volumetric_fog_length = 160.0
	environment.volumetric_fog_detail_spread = 1.4
	environment.volumetric_fog_anisotropy = 0.65
	environment.volumetric_fog_sky_affect = 0.0
	environment.volumetric_fog_ambient_inject = 0.25
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_fade_start = 0.8
	sun.shadow_bias = 0.035
	sun.light_angular_distance = 0.6
	add_child(sun)
	var settings := get_node_or_null("/root/DisplaySettings")
	set_quality(settings.atmosphere_quality if settings != null else 1)

func configure(profile: Dictionary, seed_value: int, anchor_up: Vector3, sampler: Callable) -> void:
	_profile = profile.get("atmosphere", {}).duplicate(true)
	_seed = seed_value
	source = sampler
	var weather := get_parent().get_node_or_null("Weather")
	if weather != _weather and weather != null and weather.has_method("snapshot"):
		_weather = weather
		_previous_weather_clouds = weather.clouds_enabled
		weather.clouds_enabled = false # One sky owner; weather retains precipitation.
	var frame: Basis = Cube.frame(anchor_up.normalized())
	# Fixed body-space star; travel changes the solar elevation. No invented clock
	# or day/night persistence contract. The home hemisphere starts in warm daylight.
	_sun_direction = (frame.y * 0.57 + frame.z * 0.74 + frame.x * 0.35).normalized()
	sun.basis = Basis.looking_at(-_sun_direction, frame.y)
	sky_material.set_shader_parameter("sun_direction", _sun_direction)
	sky_material.set_shader_parameter("star_seed", float(posmod(seed_value, 10000)))
	_configured = true
	update_view(0.0, true)

func _exit_tree() -> void:
	if is_instance_valid(_weather):
		_weather.clouds_enabled = _previous_weather_clouds

func set_quality(value: int) -> void:
	quality = clampi(value, 0, 2)
	if environment == null: return
	_forward_plus = RenderingServer.get_current_rendering_method() == "forward_plus"
	environment.ssao_enabled = quality >= 1 and _forward_plus
	environment.glow_enabled = quality >= 1 and _forward_plus
	environment.volumetric_fog_enabled = quality == 2 and _forward_plus
	sun.light_angular_distance = 0.6 if quality >= 1 else 0.0
	sun.directional_shadow_max_distance = 300.0 if quality == 2 else 220.0
	sky_material.set_shader_parameter("cloud_octaves", 5 if quality == 2 else (4 if quality == 1 else 2))

func _process(delta: float) -> void:
	if not _configured: return
	_tick += delta
	if _tick < 0.1: return
	var step: float = _tick
	_tick = 0.0
	update_view(step)

func update_view(delta: float, immediate: bool = false) -> void:
	if not source.is_valid(): return
	var sample: Dictionary = source.call()
	if sample.is_empty(): return
	var up: Vector3 = sample.get("up", Vector3.UP)
	if not up.is_finite() or up.length_squared() < 0.5: return
	up = up.normalized()
	_elapsed = float(sample.get("seconds", _elapsed))
	var wet: float = clampf(float(sample.get("moisture", 0.5)), 0.0, 1.0)
	var weather: Dictionary = sample.get("weather", {})
	var precipitation: float = clampf(float(weather.get("precipitation", 0.0)), 0.0, 1.0)
	_moisture = wet if immediate else lerpf(_moisture, wet, 1.0-exp(-maxf(delta,0.0)*0.5))
	var altitude: float = float(sample.get("height", 0.0))
	var air: float = exp(-maxf(altitude, 0.0)/6000.0)
	var elevation: float = up.dot(_sun_direction)
	var daylight: float = smoothstep(-0.16, 0.12, elevation)
	var sunset: float = (1.0-smoothstep(0.05,0.55,absf(elevation))) * daylight
	var top: Color = _profile.get("sky_top", Color("418ac1"))
	top = top.lerp(Color("287bc0"), 0.35)
	var horizon: Color = _profile.get("sky_horizon", Color("b4d6e6"))
	horizon = horizon.lerp(Color("c6deed"), 0.45)
	var warm: Color = _profile.get("sun_color", Color("fff0da"))
	warm = warm.lerp(Color("ffb76d"), sunset * 0.65)
	sky_material.set_shader_parameter("radial_up", up)
	sky_material.set_shader_parameter("zenith_color", top.lerp(Color("050c20"),1.0-air))
	sky_material.set_shader_parameter("horizon_color", horizon.lerp(Color("1c2942"),1.0-air))
	sky_material.set_shader_parameter("sunlight_color", warm)
	sky_material.set_shader_parameter("daylight", daylight)
	sky_material.set_shader_parameter("sunset", sunset)
	var cloud_cover: float = clampf(float(weather.get("cloud_cover", clampf(float(_profile.get("cloud_density",0.5))*0.75+_moisture*0.22,0.15,0.78))),0.0,1.0)
	sky_material.set_shader_parameter("cloud_cover", cloud_cover*air)
	# Smooth bounded loop; explicit campaign time freezes with pause/loading.
	var phase: float = fposmod(_elapsed, 7200.0) / 7200.0 * TAU
	var seed_phase: float = float(posmod(_seed, 4096)) * 0.013
	sky_material.set_shader_parameter("cloud_offset", Vector3(cos(phase)*1.8+seed_phase, sin(phase)*1.8, seed_phase*0.7))
	sun.light_color = warm
	sun.light_energy = lerpf(0.0, 1.3 if _forward_plus else 0.85, smoothstep(-0.035,0.3,elevation)) * float(_profile.get("sun_energy_scale",1.0))
	sun.light_energy *= lerpf(1.0, 0.6, smoothstep(0.4, 1.0, cloud_cover))
	environment.ambient_light_color = Color("6582b0").lerp(horizon,daylight)
	environment.ambient_light_energy = lerpf(0.12,0.34,daylight) * float(_profile.get("ambient_scale",1.0))
	environment.fog_light_color = Color("17253d").lerp(horizon,daylight)
	environment.fog_light_energy = lerpf(0.4,0.9,daylight)
	environment.fog_density = lerpf(0.14,0.30,_moisture) * float(_profile.get("fog_density_scale",1.0)) * air
	environment.fog_depth_begin = lerpf(220.0,90.0,_moisture)
	environment.fog_depth_end = lerpf(6200.0,3400.0,_moisture)
	if not weather.is_empty():
		environment.fog_depth_end = minf(environment.fog_depth_end, maxf(float(weather.get("visibility_m",18000.0)),500.0))
		environment.fog_depth_end *= lerpf(1.0,0.65,precipitation)
		environment.fog_density *= lerpf(1.0,1.3,precipitation)
	environment.volumetric_fog_density = lerpf(0.00012,0.0007,_moisture)*air
	environment.volumetric_fog_albedo = horizon

func campaign_sample() -> Dictionary:
	var campaign := get_parent()
	if not is_instance_valid(campaign.player) or campaign.terrain == null: return {}
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null: return {}
	var location: Array = Cube.global_position(camera.global_position, campaign.terrain.origin)
	var up: Vector3 = Cube.vector(Cube.normalized(location))
	var address: Dictionary = Cube.from_cartesian(str(campaign.terrain.surface.body.id),location,campaign.terrain.surface.body.radius)
	var surface_sample: Dictionary = campaign.terrain.surface.sample(address)
	return {"up": up, "height": address.height, "moisture": surface_sample.get("moisture",0.5),
		"weather": _weather.snapshot() if is_instance_valid(_weather) else {},
		"seconds": get_node("/root/GameState").campaign.data.elapsed_seconds}
