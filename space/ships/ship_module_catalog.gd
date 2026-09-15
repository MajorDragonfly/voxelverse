extends RefCounted
## Local, versioned module definitions. Downloaded stats are never authoritative.
const REVISION: int = 1
const HULL := Color("74899d")
const DARK := Color("263d50")
const LIGHT := Color("beced9")
const ACCENT := Color("efb35c")
const GLASS := Color("5cd4de")

static func all() -> Dictionary:
	var result: Dictionary = {}
	for row: Array in [
		["hull_s", "Rumpf · Beiboot", "lander", Vector3(4, 2, 6), {"mass": 12, "structure": 1, "cost": 20}, HULL],
		["cockpit", "Cockpit", "lander", Vector3(4, 2, 2), {"mass": 3, "command": 1, "seats": 2, "draw": 2, "cost": 10}, GLASS],
		["drive_s", "Landungsantrieb", "lander", Vector3(4, 2, 2), {"mass": 5, "thrust": 80, "draw": 12, "cost": 15}, DARK],
		["reactor_s", "Kompaktreaktor", "lander", Vector3(2, 2, 2), {"mass": 4, "power": 30, "energy": 40, "cost": 18}, ACCENT],
		["battery_s", "Batteriemodul", "both", Vector3(2, 2, 2), {"mass": 3, "energy": 80, "cost": 10}, DARK],
		["cargo_s", "Frachtmodul · klein", "both", Vector3(4, 2, 4), {"mass": 4, "cargo": 12, "cost": 8}, LIGHT],
		["landing_gear", "Landegestell", "lander", Vector3(4, 2, 2), {"mass": 2, "landing": 1, "cost": 6}, DARK],
		["hull_l", "Expeditionsrumpf", "expedition", Vector3(12, 6, 24), {"mass": 180, "structure": 1, "cost": 200}, HULL],
		["bridge", "Kommandobrücke", "expedition", Vector3(8, 4, 6), {"mass": 20, "command": 1, "seats": 8, "draw": 10, "cost": 50}, GLASS],
		["drive_l", "Expeditionsantrieb", "expedition", Vector3(12, 6, 6), {"mass": 70, "thrust": 1500, "draw": 90, "cost": 100}, DARK],
		["reactor_l", "Hauptreaktor", "expedition", Vector3(6, 4, 6), {"mass": 40, "power": 240, "energy": 600, "cost": 80}, ACCENT],
		["cargo_l", "Frachtsektion", "expedition", Vector3(12, 6, 12), {"mass": 40, "cargo": 200, "cost": 60}, LIGHT],
		["hangar", "Beiboot-Hangar", "expedition", Vector3(16, 12, 20), {"mass": 100, "draw": 15, "cost": 120}, DARK],
		["laboratory", "Forschungslabor", "expedition", Vector3(6, 4, 6), {"mass": 25, "research": 1, "draw": 25, "cost": 80}, LIGHT],
		["habitat", "Besatzungsquartier", "expedition", Vector3(8, 6, 12), {"mass": 35, "seats": 12, "draw": 10, "cost": 50}, HULL],
	]:
		var id: String = row[0]
		var size: Vector3 = row[3]
		var geometry: Array = [_box(Vector3.ZERO, size, row[5])]
		if id == "hangar":
			# Interior is 12 x 8 x 16 m; the front is open. The outer box is
			# reserved for docking, so modules cannot occupy the bay volume.
			geometry = [_box(Vector3(-7, 0, 0), Vector3(2, 12, 20), HULL),
				_box(Vector3(7, 0, 0), Vector3(2, 12, 20), HULL),
				_box(Vector3(0, -5, 0), Vector3(12, 2, 20), DARK),
				_box(Vector3(0, 5, 0), Vector3(12, 2, 20), HULL),
				_box(Vector3(0, 0, 9), Vector3(12, 8, 2), DARK),
				_box(Vector3(0, -3.9, -8), Vector3(10, 0.2, 1), GLASS)]
		elif id.begins_with("drive"):
			geometry.append(_box(Vector3(0, 0, size.z * 0.5 - 0.1), Vector3(size.x * 0.8, size.y * 0.65, 0.2), GLASS))
		elif id in ["bridge", "cockpit"]:
			geometry = [_box(Vector3.ZERO, size, HULL),
				_box(Vector3(0, size.y * 0.1, -size.z * 0.5 + 0.1), Vector3(size.x * 0.85, size.y * 0.55, 0.2), GLASS)]
		elif id == "landing_gear":
			geometry = [_box(Vector3(0, 0.6, 0), Vector3(4, 0.8, 2), DARK),
				_box(Vector3(-1.5, -0.4, 0), Vector3(1, 1.2, 2), LIGHT),
				_box(Vector3(1.5, -0.4, 0), Vector3(1, 1.2, 2), LIGHT)]
		else:
			geometry.append(_box(Vector3(0, size.y * 0.5 - 0.1, 0), Vector3(size.x * 0.6, 0.2, size.z * 0.75), DARK))
		result[id] = {"id": id, "name": row[1], "role": row[2], "size": size,
			"stats": row[4], "geometry": geometry, "revision": REVISION}
		if id == "hangar": result[id]["bay_size"] = Vector3(12, 8, 16)
	return result

static func _box(position: Vector3, size: Vector3, color: Color) -> Dictionary:
	return {"position": position, "size": size, "color": color}
