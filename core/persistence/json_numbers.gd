extends RefCounted
const LIMB_BITS: int = 26
const LIMB_BASE: int = 1 << LIMB_BITS
const LIMB_MASK: int = LIMB_BASE - 1
const MAX_FINITE: int = 0x7fefffffffffffff


static var _token_pattern: RegEx

## JSON owns syntax, strings and object semantics. Repair only scalar numbers
## from their original decimal tokens, in the parser's insertion order.
static func restore(value: Dictionary, text: String) -> Dictionary:
	if _token_pattern == null:
		_token_pattern = RegEx.new()
		_token_pattern.compile('"(?:[^"\\\\]|\\\\.)*"|(-?(?:0|[1-9][0-9]*)(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)|[{}]')
	var tokens: Array[String] = []
	var objects: Array[Dictionary] = []
	for found: RegExMatch in _token_pattern.search_all(text):
		var token: String = found.get_string()
		if token == "{": objects.append({})
		elif token == "}": objects.pop_back()
		elif token.begins_with('"'):
			var after: int = found.get_end()
			while after < text.length() and text[after] in [" ", "\t", "\r", "\n"]: after += 1
			if after < text.length() and text[after] == ":":
				var key: String = JSON.parse_string(token)
				# A replacement key retains its original insertion position;
				# token counts alone cannot detect that reordering.
				if objects[-1].has(key): return value
				objects[-1][key] = true
		var number: String = found.get_string(1)
		if not number.is_empty(): tokens.append(number)
	var cursor: Array[int] = [0]
	var restored: Dictionary = _restore(value, tokens, cursor, false)
	# Duplicate object keys are outside written saves. Keep the engine's
	# original parse semantics rather than misassigning their discarded tokens.
	return restored if cursor[0] == tokens.size() else value

static func _restore(value: Variant, tokens: Array[String], cursor: Array[int], frozen: bool) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		var proof: Variant = value.get("body_evidence")
		var frozen_anatomy: bool = proof is Dictionary and proof.get("schema") == 1
		for key: Variant in value:
			result[key] = _restore(value[key], tokens, cursor, frozen or (frozen_anatomy and key == "blueprint"))
		return result
	if value is Array:
		var result: Array = []
		for child: Variant in value: result.append(_restore(child, tokens, cursor, frozen))
		return result
	if value is float or value is int:
		if cursor[0] >= tokens.size(): return value
		var token: String = tokens[cursor[0]]
		cursor[0] += 1
		if frozen: return value
		# Exact small integers, including the writer's ".0", need no bigint work.
		var integer: String = token.trim_suffix(".0")
		if integer.length() <= 16 and integer.is_valid_int() and absi(int(integer)) <= 9007199254740991:
			return -0.0 if int(integer) == 0 and integer.begins_with("-") else float(int(integer))
		return precise(token, float(value))
	return value

static func precise(token: String, original: float) -> float:
	if not is_finite(original): return original
	var negative: bool = token.begins_with("-")
	var text: String = token.trim_prefix("-").to_lower()
	var exponent: int = 0
	if text.contains("e"):
		var pieces: PackedStringArray = text.split("e")
		exponent = int(pieces[1])
		text = pieces[0]
	if text.contains("."):
		exponent -= text.length() - text.find(".") - 1
		text = text.replace(".", "")
	text = text.lstrip("0")
	if text.is_empty(): return original
	while text.ends_with("0"):
		text = text.left(-1)
		exponent += 1
	# Preserve the existing non-finite/schema rejection for extreme input.
	if text.length() > 400 or exponent < -400 or exponent > 400: return original
	var decimal: Array[int] = [0]
	for ch: String in text:
		_mul(decimal, 10)
		_add(decimal, int(ch))
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, absf(original))
	var bits: int = bytes.decode_u64(0)
	for attempt in range(4):
		if bits > 0:
			var low: int = _compare_mid(decimal, exponent, bits - 1, bits)
			if low < 0 or (low == 0 and bits & 1):
				bits -= 1
				continue
		if bits < MAX_FINITE:
			var high: int = _compare_mid(decimal, exponent, bits, bits + 1)
			if high > 0 or (high == 0 and bits & 1):
				bits += 1
				continue
		bytes.encode_u64(0, bits)
		return -bytes.decode_double(0) if negative else bytes.decode_double(0)
	# The engine also underflows some valid subnormals. This bounded fallback
	# searches positive IEEE values, then rounds at the exact midpoint.
	var left: int = 0
	var right: int = MAX_FINITE
	while left < right:
		var middle: int = left + ((right - left + 1) >> 1)
		var number: Array[int] = _binary(middle)
		if _compare(decimal, exponent, number[0], number[1]) >= 0: left = middle
		else: right = middle - 1
	bits = left
	if bits < MAX_FINITE:
		var comparison: int = _compare_mid(decimal, exponent, bits, bits + 1)
		if comparison > 0 or (comparison == 0 and bits & 1): bits += 1
	bytes.encode_u64(0, bits)
	return -bytes.decode_double(0) if negative else bytes.decode_double(0)

static func _binary(bits: int) -> Array[int]:
	var exponent: int = (bits >> 52) & 2047
	var mantissa: int = bits & 0xfffffffffffff
	if exponent == 0: return [mantissa, -1074]
	return [mantissa | (1 << 52), exponent - 1075]

static func _compare_mid(decimal: Array[int], exponent: int, lower: int, upper: int) -> int:
	var a: Array[int] = _binary(lower)
	var b: Array[int] = _binary(upper)
	var power: int = mini(a[1], b[1])
	var mantissa: int = (a[0] << (a[1] - power)) + (b[0] << (b[1] - power))
	return _compare(decimal, exponent, mantissa, power - 1)

static func _compare(decimal: Array[int], exponent: int, mantissa: int, binary_exponent: int) -> int:
	var a: Array[int] = decimal.duplicate()
	var b: Array[int] = []
	while mantissa > 0:
		b.append(mantissa & LIMB_MASK)
		mantissa >>= LIMB_BITS
	if b.is_empty(): b.append(0)
	for unused in range(absi(exponent)):
		_mul(a if exponent >= 0 else b, 5)
	var shift: int = exponent - binary_exponent
	_shift(a if shift >= 0 else b, absi(shift))
	_trim(a)
	_trim(b)
	if a.size() != b.size(): return 1 if a.size() > b.size() else -1
	for index in range(a.size() - 1, -1, -1):
		if a[index] != b[index]: return 1 if a[index] > b[index] else -1
	return 0

static func _mul(value: Array[int], factor: int) -> void:
	var carry: int = 0
	for index in range(value.size()):
		var product: int = value[index] * factor + carry
		value[index] = product & LIMB_MASK
		carry = product >> LIMB_BITS
	if carry > 0: value.append(carry)

static func _add(value: Array[int], amount: int) -> void:
	var index: int = 0
	while amount > 0:
		if index == value.size(): value.append(0)
		var sum: int = value[index] + amount
		value[index] = sum & LIMB_MASK
		amount = sum >> LIMB_BITS
		index += 1

static func _shift(value: Array[int], count: int) -> void:
	if value.size() == 1 and value[0] == 0: return
	var whole: int = count / LIMB_BITS
	var tail: int = count % LIMB_BITS
	if tail != 0: _mul(value, 1 << tail)
	for unused in range(whole): value.push_front(0)

static func _trim(value: Array[int]) -> void:
	while value.size() > 1 and value[-1] == 0: value.pop_back()
