extends RefCounted
## Pure presentation helpers. Values and IDs in models remain untranslated.

static func text(key: String) -> String:
	return TranslationServer.translate(key)

static func format_text(key: String, values: Dictionary) -> String:
	return _substitute(text(key), values)

static func plural(key: String, plural_key: String, count: int, values: Dictionary = {}) -> String:
	var arguments := values.duplicate()
	arguments["count"] = count
	return _substitute(TranslationServer.translate_plural(key, plural_key, count), arguments)

static func _substitute(template: String, values: Dictionary) -> String:
	# Substitute against the original template once, never inside player names.
	var expression := RegEx.new()
	expression.compile("\\{([a-zA-Z_][a-zA-Z0-9_]*)\\}")
	var result := ""
	var end := 0
	for token: RegExMatch in expression.search_all(template):
		result += template.substr(end, token.get_start() - end)
		var key := token.get_string(1)
		result += str(values[key]) if values.has(key) else token.get_string()
		end = token.get_end()
	return result + template.substr(end)

static func number(value: float, decimals: int = 2) -> String:
	if not is_finite(value):
		return "—"
	var result := String.num(value, clampi(decimals, 0, 6))
	if result == "-0":
		result = "0"
	return result.replace(".", ",") if TranslationServer.get_locale().begins_with("de") else result

static func date_time(unix_time: int, seconds: bool = false) -> String:
	if unix_time <= 0:
		return text("TIME_UNKNOWN")
	var date := Time.get_datetime_dict_from_unix_time(unix_time)
	var day := "%02d.%02d.%04d" % [date.day, date.month, date.year] if TranslationServer.get_locale().begins_with("de") else "%04d-%02d-%02d" % [date.year, date.month, date.day]
	return day + (" · %02d:%02d:%02d UTC" % [date.hour, date.minute, date.second] if seconds else " · %02d:%02d UTC" % [date.hour, date.minute])
