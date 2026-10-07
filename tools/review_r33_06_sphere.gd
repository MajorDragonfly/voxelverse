extends "res://tests/tribal_guidance_world_test.gd"
## Ordinary title/playtest entry into the real sphere. No fabricated work/stock.
const Equipment = preload("res://world/tribe/resident_equipment_model.gd")
const Details = preload("res://ui/tribe/resident_details_panel.gd")
var observations: Array = []
var checks: int = 0
func _expect(ok: bool, message: String) -> void:
	checks += 1
	super._expect(ok, message)
func _run() -> void:
	preload("res://tests/r32_19_support.gd").install_copy()
	flow = root.get_node("SessionFlow")
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	saves.autosave_enabled = false
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	root.get_node("LocaleManager")._apply("de")
	Engine.time_scale = 3.0
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture")+1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
		RenderingServer.render_loop_enabled = false
	# Hold regular scene resources without claiming a cold-start benchmark.
	var prepared: PackedScene = load(flow.SPHERE_SCENE)
	_expect(prepared != null, "Regular spherical scene cannot be prepared")
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	_expect(Playtest.start(flow), "Regular spherical playtest entry rejected")
	await _until(func() -> bool: return not flow.loading, 180000)
	await _until(func() -> bool:
		var host: Node = current_scene.get_node_or_null("Nest/Tribe")
		return host != null and host.panel.confirmation_open, 90000)
	tribe = current_scene.get_node_or_null("Nest/Tribe")
	if tribe == null or not tribe.panel.confirmation_open:
		_expect(false, "Regular sphere did not reach explicit tribal confirmation")
		await _done(); return
	await _click(tribe.panel.confirm)
	if not await _wait_for_tribe("resident review"):
		await _done(); return
	var detail: PanelContainer = tribe.panel._resident_detail
	_expect(detail.get_script() == Details, "Owner detail attachment missing in sphere")
	if detail.get_script() != Details: await _done(); return
	await _click(tribe.panel._residents.get_child(1))
	var identity: String = tribe.selected[0]
	var point: Vector3 = tribe.actors[identity].global_position
	await _world_click(tribe.camera.unproject_position(point + Space.up(tribe,point)), MOUSE_BUTTON_LEFT)
	_expect(tribe.selected == [identity] and detail.observation.id == identity, "Actual sphere world/list identities disagree")
	_expect(Equipment.items(tribe.village()).is_empty() and detail.observation.personal_equipment.tool.is_empty(),"Regular village received free personal gear")
	for resource: String in ["wood","stone"]:
		await _click(tribe.panel._buttons[resource])
		await _until(func() -> bool: return int(tribe.village().stock[resource]) >= (6 if resource=="wood" else 4),90000)
		_expect(int(tribe.village().stock[resource]) >= (6 if resource=="wood" else 4),"Regular physical work did not supply "+resource)
		_expect(tribe.issue_order("move",tribe.anchor()),"Regular material return rejected")
		await _until(func() -> bool: return tribe.member_record(identity).cargo=="" and Equipment.Economy.Home.distance(tribe.member_record(identity).position,tribe.village().anchor)<2.0,25000)
		await _click(tribe.panel._buttons.wait)
	await _click(tribe.panel._buttons.tool)
	await _until(func() -> bool: return int(tribe.village().tools)==1,25000)
	_expect(tribe.village().tools==1 and Equipment.items(tribe.village()).is_empty(),"Regular shared-tool production fabricated personal gear")
	tribe.panel.refresh()
	await _click(detail.craft_button)
	var item_id: String=str(detail.last_result.get("item_id",""))
	_expect(detail.last_result.get("ok",false) and Equipment.free_items(tribe.village(),"tool").size()==1,"Regular paid personal manufacture failed")
	if not detail.last_result.get("ok",false): await _done(); return
	await _click(detail.equip_buttons.tool)
	_expect(Equipment.owned(tribe.village(),identity,"tool").get("id")==item_id and Equipment.free_items(tribe.village(),"tool").is_empty(),"Regular equip control lost or duplicated the exact item")
	var inventory: Dictionary=Equipment.inventory_snapshot(tribe.village())
	tribe.set_physics_process(false)
	for language: String in ["de","en"]:
		root.get_node("LocaleManager")._apply(language)
		tribe.panel.refresh()
		await _frames(4)
		tribe.panel._scroll.ensure_control_visible(detail.resident_name)
		await _frames(3)
		await _capture("sphere-equipment-"+language+"-top")
		tribe.panel._scroll.ensure_control_visible(detail.equipment)
		await _frames(3)
		await _capture("sphere-equipment-"+language+"-bottom")
	var data: Dictionary = tribe.village().duplicate(true)
	var cursor: float = state.campaign.data.elapsed_seconds
	flow.toggle_pause()
	await _frames(20)
	_expect(tribe.village() == data and state.campaign.data.elapsed_seconds == cursor, "Pause advanced resident needs/cargo or clock")
	_expect(saves.save_now(), "Actual sphere resident snapshot failed to save")
	var path: String = saves.save_path
	observations.append({"body":state.active_body_id,"campaign":state.campaign.data.id,"clock":cursor,"resident":detail.observation.duplicate(true)})
	flow.return_to_title()
	await scene_changed
	await flow.load_game(path)
	# SessionFlow requests the scene asynchronously. Its await is not a world
	# readiness signal; use the existing bounded campaign-load watchdog.
	await _until(func() -> bool:
		return not flow.loading and current_scene != null and current_scene.get_node_or_null("Nest/Tribe") != null, 150000)
	tribe = current_scene.get_node_or_null("Nest/Tribe")
	if tribe == null:
		_expect(false, "Saved spherical village did not restore")
		await _done(); return
	if not await _wait_for_tribe("resident reload"):
		await _done(); return
	tribe.set_physics_process(false)
	tribe.select_member(identity)
	detail = tribe.panel._resident_detail
	_expect(Equipment.inventory_snapshot(tribe.village())==inventory and detail.observation.personal_equipment.tool.get("id")==item_id,"Regular title/save/load changed paid personal ownership")
	var member: Dictionary = tribe.member_record(identity)
	_expect(detail.observation.id == identity and detail.observation.name == member.name and detail.observation.cargo == member.cargo and absf(detail.observation.water-member.hydration)<0.1, "Sphere reload retained pre-load member or work")
	await _capture("sphere-equipment-reloaded")
	await _done()
func _capture(label: String) -> void:
	if capture_dir.is_empty(): return
	RenderingServer.render_loop_enabled = true
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_expect(not image.is_empty() and image.save_png(capture_dir.path_join(label+".png")) == OK, "Sphere capture failed")
	RenderingServer.render_loop_enabled = false
func _done() -> void:
	print(JSON.stringify({"test":"r33_06_spherical_equipment_review","passed":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"target_pc_accepted":false}))
	RenderingServer.render_loop_enabled = true
	await preload("res://core/runtime_shutdown.gd").finish(self,0 if failures.is_empty() else 1)
