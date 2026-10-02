extends "res://tests/tribal_playtest_test.gd"
## Public spherical playtest entry; actual GUI picking, modal ownership and campaign clock.
const Layout = preload("res://ui/hud_layout.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const Fingerprint = preload("res://core/campaign/spherical_migration.gd")
var tribe: Node
var output := ""
var checks: int = 0
var cases: Array[Dictionary] = []

func _expect(ok: bool, message: String) -> void:
	checks += 1
	super._expect(ok, message)

func _run() -> void:
	flow = root.get_node("SessionFlow")
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	saves.autosave_enabled = false
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		output = args[args.find("--capture")+1]
		DirAccess.make_dir_recursive_absolute(output)
	# Live physics/input throughout; paint actual world only at capture boundaries.
	RenderingServer.render_loop_enabled = false
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	_expect(Playtest.start(flow), "Public spherical test entry rejected")
	await _until(func() -> bool: return not flow.loading, 180000)
	await _until(func() -> bool:
		var t: Node = current_scene.get_node_or_null("Nest/Tribe")
		return t != null and t.panel.confirmation_open, 90000)
	tribe = current_scene.get_node_or_null("Nest/Tribe")
	if tribe == null or not tribe.panel.confirmation_open:
		_expect(false, "Sphere did not reach ordinary confirmation: " + JSON.stringify(flow.startup_diagnostics()))
		await _done()
		return
	await _click(tribe.panel.cancel)
	_expect(state.current_phase == 0 and not paused, "Canceled handoff changed phase")
	# Freeze only the existing campaign clock for fixed-light layout comparisons.
	# The real player remains physics-enabled, so book/menu entry guards are exercised.
	state.set_process(false)
	await _matrix("creature")
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _until(func() -> bool: return tribe.is_active() and tribe.navigation.is_ready(), 90000)
	_expect(tribe.is_active() and state.current_phase == 1, "Confirmed handoff did not activate the tribe")
	if not tribe.is_active(): await _done(); return
	tribe.set_physics_process(false)
	await _matrix("tribe")
	if "--layout-only" in args:
		await _done()
		return
	# One real order and pickup/arrival; no inventory fabricated for production evidence.
	root.size = Vector2i(1280, 720)
	root.content_scale_factor = 1.0
	root.get_node("DisplaySettings").ui_scale = 1.0
	root.get_node("LocaleManager")._apply("en")
	tribe.panel._collapsed = false
	tribe.select_all()
	tribe.panel.refresh()
	state.set_process(true)
	tribe.set_physics_process(true)
	await _click(tribe.panel._buttons.wood)
	_expect(tribe.village().members.all(func(m: Dictionary) -> bool: return m.order == "wood"), "World gather click failed")
	for speed: int in [1, 2, 3]:
		await _mouse_speed(speed-1)
		_expect(float(state.campaign.data.time_scale) == float(speed) and Engine.time_scale == 1.0, "Tempo lacks one authoritative campaign factor")
		await _frames(10)
		var weather: Node = get_first_node_in_group(&"campaign_weather")
		_expect(weather != null and is_equal_approx(float(weather.snapshot().elapsed_seconds), float(state.campaign.data.elapsed_seconds)), "Weather uses a different campaign time")
	await _until(func() -> bool: return tribe.village().members.any(func(m: Dictionary) -> bool: return m.cargo == "wood"), 25000)
	_expect(tribe.village().members.any(func(m: Dictionary) -> bool: return m.cargo == "wood"), "Real gathering never picked up wood")
	await _click(tribe.panel._speed_pause)
	var clock: float = state.campaign.data.elapsed_seconds
	var frozen: Dictionary = tribe.village().duplicate(true)
	await _frames(12)
	_expect(paused and state.campaign.data.elapsed_seconds == clock and tribe.village() == frozen, "Pause advances actual cargo/work/clock")
	await _picture("tribe-running-transport-paused")
	await _click(tribe.panel._speed_pause)
	await _until(func() -> bool: return int(tribe.village().stock.wood) > 0, 25000)
	_expect(int(tribe.village().stock.wood) > 0, "Resume does not deliver real wood")
	await _click(tribe.panel._buttons.wait)
	await _picture("tribe-delivered-stock")
	# A conservative preview fixture relocates finite goods; it is separate from the delivery.
	tribe.set_physics_process(false)
	tribe.village().tools = 1
	for kind: String in ["wood", "stone"]:
		var amount: int = mini(16, tribe.village().deposits[kind].remaining)
		tribe.village().deposits[kind].remaining -= amount
		tribe.village().stock[kind] += amount
	tribe.panel.refresh()
	await _click(tribe.panel._buttons.hut)
	_expect(tribe.placement == "hut" and not tribe.panel._top_bar.visible, "Preview entry did not expose the build surface")
	var candidate := Vector3.INF
	for site: Variant in tribe.village().sites:
		var world: Vector3 = Space.resolve(tribe, site)
		var hit: Dictionary = tribe.ground_hit(tribe.camera.unproject_position(world))
		if not hit.is_empty() and tribe.placement_check("hut", hit.position).ok:
			candidate = hit.position
			break
	_expect(candidate.is_finite(), "No reachable preview site in the real sphere")
	if candidate.is_finite():
		await _pointer(tribe.camera.unproject_position(candidate))
		await _frames(8)
		_expect(tribe.building_preview.visible, "Real preview was not visible")
		await _picture("tribe-hut-preview")
		await _key(KEY_ESCAPE)
		_expect(tribe.placement.is_empty() and not flow.pause_open, "Esc did not cancel preview before opening pause")
	# Atomic save/load must retain selected speed, cursor and goods without replay.
	await _click(tribe.panel._speed_pause)
	_expect(saves.save_now(), "World save failed: " + saves.last_error)
	var saved: Dictionary = state.export_state()
	var path: String = saves.save_path
	flow.return_to_title()
	await scene_changed
	_expect(not paused and not flow.pause_open, "Title retained tactical pause")
	state.set_process(false)
	await flow.load_game(path)
	await _until(func() -> bool: return not flow.loading, 180000)
	tribe = current_scene.get_node_or_null("Nest/Tribe")
	await _until(func() -> bool: return tribe != null and tribe.is_active(), 90000)
	_expect(float(state.campaign.data.time_scale) == 3.0, "Cold world reload lost 3x speed")
	_expect(state.campaign.data.elapsed_seconds == saved.campaign.elapsed_seconds, "Cold reload produced offline time")
	if tribe != null:
		tribe.set_physics_process(false)
		_expect(Fingerprint.fingerprint(tribe.village().stock) == Fingerprint.fingerprint(saved.campaign.bodies[state.active_body_id].tribe.stock), "Reload duplicated or lost stored goods")
		await _picture("tribe-cold-reload")
	await _done()

func _matrix(phase: String) -> void:
	var player: Node = current_scene.player
	var map: CanvasLayer = get_first_node_in_group(&"minimap_hud")
	var book: CanvasLayer = player.find_child("PlayerProgression", true, false)
	var journal: CanvasLayer = get_first_node_in_group(&"discovery_journal")
	for dimensions: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for scale: float in [1.0, 1.25, 1.5]:
			for locale: String in ["de", "en"]:
				var start := failures.size()
				root.size = dimensions
				root.content_scale_factor = scale
				root.get_node("DisplaySettings").ui_scale = scale
				root.get_node("LocaleManager")._apply(locale)
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				tribe.panel._collapsed = false
				tribe.selected.clear()
				tribe.panel._tabs.current_tab = 0
				tribe.panel._scroll.scroll_vertical = 0
				tribe.panel.refresh()
				map._update_snapshot()
				await _frames(8)
				var name := "%s-%s-%dx%d-%d" % [phase, locale, dimensions.x, dimensions.y, roundi(scale*100)]
				var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
				var occupied: Array[Rect2] = [_physical(map._panel)]
				if phase == "tribe":
					occupied.append(_physical(tribe.panel._hud))
					occupied.append(_physical(tribe.panel._top_bar))
					await _click(tribe.panel._residents.get_child(0))
					_expect(tribe.selected.size() == 1, "Resident mouse selection failed: " + name)
					await _free_world_click(name)
				else:
					occupied.append(_physical(player.find_child("CompactVitals", true, false)))
					occupied.append(_physical(player.find_child("ProgressionDock", true, false)))
					occupied.append(_physical(tribe.panel.entry))
					var home: Node = get_first_node_in_group(&"home_group_controller")
					if home != null and home.panel._hud.is_visible_in_tree(): occupied.append(_physical(home.panel._hud))
					var steps: Control = flow.find_child("FirstStepsCard", true, false)
					if steps != null and steps.is_visible_in_tree(): occupied.append(_physical(steps))
				for rect: Rect2 in occupied: _expect(screen.grow(1).encloses(rect), "HUD outside screen: " + name + str(rect))
				var free: float = _connected_free(screen, occupied)
				if dimensions == Vector2i(1920,1080) and scale == 1.0:
					_expect(free >= 0.70, "Less than 70% contiguous free gameplay area: " + name + " / " + str(free))
				await _picture(name)
				var show_modal := dimensions == Vector2i(1280,720) and scale == 1.25 and locale == "en"
				# The actual modal input path is exercised in every case, not only method calls.
				await _key(KEY_K)
				_expect(book.visible and paused and not map.visible, "Book/modal ownership failed: " + name)
				if show_modal: await _picture(phase+"-development-book")
				await _key(KEY_ESCAPE)
				_expect(not book.visible and not paused, "Book Escape failed: " + name)
				await _key(KEY_J)
				_expect(journal.is_open and paused, "Journal entry failed: " + name)
				if show_modal: await _picture(phase+"-discovery-book")
				await _key(KEY_ESCAPE)
				_expect(not journal.is_open and not paused, "Journal Escape failed: " + name)
				await _click(map._atlas_button)
				_expect(map.atlas_window.is_open and paused, "Map click failed: " + name)
				if show_modal: await _picture(phase+"-world-map")
				await _key(KEY_ESCAPE)
				_expect(not map.atlas_window.is_open and not paused, "Map Escape failed: " + name)
				await _key(KEY_ESCAPE)
				_expect(flow.pause_open and paused, "Esc pause entry failed: " + name)
				if show_modal: await _picture(phase+"-escape-menu")
				var before: Dictionary = state.export_state()
				await _world_click(Vector2(10, 10), MOUSE_BUTTON_RIGHT)
				_expect(state.export_state() == before, "Modal pointer leaked into the world: " + name)
				await _key(KEY_ESCAPE)
				_expect(not paused and not flow.pause_open, "Esc return failed: " + name)
				cases.append({"case": name, "passed": failures.size() == start, "clock": state.campaign.data.elapsed_seconds, "connected_free_fraction": free})

func _free_world_click(context: String) -> void:
	if tribe.selected.is_empty(): return
	var member: Dictionary = tribe.member_record(tribe.selected[0])
	var found := false
	var points: Array[Vector2] = []
	for site: Variant in tribe.village().sites:
		points.append(tribe.camera.unproject_position(Space.resolve(tribe, site)))
	for y: float in [0.35,0.45,0.55,0.65]:
		for x: float in [0.25,0.35,0.45,0.55,0.65]:
			points.append(Vector2(root.size)*Vector2(x,y)*Layout.canvas_scale(tribe.panel))
	for point: Vector2 in points:
		var physical := point/Layout.canvas_scale(tribe.panel)
		if not Rect2(Vector2.ZERO,Vector2(root.size)).has_point(physical): continue
		await _pointer(point)
		if root.gui_get_hovered_control() != null: continue
		var hit: Dictionary = tribe.ground_hit(point)
		if hit.is_empty(): continue
		await _world_click(point,MOUSE_BUTTON_RIGHT)
		if member.order == "move":
			found = true
			break
	_expect(found, "Free world right-click cannot issue a move: " + context)
	await _click(tribe.panel._buttons.wait)
	_expect(member.order == "wait", "Actual order button cannot stop selected resident: " + context)

func _physical(control: Control) -> Rect2:
	var rect: Rect2 = control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
	var factor := Layout.canvas_scale(control)
	return Rect2(rect.position/factor, rect.size/factor)

func _connected_free(screen: Rect2, occupied: Array[Rect2]) -> float:
	# Exact rectangle subdivision and four-neighbour flood fill; no sum-of-boxes
	# approximation can mistake several disconnected pockets for free play space.
	var xs: Array[float] = [0.0, screen.size.x]
	var ys: Array[float] = [0.0, screen.size.y]
	for rect: Rect2 in occupied:
		for x: float in [clampf(rect.position.x, 0, screen.size.x), clampf(rect.end.x, 0, screen.size.x)]:
			if not x in xs: xs.append(x)
		for y: float in [clampf(rect.position.y, 0, screen.size.y), clampf(rect.end.y, 0, screen.size.y)]:
			if not y in ys: ys.append(y)
	xs.sort()
	ys.sort()
	var free: Dictionary = {}
	for y in range(ys.size()-1):
		for x in range(xs.size()-1):
			var point := Vector2((xs[x]+xs[x+1])/2, (ys[y]+ys[y+1])/2)
			if not occupied.any(func(rect: Rect2) -> bool: return rect.has_point(point)):
				free[Vector2i(x,y)] = (xs[x+1]-xs[x])*(ys[y+1]-ys[y])
	var best := 0.0
	while not free.is_empty():
		var queue: Array[Vector2i] = [free.keys()[0]]
		var area := 0.0
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			if not free.has(cell): continue
			area += float(free[cell])
			free.erase(cell)
			for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if free.has(cell+direction): queue.append(cell+direction)
		best = maxf(best, area)
	return best/(screen.size.x*screen.size.y)

func _click(button: Button) -> void:
	await _frames(3)
	if tribe != null and tribe.panel._scroll.is_ancestor_of(button):
		var tabs: TabContainer = tribe.panel._tabs
		for i in range(tabs.get_tab_count()):
			if tabs.get_tab_control(i).is_ancestor_of(button) and tabs.current_tab != i:
				var bar: TabBar = tabs.get_tab_bar()
				await _show_in_scroll(bar)
				bar.ensure_tab_visible(i)
				await _frames(3)
				var tab_point: Vector2 = bar.get_global_transform_with_canvas() * bar.get_tab_rect(i).get_center()
				await _pointer(tab_point)
				await _world_click(tab_point, MOUSE_BUTTON_LEFT)
				_expect(tabs.current_tab == i, "Actual tab click did not open action tab")
		await _frames(4)
		await _show_in_scroll(button)
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size*0.5)
	await _pointer(point)
	point = button.get_global_transform_with_canvas() * (button.size*0.5)
	await _pointer(point)
	_expect(button.is_visible_in_tree() and root.gui_get_hovered_control() == button, "Button is covered: " + str(button.name) + " by " + str(root.gui_get_hovered_control()))
	if button.is_visible_in_tree() and root.gui_get_hovered_control() == button:
		await _world_click(point, MOUSE_BUTTON_LEFT)

