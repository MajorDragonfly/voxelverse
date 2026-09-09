extends "res://core/diagnostics/spherical_campaign_probe.gd"
const Space = preload("res://world/surface/gameplay_space.gd")
const Home = preload("res://world/home_group/home_group_state.gd")

func _run() -> void:
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	if "--sphere-gameplay-restart" in OS.get_cmdline_user_args():
		await _restart_gameplay()
		await _finish()
		return
	var path: String = saves.create_slot("Radiale Gemeinschaft", 15838, Cube.MODE)
	await _open(path)
	if not _expect_world(): await _finish(); return
	var scene: Node3D = tree.current_scene
	var player: CharacterBody3D = scene.player
	var population: Node = scene.population
	await _until(func() -> bool: return population.animals.size() >= 2 and population.plants.size() >= 2, 30000)
	_expect(population.animals.size() >= 2, "No shared physical wildlife on sphere.")
	_expect(population.plants.size() >= 2, "No finite food on sphere.")
	print("SPHERE_POPULATION ", population.animals.size(), " ", population.plants.size())
	var home: Node = scene.get_node("Nest/HomeGroup")
	var result: Dictionary = home.establish_home()
	_expect(result.get("ok", false), "Home failed: " + str(result))
	await _until(func() -> bool: return home.actors.size() == 2, 10000)
	if home.actors.size() != 2: await _finish(); return
	var tribe: Node = scene.get_node("Nest/Tribe")
	# Shared interface constructs the same reversible handoff as the regular UI.
	var reason: String = tribe.prepare_confirmation()
	_expect(reason.is_empty(), "Radial village preparation failed: " + reason)
	if not reason.is_empty(): await _finish(); return
	print("SPHERE_VILLAGE_PREPARED ", tribe.navigation.graph.get_point_count())
	_expect(tribe.panel.open_confirmation(), "Shared confirmation did not open.")
	tribe.panel.confirm.pressed.emit()
	await _until(func() -> bool: return tribe.is_active(), 12000)
	_expect(tribe.is_active(), "Shared handoff failed: " + tribe.status + " / " + saves.last_error)
	if not tribe.is_active(): await _finish(); return
	var ids: Array = tribe.village().members.map(func(m: Dictionary) -> String: return m.id)
	_expect(tribe.actors.size() == 3 and home.actors.is_empty(), "Handoff duplicated home residents.")
	tribe.select_member(ids[0])
	_expect(tribe.issue_order("wood"), "Radial resident could not accept work.")
	await _until(func() -> bool: return tribe.member_record(ids[0]).cargo == "wood", 16000)
	_expect(tribe.member_record(ids[0]).cargo == "wood", "Resident did not collect real wood: " + tribe.status)
	_expect(tribe.issue_order("wait"), "Cannot pause loaded carrier.")
	var cargo: String = tribe.member_record(ids[0]).cargo
	_expect(tribe.neighbors.contact(), "No reachable neighbor: " + tribe.status)
	_expect(not tribe.body().get("tribal_neighbor", {}).is_empty(), "Neighbor missing.")
	print("SPHERE_VILLAGE_ACTIVE ", tribe.actors.size(), " ", cargo, " ", tribe.neighbors.actors.size())
	var before: Dictionary = state.get_current_body().home_group.duplicate(true)
	flow.toggle_pause()
	_expect(saves.save_now(), "Home/population save failed: " + saves.last_error)
	var raw: Dictionary = saves._read_save(path)
	_expect(saves._validate_save(raw).is_empty(), "Saved radial gameplay did not validate.")
	flow.resume()
	var locations: Dictionary = {}
	for id in scene.adapter.attached:
		locations[id] = Space.encode(self, scene.adapter.attached[id].global_position)
	var origin: Array = scene.terrain.origin.duplicate()
	scene.terrain.rebase([origin[0] + 123.0, origin[1] - 74.0, origin[2] + 51.0])
	for id in locations:
		_expect(Home.distance(locations[id], Space.encode(self, scene.adapter.attached[id].global_position)) < 0.005, "Rebase moved bound gameplay root: " + id)
	_expect(Home.validate(before, state.get_current_body().id, state.campaign.data.player_species_id).is_empty(), "Canonical home invalid.")
	_expect(saves.save_now(), "Post-rebase village save failed: " + saves.last_error)
	var checkpoint: Dictionary = saves._read_save(path)
	flow.return_to_title()
	await tree.scene_changed
	await _open(path, true)
	_expect(Migration.fingerprint(state.get_current_body().tribe) == Migration.fingerprint(checkpoint.game_state.campaign.bodies["15838"].tribe), "Restart changed resident orders or cargo.")
	flow.resume()
	await _until(func() -> bool: return tree.current_scene.get_node("Nest/Tribe").is_active(), 15000)
	tribe = tree.current_scene.get_node("Nest/Tribe")
	_expect(tribe.is_active() and tribe.member_record(ids[0]).cargo == cargo, "Restart lost loaded carrier.")
	tribe.select_member(ids[0])
	tribe.issue_order("resume")
	await _until(func() -> bool: return tribe.village().stock.wood > 0, 16000)
	_expect(tribe.village().stock.wood > 0, "Carrier did not physically deliver after restart.")
	await _animal_chain(tribe)
	flow.return_to_title()
	await tree.scene_changed
	if failures.is_empty(): print("SPHERICAL_GAMEPLAY_PASSED: shared radial population, home, village, loaded cargo, neighbor, rebase and restart.")
	await _finish()

