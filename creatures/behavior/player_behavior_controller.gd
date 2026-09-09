extends Node

const MAX_STAMINA: float = 100.0
const BITE_COST: float = 12.0
const RECOVERY_PER_SECOND: float = 15.0
const RECOVERY_DELAY: float = 0.8

var player: Node3D
var stamina: float = MAX_STAMINA
var recovery_delay: float = 0.0
var _befriending: bool = false
var _target: Node
var _hud: Label
var _hud_timer: float = 0.0
var _feedback_timer: float = 0.0


func _ready() -> void:
	name = "BehaviorController"
	# Clear held interactions when any menu owns the pause. Recovery still uses
	# _active(), so no gameplay time advances while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = get_parent()
	player.respawned.connect(reset_stamina)
	player.died.connect(func() -> void: _befriending = false)
	_hud = Label.new()
	_hud.name = "BehaviorActions"
	_hud.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hud.offset_left = -340
	_hud.offset_right = 340
	_hud.offset_top = -126
	_hud.offset_bottom = -20
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_theme_font_size_override("font_size", 17)
	_hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_hud.add_theme_constant_override("shadow_offset_x", 2)
	_hud.add_theme_constant_override("shadow_offset_y", 2)
	player.get_node("HUD").add_child(_hud)
	_refresh_hud()


func _active() -> bool:
	var flow := get_node_or_null("/root/SessionFlow")
	if flow != null and flow.loading: return false
	return not get_tree().paused and is_instance_valid(player) and not player.is_dead and player.is_physics_processing() and player.is_processing() and get_node("/root/GameState").current_phase == 0


func _unhandled_input(event: InputEvent) -> void:
	if not _active() or not event is InputEventKey or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key == KEY_F and not event.echo and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
		_befriending = event.pressed
		if event.pressed:
			_target = find_target()
		get_viewport().set_input_as_handled()
	elif key == KEY_H and event.pressed and not event.echo and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
		var target: Node = find_target()
		if target != null:
			var result: Dictionary = target.get_node("SocialBehavior").help(player)
			if not result.get("ok", false):
				player.show_gameplay_message(result.get("message", "Helfen momentan nicht möglich."))
		else:
			player.show_gameplay_message("Keine Kreatur in Sichtweite.")
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_hud.visible = _active()
	if not _active():
		_befriending = false
		return
	advance_recovery(delta)
	_feedback_timer = maxf(_feedback_timer - delta, 0.0)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not Input.is_physical_key_pressed(KEY_F) and not Input.is_key_pressed(KEY_F):
		_befriending = false
	if _befriending:
		if not is_instance_valid(_target) or _target != find_target():
			_befriending = false
		else:
			var result: Dictionary = _target.get_node("SocialBehavior").befriend(player, minf(delta, 0.25))
			if not result.get("ok", false):
				if _feedback_timer <= 0.0:
					player.show_gameplay_message(result.get("message", "Befreunden nicht möglich."))
					_feedback_timer = 2.0
				_befriending = false
			elif result.get("completed", false):
				_befriending = false
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.12
		_refresh_hud()


func find_target() -> Node:
	if not player.has_method("_find_wildlife_target"):
		return null
	var target: Node = player._find_wildlife_target(6.0, 65.0, true)
	if target == null or not target.has_node("SocialBehavior") or target.is_dead:
		return null
	return target


func spend_bite() -> bool:
	if get_node("/root/GameState").current_phase != 0:
		return true
	if stamina < BITE_COST:
		player.show_gameplay_message("Zu wenig Ausdauer · kurz erholen lassen.")
		return false
	stamina -= BITE_COST
	recovery_delay = RECOVERY_DELAY
	return true


func advance_recovery(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var recovered_time: float = maxf(delta - recovery_delay, 0.0)
	recovery_delay = maxf(recovery_delay - delta, 0.0)
	stamina = minf(stamina + recovered_time * RECOVERY_PER_SECOND * player.get_behavior_multiplier("stamina_recovery"), MAX_STAMINA)


func reset_stamina() -> void:
	stamina = MAX_STAMINA
	recovery_delay = 0.0
	_befriending = false


func export_state() -> Dictionary:
	return {"stamina": stamina, "recovery_delay": recovery_delay}


func import_state(data: Dictionary) -> void:
	stamina = clampf(float(data.get("stamina", MAX_STAMINA)), 0.0, MAX_STAMINA)
	recovery_delay = clampf(float(data.get("recovery_delay", 0.0)), 0.0, RECOVERY_DELAY)
	_befriending = false
	_target = null


func _refresh_hud() -> void:
	if _hud == null:
		return
	_hud.text = "Ausdauer %d / 100  ·  F halten: Befreunden  ·  H: Helfen  ·  K: Skilltree" % roundi(stamina)
	var target: Node = find_target()
	if target == null:
		_hud.text += "\nNähere dich einer Kreatur und richte die Kamera auf sie."
		return
	var data: Dictionary = target.get_node("SocialBehavior").entry()
	var relation: String = {"wild": "Wild", "ally": "Befreundet", "hostile": "Feindlich"}[data["relation"]]
	var name_text: String = target.get_display_name() if target.has_method("get_display_name") else "Kreatur"
	_hud.text += "\n%s · %s · Vertrauen %d %% · Gesundheit %d %%" % [name_text, relation, roundi(data["trust"]), roundi(float(data["health_ratio"]) * 100.0)]
	if data["need_origin"] in ["environment", "third_party"] and not data["player_harmed"]:
		_hud.text += "\nVerletzt · H: Nahrung teilen (12 Sättigung; bis 3,6 m)"
	elif data["relation"] == "wild":
		_hud.text += "\nF halten · Vertrauen aufbauen (bis 6 m)"
	elif data["relation"] == "ally":
		_hud.text += "\nDiese Kreatur vertraut dir und flieht nicht vor dir."
