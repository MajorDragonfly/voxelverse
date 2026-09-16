extends RefCounted
## One fixed shoulder and one connected moving voxel surface per wing.
const Catalog = preload("res://creatures/catalog/creature_wing_catalog.gd")
const Voxels = preload("res://creatures/editor/creature_voxel_mesh.gd")
const CACHE_LIMIT: int = 24
static var _cache: Dictionary = {}

static func articulation(id: String) -> Array[Dictionary]:
	if Catalog.get_profile(id).is_empty(): return []
	return [{"channel": "wing", "prefixes": ["WingSurface"], "pivot": Vector3.ZERO, "axis": Vector3.BACK, "degrees": 48.0}]

static func legacy_voxels(id: String, revision: int = 1) -> Array:
	if Catalog.get_profile(id, revision).is_empty(): return []
	return [{"position": Vector3(0.82, 0.03, 0.18), "size": Vector3(2.0, 0.28, 1.36), "color": Color("bca57c")}]

static func outline(id: String) -> PackedVector2Array:
	match id:
		"wings_broad_feather": return PackedVector2Array([Vector2(-0.09,-0.10),Vector2(0.2,-0.27),Vector2(0.7,-0.36),Vector2(1.13,-0.20),Vector2(1.38,0.03),Vector2(1.12,0.26),Vector2(0.45,0.32),Vector2(0.05,0.13)])
		"wings_slender_feather": return PackedVector2Array([Vector2(-0.09,-0.09),Vector2(0.28,-0.16),Vector2(0.96,-0.24),Vector2(1.72,-0.16),Vector2(1.60,0.08),Vector2(0.65,0.23),Vector2(0.05,0.12)])
		"wings_bat_membrane": return PackedVector2Array([Vector2(-0.09,-0.10),Vector2(0.44,-0.36),Vector2(1.52,-0.43),Vector2(1.20,-0.12),Vector2(1.38,0.23),Vector2(0.96,0.16),Vector2(0.96,0.64),Vector2(0.65,0.38),Vector2(0.50,0.78),Vector2(0.24,0.32),Vector2(0.02,0.16)])
		"wings_long_insect": return PackedVector2Array([Vector2(-0.09,-0.07),Vector2(0.22,-0.10),Vector2(0.60,-0.20),Vector2(1.30,-0.22),Vector2(1.62,-0.12),Vector2(1.73,0.02),Vector2(1.60,0.16),Vector2(1.20,0.24),Vector2(0.55,0.18),Vector2(0.18,0.08),Vector2(-0.09,0.07)])
	return PackedVector2Array()

static func feathers(id: String) -> Array:
	var result: Array = []
	if id not in ["wings_broad_feather", "wings_slender_feather"]: return result
	for index in range(8):
		var t: float = float(index) / 7.0
		if id == "wings_broad_feather": result.append([Vector2(0.20+t*1.00,-0.08),Vector2(0.25+t*1.25,0.40+sin(t*PI)*0.34),0.085])
		else: result.append([Vector2(0.23+t*1.23,-0.09),Vector2(0.36+t*1.38,0.33+sin(t*PI)*0.10),0.058])
	return result

static func meshes(id: String, skin: Color, accent: Color, shape: Vector3 = Vector3.ONE, side: float = 1, revision: int = 1) -> Array[ArrayMesh]:
	if Catalog.get_profile(id, revision).is_empty() or not shape.is_finite() or shape.x < 0.4 or shape.y < 0.4 or shape.z < 0.4 or shape.x > 2.5 or shape.y > 2.5 or shape.z > 2.5: return []
	var key: String = "%s:%s:%s:%s:%s" % [id, skin, accent, shape, side < 0]
	if _cache.has(key): return _cache[key]
	var step: float = maxf(0.020 * minf(shape.x,minf(shape.y,shape.z)), pow(2.0*1.4*0.28*shape.x*shape.y*shape.z/160000.0,1.0/3.0))
	var polygon: PackedVector2Array = outline(id)
	var plume: Array = feathers(id)
	var surfaces: Array[ArrayMesh] = []
	for socket: bool in [true, false]:
		var cells: Dictionary = {}
		var low: Vector3 = Vector3(-0.18,-0.14,-0.16) * shape if socket else Vector3(-0.10,-0.08,-0.50) * shape
		var high: Vector3 = Vector3(0.18,0.14,0.16) * shape if socket else Vector3(1.82,0.16,0.86) * shape
		for x in range(floori(low.x/step),ceili(high.x/step)):
			for z in range(floori(low.z/step),ceili(high.z/step)):
				var p := Vector2((x+0.5)*step/shape.x,(z+0.5)*step/shape.z)
				var tint: Color = skin
				var occupied: bool = socket or Geometry2D.is_point_in_polygon(p,polygon)
				var vein: bool = false
				for index in range(plume.size()):
					var f: Array = plume[index]
					var t: float = clampf((p-f[0]).dot(f[1]-f[0])/(f[1]-f[0]).length_squared(),0,1)
					if p.distance_to(f[0].lerp(f[1],t)) < float(f[2])*sqrt(maxf(0,1-pow(t,4))):
						occupied = true
						tint = skin.lerp(accent,0.14+0.10*(index%2))
						if p.distance_to(f[0].lerp(f[1],t)) < 0.011: tint = tint.lightened(0.16)
				if id == "wings_bat_membrane":
					for tip: Vector2 in [Vector2(1.52,-0.43),Vector2(1.38,0.23),Vector2(0.96,0.64),Vector2(0.50,0.78)]:
						if _line_distance(p,Vector2(0.03,0),tip) < maxf(0.030,step*0.8/minf(shape.x,shape.z)):
							vein = true
							occupied = true
					tint = skin.lightened(0.10) if vein else skin.lerp(accent,0.55).darkened(0.12)
				elif id == "wings_long_insect":
					vein = _line_distance(p,Vector2.ZERO,Vector2(1.67,0.01)) < 0.012
					for index in range(5):
						var start := Vector2(0.30+index*0.22,0)
						if _line_distance(p,start,start+Vector2(0.20,-0.18)) < 0.010 or _line_distance(p,start,start+Vector2(0.16,0.19)) < 0.010: vein = true
					tint = accent.lightened(0.10) if vein else skin.lerp(Color("d5e7d8"),0.60)
				if not occupied: continue
				var center_y: float = sin(clampf(p.x/1.75,0,1)*PI)*0.065*shape.y
				var half: float = maxf((0.038 if vein or not plume.is_empty() else 0.025)*shape.y,step*0.60)
				var bottom: float = low.y if socket else center_y-half
				var top: float = high.y if socket else center_y+half
				for y in range(floori(bottom/step),ceili(top/step)):
					var v := Vector3((x+0.5)*step/shape.x,(y+0.5)*step/shape.y,(z+0.5)*step/shape.z)
					if socket and (v/Vector3(0.18,0.14,0.16)).length_squared() > 1: continue
					if not socket and absf((y+0.5)*step-center_y) > half: continue
					var cell := Vector3i(x,y,z)
					if side < 0: cell.x = -cell.x-1
					cells[cell] = (skin if socket else tint).darkened(maxf(0,Voxels.shade(cell)))
		surfaces.append(Voxels.from_cells(cells,step,true))
	if _cache.size() >= CACHE_LIMIT: _cache.erase(_cache.keys()[0])
	_cache[key] = surfaces
	return surfaces

static func _line_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var t: float = clampf((p-a).dot(b-a)/(b-a).length_squared(),0,1)
	return p.distance_to(a.lerp(b,t))