func _until(predicate: Callable, milliseconds: int) -> void:
	var started: int = Time.get_ticks_msec()
	while not predicate.call() and Time.get_ticks_msec() - started < milliseconds: await tree.process_frame

func _animal_chain(tribe: Node) -> void:
	state.set_simulation_speed(4.0)
	var data: Dictionary = tribe.village()
	tribe.select_all()
	tribe.issue_order("wait")
	# A conserved starting reserve lets this scenario focus on animal transport.
	for kind in ["wood", "stone", "food"]:
		var amount: int = mini(20 - int(data.stock[kind]), int(data.deposits[kind].remaining))
		if amount > 0:
			data.stock[kind] += amount
			data.deposits[kind].remaining -= amount
	_expect(saves.save_now(), "Conserved reserve invalid: " + saves.last_error)
	_expect(tribe.issue_order("tool"), "Cannot start tool construction.")
	await _until(func() -> bool: return tribe.village().tools == 1, 12000)
	if not _expect_step(tribe.village().tools == 1, "Tool construction did not complete."): return
	for kind in ["well", "fiberbed"]:
		var workplace: Vector3 = _site(tribe, kind)
		if not _expect_step(workplace.is_finite(), "No physical site for " + kind): return
		if not _expect_step(tribe.issue_order(kind, workplace), "Cannot build " + kind + ": " + tribe.status): return
		await _until(func() -> bool: return tribe.village().economy.stations.has(kind), 20000)
		if not _expect_step(tribe.village().economy.stations.has(kind), "Construction did not finish: " + kind): return
		tribe.issue_order("water" if kind == "well" else "fiber")
		await _until(func() -> bool: return tribe.village().stock["water" if kind == "well" else "fiber"] >= (12 if kind == "well" else 4), 45000)
	tribe.issue_order("wait")
	if not _expect_step(saves.save_now(), "Actual workshop reserve invalid: " + saves.last_error): return
	var runtime: Node = tribe.domestication
	await _until(func() -> bool: return runtime.is_active(), 8000)
	var animal: Node3D
	# D1 exposes a role list; use the exact checked policy rather than an ecology role.
	if animal == null:
		for candidate: Node3D in runtime.visible_animals():
			var traits: Dictionary = candidate.blueprint.get("species", {}).get("domestication", {})
			if float(traits.get("milk_yield", 0.0)) > 0: animal = candidate; break
	_expect(animal != null, "No live D1 milk animal.")
	if animal == null: return
	var id: String = animal.get_campaign_identity().object_id
	var species_id: String = animal.get_campaign_identity().species_id
	var handler: String = data.members[0].id
	tribe.select_member(handler)
	if not await _approach_live(tribe, runtime, id, handler): return
	for meal in range(10):
		if runtime.controller.record(id).get("status") == "tamed": break
		if not await _approach_live(tribe, runtime, id, handler): return
		var offer: Dictionary = runtime.offer(id)
		_expect(offer.ok, "Milk animal offer failed: " + str(offer))
		if not offer.ok: return
		await _until(func() -> bool: return runtime.controller.record(id).pending.is_empty(), 6000)
	_expect(runtime.controller.record(id).get("status") == "tamed", "Milk animal did not retain completed food/trust.")
	_expect(runtime.controller.record(id).species_id == species_id and data.members.size() == 3, "Taming changed species or recruited a citizen.")
	print("SPHERE_TAMED ", id)
	var journal: Node = tree.get_first_node_in_group(&"discovery_journal")
	if not _expect_step(journal != null and journal.open_journal(), "Shared animal book did not open in the campaign."): return
	journal._tabs.current_tab = journal.ANIMALS_TAB
	journal.refresh_owned_animals()
	var owned: Array = journal._rows.filter(func(row: Dictionary) -> bool: return row.key == id)
	_expect(owned.size() == 1 and owned[0].location.contains("Breite"), "Shared campaign book lost the original spherical milk animal.")
	journal.close_journal()
	await tree.process_frame
	_expect(runtime.issue_command(id, "home").ok, "Radial home command failed.")
	await _until(func() -> bool: return runtime.actor_for(id).global_position.distance_to(tribe.anchor()) < 1.6, 18000)
	_expect(runtime.actor_for(id).global_position.distance_to(tribe.anchor()) < 1.6, "Owned animal did not walk home.")
	_expect(runtime.issue_command(id, "wait").ok, "Radial animal wait failed.")
	tribe.select_all()
	var site: Vector3 = _site(tribe, "pen")
	_expect(site.is_finite(), "No reachable physical pen site.")
	if not site.is_finite(): return
	_expect(tribe.issue_order("pen", site), "Cannot reserve pen construction: " + tribe.status)
	await _until(func() -> bool: return not tribe.village().husbandry.pens.is_empty(), 45000)
	_expect(not tribe.village().husbandry.pens.is_empty(), "Pen material transport/construction failed: " + str({"status": tribe.status, "project": tribe.village().project, "members": tribe.village().members, "routes": tribe._routes, "goals": tribe._goals}))
	if tribe.village().husbandry.pens.is_empty(): return
	tribe.issue_order("wait")
	tribe.select_member(handler)
	_expect(runtime.issue_command(id, "follow").ok, "Animal did not accept follow.")
	# Walk through the pen: follow deliberately stops behind the handler, so
	# the resident's arrival radius must not be mistaken for animal admission.
	var through: Vector3 = site + (site - tribe.anchor()).slide(Space.up(self, site)).normalized() * 1.2
	through = tribe.navigation.snap(through)
	_expect(tribe.issue_order("move", through), "Handler cannot walk through pen.")
	await _until(func() -> bool: return runtime.actor_for(id).global_position.distance_to(site) < 1.8, 24000)
	_expect(runtime.actor_for(id).global_position.distance_to(site) < 1.8, "Animal did not follow handler to pen: " + str({"animal": runtime.actor_for(id).global_position, "handler": tribe.actors[handler].global_position, "site": site, "status": runtime.actor_for(id).status, "animal_route": runtime._routes.get(id), "handler_record": tribe.member_record(handler)}))
	runtime.issue_command(id, "wait")
	var pen: Dictionary = tribe.village().husbandry.pens[0]
	_expect(tribe.husbandry.assign(pen.id, id), "D2->D3 admission failed: " + tribe.status)
	if pen.animal_id != id: return
	tribe.select_member(data.members[1].id)
	tribe.assign_profession("keeper")
	tribe.select_member(data.members[2].id)
	tribe.assign_profession("milk_carrier")
	await _until(func() -> bool: return tribe.village().husbandry.delivered.food > 0 and tribe.village().husbandry.delivered.water > 0, 28000)
	_expect(tribe.village().husbandry.delivered.food > 0 and tribe.village().husbandry.delivered.water > 0, "Keeper did not physically supply pen.")
	var carrier: String = data.members[2].id
	await _until(func() -> bool: return tribe.member_record(carrier).cargo == "milk", 100000)
	if not _expect_step(tribe.member_record(carrier).cargo == "milk", "No real carrier collected the milk batch."): return
	tribe.select_member(carrier)
	tribe.issue_order("wait")
	var stock: int = tribe.village().stock.milk
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 3)
	shape.shape = box
	blocker.add_child(shape)
	tree.current_scene.add_child(blocker)
	blocker.global_transform = Transform3D(Space.frame(self, tribe.actors[carrier].global_position), Space.offset(self, tribe.actors[carrier].global_position, Vector3(0, 1, 0)))
	await tree.physics_frame
	tribe.issue_order("resume")
	await _until(func() -> bool: return tribe.member_record(carrier).blocked, 5000)
	_expect(tribe.member_record(carrier).blocked and tribe.member_record(carrier).cargo == "milk" and tribe.village().stock.milk == stock, "Blocked path delivered or lost milk.")
	tribe.issue_order("wait")
	blocker.queue_free()
	await tree.physics_frame
	flow.toggle_pause()
	_expect(saves.save_now(), "Loaded milk carrier could not save: " + saves.last_error)
	var path: String = saves.save_path
	var expected: Dictionary = {"target": path, "saved": saves._read_save(path)}
	_expect(Atomic.write("user://sphere_gameplay_restart.json", expected, false) == OK, "Cannot preserve milk restart evidence.")
	flow.return_to_title()
	await tree.scene_changed
	var output: Array = []
	var arguments: PackedStringArray = ["--headless"]
	if OS.has_feature("editor"): arguments.append_array(["--path", ProjectSettings.globalize_path("res://")])
	arguments.append_array(["--", "--sphere-gameplay-smoke", "--sphere-gameplay-restart"])
	var code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
	_expect(code == 0 and str(output).contains("SPHERE_GAMEPLAY_FRESH_PROCESS_PASSED"), "Fresh milk process failed: " + str(output))
	await _open(path, true)
	if not _expect_world(): return
	tribe = tree.current_scene.get_node("Nest/Tribe")
	flow.resume()
	await _until(func() -> bool: return tribe.is_active(), 15000)
	tribe.select_member(carrier)
	_expect(tribe.member_record(carrier).cargo == "milk", "Reload lost real milk cargo.")
	tribe.issue_order("resume")
	await _until(func() -> bool: return tribe.village().economy.milk_received > 0, 18000)
	_expect(tribe.village().economy.milk_received > 0, "Milk cycle did not reach storage through actual transport.")
	_expect(saves.save_now(), "Complete D1/D2/D3 sphere save failed: " + saves.last_error)
	print("SPHERE_MILK_DELIVERED ", tribe.village().economy.milk_received)

