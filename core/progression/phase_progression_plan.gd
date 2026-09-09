extends RefCounted
class_name PhaseProgressionPlan

## Read-only design preview, deliberately separate from purchasable balancing rules.
const PHASES: Array[Dictionary] = [
	{"name": "Kreatur", "scope": "Einzelne Begegnung", "implemented": true,
		"social": "Befreunden und fremd verursachte Verletzungen versorgen.",
		"aggression": "Jagd auf Beute und Konflikte mit feindlichen Tieren abschließen.",
		"next": "Beziehungen und bewusst gekaufte Vermächtnisse für den Stamm erhalten."},
	{"name": "Stamm", "scope": "Gruppe und Nachbarstamm", "implemented": false,
		"social": "Gemeinschaftsaufgaben, Hilfslieferungen und Bündnisse abschließen.",
		"aggression": "Das Lager verteidigen und begrenzte Stammeskonflikte entscheiden.",
		"next": "Gruppenkoordination und gemeinsame Verteidigung; Übergabe von Mitgliedern, Heimat und Beziehungen."},
	{"name": "Antike / Mittelalter", "scope": "Siedlung und Fraktion", "implemented": false,
		"social": "Handelsabkommen erfüllen, Siedlungen versorgen und Frieden aushandeln.",
		"aggression": "Belagerungen abwehren und Feldzüge mit festem Ziel abschließen.",
		"next": "Diplomatie, Versorgung und Verteidigung; bewährte Institutionen als Vermächtnis."},
	{"name": "Weltmacht", "scope": "Staat und internationaler Konflikt", "implemented": false,
		"social": "Kooperation, humanitäre Hilfe und gemeinsame Forschung abschließen.",
		"aggression": "Strategische Konfliktziele erreichen und das eigene Gebiet schützen.",
		"next": "Wirtschaftsverbünde und strategische Logistik für die Weltraumphase vorbereiten."},
	{"name": "Weltraum", "scope": "Zivilisation und Sternensystem", "implemented": false,
		"social": "Erstkontakt, Koloniehilfe und interstellare Verträge erfolgreich abschließen.",
		"aggression": "Kolonien verteidigen und Konflikte um Systeme entscheiden.",
		"next": "Interstellare Zusammenarbeit und Flottenkoordination; stabile Galaxie-/System-/Körperadressen."},
	{"name": "Multiversum", "scope": "Universum und universenübergreifender Auftrag", "implemented": false,
		"social": "Gemeinsame Expeditionen und Abkommen zwischen Universen abschließen.",
		"aggression": "Universenübergreifende Bedrohungen mit definiertem Ziel abwehren.",
		"next": "Langfristiger Entwurf; konkrete Spielregeln erst nach der Weltraumphase festlegen."},
]


static func phase(index: int) -> Dictionary:
	return PHASES[index].duplicate(true) if index in range(PHASES.size()) else {}
