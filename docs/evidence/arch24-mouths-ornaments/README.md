# ARCH-24: Nachweise für Münder, Geweihe und Kämme

Drei Pakete: `ARCH-24-MOUTH-REFRESH`, `ARCH-24-ANTLER-FAMILIES`,
`ARCH-24-CREST-FAMILIES`. [Fachliche Übergabe](../../WORK_ARCH24_MOUTHS_ORNAMENTS.md).

Basis `176d088d34324de14952bc7506fe9763a22cf4b0`. Letzter geprüfter Quellcommit `59c2a6b21d5fb70a292be15976acab31300b3fb8`,
Tree `9dbf143dde7f680a974a995bb7a3823d4991723d`. Produktionscode unverändert seit `4d396274f96e620393644851d88e1654f95be964`;
danach wurden nur die beiden neuen Testfixtures korrigiert. Godot 4.6.3,
Linux headless, vom Runner isolierte Nutzerdaten je Test. Die Quellstände waren
beim Start sauber und während der jeweiligen Läufe unverändert.

## Gezielte Prüfläufe

16 unterschiedliche erfolgreiche Prüfungen über drei dokumentierte Quellstände.
Das ist kein einzelner vollständiger Suite-Lauf auf dem letzten Tree. Die
vollständigen Befehle, Engine, Umgebung, Quellmanifeste und Log-Prüfsummen stehen
in den Ergebnisdateien und den zugehörigen Archiven. CI prüft den späteren Merge-Tree.

| Erfolgreiche Prüfung | Quellcommit | Dauer |
|---|---|---|
| `creature_foot_provider_test` | `a18e98f` | 3.637 s |
| `creature_part_articulation_test` | `a18e98f` | 6.742 s |
| `discovery_journal_test` | `a18e98f` | 6.441 s |
| `journal_localization_test` | `a18e98f` | 28.657 s |
| `community_blueprint_package_test` | `a18e98f` | 9.657 s |
| `creature_design_library_test` | `a18e98f` | 5.88 s |
| `blueprint_contract_test` | `a18e98f` | 4.079 s |
| `creature_mouth_provider_test` | `4d39627` | 14.525 s |
| `creature_snout_family_test` | `4d39627` | 18.91 s |
| `creature_parts_studio_test` | `4d39627` | 14.365 s |
| `creature_body_contract_test` | `4d39627` | 9.047 s |
| `creature_part_revisions_test` | `4d39627` | 9.19 s |
| `creature_editor_v7_runtime_test` | `4d39627` | 4.278 s |
| `editor_localization_test` | `4d39627` | 36.268 s |
| `creature_mouth_refresh_test` | `59c2a6b` | 85.525 s |
| `creature_ornament_families_test` | `59c2a6b` | 38.269 s |

1. [Erster Lauf](01-initial-results.json), [vollständige Logs/Manifeste](01-initial-logs.tar.gz):
   sieben bestehende Verbraucher bestanden. Aufgedeckt wurden ein falsch benannter
   Editorparameter, eine fehlende Typangabe im Mundtest, unnötig hohe Voxelzahlen
   bei extremen Ornamentformen und unpassende Bein-/Paar-Annahmen im neuen Test.
2. [Korrekturlauf](02-corrections-results.json), [vollständige Logs/Manifeste](02-corrections-logs.tar.gz):
   sieben zuvor betroffene Verbraucher bestanden. Die neuen Familientests
   deckten noch Testdaten mit impliziter Katalogrevision, einen Paar-Kamm auf
   der Mittelachse und einen Vergleich mit uneinheitlicher JSON-Präzision auf.
3. [Abschließende Familientests](03-family-final-results.json), [vollständige Logs/Manifeste](03-family-final-logs.tar.gz):
   beide neuen Tests bestanden, einschließlich echter Datei-/Kampagnenspeicherung,
   Zukunftsversionsschutz, neuer Prozesse, Offline-Vorlagen und Editor-Undo/Redo.
   100 Mund- und 60 Ornamentreferenzen prüfen Geometrie, Farbe, XYZ-Grenzen,
   Spiegelung und zusammenhängende Oberflächen. Alte Arten und Modelle bleiben geprüft.

Die sieben Nachweise des ersten Laufs bleiben auf ihren dort genannten Quellstand
begrenzt. Der Korrekturlauf und die Familientests decken die späteren Änderungen an
Editor, Revisionsschutz, Volumenbudget und Testdaten ab; keine erfolgreiche Vollabnahme
wird aus einer gemischten Quellbasis behauptet. [Maschinenlesbare Zusammenstellung](summary.json).

[Hand-/Fußanbieter bytegleich zur Basis](hands-feet-unchanged.json).

## Sichtprüfung

Die Ansichten verwenden die tatsächlichen gemeinsamen Godot-Meshes. Die normale
Modellgröße samt Farben ist nach der Budgetkorrektur identisch geblieben; die
entsprechenden 32 Referenzen und Bild-/Datensatz-Prüfsummen stehen in
[visual-review.json](visual-review.json). Die erste Sichtprüfung führte zur Korrektur
von aus der Oberfläche ragenden Nasenmarkierungen und eines zu runden Oktopusschnabels.
Die finalen Ansichten wurden einzeln und am vollständigen Körper geprüft.

- [Vier Grundmünder: vorher, neu und geöffnet](mouths-comparison-1.png)
- [Hund, Krokodil, Oktopus: vorher, neu und geöffnet](mouths-comparison-2.png)
- [Katze, Bär, Schwein: vorher, neu und geöffnet](mouths-comparison-3.png)
- [Grundmünder am Körper](mouths-bodies-1.png), [Hund/Krokodil/Oktopus am Körper](mouths-bodies-2.png), [weitere Schnauzen am Körper](mouths-bodies-3.png)
- [Geweihe und Kämme als Einzelteile](ornaments-models.png), [am Körper](ornaments-bodies.png)

Reproduktion: `tools/export_mouth_refresh.gd` und `tools/export_ornament_review.gd`
geben reale Geometrie als JSON aus; `tools/render_mouth_refresh.py` und
`tools/render_ornament_review.py` erzeugen daraus die Ansichten. Das ersetzt keine
native Windows-Spiel-, Renderer- oder FPS-Abnahme.
