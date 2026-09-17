extends RefCounted
## Bounded plane raster shared by new fins/ears. Existing providers stay unchanged.
const Voxels = preload("res://creatures/editor/creature_voxel_mesh.gd")

static func axes(layout: String) -> Vector3i:
	return Vector3i(1,0,2) if layout == "ear" else (Vector3i(1,2,0) if layout == "dorsal" else Vector3i(0,2,1))

static func bounds(recipe: Dictionary) -> AABB:
	var a: Vector3i = axes(recipe.layout)
	var socket := Vector3(recipe.socket[0],recipe.socket[1],recipe.socket[2])
	var low: Vector3 = -socket
	var high: Vector3 = socket
	for pair: Array in recipe.outline:
		low[a.x] = minf(low[a.x],float(pair[0]) - 0.04)
		high[a.x] = maxf(high[a.x],float(pair[0]) + 0.04)
		low[a.y] = minf(low[a.y],float(pair[1]) - 0.04)
		high[a.y] = maxf(high[a.y],float(pair[1]) + 0.04)
	return AABB(low, high-low)

static func build(recipe: Dictionary, skin: Color, accent: Color, shape: Vector3, side: float) -> Array[ArrayMesh]:
	var a: Vector3i = axes(recipe.layout)
	var box: AABB = bounds(recipe)
	var step: float = maxf(0.02*minf(shape.x,minf(shape.y,shape.z)), pow(box.size.x*box.size.y*box.size.z*shape.x*shape.y*shape.z/90000.0,1.0/3.0))
	var socket := Vector3(recipe.socket[0],recipe.socket[1],recipe.socket[2])
	var cells: Dictionary = {}
	for x in range(floori(-socket.x*shape.x/step),ceili(socket.x*shape.x/step)):
		for y in range(floori(-socket.y*shape.y/step),ceili(socket.y*shape.y/step)):
			for z in range(floori(-socket.z*shape.z/step),ceili(socket.z*shape.z/step)):
				var cell := Vector3i(x,y,z)
				var p: Vector3 = (Vector3(cell)+Vector3.ONE*0.5)*step/shape/socket
				if p.length_squared() > 1: continue
				if side < 0: cell.x = -cell.x-1
				cells[cell] = skin.darkened(maxf(0,Voxels.shade(cell)))
	var result: Array[ArrayMesh] = [Voxels.from_cells(cells,step,true)]
	cells = {}
	var polygon := PackedVector2Array()
	for point: Array in recipe.outline: polygon.append(Vector2(point[0],point[1]))
	var span: float = shape[a.x]
	var breadth: float = shape[a.y]
	var thickness: float = shape[a.z]
	var pad: float = step*0.8/minf(span,breadth)
	var ear: bool = recipe.layout == "ear"
	for u in range(floori((box.position[a.x]-pad)*span/step),ceili((box.end[a.x]+pad)*span/step)):
		for v in range(floori((box.position[a.y]-pad)*breadth/step),ceili((box.end[a.y]+pad)*breadth/step)):
			var p := Vector2((u+0.5)*step/span,(v+0.5)*step/breadth)
			var edge: float = INF
			for i in range(polygon.size()): edge = minf(edge,distance(p,polygon[i],polygon[(i+1)%polygon.size()]))
			if not Geometry2D.is_point_in_polygon(p,polygon) and edge > pad: continue
			var ray: bool = false
			for tip_data: Array in recipe.rays:
				var tip := Vector2(tip_data[0],tip_data[1])
				var start := Vector2(0,tip.y*0.72) if recipe.layout == "dorsal" else Vector2(0.06,0)
				if distance(p,start,tip) < maxf(0.013,pad*0.65): ray = true
			var tint: Color = skin if ear else skin.lerp(accent,0.4 if ray else 0.22)
			if not ear and (ray or edge < 0.035): tint = tint.lightened(0.14)
			var curve: float = minf(absf(p.x),1.0)
			var center: float = (-0.06*curve - minf(edge,0.15)*0.35)*thickness if ear else (sin(clampf(p.x/1.5,0,1)*PI)*0.03*thickness if recipe.layout == "side" else 0.0)
			var half: float = maxf((0.042 if ear else lerpf(0.072,0.025,clampf(p.x/1.1,0,1)))*thickness,step*0.65)
			for w in range(floori((center-half)/step),ceili((center+half)/step)):
				if absf((w+0.5)*step-center) > half: continue
				var cell := Vector3i.ZERO
				cell[a.x] = u
				cell[a.y] = v
				cell[a.z] = w
				if side < 0: cell.x = -cell.x-1
				var color: Color = tint
				if ear and edge > 0.048 and p.length() > 0.16 and (w+0.5)*step < center:
					color = skin.lerp(Color("d3999a"),0.72).darkened(minf(edge,0.16)*0.8)
				cells[cell] = color.darkened(maxf(0,Voxels.shade(cell)))
	result.append(Voxels.from_cells(cells,step,true))
	return result

static func distance(p: Vector2, start: Vector2, end: Vector2) -> float:
	var t: float = clampf((p-start).dot(end-start)/(end-start).length_squared(),0,1)
	return p.distance_to(start.lerp(end,t))
