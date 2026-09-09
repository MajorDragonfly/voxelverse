# Dritter Arbeitsstrang: Spielerfortschritt

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
| Dieser Chat | `agent/player-progression-ui` | Skilltree-Bedienung, Fortschrittsanzeige und anschließend Entdeckungsbuch |

Diese Übersicht beruht auf Lars' aktueller Aufteilung und veröffentlichten Repository-Ständen. Sie ist keine Sperre für andere Chats. Noch nicht veröffentlichte Arbeit anderer Chats ist hier nicht sichtbar.

## Erstes Umsetzungspaket: Skilltree-Oberfläche

- Zwei erkennbare Äste mit den vorhandenen sechs Knoten; getrennte Punktestände, Kosten, Voraussetzungen und gekaufte Knoten.
- Knoten auswählen, Wirkung und Vermächtnis ansehen, über `ProgressionService.purchase_behavior_node()` kaufen. Die Oberfläche besitzt keine zweite Punkte- oder Speicherlogik.
- Kaufablehnungen und Schreibfehler verständlich anzeigen; Erfolg erst nach bestätigter Speicherung.
- Aktuellen Stand nach Laden und Phasenwechsel aktualisieren. Verbleibende Kreaturenpunkte bleiben entsprechend dem vorhandenen Vertrag später einsetzbar.
- Öffnen, Schließen, Mausfreigabe, Tastaturbedienung und Fokus sauber an den bestehenden Spielablauf anschließen. Gemeinsame Eingabedateien erst gegen den dann aktuellen Planeten-/Menüstand prüfen.
- Fehlende Gameplay-Anbindung der Boni und Punktequellen klar benennen. Keine Testbelohnungen oder künstlichen Spielereignisse in die reguläre Oberfläche einbauen.

Vorgesehene eigene Dateien: `ui/behavior_skill_tree.gd`, bei Bedarf eine eigene Szene sowie `tests/behavior_skill_tree_test.gd`. `ui/progression_hud.gd` ist der zu prüfende Anschluss; im geprüften Stand der PRs #12 und #13 wird diese Datei nicht verändert. Eine vollständige Integrationsprüfung einschließlich PR #11 und künftiger Commits steht noch aus.

## Anschließend: Entdeckungsbuch

Vorhandene Arten- und Regionsentdeckungen lesbar durchsuchen und zugehörige Freischaltungen anzeigen. Nur tatsächlich gespeicherte Daten verwenden; unbekannte Lebensräume, Eigenschaften oder Beziehungen nicht erfinden. Zusätzliche dauerhafte Datenfelder erst mit der Speichergrundlage abstimmen.

## Grenzen und Zusammenführung

Die Umsetzung dieses ersten Pakets bleibt außerhalb von `creatures/editor/`, `creatures/runtime/`, `creatures/wildlife/`, `world/planet_lab/`, `world/generation/` und den Planetendarstellungsdateien. Wildtiere werden im Kreaturenbranch bereits verändert; Befreunden, Hilfe, Kampfanschluss und KI sind deshalb ein später separat abzugrenzendes Paket.

Aktuelle Planetenanforderung bleibt Originalgröße plus bereisbare Galaxie. Ältere Aussagen zu komprimierten Produktionsgrößen in dieser M2A-Ausgangsbasis sind durch Lars' neuere Vorgabe ersetzt; maßgebliche Ausarbeitung liegt im Planetenarbeitsstrang.

Vor Integration die aktuellen Branchköpfe und Dateiunterschiede erneut prüfen, Konflikte gezielt zusammenführen und den gemeinsamen Laufzeitstand testen. Keine Komplettordner über andere Arbeitsstände kopieren. PR #9 bleibt ungemergt; `main` wird hier nicht verändert. Dokumentationsfortschritt ersetzt keine technische oder spielerische Abnahme.

## Status

Arbeitszweig und Zuständigkeit eingerichtet. Die Repository-Grundlage und veröffentlichten Dateiumfänge wurden geprüft. **In dieser Einrichtung wurden noch keine Gameplay- oder UI-Dateien geändert.** Der nächste Umsetzungsschritt ist die Skilltree-Oberfläche gemäß obigem Paket. Für diese reine Dokumentationsänderung ist kein neuer Spieltest erforderlich.
