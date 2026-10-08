extends SceneTree
## Actual title -> new spherical campaign -> atlas input -> save/title/cold load.
const Atlas = preload("res://core/map/exploration_atlas.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Source = preload("res://ui/world_map/world_map_source.gd")
const Presentation = preload("res://ui/world_map/atlas_presentation.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const EXPECTED := "user://int30_world_map_expected.json"
class NativeInputWitness extends Node:
	func _input(event: InputEvent) -> void:
		if event is InputEventKey:
			print("INT30_NATIVE_KEY ",JSON.stringify({"logical":event.keycode,"physical":event.physical_keycode,"pressed":event.pressed,"echo":event.echo,"ctrl":event.ctrl_pressed,"shift":event.shift_pressed,"alt":event.alt_pressed}))
var failures: Array[String] = []
var checks: int = 0
var state: Node
var saves: Node
var flow: Node
var map: CanvasLayer
var capture_dir: String = ""
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	flow = root.get_node("SessionFlow")
	saves.autosave_enabled = false
	if DisplayServer.get_name() != "headless":
		var witness := NativeInputWitness.new()
		witness.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(witness)
	var args := OS.get_cmdline_user_args()
	if "--capture" in args: capture_dir = args[args.find("--capture") + 1]; DirAccess.make_dir_recursive_absolute(capture_dir)
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	if "--input-probe" in args:
		await _input_probe()
		await _finish()
		return
	if "--map-restart" in args:
		await _restart()
		await _finish()
		return
	# Public session flow is the production entry; no laboratory/plane substitute.
	flow.new_game("INT30 Kartenbedienung", 15838)
	await _until(func() -> bool: return not flow.loading, 150000)
	_expect(not flow.loading and current_scene.scene_file_path == flow.SPHERE_SCENE, "Regular spherical campaign did not load: " + saves.last_error)
	if flow.loading or current_scene.get("player") == null: await _finish(); return
	saves.autosave_enabled = false
	map = get_first_node_in_group(&"world_map")
	_expect(map != null, "Campaign player has no world map")
	if map == null: await _finish(); return
	map.visibility_changed.connect(func() -> void:
		print("INT30_MAP_VISIBILITY ",JSON.stringify({"visible":map.visible,"open":map.is_open,"paused":paused,"snapshot_body":map.tracker.snapshot.get("address",{}).get("body_id",""),"atlas_body":map.tracker.atlas.data.get("body_id",""),"projection_body":map.projection.local.body_id,"stack":get_stack()})))
	map.tracker.update_exploration()
	var body: Dictionary = state.get_current_body_record()
	var anchor: Dictionary = current_scene.player.location()
	# Four types are valid saved identities; a fifth remote friend must not leak.
	var progression: Node = root.get_node("ProgressionService")
	var region: String = state.campaign.region_id(body.id, Vector2i.ZERO)
	var identity := {"object_id": state.campaign.object_id(region, "map-friend"), "species_id": state.campaign.species_id(body.id, 729), "body_id": body.id, "region_id": region, "habitat_cell": "0:0", "species_seed": 729}
	var ally: Dictionary = progression.get_creature_encounter(identity, "grazer", 144)
	ally.relation = "ally"; ally.trust = 100.0
	_expect(progression._encounters.put(ally), "Cannot establish saved ally fixture")
	for pair in [["long-map-place", "home", "Lang benannter Ort " + "abcdefghij ".repeat(14), true, ""], ["map-friend-habitat", "friend_habitat", "Bekannter Lebensraum", false, ally.object_id], ["map-friend-nest", "friend_nest", "Bekanntes Freundesnest", false, ally.object_id]]:
		_expect(map.tracker.atlas.remember(Source._place(pair[0], pair[2], pair[1], identity.species_id, pair[4], pair[3], anchor)), "Known place fixture rejected")
	var unknown := Cube.from_direction(body.id, [0.0, -1.0, 0.0])
	_expect(not map.tracker.atlas.known(unknown), "Remote test location is already known")
	map.tracker.atlas.remember(Source._place("must-not-leak", "SECRET SPECIES 99 NESTS", "friend_nest", identity.species_id, ally.object_id, false, unknown))
	var before: String = JSON.stringify(map.tracker.atlas.data)
	var progression_before: Dictionary = progression.export_state()
	if DisplayServer.get_name() != "headless":
		_native(["focus",str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE,root.get_window_id()))])
		await create_timer(0.08,true).timeout
	await _key(KEY_M)
	await _until(func() -> bool: return map.is_open,2000)
	_expect(map.is_open and paused, "M did not open and pause the regular campaign atlas")
	if not map.is_open:
		print("INT30_NATIVE_OPEN_STATE ",JSON.stringify({"focused":root.has_focus(),"mouse":Input.mouse_mode,"paused":paused,"snapshot":not map.tracker.snapshot.is_empty(),"problem":map.tracker.problem,"bindings":preload("res://core/input_preferences.gd").binding_label("open_world_map")}))
		await _finish()
		return
	# Foreground atlas QA uses the live campaign sampler and UI. Suppress only
	# the paused 3D backdrop on llvmpipe; it is not a target-PC graphics/FPS run.
	if DisplayServer.get_name() != "headless": root.disable_3d=true
	await _wait_queries()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var canvas_rect: Rect2 = _rect(map._canvas)
		var player_point: Vector2 = canvas_rect.get_center()
		var pixel: Color = root.get_texture().get_image().get_pixelv(Vector2i(player_point))
		_expect(pixel.r > 0.5 and pixel.g > 0.5 and pixel.b > 0.5, "Known place glyph hides the rendered player position dot")
	_expect(map._places.all(func(p: Dictionary) -> bool: return p.id != "must-not-leak"), "Unknown place or population text leaked")
	_expect(map._type_census.counts.get("friend_nest", 0) == 1 and map._type_filter.item_count == 5, "Type counts leaked unknown records or missed known types")
	_expect(not current_scene.player.find_child("PlayerProgression", true, false).open_panel(), "Book modal opened over atlas")
	var center: Vector2 = map.projection.center
	var radius: float = map.range_m
	await _wheel(map._canvas, MOUSE_BUTTON_WHEEL_UP)
	_expect(map.range_m < radius, "Actual canvas wheel failed to zoom")
	await _drag(map._canvas, Vector2(25, 15))
	_expect(map.projection.center != center, "Actual mouse drag failed to pan")
	await _key(KEY_HOME)
	var key_range: float = map.range_m
	await _key(KEY_PLUS)
	_expect(map.range_m < key_range, "Native plus key did not zoom in")
	await _key(KEY_MINUS)
	_expect(is_equal_approx(map.range_m, key_range), "Native minus key did not reverse zoom")
	var player_center: Vector2 = map.projection.center
	await _key(KEY_LEFT)
	_expect(map.projection.center != player_center, "Native arrow key did not pan")
	await _key(KEY_HOME)
	_expect(map.projection.center.distance_to(map.projection.project(anchor)) < 1.0, "Home did not return to the physical player")
	await _click(map._panel.find_child("AtlasExplored", true, false))
	await _wait_queries()
	_expect(map.range_m <= PI * map.projection.radius, "Fit exceeded spherical zoom clamp")
	await _campaign_seam()
	await _matrix()
	# Keyboard ownership must remain with the actual native type dropdown.
	if map._small: await _click(map._info_toggle)
	map._type_filter.grab_focus()
	var filter_center: Vector2 = map.projection.center
	await _key(KEY_LEFT)
	_expect(map.projection.center == filter_center, "Dropdown cursor key panned the atlas")
	# Mouse opens the dropdown; native keyboard chooses a known type.
	await _choose_type(1)
	await _wait_queries()
	_expect(not map._kind.is_empty() and map._places.all(func(p: Dictionary) -> bool: return p.kind == map._kind), "Native dropdown did not apply a known type")
	if map._small: await _click(map._info_toggle)
	await _choose_type(0)
	await _wait_queries()
	_expect(map._kind.is_empty(),"Native dropdown cannot return to all known types")
	await _key(KEY_F, true)
	_expect(map._place_search.has_focus(), "Ctrl+F did not focus search")
	map._place_search.select_all()
	await _type("Lang")
	await _wait_queries()
	_expect(map._places.size() == 1 and map._places[0].id == "long-map-place", "Native typing did not search known places")
	await _click(map._list.get_child(0))
	_expect(map._selected == "long-map-place", "Mouse result click failed to select exact stable ID")
	await _click(map._info_toggle)
	_expect(map._info_scroll.visible and map._info_detail.text.contains("abcdefghij"), "Selected long detail is not reachable")
	for scroll_step in range(64):
		var bar: VScrollBar = map._info_scroll.get_v_scroll_bar()
		if bar.value >= bar.max_value-bar.page-1.0: break
		await _wheel(map._info_scroll,MOUSE_BUTTON_WHEEL_DOWN)
	await _frames(3)
	var detail_bar: VScrollBar = map._info_scroll.get_v_scroll_bar()
	_expect(detail_bar.value >= detail_bar.max_value-detail_bar.page-1.0,"Native detail scrolling cannot reach the last line")
	_expect(map._info_detail.visible_ratio == 1.0 and map._info_detail.max_lines_visible == -1, "Long detail still truncated")
	await _capture("selected-long-detail")
	await _key(KEY_ESCAPE)
	_expect(map.is_open and not map._show_info, "Escape did not leave legend/details without closing atlas")
	await _key(KEY_ESCAPE)
	await _frames(3)
	_expect(not paused and not map.is_open, "Escape did not restore campaign control")
	# Map interaction itself leaves model/progression byte-for-byte unchanged.
	_expect(JSON.stringify(map.tracker.atlas.data) == before and progression.export_state() == progression_before, "Map input generated exploration or progression")
	await _key(KEY_M)
	_expect(map.is_open, "M cannot reopen after mouse/keyboard route")
	await _key(KEY_M)
	await _frames(3)
	_expect(not map.is_open and not paused, "M cannot toggle-close the atlas")
	await _key(KEY_F8)
	await _key(KEY_M)
	_expect(paused and root.get_node("DisplaySettings").is_menu_open() and not map.is_open, "M opened the atlas through the settings modal")
	await _key(KEY_F8)
	_expect(not paused and not root.get_node("DisplaySettings").is_menu_open(), "Settings close did not restore campaign control")
	_expect(saves.save_now(), "Actual campaign save failed: " + saves.last_error)
	var saved: Dictionary = saves._read_save(saves.save_path)
	var expected := {"path": saves.save_path, "body_id": body.id, "atlas": saved.game_state.campaign.bodies[body.id].exploration_atlas}
	_expect(Atomic.write(EXPECTED, expected, false) == OK, "Cannot write restart expectation")
	await _key(KEY_M)
	_expect(map.is_open, "Atlas cannot reopen")
	# Loading and body/record invalidation must release search, fit and pause.
	map._place_search.text = "pending"
	map._place_search.text_changed.emit("pending")
	map.fit_explored()
	map.tracker.invalidate()
	await _frames(3)
	_expect(not map.is_open and not paused and not map._place_query.active and not map._fit_query.active and not map._type_census.active, "Body invalidation retained map work/pause")
	flow.toggle_pause()
	_expect(paused and not map.open_map(), "Map opened through pause modal blocker")
	flow.return_to_title()
	await scene_changed
	_expect(get_nodes_in_group(&"world_map").is_empty() and not paused, "Scene exit leaked atlas nodes or pause")
	if "--ui-only" in args:
		await _finish()
		return
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/int30_world_map_campaign_test.gd", "--", "--map-restart"], output, true)
	print("INT30_WORLD_MAP_RESTART_LOG ", str(output))
	_expect(code == 0 and str(output).contains("INT30_WORLD_MAP_RESTART_OK") and not str(output).contains("ERROR:"), "Actual cold campaign/map restart failed")
	await _finish()
