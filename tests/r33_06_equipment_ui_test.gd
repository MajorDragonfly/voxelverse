extends "res://tests/tribal_age_test.gd"
## Actual input/controller/work/SaveGameService in the labelled flat fixture.
const Equipment = preload("res://world/tribe/resident_equipment_model.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const EXPECTED: String = "user://r33_06_expected.json"
var checks: int = 0
var detail: PanelContainer
var first: String
var second: String
var checksums: Array = []
func _expect(ok: bool, message: String) -> void:
	checks += 1
	super._expect(ok,message)
func _request(action: String, extra: Dictionary = {}) -> Dictionary:
	return {"village_id":tribe.village().id,"resident_id":first,"action":action}.merged(extra)
func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	if "--r33-cold" in OS.get_cmdline_user_args():
		await _cold(); return
	var args:=OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir=args[args.find("--capture")+1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
		capture_on_demand=true
		RenderingServer.render_loop_enabled=false
	root.get_node("LocaleManager")._apply("de")
	Engine.time_scale = 3.0
	state.start_world_with_seed(15838)
	await process_frame
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	await _frames(25)
	_expect(home.establish_home().ok,"UI fixture home establishment failed")
	await _frames(15)
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _until(func() -> bool: return tribe.is_active() and tribe.navigation.is_ready(),1200)
	_expect(tribe.is_active() and tribe.navigation.is_ready(),"Village did not activate")
	if not tribe.is_active(): await _done(); return
	first = tribe.village().members[1].id
	second = tribe.village().members[2].id
	detail = tribe.panel._resident_detail
	_expect(detail.command_handler.is_valid(),"Equipment owner host patch absent")
	if not detail.command_handler.is_valid(): await _done(); return
	await _click(tribe.panel._residents.get_child(1))
	_expect(detail.observation.id == first and detail.observation.personal_equipment.tool.is_empty(),"Detail did not open actual empty resident")
	await _gather("wood",14)
	await _gather("stone",8)
	await _click(tribe.panel._buttons.tool)
	await _until(func() -> bool: return int(tribe.village().tools) == 1,900)
	_expect(tribe.village().tools == 1 and Equipment.items(tribe.village()).is_empty(),"Shared tool unlock fabricated personal equipment")
	# Reuse the real paid workplace controller and physical construction path.
	var point: Vector3 = tribe.navigation.snap(tribe.anchor()+Vector3(-8,0,0))
	_expect(tribe.issue_order("fiberbed",point),"Paid fiberbed construction rejected: "+tribe.status)
	await _until(func() -> bool: return tribe.village().economy.stations.has("fiberbed"),1800)
	_expect(tribe.village().economy.stations.has("fiberbed"),"Physical fiberbed construction never completed")
	if not tribe.village().economy.stations.has("fiberbed"): await _done(); return
	await _gather("fiber",5)
	await _at_storage(first)
	await _at_storage(second)
	tribe.select_member(first)
	tribe.set_physics_process(false)
	tribe.panel.refresh()
	var stock: Dictionary = tribe.village().stock.duplicate(true)
	await _choose(detail.craft_choice,0)
	await _click(detail.craft_button)
	_expect(detail.last_result.get("ok",false) and Equipment.items(tribe.village()).size()==1,"Craft button did not create paid stone tool")
	var tool: String = str(detail.last_result.get("item_id",""))
	_expect(tribe.village().stock.wood==stock.wood-3 and tribe.village().stock.stone==stock.stone-2,"UI craft did not debit exact material stock")
	await _click(detail.equip_buttons.tool)
	_expect(Equipment.owned(tribe.village(),first,"tool").get("id")==tool and Equipment.free_items(tribe.village(),"tool").is_empty(),"Equip button duplicated or lost actual item")
	tribe.select_member(second)
	_expect(detail.observation.id==second and detail.observation.personal_equipment.tool.is_empty() and detail.equip_buttons.tool.disabled,"Second resident displayed/claimed first resident's tool")
	var before: Dictionary = tribe.village().duplicate(true)
	var competing: Dictionary = _request("equip",{"slot":"tool","item_id":tool})
	competing.resident_id=second
	var claim_result: Dictionary=tribe.resident_equipment_command(competing)
	_expect(not claim_result.ok and claim_result.code=="EQUIPMENT_CLAIMED" and tribe.village()==before,"Concurrent exact item ID was claimed twice")
	tribe.select_member(first)
	await _choose(detail.craft_choice,1)
	stock=tribe.village().stock.duplicate(true)
	await _click(detail.craft_button)
	var wooden: String = str(detail.last_result.get("item_id",""))
	_expect(detail.last_result.get("ok",false) and tribe.village().stock.wood==stock.wood-2 and tribe.village().stock.fiber==stock.fiber-1,"Actual recipe dropdown did not select/pay wooden tool")
	await _click(detail.equip_buttons.tool)
	_expect(Equipment.owned(tribe.village(),first,"tool").get("id")==wooden and Equipment.items(tribe.village())[tool].owner_id=="","Change button did not return same original tool")
	await _choose(detail.craft_choice,2)
	await _click(detail.craft_button)
	var tunic: String = str(detail.last_result.get("item_id",""))
	_expect(detail.last_result.get("ok",false) and tribe.village().stock.fiber==0,"Clothing crafting button did not spend its fibers")
	await _click(detail.equip_buttons.clothing)
	_expect(Equipment.owned(tribe.village(),first,"clothing").get("id")==tunic,"Detail clothing is not actual personal possession")
	await _click(detail.return_buttons.tool)
	_expect(Equipment.items(tribe.village())[wooden].owner_id=="","Return button did not return same wooden tool")
	tribe.select_member(second)
	# Return the second resident to storage before the real stock exchange.
	tribe.set_physics_process(true)
	await _at_storage(second)
	tribe.set_physics_process(false)
	await _click(detail.equip_buttons.tool)
	_expect(Equipment.owned(tribe.village(),second,"tool").get("id")==tool,"Second resident could not equip returned free stock")
	tribe.select_member(first)
	var save_path: String = saves.save_path
	var disk: String = FileAccess.get_file_as_string(save_path)
	var blocked: FileAccess = FileAccess.open("user://r33-blocked-parent",FileAccess.WRITE)
	blocked.store_string("not a directory"); blocked.close()
	saves.save_path="user://r33-blocked-parent/save.json"
	before=tribe.village().duplicate(true)
	await _click(detail.return_buttons.clothing)
	_expect(not detail.last_result.get("ok",true) and detail.last_result.get("code")=="EQUIPMENT_SAVE_FAILED" and tribe.village()==before,"Failed return changed owner/materials/IDs")
	await _click(detail.equip_buttons.tool)
	_expect(not detail.last_result.get("ok",true) and tribe.village()==before,"Failed equip/swap did not roll back both owners")
	await _choose(detail.craft_choice,0)
	await _click(detail.craft_button)
	_expect(not detail.last_result.get("ok",true) and tribe.village()==before,"Failed manufacture leaked a paid item/sequence/materials")
	_expect(FileAccess.get_file_as_string(save_path)==disk,"Failed write replaced accepted save bytes")
	saves.save_path=save_path
	await _click(detail.equip_buttons.tool)
	_expect(detail.last_result.get("ok",false) and Equipment.owned(tribe.village(),first,"tool").get("id")==wooden,"Recovered successful equip reused stale failed state")
	var request: Dictionary = _request("return",{"slot":"tool"})
	tribe.select_member(second)
	before=tribe.village().duplicate(true)
	_expect(not tribe.resident_equipment_command(request).ok and tribe.village()==before,"Stale selected resident request accepted")
	tribe.select_member(first)
	paused=true
	_expect(not tribe.resident_equipment_command(request).ok and tribe.village()==before,"Paused equipment command mutated stock")
	paused=false
	await _matrix()
	_expect(saves.save_now(),"Cannot save personal equipment")
	var expected: Dictionary = {"first":first,"second":second,"items":Equipment.items(tribe.village()).duplicate(true),"stock":tribe.village().stock.duplicate(true),"village":tribe.village().duplicate(true)}
	_expect(Atomic.write(EXPECTED,expected,false)==OK,"Cannot store cold-process expectation")
	# Unknown contract/recipe must block load and backup fallback before imports.
	var accepted: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(save_path))
	var future: Dictionary = accepted.duplicate(true)
	var body_id: String = state.active_body_id
	future.game_state.campaign.bodies[body_id].tribe[Equipment.FIELD].schema=2
	_expect(saves._has_unsupported_contract(future),"Future version not registered in central SaveService guard")
	future.game_state.campaign.bodies[body_id].tribe[Equipment.FIELD].schema=1
	future.game_state.campaign.bodies[body_id].tribe[Equipment.FIELD].items[tool].recipe_revision=2
	_expect(saves._has_unsupported_contract(future),"Future item recipe not guarded centrally")
	var future_path: String="user://r33-future-equipment.json"
	_expect(Atomic.write(future_path,future,false)==OK and Atomic.write(future_path+".bak",accepted,false)==OK,"Future/compatible backup fixture failed")
	saves.save_path=future_path
	var future_bytes: String=FileAccess.get_file_as_string(future_path)
	_expect(not saves.load_now() and FileAccess.get_file_as_string(future_path)==future_bytes,"Future item recipe fell back to older backup or rewrote bytes")
	_expect(not saves.save_now() and FileAccess.get_file_as_string(future_path)==future_bytes,"Save overwrote a guarded future equipment file")
	saves.save_path=save_path
	# Actor destruction/reconstruction does not own personal inventory.
	var old: Dictionary = detail.observation.personal_equipment.duplicate(true)
	tribe.set_physics_process(true)
	_expect(saves.load_now(),"Reload failed")
	await _until(func() -> bool: return tribe.is_active() and tribe.navigation.is_ready(),1200)
	tribe.set_physics_process(false)
	tribe.select_member(first)
	_expect(Equipment.inventory_snapshot(tribe.village())==Equipment.inventory_snapshot(expected.village) and detail.observation.personal_equipment==old,"Load/actor reconstruction lost actual ownership")
	await _cleanup()
	var output: Array=[]
	var code: int=OS.execute(OS.get_executable_path(),PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script",get_script().resource_path,"--","--r33-cold"]),output,true)
	print("R33_COLD_OUTPUT:",output)
	_expect(code==0 and str(output).contains("R33_06_COLD_PASSED") and not str(output).contains("SCRIPT ERROR") and not str(output).contains("ERROR:"),"Fresh Godot process did not restore personal items")
	print(JSON.stringify({"test":"r33_06_equipment_ui","checks":checks,"passed":failures.is_empty(),"failures":failures,"scope":"flat fixture; actual input/work/construction/SaveService"}))
	await preload("res://core/runtime_shutdown.gd").finish(self,0 if failures.is_empty() else 1)

func _gather(resource: String, amount: int) -> void:
	print("R33_EQUIPMENT_STAGE: gather "+resource)
	await _click(tribe.panel._buttons[resource])
	await _until(func() -> bool: return int(tribe.village().stock[resource])>=amount,3000)
	_expect(int(tribe.village().stock[resource])>=amount,"Real work did not supply materials: "+resource)
	# Stop further pickups with the real return command; a paused wait order
	# intentionally retains cargo and cannot be treated as a free delivery.
	_expect(tribe.issue_order("move",tribe.anchor()),"Gather return command rejected")
	await _until(func() -> bool: return tribe.member_record(first).cargo=="" and Model.Home.distance(tribe.member_record(first).position,tribe.village().anchor)<2.0,900)
	_expect(tribe.member_record(first).cargo=="","Gather return did not deliver conserved cargo")
	await _click(tribe.panel._buttons.wait)

func _at_storage(identity: String) -> void:
	tribe.select_member(identity)
	_expect(tribe.issue_order("move",tribe.anchor()),"Warehouse move rejected")
	await _until(func() -> bool: return Model.Home.distance(tribe.member_record(identity).position,tribe.village().anchor)<2.0 and tribe.member_record(identity).cargo=="",900)
	_expect(Model.Home.distance(tribe.member_record(identity).position,tribe.village().anchor)<2.0,"Resident never reached exchange point")
	await _click(tribe.panel._buttons.wait)

func _choose(choice: OptionButton, index: int) -> void:
	await _show_in_scroll(tribe.panel._scroll,choice)
	var pixel:Vector2=choice.get_global_transform_with_canvas()*(choice.size*0.5)*float(root.size.x)/root.get_visible_rect().size.x
	Input.warp_mouse(pixel)
	var motion:=InputEventMouseMotion.new()
	motion.position=pixel;motion.global_position=pixel
	motion.relative=Vector2(1,0);motion.window_id=root.get_window_id()
	Input.parse_input_event(motion);Input.flush_buffered_events()
	await process_frame
	_expect(_physical_rect(tribe.panel._scroll).has_point(pixel) and root.gui_get_hovered_control()==choice,"Recipe mouse input is outside or covered")
	var popup:PopupMenu=choice.get_popup()
	for down:bool in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		event.window_id=popup.get_window_id() if not down and not popup.is_embedded() else root.get_window_id()
		event.position=Vector2(root.position)+pixel-Vector2(popup.position) if not down and not popup.is_embedded() else pixel
		event.global_position=event.position
		Input.parse_input_event(event);Input.flush_buffered_events()
		await process_frame
	_expect(popup.visible,"Recipe dropdown did not open")
	_expect(popup.get_theme_font_size("font_size")==choice.get_theme_font_size("font_size"),"Recipe popup ignored UI font scaling")
	var focus:int=popup.get_focused_item()
	tribe.panel.refresh()
	_expect(popup.visible and popup.get_focused_item()==focus,"Live HUD refresh reset the opened recipe menu")
	for step in range(choice.item_count+1):
		if popup.get_focused_item()==index:break
		await _menu_key(popup,KEY_DOWN)
	await _menu_key(popup,KEY_ENTER)
	await _frames(3)
	_expect(choice.selected==index and not popup.visible,"Recipe keyboard choice failed")

func _menu_key(popup:PopupMenu,key:int)->void:
	for down:bool in [true,false]:
		var event:=InputEventKey.new()
		event.keycode=key;event.physical_keycode=key;event.pressed=down
		event.window_id=popup.get_window_id()
		Input.parse_input_event(event);Input.flush_buffered_events()
		await process_frame
	await process_frame

func _matrix() -> void:
	var frozen: Dictionary=tribe.village().duplicate(true)
	root.content_scale_size=Vector2i.ZERO
	for dimensions: Vector2i in [Vector2i(800,600),Vector2i(1280,720),Vector2i(1920,1080)]:
		for scale: float in [1.0,1.25,1.5]:
			for language: String in ["de","en"]:
				root.size=dimensions
				root.get_node("DisplaySettings").ui_scale=scale
				root.get_node("LocaleManager")._apply(language)
				tribe.panel.refresh()
				await _frames(4)
				_expect(tribe.panel._feedback.result.text==preload("res://core/localization/ui_text.gd").text("EQUIPMENT_SAVED"),"Equipment result retained the previous locale")
				var context: String="%d-%d-%s" % [dimensions.x,roundi(scale*100),language]
				_expect(detail.observation.id==first and not detail.observation.personal_equipment.tool.is_empty() and not detail.observation.personal_equipment.clothing.is_empty(),"Locale/layout changed ownership: "+context)
				_expect(not detail.equipment.text.contains("EQUIPMENT_") and not detail.craft_button.text.contains("EQUIPMENT_"),"Missing equipment translation: "+context)
				await _show_in_scroll(tribe.panel._scroll,detail.equipment)
				_expect(_physical_rect(tribe.panel._scroll).grow(1).encloses(_physical_rect(detail.equipment)),"Personal possession text clipped: "+context)
				await _capture("equipment-"+context+"-owned")
				await _choose(detail.craft_choice,2) # actual popup input in every locale/scale profile
				for control: Control in [detail.craft_choice,detail.craft_cost,detail.craft_button,detail.equip_buttons.tool,detail.return_buttons.tool,detail.equip_buttons.clothing,detail.return_buttons.clothing]:
					await _show_in_scroll(tribe.panel._scroll,control)
					_expect(_physical_rect(tribe.panel._scroll).grow(1).encloses(_physical_rect(control)),"Equipment control clipped: "+str(control.name)+"/"+context)
				await _show_in_scroll(tribe.panel._scroll,detail.craft_button)
				await _capture("equipment-"+context+"-craft")
				var selected: Array=tribe.selected.duplicate()
				await _world_click(detail.craft_cost.get_global_transform_with_canvas()*Vector2(5,5),MOUSE_BUTTON_LEFT)
				_expect(tribe.selected==selected,"Equipment click leaked into world: "+context)
	_expect(tribe.village()==frozen,"Language/UI matrix mutated equipment or materials")

func _cold() -> void:
	var expected: Dictionary=Atomic.parse_dictionary(FileAccess.get_file_as_string(EXPECTED))
	_expect(not expected.is_empty() and saves.load_now(),"Cold process cannot load accepted equipment save")
	_build_fixture()
	tribe=scene.get_node("Nest/Tribe")
	await _until(func() -> bool: return tribe.is_active() and tribe.navigation.is_ready(),1200)
	tribe.set_physics_process(false)
	_expect(tribe.is_active(),"Cold village did not activate")
	if tribe.is_active():
		tribe.select_member(expected.first)
		detail=tribe.panel._resident_detail
		_expect(Equipment.inventory_snapshot(tribe.village())==Equipment.inventory_snapshot(expected.village) and tribe.village().stock==expected.stock,"Cold restart changed material ledger or item owners/IDs")
		_expect(detail.observation.personal_equipment==Equipment.snapshot(tribe.village(),expected.first),"Cold detail kept a stale actor/member possession")
	if failures.is_empty(): print("R33_06_COLD_PASSED")
	await _done()

func _done() -> void:
	if is_instance_valid(scene): await _cleanup()
	RenderingServer.render_loop_enabled=true
	print(JSON.stringify({"test":"r33_06_equipment_ui","checks":checks,"passed":failures.is_empty(),"failures":failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self,0 if failures.is_empty() else 1)
