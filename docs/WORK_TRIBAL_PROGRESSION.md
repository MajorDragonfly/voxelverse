# Auftrag 6 – Stammesfortschritt der eigenen Spezies

Stand: 9. September 2026. Abgeschlossenes ursprüngliches Arbeitspaket.
Der aktuelle Folgeumfang mit fertigem M6-Anschluss und erneuter Prüfung steht in
`WORK_TRIBAL_ECONOMY_PROGRESS.md`; dieser Bericht beschreibt die erste Abnahme.

- Branch: `agent/tribal-progression`
- Gemeinsame Startbasis: `3a3e0272375e556f3ff65b7370582af79a9d48b5` (`origin/main`)
- Geprüfter Implementierungscommit: `af0fa37ed2146df6451a089646c7a5ce77925d9e`
- Dieser Bericht wird als anschließender Dokumentationscommit geliefert.
- Veröffentlichungsfreigabe: Lars hat den Upload des Fachbranches und die anschließende Verbindung zur abgeschlossenen Dorfwirtschaft bestätigt. Der aktuelle Übergabestand steht im Folgebericht.
- Keine anderen Fachbranches übernommen; `main` und `ROADMAP.md` nicht verändert.

## Ergebnis

Fünf echte Gemeinschaftsmeilensteine verdienen insgesamt maximal 18 eigene
soziale Stammespunkte. Zwei mindestens tatsächlich beteiligte Bewohner sind für
Transporte und gemeinsame Bauarbeiten erforderlich; Versorgung verlangt die
Mahlzeiten aller drei ursprünglichen Bewohner nach den gemeinsamen Lieferungen.
Abholen, Auswählen, Befehlen, Alleinarbeit, Laden oder Wiederholen desselben
Erfolgs erzeugen keine zusätzlichen Gemeinschaftspunkte.

Zwei Stammesknoten kosten 3 und 5 Stammespunkte und erhöhen die tatsächlich
verwendete Arbeitsrate um jeweils 10 %. Kreaturenpunkte, deren Käufe und das
bestehende Vermächtnis bleiben getrennt erhalten. Kauf und Speicherung sind
atomar; ein fehlgeschlagener Kauf verändert weder Punkte noch Arbeitsbonus.
Aggressive Stammesverdienste bleiben bis zu wirklichen Gruppenkämpfen offen.

K → Skilltree öffnet zunächst die aktuelle Epoche. Der Entwicklungspfad zeigt
Gemeinschaftsziele, erreichte Teilvoraussetzungen und konkret definierte
Mittelalter-/Neuzeit-Ziele. Beide Folgephasen bleiben sowohl im Menü als auch an
der produktiven Übergabeschnittstelle gesperrt. Eine Punktezahl oder ein frei
erfundener Bestätigungstext umgeht keine Sperre.

Nachbarstämme sind als deterministische Fraktionspläne derselben eigenen Spezies
mit eigener Epoche und Technik definiert. Fremde Wildarten können keine
Kulturfraktion werden. Ein unabhängig prüfbarer Erhaltungsvertrag schützt
Bewohner, Besitz und auch noch unbekannte Tierdaten beim späteren Phasenadapter.
Es werden hier noch keine Nachbarstämme gespawnt und keine Folgebühnen simuliert.

## Dateien und Integrationspunkte

| Bereich | Dateien / Änderung |
|---|---|
| Eigene Module | `core/progression/tribal_progression.gd`, `civilization_contract.gd` samt UID-Dateien |
| Fortschrittsansicht | `ui/behavior_skill_tree.gd`, `ui/development_path_panel.gd`, `core/progression/phase_progression_plan.gd` |
| Gemeinsamer Service | `autoload/progression_service.gd`: Stammesnachweise, getrennte Konten/Käufe und Effektanschluss |
| Speicherung | `autoload/save_game_service.gd`: Altformat 4 weiterhin lesbar, Kampagnenbindung und Spielstandkopien |
| Phasensperre | `autoload/game_state.gd`: bestehende Sperre von Phase 2/3 verwendet den benannten Epochenvertrag |
| Dorfanschluss | `world/tribe/tribe_controller.gd`: kleiner Vorher/Nachher-Wrapper um `_perform_work`; direkte Abfrage des kombinierten Arbeitsbonus |
| Prüfungen | `tests/tribal_progression_test.gd`, `tests/tribal_progression_world_test.gd`; bestehender UI-Test prüft sechs sichtbare Kreaturenknoten statt insgesamt sechs intern angelegter Karten |
| Vertragsdokument | `docs/TRIBAL_PROGRESSION_CONTRACT.md` |
| Prüfergebnis | `validation/tribal-progression.json` |

