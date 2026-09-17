# Stammes-Spieltest: erste Umsetzung

Basis: `176d088d34324de14952bc7506fe9763a22cf4b0`, Godot 4.6.3.
Teilauftrag aus [Runde #137](https://github.com/MajorDragonfly/voxelverse/issues/137):
erste Lieferung für M6-ORDER-LATENCY und M6-TRIBE-HUD. Der Gesamtplan steht in
[PR #145](https://github.com/MajorDragonfly/voxelverse/pull/145).

## Geänderte Bedienung

- **Aufträge** enthält Sammeln, gemeinsame Versorgung, Anhalten und Fortsetzen.
  **Bauen** enthält Werkzeug, Hütten, Zelte, Garten und die Baustellenverwaltung.
  Einzelnes Essen/Trinken und der Nahrungsvorrat-Auftrag stehen bei
  **Arbeitsplätze & Berufe** zusammen mit den weiteren Wirtschaftsaktionen.
- Bewohner zeigen Name, Beruf und aktuelle Arbeit in zwei Zeilen. Der Tooltip
  enthält weiterhin Sättigung, Wasser und den zugewiesenen Arbeitsplatz.
- Kleinere Abstände und Schaltflächen sowie bedarfsabhängige Detailseiten geben
  mehr Weltfläche frei. In der geprüften 1920×1080-Ansicht mit drei Bewohnern
  und 100 % Schriftgröße ist das aufgeklappte Alltagsmenü 316 px hoch (29,3 %).
  Dies ist eine geprüfte Beispielsituation, keine Höhengarantie für jeden Bestand.

## Auftragsverarbeitung

Unveränderte Dorfobjekte behalten ihre Meshes und Materialien bei einer reinen
Zuweisung. Änderungen an Fundstellen, Baustellen oder Tierhaltungsobjekten lösen
weiterhin die nötige Aktualisierung aus. Die Oberfläche wird pro Zuweisung einmal
aktualisiert; verborgene Tierhaltungs-/Nachbarseiten werden beim Öffnen nachgezogen.
Schriftgrößen werden bei einer Skalierungsänderung oder neuen Arbeitsplatzzeilen
erneut angewandt.

Der SaveService schreibt genau die JSON-Zeichenfolge, die er zuvor erzeugt und
validiert hat. Die zweite Serialisierung entfällt. Schema-/Readback-Prüfung,
atomare Staging-Datei, Backup, Präzision und Rücknahme fehlgeschlagener Aufträge
bleiben bestehen. Es gibt keine neue Speicherstruktur oder asynchrone Bestätigung.

`last_order_metrics` trennt Vorbereitung, Speichern, Darstellung und Rückmeldung;
`committed` unterscheidet gespeicherte Aufträge von einer bloß begonnenen
Bauplatzwahl. `last_save_metrics` zerlegt den tatsächlichen Speicherlauf.
Diese Diagnosedaten werden nicht im Spielstand gespeichert.

## Messung und Grenzen

Identische Probe mit normalem Kugel-Spieltest-Einstieg, Seed 15838, jeweils fünf
abwechselnden Holz-/Steinaufträgen; Linux-Container, headless. Separate Aufrufe
für Save, Darstellung und UI sind zusätzliche Messungen, keine addierbaren
Teilzeiten desselben Auftrags. Mediane in Millisekunden:

| Messung | Basis | Änderung |
|---|---:|---:|
| Vollständiger Auftrag | 52,774 | 50,314 |
| Separater Speicherlauf | 44,181 | 45,775 |
| Unveränderte Dorfobjekte aktualisieren | 1,385 | 0,070 |
| Oberfläche aktualisieren | 1,113 | 0,700 |

Die kleine Stichprobe belegt weniger Darstellungsarbeit, aber **keinen belastbaren
Gesamtlatenz- oder Speichergewinn**. Mehrsekündige Wartezeiten des Windows-Spieltests
wurden hier nicht reproduziert. M6-ORDER-LATENCY bleibt bis zur repräsentativen
Ziel-PC-/Framezeitmessung offen. Rohdaten und die unveränderte Vergleichsprobe
liegen unter [evidence/m6-orders-first](evidence/m6-orders-first).

## Prüfbeleg

Acht gezielte Prüfungen bestanden: `tribal_order_latency_test` (100 gespeicherte
Aufträge mit wechselnder Auswahl, stabile Dorfobjekte, Schreibfehler, Transport-
Reload, 1080p-Höhe und echte Klicks auf den Baureiter), `tribal_age_test`,
`tribal_age_supply_test`, `tribe_localization_test` (913 Prüfungen, drei Reiter,
DE/EN, 800×600 bis 1920×1080, 100/150 % Schrift), `construction_runtime_test`
(physischer Bau, Pause, Rücktransport, Wiederaufbau, Live-Load und zwölf Layouts),
`save_slots_test`, `coordinate_persistence_test`, `frozen_body_serialization_test`.
Die letzten drei sichern die geänderte gemeinsame Schreibstrecke ab.

Aufruf jeweils `python3 tools/validate_godot.py --godot <Godot-4.6.3> --tests
<gezielte Tests> --skip-main --output <Prüfverzeichnis>`. Genaue Befehle,
Quellinventare, Umgebungen und komprimierte Logs stehen im Nachweisordner.
Frühere Einzelbelege werden nur für unveränderte betroffene Implementierungen
wiederverwendet; spätere UI-/Testanpassungen besitzen eigene Nachweise. Die
Gesamtergebnisse früherer Diagnoseläufe werden nicht als vollständig grün ausgegeben.
Lokalisierungskatalog (1625 Meldungen, zwei Sprachen) und `git diff --check` bestanden.

Die UI-Belege prüfen reale Godot-Controls und Eingaben headless. Ein grafischer
Screenshot ließ sich in dieser Umgebung nicht erzeugen; visuelle und Windows-
Abnahme stehen aus. Die vier Integrationsgates müssen vor einem Merge grün sein.
Kamera, sichtbare Lagerhaufen, Tutorial und Planetenansicht folgen als eigene
Pakete. Auch der vollständige HUD-Umbau ist mit dieser ersten Lieferung nicht
abgeschlossen.