func _input_probe() -> void:
	# Short diagnostic of the existing production panel, no world acceptance.
	root.size=Vector2i(800,600);root.position=Vector2i.ZERO
	root.content_scale_factor=1.5
	root.get_node("DisplaySettings").ui_scale=1.5
	map=preload("res://ui/world_map/world_map_panel.gd").new()
	root.add_child(map)
	await _frames(3)
	map.tracker.set_process(false)
	var a: Dictionary=Cube.address("input-probe",0,0,0)
	map.tracker.atlas.bind(Atlas.create("input-probe",Cube.MODE,10000.0))
	map.tracker.atlas.reveal(a)
	_expect(map.tracker.atlas.remember(Source._place("input-nest","Nest","nest","species","",true,a)),"Probe nest fixture rejected")
	_expect(map.tracker.atlas.remember(Source._place("input-detail","Probe " + "abcdefghij ".repeat(14),"home","species","",true,a)),"Probe detail fixture rejected")
	map.tracker.snapshot={"address":a,"explorers":[a],"body_radius":10000.0,"phase":0,"sample":func(_p: Dictionary) -> Color: return Color.BLACK}
	_expect(map.open_map(),"Probe map cannot open")
	await _frames(5)
	map._info_toggle.pressed.connect(func() -> void: print("INT30_NATIVE_INFO_PRESSED ",map._show_info))
	await _click(map._info_toggle)
	_expect(map._show_info and map._info_scroll.visible,"X11 probe cannot open legend")
	await _click(map._info_toggle)
	_expect(not map._show_info,"X11 probe cannot return from legend")
	await _click(map._places_toggle)
	_expect(map._show_list and map._sidebar.visible,"X11 probe cannot open places")
	await _wait_queries()
	await _click(map._info_toggle)
	print("INT30_PROBE_TYPES ",JSON.stringify({"count":map._type_filter.item_count,"counts":map._type_census.counts,"kind":map._kind,"selected":map._type_filter.selected}))
	map._type_filter.item_selected.connect(func(index: int) -> void:print("INT30_PROBE_TYPE_SELECTED ",index," ",map._kind))
	await _choose_type(1)
	await _wait_queries()
	_expect(not map._kind.is_empty(),"X11 probe cannot choose a known type")
	await _click(map._info_toggle)
	await _choose_type(0)
	await _wait_queries()
	_expect(map._kind.is_empty(),"X11 probe cannot choose all types")
	await _key(KEY_F,true)
	await _type("Probe")
	await _wait_queries()
	_expect(map._places.size()==1,"X11 probe cannot search long detail")
	await _click(map._list.get_child(0))
	_expect(map._selected=="input-detail","X11 probe cannot select exact ID")
	await _click(map._info_toggle)
	for scroll_step in range(64):
		var bar: VScrollBar=map._info_scroll.get_v_scroll_bar()
		if bar.value>=bar.max_value-bar.page-1.0:break
		await _wheel(map._info_scroll,MOUSE_BUTTON_WHEEL_DOWN)
	var bar: VScrollBar=map._info_scroll.get_v_scroll_bar()
	_expect(bar.value>=bar.max_value-bar.page-1.0,"X11 probe cannot scroll to full detail end")
	await _key(KEY_ESCAPE)
	await _key(KEY_M)
	await _frames(3)
	_expect(not map.is_open and not paused,"X11 probe cannot restore title input")
	var text_entry := LineEdit.new()
	text_entry.size=Vector2(200,44)
	root.add_child(text_entry)
	text_entry.grab_focus()
	await _key(KEY_M)
	_expect(not map.is_open and text_entry.text=="m","Closed map stole M from native text entry")
	text_entry.queue_free()
	await _frames(3)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await _key(KEY_M)
	await _until(func() -> bool:return map.is_open,2000)
	_expect(map.is_open and paused,"X11 probe cannot open map from captured gameplay input")
	await _key(KEY_M)
	await _until(func() -> bool:return not map.is_open and not paused,2000)
	_expect(not map.is_open and not paused,"X11 probe cannot close captured-input map")
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	map.queue_free()
	await _frames(3)
