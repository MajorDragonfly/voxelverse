# Dritter Arbeitsstrang: Spielerfortschritt

**Folgeauftrag 9. September 2026:** Das Entdeckungsbuch ist einem anderen Chat übergeben. Dieser Chat setzt auf `agent/creature-behavior-gameplay` reale Begegnungsbelohnungen und Skilltree-Effekte um. [Spielbarer Umfang und Integrationsanschlüsse](CREATURE_BEHAVIOR_GAMEPLAY.md), [Fortschritt ab Stamm](BEHAVIOR_FUTURE_PHASES.md). Nestgruppen und Begleiterbefehle gehören zum separaten Kreaturverhalten-Chat. Die folgende Beschreibung hält das abgeschlossene UI-Ausgangspaket fest.

Stand: 9. September 2026.

Lars hat einen dritten parallelen Chat für Voxelverse angefragt. Die beiden laufenden Chats bearbeiten Kreatureneditor/Kreaturen und Planeten/Welt. Dieser Arbeitsstrang übernimmt die Bedienoberfläche für den Spielerfortschritt auf der vorhandenen M2A-Grundlage.

## Ausgangsbasis

Eigener Branch: `agent/player-progression-ui`.
Basis: `agent/m2-behavior-skilltree`, Commit `f01532416674cc2202aca1a6a99c45cd91d559e0` (PR #10).

M2A enthält getrennte Sozial-/Aggressionspunkte, sechs Knoten, Kaufprüfung, Effektabfragen und gemeinsame Speicherung mit Rücknahme fehlgeschlagener Käufe. Echte soziale Handlungen und angeschlossene Effektverbraucher fehlen laut `docs/BEHAVIOR_M2A.md` noch. Die Oberfläche darf diese Funktionen daher nicht als bereits spielbar darstellen.

## Aufteilung beim Start

| Arbeitsstrang | Bekannter Arbeitszweig | Schwerpunkt |
|---|---|---|
| Kreaturenchat | `agent/creature-editor-spore` (PR #12) | Körpergestaltung, Anbauteile, Oberflächen, Symmetrie und Bewegung |
| Planetenchat | `agent/underwater-voxel-planets` (PR #13), weiterer Branch `agent/planet-real-scale` sichtbar | Planeten, Gelände, Wasser, Maßstab und Galaxiegrundlagen |
| Dieser Chat | `agent/player-progression-ui` | Skilltree-Bedienung und Fortschrittsanzeige; Artenbuch wird im eigenen Arbeitsstrang weitergeführt |

Diese Übersicht beruht auf Lars' aktueller Aufteilung und veröffentlichten Repository-Ständen. Sie ist keine Sperre für andere Chats. Noch nicht veröffentlichte Arbeit anderer Chats ist hier nicht sichtbar.

## Erstes Umsetzungspaket: Skilltree-Oberfläche

- Zwei erkennbare Äste mit den vorhandenen sechs Knoten; getrennte Punktestände, Kosten, Voraussetzungen und gekaufte Knoten.
- Knoten auswählen, Wirkung und Vermächtnis ansehen, über `ProgressionService.purchase_behavior_node()` kaufen. Die Oberfläche besitzt keine zweite Punkte- oder Speicherlogik.
- Kaufablehnungen und Schreibfehler verständlich anzeigen; Erfolg erst nach bestätigter Speicherung.
- Aktuellen Stand nach Laden und Phasenwechsel aktualisieren. Verbleibende Kreaturenpunkte bleiben entsprechend dem vorhandenen Vertrag später einsetzbar.
- Öffnen, Schließen, Mausfreigabe, Tastaturbedienung und Fokus sauber an den bestehenden Spielablauf anschließen. Gemeinsame Eingabedateien erst gegen den dann aktuellen Planeten-/Menüstand prüfen.
- Fehlende Gameplay-Anbindung der Boni und Punktequellen klar benennen. Keine Testbelohnungen oder künstlichen Spielereignisse in die reguläre Oberfläche einbauen.

Vorgesehene eigene Dateien: `ui/behavior_skill_tree.gd`, bei Bedarf eine eigene Szene sowie `tests/behavior_skill_tree_test.gd`. `ui/progression_hud.gd` ist der zu prüfende Anschluss; im geprüften Stand der PRs #12 und #13 wird diese Datei nicht verändert. Eine vollständige Integrationsprüfung einschließlich PR #11 und künftiger Commits steht noch aus.

## Übergabe des Entdeckungsbuchs

Lars hat das Entdeckungsbuch ausdrücklich dem Arbeitsstrang `agent/discovery-journal` zugeteilt. Dessen Integration baut auf dem abgeschlossenen PR-14-Stand `60f61e0` auf. Die einfache Übersicht aus `ui/discovery_journal.gd` ist dort entfernt; die einzige Implementierung liegt in `ui/discovery/discovery_journal.gd`.

`ProgressionHUD` erzeugt genau eine Buchinstanz und übergibt sie als `journal` an den Skilltree. Dessen Button und J öffnen dasselbe Buch. Arten, Regionen und Teile bleiben erhalten; Vorschau, Freischaltursprung und Spielerführung werden im Artenbuchstrang gepflegt. Keine zweite Übersicht oder Punkteverwaltung anlegen. Weitere Informationen: [DISCOVERY_JOURNAL_M4A.md](DISCOVERY_JOURNAL_M4A.md).

## Grenzen und Zusammenführung

Die Umsetzung dieses ersten Pakets bleibt außerhalb von `creatures/editor/`, `creatures/runtime/`, `creatures/wildlife/`, `world/planet_lab/`, `world/generation/` und den Planetendarstellungsdateien. Wildtiere werden im Kreaturenbranch bereits verändert; Befreunden, Hilfe, Kampfanschluss und KI sind deshalb ein später separat abzugrenzendes Paket.

Aktuelle Planetenanforderung bleibt Originalgröße plus bereisbare Galaxie. Ältere Aussagen zu komprimierten Produktionsgrößen in dieser M2A-Ausgangsbasis sind durch Lars' neuere Vorgabe ersetzt; maßgebliche Ausarbeitung liegt im Planetenarbeitsstrang.

Vor Integration die aktuellen Branchköpfe und Dateiunterschiede erneut prüfen, Konflikte gezielt zusammenführen und den gemeinsamen Laufzeitstand testen. Keine Komplettordner über andere Arbeitsstände kopieren. PR #9 bleibt ungemergt; `main` wird hier nicht verändert. Dokumentationsfortschritt ersetzt keine technische oder spielerische Abnahme.

## Abnahme des ursprünglichen PR-14-Pakets

**Technisch und grafisch geprüft, manueller Spieltest offen.** Skilltree, HUD-Anschluss und Entdeckungsbuch sind auf Codecommit `7a1d1ba35b7340bdb4e505a0b1b360e93928196f` umgesetzt. [Bedienung, Nachweise und Grenzen](PLAYER_PROGRESSION_UI.md). Die Tests gegen exportierte Spieldaten sind in `tools/validate_export.py` ergänzt; bei Integration dessen Testliste und README mit dem Planetenbranch gemeinsam erhalten.

Die tatsächlichen Punktequellen und Gameplay-Boni bleiben das nächste fachliche Paket. Der Stand wird über [PR #14](https://github.com/MajorDragonfly/voxelverse/pull/14) bereitgestellt; die beiden anderen Arbeitsbranches und `main` wurden nicht verändert.
