extends RefCounted

const GROUND = preload("res://world/surface/visuals/living_ground.gdshader")
const WATER = preload("res://world/surface/visuals/living_water.gdshader")
const Cube = preload("res://world/space/cube_sphere.gd")
var ground: Array[ShaderMaterial] = []
var water: Array[ShaderMaterial] = []
var time: float = 0.0
var frozen: bool = false
var radius: float


func setup(terrain: Node) -> void:
	radius = terrain.surface.body.radius
	ground.assign([terrain.land_material, terrain._fade_land, terrain._old_land])
	water.assign([terrain.ocean_material, terrain._fade_water, terrain._old_water])
	var slots: Dictionary = terrain.surface.terrain.material_slots
	for material in ground:
		material.shader = GROUND
		material.set_shader_parameter("soil_color", slots.ground_dry.lerp(Color("71583d"), 0.6))
		material.set_shader_parameter("rock_color", slots.rock_base)
	for material in water:
		material.shader = WATER
		material.set_shader_parameter("deep_color", slots.water_deep)
		material.set_shader_parameter("shallow_color", slots.water_shallow)
	ground[2].set_shader_parameter("lod_retiring", true)
	water[2].set_shader_parameter("lod_retiring", true)
	ground[0].set_shader_parameter("lod_phase", 1.0)
	water[0].set_shader_parameter("lod_phase", 1.0)
	rebase(terrain.origin)


static func phase_at(origin: Array) -> Vector3:
	return Vector3(fposmod(origin[0], 128.0), fposmod(origin[1], 128.0), fposmod(origin[2], 128.0))


func rebase(origin: Array) -> void:
	var length: float = sqrt(origin[0] * origin[0] + origin[1] * origin[1] + origin[2] * origin[2])
	var up: Vector3 = Cube.vector(Cube.normalized(origin)) if length > 0.0 else Vector3.UP
	for material in ground + water:
		material.set_shader_parameter("origin_phase", phase_at(origin))
		material.set_shader_parameter("origin_up", up)
		material.set_shader_parameter("origin_height", length - radius)
		material.set_shader_parameter("body_radius", radius)


func advance(delta: float) -> void:
	if not frozen:
		time += delta
	for material in water:
		material.set_shader_parameter("surface_time", time)
