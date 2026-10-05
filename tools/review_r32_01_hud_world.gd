extends "res://tests/r32_14_hud_world_test.gd"
## Same delivered GUI/world assertions, with the declared startup viewport.

func _run() -> void:
	preload("res://tools/r32_shared_fixture.gd").window(self, Vector2i(1280, 720))
	await super._run()
