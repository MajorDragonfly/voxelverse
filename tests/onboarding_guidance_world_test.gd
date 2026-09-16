extends SceneTree
## Real sphere, existing gameplay actions and shared SaveGameService; isolated by runner.
const Progress = preload("res://core/onboarding_progress.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const Layout = preload("res://ui/hud_layout.gd")
var failures: Array[String] = []
var saves: Node
var flow: Node
var state: Node
var guide: Node

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	saves = root.get_node("SaveGameService")
	flow = root.get_node("SessionFlow")
	state = root.get_node("GameState")
	await process_frame
	guide = flow.get_node("FirstSteps")
	saves.session_managed = true
	saves.autosave_enabled = false
	if "--guidance-restart" in OS.get_cmdline_user_args():
		var expected := Atomic.parse_dictionary(FileAccess.get_file_as_string("user://guidance_restart.json"))
		_expect(saves.select_slot(expected.path), "Fresh process failed to load guide save: " + saves.last_error)
		_expect(_normalized(saves.guidance.export_state()) == _normalized(expected.guide) and state.campaign.data.id == expected.campaign_id, "Fresh process changed milestones or campaign identity.")
		_expect(saves.guidance.current_step().is_empty() and saves.save_now(), "Completed guide reappeared or failed to save after restart.")
		if failures.is_empty(): print("GUIDANCE_FRESH_PROCESS_PASSED")
		await _finish()
		return
	var path: String = saves.create_slot("Guidance world", 15838, Cube.MODE)
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	flow.load_game(path)
	await _until(func() -> bool: return not flow.loading, 50000)
	if current_scene == null or current_scene.scene_file_path != flow.SPHERE_SCENE or not current_scene.world_initialized:
		_expect(false, "Sphere did not load: " + saves.last_error)
		await _finish()
		return
	saves.autosave_enabled = false
	var scene: Node3D = current_scene
	var player: CharacterBody3D = scene.player
	var home: Node = scene.get_node("Nest/HomeGroup")
	var tribe: Node = scene.get_node("Nest/Tribe")
	await _until(func() -> bool: return home.can_use_panel() and player.is_on_floor(), 10000)
	player.set_process(false)
	player.set_physics_process(false)
	saves.guidance.reset(true)
	guide._process(0)
	print("GUIDANCE_STAGE loaded")
	var start: Dictionary = player.location().duplicate(true)
	# Full/invalid attempts and restoration after loading must not count as eating.
	player.current_hunger = player.maximum_hunger
	_expect(not player.consume_food("plant", 20) and not saves.guidance.done("eat"), "Full stomach counted as food.")
	player.current_hunger = 25
	_expect(not player.consume_food("invalid", 20) and not saves.guidance.done("eat"), "Unsuitable food counted.")
	player.restore_hunger(0)
	_expect(not saves.guidance.done("eat"), "Zero restoration counted as food.")
	# The shared finite plant uses restore_hunger, not consume_food.
	await _until(func() -> bool: return not scene.population.plants.is_empty(), 10000)
	var ate: bool = false
	for plant: Node3D in scene.population.plants.values().duplicate():
		if not is_instance_valid(plant): continue
		var point: Vector3 = plant.global_position + Space.frame(plant, plant.global_position) * Vector3(1, 0.1, 0)
		player.global_position = point
		plant.interact(player)
		if saves.guidance.done("eat"):
			ate = true
			break
	_expect(ate and player.current_hunger > 25, "Actual plant interaction did not count as food.")
	player.place(start)
	print("GUIDANCE_STAGE food")
	await _water(scene)
	player.place(start)
	await _until(func() -> bool: return Space.ground_ready(player, player.global_position), 25000)
	print("GUIDANCE_STAGE water")
	# Home save failure rolls back and is never observed as an achievement.
	saves.save_path = "user://missing_guidance_parent/save.json"
	_expect(not home.establish_home().ok, "Injected home write failure unexpectedly succeeded.")
	guide._observe_world()
	_expect(not saves.guidance.done("home"), "Failed home save counted.")
	saves.save_path = path
	var result: Dictionary = home.establish_home()
	_expect(result.ok, "Home could not be established: " + str(result))
	guide._observe_world()
	_expect(saves.guidance.done("home"), "Saved home not recognised.")
	if not result.ok: await _finish(); return
	_expect(home.panel.open_panel() and paused, "Home panel did not open.")
	saves.save_path = "user://missing_guidance_parent/save.json"
	_expect(not home.issue_order("follow").ok and not saves.guidance.done("command"), "Failed paused order counted.")
	saves.save_path = path
	_expect(home.issue_order("follow").ok and saves.guidance.done("command"), "Successful paused order did not count.")
	home.panel.close_panel()
	# A chosen chapter and partial movement survive a real reload and independent copy.
	saves.guidance.select_chapter("tribe")
	player.guidance_action.emit("move", 1.5)
	_expect(saves.save_now(), "Partial guide save failed.")
	var progress: Dictionary = saves.guidance.export_state()
	_expect(saves.load_now() and saves.guidance.export_state() == progress, "Partial guide changed on reload.")
	await _frames(4)
	player.set_process(false)
	player.set_physics_process(false)
	print("GUIDANCE_STAGE home")
	await _ui(player)
	print("GUIDANCE_STAGE ui")
	# Scanner, death and pause cannot accidentally record player evidence.
	saves.guidance.reset(true)
	flow.toggle_pause()
	player.guidance_action.emit("jump", 1)
	_expect(not saves.guidance.done("jump"), "Pause recorded a jump.")
	flow.resume()
	player.is_dead = true
	player.guidance_action.emit("jump", 1)
	guide._process(0)
	_expect(not saves.guidance.done("jump") and not guide.visible, "Death advanced/displayed guide.")
	player.is_dead = false
	player.inspection_mode_enabled = true
	guide._process(0)
	_expect(not guide.visible, "Guide overlaps scanner.")
	player.inspection_mode_enabled = false
	saves.guidance.import_state(progress)
	_expect(home.issue_order("home").ok, "Could not recall companions.")
	await _until(func() -> bool: return tribe.blockers().is_empty(), 15000)
	_expect(tribe.panel.open_confirmation(), "Tribe confirmation did not open.")
	guide._observe_world()
	_expect(int(state.current_phase) == 0 and not saves.guidance.done("tribe"), "Guide or preview confirmed a transition.")
	tribe.panel.cancel.pressed.emit()
	_expect(int(state.current_phase) == 0 and not saves.guidance.done("tribe"), "Cancelled transition counted.")
	_expect(tribe.panel.open_confirmation(), "Could not reopen confirmation.")
	tribe.panel.confirm.pressed.emit()
	await _until(func() -> bool: return tribe.is_active(), 15000)
	guide._observe_world()
	_expect(tribe.is_active() and saves.guidance.done("tribe") and saves.guidance.current_step().is_empty(), "Confirmed tribe did not finish guide.")
	_expect(not saves.guidance.done("jump"), "Transition fabricated optional exercise completion.")
	_expect(saves.save_now(), "Final guide save failed: " + saves.last_error)
	var expected := {"path": path, "guide": saves.guidance.export_state(), "campaign_id": state.campaign.data.id}
	_expect(Atomic.write("user://guidance_restart.json", expected, false) == OK, "Restart fixture write failed.")
	flow.return_to_title()
	await scene_changed
	guide._process(0)
	_expect(not guide.visible, "Guide leaked into title.")
	var copy_path: String = saves.duplicate_slot(path)
	_expect(not copy_path.is_empty() and _normalized(saves._read_save(copy_path).onboarding) == _normalized(expected.guide), "Independent copy lost expanded milestones.")
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/onboarding_guidance_world_test.gd", "--", "--guidance-restart"], output, true)
	_expect(code == 0 and str(output).contains("GUIDANCE_FRESH_PROCESS_PASSED"), "Fresh process failed: " + str(output))
	if code == 0: print("GUIDANCE_FRESH_PROCESS_VERIFIED")
	if failures.is_empty(): print("GUIDANCE_WORLD_PASSED: real food/water, home/order rollback, pause, chapters, responsive bilingual UI, copies, confirmed handoff and fresh process.")
	await _finish()

func _water(scene: Node3D) -> void:
	var surface: RefCounted = scene.terrain.surface
	var start: Dictionary = scene.player.location()
	scene.player.current_thirst = 20
	scene.player._try_drink_water(scene.player.global_position)
	_expect(not saves.guidance.done("drink"), "Dry land counted as drinking.")
	var lake: Dictionary = {}
	for distance in [64.0, 128.0, 256.0, 512.0, 1024.0]:
		for index in range(16):
			var angle: float = index * TAU / 16.0
			var place: Dictionary = scene.adapter.offset(start, scene.adapter.frame_at(start) * Vector3(cos(angle) * distance, 0, sin(angle) * distance))
			var candidate: Dictionary = surface._feature(Cube.direction(place.face, place.u, place.v))
			if not candidate.is_empty(): lake = candidate; break
			for cached: Dictionary in surface._lakes.values():
				if not cached.is_empty(): lake = cached; break
			if not lake.is_empty(): break
		if not lake.is_empty(): break
	_expect(not lake.is_empty(), "No freshwater found.")
	if lake.is_empty(): return
	var address: Dictionary = Cube.from_cartesian(surface.body.id, [lake.direction[0] * surface.body.radius, lake.direction[1] * surface.body.radius, lake.direction[2] * surface.body.radius], surface.body.radius)
	address.height = lake.level - 0.5
	scene.player.place(address)
	await _until(func() -> bool: return Space.ground_ready(scene.player, scene.player.global_position), 25000)
	scene.player.current_thirst = scene.player.maximum_thirst
	scene.player._try_drink_water(scene.player.global_position)
	_expect(not saves.guidance.done("drink"), "Full thirst bar counted as drinking.")
	scene.player.current_thirst = 20
	scene.player._try_drink_water(scene.player.global_position)
	_expect(saves.guidance.done("drink") and scene.player.current_thirst > 20, "Reachable freshwater did not count.")

func _ui(player: Node) -> void:
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	var snapshot: Dictionary = player.export_runtime_state()
	var progression: Dictionary = root.get_node("ProgressionService").export_state()
	for locale: String in ["de", "en"]:
		root.get_node("LocaleManager")._apply(locale)
		for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(800, 600)]:
			root.size = dimensions
			for scale_value in [1.0, 1.5]:
				root.get_node("DisplaySettings").ui_scale = scale_value
				for step in Progress.STEPS:
					saves.guidance.reset(true)
					var chapter_id: String = saves.guidance.chapter_for(step)
					saves.guidance.select_chapter(chapter_id)
					for previous: String in Progress.CHAPTER_STEPS[chapter_id]:
						if previous == step: break
						saves.guidance.record(previous, 100)
					# Freeze world observation while inspecting each incomplete chapter.
					guide._observe_timer = 100
					for frame in range(5):
						guide._process(0)
						await process_frame
					var rect := _physical(guide._panel)
					_expect(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(rect) and rect.end.y <= dimensions.y - 100, "Guide clipped/overlaps footer: " + str([locale, dimensions, scale_value, step, rect]))
					_expect(not guide._hint.text.contains("GUIDE_") and not guide._title.text.contains("GUIDE_"), "Untranslated guide.")
				flow.toggle_pause()
				flow._show_first_steps()
				await _frames(6)
				var help: Control = flow._content.get_node("GuidanceHelp")
				_expect(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(_physical(help)), "Guide help clipped: " + str([locale, dimensions, scale_value, _physical(help)]))
				_expect(flow._content.find_child("GuideChapter_home", true, false) != null, "Chapter picker missing.")
				flow.resume()
	root.size = Vector2i(1280, 720)
	root.get_node("DisplaySettings").ui_scale = 1.0
	root.get_node("LocaleManager")._apply("de")
	saves.guidance.reset(true)
	flow.toggle_pause()
	flow._show_first_steps()
	flow._content.find_child("GuideChapter_home", true, false).pressed.emit()
	_expect(not flow.pause_open and saves.guidance.data.focus == "home", "Chapter button did not resume selected help.")
	flow.toggle_pause()
	flow._show_first_steps()
	flow._content.find_child("SkipFirstSteps", true, false).pressed.emit()
	var skipped: Dictionary = saves.guidance.export_state()
	guide._observe_world()
	player.guidance_action.emit("jump", 1)
	_expect(saves.guidance.export_state() == skipped and not flow.pause_open, "Turn-off button did not silence guide.")
	flow.toggle_pause()
	flow._show_first_steps()
	flow._content.find_child("RestartFirstSteps", true, false).pressed.emit()
	_expect(saves.guidance.current_step() == "look" and not flow.pause_open, "Restart button did not resume basics.")
	var future := {"schema": 99, "future": ["keep"]}
	saves.guidance.import_state(future)
	flow.toggle_pause()
	flow._show_first_steps()
	_expect(flow._content.find_child("RestartFirstSteps", true, false).disabled and flow._content.find_child("GuideChapter_home", true, false).disabled, "Future guide exposed enabled edits.")
	guide.restart()
	guide.select_chapter("home")
	_expect(saves.guidance.export_state() == future, "UI overwrote a future guide.")
	_expect(guide._help_scroll.follow_focus, "Help cannot follow keyboard focus.")
	root.get_node("LocaleManager")._apply("en")
	await _frames(3)
	_expect(flow._content.find_child("RestartFirstSteps", true, false).text == "Restart introduction", "Open help did not follow language switch.")
	flow.resume()
	root.get_node("LocaleManager")._apply("de")
	# Live bindings, including secondary mouse keys, appear without reopening help.
	var old: Array[InputEvent] = InputMap.action_get_events("primary_action")
	InputMap.action_erase_events("primary_action")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Z
	InputMap.action_add_event("primary_action", key)
	_expect(guide.hint("eat").begins_with("Z"), "Guide ignored rebinding.")
	InputMap.action_erase_events("primary_action")
	for event in old: InputMap.action_add_event("primary_action", event)
	_expect(player.export_runtime_state() == snapshot and root.get_node("ProgressionService").export_state() == progression, "Reading guidance changed player/rewards.")

func _normalized(value: Dictionary) -> Dictionary:
	return Atomic.parse_dictionary(Atomic.stringify(value))

func _physical(control: Control) -> Rect2:
	var transform := control.get_global_transform_with_canvas()
	var factor := Layout.canvas_scale(control)
	return Rect2(transform.origin / factor, control.size * transform.get_scale() / factor)

func _until(predicate: Callable, milliseconds: int) -> void:
	var start: int = Time.get_ticks_msec()
	while not predicate.call() and Time.get_ticks_msec() - start < milliseconds: await process_frame

func _frames(count: int) -> void:
	for i in range(count): await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _finish() -> void:
	paused = false
	for failure in failures: push_error(failure)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
