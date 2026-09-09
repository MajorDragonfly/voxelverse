# Nachbarfraktion und Hilfslieferung – Vertrag 1

Auftrag 6, Fortsetzung des abgeschlossenen Stammesfortschritts samt M6-Anschluss.
Eigene Module: `world/tribe/neighbors/neighbor_state.gd`, `neighbor_runtime.gd`
und `ui/tribe/neighbor_panel.gd`.

## Spielbarer Ablauf

1. Nach dem bestätigten Stammesstart unter **Dorf → Nachbarn → Nachbarlager suchen**
   einen erreichbaren Kontakt finden. Die Suche verwendet nur bereits geladenen,
   trockenen, ausreichend freien Boden im gemeinsamen Dorf-Navigationsgraphen.
   Für den Nachbarkontakt wird dessen örtliche Ausdehnung begrenzt von 12 auf
   18 Meter erweitert. Halbmeter-Zwischenpunkte ergänzen die bisherigen geprüften
   Einmeter-Stufenübergänge. Der nächste geeignete Lagerplatz liegt 6 bis 16 Meter
   vom Dorf entfernt; Wege und Bewohner bleiben innerhalb des bestehenden
   gespeicherten Ortsbereichs von 22 Metern. Alle Boden-/Wegeprüfungen bleiben aktiv.
   Ohne geeigneten Platz bleibt die Suche erfolglos und kann wiederholt werden.
2. Das Lager des **Uferbunds** besitzt zwei eigene Bewohner, Vorräte, Beziehung,
   Technikstand und eine Fraktions-ID. Beide Bewohner verwenden denselben
   Körperbauplan wie die eigene Spezies; sie werden weder Wildtiere noch zusätzliche
   Mitglieder der eigenen steuerbaren Dreiergruppe.
3. Mindestens zwei freie eigene Bewohner wählen und **Auswahl liefert Hilfe**
   anklicken. Sie holen Waren am eigenen Lager ab und tragen sie einzeln zum
   Nachbarlager: insgesamt **6 Nahrung und 4 Holz**. Bei der Abholung bleiben sechs
   Nahrung als Heimreserve liegen. Fehlende Vorräte müssen nachgeliefert werden;
   beispielsweise kann der dritte Bewohner die Dorfversorgung fortsetzen.
4. Pro Träger zählen höchstens fünf angekommene Einheiten. Der Abschluss braucht
   damit mindestens zwei wirklich beteiligte Träger. Eine Abholung, Berufszuweisung
   oder das bloße Annehmen des Auftrags zählt nicht als erfüllte Hilfe.
5. Erst nach allen Lieferungen bauen die beiden Nachbarn an ihren erreichten
   Arbeitsplätzen ihre Unterkunft. Beide müssen mitarbeiten; gemeinsam sind zwölf
   aktive Spielsekunden Bauarbeit erforderlich. Vier Holz werden einmal verbaut,
   die sechs Nahrung bleiben im Nachbarlager. Der Uferbund wird freundlich.
6. Dieser Abschluss erfüllt die Nachbarhilfe-Voraussetzung im Entwicklungspfad und
   verdient einmal pro Kampagne **3 soziale Stammespunkte** (`neighbor_help`).
   Mittelalter und Neuzeit bleiben bis zu ihren eigenen Spielmodi und der
   bestätigten, atomaren Bestandsübernahme gesperrt.

Die bestehenden Dorfbuttons **Anhalten/Fortsetzen** gelten weiter. Bei einem
anderen Auftrag wird noch getragene Hilfsfracht zuerst physisch ins eigene Lager
zurückgebracht. Dabei steigen weder der allgemeine Lieferzähler noch
Gemeinschaftspunkte. Erst anschließend führt der Bewohner seinen neuen Auftrag
aus. Volle/fehlende Wege behalten die Arbeit; nach einem entfernten Hindernis
greift die vorhandene Wegsuche erneut. Globale Pause und Simulationsgeschwindigkeit
null stoppen beide Gruppen, und Laden erzeugt keine Offlinearbeit.

## Gemeinsame Speicherung

Das äußere Save-Format bleibt 6, `progression.schema` bleibt 5 und der Dorfvertrag
bleibt `tribe.schema = 3`. **`tribal.schema` steigt von 2 auf 3.** Dadurch erkennen
auch die vorherigen Leser dieses Pakets einen neueren Gesamtstand und schützen
ihn vor Überschreiben, obwohl sie den neuen Nachbaranschluss noch nicht kennen.
Stammesformat 1/2 wird mit erhaltenen Käufen, Verdiensten und Wirtschaftsbeweisen
migriert. Es werden weder Lager noch Nachbarerfolge aus alten Punkteständen erzeugt.

Der optionale Zustand `campaign.bodies[body_key].tribal_neighbor` hat Schema 1:

| Feld | Vertrag |
|---|---|
| `id`, `species_id`, `body_id`, `village_id` | Deterministisch an dieselbe eigene Spezies und diesen Dorf-/Planetenstand gebunden; separate Nachbarfraktion |
| `phase`, `technology`, `relation` | Eigene Phase 1; Unterkunft 0/1 und neutral/freundlich gemäß tatsächlich erfüllter Hilfe |
| `anchor`, `members` | Gespeicherter Lagerort und zwei stabile Individuen mit Position, Arbeitsplatz, Gehabschnitt und Blockierungsstatus |
| `foundation` | Vier geprüfte, erreichbare Bodenauflagen; ein sichtbares Holzfundament gleicht kleine Geländestufen aus, ohne den Planetenboden zu ersetzen |
| `stock` | Wirklich angekommene Nahrung und Holz, abzüglich des einmal verbauten Holzes |
| `aid.id`, `aid.status` | Stabile Vereinbarungs-ID; angeboten → aktiv → im Bau → abgeschlossen |
| `received`, `withdrawn`, `returned` | Je Ressource insgesamt angekommen, am eigenen Lager abgeholt und physisch zurückgegeben |
| `shipments` | Maximal drei eigene Träger; Abschnitt abholen/liefern/zurückbringen und die konkrete einzelne Fracht |
| `carriers`, `builders`, `build_seconds` | Begrenzte echte Beteiligung sowie Bauzeit; keine separat manipulierbare Kontostandskopie |

Für jede Ressource gilt immer:

`abgeholt = angekommen + zurückgegeben + noch getragen`

Fracht stimmt zusätzlich mit dem vorhandenen Bewohnerdatensatz überein. Der
Stammesverdienst speichert Dorf-, Fraktions- und Vereinbarungs-ID; der gemeinsame
Save-Validator verlangt dafür die passende abgeschlossene Vereinbarung. Ein
fremdes Tier, eine unbekannte Person, fehlende Waren oder eine manipulierte
Fraktionsart werden abgelehnt. Auch ein neueres Nachbarschema aktiviert die
vorhandene Zukunftsstand-Sperre.

Kontaktaufnahme und Lieferauftrag speichern atomar. Bei Schreibfehler werden
Nachbarzustand und Bewohneraufträge zurückgesetzt; vor erfolgreichem Kontakt-Save
erscheinen keine neuen Akteure. Laufende Lieferungen, beide Gruppen und Fortschritt
werden im selben Kampagnensnapshot erfasst. Kopien behalten alle individuellen
Identitäten und abgeschlossenen Vereinbarungen; nur die schon bestehende
Kampagnenbindung des Fortschritts wird neu gesetzt.

## Anschlüsse und Grenzen

- `TribeController.neighbors` besitzt ausschließlich den Nachbarablauf.
  `_walk` verwendet weiterhin die gemeinsame Navigation und echte Physik; sein
  optionaler Bewohnerdatensatz erlaubt denselben Bewegungsweg für Nachbarn.
- Ohne Nachbarlager bleibt die bisherige 12-Meter-Graphgröße aktiv. Nach erfolgreichem
  Kontakt verwenden Wiederaufnahme, Arbeitsplatzprüfung und Hindernis-Neusuche
  denselben erweiterten Graphen. Eine erfolglose Kontaktsuche stellt die bisherige
  Größe wieder her. Gespeichert werden Orte und Aufträge, keine veralteten Pfade.
- Vorhandene Rohstoffproduktion, Mahlzeiten, Trinkpausen, Berufe und Tierhaltung
  bleiben bei ihren bisherigen Besitzern. Der Hilfsadapter beobachtet nicht nur
  Menüklicks, sondern führt seine Warenübergaben ausschließlich am erreichten
  Quell-/Zielort aus. Rückgaben erhöhen keine Dorf-Sammelzähler.
- Der Kontakt reserviert seine Lagerfläche gegenüber neu platzierten
  Arbeitsplätzen. Bereits begonnene Baustellen und feste Dorfplätze werden bei
  der Kontaktsuche ausgespart.
- `ProgressionService.record_neighbor_help` akzeptiert nur den aktiven eigenen
  Dorfcontroller. Vergabe erfolgt synchron nach dem Übergang von echtem Bau zu
  fertiggestellter Unterkunft; vorhandene Belohnungssignale bleiben erhalten.
- Ein Tab in der bestehenden Dorfleiste verwendet `progression_style.gd` und
  deren Größen-/Pauseverhalten. Keine zweite Buch-, Modal- oder Pauseverwaltung.
- Zunächst **ein örtliches Nachbarlager je bestehendem Dorf-/Planetenstand**,
  innerhalb des kleinen vorhandenen Navigationsgebiets. Das ist noch kein fernes
  zweites Vollwirtschaftsdorf, keine regionale Handelsroute, kein Kriegssystem
  und keine Weltsimulation außerhalb geladener Bereiche.
- Nachbarn bewegen sich am Lager und bauen die erhaltene Unterkunft. Eigene
  Rohstoffproduktion, Bevölkerungswachstum, Diplomatieabkommen und wiederkehrender
  Handel sind spätere Erweiterungen mit eigenen Leistungs-/Speicherkontrakten.
- Bewohner-/Tieridentitäten bleiben getrennt. Der neue Test verwendet für noch
  nicht integrierte Tierhaltung ausdrücklich einen unveränderten Tierdatensatz
  als Erhaltungs-Fixture; er behauptet keine zusammengeführte D2-/D3-Spielschleife.