func _campaign_seam() -> void:
	# Deterministic saved fog on the real campaign map, without moving the
	# player/camera or asking the exploration tracker to discover anything.
	var original: Dictionary = map.tracker.atlas.data
	var seam: Dictionary = Atlas.create(original.body_id, original.mode, original.radius)
	_expect(map.tracker.atlas.bind(seam), "Cannot bind campaign seam fixture")
	map.terrain.reset()
	var visits: Array[Dictionary] = []
	for side: int in [-1,1]:
		var longitude: float = side * (PI - 64.0 / original.radius)
		var visit: Dictionary = Cube.from_direction(original.body_id,[sin(longitude),0.0,cos(longitude)])
		visits.append(visit)
		map.tracker.atlas.reveal(visit)
		map.tracker.atlas.remember(Source._place("seam-%d" % side,"Naht %d" % side,"home","species","",true,visit))
	map._refresh_places()
	map.fit_explored()
	await _wait_queries()
	_expect(map.range_m < 256.0, "Campaign seam fit selected a planetary rectangle")
	for visit: Dictionary in visits:
		var delta: Vector2 = map.projection.project(visit)-map.projection.center
		_expect(absf(delta.x) < map.range_m and absf(delta.y) < map.range_m, "Campaign fitted viewport lost a seam visit")
	await _until(func() -> bool: return map.terrain.completed and not map._request_pending,10000)
	print("INT30_SEAM_RASTER ",JSON.stringify({"coverage":map.terrain.coverage(),"completed":map.terrain.completed,"last_samples":map.terrain.last_samples,"last_usec":map.terrain.last_usec,"samples_total":map.terrain.samples_total,"pending":map._request_pending}))
	_expect(map.terrain.completed and not map._request_pending,"Campaign seam raster did not complete")
	await _capture("campaign-spherical-seam")
	_expect(map.tracker.atlas.bind(original), "Cannot restore original campaign atlas")
	map.terrain.reset()
	map._refresh_places()
	map.focus_player()
	await _wait_queries()
