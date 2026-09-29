extends Node3D
## One reusable voxel tool per nearby resident. The controller only pulses it
## after VillageWork actually advances work or construction progress.
const VISIBLE_SECONDS := 0.38
var _remaining: float = 0.0
var _clock: float = 0.0
var _kind: String = ""
var _head: MeshInstance3D

func _ready() -> void:
	name = "TribeWorkTool"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	position = Vector3(0.55, 1.25, -0.32)
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.09, 0.58, 0.09)
	handle.mesh = handle_mesh
	handle.material_override = _material(Color("8f6842"))
	add_child(handle)
	_head = MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.38, 0.12, 0.13)
	_head.mesh = head_mesh
	_head.position.y = 0.24
	add_child(_head)
	hide()
	set_process(false)

func pulse(kind: String) -> void:
	if kind != _kind:
		_kind = kind
		var color := Color("b5c0be") if kind in ["stone", "quarry", "tool"] else Color("b6a16a") if kind in ["garden", "food", "fiber", "fiberbed"] else Color("9f7652")
		_head.material_override = _material(color)
	_remaining = VISIBLE_SECONDS
	show()
	set_process(true)

func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		_remaining = 0.0
		rotation.z = 0.0
		hide()
		set_process(false)
		return
	_clock += delta
	rotation.z = sin(_clock * 9.0) * 0.32

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material
