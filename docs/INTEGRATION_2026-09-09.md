# Gemeinsame Integration vom 9. September 2026

Die sieben Arbeitsstränge sind in einem Quellstand zusammengeführt. Der Integrationsstand enthält die 19 Teil-PRs #9–#27; ihre exakten Quell-Commits stehen in [integration-sources-2026-09-09.json](integration-sources-2026-09-09.json). Der gemeinsame Stand ist integriert und automatisch geprüft. Der letzte lokal geprüfte Laufzeit-Commit ist `9e9c968`; nachfolgende Änderungen betreffen Roadmap, Übergabe und Prüfnachweise. Alle 19 Quell-Commits sind als Vorfahren nachgewiesen. Die sieben Remote-Spitzen waren bei der erneuten Prüfung unverändert.

## Zusammengeführte Lieferungen

| Strang | Spitze | Enthaltene Teil-PRs |
|---|---|---|
| Planeten/Landschaft | `1832ce4` | #9, #11, #13, #15, #22, #27 |
| Kreaturenwerkstatt | `2169648` | #12 |
| Skilltree/Sozialspiel/Stamm | `bb2c237` | #10, #14, #17, #23, #25; Heimatgruppe #20 ebenfalls übernommen |
| Entdeckungsbuch/Forschung | `5e02662` | #19 |
| Startmenü/Spielstände/Scan | `6a502e8` | #16 |
| Heimatgruppe/Wildtier-KI | `b8c2696` | #20, #21, #24, #26 |
| Sounds/Musik | `9bdbe2e` | #18 |

## Gemeinsame Korrekturen

- Ein Entdeckungsbuch für J und Entwicklung mit Forschung, Vergleich und Merkliste. Entwicklungspfad und getrennte Phasenansichten bleiben erhalten. Das Buch ist auch im Stammeszeitalter erreichbar.
- Scanpflicht bleibt verbindlich: Befreunden, Helfen oder Angreifen entdecken die Art nicht vorzeitig. Alte Entdeckungen werden weiterhin als bekannt übernommen.
- Spielstandplätze/Verlauf, Schema-6-Prüfung, Stammesmigration, Forschung, Beziehungen und atomarer bestätigter Phasenwechsel gemeinsam erhalten. Schreib-/Kauf-/Forschungstransaktionen berücksichtigen sich gegenseitig.
- Stammescontroller und Wildtier-Nahrungsstreamer sitzen beide am Nest; Heimatposition, sichere Schritte und Prüfungen warten auf tatsächliche Weltbereitschaft.
- Audio verwendet den örtlichen Wasserstand von Flüssen und Seen. Scanner bindet sich an den echten Scan, erfolgreiche Gruppenbefehle liefern eine eindeutige Rückmeldung; Befreunden und KI-Warnung liefern passende Laute. Einstellungen enthalten einen Ton-/Musikzugang; F7 öffnet kein zweites Modal über einer fremden Pause.
- Der gemeinsame Beendigungsablauf gibt die Audiowiedergabe frei, solange Szenenbaum und Mixer noch arbeiten. Dies gilt für reguläres Beenden und instrumentierte Abnahmeskripte.
- Exportprüfungen werden um alle betroffenen Fachtests ergänzt; der allgemeine Testlauf berücksichtigt auch die Audiounterverzeichnisse. Ältere Testannahmen zu automatischer Entdeckung und fehlenden Services sind an den tatsächlichen gemeinsamen Vertrag angepasst.

## Prüfung und Grenzen

Geprüft mit Godot **4.6.3** in isolierten Spielstandverzeichnissen:

