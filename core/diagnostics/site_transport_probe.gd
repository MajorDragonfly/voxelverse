extends "res://core/diagnostics/settlement_runtime_probe.gd"
const Freight = preload("res://world/tribe/transport/site_transport_state.gd")

func _run() -> void:
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	var path: String = saves.create_slot("Warentransport mit echten Wegen", 15838, Cube.MODE)
	await _open(path)
	if not _expect_world(): await _done(); return
	var home: Node = tree.current_scene.get_node("Nest/HomeGroup")
	_expect(home.establish_home().get("ok", false), "Home founding failed.")
	await _until(func() -> bool: return home.actors.size() == 2, 10000)
	var tribe: Node = tree.current_scene.get_node("Nest/Tribe")
	_expect(tribe.panel.open_confirmation(), "Tribal confirmation failed.")
	tribe.panel.confirm.pressed.emit()
	await _until(func() -> bool: return tribe.is_active() and tribe.domestication.is_active() and not tribe.navigation.pending, 15000)
	if not tribe.is_active(): _expect(false, "Tribe inactive: " + tribe.status); await _done(); return
	var residents: Array = tribe.village().members.map(func(m: Dictionary) -> String: return m.id)
	var origin: String = tribe.village().id
	# Evaluate a bounded set of real loaded ground points, using the exact live
	# clearance/route checks. The resident walks the winning path under physics.
	tree.paused = true
	var candidate: Vector3 = await _candidate(tribe)
	tree.paused = false
	if not candidate.is_finite(): _expect(false, "No valid second site in loaded terrain."); await _done(); return
	print("SECOND_SITE candidate ", candidate, " distance ", candidate.distance_to(tribe.anchor()))
	tribe.select_member(residents[2])
	_expect(tribe.issue_order("move", candidate), "Founder movement was rejected.")
	await _until(func() -> bool: return tribe.member_record(residents[2]).order == "wait", 20000)
	if not tribe.settlements.founding_reason().is_empty(): _expect(false, "Founder failed to arrive: " + tribe.settlements.founding_reason()); await _done(); return
	var location: Dictionary = tribe.member_record(residents[2]).position.duplicate(true)
	var home_before: Dictionary = tribe.body().home_group.duplicate(true)
	var source_stock: Dictionary = tribe.village().stock.duplicate(true)
	_expect(await tribe.settlements.found(), "Physical founding failed: " + tribe.status + " / " + saves.last_error)
	if not tribe.body().has("settlements"): await _done(); return

	var second: String = Collection.ids(tribe.body())[1]
	tribe.select_member(residents[1])
	_expect(tribe.issue_order("wood"), "Gathering shipment source stock failed.")
	await _until(func() -> bool: return tribe.village().stock.wood >= 3, 40000)
	_expect(tribe.village().stock.wood >= 3, "Carrier did not gather source goods.")
	_expect(tribe.issue_order("move", tribe.anchor()), "Carrier could not return to loading point.")
	await _until(func() -> bool: return tribe.member_record(residents[1]).order == "wait" and tribe.member_record(residents[1]).cargo == "", 15000)
	if not tribe.site_transport.reason(second).is_empty():
		_expect(false, "Carrier unavailable: " + tribe.site_transport.reason(second))
		await _done(); return
	var before: Dictionary = tribe.body().duplicate(true)
	DirAccess.make_dir_absolute(saves.save_path + ".tmp")
	_expect(not tribe.site_transport.send(second, "wood", 1), "Shipment survived an actual save failure.")
	DirAccess.remove_absolute(saves.save_path + ".tmp")
	_expect(tribe.body().get(Freight.FIELD, {}) == before.get(Freight.FIELD, {}) and tribe.village().stock == Collection.village(before, origin).stock, "UI transaction failed to roll back goods and job.")
	var stock: int = tribe.village().stock.wood
	var panel: Node = tribe.panel._tabs.find_child("SiteFreight", true, false)
	_expect(panel != null, "Missing playable shipment controls.")
	panel._amount.value = 2
	panel._send.pressed.emit()
	_expect(Freight.active(tribe.body()), "Send control failed: " + tribe.site_transport.message + " / " + saves.last_error)
	if not Freight.active(tribe.body()): await _done(); return
	_expect(tribe.village().stock.wood == stock - 2 and Collection.village(tribe.body(), second).stock.wood == 0, "Shipment credited destination before walking.")
	_expect(not tribe.issue_order("wood"), "Carrier accepted a competing village order.")
	_expect(not tribe.assign_profession("forester"), "Carrier accepted a competing profession.")
	_expect(not tribe.neighbors.start_aid_result().ok, "Carrier accepted competing neighbor aid.")
	_expect(tribe.domestication.issue_command("missing-animal", "follow").code == "handler_busy", "Carrier accepted competing animal handling.")
	await tree.physics_frame
	tree.paused = true
	var paused: String = Atomic.stringify(Freight.job(tribe.body()))
	for frame: int in 8: await tree.process_frame
	_expect(paused == Atomic.stringify(Freight.job(tribe.body())), "Pause advanced actual carrier.")
	tree.paused = false
	await _until(func() -> bool: return not Freight.active(tribe.body()), 30000)
	_expect(Freight.job(tribe.body()).status == "delivered", "Physical shipment failed: " + str(Freight.job(tribe.body())))
	_expect(Collection.village(tribe.body(), second).stock.wood == 2 and tribe.village().stock.wood == stock - 2, "Physical delivery did not conserve goods.")
	_expect(Freight.Home.distance(tribe.member_record(residents[1]).position, Collection.village(tribe.body(), second).anchor) < 1.0, "Stock arrived before the actual carrier.")
	# A second delivery switches to the unobserved source while already moving.
	_expect(tribe.issue_order("move", tribe.anchor()), "Return to loading point failed.")
	await _until(func() -> bool: return tribe.member_record(residents[1]).order == "wait", 20000)
	_expect(tribe.site_transport.send(second, "wood", 1), "Second shipment failed.")
	for frame: int in 6: await tree.physics_frame
	_expect(await tribe.settlements.select(second), "Near/far shipment switch failed: " + tribe.status)
	await _until(func() -> bool: return not Freight.active(tribe.body()), 20000)
	_expect(Freight.job(tribe.body()).status == "delivered" and tribe.village().stock.wood == 3, "Far delivery failed after actual settlement selection.")
	_expect(tribe.actors.size() == 1 and not tribe.actors.has(residents[1]), "Far carrier duplicated into destination actors.")
	_expect(saves.save_now(), "Playable shipment failed common save: " + saves.last_error)
	for locale: String in ["de", "en"]:
		TranslationServer.set_locale(locale)
		panel.refresh()
		_expect(not panel._title.text.contains("SITE_FREIGHT") and not panel._state.text.contains("SITE_FREIGHT") and not panel._send.text.contains("SITE_FREIGHT"), "Untranslated shipment controls: " + locale)
	await _done()

func _done() -> void:
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("SITE_TRANSPORT_RUNTIME_PASSED: real sphere, walked founder/carrier, gathered goods, UI send, failed-save rollback, pause, selection handoff, two deliveries and DE/EN.")
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)
