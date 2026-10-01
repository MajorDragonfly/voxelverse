extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
 var count: int = 3000
 for i in range(count):
  var task := Thread.new()
  var err: Error = task.start(_load_scene.bind("res://empty%d.tscn" % i))
  if err != OK: push_error("Thread failed"); quit(1); return
  var scene: PackedScene = task.wait_to_finish()
  if scene == null: push_error("Load failed"); quit(1); return
  scene = null
  task = null
 for i in range(4): await process_frame
 print("OWNED_THREAD_DEFAULT_COLD completed=", count)
 quit()
static func _load_scene(path: String) -> PackedScene:
 return ResourceLoader.load(path, "PackedScene") as PackedScene