func _restart() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(EXPECTED))
	flow.world_started.connect(flow.toggle_pause, CONNECT_ONE_SHOT)
	flow.load_game(expected.path)
	await _until(func() -> bool: return not flow.loading, 150000)
	_expect(not flow.loading and state.get_current_body_record().id == expected.body_id, "Cold load changed body or failed")
	_expect(JSON.parse_string(JSON.stringify(state.get_current_body_record().exploration_atlas)) == JSON.parse_string(JSON.stringify(expected.atlas)), "Cold load changed fog or stable saved places")
	flow.resume()
	map = get_first_node_in_group(&"world_map")
	if map != null:
		map.tracker.update_exploration()
		await _key(KEY_M)
		_expect(map.is_open, "Cold campaign cannot open the atlas")
		await _wait_queries()
		_expect(map._places.any(func(p: Dictionary) -> bool: return p.id == "long-map-place") and map._places.all(func(p: Dictionary) -> bool: return p.id != "must-not-leak"), "Cold load lost known ID or leaked unknown place")
		await _key(KEY_ESCAPE)
		await _frames(3)
	flow.toggle_pause()
	# Exercise the production body-travel lifecycle, beyond record invalidation.
	var departed: bool = await flow.travel_to_planet(23757, 0, 15838)
	_expect(departed, "Actual body travel failed: " + saves.last_error)
	await _until(func() -> bool: return not flow.loading, 150000)
	_expect(not flow.loading and state.active_body_id != expected.body_id, "Travel reused the original body")
	map = get_first_node_in_group(&"world_map")
	if map != null and not flow.loading:
		map.tracker.update_exploration()
		await _key(KEY_M)
		await _wait_queries()
		_expect(map.is_open and map.tracker.atlas.data.body_id == state.active_body_id and map._places.all(func(p: Dictionary) -> bool: return p.id not in ["long-map-place", "map-friend-nest", "must-not-leak"]), "Body travel leaked source fog/places/search")
		_expect(get_nodes_in_group(&"world_map").size() == 1, "Body travel retained a second atlas owner")
		print("INT30_MAP_BODY_TRAVEL ", JSON.stringify({"from":expected.body_id,"to":state.active_body_id,"map_body":map.tracker.atlas.data.body_id}))
		await _key(KEY_ESCAPE)
		await _frames(3)
	flow.toggle_pause()
	flow.return_to_title()
	await scene_changed
	if failures.is_empty(): print("INT30_WORLD_MAP_RESTART_OK")
