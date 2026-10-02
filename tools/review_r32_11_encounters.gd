extends "res://creatures/behavior/review/int30_creature_review.gd"
## Bounded native fixture using live production AI/social/pose actors. The
## inherited review player is an observer, not the regular campaign controller.
## Commands/results are recorded; captions are diagnostic, not product labels.
var caption: String = ""

func _encounters() -> void:
	for temperament in range(3):
		var actor: CharacterBody3D = _specimen(temperament, 801 + temperament)
		var social: Node = actor.get_node("SocialBehavior")
		player.position = actor.position + Vector3(0, 0, 2.0)
		var pause_response: float = 0.0
		for frame in range(104):
			caption = "Drei bewusste Aktionen · Temperament %d/3" % (temperament + 1)
			if frame in [0, 50, 86]: _record_action(actor, social.social_status().playful, true)
			if frame == 14:
				pause_response = social.response_remaining
				root.get_node("GameState").set_simulation_speed(0.0)
			if frame in range(14, 28): caption = "Pause · kein Vertrauen und keine Reaktionszeit vergehen"
			if frame == 28:
				_expect(social.response_remaining == pause_response, "Rendered pause advanced the response")
				_record_action(actor, false, false)
				root.get_node("GameState").set_simulation_speed(1.0)
			await _observe(actor)
		_expect(social.entry().trust == 100.0 and social.entry().relation == "ally", "Rendered temperament did not complete its three steps")
		for attempt in range(3): _record_action(actor, false, false)
		actor.free()
		await process_frame
	# Wrong gesture, genuine flight and calm retry; never reset the AI timers.
	var actor: CharacterBody3D = _specimen(1, 811)
	var social: Node = actor.get_node("SocialBehavior")
	player.position = actor.position + Vector3(0, 0, 2.0)
	_record_action(actor, false, true)
	for frame in range(36):
		caption = "Vorsichtiges Tier · beobachten und Reaktion abwarten"
		await _observe(actor)
	_record_action(actor, true, false)
	_expect(actor._threat_timer > 0.0 and social.entry().trust == 35.0, "Wrong gesture did not cause actual refusal")
	player.position = Vector3(25, 100.05, 25)
	await _calm(actor, "Abgelehnte Spielgeste · Abstand geben · echte Flucht / Beruhigung")
	player.position = actor.position + Vector3(0, 0, 2.0)
	_record_action(actor, false, true)
	for frame in range(18):
		caption = "Ruhiger erneuter Versuch · Vertrauen 70, keine Belohnung"
		await _observe(actor)
	actor.free()
	await process_frame
	# Actual damage interrupts attention; the saved partial relationship remains.
	actor = _specimen(2, 821)
	social = actor.get_node("SocialBehavior")
	player.position = actor.position + Vector3(0, 0, 2.0)
	_record_action(actor, false, true)
	for frame in range(14):
		caption = "Begegnung begonnen · Vertrauen 35"
		await _observe(actor)
	var attacker := Node3D.new()
	scene.add_child(attacker)
	attacker.position = actor.position + Vector3.RIGHT
	actor.receive_creature_attack(1.0, attacker)
	_record_action(actor, false, false)
	player.position = Vector3(25, 100.05, 25)
	for frame in range(8):
		caption = "Fremdangriff · Schmerz / Angst · Begegnung unterbrochen"
		await _observe(actor)
	attacker.free()
	await _calm(actor, "Unterbrechung · Bedrohung endet in der normalen KI")
	player.position = actor.position + Vector3(0, 0, 2.0)
	_record_action(actor, false, true)
	for frame in range(18):
		caption = "Wiederaufnahme · gespeichertem Tier bleibt Vertrauen 70"
		await _observe(actor)
	actor.free()
	await process_frame
	# Two near animals: only the explicitly selected target changes relationship.
	actor = _specimen(0, 831)
	var other: CharacterBody3D = _specimen(1, 832)
	actor.position.x = -1.7
	other.position.x = 1.7
	social = actor.get_node("SocialBehavior")
	player.position = actor.position + Vector3(0, 0, 2.0)
	_record_action(actor, false, true)
	_expect(other.get_node("SocialBehavior").entry().trust == 0.0, "Near second animal received first action")
	for frame in range(18):
		caption = "Zwei nahe Tiere · links 35 / rechts 0 · genau ein Ziel"
		await _observe(actor, other)
	player.position = other.position + Vector3(0, 0, 2.0)
	_record_action(other, false, true)
	_expect(social.entry().trust == 35.0, "Target switch advanced the old encounter")
	for frame in range(18):
		caption = "Zielwechsel · links 35 / rechts 35 · keine Mehrfachbindung"
		await _observe(actor, other)
	actor.free()
	other.free()
	await process_frame
	# A genuinely hostile role uses the same entry/rejection path and normal AI.
	actor = _specimen(2, 841)
	actor.ecological_role = "predator"
	player.position = actor.position + Vector3(0, 0, 4.0)
	_record_action(actor, false, false)
	for frame in range(36):
		caption = "Feindliches Tier · keine Vertrauensänderung durch Befreunden"
		await _observe(actor)
	_expect(actor.get_node("SocialBehavior").entry().trust == 0.0, "Hostile role accumulated trust")
	actor.free()
	await process_frame
	# Real SaveGameService reload while response is still pending.
	actor = _specimen(1, 851)
	social = actor.get_node("SocialBehavior")
	player.position = actor.position + Vector3(0, 0, 2.0)
	_record_action(actor, false, true)
	var saves: Node = root.get_node("SaveGameService")
	_expect(saves.save_now() and saves.load_now(), "Rendered save/load failed")
	_expect(social.response_remaining > 0.0, "Rendered reload erased response")
	_record_action(actor, false, false)
	for frame in range(18):
		caption = "Speichern / Laden · Reaktionspause bleibt erhalten · Vertrauen 35"
		await _observe(actor)
	actor.free()
	await process_frame

