extends "res://tests/tribal_age_world_test.gd"
const D1 = preload("res://world/fauna/domestication/domestication_contract.gd")
var metrics: Dictionary = {}

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var saves: Node = root.get_node("SaveGameService")
	var state: Node = root.get_node("GameState")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://d2-world.json"
	state.start_world_with_seed(23757)
	state.campaign.reset("campaign_d2_world_validation")
	await process_frame
	change_scene_to_file("res://main/main.tscn")
	await scene_changed
	var home: Node = current_scene.get_node("Nest/HomeGroup")
	var tribe: Node = current_scene.get_node("Nest/Tribe")
	var d2: Node = tribe.get_node("Domestication")
	var streamer: Node = current_scene.get_node("FaunaStreamerV7")
	var player: CharacterBody3D = current_scene.get_node("Player")
	var animal: Node3D
	for frame in range(1800):
		await _frames(1)
		if not home.can_use_panel(): continue
		for candidate in streamer._active_fauna:
			if is_instance_valid(candidate) and not candidate.catalog_species.is_empty() and candidate.is_on_floor(): animal = candidate
		if animal != null and player.is_on_floor() and streamer.domestic_fauna.plants.size() >= 3: break
	_expect(animal != null, "Live D1 generator did not provide a companion")
	if animal == null:
		await _done()
		return
	var candidates: Array = []
	for candidate in streamer._active_fauna:
		if is_instance_valid(candidate) and not candidate.catalog_species.is_empty():
			candidates.append(candidate)
			candidate.set_physics_process(false)
	# Freeze only while arranging the initial home; neither body nor position is fabricated.
	animal.set_physics_process(false)
	player.set_physics_process(false)
	player.set_process(false)
	for frame in range(500):
		await _frames(1)
		if current_scene.get_node("WorldManager").get_pending_chunk_count() == 0: break
	# Placement and authored obstacle jobs outlive the terrain queue. Search
	# only after those actual collision owners have completed around the village.
	for frame in range(6000):
		await process_frame
		var complete: bool = true
		for chunk: Node in current_scene.get_node("WorldManager").loaded_chunks.values():
			if not chunk.generation_complete or not chunk.get_node("ProceduralEcosystemV6").generation_complete: complete = false
		if complete: break
	print("D2_WORLD: terrain and obstacle placement ready")
	var generator: Node = root.get_node("WorldGenerator")
	var nav := Navigation.new()
	var established: bool = false
	var site_counts: Dictionary = {"ground": 0, "navigation": 0, "last_rejection": ""}
	for candidate in candidates:
		animal = candidate
		for x in range(-16, 17):
			for z in range(-16, 17):
				var point: Vector3 = animal.global_position + Vector3(x, 0, z)
				point.y = generator.get_terrain_height(point.x, point.z) + 0.3
				if not home.has_ground(point): continue
				site_counts["ground"] += 1
				nav.rebuild(home, home._floor_hit(point)["position"])
				if nav.sites().is_empty(): continue
				var connected: bool = true
				for offset: Vector3 in [Vector3(-2.5, 0, 2.5), Vector3(2.5, 0, 2.5)]:
					var floor_hit: Dictionary = home._floor_hit(point + offset)
					if floor_hit.is_empty() or nav.route(floor_hit["position"] + Vector3.UP * 0.08, nav.origin).is_empty(): connected = false
				if not connected: continue
				nav.rebuild(home, home._floor_hit(point)["position"], {}, 20)
				var can_approach: bool = false
				for point_id: int in nav.graph.get_point_ids():
					var reachable: Vector3 = nav.graph.get_point_position(point_id)
					if reachable.distance_to(nav.origin) <= 20 and reachable.distance_to(animal.global_position) <= 4.1 and not nav.route(nav.origin, reachable).is_empty():
						can_approach = true
						break
				if not can_approach: continue
				site_counts["navigation"] += 1
				player.global_position = home._floor_hit(point)["position"] + Vector3.UP * 0.3
				await _frames(1)
				var result: Dictionary = home.establish_home()
				site_counts["last_rejection"] = str(result)
				if result["ok"]:
					established = true
					break
			if established: break
		if established: break
	_expect(established, "No village site near generated fauna")
	metrics["site_search"] = site_counts
	var identity: Dictionary = animal.get_campaign_identity()
	var original: Dictionary = D1.encode(animal.blueprint)
	metrics["source"] = identity
	metrics["source_position"] = str(animal.global_position)
	if not established:
		await _done()
		return
	print("D2_WORLD: home established ", home.home_position())
	await _frames(30)
	if not tribe.prepare_confirmation().is_empty():
		home.issue_order("home")
		for frame in range(120):
			await _frames(1)
			if tribe.prepare_confirmation().is_empty(): break
	tribe.panel.open_confirmation()
	_expect(not tribe.panel.confirm.disabled, "Real village cannot confirm tribal age: " + tribe.panel._detail.text)
	tribe.panel._confirm()
	await _frames(30)
	_expect(d2.is_active(), "D2 did not activate on real terrain")
	if not d2.is_active():
		await _done()
		return
	for candidate in candidates:
		if is_instance_valid(candidate) and candidate != animal: candidate.set_physics_process(true)
	Engine.time_scale = 3.0
	print("D2_WORLD: tribe active; gathering")
	tribe.select_all()
	_expect(tribe.issue_order("food"), "Cannot gather actual taming food")
	for frame in range(1800):
		await _frames(1)
		if tribe.village()["stock"]["food"] >= 12: break
	_expect(tribe.village()["stock"]["food"] >= 12, "Real residents cannot deliver taming food")
	tribe.issue_order("wait")
	await _frames(10)
	var handler: String = tribe.village()["members"][0]["id"]
	tribe.select_member(handler)
	# Controlled initial condition: the real spawned animal stays still during
	# village/food preparation and the handler's approach. Release its real AI
	# before feeding; no body, position, stock or route is synthesized.
	var before_food_clock: float = animal._foraging_clock
	var before_water_clock: float = animal._water_clock
	var accepted: bool = false
	if d2.approach(identity["object_id"]):
		for frame in range(500):
			await _frames(1)
			if tribe.member_record(handler)["order"] == "wait": break
		animal.set_physics_process(true)
		await _frames(1)
		_expect(animal._foraging_clock > before_food_clock and animal._water_clock > before_water_clock and animal._ignore_player, "Phase 1 froze fauna needs or retained player aggro")
		accepted = d2.offer(identity["object_id"])["ok"]
		metrics["adopted_source"] = identity
	_expect(accepted, "Cannot approach and feed actual generated animal: " + d2.status)
	if not accepted:
		var nearest: float = INF
		for point_id: int in tribe.navigation.graph.get_point_ids():
			var point: Vector3 = tribe.navigation.graph.get_point_position(point_id)
			if point.distance_to(tribe.anchor()) > 20 or tribe.navigation.route(tribe.actors[handler].global_position, point).is_empty(): continue
			nearest = minf(nearest, point.distance_to(animal.global_position))
		metrics["nearest_reachable_m"] = nearest
		metrics["members"] = tribe.village()["members"]
		metrics["animal_position"] = str(animal.global_position) if is_instance_valid(animal) else "gone"
		await _done()
		return
	var food_start: int = tribe.village()["stock"]["food"]
	print("D2_WORLD: first offer accepted")
	var meals: int = ceili(100.0 / float(d2._policy.for_species(identity["species_id"], "food")["trust_gain"]))
	for meal in range(meals):
		if meal > 0: _expect(d2.offer(identity["object_id"])["ok"], "Repeated real-world offer failed: " + d2.status)
		for frame in range(180):
			await _frames(1)
			if d2.controller.record(identity["object_id"])["pending"].is_empty(): break
	var record: Dictionary = d2.controller.record(identity["object_id"])
	_expect(record["status"] == "tamed" and record["trust"] == 100, "Real-world animal did not tame")
	_expect(tribe.village()["stock"]["food"] == food_start - meals, "Real-world food was duplicated or spent twice")
	_expect(tribe.actors.size() == 3 and D1.encode(d2.animals[identity["object_id"]].blueprint) == original, "Real-world adoption changed body or citizens")
	_expect(d2.issue_command(identity["object_id"], "home")["ok"], "Real-world return home rejected")
	var return_start: Vector3 = d2.animals[identity["object_id"]].global_position
	await _frames(500)
	metrics["home_travel_m"] = return_start.distance_to(d2.animals[identity["object_id"]].global_position)
	metrics["home_gap_m"] = d2.animals[identity["object_id"]].global_position.distance_to(tribe.anchor())
	metrics["animal_home_position"] = str(d2.animals[identity["object_id"]].global_position)
	metrics["home_position"] = str(tribe.anchor())
	metrics["animal_status"] = d2.animals[identity["object_id"]].status
	metrics["food_spent"] = food_start - int(tribe.village()["stock"]["food"])
	_expect(float(metrics["home_gap_m"]) < 1.7 and float(metrics["home_travel_m"]) > 5.0, "Animal cannot return to home area on actual terrain")
	_expect(saves.save_now() and saves.load_now(), "Main world save/load failed")
	await _frames(120)
	var count: int = 0
	for node: Node in get_nodes_in_group(&"wildlife"):
		if node.get_campaign_identity()["object_id"] == identity["object_id"]: count += 1
	_expect(count == 1 and d2.controller.record(identity["object_id"])["status"] == "tamed", "Main world reload duplicated or forgot held animal")
	tribe.panel._tabs.current_tab = d2.controls.get_index()
	for size: Vector2i in [Vector2i(1280, 800), Vector2i(1280, 720)]:
		root.size = size
		await _frames(4)
		var rect: Rect2 = tribe.panel._hud.get_global_rect()
		_expect(d2.controls.visible and rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= size.x + 1 and rect.end.y <= size.y + 1, "Tribal animal controls exceed viewport: " + str(size))
	await _done()

func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame

func _done() -> void:
	print(JSON.stringify({"test": "domestication_world", "failures": failures, "measurements": metrics}))
	if is_instance_valid(current_scene): current_scene.queue_free()
	await _frames(12)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
