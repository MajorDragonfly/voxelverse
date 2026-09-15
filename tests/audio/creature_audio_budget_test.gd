extends SceneTree
## Real AudioManager and signal-connected observers under a large, changing scene.
const Shutdown = preload("res://core/runtime_shutdown.gd")
var audio: Node
var registry: Node
var scene: Node3D
var camera: Camera3D
var failures: Array[String] = []
var checks := 0
var peak: Dictionary = {}
var samples_us: Array[int] = []
var heard: Array[int] = []

class Creature extends Node3D:
	signal health_changed(current: float, maximum: float)
	signal audio_event(event: StringName)
	signal audio_action(event: StringName)
	var current_health := 40.0
	var maximum_health := 40.0
	var is_dead := false
	var species_seed := 42
	var ecological_role := "grazer"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	audio = root.get_node("AudioManager")
	root.get_node("SaveGameService").autosave_enabled = false
	registry = audio.creatures
	registry.set_process(false)
	registry.clear()
	audio.director.set_process(false)
	audio.director.set_physics_process(false)
	audio.music.automatic_tracking = false
	audio.creature_sound_played.connect(func(id: int, _event: StringName, _pitch: float, _family: String): heard.append(id))
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	camera = Camera3D.new()
	scene.add_child(camera)
	camera.make_current()
	await large_population()
	await lifecycle()
	await scope_and_playback()
	await process_frame
	registry.clear()
	scene.queue_free()
	await process_frame
	samples_us.sort()
	var stats := {"count": samples_us.size(), "max_us": samples_us.back(),
		"p95_us": samples_us[int((samples_us.size() - 1) * 0.95)]}
	print("CREATURE_AUDIO_BUDGET ", JSON.stringify({"passed": failures.is_empty(), "checks": checks,
		"failures": failures, "peaks": peak, "registry_step": stats, "diagnostics": registry.diagnostics()}))
	await Shutdown.finish(self, 0 if failures.is_empty() else 1)


func actor(position: Vector3, group: StringName = &"wildlife") -> Creature:
	var result := Creature.new()
	scene.add_child(result)
	result.position = position
	if not group.is_empty():
		result.add_to_group(group) # Group assignment after ready is supported.
	return result


func step(count: int = 1, check_budgets: bool = true) -> void:
	for index in count:
		await process_frame
		var before := Time.get_ticks_usec()
		registry._process(1.0 / 60.0)
		samples_us.append(Time.get_ticks_usec() - before)
		for emitter in registry.emitters.values():
			emitter.automatic_calls = false
		var stats: Dictionary = registry.diagnostics()
		if check_budgets:
			for item in [["tracked", 64], ["walk_steps", 64], ["walk_depth", 128], ["polled", 8],
					["attached", 4], ["attempted", 4], ["retired", 2]]:
				peak[item[0]] = maxi(int(peak.get(item[0], 0)), int(stats[item[0]]))
				expect(int(stats[item[0]]) <= int(item[1]), "Exceeded %s budget: %s" % [item[0], stats])
			expect(audio._voices.size() == 16, "Spatial voice pool grew")


func finish_sweeps(count: int = 2) -> void:
	var goal: int = registry.diagnostics().completed_sweeps + count
	for frame in 1600:
		await step()
		if registry.diagnostics().completed_sweeps >= goal:
			return
	expect(false, "Incremental scene discovery starved before finishing a sweep")


