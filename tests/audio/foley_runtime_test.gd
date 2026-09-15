extends SceneTree
## Real world director and imported sounds on a non-Y local water surface.
const Shutdown = preload("res://core/runtime_shutdown.gd")
var audio: Node
var director: Node
var scene: Node3D
var camera: Camera3D
var player: Swimmer
var heard: Array[StringName] = []
var failures: Array[String] = []
var checks := 0
var queries := 0
var query_peak := 0
var water_x := 3.0
var water_present := true

class Swimmer extends CharacterBody3D:
	var is_dead := false
	var is_swimming := false


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	audio = root.get_node("AudioManager")
	root.get_node("SaveGameService").autosave_enabled = false
	director = audio.director
	director.set_physics_process(false)
	director.set_process(false)
	audio.creatures.automatic_tracking = false
	audio.music.automatic_tracking = false
	audio.sound_played.connect(func(event: StringName, _point: Vector3): heard.append(event))
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	player = Swimmer.new()
	player.up_direction = Vector3.RIGHT
	player.set_meta("surface_mode", "cube_sphere_v1")
	scene.add_child(player)
	player.position = Vector3(2.7, 0, 0)
	player.add_to_group(&"player")
	camera = Camera3D.new()
	scene.add_child(camera)
	camera.position.x = 3.2
	camera.make_current()
	director.sample_provider = sample
	director.reset_tracking()
	var initial_nodes: int = director.get_child_count()
	await tick(60)
	expect(heard.is_empty(), "Wet spawn/idle produced a transition or footstep")
	await tick(90, Vector3(0, 0, -0.07))
	expect(heard.count(&"step_water") >= 3 and not heard.has(&"swim"), "Shallow wading did not use its foot-contact sound")
	# A deep grounded/wading body is not necessarily swimming. Read controller state.
	player.position.x = 1.4
	var before := heard.count(&"step_water")
	await tick(60, Vector3(0, 0, -0.07))
	expect(heard.count(&"step_water") > before and not heard.has(&"swim"), "Depth overrode the controller's non-swimming state")
	player.is_swimming = true
	await tick(70, Vector3(0, 0, -0.07))
	expect(heard.has(&"swim"), "Swimming controller state did not select strokes")
	# Radial upward/downward strokes count as movement too, without a Y assumption.
	player.position.x = -2.0
	before = heard.count(&"swim")
	await tick(70, Vector3(0.03, 0, 0))
	expect(heard.count(&"swim") > before, "Vertical swimming had no stroke feedback")
	camera.position.x = 2.0
	director._sample_clock = 0.0
	await tick(3)
	expect(director._underwater and heard.count(&"water_dive") == 1, "Radial eye crossing did not emit one dive cue")
	before = heard.count(&"underwater_bubbles")
	await tick(360)
	expect(heard.count(&"underwater_bubbles") == before, "Idle underwater created movement bubble cues")
	await tick(660, Vector3(0, 0, -0.035))
	var bubbles := heard.count(&"underwater_bubbles") - before
	expect(bubbles >= 1 and bubbles <= 4, "Moving underwater bubble cadence was missing or unbounded")
	expect(heard.count(&"water_dive") == 1, "Continuous submersion repeated its transition")
	# Shared eye-depth hysteresis prevents surface flutter.
	for depth in [0.02, 0.008, 0.03, 0.01]:
		camera.position.x = water_x - depth
		director._sample_clock = 0.0
		await tick(2)
	expect(director._underwater and not heard.has(&"water_surface"), "Surface jitter triggered an early emerge cue")
	camera.position.x = water_x + 0.2
	director._sample_clock = 0.0
	await tick(3)
	expect(not director._underwater and heard.count(&"water_surface") == 1, "Emerging did not use its own cue")
	await tick(50)
	before = heard.size()
	var cadence: float = director._water_foley._bubble_clock
	paused = true
	camera.position.x = water_x - 1.0
	director._sample_clock = 0.0
	director._physics_process(60.0)
	expect(heard.size() == before and director._water_foley._bubble_clock == cadence, "Pause advanced water foley")
	paused = false
	await tick(3)
	expect(heard.count(&"water_dive") == 2, "Unpaused eye crossing was lost")
	# Water-body departure differs from entering; settle and eye changes stay separate.
	camera.position.x = water_x + 0.2
	director._sample_clock = 0.0
	await tick(50)
	player.is_swimming = false
	player.position.x = water_x + 0.2
	director._sample_clock = 0.0
	await tick(3)
	expect(heard.has(&"water_exit"), "Walking out of water reused the entry splash")
	before = heard.size()
	player.position.z += 1000.0
	await tick(60)
	expect(heard.size() == before, "Teleport synthesized strokes or water transitions")
	# Camera/source replacement initializes silently, also when already submerged.
	var replacement := Camera3D.new()
	scene.add_child(replacement)
	replacement.position = Vector3(1, 0, player.position.z)
	replacement.make_current()
	await tick(60)
	expect(heard.size() == before, "Camera replacement fabricated an entry cue")
	camera.queue_free()
	camera = replacement
	for name in [&"water_dive", &"water_surface", &"water_exit", &"underwater_bubbles"]:
		var stream: AudioStream = audio.get_sound_stream(name)
		expect(stream != null and stream.get_length() > 0.4, "New event missing its imported sound: " + String(name))
	expect(audio._streams[&"underwater_bubbles"].size() == 3, "Bubble variants not registered")
	expect(director.get_child_count() == initial_nodes and audio._voices.size() == 16, "Foley allocated additional players")
	expect(query_peak <= 4, "Foley added environment queries beyond the existing frame cap")
	player.queue_free()
	await tick(3)
	expect(director._player == null and not director._underwater, "Deleted player retained underwater state")
	director.sample_provider = Callable()
	director.reset_tracking()
	scene.queue_free()
	await process_frame
	print("FOLEY_RUNTIME ", JSON.stringify({"passed": failures.is_empty(), "checks": checks,
		"failures": failures, "query_peak": query_peak, "event_counts": counts()}))
	await Shutdown.finish(self, 0 if failures.is_empty() else 1)


func tick(frames: int, movement: Vector3 = Vector3.ZERO) -> void:
	for index in frames:
		await process_frame
		if is_instance_valid(player) and player.is_inside_tree() and not player.is_queued_for_deletion():
			player.position += movement
			player.velocity = movement * 60.0
		queries = 0
		director._physics_process(1.0 / 60.0)
		query_peak = maxi(query_peak, queries)


func sample(_position: Vector3) -> Dictionary:
	queries += 1
	return {"water_present": water_present, "water_point": Vector3(water_x, 0, 0),
		"up": Vector3.RIGHT, "biome_name": "Forest"}


func counts() -> Dictionary:
	var result := {}
	for event in heard:
		result[String(event)] = int(result.get(String(event), 0)) + 1
	return result


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
