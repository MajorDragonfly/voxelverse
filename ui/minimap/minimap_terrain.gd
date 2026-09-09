extends RefCounted
## Incremental 2D raster, no camera or second world render. Work is bounded by
## sample count AND a soft time budget, with a bounded position/zoom cache.
const GRID: int = 48
const CACHE_LIMIT: int = 6144
const MAX_SAMPLES: int = 32
const BUDGET_USEC: int = 1400
const UNKNOWN := Color("172a36")
var image: Image = Image.create(GRID, GRID, false, Image.FORMAT_RGBA8)
var texture: ImageTexture
var center := Vector2.ZERO
var radius: float = 64.0
var cell: float = 128.0 / GRID
var sampling: Callable
var _cache: Dictionary = {}
var _cache_order: Array[Vector3i] = []
var _eviction_cursor: int = 0
var _queue: Array[Vector2i] = []
var _cursor: int = 0
var _key: Vector3i = Vector3i(2147483647, 0, 0)
var samples_total: int = 0
var last_samples: int = 0
var last_usec: int = 0
var completed: bool = false
var revision: int = 0

func _init() -> void:
	image.fill(UNKNOWN)
	texture = ImageTexture.create_from_image(image)

func reset() -> void:
	_cache.clear()
	_cache_order.clear()
	_eviction_cursor = 0
	sampling = Callable()
	_queue.clear()
	_cursor = 0
	completed = false
	_key = Vector3i(2147483647, 0, 0)
	image.fill(UNKNOWN)
	texture.update(image)
	revision += 1

func request(position: Vector2, extent: float, sample: Callable) -> void:
	if not position.is_finite() or not is_finite(extent) or extent <= 0.0: return
	sampling = sample
	var step: float = extent * 2.0 / GRID
	var snapped := Vector2i((position / step).floor())
	var request_key := Vector3i(snapped.x, snapped.y, roundi(extent * 100.0))
	if _key == request_key: return
	_key = request_key
	radius = extent
	cell = step
	center = Vector2(snapped) * cell
	_queue.clear()
	_cursor = 0
	for y in range(GRID):
		for x in range(GRID):
			var pixel := Vector2i(x, y)
			var key: Vector3i = _pixel_key(pixel)
			if _cache.has(key): image.set_pixel(x, y, _cache[key])
			else:
				image.set_pixel(x, y, UNKNOWN)
				_queue.append(pixel)
	_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (Vector2(a) - Vector2.ONE * GRID * 0.5).length_squared() < (Vector2(b) - Vector2.ONE * GRID * 0.5).length_squared())
	completed = _queue.is_empty()
	texture.update(image)
	revision += 1

func step_work() -> void:
	last_samples = 0
	last_usec = 0
	if completed or not sampling.is_valid(): return
	var started: int = Time.get_ticks_usec()
	while _cursor < _queue.size() and last_samples < MAX_SAMPLES:
		var pixel: Vector2i = _queue[_cursor]
		_cursor += 1
		var offset: Vector2 = center + (Vector2(pixel) + Vector2.ONE * 0.5 - Vector2.ONE * GRID * 0.5) * cell
		var value: Variant = sampling.call(offset)
		var color: Color = value if value is Color else UNKNOWN
		if _cache.size() >= CACHE_LIMIT:
			# Fixed-size FIFO ring avoids allocating thousands of keys per sample.
			_cache.erase(_cache_order[_eviction_cursor])
			_cache_order[_eviction_cursor] = _pixel_key(pixel)
			_eviction_cursor = (_eviction_cursor + 1) % CACHE_LIMIT
		else:
			_cache_order.append(_pixel_key(pixel))
		_cache[_pixel_key(pixel)] = color
		image.set_pixelv(pixel, color)
		last_samples += 1
		samples_total += 1
		if Time.get_ticks_usec() - started >= BUDGET_USEC: break
	last_usec = Time.get_ticks_usec() - started
	completed = _cursor >= _queue.size()
	if last_samples > 0:
		texture.update(image)
		revision += 1

func _pixel_key(pixel: Vector2i) -> Vector3i:
	return Vector3i(_key.x + pixel.x - GRID / 2, _key.y + pixel.y - GRID / 2, _key.z)

func coverage() -> float:
	return 1.0 - float(_queue.size() - _cursor) / float(GRID * GRID)