func _record_action(actor: CharacterBody3D, playful: bool, accepted: bool) -> void:
	var social: Node = actor.get_node("SocialBehavior")
	var before: float = social.entry().trust
	var result: Dictionary = social.befriend(player, 0.1, playful)
	observations.append({"frame": capture_serial, "object_id": actor.get_campaign_identity().object_id,
		"action": "play" if playful else "calm", "result": result, "before_trust": before, "after_trust": social.entry().trust})
	_expect(result.ok == accepted, "Unexpected visible action result: " + str(result))
	if not accepted: _expect(social.entry().trust == before, "Rejected visible action changed trust")

func _calm(actor: CharacterBody3D, text: String) -> void:
	var settled: bool = false
	for frame in range(180):
		caption = text
		await _observe(actor)
		if actor._threat_timer <= 0.0 and actor.get_expression_context().get("intent", "rest") not in ["flee", "alert", "chase"]:
			settled = true
			break
	_expect(settled, "Live AI did not calm within the unchanged 12-second fixture bound")

func _observe(actor: CharacterBody3D, other: CharacterBody3D = null) -> void:
	var start: int = Time.get_ticks_usec()
	var social: Node = actor.get_node("SocialBehavior")
	title.text = "R32-11 · aktive KI in Kollisionsprobe\n" + caption
	detail.text = "Vertrauen %.0f · Reaktionspause %.2f s" % [social.entry().trust, social.response_remaining]
	if other != null: detail.text += " · Nachbar %.0f" % other.get_node("SocialBehavior").entry().trust
	var camera: Camera3D = root.get_camera_3d()
	var target: Vector3 = actor.position + Vector3.UP
	if other != null: target = (actor.position + other.position) * 0.5 + Vector3.UP
	camera.size = 9.0 if other != null else 7.0
	camera.position = target + Vector3(4.3, 3.5, 7.2)
	camera.look_at(target)
	await _frame(start, true)
	if capture_serial % 15 == 0:
		observations.append({"frame": capture_serial, "object_id": actor.get_campaign_identity().object_id,
			"trust": social.entry().trust, "relation": social.entry().relation, "response": social.response_remaining,
			"intent": actor.get_expression_context().get("intent", "rest"), "grounded": actor.is_on_floor()})
