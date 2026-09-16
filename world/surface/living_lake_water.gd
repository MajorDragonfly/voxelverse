extends RefCounted
## Settled freshwater on the existing, immutable v2 terrain. Flood from the
## source to find the lowest escape saddle, then retain only its connected
## basin. The bounded grid belongs to a lake, never to a render/streaming tile.
const Cube = preload("res://world/space/cube_sphere.gd")
const CELL: float = 2.0
const HALF: int = 14
const SIDE: int = HALF * 2 + 1
const REACH: float = HALF * CELL * 1.414214 + 1.0
const FREEBOARD: float = 0.35 # Includes the half-metre voxel rounding margin.
var direction: Array
var frame: Basis
var radius: float
var levels := PackedFloat64Array()
var stage: float
var spill: float
var _heap: Array[Vector2] = []


func _init(surface: RefCounted, lake: Dictionary) -> void:
	direction = lake.direction
	frame = Cube.frame(Cube.vector(direction))
	radius = surface.body.radius
	var ground := PackedFloat64Array()
	ground.resize(SIDE * SIDE)
	var costs := PackedFloat64Array()
	costs.resize(ground.size())
	costs.fill(INF)
	for y in range(SIDE):
		for x in range(SIDE):
			ground[y * SIDE + x] = surface.height_precise(_direction_at(Vector2(x - HALF, y - HALF) * CELL))
	var source: int = HALF * SIDE + HALF
	costs[source] = ground[source]
	_push(source, costs[source])
	spill = INF
	while not _heap.is_empty():
		var item: Vector2 = _pop()
		var index: int = int(item.x)
		# Heap priorities are floats; use the authoritative double cost below.
		if item.y > costs[index] + 0.00001: continue
		var x: int = index % SIDE
		var y: int = index / SIDE
		if x == 0 or y == 0 or x == SIDE - 1 or y == SIDE - 1:
			spill = minf(spill, costs[index])
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nx: int = x + step.x
			var ny: int = y + step.y
			if nx < 0 or ny < 0 or nx >= SIDE or ny >= SIDE: continue
			var next: int = ny * SIDE + nx
			var cost: float = maxf(costs[index], ground[next])
			if cost >= costs[next]: continue
			costs[next] = cost
			_push(next, cost)
	stage = maxf(0.0, minf(float(lake.level), spill - FREEBOARD))
	levels.resize(ground.size())
	for y in range(SIDE):
		for x in range(SIDE):
			var index: int = y * SIDE + x
			# Disconnected downhill ground must not become a second suspended
			# lake. Bury the inactive surface before blending to the global sea.
			var level: float = stage if costs[index] <= stage else minf(stage, ground[index] - FREEBOARD)
			var rim: float = maxf(absf(x - HALF), absf(y - HALF)) * CELL
			levels[index] = lerpf(maxf(0.0, level), 0.0, smoothstep((HALF - 2) * CELL, HALF * CELL, rim))


func level_at(d: Array) -> float:
	var relative := Vector3((d[0] - direction[0]) * radius, (d[1] - direction[1]) * radius, (d[2] - direction[2]) * radius)
	var grid := Vector2(relative.dot(frame.x), relative.dot(frame.z)) / CELL + Vector2.ONE * HALF
	if grid.x <= 0.0 or grid.y <= 0.0 or grid.x >= SIDE - 1 or grid.y >= SIDE - 1: return 0.0
	var x: int = floori(grid.x)
	var y: int = floori(grid.y)
	var a: int = y * SIDE + x
	return lerpf(lerpf(levels[a], levels[a + 1], grid.x - x),
		lerpf(levels[a + SIDE], levels[a + SIDE + 1], grid.x - x), grid.y - y)


func _direction_at(offset: Vector2) -> Array:
	var delta: Vector3 = (frame.x * offset.x + frame.z * offset.y) / radius
	return Cube.normalized([direction[0] + delta.x, direction[1] + delta.y, direction[2] + delta.z])


func _push(index: int, cost: float) -> void:
	var item := Vector2(index, cost)
	var child: int = _heap.size()
	_heap.append(item)
	while child > 0:
		var parent: int = (child - 1) / 2
		if _heap[parent].y <= item.y: break
		_heap[child] = _heap[parent]
		child = parent
	_heap[child] = item


func _pop() -> Vector2:
	var first: Vector2 = _heap[0]
	var last: Vector2 = _heap.pop_back()
	if _heap.is_empty(): return first
	var parent: int = 0
	while parent * 2 + 1 < _heap.size():
		var child: int = parent * 2 + 1
		if child + 1 < _heap.size() and _heap[child + 1].y < _heap[child].y: child += 1
		if last.y <= _heap[child].y: break
		_heap[parent] = _heap[child]
		parent = child
	_heap[parent] = last
	return first