func _matrix() -> void:
	var locale: Node = root.get_node("LocaleManager")
	for size: Vector2i in [Vector2i(800,600), Vector2i(1280,720), Vector2i(1920,1080)]:
		for scale: float in [1.0,1.25,1.5]:
			for language: String in ["de","en"]:
				root.size = size
				root.position = Vector2i.ZERO
				root.get_node("DisplaySettings").ui_scale = scale
				root.content_scale_factor = scale
				locale._apply(language)
				map._show_info = false; map._show_list = false; map._layout()
				await _frames(7)
				_expect(Rect2(Vector2.ZERO,Vector2(size)).encloses(_rect(map._panel)), "Map panel escaped %s/%s/%s" % [size,scale,language])
				_expect(_rect(map._canvas).size.y >= 150, "Map viewport too small %s/%s/%s" % [size,scale,language])
				await _capture("%s-%dx%d-%d-map" % [language,size.x,size.y,roundi(scale*100)])
				await _click(map._info_toggle)
				_expect(map._legend.is_visible_in_tree() and map._info_scroll.is_visible_in_tree(), "Legend is inaccessible in small map")
				_expect(not map._info_detail.text.begins_with("ATLAS_"), "Untranslated detail")
				await _capture("%s-%dx%d-%d-legend" % [language,size.x,size.y,roundi(scale*100)])
				await _click(map._info_toggle)
				if map._small: await _click(map._places_toggle)
				_expect(map._sidebar.is_visible_in_tree() and _rect(map._scroll).size.y >= 44*scale, "Place list/search cannot be reached")
				await _capture("%s-%dx%d-%d-places" % [language,size.x,size.y,roundi(scale*100)])
	root.size = Vector2i(800,600)
	root.get_node("DisplaySettings").ui_scale = 1.5
	root.content_scale_factor = 1.5
	locale._apply("de")
	map._layout()
	await _frames(6)
