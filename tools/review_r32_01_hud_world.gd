extends "res://tests/r32_14_hud_world_test.gd"
## Same delivered GUI/world assertions, with the declared startup viewport.
## Native layout/input frames paint the real canvas without redundant 3D draws.
## Every recorded picture restores the complete world render. Physics, input,
## clock, quality, original assertions and the outer deadline stay unchanged.
var _native_canvas_frames: bool = false
var _matrix_canvas_frames: bool = false

func _run() -> void:
	preload("res://tools/r32_shared_fixture.gd").window(self, Vector2i(1280, 720))
	_native_canvas_frames = DisplayServer.get_name() != "headless"
	await super._run()

func _matrix(phase: String) -> void:
	_matrix_canvas_frames = _native_canvas_frames
	await super._matrix(phase)
	_matrix_canvas_frames = false
	root.disable_3d = false

func _frames(count: int) -> void:
	if _matrix_canvas_frames: root.disable_3d = true
	await super._frames(count)

func _paint_layout() -> void:
	if _matrix_canvas_frames: root.disable_3d = true
	await super._paint_layout()

func _picture(name: String) -> void:
	if _native_canvas_frames: root.disable_3d = false
	await super._picture(name)
	if _matrix_canvas_frames: root.disable_3d = true

func _done() -> void:
	root.disable_3d = false
	await super._done()
