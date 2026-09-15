extends RefCounted
## Interactive resources use the same V9 planet/biome palette as the ecosystem.
## Geometry is instance-seeded; a harvest only changes the separate fruit mesh.
const Voxels = preload("res://world/visuals/scenery/resource_voxel_mesh.gd")
const Flora = preload("res://world/visuals/scenery/flora_species_factory_v9.gd")
const FORMS: Array[String] = ["bramble", "upright", "tiered", "fan", "arch", "cushion"]

static func species(profile: Dictionary, biome: String, seed_value: int) -> Dictionary:
	return Flora.create_species_variant(profile, biome, "dense_bush_v2", posmod(seed_value, 6))

static func forage(seed_value: int, span: float, tall: float, count: int, voxel: float,
	gap: float, profile: Dictionary, biome: String) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var style: Dictionary = species(profile, biome, seed_value)
	var palette: Dictionary = style.palette
	var form: int = posmod(seed_value, FORMS.size())
	var cell: Vector3 = Vector3.ONE * voxel * 0.36
	var crowns: Array = []
	var yaw: Basis = Basis(Vector3.UP, random.randf() * TAU)
	var stretch := Vector3(random.randf_range(0.85, 1.05), 1.0, random.randf_range(0.85, 1.05))
	match form:
		0: # Broad, low branching bramble.
			for i in range(5):
				var angle: float = i * TAU / 5.0
				crowns.append([Vector3(cos(angle)*0.42, 0.40, sin(angle)*0.42), Vector3(0.37,0.30,0.37)])
		1: # Narrow vertical crowns with exposed stems.
			for i in range(3):
				var angle: float = i * TAU / 3.0
				crowns.append([Vector3(cos(angle)*0.35, 0.58, sin(angle)*0.35), Vector3(0.23,0.40,0.23)])
		2: # Stepped whorls, reducing toward the tip.
			for layer in range(3):
				for i in range(3):
					var angle: float = i * TAU / 3.0 + layer * 0.7
					var width: float = 0.43 - layer * 0.12
					crowns.append([Vector3(cos(angle)*width, 0.28+layer*0.28, sin(angle)*width), Vector3(width,0.16,width)])
		3: # A flat fan, visibly different from a circular shrub.
			for i in range(5):
				crowns.append([Vector3((i-2)*0.28, 0.72-absf(i-2)*0.12, 0), Vector3(0.26,0.25,0.22)])
		4: # Two rising branches with an open arch below the crown.
			for i in range(7):
				var angle: float = float(i) * PI / 6.0
				crowns.append([Vector3(cos(angle)*0.56, 0.32+sin(angle)*0.48, 0), Vector3(0.26,0.20,0.32)])
		5: # Ground-hugging cushion, several offset pads.
			for i in range(3):
				var angle: float = i * TAU / 3.0
				crowns.append([Vector3(cos(angle)*0.27, 0.25, sin(angle)*0.27), Vector3(0.50,0.22,0.50)])
	var cells: Dictionary = {}
	var leaves: Dictionary = {}
	var low: Color = palette.get("foliage_shadow", Color("294c36"))
	var high: Color = palette.get("foliage_highlight", Color("8daa62"))
	var bark: Color = palette.get("bark_base", Color("705037"))
	for crown: Array in crowns:
		var center: Vector3 = yaw * (crown[0] * Vector3(span,tall,span) * stretch)
		center.y *= random.randf_range(0.91, 1.06)
		var radii: Vector3 = crown[1] * Vector3(span,tall,span) * random.randf_range(0.88, 1.06)
		var root: Vector3 = Vector3(signf(crown[0].x)*span*0.45, cell.y*0.5, 0) if form == 4 else Vector3(0,cell.y*0.5,0)
		Voxels.line(cells, yaw * root, center, cell, bark)
		var reach := Vector3i((radii / cell).ceil())
		var origin := Vector3i((center / cell).round())
		for x in range(-reach.x, reach.x+1):
			for y in range(-reach.y, reach.y+1):
				for z in range(-reach.z, reach.z+1):
					var key: Vector3i = origin + Vector3i(x,y,z)
					var point: Vector3 = Vector3(key) * cell
					var distance: float = ((point-center)/radii).length_squared()
					if point.y < cell.y*1.5 or distance > 1.0: continue
					if distance > 0.70 and random.randf() < gap: continue
					leaves[key] = low.lerp(high, clampf(point.y/tall*0.8+random.randf_range(-0.06,0.12), 0.0, 1.0))
	cells.merge(leaves, true)
	var candidates: Array[Vector3] = []
	for key: Vector3i in leaves:
		var point: Vector3 = Vector3(key) * cell
		var outward: Vector3 = Vector3(point.x,0,point.z).normalized()
		if not cells.has(key + Vector3i((outward*1.5).round())):
			candidates.append(point + outward * cell.x * 0.85)
	var fruit: Dictionary = {}
	var fruit_cell: Vector3 = cell * 0.65
	var fruit_palette: Array[Color] = [Color("ba455d"), Color("dda34b"), Color("657fb7"), Color("db7544"), Color("9f599e")]
	var fruit_color: Color = fruit_palette[posmod(int(style.species_seed / 7), fruit_palette.size())]
	for i in range(mini(count, candidates.size())):
		var selected: int = random.randi_range(0, candidates.size()-1)
		var point: Vector3 = candidates[selected]
		candidates.remove_at(selected)
		for offset in [Vector3.ZERO, Vector3(0.6,-0.8,0.1), Vector3(-0.6,-0.8,-0.1), Vector3(0,-1.6,0)]:
			fruit[Vector3i(((point + offset*fruit_cell)/fruit_cell).round())] = fruit_color.lightened(random.randf_range(-0.06,0.16))
	return {"foliage": Voxels.build(cells, cell), "fruit": Voxels.build(fruit, fruit_cell),
		"form": FORMS[form], "species_id": style.species_id, "occupied_cells": cells.size()}

