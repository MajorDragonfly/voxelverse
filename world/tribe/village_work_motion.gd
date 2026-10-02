extends Node3D
## One reusable voxel tool per nearby resident. The controller only pulses it
## after VillageWork actually advances work or construction progress.
const VISIBLE_SECONDS := 0.38
const TOOL_OFFSET := Vector3(0.55, 1.25, -0.32)
var _remaining: float = 0.0
var _clock: float = 0.0
var _phase: float = 0.0
var _kind: String = ""
var _head: MeshInstance3D
var _state: Node
var _visual: Node3D

func _ready() -> void:
	name = "TribeWorkTool"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	position = TOOL_OFFSET
	_state = get_node_or_null("/root/GameState")
	_visual = get_parent().get_node_or_null("CreatureRuntimeVisual")
	var identity: Variant = get_parent().get("member_id")
	if identity != null:
		# Adjacent resident IDs must not produce adjacent (visually identical)
		# phases. Mix the stable ID once, outside the per-frame update.
		_phase = float(str(identity).sha256_text().left(8).hex_to_int()) * TAU / 4294967296.0
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
	if _remaining <= 0.0: _clock = 0.0
	if kind != _kind:
		_kind = kind
		var color := Color("b5c0be") if kind in ["stone", "quarry", "tool"] else Color("b6a16a") if kind in ["garden", "food", "fiber", "fiberbed"] else Color("9f7652")
		_head.material_override = _material(color)
	_remaining = VISIBLE_SECONDS
	show()
	set_process(true)

func _process(delta: float) -> void:
	# Tempo pause uses time_scale=0 without pausing the tree. Reuse the same
	# delta as actual village work; this node never advances campaign time.
	delta = _state.simulation_delta(delta) if is_instance_valid(_state) else maxf(delta, 0.0)
	if delta <= 0.0: return
	_remaining -= delta
	if _remaining <= 0.0:
		_remaining = 0.0
		rotation.z = 0.0
		hide()
		set_process(false)
		return
	_clock = fposmod(_clock + delta, TAU / 9.0)
	if is_instance_valid(_visual):
		# Residents turn their visual, not the radial physics root. Keep the
		# existing reusable prop on the same side of that turning body.
		position = _visual.basis * TOOL_OFFSET
		rotation.y = _visual.rotation.y
	rotation.z = sin(_clock * 9.0 + _phase) * 0.32

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material
