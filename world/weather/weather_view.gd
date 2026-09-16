extends Node3D
## Bounded, shader-free fallback: two MultiMeshes, no per-drop Nodes or collisions.
## Rendering owners can replace clouds via clouds_enabled and consume the snapshot.
const Cube = preload("res://world/space/cube_sphere.gd")
const RAIN_COUNT: int = 384
const CLOUD_COUNT: int = 96
const PATCH_RADIUS: float = 12.0
const GRID_SIDE: int = 5
const GRID_STEP: float = PATCH_RADIUS * 2.0 / float(GRID_SIDE - 1)
var clouds_enabled: bool = true
var precipitation_enabled: bool = true
var _rain: MultiMeshInstance3D
var _clouds: MultiMeshInstance3D
var _cloud_material: StandardMaterial3D
var _drops: Array[Vector3] = []
var _puffs: Array[Vector3] = []
var _floors: PackedFloat32Array = []
var _seed: int = -1
var _probe_position: Vector3 = Vector3.INF
var _probe_up: Vector3 = Vector3.UP
var _particle_transforms: Array[Transform3D] = []
var _particle_colors: PackedColorArray = []

func _ready() -> void:
	top_level = true
	var rain_material := StandardMaterial3D.new()
	rain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_material.albedo_color = Color.WHITE
	rain_material.vertex_color_use_as_albedo = true
	rain_material.disable_fog = false
	_rain = _batch(RAIN_COUNT, rain_material, AABB(Vector3(-18, -24, -18), Vector3(36, 50, 36)))
	_particle_transforms.resize(RAIN_COUNT)
	_particle_colors.resize(RAIN_COUNT)
	_cloud_material = StandardMaterial3D.new()
	_cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cloud_material.albedo_color = Color("e1e7ec")
	_clouds = _batch(CLOUD_COUNT, _cloud_material, AABB(Vector3(-850, 160, -850), Vector3(1700, 400, 1700)))
	hide_weather()

func _batch(count: int, material: Material, bounds: AABB) -> MultiMeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = material
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_colors = true
	mesh.mesh = box
	mesh.instance_count = count
	for i in range(count): mesh.set_instance_color(i, Color.WHITE)
	mesh.visible_instance_count = 0
	mesh.custom_aabb = bounds
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance

func configure(seed_value: int) -> void:
	if _seed == seed_value: return
	_seed = seed_value
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	_drops.clear()
	_puffs.clear()
	_floors.resize(GRID_SIDE * GRID_SIDE)
	invalidate_cover()
	for i in range(RAIN_COUNT):
		_drops.append(Vector3(random.randf_range(-PATCH_RADIUS, PATCH_RADIUS), random.randf(), random.randf_range(-PATCH_RADIUS, PATCH_RADIUS)))
	for i in range(CLOUD_COUNT / 4):
		var center := Vector3(random.randf_range(-720, 720), random.randf_range(230, 330), random.randf_range(-720, 720))
		for j in range(4):
			_puffs.append(center + Vector3(random.randf_range(-45, 45), random.randf_range(-12, 12), random.randf_range(-32, 32)))

func position_at(point: Vector3, up: Vector3) -> void:
	global_transform = Transform3D(Cube.frame(up), point)
	if point.distance_squared_to(_probe_position) > 9.0 or up.dot(_probe_up) < 0.9999:
		invalidate_cover()

func invalidate_cover() -> void:
	_floors.fill(INF) # Do not rain through unknown or stale terrain/roofs.

## Exact bounded draw submission, also inspectable with the headless renderer.
## MultiMesh readback is not available on Godot's dummy rendering backend.
func particle_submission(index: int) -> Dictionary:
	if index < 0 or index >= _rain.multimesh.visible_instance_count: return {}
	return {"transform": _particle_transforms[index], "color": _particle_colors[index]}

func _submit_particle(index: int, transform: Transform3D, color: Color) -> void:
	_particle_transforms[index] = transform
	_particle_colors[index] = color
	_rain.multimesh.set_instance_transform(index, transform)
	_rain.multimesh.set_instance_color(index, color)