func large_population() -> void:
	# Non-creature render nodes must count towards the discovery budget as well.
	var scenery := Node3D.new()
	scene.add_child(scenery)
	for i in 2048:
		scenery.add_child(Node3D.new())
	var distant: Array[Creature] = []
	for i in 320:
		distant.append(actor(Vector3(1000.0 + i % 8, 0.0, -5.0)))
	for i in 80:
		actor(Vector3(float(i % 4), 0.0, -40.0))
	var closest := actor(Vector3(0, 0, -3))
	var player := actor(Vector3(0, 0, -4), &"player")
	await finish_sweeps()
	expect(registry.emitters.size() == 64, "Did not fill the bounded nearby observer pool")
	expect(registry.emitters.has(closest.get_instance_id()), "Late nearest source was starved by scene order")
	expect(registry.emitters.has(player.get_instance_id()), "Player feedback was starved by ambient sources")
	for source in distant:
		expect(not registry.emitters.has(source.get_instance_id()), "Inaudible source consumed an observer")
	for emitter in registry.emitters.values():
		expect(not emitter.is_processing(), "Creature still has an independent per-frame observer")
	var observations: Dictionary = {}
	for emitter in registry.emitters.values():
		observations[emitter.get_instance_id()] = emitter.last_sample
	await step(8)
	for emitter in registry.emitters.values():
		expect(float(emitter.last_sample) > float(observations.get(emitter.get_instance_id(), -1)), "Round-robin polling starved an active source")
	# Legacy actors without health signals still get one audible injury observation.
	audio.stop_world()
	closest.current_health -= 3.0
	var previous := heard.count(closest.get_instance_id())
	await step(12)
	expect(heard.count(closest.get_instance_id()) == previous + 1, "Legacy damage was lost or repeated at pool capacity")
	# Move the listener across the population while a sweep is in flight.
	camera.position.x = 1000.0
	await finish_sweeps()
	expect(not registry.emitters.has(closest.get_instance_id()), "Old neighborhood retained observers after listener travel")
	expect(registry.emitters.has(distant[0].get_instance_id()), "New nearby population remained silent")
	camera.position = Vector3.ZERO
	await finish_sweeps()
	expect(registry.emitters.has(closest.get_instance_id()), "A-B-A listener travel failed to rediscover the original source")
	# Hysteresis avoids repeated construction at the audible boundary.
	closest.position.z = -50.0
	await step(16)
	expect(registry.emitters.has(closest.get_instance_id()), "Hysteresis did not retain a quiet boundary source")
	expect(not audio.play_creature(&"warn", closest), "Outside-hearing source allocated a voice")
	closest.position.z = -70.0
	await step(40)
	expect(not registry.emitters.has(closest.get_instance_id()), "Distant observer was never retired")
	# Keep the next cases small; no source or queued traversal may retain scenery.
	registry.clear()
	for child in scene.get_children():
		if child != camera:
			child.queue_free()
	await step(2)
	expect(registry.emitters.is_empty(), "Deleted population remained registered")


func lifecycle() -> void:
	var source := actor(Vector3(0, 0, -3))
	await finish_sweeps(1)
	var original: Node = registry.emitters.get(source.get_instance_id())
	expect(original != null, "Source not discovered before lifecycle case")
	if original == null:
		return
	var prior_generation: int = registry.generation
	registry.clear()
	expect(registry.generation > prior_generation and not original.emit_reaction(&"attack"), "Clear left an active old-generation callback")
	var fresh: Node = registry.attach(source)
	expect(fresh != null and fresh != original, "Same-frame clear/reattach was blocked by the old child")
	var before := heard.size()
	source.audio_event.emit(&"warn")
	expect(heard.size() == before + 1, "Same-frame replacement duplicated or lost a signal")
	expect(source.audio_event.get_connections().size() == 1, "Old emitter kept its signal connection")
	# Removal precedes deletion in real scene transitions.
	scene.remove_child(source)
	expect(not registry.emitters.has(source.get_instance_id()), "Detached source retained a registry slot")
	expect(not fresh.emit_reaction(&"hurt"), "Detached emitter accepted a callback")
	for voice in audio._voices:
		if int(voice.get_meta(&"audio_source_id", -1)) == source.get_instance_id():
			expect(not voice.playing, "Detached source left an audible voice")
	await step()
	scene.add_child(source)
	await finish_sweeps(1)
	expect(registry.emitters.has(source.get_instance_id()), "Restored source did not receive a fresh observer")
	# No timers, discovery or polling may advance through a paused interval.
	var clock: float = registry._elapsed
	var stats: Dictionary = registry.diagnostics()
	paused = true
	registry._process(120.0)
	expect(registry._elapsed == clock and registry.diagnostics() == stats, "Pause advanced registry time or work")
	expect(not audio.play_creature(&"hurt", source), "Paused callback allocated a voice")
	paused = false
	await step(2)
	expect(registry._elapsed < clock + 0.1, "Resume caught up paused wall time")
	source.set_meta(&"audio_disabled", true)
	await step(4)
	expect(not audio.play_creature(&"warn", source), "Explicitly disabled source accepted audio")
	source.queue_free()
	await step(2)
	# A same-frame burst has a hard constructor limit; remaining requests retry.
	registry.automatic_tracking = false
	await step()
	var burst: Array[Creature] = []
	var accepted := 0
	for i in 24:
		var candidate := actor(Vector3(0, 0, -5), &"")
		burst.append(candidate)
		if registry.attach(candidate) != null:
			accepted += 1
	expect(accepted == 4, "Explicit attachment burst escaped the four-constructor limit")
	await step()
	expect(registry.attach(burst.back()) != null, "Rejected source could not retry next frame")
	registry.clear()
	for candidate in burst:
		candidate.queue_free()
	await step()
	registry.automatic_tracking = true
	var explicit := actor(Vector3(0, 0, -4), &"")
	expect(audio.play_creature(&"warn", explicit), "Explicit source without a wildlife group was rejected")
	await step(12)
	expect(registry.emitters.has(explicit.get_instance_id()), "Explicit source was retired just because it had no wildlife group")
	explicit.queue_free()
	await step()


