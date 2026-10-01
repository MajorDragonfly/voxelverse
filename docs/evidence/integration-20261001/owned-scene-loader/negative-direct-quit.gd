extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
 var flow: Node = root.get_node("SessionFlow")
 var err: Error = flow._scene_load.begin("res://main/spherical_campaign.tscn")
 print("DIRECT_QUIT_ACTIVE error=", err, " active=", flow._scene_load.is_active(), " ready=", flow._scene_load.is_ready())
 quit()
