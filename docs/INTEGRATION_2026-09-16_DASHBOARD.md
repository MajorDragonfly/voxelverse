# Gemeinsame Integration vom 16. September 2026

[PR #141](https://github.com/MajorDragonfly/voxelverse/pull/141) führt die vollständige
Spieltestbasis #125 und **14 neue feste Fachlieferungen** zusammen. Der gemeinsame
Spielcode-Quellstand ist `1111567a06223ff8692fb5a71596d488e4f8c183`; nachfolgende Status-, Werkzeug- und
Nachweisdateien ändern den Spielcode nicht. Branch: `agent/integration-dashboard-20260916`.

## Umfang

| PR | Enthaltene Lieferung |
|---|---|
| #126 | Gespeicherte Planetenklimata und geschützte Heimat |
| #127 | 18 Grafikregler; Einstellungen standardmäßig über Esc |
| #128 | Gegenseitiges Spielverhalten der Wildtiere |
| #129 | Gespeicherte Schiffsinstanzen, Hangar und Flottentest |
| #130 | Baustellen pausieren, abbrechen und Material zurückbringen |
| #131 | Bekannte Orte im Atlas suchen und gefiltert durchblättern |
| #132 | Favoriten und erweiterte Suche für Kreaturenvorlagen |
| #133 | Rückkehr zur Heimat nach dem Tod |
| #134 | Tastenbelegung für Karte, Entdeckungsbuch und Entwicklung |
| #135 | Spielstände suchen, filtern und seitenweise verwalten |
| #136 | Vier Einführungskapitel bis zum ersten Stamm |
| #138 | Spielstände und Sicherungen schrittweise prüfen |
| #139 | Projekt-Dashboard, Statusquelle, Rundenliste und Paketübergaben |
| #140 | Wildtierjagd und endliches Aasfressen |

Alle ursprünglichen Branch-, Basis- und Kopfzuordnungen stehen in
[inputs.json](evidence/integration-20260916/inputs.json). Die Stapel #131 → #134,
#135 → #138 und #128 → #140 sind vollständig enthalten. #122 bleibt die bereits
in #125 dokumentierte alternative Werkzeugimplementierung. Laufende oder noch
nicht veröffentlichte Arbeiten, insbesondere weitere Körperteile, Musik und
ARCH-27-Folgeschritte, verbleiben bei ihren Besitzern. Kein fremder Arbeitsbranch
wird verändert, kein neuerer Kopf ohne eigene Übergabe übernommen.

## Gemeinsame Anschlüsse

- Klima- und Flotten-Zukunftsschutz in demselben SaveParticipant erhalten;
  Sprachkatalog nach Schlüsseln und Testverträge nach IDs vereinigt.
- 1.623 Sprachmeldungen für DE/EN, 210 Godot-Tests in genau einer Registry.
- Das gespeicherte Vakuummerkmal steuert jetzt auch den gemeinsamen Shaderhimmel:
  keine atmosphärische Streuung, Wolken oder Nebel; direkte Sonne bleibt erhalten.
  Grafikwechsel und Rückkehr auf einen Planeten mit Atmosphäre sind geprüft.
- Die neue Tastenhilfe erhält den Standardweg **Esc → Einstellungen**. Ein
  versehentlich wörtlicher Zeilenumbruch zwischen Buch und Entwicklung ist korrigiert.
- Der vorhandene Menütest scrollt Schaltflächen der längeren Kapitelhilfe vor
  tatsächlichen Mausereignissen sichtbar. Der erste gemeinsame Lauf hatte hier
  einen Timeout; die ursprünglichen Ergebnisse bleiben im Prüfarchiv.
- Die Artenvergleichsprüfung legt ihre deutsche Testsprache fest. Der frühere
  Windows-Lauf erwartete deutsche Texte und Dezimalkommas bei englischer Systemsprache.
- Das CI-Gesamtbudget je Quellshard beträgt 45 statt 30 Minuten. Die Basis hatte
  einen abgebrochenen Shard; alle Tests und ihre Einzelzeitgrenzen bleiben erhalten.

## Nachweise und Grenzen

Godot 4.6.3, Linux/headless und isolierte synthetische Nutzerdaten. 13 von 14
gezielten Tests bestehen am ersten gemeinsamen Quellstand; der Frontend-Timeout
wird anschließend korrigiert. Frontend und Artenvergleich bestehen danach auf
dem sauberen, unveränderten Folgecommit. Damit sind **15 unterschiedliche
Fach-/Anschlusstests** erfolgreich, jedoch keine lokale Vollsuite behauptet.
167 Python-Fälle ergeben 160 Erfolge und sieben optionale Auslassungen.
Import, Art-/Quellprüfung und generierte Projektansichten bestehen.

[Quellzuordnung und Ergebnisübersicht](evidence/integration-20260916/results.json) ·
[unveränderte lokale Berichte und Logs](evidence/integration-20260916/local-evidence.tar.gz).
Die Veröffentlichung über die GitHub-Anbindung erhält andere Commit-IDs;
sämtliche übertragenen Quell-Trees sind identisch verglichen.

Die vollständige Quellprüfung, gemeinsame Produktions-/Reiseketten und native
Windows-/Linux-Exporte gehören zu den [Checks von #141](https://github.com/MajorDragonfly/voxelverse/pull/141/checks).
Der alte Siedlungs-Grafiklauf von #125 war ebenfalls rot; ein gedrosselter
Headless-Diagnoselauf ist kein Ersatz für dessen erneute native Prüfung.
Ziel-PC-Grafik, Bediengefühl, Langzeitbetrieb und FPS bleiben eine eigene Abnahme.

## Projektverwaltung

`tools/workflow/project.json` führt nun den neuen Kandidaten und die 14 Pakete
als integriert, mit ihren festen Quellständen. README, Detaildashboard,
PROJECT_STATUS, NEXT_PARALLEL_WORK und SVG werden daraus gemeinsam erzeugt.
Die Schätzung bleibt **rund 35 %** des gesamten Zielumfangs: Die Zusammenführung
bereits bewerteter Lieferungen erzeugt keinen künstlichen Fortschritt.

[Issue #137](https://github.com/MajorDragonfly/voxelverse/issues/137) bleibt die
einzige zentrale Rundenliste. Bekannte laufende Zuständigkeiten werden dort
erhalten; die neue Übersicht erklärt keine unvollständige Belegung zu freien Paketen.

Für den Spieltest: Esc → Einstellungen; Hauptmenü → Stammeszeitalter testen
oder Flottentest; im regulären Kreaturenspiel die Einführung, Tiere, Atlas und
Speicher-/Ladevorgänge gemeinsam ausprobieren. Ein Merge ersetzt diesen Test nicht.

Nachtrag zur Live-Übersicht: Detaillierte `integrated`-Lieferungen zählen jetzt
eben der kompakten Eingangsliste. Ein zusätzlicher Statuscommit kann seine eigene
SHA nicht enthalten; deshalb prüft der Live-Abgleich den exakten vorwärts
führenden GitHub-Dateivergleich. Ausschließlich bekannte Dokumentations-/Statuspfade
sind zulässig. Geänderter Spielcode, unsichere Umbenennungen, divergierende Historie
und ein möglicherweise bei 300 Dateien gekürzter Vergleich bleiben abgleichpflichtig.
15 Dashboard-Werkzeugtests einschließlich zwei neuer Regressionen bestanden.
