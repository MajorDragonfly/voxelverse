extends SceneTree
## Real signal delivery, voice allocation, lifecycle and optional integration.

const PROFILE = preload("res://audio/runtime/creature_voice_profile.gd")
var audio: Node
var failures: Array[String] = []
var heard: Array[StringName] = []
var scene: Node3D

class Creature extends Node3D:
	signal health_changed(current_health: float, maximum_health: float)
	signal creature_defeated(creature: Node)
	signal died
	signal respawned
	signal creature_attacked(target: Node, damage: float)
	signal audio_event(event: StringName)
	var species_seed := 42
	var ecological_role := "grazer"
	var current_health := 40.0
	var maximum_health := 40.0
	var is_dead := false
	var blueprint := {"body": {"shape": Vector3(1.3, 1, 2.1), "scale": 1.0}}

class LegacyCreature extends Node3D:
	var current_health := 40.0
	var maximum_health := 40.0
	var is_dead := false

class ProgressionFixture extends Node:
	signal species_discovered(key: String, display_name: String)
	signal behavior_node_purchased(node_id: String)


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, reason: String) -> void:
	if not value:
		failures.append(reason)
		push_error(reason)


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func run() -> void:
	audio = root.get_node("AudioManager")
	audio.creature_sound_played.connect(func(_id: int, event: StringName, _pitch: float, _family: String): heard.append(event))
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	check(PROFILE.build(42, "grazer", 1.0) == PROFILE.build(42, "grazer", 1.0), "Stable species identity")
	check(PROFILE.build(42, "grazer", 0.4).pitch > PROFILE.build(42, "grazer", 2.5).pitch, "Small creatures have higher pitch")
	check(PROFILE.build(42, "grazer").family != PROFILE.build(42, "predator").family, "Roles have different timbres")
	var creature := Creature.new()
	scene.add_child(creature)
	creature.position.z = -5
	creature.add_to_group(&"wildlife")
	await frames(40)
	var emitter: Node = audio.creatures.emitters.get(creature.get_instance_id())
	check(emitter != null, "Automatic attachment to wildlife")
	if emitter == null:
		await preload("res://core/runtime_shutdown.gd").finish(self, 1)
		return
	check(heard.is_empty(), "No startup chorus or false injury")
	emitter._call_clock = 0.0
	await frames(8)
	check(heard.count(&"contact") == 1, "Automatic calls reach the spatial sound API")
	emitter.automatic_calls = false
	check(audio.creatures.attach(creature) == emitter, "Repeated attachment stays singular")
	creature.current_health = 35
	creature.health_changed.emit(35, 40)
	await frames(12)
	check(heard.count(&"hurt") == 1, "Health signal plus observer emits only one hurt")
	creature.current_health = 40
	creature.health_changed.emit(40, 40)
	creature.maximum_health = 20
	creature.current_health = 20
	creature.health_changed.emit(20, 20)
	await frames(24)
	check(heard.count(&"hurt") == 1, "Healing and changed max health are not damage")
	creature.audio_event.emit(&"warn")
	creature.audio_event.emit(&"warn")
	check(heard.count(&"warn") == 1, "Repeated warning is debounced")
	creature.creature_attacked.emit(creature, 3.0)
	check(heard.count(&"attack") == 1, "Actual attack signal drives attack sound")
	creature.current_health = 0
	creature.is_dead = true
	creature.health_changed.emit(0, 20)
	creature.creature_defeated.emit(creature)
	creature.died.emit()
	await frames(20)
	check(heard.count(&"death") == 1, "Multiple death signals produce one sound")
	check(not audio.play_creature(&"contact", creature), "Corpses cannot call")
	creature.is_dead = false
	creature.current_health = 20
	creature.respawned.emit()
	await frames(22)
	check(audio.play_creature(&"friend", creature), "Respawn permits live reactions again")
	creature.position.z = -70
	check(not audio.play_creature(&"hurt", creature), "Distant creatures do not allocate voices")
	creature.position.z = -5
	paused = true
	check(not audio.play_creature(&"attack", creature), "Pause suppresses creature events")
	paused = false
	var legacy := LegacyCreature.new()
	scene.add_child(legacy)
	legacy.position.z = -3
	var legacy_emitter: Node = audio.creatures.attach(legacy)
	legacy_emitter.automatic_calls = false
	legacy.current_health -= 5
	await frames(12)
	check(heard.count(&"hurt") == 2, "Legacy health observation drives injury without new signals")
	# A contact sound may be displaced to preserve important feedback.
	audio.stop_world()
	for i in 16:
		check(audio.play_world(&"creature_throat_contact", Vector3(0, 0, -5), -8, 1, 1000 + i, 0), "Fill bounded ambient pool")
	check(audio.play_world(&"land", Vector3(0, 0, -5), 0, 1, 2000, 1), "Movement can displace an ambient call")
	check(audio.play_world(&"creature_rasp_hurt", Vector3(0, 0, -5), 0, 1, 3000, 2), "Critical feedback can displace lower priority")
	check(audio._voices.size() == 16, "Voice pool never grows")
	audio.stop_world()
	var id := creature.get_instance_id()
	creature.queue_free()
	await frames(40)
	check(not audio.creatures.emitters.has(id), "Destroyed creatures are pruned")
	# Exercise the real integration when progression is installed, and the
	# optional legacy contract when this package is tested independently.
	var progression: Node = root.get_node_or_null("ProgressionService")
	var fixture: bool = progression == null
	if fixture:
		progression = ProgressionFixture.new()
		progression.name = "ProgressionService"
		root.add_child(progression)
	await frames(35)
	audio.stop_ui()
	progression.species_discovered.emit("test-species", "Test species")
	var ui_playing := false
	for voice in audio._ui_voices:
		ui_playing = ui_playing or voice.playing
	check(not ui_playing if progression.has_method("has_species_scan") else ui_playing,
		"Scan-aware discovery waits for scanner completion; legacy discovery emits feedback")
	progression.behavior_node_purchased.emit("creature.social.approach")
	ui_playing = false
	for voice in audio._ui_voices:
		ui_playing = ui_playing or voice.playing
	check(ui_playing, "Successful real progression purchase produces feedback")
	if fixture:
		progression.queue_free()
	legacy.queue_free()
	await frames(40)
	check(audio.creatures.emitters.is_empty(), "All creature tracking released")
	audio.stop_ui()
	# Let the mixer release pending playbacks before the process shuts down.
	await create_timer(0.25).timeout
	print("CREATURE_AUDIO_RESULT ", JSON.stringify({"passed": failures.is_empty(), "failures": failures, "heard": heard}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
