extends "res://tests/tribal_age_test.gd"
const Lab = preload("res://world/tribe/lab/husbandry_lab.gd")
const H = preload("res://world/tribe/village_husbandry.gd")

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	Engine.time_scale = 3.0
	root.size = Vector2i(1280, 800)
	var lab: Node3D = load("res://world/tribe/lab/husbandry_lab.tscn").instantiate()
	scene = lab
	root.add_child(scene)
	current_scene = scene
	await _until(func() -> bool: return lab.ready_for_entry, 300)
	tribe = lab.tribe
	home = lab.home
	player = lab.player
	if not lab.ready_for_entry:
		_expect(false, "Husbandry UI fixture failed to initialize.")
		await _cleanup()
		_finish()
		return
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _until(func() -> bool: return lab.ready_for_work and tribe.is_active() and tribe.navigation.is_ready(), 1600)
	if not lab.ready_for_work:
		_expect(false, "Husbandry UI fixture failed to enter tribal age.")
		await _cleanup()
		_finish()
		return
	# This bounded UI fixture supplies D1/D2 only. The separate sphere acceptance
	# proves real generated species and taming; no production is invented here.
	tribe.body().d3_lab_sources.traits = Lab.D1.suitability("eggs")
	tribe.select_all()
	tribe.panel._tabs.current_tab = 2
	tribe.panel.refresh()
	await _frames(3)
	await _click(tribe.panel._buttons.laying_site)
	_expect(tribe.placement == "laying_site", "Laying-site button did not start placement.")
	await _world_click(tribe.camera.unproject_position(Vector3(0, 100.06, 7)), MOUSE_BUTTON_RIGHT)
	_expect(tribe.village().project.get("kind") == "laying_site", "Laying-site click did not reserve construction.")
	await _until(func() -> bool: return not tribe.village().husbandry.pens.is_empty() and tribe.navigation.is_ready(), 2000)
	if tribe.village().husbandry.pens.is_empty():
		_expect(false, "Laying-site material transport did not complete: " + tribe.status)
		await _cleanup()
		_finish()
		return
	tribe.issue_order("wait")
	var p: Dictionary = tribe.village().husbandry.pens[0]
	var place_id: String = p.id
	_expect(p.kind == "laying_site" and H.site_recipe(p) == H.Production.EGGS, "Completed place became a milk pen.")
	var before: Dictionary = tribe.village().duplicate(true)
	var path: String = saves.save_path
	saves.save_path = "user://no-egg-ui-parent/blocked.json"
	_expect(not tribe.husbandry.change_site(place_id) and tribe.village() == before, "Failed place conversion did not roll back.")
	saves.save_path = path
	_expect(tribe.husbandry.change_site(place_id), "Empty laying place could not become a milk place.")
	tribe.panel.refresh()
	_expect(tribe.panel._animals.item_count == 0, "Milk place offered the egg-only fixture animal.")
	_expect(tribe.husbandry.change_site(place_id), "Paid milk place could not be reused for eggs.")
	tribe.panel.refresh()
	_expect(tribe.panel._animals.item_count == 1 and tribe.panel._pens.get_item_text(0).contains("Legestelle"), "Laying-place selector did not update its candidates.")
	await _click(tribe.panel._bind_animal)
	_expect(tribe.village().husbandry.pens[0].animal_id == Lab.ANIMAL, "Shared assignment button rejected the laying animal.")
	before = tribe.village().duplicate(true)
	_expect(not tribe.husbandry.change_site(place_id) and tribe.village() == before, "Occupied place changed recipe.")
	tribe.panel.refresh()
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(800, 600)]:
		root.size = dimensions
		await _frames(5)
		tribe.panel._layout()
		await _frames(3)
		var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
		_expect(screen.encloses(_physical_rect(tribe.panel._hud)), "Egg commands escaped viewport: " + str(dimensions))
		for control: Control in [tribe.panel._buttons.eggs, tribe.panel._bind_animal, tribe.panel._release_animal]:
			tribe.panel._hud_scroll.ensure_control_visible(control)
			await _frames(3)
			_expect(_physical_rect(tribe.panel._hud).has_point(_physical_rect(control).get_center()), "Egg action cannot be reached by scrolling: " + str(dimensions))
	_expect(tribe.panel._stock.text.contains("Eier"), "Egg stock is absent from the shared HUD.")
	_expect(saves.save_now(), "Laying place did not save: " + saves.last_error)
	if failures.is_empty(): print("EGG_HUSBANDRY_UI_PASSED: actual buttons, build, assignment, reuse, rollback and small-screen layout.")
	await _cleanup()
	_finish()
