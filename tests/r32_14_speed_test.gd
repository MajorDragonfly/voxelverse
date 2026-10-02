extends "res://tests/tribal_age_test.gd"
## Real controller/menu and atomic save path; fixtures are explicitly not terrain acceptance.
const Atomic = preload("res://core/persistence/atomic_json.gd")
var observations: Array[Dictionary] = []

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	if "--restart-check" in OS.get_cmdline_user_args():
		state.set_process(false)
		_expect(saves.load_now(), "Fresh process cannot reload 3x save")
		_expect(float(state.campaign.data.time_scale) == 3.0, "Fresh process lost chosen 3x speed")
		var before: Dictionary = state.export_state()
		state._process(600.0)
		_expect(state.export_state() == before, "Closed/menu time produced offline work")
		print("R32_14_SPEED_RESTART_OK")
		await _finish()
		return
	Engine.time_scale = 1.0
	# The isolated fixture uses native pixels. The spherical matrix separately
	# exercises the real project's stretched canvas and every configured scale.
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.get_node("DisplaySettings").ui_scale = 1.0
	state.start_world_with_seed(15838)
	await process_frame
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	await _frames(25)
	_expect(home.establish_home().ok, "Speed fixture cannot establish precursor group")
	await _frames(15)
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _until(func() -> bool: return tribe.is_active() and tribe.navigation.is_ready(), 1200)
	if not tribe.is_active():
		_expect(false, "Speed fixture cannot activate real tribe")
		await _cleanup()
		await _finish()
		return
	await _movement_speeds()
	for legacy: float in [0.0,4.0]:
		_expect(state.set_simulation_speed(legacy), "Legacy campaign factor was rejected")
		tribe.panel.refresh()
		_expect(tribe.panel._speed_selector.text == "%d×" % roundi(legacy) and tribe.panel._speed_selector.item_count == 3, "HUD misrepresents legacy speed or offers an inert item")
	# A valid legacy 2x save must not multiply the 3x HUD selection into 6x.
	_expect(state.set_simulation_speed(2.0), "Existing campaign speed setup failed")
	await _mouse_speed(2)
	observations.append({"requested": 3, "engine_scale": Engine.time_scale,
		"saved_scale": state.campaign.data.time_scale,
		"effective_rate": Engine.time_scale * state.simulation_delta(1.0)})
	_expect(is_equal_approx(Engine.time_scale * state.simulation_delta(1.0), 3.0), "3x selection multiplies the existing campaign factor into a second speed")
	_expect(is_equal_approx(float(state.campaign.data.time_scale), 3.0), "3x selection was not stored in authoritative campaign state")
	_expect(saves.save_now(), "Speed save failed: " + saves.last_error)
	var saved := Atomic.parse_dictionary(FileAccess.get_file_as_string(SAVE))
	_expect(is_equal_approx(float(saved.get("game_state", {}).get("campaign", {}).get("time_scale", -1)), 3.0), "Atomic save omitted selected 3x speed")
	# A tactical pause must freeze clock and genuine inventory, while menus retain input.
	await _click(tribe.panel._speed_pause)
	var clock: float = state.campaign.data.elapsed_seconds
	var snapshot: Dictionary = tribe.village().duplicate(true)
	await _frames(8)
	_expect(paused and clock == state.campaign.data.elapsed_seconds and snapshot == tribe.village(), "Tactical pause advances clock or production")
	await _click(tribe.panel._speed_pause)
	state.set_process(false)
	tribe.set_physics_process(false)
	_expect(saves.load_now(), "3x save cannot be reloaded")
	_expect(is_equal_approx(float(state.campaign.data.time_scale), 3.0), "Reload lost chosen campaign speed")
	var child_output: Array = []
	var child_args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--restart-check"])
	var child_code := OS.execute(OS.get_executable_path(), child_args, child_output, true)
	_expect(child_code == 0 and str(child_output).contains("R32_14_SPEED_RESTART_OK") and not str(child_output).contains("SCRIPT ERROR"), "Real process restart failed: " + str(child_output))
	print("R32_14_SPEED_OBSERVATIONS: ", JSON.stringify(observations))
	await _cleanup()
	await _finish()

func _movement_speeds() -> void:
	# Actual collision-body travel on the existing navigation fixture. Work is
	# disabled here; this guards the previous fast walking behavior separately.
	state.set_process(false)
	tribe.set_physics_process(false)
	var member: Dictionary = tribe.village().members[1]
	var actor: CharacterBody3D = tribe.actors[member.id]
	var start: Vector3 = actor.global_position
	var goal: Vector3 = preload("res://world/surface/gameplay_space.gd").resolve(tribe, tribe.village().deposits.wood.position)
	var distances: Array[float] = []
	for speed: int in [1, 2, 3]:
		state.set_simulation_speed(float(speed))
		actor.global_position = start
		actor.velocity = Vector3.ZERO
		tribe._routes.clear()
		tribe._goals.clear()
		for tick in range(12):
			await physics_frame
			tribe._walk(actor, member.id, goal, 1.0/Engine.physics_ticks_per_second, 100.0)
			await process_frame
		distances.append(actor.global_position.distance_to(start))
	_expect(distances[0] > 0.2 and distances[1] > distances[0]*1.7 and distances[2] > distances[0]*2.5, "Canonical clock lost 2x/3x physical travel: " + str(distances))
	print("R32_14_NEAR_MOVEMENT: ", distances)
	actor.global_position = start
	actor.velocity = Vector3.ZERO
	tribe._routes.clear()
	tribe._goals.clear()
	state.set_simulation_speed(1.0)
	state.set_process(true)
	tribe.set_physics_process(true)