func _wait_queries() -> void:
	await _until(func() -> bool: return not map._search_pending and not map._place_query.active and not map._type_census.active and not map._fit_query.active, 20000)
	_expect(not map._search_pending and not map._place_query.active and not map._type_census.active and not map._fit_query.active, "Bounded map query timed out")
func _rect(c: Control) -> Rect2:
	var t: Transform2D = c.get_global_transform_with_canvas()
	var factor: float = float(root.size.x) / root.get_visible_rect().size.x
	return Rect2(t.origin * factor, c.size * t.get_scale() * factor)
func _choose_type(index: int) -> void:
	_expect(index<map._type_filter.item_count,"Native type index is missing")
	await _click(map._type_filter)
	var popup: PopupMenu=map._type_filter.get_popup()
	# Mouse opening has no focused menu row. First Down focuses row zero;
	# Home is not a PopupMenu navigation command on this native backend.
	for step in range(map._type_filter.item_count+1):
		if popup.get_focused_item()==index:break
		await _key(KEY_DOWN)
	_expect(popup.get_focused_item()==index,"Native dropdown cannot focus requested row")
	await _key(KEY_ENTER)
	_expect(not popup.visible and map._type_filter.selected==index,"Native dropdown cannot activate requested row")
func _click(c: Control) -> void:
	var p: Vector2 = _rect(c).get_center()
	if DisplayServer.get_name() != "headless":
		var control_name: String=str(c.name)
		var target_id: String=str(c.get_meta("atlas_place_id",""))
		var previous_id: String=map._selected
		var received: Array[bool]=[false]
		var receipt: Callable=func() -> void: received[0]=true
		c.connect("pressed",receipt,CONNECT_ONE_SHOT)
		_native(["focus",str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE,c.get_window().get_window_id()))])
		_native(["move",str(roundi(p.x+root.position.x)),str(roundi(p.y+root.position.y))])
		await create_timer(0.08,true).timeout
		for down in ["1","0"]:
			_native(["button","1",down]);await create_timer(0.05,true).timeout
		# Selecting a stable ID rebuilds the result buttons during pressed.
		# Its changed selection is a receipt even if that emitter is disposed.
		var activated: Callable=func() -> bool:return received[0] or (not target_id.is_empty() and target_id!=previous_id and map._selected==target_id)
		await _until(activated,2000)
		_expect(activated.call(),"Actual X11 click did not activate "+control_name)
		if is_instance_valid(c) and c.is_connected("pressed",receipt):c.disconnect("pressed",receipt)
		await _frames(3)
		return
	# Use the ordinary Input/Window path so the singleton's pointer/button state
	# agrees with the GUI event. Direct viewport injection left button hover
	# state stale even when the canvas received drag/wheel events.
	root.notify_mouse_entered()
	var viewport_control: String = str(c.name)
	var viewport_target: String = str(c.get_meta("atlas_place_id", ""))
	var viewport_previous: String = map._selected
	var viewport_received: Array[bool] = [false]
	var viewport_receipt: Callable = func() -> void: viewport_received[0] = true
	c.connect("pressed", viewport_receipt, CONNECT_ONE_SHOT)
	var motion := InputEventMouseMotion.new(); motion.position = p; motion.global_position = p + Vector2(root.position); Input.parse_input_event(motion)
	await process_frame
	var hovered: Control = root.gui_get_hovered_control()
	print("INT30_HEADLESS_CLICK ", JSON.stringify({"control": viewport_control, "point": p, "hover": str(hovered), "mouse": Input.mouse_mode}))
	for down in [true,false]:
		var e := InputEventMouseButton.new(); e.position=p; e.global_position=p+Vector2(root.position); e.button_index=MOUSE_BUTTON_LEFT; e.pressed=down; e.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0; Input.parse_input_event(e)
		await process_frame
	# Place selection may dispose/rebuild its own emitter, as in the native path.
	_expect(viewport_received[0] or (not viewport_target.is_empty() and viewport_target != viewport_previous and map._selected == viewport_target), "Actual viewport click did not activate " + viewport_control)
	if is_instance_valid(c) and c.is_connected("pressed", viewport_receipt): c.disconnect("pressed", viewport_receipt)
	await _frames(3)
