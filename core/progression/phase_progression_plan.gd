extends RefCounted
class_name PhaseProgressionPlan

## Read-only design preview, deliberately separate from purchasable balancing rules.
const PHASES: Array[Dictionary] = [
	{"name": "Kreatur", "scope": "Einzelne Begegnung", "implemented": true,
		"control": "Du steuerst deine Kreatur; die Nestgruppe bleibt Teil dieser Phase.",
		"loop": ["Erkunden und Körper entwickeln", "Beziehungen aufbauen oder jagen", "Eine eigene Nestgruppe bilden"],
		"social": "Befreunden und fremd verursachte Verletzungen versorgen.",
		"aggression": "Jagd auf Beute und Konflikte mit feindlichen Tieren abschließen.",
		"next": "Kreatur → Nestgruppe → Stammesphase. Die Nestgruppe ist die Vorstufe, noch kein Dorf."},
	{"name": "Stamm", "scope": "Drei Bewohner und ihr erstes Dorf", "implemented": true,
		"control": "Du befehligst Gruppen, verteilst Aufgaben und entwickelst ein richtiges Dorf.",
		"loop": ["Material sammeln", "Werkzeuge herstellen", "Behausung bauen", "Bewohner versorgen", "Dorf erweitern"],
		"social": "Gemeinsame Transporte, Handwerk, Hüttenbau, Gartenbau und Versorgung der ganzen Gruppe abschließen. Jeder Meilenstein verdient einmal eigene Stammespunkte.",
		"aggression": "Geplant: das Lager verteidigen und begrenzte Stammeskonflikte entscheiden. Noch keine aktive Punktequelle.",
		"next": "Dies ist die eigentliche Stammesphase mit einem spielbaren Dorfeinstieg. Ein Wurzelgarten und Daueraufträge sichern Nahrung. Als Nächstes: weitere Berufe, Rohstoffquellen, Bevölkerungswachstum und Nachbarstämme."},
	{"name": "Antike / Mittelalter", "scope": "Siedlung und Fraktion", "implemented": false,
		"control": "Du organisierst mehrere Siedlungen und ihre Bevölkerung.",
		"loop": ["Landwirtschaft und Handwerk ausbauen", "Siedlungen verbinden", "Handel und regionale Konflikte führen"],
		"social": "Handelsabkommen erfüllen, Siedlungen versorgen und Frieden aushandeln.",
		"aggression": "Belagerungen abwehren und Feldzüge mit festem Ziel abschließen.",
		"next": "Diplomatie, Versorgung und Verteidigung; bewährte Institutionen als Vermächtnis."},
	{"name": "Neuzeit / Weltmacht", "scope": "Staat und internationaler Konflikt", "implemented": false,
		"control": "Du führst einen Staat und lenkst Wirtschaft, Diplomatie und Verteidigung.",
		"loop": ["Industrie entwickeln", "Internationale Beziehungen gestalten", "Den Schritt ins All vorbereiten"],
		"social": "Kooperation, humanitäre Hilfe und gemeinsame Forschung abschließen.",
		"aggression": "Strategische Konfliktziele erreichen und das eigene Gebiet schützen.",
		"next": "Wirtschaftsverbünde und strategische Logistik für die Weltraumphase vorbereiten."},
	{"name": "Weltraum", "scope": "Zivilisation und Sternensystem", "implemented": false,
		"control": "Du entwickelst deine Zivilisation über Planeten und Sternensysteme hinweg.",
		"loop": ["Sternensysteme erkunden", "Kolonien versorgen", "Interstellare Beziehungen gestalten"],
		"social": "Erstkontakt, Koloniehilfe und interstellare Verträge erfolgreich abschließen.",
		"aggression": "Kolonien verteidigen und Konflikte um Systeme entscheiden.",
		"next": "Interstellare Zusammenarbeit und Flottenkoordination; stabile Galaxie-/System-/Körperadressen."},
	{"name": "Multiversum", "scope": "Universum und universenübergreifender Auftrag", "implemented": false,
		"control": "Langfristiger Entwurf für deine universenübergreifende Zivilisation.",
		"loop": ["Neue Universen erkunden", "Expeditionen und übergreifende Beziehungen entwickeln"],
		"social": "Gemeinsame Expeditionen und Abkommen zwischen Universen abschließen.",
		"aggression": "Universenübergreifende Bedrohungen mit definiertem Ziel abwehren.",
		"next": "Langfristiger Entwurf; konkrete Spielregeln erst nach der Weltraumphase festlegen."},
]


static func phase(index: int) -> Dictionary:
	return PHASES[index].duplicate(true) if index in range(PHASES.size()) else {}