static func nest(seed_value: int, radius: float, voxel: float, strands: int, layers: int,
	gap: float, profile: Dictionary, biome: String) -> ArrayMesh:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var palette: Dictionary = species(profile, biome, seed_value).palette
	var bark: Color = palette.get("bark_base", Color("795740"))
	var moss: Color = palette.get("foliage_base", Color("58714a"))
	var straw: Color = Color("b49a64").lerp(bark.lightened(0.28), 0.22)
	var cell := Vector3(voxel*0.24, voxel*0.18, voxel*0.24)
	var cells: Dictionary = {}
	var ellipse := Vector3(random.randf_range(0.91,1.06), 1, random.randf_range(0.91,1.06))
	var yaw: Basis = Basis(Vector3.UP, random.randf()*TAU)
	# A shallow cupped bed, with flecks and short interwoven fibers.
	var reach: int = ceili(radius / cell.x)
	for x in range(-reach,reach+1):
		for z in range(-reach,reach+1):
			var distance: float = Vector2(x,z).length()*cell.x/radius
			if distance > 0.93: continue
			var height: int = 1 + floori(pow(distance,3)*3)
			var point: Vector3 = yaw * (Vector3(x*cell.x,height*cell.y,z*cell.z)*ellipse)
			var key := Vector3i((point/cell).round())
			cells[key] = straw.darkened(random.randf_range(0.10,0.32))
	for i in range(strands*3):
		var angle: float = random.randf()*TAU
		var center := Vector3(cos(angle),0,sin(angle))*random.randf_range(0.1,0.78)*radius
		center.y = cell.y*(2.2+pow(center.length()/radius,3)*3)
		var direction: Vector3 = Vector3(cos(angle+1.4),0,sin(angle+1.4))*random.randf_range(0.07,0.20)*radius
		if random.randf() >= gap:
			Voxels.line(cells, yaw*((center-direction)*ellipse), yaw*((center+direction)*ellipse), cell, straw.lightened(random.randf_range(-0.1,0.16)))
	# Staggered tangential branch segments form a woven rim, with a low entrance.
	for layer in range(layers+2):
		for i in range(strands):
			var angle: float = (i+layer*0.45)*TAU/strands
			if layer > 0 and sin(angle) > 0.88: continue
			var r: float = radius*random.randf_range(0.88,1.02)
			var center := Vector3(cos(angle)*r, (layer+1.0)*voxel*0.42, sin(angle)*r)
			var tangent := Vector3(-sin(angle),random.randf_range(-0.14,0.14),cos(angle))
			var half_length: float = radius*random.randf_range(0.17,0.29)
			for thickness in range(2):
				var lift := Vector3.UP*thickness*cell.y
				Voxels.line(cells, yaw*((center-tangent*half_length+lift)*ellipse), yaw*((center+tangent*half_length+lift)*ellipse), cell, bark.lightened(random.randf_range(0.02,0.24)))
	# Local leaves caught in the lower rim tie it to the planet's vegetation.
	for i in range(strands/2):
		var angle: float = random.randf()*TAU
		var center: Vector3 = yaw*(Vector3(cos(angle)*radius,cell.y*2,sin(angle)*radius)*ellipse)
		for x in range(-1,2):
			for z in range(-1,2):
				cells[Vector3i((center/cell).round())+Vector3i(x,0,z)] = moss.lightened(random.randf_range(-0.08,0.12))
	return Voxels.build(cells,cell)
