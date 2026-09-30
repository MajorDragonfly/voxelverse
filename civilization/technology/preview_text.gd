extends RefCounted
## Scoped prototype translations pending central catalog integration by Chat 1.
## All views use the existing UiText/TranslationServer path.
const UiText = preload("res://core/localization/ui_text.gd")
const MESSAGES := "res://civilization/technology/messages.json"
const PART_KEYS: Dictionary = {"mass_house_core": "MEDTECH_PART_HOUSE", "opening_door_wood": "MEDTECH_PART_DOOR",
	"mass_workshop": "MEDTECH_PART_WORKSHOP", "mass_market_wing": "MEDTECH_PART_MARKET", "decor_awning": "MEDTECH_PART_AWNING"}
var translations: Array[Translation] = []

func install() -> void:
	var messages: Array = JSON.parse_string(FileAccess.get_file_as_string(MESSAGES))["messages"]
	# Reuse the existing translated resource vocabulary in the isolated project.
	var shared: Array = JSON.parse_string(FileAccess.get_file_as_string("res://localization/catalog.json"))["messages"]
	for entry: Dictionary in shared:
		if str(entry["key"]).begins_with("TRIBE_RESOURCE_"): messages.append(entry)
	for locale: String in ["de", "en"]:
		var translation := Translation.new()
		translation.set_locale(locale)
		for entry: Dictionary in messages:
			translation.add_message(entry["key"], entry[locale])
		translations.append(translation)
		TranslationServer.add_translation(translation)

func uninstall() -> void:
	for translation: Translation in translations: TranslationServer.remove_translation(translation)
	translations.clear()

static func text(key: String) -> String:
	return UiText.text(key)

static func format_text(key: String, values: Dictionary) -> String:
	return UiText.format_text(key, values)

static func requirement(id: String) -> String:
	return text("MEDTECH_REQ_" + id.to_upper())

static func resource_title(id: String) -> String:
	return text("TRIBE_RESOURCE_" + id.to_upper())

static func part_title(id: String) -> String:
	return text(PART_KEYS.get(id, id))