## Runs only in physics, at 2 Hz. One roof/ground ray per 6 m cell.
## Camera following/rebases use current local coordinates, never absolute floats.
func probe_cover(excluded: Array[RID]) -> void:
	_probe_position = global_position
	_probe_up = global_basis.y
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for z in range(GRID_SIDE):
		for x in range(GRID_SIDE):
			var local := Vector3(float(x) * GRID_STEP - PATCH_RADIUS, 0.0, float(z) * GRID_STEP - PATCH_RADIUS)
			var query := PhysicsRayQueryParameters3D.create(to_global(local + Vector3.UP * 22.0), to_global(local - Vector3.UP * 22.0), 1 | 2 | 4)
			query.exclude = excluded
			var hit: Dictionary = space.intersect_ray(query)
			_floors[z * GRID_SIDE + x] = to_local(hit.position).y + 0.15 if not hit.is_empty() else INF

func present(snapshot: Dictionary, underwater: bool, covered: bool) -> void:
	if _seed < 0 or snapshot.is_empty(): hide_weather(); return
	var clock: float = float(snapshot.elapsed_seconds)
	var wind: float = float(snapshot.wind_mps)
	var direction := Vector3(cos(float(snapshot.wind_bearing)), 0.0, sin(float(snapshot.wind_bearing)))
	var drift: Vector3 = direction * clock * wind
	if snapshot.has("wind_offset"): drift = Cube.vector(snapshot.wind_offset)
	var snow_fraction: float = float(snapshot.get("snow_fraction", 0.0))
	var storm: bool = snapshot.get("storm_preview_schema") == 1 and bool(snapshot.get("preview", false))
	var intensity: float = float(snapshot.get("storm_particle_intensity", 0.0)) if storm else float(snapshot.precipitation)
	var count: int = clampi(int(round(intensity * RAIN_COUNT)), 0, RAIN_COUNT)
	_rain.visible = precipitation_enabled and not underwater and not covered and count > 0
	_rain.multimesh.visible_instance_count = count if _rain.visible else 0
	if _rain.visible:
		var velocity: Vector3 = direction * wind - Vector3.UP * 17.0
		var streak: Basis = Cube.frame(-velocity.normalized()).scaled(Vector3(0.018, 0.48, 0.018))
		for i in range(count):
			var drop: Vector3 = _drops[i]
			var snow: bool = not storm and drop.y < snow_fraction
			var flutter := Vector3(sin(clock * 1.3 + i) * 0.4, 0.0, cos(clock + i) * 0.3) if snow or storm else Vector3.ZERO
			var point := Vector3(wrapf(drop.x + drift.x + flutter.x, -PATCH_RADIUS, PATCH_RADIUS),
				wrapf(drop.y * 40.0 - clock * (0.45 if storm else (1.6 if snow else 17.0)), -20.0, 20.0),
				wrapf(drop.z + drift.z + flutter.z, -PATCH_RADIUS, PATCH_RADIUS))
			var gx: int = clampi(int(round((point.x + PATCH_RADIUS) / GRID_STEP)), 0, GRID_SIDE - 1)
			var gz: int = clampi(int(round((point.z + PATCH_RADIUS) / GRID_STEP)), 0, GRID_SIDE - 1)
			var hidden: bool = point.y < _floors[gz * GRID_SIDE + gx] or point.length_squared() < 1.0
			var shape: Basis = Basis.IDENTITY.scaled(Vector3(0.075, 0.045, 0.075)) if snow else streak
			if storm: shape = Basis.IDENTITY.scaled(Vector3(0.055, 0.04, 0.055) * (0.8 + drop.y * 0.7))
			_submit_particle(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO) if hidden else shape, point),
				snapshot.storm_particle_color if storm else (Color("e8f0f2") if snow else Color("9bbac7")))
	_clouds.visible = clouds_enabled and not underwater and bool(snapshot.get("atmosphere_present", true))
	_clouds.multimesh.visible_instance_count = CLOUD_COUNT if _clouds.visible else 0
	if _clouds.visible:
		var cover: float = float(snapshot.cloud_cover)
		_cloud_material.albedo_color = Color("edf0f2").lerp(Color("8997a3"), cover * 0.78)
		var scale_factor: float = lerpf(0.32, 1.8, cover)
		for i in range(CLOUD_COUNT):
			var point: Vector3 = _puffs[i]
			point.x = wrapf(point.x + drift.x * 0.6, -720.0, 720.0)
			point.z = wrapf(point.z + drift.z * 0.6, -720.0, 720.0)
			_clouds.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(92, 22, 65) * scale_factor), point))

func hide_weather() -> void:
	if is_instance_valid(_rain):
		_rain.visible = false
		_rain.multimesh.visible_instance_count = 0
	if is_instance_valid(_clouds):
		_clouds.visible = false
		_clouds.multimesh.visible_instance_count = 0