func _restart_gameplay() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://sphere_gameplay_restart.json"))
	await _open(expected.target, true)
	if not _expect_world(): return
	var body: Dictionary = state.get_current_body_record()
	var previous: Dictionary = expected.saved.game_state.campaign.bodies["15838"]
	for field in ["home_group", "tribe", "domesticated_animals", "tribal_neighbor", "surface_population"]:
		_expect(Migration.fingerprint(body[field]) == Migration.fingerprint(previous[field]), "Fresh process changed milk checkpoint: " + field)
	_expect(state.campaign.data.elapsed_seconds == expected.saved.game_state.campaign.elapsed_seconds, "Closed application advanced campaign time.")
	if failures.is_empty(): print("SPHERE_GAMEPLAY_FRESH_PROCESS_PASSED")
	flow.return_to_title()
	await tree.scene_changed

func _site(tribe: Node, kind: String) -> Vector3:
	for point_id: int in tribe.navigation.graph.get_point_ids():
		var candidate: Vector3 = tribe.navigation.graph.get_point_position(point_id)
		if candidate.distance_to(tribe.anchor()) < 6 or candidate.distance_to(tribe.anchor()) > 9: continue
		var free: bool = tribe.navigation.free_shelter(candidate, tribe.village(), kind) if kind == "pen" else tribe.navigation.free_workplace(candidate, tribe.village(), kind)
		if free and not tribe.neighbors.occupies(candidate): return candidate
	return Vector3.INF

