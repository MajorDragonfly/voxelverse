extends RefCounted
## JSON scalar doubles can change by a final decimal digit. Native Vector3/
## Color values, strings, collection structure and integral values stay exact.
static func native_equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not native_equal(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in range(a.size()):
			if not native_equal(a[index], b[index]): return false
		return true
	if (a is int or a is float) and (b is int or b is float):
		return a == b or absf(float(a) - float(b)) <= 1e-12
	return typeof(a) == typeof(b) and a == b
