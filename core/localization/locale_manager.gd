extends Node
## Device preference only. Never write a locale into campaign/species data.
signal language_changed(locale: String)

const CONFIG_PATH := "user://language_settings.cfg"
const SCHEMA := 1
const FALLBACK := "de"
const Catalogs = preload("res://localization/catalogs.gd")
const LANGUAGES = Catalogs.LANGUAGES
const CATALOGS = Catalogs.CATALOGS
var preference: String = "auto"
var locale: String = FALLBACK
var load_problem: String = ""
var _read_only: bool = false

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for catalog: Translation in CATALOGS:
		TranslationServer.add_translation(catalog)
	load_saved()

static func resolve_language(value: String) -> String:
	var normalized := value.strip_edges().replace("-", "_").to_lower()
	if LANGUAGES.has(normalized):
		return normalized
	var base := normalized.get_slice("_", 0)
	return base if LANGUAGES.has(base) else FALLBACK

func load_saved(path: String = CONFIG_PATH, system_locale: String = OS.get_locale()) -> void:
	preference = "auto"
	load_problem = ""
	_read_only = false
	var config := ConfigFile.new()
	var error := config.load(path)
	if error == OK:
		var schema: Variant = config.get_value("language", "schema", SCHEMA)
		var value: Variant = config.get_value("language", "preference", "auto")
		if not schema is int or schema != SCHEMA:
			_read_only = true
			load_problem = "LANGUAGE_NEWER_SETTINGS"
		elif value is String and (value == "auto" or LANGUAGES.has(value)):
			preference = value
		else:
			load_problem = "LANGUAGE_INVALID_SETTINGS"
	elif error != ERR_FILE_NOT_FOUND:
		load_problem = "LANGUAGE_INVALID_SETTINGS"
	_apply(resolve_language(system_locale) if preference == "auto" else preference)

func save_preference(value: String, path: String = CONFIG_PATH) -> Error:
	if value != "auto" and not LANGUAGES.has(value):
		return ERR_INVALID_PARAMETER
	if _read_only:
		return ERR_UNAVAILABLE
	# Persist before applying: failed writes retain the previous live language.
	var config := ConfigFile.new()
	config.set_value("language", "schema", SCHEMA)
	config.set_value("language", "preference", value)
	var error := config.save(path + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	if error != OK:
		return error
	preference = value
	load_problem = ""
	_apply(resolve_language(OS.get_locale()) if value == "auto" else value)
	return OK

func _apply(value: String) -> void:
	var changed := locale != value or TranslationServer.get_locale() != value
	locale = value
	TranslationServer.set_locale(value)
	if changed:
		language_changed.emit(locale)
