extends SceneTree
## Actual shared player widgets: responsive geometry, read-only vitals and modal return.
const Layout = preload("res://ui/hud_layout.gd")
var failures: Array[String] = []
var output := ""
var player: Node3D
var hud: Node
var map: CanvasLayer

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--capture" in args: output = args[args.find("--capture") + 1]
	var saves := root.get_node("SaveGameService")
	saves.session_managed = true
	saves.autosave_enabled = false
	saves.create_slot("HUD layout", 15838, "legacy_plane_v9")
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.size = Vector2i(1280, 720)
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	player = load("res://creatures/player/player.tscn").instantiate()
	player.position = Vector3(0, 100, 0)
	scene.add_child(player)
	player.fall_acceleration = 0
	await _frames(8)
	player.set_process(false)
	root.content_scale_size = Vector2i.ZERO
	hud = player.get_node("HUDPresentation")
	map = get_first_node_in_group(&"minimap_hud")
	var vitals: Control = player.find_child("CompactVitals", true, false)
	var progression: Control = player.find_child("ProgressionDock", true, false)
	var inspection: Node = player.get_node("CreatureInspectionHUD")
	var target: Node = player.get_node("TargetHealthHUD")
	var journal := get_first_node_in_group(&"discovery_journal")
	var original_max: float = player.maximum_health
	player.maximum_health = 240
	player.current_health = 48
	player.current_hunger = 62
	player.current_thirst = 17
	player._update_hud()
	hud._process(1)
	_expect(hud._vitals.HealthBar.bar.max_value == 240 and hud._vitals.HealthBar.bar.value == 48, "Vitals did not follow changed maximum and damage.")
	_expect(hud._vitals.HealthBar.value.text == "! 48/240" and hud._critical, "Critical health lacks a non-colour warning.")
	_expect(player.thirst_bar == hud._vitals.ThirstBar.source, "Vitals replaced controller-owned source bars.")
	var before: Dictionary = player.export_runtime_state()
	for dimensions: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(800, 600)]:
		for scaling: float in [1.0, 1.5]:
			root.size = dimensions
			root.content_scale_factor = scaling
			await _frames(8)
			for language: String in ["de", "en"]:
				root.get_node("LocaleManager")._apply(language)
				await _frames(4)
				hud._process(1)
				map._update_snapshot()
				inspection._layout()
				await _frames(4)
				_expect(map.visible, "Minimap disappeared during gameplay.")
				var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
				var map_rect := _physical(map._panel)
				var vital_rect := _physical(vitals)
				_expect(screen.encloses(map_rect) and screen.encloses(vital_rect), "Map or vital panel outside " + str(dimensions))
				_expect(map_rect.end.y + 8 <= vital_rect.position.y, "Map overlaps vitals.")
				_expect(map._map.map_rect().size.x == map._map.map_rect().size.y, "Compact minimap distorts distances.")
				_expect(absf(map_rect.position.x - vital_rect.position.x) < 1, "Map and vitals lose their shared edge.")
				_expect(screen.encloses(_physical(progression)), "Progression dock outside viewport.")
				_expect(_physical(inspection._panel).end.y <= dimensions.y - 80, "Scan card enters home/action footer.")
				_expect(not _physical(inspection._panel).intersects(map_rect), "Scan card overlaps minimap.")
				target._panel.show()
				player.show_gameplay_message("Eine Spielmeldung mit genügend Text zum Prüfen des Zeilenumbruchs.")
				player.get_node("ProgressionHUD")._show_notification("Neue Art entdeckt · Entdeckungsbuch ansehen")
				hud._process(1)
				await _frames(4)
				var message: Control = player.find_child("GameplayMessage", true, false)
				var discovery: Control = player.find_child("DiscoveryNotification", true, false)
				_expect(not _physical(message).intersects(_physical(discovery)), "Gameplay and discovery messages overlap: " + str(dimensions) + " / " + str(scaling) + str(_physical(message)) + str(_physical(discovery)))
				_expect(not _physical(target._panel).intersects(_physical(progression)), "Combat header overlaps progression shortcuts.")
				target._panel.hide()
				message.hide()
				discovery.hide()
				if scaling == 1.0 and language == "de": await _capture("hud-%dx%d.png" % [dimensions.x, dimensions.y])
	_expect(player.export_runtime_state() == before, "HUD layout changed authoritative player state.")
	# Existing journal button really opens/closes the same shared book.
	root.size = Vector2i(1280, 720)
	root.content_scale_factor = 1.0
	player.set_physics_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.find_child("OpenDiscoveryJournal", true, false).pressed.emit()
	await _frames(4)
	_expect(journal.is_open and paused and not map.visible, "Journal action failed to pause/hide the map.")
	journal.close_journal()
	await create_timer(0.2).timeout
	_expect(not paused and map.visible, "Map did not return after closing the journal.")
	player.maximum_health = original_max
	scene.queue_free()
	await _frames(4)
	_expect(get_nodes_in_group(&"minimap_hud").is_empty(), "Minimap leaked on scene exit.")
	await _sphere()
	for failure in failures: push_error(failure)
	print("HUD_LAYOUT_OK" if failures.is_empty() else "HUD_LAYOUT_FAILED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _sphere() -> void:
	var saves := root.get_node("SaveGameService")
	var flow := root.get_node("SessionFlow")
	var path: String = saves.create_slot("HUD Kugelkampagne", 15838, preload("res://world/space/cube_sphere.gd").MODE)
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	flow.load_game(path)
	var started := Time.get_ticks_msec()
	while flow.loading and Time.get_ticks_msec() - started < 45000: await process_frame
	if current_scene == null or current_scene.scene_file_path != "res://main/spherical_campaign.tscn" or not current_scene.world_initialized:
		_expect(false, "Real spherical campaign failed to load: " + saves.last_error)
		return
	_expect(get_nodes_in_group(&"minimap_hud").size() == 1, "Spherical campaign installed more than one minimap.")
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	root.get_node("LocaleManager")._apply("de")
	player = current_scene.player
	hud = player.get_node("HUDPresentation")
	map = get_first_node_in_group(&"minimap_hud")
	await create_timer(0.5).timeout
	_expect(map.visible, "Spherical minimap is hidden.")
	var first_steps: Control = flow.find_child("FirstStepsCard", true, false)
	_expect(_physical(first_steps).end.y <= 720 - 100, "Onboarding covers the home shortcut.")
	await _capture("hud-sphere-1280x720.png")
	# Render the compact scanner with a real species; acquisition is covered by creature_scan_test.
	var creature: Node3D = load("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
	creature.configure(2771337, 911227, Vector2i.ZERO, "forager")
	current_scene.add_child(creature)
	creature.set_physics_process(false)
	creature.position = player.position + Vector3(0, 0, -4)
	var inspection: Node = player.get_node("CreatureInspectionHUD")
	inspection.set_process(false)
	inspection._show_target(creature)
	inspection._controls.text = tr("HUD_SCAN_CONTROLS") % "E"
	inspection._panel.show()
	player.inspection_mode_enabled = true
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(800, 600)]:
		root.size = dimensions
		await _frames(8)
		inspection._layout()
		await _frames(4)
		_expect(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(_physical(inspection._panel)), "Populated scan card is clipped.")
		_expect(not first_steps.is_visible_in_tree(), "Onboarding overlays the active scanner.")
		var tribe_entry: Control = current_scene.find_child("TribalAgeEntry", true, false)
		_expect(not _physical(tribe_entry).intersects(_physical(map._panel)), "Tribe entry overlaps the minimap.")
		await _capture("hud-scan-%dx%d.png" % [dimensions.x, dimensions.y])
	creature.queue_free()
	flow.return_to_title()
	await scene_changed
	await _frames(3)
	_expect(get_nodes_in_group(&"minimap_hud").is_empty(), "Spherical minimap leaked after returning to title.")

func _physical(control: Control) -> Rect2:
	var transform := control.get_global_transform_with_canvas()
	var factor := Layout.canvas_scale(control)
	return Rect2(transform.origin / factor, control.size * transform.get_scale() / factor)

func _frames(count: int) -> void:
	for i in range(count): await process_frame

func _capture(filename: String) -> void:
	if output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(filename))

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