func _show_in_scroll(control: Control) -> void:
	var scroll: ScrollContainer = tribe.panel._scroll
	scroll.ensure_control_visible(control)
	await _frames(3)
	var window := _physical(scroll)
	var target := _physical(control)
	var factor := window.size.y / maxf(scroll.size.y, 1.0)
	if target.position.y < window.position.y:
		scroll.scroll_vertical -= ceili((window.position.y-target.position.y+4)/factor)
	elif target.end.y > window.end.y:
		scroll.scroll_vertical += ceili((target.end.y-window.end.y+4)/factor)
	await _frames(3)
	_expect(_physical(scroll).grow(1).encloses(_physical(control)), "World HUD action remains clipped: " + str(control.name))

func _mouse_speed(index: int) -> void:
	await _click(tribe.panel._speed_selector)
	var popup: PopupMenu = tribe.panel._speed_selector.get_popup()
	await _frames(2)
	_expect(popup.visible, "Real speed popup did not open")
	if not popup.visible: return
	var box: StyleBox = popup.get_theme_stylebox("panel")
	var top := box.get_content_margin(SIDE_TOP)
	var height := (float(popup.size.y)-top-box.get_content_margin(SIDE_BOTTOM))/popup.item_count
	await _world_click(Vector2(popup.position)+Vector2(float(popup.size.x)/2,top+(index+0.5)*height), MOUSE_BUTTON_LEFT)
	_expect(not popup.visible, "Real speed popup did not close")

