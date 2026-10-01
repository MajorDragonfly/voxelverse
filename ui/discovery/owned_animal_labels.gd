extends RefCounted
## Narrow presentation labels; shared catalog entries take precedence.
## Append payload for Chat 1: docs/evidence/int30-13-owned-animals/localization-append.json.
const MESSAGES := {
	"OWNED_ORDERS_ALL": {"de": "Alle Aufträge", "en": "All commands"},
	"OWNED_ORDER_FILTER": {"de": "Nach Auftrag filtern", "en": "Filter by command"},
	"OWNED_SORT": {"de": "Sortierung wählen", "en": "Choose sorting"},
	"OWNED_SORT_NAME": {"de": "Name · A–Z", "en": "Name · A–Z"},
	"OWNED_SORT_SPECIES": {"de": "Art · A–Z", "en": "Species · A–Z"},
	"OWNED_SORT_TRUST": {"de": "Vertrauen · höchstes zuerst", "en": "Trust · highest first"},
	"OWNED_SORT_ORDER": {"de": "Auftrag · gruppiert", "en": "Command · grouped"},
	"OWNED_RECORDED_ROLE": {"de": "Belegte Art-Eignung: {roles}", "en": "Recorded species suitability: {roles}"},
	"OWNED_ROLE_UNOBSERVED": {"de": "Art-Eignung nicht bekannt. Ein vollständiger, unterstützter Art-Scan fehlt.", "en": "Species suitability unknown. A complete, supported species scan is missing."},
	"OWNED_ROLE_NOTICE": {"de": "Art-Eignung ist keine laufende Produktion. Tierplatz, Versorgung und tatsächliche Erträge werden hier nicht beobachtet.", "en": "Species suitability does not show active production. Animal housing, care and actual yields are not observed here."},
	"OWNED_LOCATION_NOTICE": {"de": "Ort aus dem Tierbestand; Aktualität und Ankunft sind nicht beobachtbar. Das Auftragsziel ist kein Ankunftsnachweis.", "en": "Location from the animal register; freshness and arrival are not observable. A command target does not prove arrival."},
	"OWNED_ORDER_DETAIL": {"de": "Aktueller Auftrag: {order}", "en": "Current command: {order}"},
}

static func text(key: String, locale: String) -> String:
	return str(MESSAGES.get(key, {}).get("de" if locale.begins_with("de") else "en", key))
