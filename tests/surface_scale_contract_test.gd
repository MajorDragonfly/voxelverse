extends SceneTree
const Context = preload("res://core/campaign/surface_context.gd")
const Layout = preload("res://world/planet_lab/planet_tile_layout.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	for radius in [50000.0, Context.DEFAULT_RADIUS, Context.MAX_WALKABLE_RADIUS]:
		var layout := Layout.new(radius)
		for uv in [Vector2.ZERO, Vector2(1, 0.3), Vector2(1, 1)]:
			var d: Vector3 = Cube.vector(Cube.direction(0, uv.x, uv.y))
			var leaves: Dictionary = layout.choose(d)
			var focus: Dictionary = layout.find_at(0, uv.x, uv.y, leaves)
			if focus.is_empty() or focus.width * radius / 16.0 > 4.0: failures.append("Accepted radius cannot reach collision resolution: " + str(radius))
			if leaves.size() > Layout.MAX_LEAVES: failures.append("Radius escaped the terrain budget.")
	var body: Dictionary = Context.create({"id": "scale-test", "seed": 15838})
	if not Context.create({"id": "too-big", "seed": 15838}, 1.0e10).is_empty(): failures.append("Unsupported radius entered unfinishable terrain loading.")
	body.surface_context.radius = 1.0e10
	if not Context.unsupported(body) or Context.validate(body).is_empty(): failures.append("Unwalkable saved body was silently changed or allowed.")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("SURFACE_SCALE_PASSED: small, Earth and upper bound reach collision detail; oversized saves remain protected.")
	quit(0 if failures.is_empty() else 1)
