extends SceneTree
## Capture on PR #112 (9b502ef) before extracting the revision-1 tail provider.
## Output is explicit; this tool never rewrites a fixture as part of validation.
const Parts = preload("res://creatures/editor/creature_part_library.gd")
const Geometry = preload("res://creatures/editor/creature_part_geometry.gd")
const Snapshot = preload("res://tests/creature_foot_snapshot.gd")
const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")


func _initialize() -> void:
	var result: Dictionary = {}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ids: Array = ["tail_balance", "tail_club", "tail_fin", "tail_stinger"]
	if args.size() > 1: ids = Array(args.slice(1))
	for id: String in ids:
		for shape: Vector3 in [Vector3.ONE, Vector3(0.8, 1.1, 1.4), Vector3(1.7, 0.6, 0.9)]:
			for side: float in [-1.0, 1.0]:
				var node := Node3D.new()
				node.set_meta("creature_part_side", side)
				Geometry.build(node, Parts.get_part(id), {"category": "tail", "shape_scale": shape}, Blueprint.create_default())
				result["%s:%s:%d" % [id, shape, int(side)]] = JSON.stringify(Snapshot.describe(node)).sha256_text()
				node.free()
	var file := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	file.close()
	print("TAIL_BASELINE_CAPTURED: ", result.size())
	quit()
