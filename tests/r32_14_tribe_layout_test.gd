extends "res://tests/tribal_age_test.gd"
## Supplemental real-controls fixture matrix, including all three actual UI scales.
var checks: int = 0
var cases: Array[Dictionary] = []

func _expect(condition: bool, message: String) -> void:
	checks += 1
	super._expect(condition, message)

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture")+1]
		capture_on_demand = true
		RenderingServer.render_loop_enabled = false
	state.start_world_with_seed(15838)
	await process_frame
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	await _frames(25)
	_expect(home.establish_home().ok, "Layout fixture cannot establish group")
	await _frames(15)
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _until(func() -> bool: return tribe.is_active() and tribe.navigation.is_ready(), 1200)
	if not tribe.is_active():
		_expect(false, "Cannot activate layout village")
		await _cleanup()
		await _finish()
		return
	tribe.set_physics_process(false)
	state.set_process(false)
	var panel: CanvasLayer = tribe.panel
	var map: CanvasLayer = get_first_node_in_group(&"minimap_hud")
	# Include all supported resource categories; numeric length is a real HUD constraint.
	var data: Dictionary = tribe.village()
	for resource: String in data.stock:
		data.stock[resource] = 12345
	for dimensions: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for scale: float in [1.0, 1.25, 1.5]:
			for language: String in ["de", "en"]:
				var start := failures.size()
				root.size = dimensions
				root.content_scale_factor = scale
				root.get_node("DisplaySettings").ui_scale = scale
				root.get_node("LocaleManager")._apply(language)
				tribe.selected.clear()
				panel._collapsed = false
				panel._tabs.current_tab = 0
				panel.refresh()
				map._update_snapshot()
				await _frames(8)
				var context := "%dx%d/%d/%s" % [dimensions.x, dimensions.y, roundi(scale*100), language]
				var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
				var resources := _physical_rect(panel._top_bar)
				var commands := _physical_rect(panel._hud)
				_expect(screen.grow(1).encloses(resources), "Expanded resource strip outside viewport: " + context + str(resources))
				_expect(not resources.intersects(commands), "Expanded resource strip covers actions: " + context)
				_expect(not resources.intersects(_physical_rect(map._panel)), "Resource strip covers minimap: " + context)
				_expect(resources.encloses(_physical_rect(panel._speed_selector)), "Speed selector clipped by resources: " + context)
				await _capture("tribe-layout-" + context.replace("/", "-"))
				for tab in range(panel._tabs.get_tab_count()):
					panel._tabs.current_tab = tab
					await _frames(6)
					_expect(screen.grow(1).encloses(_physical_rect(panel._hud)), "Tab HUD outside viewport: " + context + "/" + str(tab))
					_expect(not _physical_rect(panel._hud).intersects(_physical_rect(map._panel)), "Tab covers minimap: " + context + "/" + str(tab))
					for button: Button in panel._tabs.get_current_tab_control().find_children("*", "Button", true, false):
						if not button.is_visible_in_tree(): continue
						await _show_in_scroll(panel._scroll, button)
						if not _physical_rect(panel._scroll).grow(1).encloses(_physical_rect(button)):
							print("R32_14_CLIPPED: ", context, " ", button.get_path(), " text=", button.text, " rect=", _physical_rect(button), " scroll=", _physical_rect(panel._scroll))
							await _capture("clipped-" + context.replace("/", "-") + "-" + str(tab))
					panel._scroll.scroll_vertical = 0
				cases.append({"case": context, "passed": failures.size() == start, "resource_rect": str(resources)})
	print("R32_14_TRIBE_LAYOUT: ", JSON.stringify({"checks": checks, "cases": cases, "failures": failures}))
	await _cleanup()
	await _finish()
