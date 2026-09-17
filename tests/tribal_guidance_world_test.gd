extends "tribal_playtest_test.gd"
## Public sphere entry; tutorial observes real commands, arrivals and construction.
const Space = preload("res://world/surface/gameplay_space.gd")
const Economy = preload("res://world/tribe/village_economy.gd")
const Keys = preload("res://core/input_preferences.gd")
const Copy = preload("res://ui/frontend/guidance_text.gd")
const Layout = preload("res://ui/hud_layout.gd")
var tribe: Node
var guide: Node
var capture_dir := ""

func _run() -> void:
	flow = root.get_node("SessionFlow")
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920, 1080)
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	_expect(Playtest.start(flow), "Cannot start the tutorial sphere test.")
	await _until(func() -> bool:
		var t: Node = current_scene.get_node_or_null("Nest/Tribe")
		return t != null and t.panel.confirmation_open, 90000)
	tribe = current_scene.get_node_or_null("Nest/Tribe")
	if tribe == null or not tribe.panel.confirmation_open:
		_expect(false, "Sphere setup did not reach tribe confirmation.")
		await _finish()
		return
	saves.autosave_enabled = false
	tribe.panel.confirm.pressed.emit()
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 20000)
	if not tribe.is_active():
		_expect(false, "Sphere tribe did not activate.")
		await _finish()
		return
	guide = flow.get_node("FirstSteps")
	await _frames(6)
	_expect(saves.guidance.tribal_step() == "tribe_camera" and saves.guidance.tribal_completed() == 0, "Automatic handoff/selection completed tutorial actions.")
	_expect(tribe.panel._guidance_row.is_visible_in_tree() and not guide.visible, "Guide is missing or overlaps the tribe as a second floating card.")
	await _capture("tutorial-start-de")
	# The hint and the real camera both use the current binding.
	var preferences: RefCounted = root.get_node("DisplaySettings").input_preferences
	var bindings: Dictionary = preferences.bindings.duplicate(true)
	preferences.bindings.move_forward = [KEY_UP, 0]
	preferences.apply_runtime()
	_expect(Copy.hint("tribe_camera").contains(Keys.code_label(KEY_UP)), "Camera hint ignored a remapped key.")
	root.gui_release_focus()
	_press(KEY_UP, true)
	await _until(func() -> bool: return saves.guidance.tribal_done("tribe_camera"), 3000)
	_press(KEY_UP, false)
	_expect(saves.guidance.tribal_done("tribe_camera"), "Actual remapped camera movement did not count.")
	preferences.bindings = bindings
	preferences.apply_runtime()
	_press(KEY_HOME, true)
	_press(KEY_HOME, false)
	await _click(tribe.panel._residents.get_child(1))
	_expect(tribe.selected.size() == 1 and saves.guidance.tribal_done("tribe_single"), "Resident card did not select/record one resident.")
	await _click(tribe.panel.find_child("SelectAll", true, false))
	_expect(tribe.selected.size() == 3 and saves.guidance.tribal_done("tribe_group"), "Group button did not select/record the group.")
	# A rejected order and an atomic save failure leave the exercise incomplete.
	_expect(not tribe.issue_order("hut") and not saves.guidance.tribal_done("tribe_place"), "Building without tools counted as placement.")
	var path: String = saves.save_path
	var blocker := FileAccess.open("user://tutorial-write-blocker", FileAccess.WRITE)
	blocker.store_string("file, not a directory")
	blocker.close()
	saves.save_path = "user://tutorial-write-blocker/save.json"
	_expect(not tribe.issue_order("wood") and not saves.guidance.tribal_done("tribe_order"), "Failed order save completed a tutorial step.")
	saves.save_path = path
	await _click(tribe.panel._buttons.wood)
	_expect(saves.guidance.tribal_done("tribe_order") and not saves.guidance.tribal_done("tribe_delivery"), "Accepted order did not count, or counted a delivery before arrival.")
	# A temporarily unavailable route cannot produce an arrived-goods event.
	var graph: AStar3D = tribe.navigation.graph
	tribe.navigation.graph = AStar3D.new()
	tribe._route_retry = 5.0
	await _frames(12)
	_expect(tribe.village().stock.wood == 0 and not saves.guidance.tribal_done("tribe_delivery"), "Blocked work fabricated a delivery.")
	tribe.navigation.graph = graph
	await _until(func() -> bool: return tribe.village().members.any(func(m: Dictionary) -> bool: return m.cargo == "wood"), 20000)
	_expect(tribe.village().stock.wood == 0 and not saves.guidance.tribal_done("tribe_delivery"), "Pickup/in-transit wood counted as stored goods.")
	await _until(func() -> bool: return tribe.village().stock.wood > 0, 20000)
	_expect(saves.guidance.tribal_done("tribe_delivery"), "Physical delivery did not complete the storage step.")
	tribe.set_physics_process(false)
	await _ui()
	tribe.set_physics_process(true)
	# An empty pantry does not count. Actual consumption after gathering does.
	await _click(tribe.panel._buttons.feed)
	await _frames(12)
	_expect(not saves.guidance.tribal_done("tribe_supply"), "Empty food stores completed supply.")
	await _click(tribe.panel._buttons.food)
	await _until(func() -> bool: return tribe.village().stock.food > 0, 25000)
	await _click(tribe.panel._buttons.feed)
	await _until(func() -> bool: return saves.guidance.tribal_done("tribe_supply"), 15000)
	_expect(saves.guidance.tribal_done("tribe_supply") and tribe.village().meals > 0, "Real eating did not complete supply.")
	# Move a bounded fixture quantity from the finite deposits into storage;
	# crafting, placement, transport and completion still run through real work.
	tribe.set_physics_process(false)
	for resource: String in ["wood", "stone"]:
		tribe.village().deposits[resource].remaining -= 16
		tribe.village().stock[resource] += 16
	_expect(saves.save_now(), "Conserving construction fixture is invalid: " + saves.last_error)
	tribe.panel.refresh()
	await _click(tribe.panel._buttons.tool)
	_expect(not saves.guidance.tribal_done("tribe_tool"), "Starting a tool completed it early.")
	tribe.set_physics_process(true)
	await _until(func() -> bool: return tribe.village().tools > 0, 25000)
	_expect(saves.guidance.tribal_done("tribe_tool"), "Finished tool did not count.")
	tribe.set_physics_process(false)
	await _click(tribe.panel._buttons.forester)
	if tribe.placement != "forester":
		_expect(false, "The forestry action did not start placement: " + tribe.status)
		await _finish()
		return
	var site := Vector3.INF
	for saved_site: Variant in tribe.village().sites:
		var candidate: Vector3 = Space.resolve(tribe, saved_site)
		var hit: Dictionary = tribe.ground_hit(tribe.camera.unproject_position(candidate))
		if not hit.is_empty() and tribe.placement_check("forester", hit.position).ok:
			site = hit.position
			break
	_expect(site.is_finite(), "No reachable station site through the sphere camera ray.")
	if not site.is_finite(): await _finish(); return
	await _pointer(tribe.camera.unproject_position(site))
	_expect(tribe.building_preview.visible and tribe.building_preview.result.get("ok", false) and not saves.guidance.tribal_done("tribe_place"), "Preview counted as placement or is not visible.")
	await _capture("tutorial-placement")
	_press(KEY_ESCAPE, true)
	_press(KEY_ESCAPE, false)
	_expect(tribe.placement.is_empty() and not saves.guidance.tribal_done("tribe_place") and not paused, "Canceled preview counted or opened pause.")
	await _click(tribe.panel._buttons.forester)
	await _pointer(tribe.camera.unproject_position(site))
	saves.save_path = "user://tutorial-write-blocker/save.json"
	await _world_click(tribe.camera.unproject_position(site), MOUSE_BUTTON_RIGHT)
	_expect(not saves.guidance.tribal_done("tribe_place") and tribe.village().project.is_empty(), "Failed placement counted or left a project.")
	saves.save_path = path
	await _world_click(tribe.camera.unproject_position(site), MOUSE_BUTTON_RIGHT)
	_expect(saves.guidance.tribal_done("tribe_place") and not saves.guidance.tribal_done("tribe_finish"), "Confirmed construction did not separate placement and completion.")
	tribe.set_physics_process(true)
	var first_tick: int = Engine.get_physics_frames()
	var started: int = Time.get_ticks_msec()
	# llvmpipe can draw fewer frames than the physics catch-up limit supports.
	# Keep the 45 seconds of actual physics work, with a bounded wall watchdog.
	await _until(func() -> bool:
		return tribe.village().economy.stations.has("forester") or Engine.get_physics_frames() - first_tick >= 45 * Engine.physics_ticks_per_second,
		45000 if capture_dir.is_empty() else 180000)
	print("TRIBAL_TUTORIAL_CONSTRUCTION ", JSON.stringify({"wall_ms": Time.get_ticks_msec() - started,
		"physics_s": float(Engine.get_physics_frames() - first_tick) / Engine.physics_ticks_per_second,
		"project": tribe.village().project, "status": tribe.status,
		"workers": tribe.village().members.map(func(m: Dictionary) -> Dictionary:
			return {"order": m.order, "blocked": m.blocked, "stage": m.stage, "cargo": m.cargo, "work": m.work})}))
	_expect(tribe.village().economy.stations.has("forester") and saves.guidance.tribal_done("tribe_finish"), "Real station construction failed or did not count.")
	if not tribe.village().economy.stations.has("forester"):
		await _capture("tutorial-construction-state")
		await _finish()
		return
	tribe.set_physics_process(false)
	saves.save_path = "user://tutorial-write-blocker/save.json"
	_expect(not tribe.assign_profession("forester") and not saves.guidance.tribal_done("tribe_profession"), "Failed profession save counted.")
	saves.save_path = path
	tribe.panel._jobs.select(Economy.JOBS.keys().find("forester"))
	await _click(tribe.panel._jobs.get_parent().get_child(2))
	_expect(saves.guidance.tribal_done("tribe_profession"), "Assign-profession button did not count.")
	var identity: String = tribe.village().economy.stations.forester.id
	graph = tribe.navigation.graph
	tribe.navigation.graph = AStar3D.new()
	_expect(not tribe.issue_workplace(identity) and not saves.guidance.tribal_done("tribe_workplace"), "Unreachable workplace counted.")
	tribe.navigation.graph = graph
	await _click(tribe.panel._workplaces._rows[identity])
	_expect(saves.guidance.tribal_done("tribe_workplace") and tribe.village().members.all(func(m: Dictionary) -> bool: return m.get("workplace_id", "") == identity), "Real workplace row did not bind residents/complete help.")
	await _frames(6)
	_expect(saves.guidance.tribal_completed() == 11 and not tribe.panel._guidance_row.visible, "Complete tutorial still covers the village.")
	_expect(saves.save_now(), "Cannot save completed sphere guide: " + saves.last_error)
	var completed: Dictionary = saves.guidance.export_state()
	tribe.set_physics_process(true)
	_expect(saves.load_now(), "Cannot reload completed sphere guide.")
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 20000)
	tribe.set_physics_process(false)
	_expect(saves.guidance.export_state() == completed and guide._tribal.tribe == tribe, "Reload lost progress or bound the wrong tribe observer.")
	# Existing saves are quiet until opt-in, then acknowledge the actual tool
	# and finished station. Neither can be required again in a full village.
	var existing: Dictionary = tribe.village().duplicate(true)
	saves.guidance.import_state({"schema": 2, "skipped": true, "progress": {"tribe": 1}})
	await _frames(3)
	_expect(saves.guidance.tribal_completed() == 0 and not tribe.panel._guidance_row.visible, "Migration enabled old-village help without opt-in.")
	flow.toggle_pause()
	flow._show_first_steps()
	flow._content.find_child("GuideChapter_tribe_build", true, false).pressed.emit()
	await _frames(3)
	_expect(saves.guidance.tribal_completed() == 3 and saves.guidance.tribal_done("tribe_tool") and saves.guidance.tribal_done("tribe_place") and saves.guidance.tribal_done("tribe_finish"), "Existing construction prerequisites block opt-in help: " + str({"guidance": saves.guidance.export_state(), "observer_active": guide._tribal.active(), "paused": paused, "tools": tribe.village().tools, "stations": tribe.village().economy.stations.keys()}))
	_expect(not saves.guidance.tribal_done("tribe_delivery") and not saves.guidance.tribal_done("tribe_supply") and tribe.village() == existing, "Reading completed buildings fabricated work or changed the village.")
	saves.guidance.import_state(completed)
	flow.toggle_pause()
	flow._show_first_steps()
	await _frames(6)
	guide._help_scroll.scroll_vertical = roundi(guide._help_scroll.get_v_scroll_bar().max_value)
	await _frames(3)
	await _capture("tutorial-completed")
	flow.resume()
	if failures.is_empty(): print("TRIBAL_GUIDANCE_WORLD_PASSED: 11 real-action milestones, rollback, transport, remapping, bilingual layout, pause, resume and save/load.")
	await _finish()

