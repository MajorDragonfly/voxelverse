# INT30 – Gemeinsame Lieferung 01.10.2026

Aktiver Kandidat: [PR #245](https://github.com/MajorDragonfly/voxelverse/pull/245), Branch `agent/integration-int30-20261001`.
Quellanker `c14a407859b7e655f8229c894111f35b0e451a44`, Tree `68b5769db2e518f82648875b4c4faf19889378e3`; folgende Tracking-/Nachweisänderungen sind separat. Die einzige Live-Zuordnung bleibt [#137](https://github.com/MajorDragonfly/voxelverse/issues/137).

## Zusammengeführter Umfang

23 feste veröffentlichte Fachköpfe aus Chats 2–25 sind als Vorfahren erhalten. Chat 11 hat bislang null Produkt-Diff/keinen PR; sein Kartenbereich bleibt zugeordnet. [Alle Eingangsköpfe, Trees und Dateien](evidence/integration-20261001/inputs.json). Die gemeinsame Fachbasis bleibt `2b1ac023db4074c2ce6b7db8fbab09ab929a8435`. #221/RC1 bleibt eingefrorener geprüfter Vergleichsbuild; Quell-PRs und #9 bleiben offen.

Verbunden sind Wasserclock, öffentliche Scannerabfrage, Stammes-Tutorialkarte/Hilfeseite, Bibliotheksvergleich und optionale Galerie mit Import-Refresh, kosmetischer Editor, Gebäudevorlagenauswahl, portabler Gebäude-/Schiffsaustausch sowie lesender Galaxieanschluss. Kopien schützen Originale; Prototypen erzeugen keine neue Epochen-/Wirtschaftsfreigabe. Weltbeschriftungen folgen dem Sprachwechsel ohne neue Dorfmeshes oder Lageränderung.

Gemeinsame Registry: 266 eindeutige Godot-Tests in 18 Verträgen. Katalog: 2.596 DE/EN-Nachrichten. Vorhandene Pflichtgates erhalten; zusätzliche unabhängige native Helferläufe erzeugen vergleichbare Bilder/Bediennachweise am gemeinsamen Tree.

## Belegte Integrationskorrekturen

- Gebäudeimport: gleichzeitig exklusive Datei- und Kopierdialoge erzeugten einen echten Godot-Fehler trotz erfolgreicher Produktassertions. Datei-Auswahl wird vor Kopierbestätigung geschlossen; der Eingabetest prüft den einzigen sichtbaren Dialog. [Erster strikter Fehler](evidence/integration-20261001/owner-connections-checks/results.json), [korrigierte Prüfung](evidence/integration-20261001/building-dialog-recheck/results.json).
- Frischer Import erzeugte acht fehlende GDScript-UID-Dateien. Die native Audioseite bestand 309 Kontrollen und zwölf maßrichtige PNGs, wurde aber korrekt wegen schmutziger Quellen abgelehnt. Tatsächliche Engine-UIDs sind jetzt versioniert; erneuter Import lässt den Checkout sauber. [Original-CI-Log](evidence/integration-20261001/audio-settings-first-ci.log.gz), [sauberer Import](evidence/integration-20261001/clean-import-checks/results.json). Fehlerfilter bleiben unverändert.
- Native Sammelprüfung: Job-Umgebungswerte verwenden den verfügbaren Matrix-Kontext; Ready-for-review startet die Prüfflows ebenfalls. Kontextgrenzen: [offizielle GitHub-Referenz](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#context-availability).

## Tatsächlich geprüfte Fälle

Godot 4.6.3/Linux, isolierte Nutzerdaten, seriell; unveränderte interne Fristen. [Originalbefehle, Engine, geprüfte Quellen und Logs](evidence/integration-20261001/serial-diagnostics/results.json). Lokale und veröffentlichte Trees sind je Lieferwelle identisch; die [Publikationszuordnung](evidence/integration-20261001/publication-report.json) erhält die genaue Provenienz.

| Gezielter Test | Ergebnis | Dauer |
|---|---|---:|
| living_creatures_world_test: drei physische Bewohner, Kolonien und echter Reload | bestanden | 88,131 s |
| domestic_surface_runtime_test: D1.2, physische Habitatankunft und Kontakte | bestanden | 67,050 s |
| weather_runtime_test: Himmel/UI/Wasserclock, Tempo, Pause, Save/Load, A–B–A | bestanden | 150,308 s |
| shipyard_presentation_test: beide Rollen, Dialoge, Kopien/Originalschutz | bestanden | 7,100 s |
| tribe_localization_test: Welt-/Paneltexte ohne Mesh-/Bestandsänderung | bestanden | 31,236 s |
| int30_tribal_guidance_ui_test: echte kontextuelle Hilfen ohne Fortschrittsbuchung | bestanden | 4,882 s |
| int30_creature_appearance_test: kosmetische Bedienung, Historie und Neustart | bestanden | 29,625 s |
| building_editor_input_test: vollständige Eingaben einschließlich korrigiertem Importdialog | bestanden nach belegtem Fix | 10,901 s |

Die vier weiteren UI-Ergebnisse und der rote Vorlauf stehen [hier](evidence/integration-20261001/owner-connections-checks/results.json). 218 Werkzeugtests: 211 bestanden, sieben vorgesehene Skips; Struktur/Katalog/Hygiene/Paketprüfung bestanden. [Werkzeugnachweis](evidence/integration-20261001/tooling-results.json). Ein Plan wählt sämtliche 266 Quelltests plus Runtime aus; die Tabelle oben ist ausdrücklich eine gezielte Prüfung.

## Nächste Schritte und offene Abnahmen

1. Neue tatsächliche FULL-Gates auf dem abschließenden Merge-Tree: alle Quelltests, reale Produktions-/Reisekette, beide Renderer, Windows- und Linux-Exporte; native Modulbilder/Bedienabläufe prüfen. Keine alte RC1- oder Draft-Freigabe übertragen.
2. Gemessene Population-Spitzen und Scannerkosten gezielt messen/beheben. Frühere Reload-/D1.2-Ausfälle treten in der seriellen Gegenprobe nicht auf; deren Lastursache ist damit nicht bewiesen. Rückweg p95 195,2→548,0 ms und p99 322,1→730,0 ms sowie kalte Scannerabfragen bis188,6 ms bleiben offene Messergebnisse.
3. Neuer eindeutig bezeichneter Windows-Kandidat und Lars' Ziel-PC: bewegte Treppe/Scanränder/Mehrfachziele, fertige Hütte+Dorfplatz+echte Vorräte, Stammesbedienung, Material/Wetter/Wasser und zehnminütige1080p-Route. Software-Rendering belegt keine Ziel-PC-Bildrate.
4. Fehlende Weltkartenlieferung11 nachholen; normale Extremsturmplanung bleibt eigenes Folgepaket. Diagnose-Stürme/synthetische Warnungsfixtures sind keine natürliche Wetterkette.
5. Erst nach erfüllten bestehenden Sperren zulässiger main-Merge und nachgewiesene PR-Bereinigung. Fachbranches, bestehende Besitzer und nicht integrierte fremde Arbeit erhalten.

Mittelalter, Neuzeit und die vollständige Weltraumschleife bleiben Entwicklungsziele. Diese Lieferung behauptet weder subjektive Spielspaß- noch Ziel-PC-Abnahme.
