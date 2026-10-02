extends Node3D
## Physical tangent-plane fixture using the ACTIVE sphere player and real radial
## adapter. This is not generated campaign terrain or a target-PC acceptance.
const Cube = preload("res://world/space/cube_sphere.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const Adapter = preload("res://world/surface/radial_surface_adapter.gd")

class SurfaceFixture extends RefCounted:
	var body: Dictionary = {"id": "r32-03-fixture", "radius": 6371000.0, "seed": 15838, "gravity": 20.0}
	func sample(_address: Dictionary) -> Dictionary:
		return {"height": 30.0, "water_level": 0.0, "water": false}

class TerrainFixture extends Node3D:
	signal origin_changed(previous: Array, current: Array)
	var surface := SurfaceFixture.new()
	var origin: Array = [0.0, 6371030.0, 0.0]
	var rebases: int = 0
	func ground_ready(_point: Array) -> bool: return true
	func stream_at(_up: Vector3, _force: bool = false) -> void: pass
	func set_motion_hint(_up: Vector3, _motion: Vector3) -> void: pass
	func rebase(point: Array) -> void:
		var previous: Array = origin
		origin = point.duplicate()
		rebases += 1
		origin_changed.emit(previous, origin)

class Recorder extends Node:
	var fixture: Node3D
	func _physics_process(delta: float) -> void: fixture.record(delta)
	func _process(delta: float) -> void:
		fixture.render_rows.append({"frame": Engine.get_process_frames(), "wall_us": Time.get_ticks_usec(), "delta_s": delta, "phase": fixture.phase})

var world_initialized: bool = true
var terrain: TerrainFixture
var adapter: RefCounted
var player: CharacterBody3D
var phase: String = "settle"
var rows: Array[Dictionary] = []
var render_rows: Array[Dictionary] = []
var reference_origin: Array = [0.0, 6371030.0, 0.0]
var geometry: Node3D
var diagonal: bool = false
var elapsed: float = 0.0

func setup(size: float = 1.0, angled: bool = false, speed: float = 4.0) -> void:
	diagonal = angled
	terrain = TerrainFixture.new()
	add_child(terrain)
	adapter = Adapter.new(terrain)
	set_meta("campaign_surface", adapter)
	geometry = Node3D.new()
	add_child(geometry)
	_box(Vector3(40, 1, 30), Vector3(2, -0.5, 0), Color("456c50"))
	for step in range(3):
		_box(Vector3(2, 0.5 * (step + 1), 18), Vector3(2 + step * 2, 0.25 * (step + 1), 0), Color("899986") if step % 2 == 0 else Color("718674"))
	_box(Vector3(3, 1.5, 18), Vector3(8.5, 0.75, 0), Color("899986"))
	# Native spring arm obstacle; no changed collision mask or spring settings.
	_box(Vector3(0.3, 6, 20), Vector3(-5.5, 3, 0), Color("53697b"))
	terrain.origin_changed.connect(func(_old: Array, current: Array) -> void:
		geometry.position = Cube.local_position(reference_origin, current))
	# Load after autoloads exist, as the normal campaign entry does.
	player = load("res://creatures/player/player.tscn").instantiate()
	player.set_script(load("res://creatures/player/spherical_campaign_player.gd"))
	player.terrain = terrain
	player.adapter = adapter
	player.initial_placement = true
	player.get_node("CreatureRuntimeVisual").runtime_visual_scale *= size
	player.get_node("CreatureRuntimeVisual").apply_blueprint_stats = false
	add_child(player)
	player.position = Vector3(-1, 0.03, -2 if diagonal else 0)
	player.move_speed = speed
	player.camera_pivot.rotation = Vector3(deg_to_rad(-15), deg_to_rad(-70 if diagonal else -90), 0)
	adapter.bind("r32-03-player", player, player.location(), player.forward)
	player.camera.make_current()
	var recorder := Recorder.new()
	recorder.fixture = self
	recorder.process_physics_priority = 100
	add_child(recorder)

func point(node: Node3D) -> Vector3:
	return Cube.local_position(Cube.global_position(node.global_position, terrain.origin), reference_origin)

func record(delta: float) -> void:
	elapsed += delta
	var floor: Dictionary = Space.floor_hit(player, player.global_position, 0.2, 2.4)
	var feet: Array = []
	var animator: Node = player.get_node("AdaptiveLocomotionAnimator")
	for limb: Dictionary in animator._leg_records:
		var foot: Node3D = limb.get("foot")
		if not is_instance_valid(foot): continue
		var hit: Dictionary = Space.floor_hit(player, foot.global_position, 0.7, 2.0)
		feet.append({"position": _vec(point(foot)), "floor_gap_m": (foot.global_position - hit.position).dot(player.up_direction) if not hit.is_empty() else null,
			"swing": bool(limb.get("swing", false)), "lift": float(limb.get("lift", 0.0))})
	var preview: Node3D = player.preview
	var capsule_gap: Variant = _capsule_support_gap()
	var contacts: Array = []
	for index in range(player.get_slide_collision_count()):
		var collision: KinematicCollision3D = player.get_slide_collision(index)
		contacts.append({"normal": _vec(collision.get_normal()), "point": _vec(Cube.local_position(Cube.global_position(collision.get_position(), terrain.origin), reference_origin))})
	rows.append({"tick": rows.size(), "time_s": elapsed, "wall_us": Time.get_ticks_usec(), "phase": phase,
		"body": _vec(point(player)), "visual": _vec(point(preview)) if is_instance_valid(preview) else [],
		"pivot": _vec(point(player.camera_pivot)), "camera": _vec(point(player.camera)),
		"floor": player.is_on_floor(), "floor_gap_m": (player.global_position - floor.position).dot(player.up_direction) if not floor.is_empty() else null,
		"capsule_support_gap_m": capsule_gap,
		"feet": feet, "offset_m": player._camera_step_offset, "vertical_velocity": player.velocity.dot(player.up_direction),
		"spring_m": player.spring_arm.get_hit_length(), "rebases": terrain.rebases, "contacts": contacts})

func _capsule_support_gap() -> Variant:
	# Sample the actual rounded capsule underside, rather than requiring its
	# centre to be over a tread. Keep the centre ray separately in the trace.
	var collider: CollisionShape3D = player.collision_shape
	var capsule: CapsuleShape3D = collider.shape
	var up: Vector3 = player.up_direction
	var center: Vector3 = collider.global_position - up * (capsule.height * 0.5 - capsule.radius)
	var best: Variant = null
	for fraction in [0.0, 0.25, 0.5, 0.75, 0.9]:
		for axis in [player.global_basis.x, -player.global_basis.x, player.global_basis.z, -player.global_basis.z]:
			var lateral: float = capsule.radius * fraction
			var bottom: Vector3 = center + axis * lateral - up * sqrt(capsule.radius * capsule.radius - lateral * lateral)
			var hit: Dictionary = Space.floor_hit(player, bottom, 0.15, 2.0)
			if hit.is_empty(): continue
			var gap: float = (bottom - hit.position).dot(up)
			if best == null or absf(gap) < absf(float(best)): best = gap
	return best

func put_on_plateau() -> void:
	var direction: Vector3 = (-player.camera_pivot.global_basis.z).slide(Vector3.UP).normalized()
	player.global_position = geometry.position + Vector3(-1, 1.53, -2 if diagonal else 0) + direction * (9.6 / direction.x)
	player.velocity = Vector3.ZERO
	player._reset_step_camera()

func shift_origin() -> void:
	terrain.rebase([terrain.origin[0] + 91, terrain.origin[1] - 23, terrain.origin[2] + 17])

func close() -> void:
	adapter.close()
	queue_free()

func _vec(value: Vector3) -> Array: return [value.x, value.y, value.z]

func _box(size: Vector3, position_value: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = position_value
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	body.add_child(visual)
	geometry.add_child(body)