func _ui() -> void:
	var partial: Dictionary = saves.guidance.export_state()
	var village: Dictionary = tribe.village().duplicate(true)
	for locale: String in ["de", "en"]:
		root.get_node("LocaleManager")._apply(locale)
		for dimensions: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
			root.size = dimensions
			for scaling: float in [1.0, 1.25, 1.5]:
				# The complete 12-case layout matrix runs headless. Native review
				# renders the three representative cases used by the screenshots.
				if not capture_dir.is_empty() and not ((dimensions.y == 1080 and scaling == 1.0) or (locale == "de" and dimensions.y == 720 and scaling == 1.5)): continue
				root.get_node("DisplaySettings").ui_scale = scaling
				await _frames(6)
				var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
				_expect(screen.encloses(_physical(tribe.panel._hud)) and _physical(tribe.panel._hud).encloses(_physical(tribe.panel._guidance_row)), "Tribe guide clipped: " + str([locale, dimensions, scaling, _physical(tribe.panel._hud), _physical(tribe.panel._guidance_row)]))
				_expect(not tribe.panel._guidance_hint.text.contains("GUIDE_") and tribe.panel._guidance_help.text == ("Hilfe" if locale == "de" else "Help"), "Tribe guide did not switch language.")
				if locale == "en" and dimensions.y == 1080 and scaling == 1.0: await _capture("tutorial-work-en")
				await _click(tribe.panel._guidance_help)
				await _frames(6)
				_expect(paused and flow._content.has_node("GuidanceHelp"), "Help link did not open paused chapters.")
				if flow._content.has_node("GuidanceHelp"):
					_expect(screen.encloses(_physical(flow._content.get_node("GuidanceHelp"))), "Tribal chapter help clipped: " + str([locale, dimensions, scaling]))
					_expect(flow._content.find_child("GuideChapter_tribe_build", true, false) != null and flow._content.find_child("GuideChapter_explore", true, false) == null, "Help presents the wrong phase chapters.")
				if locale == "de" and dimensions.y == 720 and scaling == 1.5: await _capture("tutorial-help-720")
				flow.resume()
	root.size = Vector2i(1920, 1080)
	root.get_node("DisplaySettings").ui_scale = 1.0
	root.get_node("LocaleManager")._apply("de")
	flow.toggle_pause()
	flow._show_first_steps()
	flow._content.find_child("SkipFirstSteps", true, false).pressed.emit()
	await _frames(3)
	_expect(not paused and not tribe.panel._guidance_row.visible and saves.guidance.tribal_completed() == 5, "Skip lost progress or retained the prompt.")
	flow.toggle_pause()
	flow._show_first_steps()
	flow._content.find_child("GuideChapter_tribe_work", true, false).pressed.emit()
	_expect(not paused and saves.guidance.tribal_step() == "tribe_supply", "Resume did not choose the next incomplete work step.")
	flow.toggle_pause()
	flow._show_first_steps()
	flow._content.find_child("RestartFirstSteps", true, false).pressed.emit()
	_expect(saves.guidance.tribal_completed() == 0 and saves.guidance.data.progress == partial.progress, "Tribe restart changed creature guide progress.")
	var future := {"schema": 99, "tribal": {"future_step": "preserve"}}
	saves.guidance.import_state(future)
	flow.toggle_pause()
	flow._show_first_steps()
	_expect(flow._content.find_child("RestartFirstSteps", true, false).disabled and flow._content.find_child("GuideChapter_tribe_work", true, false).disabled, "Future guide can be overwritten by help controls.")
	flow.resume()
	_expect(saves.guidance.export_state() == future, "Reading future help changed its data.")
	saves.guidance.import_state(partial)
	_expect(tribe.village() == village, "Help navigation changed village work/inventory.")
	await _frames(6)

