extends Node3D
## External payload root: resolves by stable ID each frame, including rebuilds.
## Put a rider/equipment visual below this node; gameplay stays with its owner.
var _preview: Node3D
var socket_id: String = ""
var available: bool = false


func _init() -> void:
	process_priority = 100 # Follow preview animation after its normal process step.


func bind(preview: Node3D, id: String) -> void:
	_preview = preview
	socket_id = id
	sync_pose()


func _process(_delta: float) -> void:
	sync_pose()


func sync_pose() -> void:
	available = false
	if is_inside_tree() and is_instance_valid(_preview) and _preview.is_inside_tree() and _preview.has_method("body_socket"):
		var socket: Dictionary = _preview.call("body_socket", socket_id)
		if socket.has("world_transform"):
			global_transform = socket["world_transform"]
			available = true
	visible = available