func scope_and_playback() -> void:
	var source := actor(Vector3(0, 0, -3))
	await finish_sweeps(1)
	# Real imported loop gives a stable playback for movement/removal checks.
	audio.register_sound(&"creature_budget_loop", [audio.get_sound_stream(&"wind_loop")])
	expect(audio.play_world(&"creature_budget_loop", source.position, -30, 1, source.get_instance_id()), "Could not start source-owned playback")
	var voice: AudioStreamPlayer3D
	for candidate in audio._voices:
		if candidate.playing and candidate.get_meta(&"audio_source_id", -1) == source.get_instance_id():
			voice = candidate
	if voice == null:
		expect(false, "Missing source-owned voice")
		return
	source.position.x = 7.0
	audio._update_world_sources()
	expect(voice.global_position == source.global_position, "Moving creature left its voice at the old position")
	var shift := Vector3(-10000, 23000, 51000)
	source.position += shift
	camera.position += shift
	audio.director.surface_origin_shifted(shift)
	expect(voice.global_position == source.global_position, "Origin shift did not preserve source/voice alignment")
	audio._update_world_sources()
	expect(voice.global_position == source.global_position, "Source follow applied the origin shift twice")
	# Foreign subviewports/worlds must not allocate even at the same coordinates.
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	scene.add_child(viewport)
	var foreign := Creature.new()
	viewport.add_child(foreign)
	foreign.position = camera.position
	expect(not registry.audible(foreign) and not audio.play_creature(&"warn", foreign), "Foreign world leaked creature feedback")
	viewport.queue_free()
	# New scene without freeing the outgoing one: invalidate pending discovery and signals.
	var old_scene := scene
	var old_generation: int = registry.generation
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	camera = Camera3D.new()
	scene.add_child(camera)
	camera.make_current()
	await step(1, false) # Whole-scene teardown is bounded by 64, outside normal retire rate.
	expect(registry.generation > old_generation and registry.emitters.is_empty(), "Scene replacement retained old generation work")
	var count := heard.size()
	source.audio_event.emit(&"attack")
	expect(heard.size() == count and not audio.play_creature(&"hurt", source), "Old scene signal crossed into the new scene")
	expect(not voice.playing, "Old scene playback survived source switch")
	old_scene.queue_free()
	var new_source := actor(Vector3(0, 0, -2))
	await finish_sweeps(1)
	expect(registry.emitters.has(new_source.get_instance_id()), "New scene source was not discovered")


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)
