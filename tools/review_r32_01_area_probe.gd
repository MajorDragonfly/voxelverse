extends "res://tools/review_r32_21_area_world.gd"
## Same delivered controls, drag, ledger and restart assertions.
func _run() -> void:
	preload("res://tools/r32_shared_fixture.gd").window(get_tree(), Vector2i(1280, 720))
	await super._run()
