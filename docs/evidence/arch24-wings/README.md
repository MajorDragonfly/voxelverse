# Prüfnachweis · ARCH-24-WING-FAMILIES

Geprüft am 16.09.2026, Linux x86_64, Godot 4.6.3 stable
`7d41c59c4`, gepinnter Download mit SHA-Prüfung. Headless-Quellprojekt,
isolierte Nutzerdaten des Runners; neue Prozesse übernehmen nur dessen
Test-Save-Verzeichnis. Kein Testlauf wurde während seiner Ausführung verändert.

| Lauf | Quellcommit | Tree | Ergebnis |
|---|---|---|---|
| Anfangslauf | `7c1b4199395fe5f3ac52949ebb0bee48ac417bbd` | `80bea3792210d3b823a58d877a3d90594a5ebca8` | 11 von 12 Tests grün; Flügeltest rot |
| Korrektur | `e479a6d56dc85b929ba51b96716f9b428c29a2ba` | `e9abf4111ac4a763c210ef7d1c2f6fc496250a0b` | Flügelfamilie und Teile-Studio grün |
| Vorherige Lieferung #154 | `d65d69384cfdd92312100a35a4f419875999f036` | `75b151894362f967a5af8ca8a1a4cbff66da0ddc` | Beide CI-Fehler gezielt behoben und geprüft |

Der veröffentlichte Quellcommit `8f31144595f773b77c16d15f9c33e88ba4cedd0d`
hat exakt den Tree des Korrekturlaufs. Der folgende Dokumentationscommit ergänzt
nur diese Nachweise und die Fachübergabe. Die Quellstände aller Läufe waren sauber;
`source_integrity` bestätigt jeweils unveränderte Eingaben. Die vollständigen
Quellmanifeste liegen komprimiert neben den jeweiligen Logs.

## Befehle

Im Fachcheckout, `$GODOT_BIN` = gepinnter Godot-Editor:

```sh
python3 tools/validate_godot.py --godot "$GODOT_BIN" --tests creature_wing_family_test creature_part_articulation_test creature_foot_provider_test creature_hand_provider_test creature_parts_studio_test creature_body_contract_test creature_part_revisions_test community_blueprint_package_test creature_design_library_test discovery_journal_test editor_localization_test egg_species_campaign_test --skip-import --skip-main --output ../wing-checks
python3 tools/validate_godot.py --godot "$GODOT_BIN" --tests creature_wing_family_test creature_parts_studio_test --skip-import --skip-main --output ../wing-final-checks
```

Der Editorimport war für die verwendeten Ressourcen bereits erfolgreich; die
Korrektur änderte nur Skripte und die ausdrücklich erfasste Flügelreferenz.
Nachweise: [Anfangslauf](initial-checks/results.json),
[Korrekturlauf](final-checks/results.json),
[Flügelfamilie](final-checks/creature_wing_family_test.log).

Der erste Lauf fand zwei getrennte Randzellen an einer nichtuniform gestreckten
Fledermausfläche. Die vier Streben werden nun mit begrenzter Mindestbreite als
tragende Geometrie erzeugt. Die Zusammenhangsprüfung bleibt unverändert streng.
Außerdem zählte die neue Laufzeitprüfung irrtümlich den vorhandenen Auswahlcollider
als drittes Mesh. Sie prüft nun die beiden benannten Meshes und separat ihren
Kontakt zum festen Schulterstück in jeder Streckpose. Keine produktive Kollision
wurde entfernt. Alle vorherigen Fehlerlogs bleiben im Anfangslauf erhalten.

Der abschließende Familienlauf besteht **1.277 Prüfungen**, 40 festgehaltene
Mesh-/Farbkombinationen (vier Modelle, fünf XYZ-Formen, beide Seiten), 30 alte
Arten, Editoraktionen, Freischaltungsmigration, echte Saves, Offline-Pakete und
einen neuen Godot-Prozess. Füße bleiben am radialen Boden; Flügel werden nicht
als Stützbeine gezählt. Zukunftsrevisionen können bestehende Saves nicht ersetzen.
Die unveränderten direkten Verbraucher aus dem Anfangslauf wurden nach der
begrenzten Korrektur nicht nochmals vollständig ausgeführt.

## Sichtprüfung

```sh
"$GODOT_BIN" --headless --path . --script tools/export_wing_review.gd -- ../wings-final-meshes.json
python3 tools/render_wing_review.py ../wings-final-meshes.json ../wing-final-views
```

Geprüft: vier unterscheidbare Silhouetten, verbundene Streben/Federflächen,
beidseitiger Körperanschluss und angehobene Streckpose. Die PNGs stammen aus den
Mesharrays des gemeinsamen Anbieters. Native Spielaufnahme, GPU-/FPS- oder
Ziel-PC-Abnahme sind damit nicht behauptet. Die komplette CI läuft separat im PR;
Integration erst nach den vier Pflichtgates für den dann aktuellen Merge-Stand.

## Nachbesserung der vorherigen Lieferung

Auf dem separaten Branch von #154 wurde folgender enger Lauf durchgeführt:

```sh
python3 tools/validate_godot.py --godot "$GODOT_BIN" --tests egg_species_campaign_test wildlife_hunting_world_test --skip-main --output ../previous-mouth-ci-checks
```

Beide Proben bestanden (46,729 s / 34,529 s), einschließlich Import und
Quellintegrität. Veröffentlicht als `1db2d4e43963e7c2250c6e31a13330325245a258`.
Die historische Fixture erwartet die vier Kamm-Freischaltungen ausdrücklich;
die Jagdprobe verwendet eine freie Aufstellung über die unveränderte produktive
Kollisionsprüfung. [Ergebnisse](previous-mouth-ci/results.json).
