extends SceneTree
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Surface = preload("res://core/campaign/surface_context.gd")
const Factory = preload("res://world/surface/planet_surface_factory.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const Storm = preload("res://world/weather/r33_sandstorm.gd")
const Runtime = preload("res://world/weather/r33_exposure_runtime.gd")
const Receipt = preload("res://world/weather/r33_exposure_state.gd")
const Climate = preload("res://world/weather/planet_climate.gd")
const Shelters = preload("res://world/tribe/village_shelters.gd")
var failures: Array[String] = []
var rows: Array[Dictionary] = []
var folder: String
var state: Node
var flow: Node
var weather: Node
var camera: Camera3D
var body: Dictionary
var cycle: Dictionary
var drawn: int = 0
var initial_pose: Transform3D
var peak: float

func _initialize() -> void:
    RenderingServer.frame_post_draw.connect(func() -> void: drawn += 1)
    call_deferred("_run")

func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    folder = args[args.find("--capture") + 1] if "--capture" in args else ""
    state = root.get_node("GameState")
    flow = root.get_node("SessionFlow")
    var saves: Node = root.get_node("SaveGameService")
    saves.autosave_enabled = false
    saves.session_managed = true
    if "--cold-native" in args:
        var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("cold-fixture.json")))
        saves.save_path = fixture.path
        saves.session_active = true
        check(saves.load_now(), "Fresh-process actual slot load failed.")
        var receipt: Dictionary = state.get_current_body_record()[Receipt.FIELD]
        check(preload("res://tests/r33_07_extreme_weather_test.gd").receipt_matches(receipt, JSON.parse_string(fixture.receipt)), "Fresh-process receipt differs.")
        check(is_equal_approx(saves._last_player_state.health_ratio, fixture.health_ratio), "Fresh-process real health differs.")
        check(state.campaign.data.elapsed_seconds == fixture.clock, "Fresh-process clock differs.")
        Receipt.attach(state.get_current_body_record(), state.campaign.data.player_object_id, fixture.clock)
        check(Receipt.consume(receipt, state.get_current_body_record(), fixture.clock, 1.0, false, fixture.health_ratio) == 0.0, "Cold process double harm.")
        await _finish()
        return
    check(not folder.is_empty() and DisplayServer.get_name() != "headless", "Native campaign required.")
    if not failures.is_empty(): await _finish(); return
    var settings: Node = root.get_node("DisplaySettings")
    settings.display_mode = 0
    settings.resolution = Vector2i(960, 540)
    settings.vsync_enabled = false
    settings._apply_settings(false)
    root.size = Vector2i(960, 540)
    root.get_node("LocaleManager")._apply("de")
    var path: String = saves.create_slot("R33-07 natural sandstorm", 15838, Cube.MODE)
    check(not path.is_empty(), "Slot creation.")
    var system_seed: int = 0
    var reference: String = args[args.find("--reference-save") + 1] if "--reference-save" in args else ""
    var seeds: Array[int] = []
    if reference.is_empty():
        for value: int in range(23757, 23821): seeds.append(value)
    else:
        var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(reference))
        body = payload.game_state.campaign.bodies[payload.game_state.body_id]
        system_seed = payload.game_state.system_seed
    for candidate_seed: int in seeds:
        var candidate: Dictionary = state.campaign.ensure_body(15838, candidate_seed)
        if candidate.get(Climate.FIELD, {}).get("profile_id") != "arid": continue
        var site: Dictionary = _site(candidate)
        if site.is_empty(): continue
        body = state.campaign.body_record(candidate.id)
        body.surface_context.spawn = site
        system_seed = candidate_seed
        break
    check(not body.is_empty(), "No naturally generated dry sandy unprotected body/site.")
    if body.is_empty(): await _finish(); return
    if reference.is_empty(): check(state.activate_body(body.id, system_seed, 1, false), "Natural body activation.")
    cycle = Storm.schedule(body.id, body.seed)
    # Same daytime observation in both renderers, independent of startup FPS.
    var offset: float = 0.0
    var Atmosphere = preload("res://world/visuals/atmosphere/campaign_atmosphere.gd")
    for index: int in range(12):
        var fraction: float = Atmosphere.day_progress(cycle.calm + cycle.period * index)
        if fraction > 0.3 and fraction < 0.55:
            offset = cycle.period * index
            break
    peak = offset + cycle.calm + cycle.warning + cycle.rising + 30.0
    state.campaign.data.elapsed_seconds = offset + cycle.calm - 5.0
    state.set_simulation_speed(0.0)
    check(saves.save_now(), "Initial actual save.")
    if not reference.is_empty(): FileAccess.open(path, FileAccess.WRITE).store_string(FileAccess.get_file_as_string(reference))
    FileAccess.open(folder.path_join("reference-save.json"), FileAccess.WRITE).store_string(FileAccess.get_file_as_string(path))
    saves.session_active = false
    change_scene_to_file(flow.TITLE_SCENE)
    await scene_changed
    RenderingServer.render_loop_enabled = false
    await _open(path)
    if not failures.is_empty(): await _finish(); return
    for frame: int in range(27):
        await _capture("frame-%04d.png" % frame, offset + cycle.calm - 5.0 + frame * 15.0)
    check(weather.snapshot().get("storm_phase") == "calm" and weather.snapshot().get("hazard_intensity") == 0.0, "Storm did not end.")
    await _capture("warning-de.png", offset + cycle.calm + 20.0)
    check(weather._forecast_panel._warning.visible, "Actual warning not drawn.")
    root.get_node("LocaleManager")._apply("en")
    await _capture("warning-en.png", offset + cycle.calm + 20.0)
    root.get_node("LocaleManager")._apply("de")
    await _capture("exposed-before.png", peak)
    check(weather.snapshot().condition == "sandstorm" and weather._view._rain.multimesh.visible_instance_count > 0, "No native normal sand entry.")
    var actor: Node3D = current_scene.player
    actor.defense_rating = 0.0
    actor.hunger_loss_per_second = 0.0
    actor.thirst_loss_per_second = 0.0
    actor.recovery.reset()
    var before: float = actor.current_health
    await _live(60, 1.0)
    await _capture("exposed-after.png", state.campaign.data.elapsed_seconds)
    check(actor.current_health < before and body[Receipt.FIELD].spent_ratio > 0.0, "Actual live exposure produced no health consequence.")
    var exposed_loss: float = before - actor.current_health
    check(exposed_loss <= actor.maximum_health * Receipt.MAX_DAMAGE_RATIO, "Native damage exceeds bound.")
    var shelter := StaticBody3D.new()
    current_scene.add_child(shelter)
    shelter.global_position = actor.global_position - Space.up(actor, actor.global_position) * 0.7
    var sample: Dictionary = Runtime.local_sample(weather, actor, body, state.campaign.data.elapsed_seconds)
    var wind: Vector3 = Cube.vector(sample.wind_velocity)
    shelter.global_basis = Cube.frame(Space.up(actor, actor.global_position), -wind)
    var models := Shelters.new()
    models.add_model(shelter, "hut")
    models.free()
    await physics_frame
    await physics_frame
    check(Runtime.protection(actor, sample).protected, "Actual original hut geometry does not protect.")
    before = actor.current_health
    await _live(60, 4.0)
    await _capture("physical-shelter.png", state.campaign.data.elapsed_seconds)
    check(actor.current_health == before and weather._exposure.last_result.protected, "Protected actor harmed at 4x.")
    check(saves.save_now(), "Actual sheltered checkpoint.")
    var saved_clock: float = state.campaign.data.elapsed_seconds
    var saved_receipt: String = Atomic.stringify(body[Receipt.FIELD])
    FileAccess.open(folder.path_join("cold-fixture.json"), FileAccess.WRITE).store_string(Atomic.stringify({"path":path,"clock":saved_clock,"receipt":saved_receipt,"health_ratio":actor.get_health_ratio()}))
    var cold_output: Array = []
    var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--capture", folder, "--cold-native"], cold_output, true)
    FileAccess.open(folder.path_join("cold-process.log"), FileAccess.WRITE).store_string(str(cold_output))
    check(code == 0 and "ERROR:" not in str(cold_output) and "SCRIPT ERROR" not in str(cold_output), "Fresh process failed.")
    flow.toggle_pause()
    for frame: int in range(3): await process_frame
    check(state.campaign.data.elapsed_seconds == saved_clock and actor.current_health == before, "Pause moved health/clock.")
    await _image("paused.png")
    flow.resume()
    weather.set_preview_condition("sandstorm")
    await _capture("diagnostic-only.png", saved_clock)
    check(weather.snapshot().preview and weather.snapshot().hazard_intensity == 0 and weather.forecast().is_empty(), "Diagnostic mixes normal hazard.")
    before = actor.current_health
    await _live(30, 1.0)
    check(actor.current_health == before, "Diagnostic caused actual harm.")
    weather.set_preview_condition("")
    await _capture("before-reload.png", saved_clock)
    check(saves.save_now(), "Reload checkpoint.")
    var saved_health: float = actor.current_health
    flow.return_to_title()
    await scene_changed
    await _open(path)
    if not failures.is_empty(): await _finish(); return
    body = state.get_current_body_record()
    check(is_equal_approx(current_scene.player.current_health, saved_health), "Scene reload changed actual health.")
    check(is_equal_approx(body[Receipt.FIELD].spent_ratio, JSON.parse_string(saved_receipt).spent_ratio), "Scene reload reset harm budget.")
    await _capture("reloaded.png", saved_clock)
    var no_catchup: float = current_scene.player.current_health
    weather._physics_process(0.0)
    check(current_scene.player.current_health == no_catchup, "Scene reload applied duplicate harm.")
    FileAccess.open(folder.path_join("consequences.json"), FileAccess.WRITE).store_string(JSON.stringify({"exposed_loss":exposed_loss,"protected_loss":0.0,"saved_health":saved_health,"spent_ratio":body[Receipt.FIELD].spent_ratio,"cold_code":code}))
    await _finish()

