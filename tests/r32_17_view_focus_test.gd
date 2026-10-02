extends SceneTree
## Run on the unmodified base (negative) and isolated owner-patch overlay.
class TerrainSpy extends Node:
	var views: int = 0
	var hints: int = 0
	var streams: int = 0
	func set_view_focus(_value: Vector3) -> void: views += 1
	func set_motion_hint(_up: Vector3, _velocity: Vector3) -> void: hints += 1
	func stream_at(_up: Vector3) -> void: streams += 1
class SurfaceSpy extends RefCounted:
	var terrain: Node
class Owner extends Node3D:
	var camera: Camera3D
	var _focus := Vector3.ZERO
	var _zoom: float = 26.0
	signal guidance_action(action: String, value: float)
	func is_active() -> bool: return true
	func anchor() -> Vector3: return Vector3.ZERO
class Rig extends "res://world/tribe/tribe_camera.gd":
	func update_camera() -> void: pass

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var owner := Owner.new()
	root.add_child(owner)
	owner.camera = Camera3D.new()
	owner.add_child(owner.camera)
	var observer := Camera3D.new()
	root.add_child(observer)
	var terrain := TerrainSpy.new()
	root.add_child(terrain)
	var surface := SurfaceSpy.new()
	surface.terrain = terrain
	var rig := Rig.new()
	rig.setup(owner)
	rig.surface = surface
	owner.camera.make_current()
	rig.advance(0.016)
	var current_ok: bool = terrain.views == 1 and terrain.hints == 1 and terrain.streams == 1
	observer.make_current()
	rig.advance(0.016)
	var inactive_ok: bool = terrain.views == 1 and terrain.hints == 2 and terrain.streams == 2
	print(JSON.stringify({"test": "r32_17_view_focus", "checks": 2, "current_camera_keeps_visual_and_physical_focus": current_ok,
		"inactive_camera_keeps_physical_without_overwriting_observer": inactive_ok, "passed": current_ok and inactive_ok,
		"scope": "real camera advance and viewport selection; owner-overlay contract, no render/FPS acceptance"}))
	rig.close()
	for node in [owner, observer, terrain]: node.queue_free()
	await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if current_ok and inactive_ok else 1)
