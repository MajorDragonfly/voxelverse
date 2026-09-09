extends RefCounted

const Layout = preload("res://world/planet_lab/planet_tile_layout.gd")
const Batch = preload("res://world/planet_lab/planet_mesh_batch.gd")
const MAX_WORKERS: int = 4
var body: Dictionary
var direction: Vector3
var previous_masks: Dictionary = {}
var available: Dictionary = {}
var result: Dictionary = {}
var duration_usec: int = 0
var selection_usec: int = 0
var mesh_usec: int = 0
var worker_count: int = 0
var _started: int
var _meshing_started: int
var _selection_task: int = -1
var _tasks: Array[int] = []
var _batches: Array[RefCounted] = []


static func variant_key(tile: Dictionary) -> String:
	return "%s:%d" % [tile.id, tile.mask]


func start() -> void:
	_started = Time.get_ticks_usec()
	_selection_task = WorkerThreadPool.add_task(_select, false, "Planet tile selection")


func _select() -> void:
	result = Layout.new(body.radius).choose(direction, previous_masks)
	selection_usec = Time.get_ticks_usec() - _started


func advance(blocking: bool = false) -> bool:
	if _selection_task >= 0:
		if not blocking and not WorkerThreadPool.is_task_completed(_selection_task):
			return false
		WorkerThreadPool.wait_for_task_completion(_selection_task)
		_selection_task = -1
		_meshing_started = Time.get_ticks_usec()
		var missing: Array[Dictionary] = []
		for tile: Dictionary in result.values():
			if not available.has(variant_key(tile)):
				missing.append(tile)
		worker_count = mini(missing.size(), clampi(OS.get_processor_count() - 1, 1, MAX_WORKERS))
		for index in range(worker_count):
			var batch := Batch.new()
			batch.body = body.duplicate(true)
			batch.prepare()
			for tile_index in range(index, missing.size(), worker_count):
				batch.tiles.append(missing[tile_index])
			_batches.append(batch)
			_tasks.append(WorkerThreadPool.add_task(batch.run, false, "Planet mesh batch"))
	for task: int in _tasks:
		if not blocking and not WorkerThreadPool.is_task_completed(task):
			return false
	for task: int in _tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_tasks.clear()
	_batches.clear()
	mesh_usec = Time.get_ticks_usec() - _meshing_started
	duration_usec = Time.get_ticks_usec() - _started
	return true


func join() -> void:
	# Cancellation joins existing work without starting unused mesh batches.
	if _selection_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_selection_task)
		_selection_task = -1
	for task: int in _tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_tasks.clear()
	_batches.clear()