| Prüfung | Ergebnis | Aussage |
|---|---|---|
| Gemeinsamer Quellstand | **91/91 Prüfungen bestanden** | 66 Testskripte plus Import/Artquellen und 23 Start-/Beendigungs-/Streamingprüfungen. Zusammengefasster Erstlauf und gezielte Wiederholungen nach Korrekturen; der Erstlauf war nicht vollständig grün. |
| Linux-Release außerhalb des Quellprojekts | **28/28 bestanden** | Echtes Release gestartet; Hauptmenü/Pause/Spielstandplätze, Labor, 19 Fachtests am PCK, Stammes-Kaltstart und drei Planeten-Seeds. Instrumentierte Skripte verwenden den Editor mit dem tatsächlichen Release-PCK, weil das Release-Template `--script` sperrt. |
| Windows-Testpaket | Export erfolgreich; **6/6 Inhaltsprüfungen bestanden** | Start, Scan, Spielstände, Stammeswechsel, Versorgung und Interface-Audio am tatsächlichen Windows-PCK mit dem Linux-Editor geprüft. Keine Behauptung einer nativen Windows-Ausführung. |
| Grafik, GPU, Klang, Ziel-PC | **Offen** | Die Bildschirmverbindung war in dieser Umgebung gesperrt. Screenshots, Hörabnahme und Leistung auf Lars’ Windows-PC müssen noch geprüft werden. |

[Zusammenfassung](../validation/integration-2026-09-09/summary.json), [Quellprüfungen mit Herkunft der Wiederholungen](../validation/integration-2026-09-09/source-results.json), [Linux-Export](../validation/integration-2026-09-09/linux-export-results.json), [Windows-PCK](../validation/integration-2026-09-09/windows-pck-results.json). Die ursprünglichen Teilläufe und neuen CPU-Messungen sind im gleichen Verzeichnis erhalten. Historische Benchmarkdateien wurden nicht durch neue Messungen ersetzt.

Die Prüfungen decken die Integrationsnähte ab: ein gemeinsames Buch und Forschung, verpflichtenden Scan, UI/Pausen, Rückabwicklung fehlgeschlagener Speicherung, denselben Bewohnerbestand nach bestätigtem Phasenwechsel und Kaltstart, Versorgung, Wildtierbedürfnisse und Audio. Beschleunigte Simulation verkürzt die Audiobereinigung beim Beenden nicht mehr.

## Bereitstellung und Start der nächsten Runde

Der vollständige Integrationsbranch heißt `agent/integration-2026-09-09`, die ursprüngliche main-Basis war `c9be789b9d1b1effa9e3b30a653c739feb392b25`. Die automatische Freigabeprüfung hatte den ersten öffentlichen Upload blockiert. Lars hat den Upload und die Übernahme nach main anschließend ausdrücklich freigegeben. Vor Veröffentlichung wurden main und alle sieben Fachbranch-Spitzen erneut geprüft: keine neuen Änderungen. Die Veröffentlichung über die verbundene GitHub-Anwendung verwendet einen gemeinsamen Commit mit allen sieben Fachbranch-Spitzen als Eltern und exakt dem geprüften Dateibaum. Die lokalen Integrations-Commit-IDs dienen als Prüfreferenz; die GitHub-Commit-ID wird neu vergeben. Der Integrations-PR erhält einen regulären Merge, damit die Historie sämtlicher Teil-PRs erhalten bleibt. Nach seiner Übernahme beginnen neue Chats vom aktualisierten main und dokumentieren dessen Start-Commit.

`Voxelverse-Integration-Windows-2026-09-09.zip` enthält die Windows-EXE, das PCK, diese Roadmap/Übergaben, Prüfergebnisse und eine Startanleitung. Der einzige Unterschied zum geprüften Spielcode ist der Anwendungsname `Voxelverse Integration 2026-09-09`, damit das Testpaket einen eigenen Spielstandordner verwendet. Native Windows-/Grafik-/Klangabnahme bleibt offen.

Die neue Tierrollen-/Zähmungsanforderung ist in ROADMAP.md als D1–D4 geplant. Milchproduktion, Pflügen, Reiten und Hundeaufgaben sind noch keine fertigen Spielsysteme. Nur die eigene Spezies steigt kulturell auf; die Stammesphase hat einen ersten Dorfablauf, Mittelalter/Neuzeit/Weltraum bleiben kommende Spielschleifen. Die Kugelkampagne bleibt von den bereits besuchbaren Laborkörpern zu unterscheiden. Hörtest und Leistung auf Lars’ Windows-PC bleiben eine manuelle Abnahme.

[Nächste sieben Arbeitsaufträge](NEXT_PARALLEL_WORK.md)
