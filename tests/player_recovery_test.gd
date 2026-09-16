extends SceneTree
var failures: Array[String] = []
var player: Node3D
var deaths: int = 0
var returns: int = 0

class Nest extends Node3D:
	func get_respawn_position() -> Vector3: return global_position

class Target extends Node3D:
	var attacks: int = 0
	var current_health: float = 100.0
	var maximum_health: float = 100.0
	var is_dead: bool = false
	func receive_creature_attack(_damage: float, _source: Node) -> void: attacks += 1

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var saves := root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves.session_managed = true
	saves.create_slot("Recovery contracts", 15838, "legacy_plane_v9")
	await process_frame
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var ground := _box(scene, Vector3(0, 29.5, 0), Vector3(60, 1, 60))
	var nest := Nest.new()
	nest.position = Vector3(0, 30.5, 0)
	scene.add_child(nest)
	nest.add_to_group(&"player_nest")
	player = load("res://creatures/player/player.tscn").instantiate()
	scene.add_child(player)
	player.collision_layer = 8
	player.collision_mask = 7
	player.position = Vector3(15, 30.2, 0)
	player.hunger_loss_per_second = 0
	player.thirst_loss_per_second = 0
	player.respawn_delay = 0.12
	player.died.connect(func(): deaths += 1)
	player.respawned.connect(func(): returns += 1)
	await physics_frame
	await process_frame
	var living: Dictionary = player.export_runtime_state()
	player.toggle_inspection_mode()
	player.receive_damage(100000)
	player.receive_damage(100000)
	check(player.is_dead and deaths == 1 and not player.inspection_mode_enabled, "Death not idempotent or scanner remained active")
	var editor_key := InputEventKey.new()
	editor_key.keycode = KEY_F2
	editor_key.pressed = true
	player.get_node("CreatureRuntimeVisual")._unhandled_input(editor_key)
	check(current_scene == scene and not player.can_perform_action(&"bite"), "Dead player opened editor or retained action permission")
	var before: Vector3 = player.position
	paused = true
	var countdown: float = player.recovery.remaining
	await create_timer(0.2).timeout
	check(player.is_dead and returns == 0 and player.recovery.remaining == countdown and player.position == before, "Pause advanced recovery or corpse physics")
	paused = false
	root.get_node("SessionFlow").loading = true
	player.recovery.advance(1.0)
	check(player.recovery.remaining == countdown, "Loading advanced recovery")
	root.get_node("SessionFlow").loading = false
	# Importing a living snapshot cancels the previous attempt completely.
	player.import_runtime_state(living)
	await create_timer(0.2).timeout
	check(not player.is_dead and returns == 0 and player.position.distance_to(before) < 1.0, "Stale return moved a newly loaded player")
	# Persisted zero health restarts recovery, including old saves without flags.
	var dead: Dictionary = living.duplicate(true)
	dead.health_ratio = 0.0
	dead.hunger_ratio = 0.0
	dead.thirst_ratio = 0.0
	var obstruction := _box(scene, Vector3(0, 31, 0), Vector3(2, 2, 2), 2)
	await physics_frame
	player.import_runtime_state(dead)
	await until(func(): return returns == 1)
	check(not player.is_dead and player.position.distance_to(Vector3(0, 30.08, 0)) > 1.0, "Recovery overlapped the obstructed nest")
	check(player.get_health_ratio() == 1.0 and player.get_hunger_ratio() == 1.0 and player.get_thirst_ratio() == 1.0, "Recovery lost needs")
	check(player.recovery.protected() and player.velocity.length() < 1.0, "Recovery lacked protection or retained falling velocity")
	player.receive_damage(100000)
	check(not player.is_dead, "Spawn protection allowed immediate death")
	paused = true
	var protection: float = player.recovery.remaining
	await create_timer(0.1).timeout
	check(player.recovery.remaining == protection, "Pause consumed spawn protection")
	paused = false
	var target := Target.new()
	scene.add_child(target)
	target.position = player.position + Vector3(0, 0, -1)
	check(player.perform_bite_on_target(target) and target.attacks == 1 and not player.recovery.protected(), "Successful attack retained invulnerability")
	target.queue_free()
	obstruction.queue_free()
	await physics_frame
	# Missing floor must never restore a living falling player. Recheck later.
	ground.collision_layer = 0
	player.receive_damage(100000)
	await until(func(): return player.recovery.stage == "blocked")
	check(player.is_dead and returns == 1, "No-floor recovery was treated as success")
	ground.collision_layer = 1
	await until(func(): return returns == 2)
	check(not player.is_dead and player.recovery.protected(), "Restored ground did not unblock recovery")
	player.recovery.advance(6.0)
	check(not player.recovery.protected(), "Protection never expired")
	await _layout_review()
	# Real deletion cancels recovery without a timer writing to a later session.
	player.receive_damage(100000)
	player.queue_free()
	await create_timer(0.2).timeout
	check(returns == 2, "Freed player completed stale recovery")
	scene.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PLAYER_RECOVERY_PASSED: pause/load/cancel, real obstacles, no-floor retry, needs, protection, attack and teardown")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _box(parent: Node3D, at: Vector3, size: Vector3, layer: int = 1) -> StaticBody3D:
	var result := StaticBody3D.new()
	result.collision_layer = layer
	result.position = at
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	result.add_child(shape)
	parent.add_child(result)
	return result

func until(predicate: Callable) -> void:
	var start: int = Time.get_ticks_msec()
	while not predicate.call() and Time.get_ticks_msec() - start < 5000: await process_frame
	check(predicate.call(), "Timed out waiting for recovery stage")

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)


func _layout_review() -> void:
	var view: Node = player.recovery.get_child(0)
	player.set_process(false)
	var old_locale: String = TranslationServer.get_locale()
	var old_size: Vector2i = root.size
	for locale: String in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = size
			for font_scale: float in [1.0, 1.5]:
				root.get_node("DisplaySettings").ui_scale = font_scale
				for stage: String in ["countdown", "preparing", "blocked", "protected"]:
					player.recovery.stage = stage
					player.recovery.remaining = 2.0
					await process_frame
					await process_frame
					view.refresh()
					check(view.visible and not view.heading.text.begins_with("RECOVERY_"), "Untranslated recovery heading")
					check(not view.detail.text.begins_with("RECOVERY_") and not view.detail.text.contains("{seconds}"), "Untranslated recovery detail")
					check(view.panel.get_global_rect().size.x <= root.get_visible_rect().size.x, "Recovery width exceeds viewport")
					check(root.get_visible_rect().encloses(view.panel.get_global_rect()), "Recovery card outside viewport")
					check(view.heading.get_theme_font_size("font_size") == roundi(24 * font_scale), "Recovery ignores text scale")
	root.get_node("GameState").current_phase = 1
	view.refresh()
	check(not view.visible, "Recovery card remained visible after tribal handoff")
	root.get_node("GameState").current_phase = 0
	root.size = old_size
	root.get_node("DisplaySettings").ui_scale = 1.0
	TranslationServer.set_locale(old_locale)
	player.recovery.reset()
	player.set_process(true)