func _site(candidate: Dictionary) -> Dictionary:
    var surface: RefCounted = Factory.create(Surface.descriptor(candidate))
    for face: int in range(6):
        for y: int in range(-15, 16):
            for x: int in range(-15, 16):
                var address: Dictionary = Cube.address(candidate.id, face, x / 16.0, y / 16.0)
                var d: Array = Cube.direction(address.face, address.u, address.v)
                if Storm.region(candidate.id, candidate.seed, [d[0] * surface.body.radius, d[1] * surface.body.radius, d[2] * surface.body.radius]) < 0.9: continue
                var terrain: Dictionary = surface.sample(address)
                if terrain.moisture >= 0.15 or terrain.temperature <= 0.3 or float(terrain.get("biome_weights", {}).get("desert", 0.0)) < 0.25: continue
                if not Surface.landing_problem(surface, address).is_empty(): continue
                address.height = terrain.height + 1.1
                return address
    return {}

func _open(path: String) -> void:
    flow.load_game(path)
    var started: int = Time.get_ticks_msec()
    while flow.loading and Time.get_ticks_msec() - started < 90000: await process_frame
    check(not flow.loading and current_scene.scene_file_path == Surface.SCENE, "Existing 90-s public load guard.")
    if flow.loading or current_scene.scene_file_path != Surface.SCENE: return
    weather = current_scene.get_node("Weather")
    body = state.get_current_body_record()
    camera = root.get_camera_3d()
    current_scene.player.process_mode = Node.PROCESS_MODE_DISABLED
    var spawn: Dictionary = state.get_current_body_record().surface_context.spawn
    var up: Vector3 = Cube.vector(Cube.direction(spawn.face, spawn.u, spawn.v))
    var point: Vector3 = Space.resolve(weather, spawn)
    camera.top_level = true
    camera.global_transform = Transform3D(Cube.frame(up), point) * Transform3D(Basis(Vector3.RIGHT, -0.10), Vector3(0,1.7,0)) * Transform3D(Basis.IDENTITY, Vector3(0,0,7.2))
    initial_pose = camera.global_transform
    for frame: int in range(4): await process_frame

