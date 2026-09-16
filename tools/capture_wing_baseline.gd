extends SceneTree
## Capture visually accepted revision-1 wings; never run implicitly in validation.
## Output is explicit; this tool never rewrites a fixture as part of validation.
const Parts = preload("res://creatures/editor/creature_part_library.gd")
const Geometry = preload("res://creatures/editor/creature_part_geometry.gd")
const Snapshot = preload("res://tests/creature_foot_snapshot.gd")
const WingTest = preload("res://tests/creature_wing_family_test.gd")
const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")


func _initialize() -> void:
	var result: Dictionary = {}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ids: Array = WingTest.IDS
	if args.size() > 1: ids = Array(args.slice(1))
	for id: String in ids:
		for shape: Vector3 in WingTest.SHAPES:
			for side: float in [-1.0, 1.0]:
				var node := Node3D.new()
				node.set_meta("creature_part_side", side)
				Geometry.build(node, Parts.get_part(id), {"category": "wings", "shape_scale": shape}, Blueprint.create_default())
				result["%s:%s:%d" % [id, shape, int(side)]] = WingTest.fingerprint(node)
				node.free()
	var file := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	file.close()
	print("WING_BASELINE_CAPTURED: ", result.size())
	quit()