func _world_click(point: Vector2, code: int) -> void:
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = code
		event.pressed = down
		root.push_input(event, true)
	await _frames(3)

func _pointer(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	root.push_input(event, true)
	await _frames(2)

func _key(code: int) -> void:
	root.gui_release_focus()
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event, true)
	await _frames(6)
	if code == KEY_ESCAPE and not paused:
		# Book/journal modal leases include their real release/input cooldown.
		# Render-on-demand frames alone do not represent elapsed wall time.
		await create_timer(0.25).timeout

func _frames(count: int) -> void:
	for i in range(count): await process_frame

func _picture(name: String) -> void:
	if output.is_empty(): return
	RenderingServer.render_loop_enabled = true
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.resize(root.size.x, root.size.y)
	image.save_png(output.path_join(name+".png"))
	RenderingServer.render_loop_enabled = false
	print("R32_14_WORLD_PICTURE: ", name)

func _done() -> void:
	RenderingServer.render_loop_enabled = true
	if not output.is_empty():
		var report := FileAccess.open(output.path_join("world-matrix.json"), FileAccess.WRITE)
		report.store_string(JSON.stringify({"checks": checks, "cases": cases, "failures": failures}))
	print("R32_14_WORLD: ", JSON.stringify({"checks": checks, "cases": cases, "failures": failures}))
	await _finish()