func _live(frames: int, speed: float) -> void:
    state.set_simulation_speed(speed)
    for index: int in range(frames):
        # The actual GameState port remains the only writer of simulated time.
        # Player movement is frozen solely to retain a comparable observation.
        current_scene.player.set_physics_process(true)
        state._process(1.0/60.0)
        current_scene.player.set_physics_process(false)
        weather._process(0.0)
        weather._physics_process(1.0/60.0)
        await physics_frame
    state.set_simulation_speed(0.0)

func _capture(name: String, clock: float) -> void:
    if absf(clock - float(state.campaign.data.elapsed_seconds)) > 0.001: weather._exposure.reset()
    state.campaign.data.elapsed_seconds = clock
    weather._forecast_elapsed = 1.0
    weather._process(0.0)
    current_scene._atmosphere.update_view(0.0, true)
    for frame: int in range(2): await process_frame
    if not bool(weather.snapshot().get("preview", false)):
        var expected: Dictionary = Runtime.local_sample(weather, current_scene.player, state.get_current_body_record(), clock)
        check(weather.snapshot().get("storm_event_id") == expected.get("storm_event_id") and weather.snapshot().get("storm_phase") == expected.get("storm_phase"), "Normal campaign source disagreement.")
        check(weather._forecast_panel._warning.visible == bool(weather.snapshot().get("storm_warning", false)), "Warning differs from exact lead.")
    check(camera.global_transform.is_equal_approx(initial_pose), "Comparison camera moved.")
    await _image(name)
    rows.append({"file":name,"clock":clock,"snapshot":weather.snapshot(),"health":current_scene.player.current_health,"receipt":state.get_current_body_record().get(Receipt.FIELD,{}).duplicate(true)})
    FileAccess.open(folder.path_join("partial.json"), FileAccess.WRITE).store_string(JSON.stringify(rows))

func _image(name: String) -> void:
    var previous: int = drawn
    RenderingServer.force_draw(false)
    RenderingServer.force_sync()
    check(drawn > previous, "No full native frame_post_draw.")
    check(root.get_texture().get_image().save_png(folder.path_join(name)) == OK, "Native image write.")

func _finish() -> void:
    if "--cold-native" not in OS.get_cmdline_user_args():
        FileAccess.open(folder.path_join("review.json"), FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"rows":rows,"native_frames":drawn}))
    for failure: String in failures: push_error(failure)
    print("R33_07_NATIVE: ", failures.is_empty())
    RenderingServer.render_loop_enabled = true
    await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func check(value: bool, message: String) -> void:
    if not value and not failures.has(message): failures.append(message)
