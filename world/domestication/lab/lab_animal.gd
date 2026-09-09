extends CharacterBody3D
## Small plane-only movement adapter; does not inherit phase-0 wildlife AI.
const State = preload("res://world/domestication/animal_state.gd")
var host: Node3D
var object_id: String
var status: String = "Wartet"
var model: Node3D
var label: Label3D
var legs: Array[MeshInstance3D] = []
var stride: float = 0.0
var fleeing: float = 0.0

func setup(scene: Node3D, id: String) -> void:
	host = scene
	object_id = id
	position = State.vector(host.controller.record(id)["position"])
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.5
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 1.2, 1.5)
	shape.shape = box
	shape.position.y = 0.6
	add_child(shape)
	model = Node3D.new()
	add_child(model)
	var fur := Color("d5a776")
	host.box_mesh(model, Vector3(1.0, 0.7, 1.55), Vector3(0, 0.95, 0), fur)
	host.box_mesh(model, Vector3(0.72, 0.66, 0.65), Vector3(0, 1.28, -0.94), fur.lightened(0.12))
	host.box_mesh(model, Vector3(0.45, 0.3, 0.45), Vector3(0, 1.12, -1.3), Color("765843"))
	for side in [-1.0, 1.0]:
		host.box_mesh(model, Vector3(0.19, 0.5, 0.25), Vector3(side * 0.25, 1.77, -0.8), fur.darkened(0.15))
		host.box_mesh(model, Vector3(0.08, 0.12, 0.14), Vector3(side * 0.38, 1.4, -1.05), Color("1e2833"))
		for z in [-0.5, 0.5]:
			legs.append(host.box_mesh(model, Vector3(0.28, 0.65, 0.32), Vector3(side * 0.33, 0.33, z), fur.darkened(0.18)))
	host.box_mesh(model, Vector3(0.23, 0.25, 0.85), Vector3(0, 1.05, 1.08), fur)
	label = Label3D.new()
	label.position.y = 2.5
	label.font_size = 36
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(host) or host.snapshot.is_empty(): return
	var a: Dictionary = host.controller.record(object_id)
	if a.is_empty(): return
	if a["status"] == "dead":
		status = "Verstorben"
		model.rotation.z = PI * 0.5
		label.text = status
		velocity = Vector3.ZERO
		return
	var target: Vector3 = global_position
	status = "Wildtier" if a["status"] == "wild" else "Zähmung begonnen" if a["status"] == "taming" else "Wartet"
	fleeing = maxf(0.0, fleeing - delta)
	if fleeing > 0.0:
		target = global_position + (global_position - host.handler.global_position).normalized() * 2.0
		status = "Flieht"
	elif not a["pending"].is_empty():
		status = "Nimmt Futter an"
	elif host.snapshot["phase"] >= 1 and a["status"] == "tamed":
		match a["order"]:
			"follow":
				if a["handler_id"] == host.fixture.ACTOR:
					target = host.handler.global_position
					status = "Folgt / bei dir"
				else: status = "Betreuer nicht verfügbar"
			"home":
				target = State.vector(a["home"])
				status = "Heimkehr / am Heimatplatz"
			"wait": target = State.vector(a["wait_position"])
	var direction: Vector3 = Vector3.ZERO
	var distance: float = Vector2(target.x - global_position.x, target.z - global_position.z).length()
	var tolerance: float = 1.6 if a["order"] == "follow" else 0.4
	if distance > tolerance:
		direction = host.route_direction(global_position, target)
		if direction == Vector3.ZERO: status = "Weg blockiert"
	velocity.x = direction.x * 3.4
	velocity.z = direction.z * 3.4
	velocity.y = -0.5 if is_on_floor() else maxf(-15.0, velocity.y - 24.0 * delta)
	move_and_slide()
	if direction.length_squared() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 8.0))
	stride += delta * direction.length() * 9.0
	for i in range(legs.size()):
		legs[i].rotation.x = sin(stride + float(i % 2) * PI) * 0.3 * direction.length()
	label.text = "%s · %d %%\n%s" % ["Gezähmt" if a["status"] == "tamed" else "Fremdes Tier", roundi(a["trust"]), status]
	host.controller.record_position(object_id, global_position)
