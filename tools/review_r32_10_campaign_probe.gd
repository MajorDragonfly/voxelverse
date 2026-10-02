extends "res://core/diagnostics/spherical_creature_probe.gd"
## Normal SessionFlow world and naturally streamed animals; no invented actor,
## AI intent, relationship, spawn limit or survival override.
var output: String
var observations: Array[Dictionary] = []
var actions: Array[Dictionary] = []
var serial := 0
var saw_heart := false

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 1:
		push_error("Campaign output path required")
		await preload("res://core/runtime_shutdown.gd").finish(tree, 1)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	var path: String = saves.create_slot("R32-10 Zeichenbegegnung", 15838, Cube.MODE)
	await _open(path)
	if not _expect_world(): await _complete(); return
	var scene: Node3D = tree.current_scene
	await _until(func() -> bool: return scene.population.animals.size() >= 2, 25000)
	var actor: Node3D = await _aim_at_wildlife(scene)
	if actor == null:
		_expect(false, "No naturally streamed animal in the regular campaign")
		await _complete()
		return
	var player: Node3D = scene.player
	var social: Node = actor.get_node("SocialBehavior")
	var reached := false
	for index in range(4):
		var location: Dictionary = Space.address(self, actor.global_position)
		var direction := Vector3(cos(index * PI / 2.0), 0, sin(index * PI / 2.0))
		var offset: Vector3 = scene.adapter.frame_at(location) * direction * 3.0
		var place: Dictionary = scene.adapter.offset(location, offset)
		var ground: Dictionary = scene.adapter.sample(place)
		if ground.water: continue
		place.height = ground.height + 0.1
		player.place(place, -offset)
		await tree.physics_frame
		await tree.physics_frame
		await _until(func() -> bool: return Space.ground_ready(self, player.global_position) and player.is_on_floor(), 10000)
		if not is_instance_valid(actor): break
		if social.can_reach(player):
			reached = true
			break
	_expect(reached, "Actual campaign animal could not be reached through normal ground/visibility")
	if not reached: await _complete(); return
	for step in range(3):
		if not is_instance_valid(actor):
			_expect(false, "Real encounter animal unloaded")
			break
		var result: Dictionary = social.befriend(player, 0.1, social.social_status().playful)
		actions.append({"step": step, "result": result, "identity": actor.get_campaign_identity()})
		_expect(bool(result.get("ok", false)), "Real campaign social action rejected: " + str(result))
		if not result.get("ok", false): break
		await _record(scene, actor, ceili((maxf(0.7, float(social.response_remaining)) + 0.15) * 15.0))
	_expect(saw_heart, "No visible positive sign after the actual campaign friendship")
	if is_instance_valid(actor) and saw_heart:
		_expect(social.entry().relation == "ally", "Heart not backed by actual ally state")
	await _complete()

func _record(scene: Node3D, actor: Node3D, frames: int) -> void:
	for frame in range(frames):
		if not is_instance_valid(actor): return
		var camera: Camera3D = scene.player.camera
		camera.look_at(actor.get_node("CollisionShape3D").global_position, scene.player.up_direction)
		await tree.process_frame
		await RenderingServer.frame_post_draw
		var label: Label3D = actor._label
		saw_heart = saw_heart or (label.visible and label.text == "♥")
		var image: Image = tree.root.get_texture().get_image()
		_expect(image.save_png(output.path_join("frame_%04d.png" % serial)) == OK, "Campaign image save failed")
		observations.append({"frame": serial, "identity": actor.get_campaign_identity(),
			"camera": var_to_str(camera.global_transform), "fov": camera.fov,
			"player_location": scene.player.location(), "emotion": actor.get_node("ExpressionBehavior").emotion.state,
			"intent": actor.ai_state, "symbol": label.text, "visible": label.visible,
			"clock": state.campaign.data.elapsed_seconds,
			"sun": var_to_str(scene._atmosphere.sun.global_transform),
			"sun_energy": scene._atmosphere.sun.light_energy,
			"weather_sample": scene._atmosphere.campaign_sample,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
		serial += 1

func _complete() -> void:
	var file := FileAccess.open(output.path_join("campaign.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed": 15838, "source": "SessionFlow spherical campaign, natural population",
		"renderer": RenderingServer.get_current_rendering_method(), "device": RenderingServer.get_video_adapter_name(),
		"actions": actions, "observations": observations, "saw_heart": saw_heart, "failures": failures}, "\t"))
	file.close()
	for failure in failures: push_error(failure)
	print("R32_CAMPAIGN_SIGNS_PASSED" if failures.is_empty() else "R32_CAMPAIGN_SIGNS_FAILED")
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)
