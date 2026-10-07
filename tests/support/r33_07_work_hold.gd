extends "res://tests/tribal_age_test.gd"
## Production village fixture and public entry/orders; synthetic normal storm
## input isolates the owner hook. Cover is always actual actor collision state.
const Exposure = preload("res://world/weather/r33_exposure_runtime.gd")
class WeatherPort:
	extends Node
	var normal: Dictionary = {}
	var active: bool = false
	func suspends_resident_work(actor: Node3D, order: String) -> bool:
		return active and Exposure.suspends_work(normal, Exposure.protection(actor, normal), order)

func _run() -> void:
	root.get_node("LocaleManager")._apply("de")
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	state.start_world_with_seed(15838)
	await process_frame
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	await _frames(25)
	_expect(home.establish_home().ok, "Work fixture home entry.")
	await _frames(20)
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _until(func() -> bool: return tribe.is_active() and tribe.navigation.is_ready(), 1000)
	if not tribe.is_active():
		_expect(false, "Actual tribe entry failed.")
		await _cleanup()
		_finish()
		return
	var port := WeatherPort.new()
	scene.add_child(port)
	port.add_to_group(&"campaign_weather")
	var Test = preload("res://tests/r33_07_extreme_weather_test.gd")
	var Storm = preload("res://world/weather/r33_sandstorm.gd")
	var id: String = "extreme-fixture"
	port.normal = Test.sample(id, 15838, Storm.schedule(id, 15838).calm + 240.0, Test.site(id, 15838))
	port.normal.wind_velocity = [1.0, 0.0, 0.0]
	tribe.select_all()
	_expect(tribe.issue_order("wood"), "Real wood order rejected.")
	var worker: String = str(tribe.village().members[1].id)
	await _until(func() -> bool: return tribe.member_record(worker).cargo == "wood", 800)
	_expect(tribe.member_record(worker).cargo == "wood", "Original work did not produce real cargo.")
	port.active = true
	var saved: Dictionary = tribe.member_record(worker).duplicate(true)
	var stock: int = int(tribe.village().stock.wood)
	await _frames(25)
	_expect(tribe.member_record(worker) == saved and int(tribe.village().stock.wood) == stock, "Storm hold mutated actual order/work/cargo/stock.")
	_expect(tribe.actors[worker].velocity == Vector3.ZERO, "Held carrier still moving.")
	paused = true
	_expect(saves.save_now() and saves.load_now(), "Held actual cargo cannot save/reload.")
	paused = false
	await _until(func() -> bool: return tribe.is_active() and tribe.navigation.is_ready(), 1000)
	_expect(tribe.member_record(worker).cargo == saved.cargo and tribe.member_record(worker).order == saved.order
		and is_equal_approx(tribe.member_record(worker).work, saved.work), "Hold/reload lost work/cargo.")
	var actor: Node3D = tribe.actors[worker]
	_expect(port.suspends_resident_work(actor, "wood"), "Reloaded exposed worker no longer held.")
	var roof: StaticBody3D = _box(Vector3(3,0.4,3), actor.global_position + Vector3.UP * 2.3)
	var wall: StaticBody3D = _box(Vector3(0.4,4,3), actor.global_position - Vector3.RIGHT * 1.3)
	await _frames(3)
	_expect(not port.suspends_resident_work(actor, "wood"), "Real sheltered worker still held.")
	roof.collision_layer = 0
	wall.collision_layer = 0
	await _frames(3)
	_expect(port.suspends_resident_work(actor, "wood"), "Removed real shelter still protects worker.")
	port.active = false
	await _until(func() -> bool: return int(tribe.village().stock.wood) > stock, 650)
	_expect(int(tribe.village().stock.wood) > stock and tribe.member_record(worker).order == saved.order, "Decay did not resume existing cargo/order.")
	print(JSON.stringify({"kind":"R33_07_WORK_EVIDENCE", "passed":failures.is_empty(), "worker":worker,
		"held_member":saved, "wood_before_hold":stock, "wood_after_resume":tribe.village().stock.wood,
		"order_after_resume":tribe.member_record(worker).order, "failures":failures}))
	print("R33_07_WORK: ", failures.is_empty(), "; real controller/public wood work/cargo; hold/save/load/physical cover/resume")
	await _cleanup()
	_finish()