func _wheel(c: Control, button: int) -> void:
	var p: Vector2 = _rect(c).get_center()
	if DisplayServer.get_name() != "headless":
		_native(["move",str(roundi(p.x+root.position.x)),str(roundi(p.y+root.position.y))])
		await _frames(2)
		for down in ["1","0"]: _native(["button",str(4 if button==MOUSE_BUTTON_WHEEL_UP else 5),down])
		await _frames(3)
		return
	root.notify_mouse_entered()
	var motion := InputEventMouseMotion.new(); motion.position=p; motion.global_position=p+Vector2(root.position); Input.parse_input_event(motion)
	await process_frame
	for down in [true,false]:
		var e := InputEventMouseButton.new(); e.position=p; e.global_position=p+Vector2(root.position); e.button_index=button; e.pressed=down; Input.parse_input_event(e)
		await process_frame
	await _frames(3)
func _drag(c: Control, delta: Vector2) -> void:
	var p: Vector2 = _rect(c).get_center()
	if DisplayServer.get_name() != "headless":
		_native(["move",str(roundi(p.x+root.position.x)),str(roundi(p.y+root.position.y))]);await _frames(2)
		_native(["button","1","1"]);await _frames(2)
		_native(["move",str(roundi(p.x+delta.x+root.position.x)),str(roundi(p.y+delta.y+root.position.y))]);await _frames(2)
		_native(["button","1","0"]);await _frames(3)
		return
	root.notify_mouse_entered()
	var start := InputEventMouseMotion.new(); start.position=p; start.global_position=p+Vector2(root.position); Input.parse_input_event(start)
	await process_frame
	var e := InputEventMouseButton.new(); e.position=p; e.global_position=p+Vector2(root.position); e.button_index=MOUSE_BUTTON_LEFT; e.pressed=true; e.button_mask=MOUSE_BUTTON_MASK_LEFT; Input.parse_input_event(e)
	await process_frame
	var m := InputEventMouseMotion.new(); m.position=p+delta; m.global_position=m.position+Vector2(root.position); m.relative=delta; m.button_mask=MOUSE_BUTTON_MASK_LEFT; Input.parse_input_event(m)
	await process_frame
	e=e.duplicate(); e.position=p+delta; e.global_position=e.position+Vector2(root.position); e.pressed=false; e.button_mask=0; Input.parse_input_event(e)
	await _frames(3)
