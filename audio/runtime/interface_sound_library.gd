extends RefCounted
const SOUNDS := {
	&"scan_acquire": [preload("res://audio/assets/interface/scan_acquire.wav")],
	&"scan_abort": [preload("res://audio/assets/interface/scan_abort.wav")],
	&"order_move": [preload("res://audio/assets/interface/order_move.wav")],
	&"order_gather": [preload("res://audio/assets/interface/order_gather.wav")],
	&"order_attack": [preload("res://audio/assets/interface/order_attack.wav")],
	&"order_build": [preload("res://audio/assets/interface/order_build.wav")],
	&"order_wait": [preload("res://audio/assets/interface/order_wait.wav")],
	&"order_feed": [preload("res://audio/assets/interface/order_feed.wav")],
	# A new animal bond uses the existing milestone cue, with no discovery reward.
	&"order_tame": [preload("res://audio/assets/discovery.wav")],
	&"order_reject": [preload("res://audio/assets/interface/order_reject.wav")],
	&"scan_loop": [preload("res://audio/assets/interface/scan_loop.wav")],
}
