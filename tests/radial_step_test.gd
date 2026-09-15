extends SceneTree
## Real capsule sweeps over a ledge, with unchanged step height and collision masks.
const Space = preload("res://world/surface/gameplay_space.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
var failures: Array[String] = []
var observations: Array[Dictionary] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	for up in [Vector3.UP,Vector3.DOWN,Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK,Vector3(1,2,3).normalized()]:
		await _case(up,0.5,false,true)
	for up in [Vector3.UP,Vector3(1,2,3).normalized()]:
		await _case(up,0.8,false,false)
		await _case(up,0.5,true,false)
	for message in failures: push_error(message)
	print("RADIAL_STEP_EVIDENCE ",JSON.stringify(observations))
	if failures.is_empty(): print("RADIAL_STEP_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self,0 if failures.is_empty() else 1)
func _box(parent: Node3D,size: Vector3,position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
func _case(up: Vector3,height: float,ceiling: bool,expected: bool) -> void:
	var host := Node3D.new()
	host.basis = Cube.frame(up)
	root.add_child(host)
	_box(host,Vector3(12,1,6),Vector3(0,-0.5,0))
	_box(host,Vector3(3,height,4),Vector3(2.5,height*0.5,0))
	if ceiling: _box(host,Vector3(8,0.2,5),Vector3(0,1.95,0))
	var actor := CharacterBody3D.new()
	actor.collision_layer = 8
	actor.collision_mask = 1
	actor.safe_margin = 0.01
	actor.floor_snap_length = 0.25
	actor.up_direction = up
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.65
	collider.shape = capsule
	collider.position.y = 0.825
	actor.add_child(collider)
	host.add_child(actor)
	actor.position = Vector3(-1,0.03,0)
	for tick in range(3): await physics_frame
	var forward: Vector3 = host.global_basis.x
	var reached: bool = false
	var returned: bool = false
	var horizontal_correction: float = 0.0
	var highest: float = 0.0
	for tick in range(210):
		var sign_value: float = -1.0 if reached else 1.0
		var velocity: Vector3 = forward*4.0*sign_value - up*2.0
		var before: Vector3 = actor.global_position
		Space.step(actor,forward*(4.0/60.0)*sign_value,0.58)
		horizontal_correction = maxf(horizontal_correction,(actor.global_position-before).slide(up).length())
		actor.velocity = velocity
		actor.move_and_slide()
		var point: Vector3 = host.to_local(actor.global_position)
		highest = maxf(highest,point.y)
		if point.x > 2.3: reached = true
		if reached and point.x < -0.8: returned = true; break
		await physics_frame
	var passed: bool = reached and returned if expected else not reached
	if not passed: failures.append("Step case failed: " + str(up) + " height=" + str(height) + " ceiling=" + str(ceiling))
	if horizontal_correction > 0.00001: failures.append("Step introduced horizontal teleport.")
	observations.append({"up":[up.x,up.y,up.z],"height":height,"ceiling":ceiling,"expected_walkable":expected,
		"reached":reached,"returned":returned,"passed":passed,"max_height":highest,"horizontal_correction":horizontal_correction})
	host.free()
	await physics_frame