func _approach_live(tribe: Node, runtime: Node, id: String, handler: String) -> bool:
	var start: int = Time.get_ticks_msec()
	var diagnostic_at: int = start + 2000
	var retry_at: int = start
	while Time.get_ticks_msec() - start < 24000:
		var actor: Node3D = runtime.actor_for(id)
		if actor == null: break
		if tribe.member_record(handler).order == "wait":
			if actor.global_position.distance_to(tribe.actors[handler].global_position) <= runtime.Controller.REACH - 0.1 and runtime.context(id, handler).line_of_sight: return true
			# A wild animal can temporarily leave the resident's work area.
			# Wait for its real patrol/return instead of requiring instant reach.
			if Time.get_ticks_msec() >= retry_at:
				runtime.approach(id)
				retry_at = Time.get_ticks_msec() + 250
		if Time.get_ticks_msec() >= diagnostic_at:
			diagnostic_at += 2000
			var walker: CharacterBody3D = tribe.actors[handler]
			print("TAME_PATH ", walker.global_position, " velocity=", walker.velocity, " floor=", walker.is_on_floor(), " route=", tribe._routes.get(handler, PackedVector3Array()).slice(0, 2), " target=", actor.global_position)
		await tree.process_frame
	return _expect_step(false, "Handler did not reach moving animal: " + runtime.status + " / " + tribe.status + " / " + str(tribe.member_record(handler)) + " / animal=" + str(runtime.actor_for(id).global_position if runtime.actor_for(id) != null else Vector3.INF) + " / handler=" + str(tribe.actors[handler].global_position))

func _expect_step(condition: bool, message: String) -> bool:
	_expect(condition, message)
	return condition

func _finish() -> void:
	tree.paused = false
	for failure in failures: push_error(failure)
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)
