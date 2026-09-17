# Prüfung des GPT-Einrichtungspakets

Stand: 17.09.2026. Paket `DEV-GPT-TEAM`, [Issue #161](https://github.com/MajorDragonfly/voxelverse/issues/161). Basis: `main` auf `176d088d34324de14952bc7506fe9763a22cf4b0`. Der zugehörige PR identifiziert die konkrete Lieferung und ihren CI-Stand.

## Lokal belegt

- Elf vollständige Arbeitsanweisungen, jeweils einschließlich identischer gemeinsamer Regeln; 7.158–7.474 Zeichen pro Anweisung. Rollenmetadaten enthalten je drei Gesprächseinstiege. Alle angegebenen Einstiegspfade existieren in der Basis; genannte Prüfverträge stammen aus der vorhandenen Registry.
- JSON-/OpenAPI-Strukturprüfung beider Action-Schemata: Intake hat zwölf Operationen, davon zwei schreibende POSTs; Read-only hat zehn GETs. Lokale Referenzen, Pfadparameter, eindeutige operationIds, Bearer-Konfiguration und Beschreibungsgrenzen geprüft. POSTs sind ausdrücklich als consequential markiert. Keine Merge-, Code-Schreib- oder Verwaltungsoperationen.
- Drei Issue-Formulare als YAML gelesen; eindeutige Feld-IDs, elf übereinstimmende Rollenoptionen und Beschreibungslängen geprüft. Das bestehende Arbeitspaketformular ist unverändert.
- `python3 tools/check_project_hygiene.py`: bestanden.
- `python3 tools/check_validation_contracts.py --output /tmp/voxelverse-gpt-contracts.json`: bestanden; Registry mit 210 Godot-Tests/18 Verträgen und Sprachkatalog mit 1.623 Einträgen in zwei Sprachen konsistent. Die Engine-Tests wurden dadurch nicht ausgeführt.
- `python3 tools/work_packet.py check`: sechs vorhandene Paketbriefe gültig.
- `python3 tools/project_dashboard.py check`: zentrale Daten und erzeugte Ansichten konsistent; keine Fortschrittsänderung.
- `python3 -m unittest discover -s tests/tooling -p '*_test.py'`: 188 Fälle, davon sieben vom bestehenden Testlauf übersprungen; übrige bestanden (38,534 Sekunden). Keine neuen Tests für die Rollentexte hinzugefügt.
- Unabhängige Gegenprüfung von Vergabe-/Rollenregeln, Action-Berechtigungen, Vorlagen und ehrlichen Fähigkeiten; kein blockierender Befund.

## Noch nicht dadurch belegt

Der GPT-Builder wurde nicht bedient; keine GPTs im Benutzerkonto angelegt, keine Tokens erzeugt und keine Authentifizierungs-/Schreibprobe über eine Custom-GPT-Action durchgeführt. Die OpenAPI-Prüfung ist eine gezielte Strukturprüfung, keine vollständige Metaspezifikations- oder Produkterprobung. [Einrichtungsproben](GITHUB-EINRICHTUNG.md) bleiben im Benutzerkonto erforderlich.

Es wurde kein Spielcode geändert und lokal keine neue Godot-, Grafik-, Export- oder Ziel-PC-Abnahme behauptet. Die vorhandene CI entscheidet nach ihren unveränderten Regeln über den nötigen PR-Prüfumfang. Ein grüner Einrichtungstest bestätigt weder Spielfehler noch die Qualität späterer Fachlieferungen.