func _type(value: String) -> void:
	if DisplayServer.get_name() != "headless":
		for c in value: _native(["tap",c.to_lower()]);await _frames(3)
		return
	for c in value:
		var e := InputEventKey.new(); e.keycode=c.to_upper().unicode_at(0); e.physical_keycode=e.keycode; e.unicode=c.unicode_at(0); e.pressed=true; root.push_input(e,true)
		await process_frame
func _key(code: int, ctrl: bool=false) -> void:
	if DisplayServer.get_name() != "headless":
		var names := {KEY_M:"m",KEY_F:"f",KEY_HOME:"Home",KEY_PLUS:"equal",KEY_MINUS:"minus",KEY_LEFT:"Left",KEY_DOWN:"Down",KEY_ENTER:"Return",KEY_ESCAPE:"Escape",KEY_F8:"F8"}
		_native(["tap",names[code]]+(["ctrl"] if ctrl else []))
		await _frames(3)
		return
	for down in [true,false]:
		var target: Viewport = map._type_filter.get_popup() if is_instance_valid(map) and map._type_filter.get_popup().visible else root
		var e := InputEventKey.new(); e.keycode=code; e.physical_keycode=code; e.ctrl_pressed=ctrl; e.pressed=down; target.push_input(e,true)
		await process_frame
func _native(args: Array) -> void:
	var output: Array=[]
	var code: int=OS.execute("python3",[ProjectSettings.globalize_path("res://docs/evidence/int30-11-world-map/native_input.py")]+args,output,true)
	_expect(code==0,"Native X11 event failed: "+str(output))
func _capture(name: String) -> void:
	print("INT30_MAP_VIEW ", JSON.stringify({"name":name,"window":str(root.size),"viewport":str(root.get_visible_rect().size),"panel":str(_rect(map._panel)),"info":map._show_info,"places":map._show_list}))
	if capture_dir.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(name+".png"))
func _frames(n: int) -> void:
	for i in range(n): await process_frame
func _until(predicate: Callable, timeout_ms: int) -> void:
	var end: int=Time.get_ticks_msec()+timeout_ms
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
func _expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		print("INT30_MAP_CHECK_FAILED ", message)
func _finish() -> void:
	print("INT30_WORLD_MAP_CAMPAIGN_CHECKS ",checks)
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("INT30_WORLD_MAP_CAMPAIGN_OK")
	await preload("res://core/runtime_shutdown.gd").finish(self,0 if failures.is_empty() else 1)
