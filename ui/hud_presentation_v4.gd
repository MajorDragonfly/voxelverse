extends "res://ui/hud_presentation.gd"

# Gameplay HUD V4 keeps only survival state and the reticle. World seed,
# coordinates, temperature, moisture and shortcut diagnostics belong in a
# dedicated debug screen rather than the normal play view.


func _process(_delta: float) -> void:
	pass


func _install_hud_presentation() -> void:
	if _player == null:
		return
	_hud = _player.get_node_or_null("HUD") as CanvasLayer
	if _hud == null:
		return

	_style_status_panel()
	_create_reticle()


func _update_world_label() -> void:
	pass
