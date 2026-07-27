extends Node

# V7 controls actual terrain meshes instead of only decorative layers.
# Near and Mid use the collision-matching voxel mesh; Far switches to the
# worker-built low-resolution proxy.

@export_range(16.0, 96.0, 1.0) var near_distance: float = 42.0
@export_range(32.0, 192.0, 1.0) var mid_distance: float = 78.0
@export_range(0.1, 2.0, 0.1) var update_interval: float = 0.35

var _chunk: Node3D
var _player: Node3D
var _timer: float = 0.0
var _current_tier: int = -1


func _ready() -> void:
	_chunk = get_parent() as Node3D
	call_deferred("_bind_and_update")


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = update_interval
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	_update_lod()


func _bind_and_update() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Node3D
	_update_lod()


func _update_lod() -> void:
	if _chunk == null or _player == null:
		return
	var distance: float = _chunk.global_position.distance_to(
		_player.global_position
	)
	var tier: int = 2
	if distance <= near_distance:
		tier = 0
	elif distance <= mid_distance:
		tier = 1
	if tier == _current_tier:
		return
	_current_tier = tier

	if _chunk.has_method("set_lod_tier"):
		_chunk.call("set_lod_tier", tier)
	var ecosystem := _chunk.get_node_or_null("ProceduralEcosystemV6")
	if ecosystem != null and ecosystem.has_method("set_lod_tier"):
		ecosystem.call("set_lod_tier", tier)

	var water := _chunk.get_node_or_null("WaterMesh") as GeometryInstance3D
	if water != null:
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		water.visibility_range_end = mid_distance * 2.75
