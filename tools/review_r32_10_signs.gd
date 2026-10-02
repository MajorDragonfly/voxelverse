extends "res://creatures/behavior/review/int30_creature_review.gd"
## Bounded flat fixture; real production AI and public social/damage entry points.
## This is encounter evidence, not a spherical route or target-PC benchmark.
var marker_us: Array[int] = []
var visible_states: Dictionary = {}
var matrix: Array[Dictionary] = []

func _encounters() -> void:
	var camera := root.get_camera_3d()
	camera.size = 6.5
	player.position = Vector3(0, 100.05, 2)
	var actor := _specimen(0, 501)
	var social: Node = actor.get_node("SocialBehavior")
	title.text = "R32-10 · echte soziale Handlungen / public APIs · flache Fachszene"
	for step in range(3):
		var result: Dictionary = social.befriend(player, 0.1, social.social_status().playful)
		observations.append({"action": "befriend", "step": step, "result": result})
		_expect(bool(result.get("ok", false)), "Real social action rejected")
		var seconds: float = maxf(0.5, float(social.response_remaining) + 0.15)
		await _observe(actor, ceili(seconds * 15.0), "Begegnung %d/3" % (step + 1))
	_expect(social.entry().relation == "ally", "Real three-step encounter did not create an ally")
	var greet: Dictionary = social.greet(player)
	_expect(greet.ok, "Ally greeting unavailable")
	await _observe(actor, 12, "Begruessung")
	actor.free()
	await process_frame
	actor = _specimen(1, 504)
	var refused: Dictionary = actor.get_node("SocialBehavior").befriend(player, 0.1, true)
	_expect(not refused.ok, "First inappropriate gesture was accepted")
	observations.append({"action": "refused_gesture", "result": refused})
	await _observe(actor, 12, "Abgelehnte Geste / Angst")
	var attacker := Node3D.new()
	scene.add_child(attacker)
	attacker.position = actor.position + Vector3.RIGHT
	actor.receive_creature_attack(1.0, attacker)
	await _observe(actor, 12, "Echter Fremdschaden / Schmerz")
	actor.free()
	attacker.free()
	await process_frame
	player.position = Vector3(0, 100.05, 2)
	actor = _animal("predator", Vector3(0, 100.05, 0), 411)
	actor._visual_root.rotation.y = PI
	await _observe(actor, 12, "Echte Wahrnehmung / Gefahr")
	actor.free()
	await process_frame
	await _group_views()
	await _inspection_matrix()
	for state: String in ["curious", "affectionate", "playful", "afraid", "hurt", "angry"]:
		_expect(visible_states.has(state), "No actual encounter captured for " + state)
	var file := FileAccess.open(output.path_join("signs.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"fixture": "flat production-runtime actors", "seed": 15838,
		"sun_rotation_degrees": [-55, -35, 0], "visible_states": visible_states,
		"marker_cpu_us": marker_us, "ui_matrix": matrix, "failures": failures}, "\t"))
	file.close()

func _observe(actor: Node3D, frames: int, caption: String) -> void:
	var camera := root.get_camera_3d()
	for frame in range(frames):
		var target: Vector3 = actor.global_position + Vector3.UP * 1.2
		camera.position = target + Vector3(4.3, 3.5, 7.2)
		camera.look_at(target)
		detail.text = caption
		await _frame(Time.get_ticks_usec(), true)
		var label: Label3D = actor._label
		if label.visible:
			visible_states[str(actor._emotion_cue._state)] = label.text
		observations.append({"frame": capture_serial - 1, "case": caption,
			"ai_intent": actor._intent, "ai_state": actor.ai_state,
			"emotion": actor.get_node("ExpressionBehavior").emotion.state,
			"symbol": label.text, "visible": label.visible, "health": actor.current_health,
			"camera": [camera.position.x, camera.position.y, camera.position.z]})

func _group_views() -> void:
	var animals: Array[CharacterBody3D] = []
	player.position = Vector3(0, 100.05, 2)
	var camera := root.get_camera_3d()
	camera.position = Vector3(4, 105, 11)
	camera.look_at(Vector3(0, 101.5, 0))
	camera.size = 10.0
	title.text = "R32-10 · Gruppenlimit / Prioritaet · kontrollierte Praesentationsinputs"
	for index in range(6):
		var actor := _animal("grazer", Vector3((index - 2.5) * 1.8, 100.05, 0), 771)
		actor.set_physics_process(false)
		actor.get_node("ExpressionBehavior").set_process(false)
		actor.get_node("ExpressionBehavior").emotion.state = "curious"
		actor._refresh_label(0.01)
		animals.append(actor)
	await _still("group-curiosity")
	animals[4]._intent = "alert"
	animals[4]._refresh_label(0.01)
	await _still("group-danger")
	for tick in range(100):
		var start: int = Time.get_ticks_usec()
		for actor in animals: actor._refresh_label(0.001)
		marker_us.append(Time.get_ticks_usec() - start)
	# Depth occlusion is provided by the renderer, without changing AI sensing.
	var wall := _box(Vector3(14, 8, 0.3), Vector3(0, 103.5, 4))
	await _still("group-occluded")
	wall.free()
	player.position = Vector3(0, 100.05, 22)
	for actor in animals: actor._refresh_label(0.01)
	await _still("group-distant")
	for actor in animals: actor.free()
	await process_frame

func _still(name: String) -> void:
	detail.text = name
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Still capture failed")

func _inspection_matrix() -> void:
	title.hide()
	detail.hide()
	var inspector: Node3D = load("res://creatures/player/player.tscn").instantiate()
	scene.add_child(inspector)
	inspector.position = Vector3(0, 100.05, 2)
	inspector.set_physics_process(false)
	inspector.set_process(false)
	inspector.hide()
	await process_frame
	await process_frame
	var hud: Node = inspector.get_node("CreatureInspectionHUD")
	if hud == null:
		_expect(false, "Production inspection HUD not found")
		inspector.free()
		return
	hud.set_process(false)
	var actor := _specimen(0, 511)
	actor.set_physics_process(false)
	actor.ai_state = "flee"
	for size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for scale: float in [1.0, 1.25, 1.5]:
			root.size = size
			root.content_scale_size = Vector2i(1280, 720)
			root.content_scale_factor = scale
			for locale: String in ["de", "en"]:
				root.get_node("LocaleManager")._apply(locale)
				hud._show_target(actor)
				hud._controls.text = tr("HUD_SCAN_CONTROLS") % "E"
				hud._panel.show()
				hud._layout()
				await process_frame
				hud._layout()
				await process_frame
				hud._layout()
				await RenderingServer.frame_post_draw
				var rect: Rect2 = hud._panel.get_global_rect()
				var inside: bool = root.get_visible_rect().encloses(rect)
				_expect(inside, "Inspection panel outside viewport: %s/%s/%s" % [size, scale, locale])
				var name: String = "inspection-%dx%d-%d-%s" % [size.x, size.y, roundi(scale * 100), locale]
				_expect(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "UI capture failed")
				matrix.append({"size": [size.x, size.y], "scale": scale, "locale": locale,
					"inside_viewport": inside, "detail": hud._detail.text,
					"metric_labels": hud._stats.values().map(func(v: Label) -> String: return v.get_parent().get_child(0).text),
					"image": name + ".png"})
	actor.free()
	inspector.free()
	await process_frame