func _press(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)

func _physical(control: Control) -> Rect2:
	var transform := control.get_global_transform_with_canvas()
	var factor := Layout.canvas_scale(control)
	return Rect2(transform.origin / factor, control.size * transform.get_scale() / factor)

func _click(button: BaseButton) -> void:
	if tribe.panel._tabs.is_ancestor_of(button):
		var tabs: TabContainer = tribe.panel._tabs
		for index in range(tabs.get_tab_count()):
			if tabs.get_tab_control(index).is_ancestor_of(button) and tabs.current_tab != index:
				tribe.panel._scroll.ensure_control_visible(tabs.get_tab_bar())
				await _frames(3)
				var bar: TabBar = tabs.get_tab_bar()
				bar.ensure_tab_visible(index)
				await _frames(3)
				await _pointer(bar.get_global_transform_with_canvas() * bar.get_tab_rect(index).get_center())
				# A completed action can replace the hint and resize the HUD while
				# the pointer is moving. Click the current rect, not a stale point.
				_mouse_click(bar.get_global_transform_with_canvas() * bar.get_tab_rect(index).get_center(), MOUSE_BUTTON_LEFT)
				await _frames(3)
				_expect(tabs.current_tab == index, "Cannot open the action's tab: " + str({"wanted": index, "actual": tabs.current_tab, "bar": _physical(bar), "scroll": _physical(tribe.panel._scroll), "hover": root.gui_get_hovered_control()}))
				if tabs.current_tab != index: return
	if tribe.panel._scroll.is_ancestor_of(button): tribe.panel._scroll.ensure_control_visible(button)
	if tribe.panel._hud_scroll.is_ancestor_of(button): tribe.panel._hud_scroll.ensure_control_visible(button)
	await _frames(3)
	_expect(button.is_visible_in_tree() and not button.disabled, "Required control is not available: " + str(button.name))
	if not button.is_visible_in_tree() or button.disabled: return
	await _pointer(button.get_global_transform_with_canvas() * (button.size * 0.5))
	_mouse_click(button.get_global_transform_with_canvas() * (button.size * 0.5), MOUSE_BUTTON_LEFT)
	await process_frame

func _world_click(point: Vector2, button: MouseButton) -> void:
	await _pointer(point)
	_mouse_click(point, button)
	await process_frame

func _mouse_click(point: Vector2, button: MouseButton) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func _pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await _frames(3)

func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame

func _capture(label: String) -> void:
	print("TRIBAL_TUTORIAL_STAGE: " + label)
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(capture_dir.path_join(label + ".png"))
	image.resize(960, roundi(image.get_height() * 960.0 / image.get_width()), Image.INTERPOLATE_LANCZOS)
	print("TRIBAL_TUTORIAL_IMAGE:" + label + ":" + Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.8)))

func _expect(condition: bool, message: String) -> void:
	super._expect(condition, message)
	if not condition: print("TRIBAL_TUTORIAL_CHECK_FAILED: " + message)
