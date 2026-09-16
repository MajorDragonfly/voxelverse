extends RefCounted
## Read-only selection of SaveGameService summaries; paths remain identities.
const PAGE_SIZE := 12

static func select(slots: Array, term: String = "", phase: int = -1, status: String = "all", order: String = "recent") -> Array[Dictionary]:
	var words := term.strip_edges().to_lower().split(" ", false)
	var result: Array[Dictionary] = []
	for slot: Dictionary in slots:
		if phase >= 0 and int(slot.phase) != phase: continue
		var attention: bool = not bool(slot.valid) or bool(slot.recovered)
		if status == "ready" and attention: continue
		if status == "attention" and not attention: continue
		var searchable := str(slot.name).to_lower() + " " + str(slot.seed)
		var matches := true
		for word: String in words:
			if not searchable.contains(word): matches = false; break
		if not matches: continue
		result.append(slot)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		match order:
			"name":
				var left := str(a.name).to_lower()
				var right := str(b.name).to_lower()
				var comparison := left.naturalnocasecmp_to(right)
				if comparison != 0: return comparison < 0
			"playtime":
				if float(a.seconds) != float(b.seconds): return float(a.seconds) > float(b.seconds)
			_:
				if int(a.saved_time) != int(b.saved_time): return int(a.saved_time) > int(b.saved_time)
		return str(a.path) < str(b.path))
	return result

static func page_for(slots: Array, path: String) -> int:
	for index in slots.size():
		if str(slots[index].path) == path: return index / PAGE_SIZE
	return -1

static func page(slots: Array, index: int) -> Array:
	var start := clampi(index, 0, maxi(ceili(float(slots.size()) / PAGE_SIZE) - 1, 0)) * PAGE_SIZE
	return slots.slice(start, start + PAGE_SIZE)
