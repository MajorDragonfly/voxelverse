extends Node
class_name UnderwaterView
const Immersion = preload("res://world/surface/water_immersion.gd")

## Camera-owned water atmosphere. Sampling follows the eye, including an
## elevated lake or a rebased sphere; swimming/body immersion is independent.
var sample_water: Callable
var depth: float = 0.0
var submerged: bool = false
var _camera: Camera3D
var _previous_environment: Environment
var _water_environment: Environment


func _ready() -> void:
	process_priority = 100
	add_to_group(&"underwater_view")


func _process(_delta: float) -> void:
	update_view()


func update_view() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != _camera:
		_restore()
		_camera = camera
	if not is_instance_valid(camera) or not sample_water.is_valid():
		_restore()
		return
	var water: Dictionary = sample_water.call(camera.global_position)
	depth = float(water.get("depth", -1.0))
	# Hysteresis lies below the waterline: an eye above water always sees air.
	var wet: bool = Immersion.submerged(bool(water.get("water", false)), depth, submerged)
	if not wet:
		_restore()
		return
	if not submerged:
		_previous_environment = camera.environment
		var source: Environment = _previous_environment
		if source == null:
			source = camera.get_world_3d().environment
		_water_environment = source.duplicate() if source != null else Environment.new()
		camera.environment = _water_environment
		submerged = true
	var pigment: Color = water.get("color", Color("12546a"))
	var deep: float = 1.0 - exp(-depth / 14.0)
	var haze: Color = pigment.lerp(Color("06303e"), deep * 0.65)
	_water_environment.background_mode = Environment.BG_COLOR
	_water_environment.background_color = haze
	_water_environment.fog_enabled = true
	_water_environment.fog_mode = Environment.FOG_MODE_DEPTH
	_water_environment.fog_density = 1.0
	_water_environment.fog_depth_begin = 0.5
	_water_environment.fog_depth_end = lerpf(34.0, 13.0, deep)
	_water_environment.fog_depth_curve = 0.85
	_water_environment.fog_light_color = haze
	_water_environment.fog_light_energy = lerpf(0.85, 0.42, deep)
	_water_environment.fog_sky_affect = 1.0
	_water_environment.fog_sun_scatter = 0.0
	_water_environment.fog_aerial_perspective = 0.0
	_water_environment.volumetric_fog_enabled = false
	_water_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_water_environment.ambient_light_color = Color("7cafb5")
	_water_environment.ambient_light_energy = lerpf(0.42, 0.16, deep)
	_water_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_water_environment.tonemap_exposure = lerpf(0.85, 0.50, deep)
	_water_environment.glow_enabled = false
	_water_environment.ssao_intensity = 0.35


func _restore() -> void:
	if is_instance_valid(_camera) and _water_environment != null and _camera.environment == _water_environment:
		_camera.environment = _previous_environment
	submerged = false
	_previous_environment = null
	_water_environment = null


func _exit_tree() -> void:
	_restore()