**Auftrag 5:** Der ursprüngliche Inhalt von `_work` heißt in diesem Paket
`_perform_work`. Dorfänderungen beim Integrieren dort erhalten und den Wrapper
bewusst mitnehmen. Keine zweite Produktionsabrechnung installieren.

**Auftrag 7:** `behavior_rewarded` und `behavior_node_purchased` bleiben die
vorhandenen Rückmeldesignale. Neue Meilenstein-/Knoten-IDs stehen im Vertrag.
Es gibt kein neues Buch und keinen zweiten Pausenbesitzer.

## Versionen und Migration

Äußeres Speicherformat bleibt 6; Fortschritt steigt **4 → 5** und enthält
`tribal.schema = 1`. Dorf bleibt 2, bestehendes Verhaltensformat/-regelwerk bleibt
1, alle Phasen- und Arten-IDs bleiben unverändert. Ältere Fortschrittsstände
bekommen einen leeren Stammesnachweis, ohne Erfolge zu erfinden oder Bewohner,
Inventare und Entwürfe zu ändern. Neuere Nachweisversionen werden vor
Überschreiben geschützt. Spielstandkopien behalten alle bezahlten Erfolge und
binden sie nur an die neue Kampagnen-ID.

## Durchgeführte Prüfung

Godot **4.6.3**, abschließend mit eigener ausführbarer Datei ohne Portable-Marker
und pro Test getrenntem `XDG_DATA_HOME`. Alle sieben Abschlusstests bestanden:

| Test | Wesentliche Aussage |
|---|---|
| `tribal_progression_test` | Keine Punkte aus Alleinarbeit, Leerlauf, Replay, Phase 0 oder fremden Tieren; Baustellenbeteiligung nach JSON-Laden; eigene Fraktionsidentitäten; Bewohner-/Tiererhalt und Phasensperre |
| `tribal_progression_world_test` | Bestehender bestätigter Stammesstart und echte Gruppenbewegung; 14 Punkte durch Transporte, Werkzeug, Hütten und Mahlzeiten; reale GUI-Käufe, +20 % Arbeitsrate, Speicherfehler-Rücksetzung, vollständiger Prozessneustart, dreimal Laden ohne Doppelverdienst, Kopieren/Migration, 800×900-Breite |
| `tribal_age_supply_test` | Laufender Garten-/Versorgungsablauf, Nahrung wächst nur in Simulationszeit, Transport und Essenspausen nach Laden, alte Dorfmigration |
| `behavior_progression_test` | Alte Kreaturenpunkte, Käufe, Kampagnenereignisse, Migration und Vermächtnis funktionieren weiter |
| `behavior_skill_tree_test` | Die bestehende Kreaturenoberfläche und deren tatsächliche Käufe bleiben bedienbar |
| `development_path_test` | Lesender Entwicklungspfad, getrennte Phasenansichten, erhaltene Heimatgruppe, keine Zustandsänderung durch Blättern |
| `save_slots_test` | Vorhandene Verwaltung/Kopien der Spielstände bleiben nutzbar |

Zusätzlich erfolgreicher Editorimport und `git diff --check`.
Rasteraufnahmen konnten in dieser Umgebung nicht erzeugt werden: Der lokale
X11-Server konnte keine Verbindungsschnittstelle öffnen. Die GUI wurde mit
headless Eingaben und Layoutgrenzen geprüft; eine manuelle Windows-Sicht- und
Spielprüfung ist weiterhin erforderlich. Es wird keine Ziel-PC-Framezeit behauptet.

## Bewusst verbleibende Arbeit

- Aktive Nachbarfraktionen, Diplomatie und Gruppenkämpfe als eigene Spielschleife.
- Geprüfte Nachweise für dauerhafte Wasserversorgung, Berufe und regionale
  Transporte aus Auftrag 5; kein Ersetzen dieser Nachweise durch Punktezähler.
- D2-Tiere mit dem künftigen Epochenadapter gemeinsam prüfen. Der vorliegende
  Erhaltungstest verwendet ausdrücklich eine Tierdaten-Fixture, keine bereits
  zusammengeführte D2-Spielschleife.
- Produktive Zielmodi für Mittelalter/Neuzeit, gebundene ausdrückliche Bestätigung
  und atomare Epochenübergabe gemäß Vertrag. Solange sie fehlen, gesperrt lassen.
- Künftiges Bevölkerungswachstum muss die heute drei ursprünglichen Bewohner und
  neue Beitragende gemeinsam gegen den erweiterten Dorfvertrag prüfen.

Für die nächste gemeinsame Runde ist dieses Paket bereit zur Integration. Den
geprüften Implementierungscommit und den Dokumentationscommit übernehmen, nicht
unbesehen einen später weiterentwickelten Branch-Kopf.
