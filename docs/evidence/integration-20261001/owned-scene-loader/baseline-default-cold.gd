extends SceneTree
var candidates: Array[int] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
 var count: int = 3000
 var preserved: int = 0
 for i in range(count):
  var marker: int = _marker_id()
  var err: Error = ResourceLoader.load_threaded_request("res://empty%d.tscn" % i, "PackedScene")
  if err != OK: push_error("Request failed"); quit(1); return
  var candidate: int = marker + (1 << 24)
  var scene: PackedScene = ResourceLoader.load_threaded_get("res://empty%d.tscn" % i)
  if scene == null: push_error("Get failed"); quit(1); return
  candidates.append(candidate)
  scene = null
 for i in range(4): await process_frame
 for id: int in candidates:
  if is_instance_id_valid(id):
   preserved += 1
   print("NATIVE_PRESERVED ", id)
 print("NORMAL_GET_RACE_PROBE requests=", count, " preserved_candidates=", preserved, " pending=", ResourceLoader.load_threaded_get_status("res://empty.tscn"))
 quit()
func _marker_id() -> int:
 var marker := RefCounted.new()
 return marker.get_instance_id()
