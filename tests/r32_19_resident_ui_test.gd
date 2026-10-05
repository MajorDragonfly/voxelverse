extends "res://tests/tribal_age_test.gd"
## Real selection, GUI commands and physics in a clearly labelled flat fixture.
## The owner host patch is required; this is not a sphere or target-PC acceptance.
const Atomic = preload("res://core/persistence/atomic_json.gd")
const COLD_EXPECTED: String = "user://r32_19_resident_expected.json"
const Details = preload("res://ui/tribe/resident_details_panel.gd")
const DetailText = preload("res://core/localization/ui_text.gd")
var checks: int = 0
var observations: Array = []
func _expect(ok: bool, message: String) -> void:
	checks += 1
	super._expect(ok, message)
func _run() -> void:
	preload("res://tests/r32_19_support.gd").install_copy()
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	if "--r32-cold" in OS.get_cmdline_user_args():
		await _cold()
		return
	state.start_world_with_seed(15838)
	await process_frame
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	await _frames(25)
	_expect(home.establish_home().ok, "Cannot establish residents in UI fixture")
	await _frames(15)
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _until(func() -> bool: return tribe.is_active() and tribe.navigation.is_ready(), 1200)
	var detail: PanelContainer = tribe.panel._resident_detail
	_expect(detail.get_script() == Details, "Required owner detail attachment is absent")
	if not tribe.is_active() or detail.get_script() != Details:
		await _cleanup(); _finish(); return
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	await _frames(4)
	var member: Dictionary = tribe.village().members[1]
	var identity: String = member.id
	# Prebuilt-well fixture. Water is produced by the normal simulation; no
	# artificial stock/delivery counter. This does not test well construction.
	tribe.village().tools = 1
	Model.Economy.complete_station(tribe.village(), Model.Economy.station_project(tribe.village(), "well", tribe.village().deposits.water.position))
	_expect(Model.validate(tribe.village(), tribe.body(), state.campaign.data).is_empty(), "Prebuilt well fixture is invalid")
	await _click(tribe.panel._residents.get_child(1))
	_expect(tribe.selected == [identity] and detail.observation.id == identity, "List selection disagrees with canonical detail identity")
	var point: Vector2 = tribe.camera.unproject_position(tribe.actors[identity].global_position + GameplaySpace.up(tribe, tribe.actors[identity].global_position))
	await _world_click(point, MOUSE_BUTTON_LEFT)
	_expect(tribe.selected == [identity] and detail.visible and detail.observation.id == identity, "World click chose a different/multiple resident than the list")
	observations.append({"world_click_point": [point.x,point.y], "selected": tribe.selected.duplicate(), "expected": identity})
	var second_actor: Node3D = tribe.actors[tribe.village().members[2].id]
	await _world_click(tribe.camera.unproject_position(second_actor.global_position + GameplaySpace.up(tribe, second_actor.global_position)), MOUSE_BUTTON_LEFT, true)
	_expect(tribe.selected.size() == 2 and not detail.visible, "Multiple selection fabricated a single-person detail")
	tribe.select_member(identity)
	await _world_click(Vector2(1000,200), MOUSE_BUTTON_LEFT)
	_expect(tribe.selected.is_empty() and not detail.visible, "Empty world click retained a person's detail")
	# Enemy/unknown list identity never resolves through canonical membership.
	tribe.select_member("enemy")
	_expect(tribe.selected.is_empty() and not detail.visible, "Unknown actor selected a resident")
	# A real hostile actor in this explicitly flat fixture, not a member ID alias.
	var enemy: CharacterBody3D = load("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
	enemy.requested_role = "predator"
	enemy.species_seed = 8819
	enemy.individual_seed = 19
	var ray_origin: Vector3 = tribe.camera.project_ray_origin(Vector2(1000,200))
	var ray_direction: Vector3 = tribe.camera.project_ray_normal(Vector2(1000,200))
	enemy.position = ray_origin + ray_direction * ((100.05-ray_origin.y)/ray_direction.y)
	scene.add_child(enemy)
	enemy.set_physics_process(false) # Keep only this fixture target at its observed hit point.
	_expect(enemy.is_in_group("wildlife_predator") and enemy.current_health > 0 and enemy.has_node("CollisionShape3D"), "Hostile-hit fixture is not a live predator")
	tribe.select_member(identity)
	var enemy_point: Vector2 = tribe.camera.unproject_position(enemy.global_position + GameplaySpace.up(tribe,enemy.global_position))
	await _world_click(enemy_point, MOUSE_BUTTON_LEFT)
	_expect(tribe.selected.is_empty() and not detail.visible, "Hostile world hit retained or fabricated a resident detail")
	observations.append({"hostile_world_hit": {"point":[enemy_point.x,enemy_point.y],"role":enemy.ecological_role,"identity":enemy.get_campaign_identity().object_id,"selected":tribe.selected.duplicate()}})
	enemy.queue_free()
	await _frames(3)
	await _click(tribe.panel._residents.get_child(1))
	await _click(tribe.panel._buttons.wood)
	await _until(func() -> bool: return member.cargo == "wood" and detail.observation.cargo == "wood", 650)
	# Native drawing may consume several physics ticks per frame. Capture the
	# observed carrying boundary before the click helper can reach delivery.
	tribe.set_physics_process(false)
	_expect(member.cargo == "wood", "Real resident never picked up wood")
	_expect(detail.observation.cargo == member.cargo and detail.observation.order == member.order, "Periodic refresh did not reflect real work and cargo")
	await _click(tribe.panel._buttons.wait)
	_expect(detail.observation.cargo == "wood" and detail.observation.order == "wait", "Stop erased cargo or obscured order")
	tribe.set_physics_process(true)
	await _click(tribe.panel._buttons.water)
	await _until(func() -> bool: return tribe.village().stock.water > 0, 850)
	_expect(tribe.village().stock.water > 0, "Normal well water never reached the warehouse")
	await _click(tribe.panel._buttons.wait)
	var drinks: int = tribe.village().economy.drinks
	# Controlled thirst in this flat fixture; the subsequent command, walk,
	# stock consumption and display update remain the real domain path.
	member = tribe.member_record(identity)
	member.hydration = 60.0
	tribe.panel.refresh()
	var before_water: float = member.hydration
	await _click(tribe.panel._buttons.drink)
	await _until(func() -> bool: return tribe.village().economy.drinks > drinks, 500)
	await _frames(15)
	member = tribe.member_record(identity)
	observations.append({"drink": {"before": before_water, "actual": member.hydration, "detail": detail.observation.water, "prior_count": drinks, "count": tribe.village().economy.drinks, "order": member.order, "cargo": member.cargo, "selected": tribe.selected.duplicate()}})
	print("R32_DRINK_OBSERVATION:", JSON.stringify(observations[-1]))
	_expect(tribe.village().economy.drinks > drinks, "No actual water consumption occurred")
	_expect(member.hydration > before_water and absf(detail.observation.water - member.hydration) < 0.1, "Real drink was not reflected by periodic detail refresh")
	# Freeze observation boundaries; presentation must never advance production.
	tribe.set_physics_process(false)
	var well_id: String = tribe.village().economy.stations.well.id
	_expect(tribe.issue_workplace(well_id), "Real controller rejected the existing well workplace")
	_expect(detail.observation.workplace_id == well_id and detail.observation.workplace_kind == "well", "Assigned well was not reflected by detail refresh")
	_expect(tribe.issue_order("wait") and detail.observation.workplace_id == well_id, "Stop discarded assigned workplace")
	member = tribe.member_record(identity)
	member.name = "TRIBE_BOOK {count}"
	var literal_name: String = member.name
	var frozen: String = JSON.stringify(tribe.village())
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture")+1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
		RenderingServer.render_loop_enabled = false
		capture_on_demand = true
	for dimensions: Vector2i in ([] if "--quick" in args else [Vector2i(800,600),Vector2i(1280,720),Vector2i(1920,1080)]):
		for scale: float in [1.0,1.25,1.5]:
			for language: String in ["de","en"]:
				root.size = dimensions
				root.get_node("DisplaySettings").ui_scale = scale
				root.get_node("LocaleManager")._apply(language)
				tribe.panel.refresh()
				await _frames(4)
				var context: String = "%s-%s-%s" % [dimensions.x,roundi(scale*100),language]
				_expect(detail.resident_name.text == literal_name and detail.observation.id == identity, "Locale/layout translated or replaced identity: " + context)
				_expect(detail.activity.text.find("TRIBE_") < 0 and detail.health.text.find("RESIDENT_") < 0, "Missing translation: " + context)
				_expect(detail.workplace.text == DetailText.format_text("RESIDENT_WORKPLACE", {"name":DetailText.text("VILLAGE_WORLD_WELL"),"number":1}), "Finished well labelled as construction or wrong workplace: " + context)
				_expect(detail.equipment.text.find(str(tribe.village().tools)) < 0, "Village tools displayed as personal: " + context)
				for label: Label in [detail.resident_name,detail.health,detail.activity,detail.food_text,detail.water_text,detail.cargo,detail.workplace,detail.equipment]:
					await _reveal_detail_label(label,context)
					_expect(_physical_rect(tribe.panel._scroll).grow(1).intersects(_physical_rect(label)), "Detail line unreachable: " + label.name + "/" + context)
				await _reveal_detail_label(detail.resident_name,context)
				await _capture("resident-"+context+"-top")
				await _reveal_detail_label(detail.equipment,context)
				await _capture("resident-"+context+"-bottom")
				var prior: Array = tribe.selected.duplicate()
				await _world_click(detail.equipment.get_global_transform_with_canvas()*Vector2(8,8),MOUSE_BUTTON_LEFT)
				_expect(tribe.selected == prior, "Detail click leaked to world selection: " + context)
	_expect(JSON.stringify(tribe.village()) == frozen, "UI/language inspection mutated canonical village")
	_expect(saves.save_now(), "Resident save failed")
	var old: Dictionary = member
	tribe.set_physics_process(true) # Release this review's own matrix freeze before normal navigation rebuild.
	_expect(saves.load_now(), "Resident load failed")
	await _until(func() -> bool: return tribe.is_active() and tribe.navigation.is_ready(), 1200)
	_expect(tribe.is_active() and tribe.navigation.is_ready(), "Reloaded resident runtime is not ready")
	await _frames(15)
	tribe.set_physics_process(false)
	tribe.select_member(identity)
	member = tribe.member_record(identity)
	_expect(detail.observation.id == identity and detail.observation.name == literal_name and detail.observation.workplace_id == well_id and absf(detail.observation.food - member.hunger) < 0.1 and absf(detail.observation.water - member.hydration) < 0.1, "Reload detail kept old member dictionary or lost workplace")
	print("R32_RELOAD_OBSERVATION:", JSON.stringify({"expected_name":literal_name,"actual_name":member.name,"detail":detail.observation,"canonical_food":member.hunger,"canonical_water":member.hydration}))
	old.name = "obsolete dictionary"
	tribe.panel.refresh()
	_expect(detail.observation.name == literal_name, "Old pre-load dictionary controls current detail")
	_expect(saves.save_now(), "Cannot commit fresh-process resident source")
	_expect(Atomic.write(COLD_EXPECTED, detail.observation, false) == OK, "Cannot store independent cold expectation")
	await _cleanup()
	var cold_output: Array = []
	var cold_args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--r32-cold"])
	var cold_code: int = OS.execute(OS.get_executable_path(), cold_args, cold_output, true)
	print("R32_COLD_OUTPUT:", cold_output)
	_expect(cold_code == 0 and str(cold_output).contains("R32_19_COLD_PASSED") and not str(cold_output).contains("SCRIPT ERROR") and not str(cold_output).contains("ERROR:"), "Fresh-process resident restore failed")
	print(JSON.stringify({"test":"r32_19_resident_ui","checks":checks,"passed":failures.is_empty(),"failures":failures,"observations":observations,"scope":"flat fixture; real controller/input/work/save"}))
	await preload("res://core/runtime_shutdown.gd").finish(self,0 if failures.is_empty() else 1)

func _reveal_detail_label(label: Label, context: String) -> void:
	var scroll: ScrollContainer = tribe.panel._scroll
	scroll.ensure_control_visible(label)
	# Container and scrollbar passes differ without a render backend. Follow
	# current physical geometry with a bounded guard; never accept a clipped line.
	for attempt in range(6):
		await _frames(2)
		var window: Rect2 = _physical_rect(scroll)
		var target: Rect2 = _physical_rect(label)
		if window.grow(1).encloses(target): break
		var scale: float = window.size.y / maxf(scroll.size.y,1.0)
		if target.position.y < window.position.y:
			scroll.scroll_vertical -= ceili((window.position.y-target.position.y+4.0)/scale)
		elif target.end.y > window.end.y:
			scroll.scroll_vertical += ceili((target.end.y-window.end.y+4.0)/scale)
	await _frames(2)
	var window: Rect2 = _physical_rect(scroll).grow(1)
	var target: Rect2 = _physical_rect(label)
	var readable: bool = window.encloses(target) or (target.size.y > window.size.y and window.intersects(target))
	if not readable:
		print("R32_DETAIL_RECT:",JSON.stringify({"case":context,"label":label.name,"scroll_rect":str(window),"label_rect":str(target),"scroll_vertical":scroll.scroll_vertical}))
	_expect(readable,"Detail line remains clipped: "+label.name+"/"+context)

func _cold() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(COLD_EXPECTED))
	_expect(not expected.is_empty() and saves.load_now(), "Cold process cannot load recorded resident")
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	await _until(func() -> bool: return tribe.is_active() and tribe.navigation.is_ready(), 1200)
	_expect(tribe.is_active() and tribe.navigation.is_ready(), "Cold resident runtime did not activate")
	tribe.set_physics_process(false)
	if tribe.is_active():
		tribe.select_member(expected.id)
		var detail: PanelContainer = tribe.panel._resident_detail
		var member: Dictionary = tribe.member_record(expected.id)
		_expect(detail.get_script() == Details and detail.visible and detail.observation.id == expected.id and detail.observation.name == expected.name, "Cold process replaced literal name or identity")
		_expect(absf(detail.observation.food - member.hunger) < 0.1 and absf(detail.observation.water - member.hydration) < 0.1 and detail.observation.order == expected.order and detail.observation.cargo == expected.cargo and detail.observation.workplace_id == expected.workplace_id, "Cold process detail disagrees with restored work/needs/workplace")
		_expect(not detail.observation.personal_equipment_available, "Cold process fabricated equipment")
	if failures.is_empty(): print("R32_19_COLD_PASSED")
	await _cleanup()
	await preload("res://core/runtime_shutdown.gd").finish(self,0 if failures.is_empty() else 1)
