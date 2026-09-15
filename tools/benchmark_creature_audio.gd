extends SceneTree
## Fixed CPU route, compatible with the baseline and the bounded registry.
## Outputs measurements only: no GPU/FPS or subjective hearing claim.
var scene: Node3D
var audio: Node
var samples: Array[int] = []
var stages: Array[Dictionary] = []
var attachments_peak := 0
var tracked_peak := 0
var alive_peak := 0
var retired: Array[WeakRef] = []
var peaks: Dictionary = {}

class Creature extends Node3D:
	var current_health := 40.0
	var maximum_health := 40.0
	var is_dead := false
	var species_seed := 42
	var ecological_role := "grazer"


func _initialize() -> void:
	call_deferred("run")


func actor(point: Vector3) -> Node3D:
	var creature := Creature.new()
	scene.add_child(creature)
	creature.position = point
	creature.add_to_group(&"wildlife")
	return creature


func run() -> void:
	audio = root.get_node("AudioManager")
	root.get_node("SaveGameService").autosave_enabled = false
	var registry: Node = audio.creatures
	registry.set_process(false)
	registry.clear()
	audio.director.set_process(false)
	audio.director.set_physics_process(false)
	audio.music.automatic_tracking = false
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.make_current()
	var scenery := Node.new()
	scene.add_child(scenery)
	for i in 2048:
		scenery.add_child(Node3D.new())
	for i in 320:
		actor(Vector3(1000.0 + i % 8, 0.0, -5.0))
	for i in 80:
		actor(Vector3(float(i % 4), 0.0, -40.0))
	var near_a := actor(Vector3(0, 0, -2))
	var near_b := actor(Vector3(1000, 0, -2))
	for stage in 3:
		camera.position.x = 1000.0 if stage == 1 else 0.0
		var target: Node3D = near_b if stage == 1 else near_a
		var first_seen := -1
		for frame in 360:
			await process_frame
			var previous: Dictionary = registry.emitters.duplicate()
			var started := Time.get_ticks_usec()
			registry._process(1.0 / 60.0)
			# Baseline polls each emitter in a separate process callback. Execute
			# those callbacks here too, so both versions measure the same work.
			if not registry.has_method("diagnostics"):
				for emitter in registry.emitters.values():
					emitter._process(1.0 / 60.0)
			samples.append(Time.get_ticks_usec() - started)
			var attached := 0
			for id in registry.emitters:
				var emitter: Node = registry.emitters[id]
				emitter.automatic_calls = false
				emitter.set_process(false)
				if not previous.has(id):
					attached += 1
			for id in previous:
				if not registry.emitters.has(id) and is_instance_valid(previous[id]):
					retired.append(weakref(previous[id]))
			retired = retired.filter(func(value: WeakRef): return value.get_ref() != null)
			alive_peak = maxi(alive_peak, registry.emitters.size() + retired.size())
			attachments_peak = maxi(attachments_peak, attached)
			tracked_peak = maxi(tracked_peak, registry.emitters.size())
			if registry.has_method("diagnostics"):
				for key in ["walk_steps", "walk_depth", "attached", "attempted", "retired", "polled"]:
					peaks[key] = maxi(int(peaks.get(key, 0)), int(registry.diagnostics()[key]))
			if first_seen < 0 and registry.emitters.has(target.get_instance_id()):
				first_seen = frame
		stages.append({"listener_x": camera.position.x, "nearest_first_frame": first_seen,
			"nearest_tracked_at_end": registry.emitters.has(target.get_instance_id())})
	samples.sort()
	print("CREATURE_AUDIO_MEASUREMENT ", JSON.stringify({"engine": Engine.get_version_info().string,
		"nodes": 2048, "creatures": 402, "frames": samples.size(), "dt": 1.0 / 60.0,
		"scope": "registry and emitter CPU only; synthetic scene; no rendering or FPS claim",
		"max_us": samples.back(), "p95_us": samples[int((samples.size()-1)*0.95)],
		"median_us": samples[samples.size()/2], "sum_us": samples.reduce(func(a: int, b: int): return a+b, 0),
		"tracked_peak": tracked_peak, "attachments_peak": attachments_peak, "alive_observers_peak": alive_peak,
		"bounded_peaks": peaks, "stages": stages}))
	registry.clear()
	scene.queue_free()
	await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self, 0)
