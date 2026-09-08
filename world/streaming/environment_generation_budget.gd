extends RefCounted

# Shared by all streamed chunks: overlapping coroutines cannot each consume
# an independent frame budget. The check follows every bounded placement step.
const BUDGET_USEC: int = 1800
static var _frame: int = -1
static var _used_usec: int = 0
static var max_step_usec: int = 0
static var max_placement_usec: int = 0
static var max_batch_usec: int = 0
static var max_resource_usec: int = 0
static var max_cluster_step_usec: int = 0
static var max_cluster_upload_usec: int = 0
static var _mesh_upload_frame: int = -1


static func claim_mesh_upload() -> bool:
	var frame: int = Engine.get_process_frames()
	if _mesh_upload_frame == frame:
		return false
	exhausted() # Start this frame's accounting even if terrain uploads first.
	_mesh_upload_frame = frame
	return true


static func exhausted() -> bool:
	var frame: int = Engine.get_process_frames()
	if frame != _frame:
		_frame = frame
		_used_usec = 0
	return _used_usec >= BUDGET_USEC


static func record(started: int, phase: String = "placement") -> void:
	var elapsed: int = Time.get_ticks_usec() - started
	_used_usec += elapsed
	max_step_usec = maxi(max_step_usec, elapsed)
	if phase == "batch":
		max_batch_usec = maxi(max_batch_usec, elapsed)
	elif phase == "resource":
		max_resource_usec = maxi(max_resource_usec, elapsed)
	elif phase == "cluster":
		max_cluster_step_usec = maxi(max_cluster_step_usec, elapsed)
	elif phase == "cluster_upload":
		max_cluster_upload_usec = maxi(max_cluster_upload_usec, elapsed)
	elif phase == "terrain":
		pass # Account for the budget; terrain keeps its own upload measurement.
	else:
		max_placement_usec = maxi(max_placement_usec, elapsed)
