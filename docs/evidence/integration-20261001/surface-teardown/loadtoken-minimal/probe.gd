extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var mode: String = OS.get_cmdline_user_args()[0]
	var status: Error = ResourceLoader.load_threaded_request("res://empty.tscn", "PackedScene")
	if status != OK: push_error("Request failed"); quit(1); return
	var deadline: int = Time.get_ticks_msec() + 5000
	while ResourceLoader.load_threaded_get_status("res://empty.tscn") == ResourceLoader.THREAD_LOAD_IN_PROGRESS and Time.get_ticks_msec() < deadline: await process_frame
	print("LOADTOKEN_STATUS before=", ResourceLoader.load_threaded_get_status("res://empty.tscn"), " mode=", mode)
	if mode == "consume":
		var scene: PackedScene = ResourceLoader.load_threaded_get("res://empty.tscn")
		if scene == null: push_error("Get failed"); quit(1); return
		print("LOADTOKEN_STATUS after=", ResourceLoader.load_threaded_get_status("res://empty.tscn"))
	for i in range(4): await process_frame
	quit()
