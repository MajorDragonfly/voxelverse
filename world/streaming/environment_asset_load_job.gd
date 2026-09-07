extends RefCounted

# ResourceLoader.load is synchronous on this owned worker. Main-thread callers
# poll/join the WorkerThreadPool task before using the PackedScene. In Godot 4.6.3
# a threaded loader can expose THREAD_LOAD_LOADED before its final token cleanup;
# joining our outer task keeps resource lifetime independent of that status.
var path: String
var scene: PackedScene


func run() -> void:
	scene = ResourceLoader.load(path, "PackedScene") as PackedScene
