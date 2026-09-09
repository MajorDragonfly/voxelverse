extends RefCounted
## Explicit preload dependencies keep every sound in exported builds.
const SOUNDS := {
	&"step_grass": [preload("res://audio/assets/step_grass_0.wav"), preload("res://audio/assets/step_grass_1.wav"), preload("res://audio/assets/step_grass_2.wav")],
	&"step_sand": [preload("res://audio/assets/step_sand_0.wav"), preload("res://audio/assets/step_sand_1.wav"), preload("res://audio/assets/step_sand_2.wav")],
	&"step_stone": [preload("res://audio/assets/step_stone_0.wav"), preload("res://audio/assets/step_stone_1.wav"), preload("res://audio/assets/step_stone_2.wav")],
	&"step_snow": [preload("res://audio/assets/step_snow_0.wav"), preload("res://audio/assets/step_snow_1.wav"), preload("res://audio/assets/step_snow_2.wav")],
	&"step_wood": [preload("res://audio/assets/step_wood_0.wav"), preload("res://audio/assets/step_wood_1.wav"), preload("res://audio/assets/step_wood_2.wav")],
	&"step_water": [preload("res://audio/assets/step_water_0.wav"), preload("res://audio/assets/step_water_1.wav"), preload("res://audio/assets/step_water_2.wav")],
	&"jump": [preload("res://audio/assets/jump.wav")],
	&"land": [preload("res://audio/assets/land.wav")],
	&"splash": [preload("res://audio/assets/splash.wav")],
	&"swim": [preload("res://audio/assets/swim.wav")],
	&"ui_confirm": [preload("res://audio/assets/ui_confirm.wav")],
	&"ui_back": [preload("res://audio/assets/ui_back.wav")],
	&"discovery": [preload("res://audio/assets/discovery.wav")],
	&"wind_loop": [preload("res://audio/assets/wind_loop.wav")],
	&"foliage_loop": [preload("res://audio/assets/foliage_loop.wav")],
	&"water_loop": [preload("res://audio/assets/water_loop.wav")],
	&"underwater_loop": [preload("res://audio/assets/underwater_loop.wav")],
}
