# INT30 – Gemeinsame Lieferung 01.10.2026

Aktiver Kandidat: [PR #245](https://github.com/MajorDragonfly/voxelverse/pull/245), Branch `agent/integration-int30-20261001`.
Abschließender korrigierter Quellanker `462ee5b2f9427f4097acda981e455c91a75fd1ad`, Tree `306f5fffa8722dc1a733d9c52338e61566f640aa`; folgende Tracking-/Nachweisänderungen sind separat. Erster Quellanker `c14a407859b7e655f8229c894111f35b0e451a44` bleibt in der unveränderten Eingangsliste und den zugehörigen ursprünglichen Nachweisen erhalten. Die einzige Live-Zuordnung bleibt [#137](https://github.com/MajorDragonfly/voxelverse/issues/137).

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

## Erste tatsächliche gemeinsame CI und gezielte Folgearbeit

Die Ready-Prüfung auf `4513216a61cbab8d660b8a8405eb4a9c879b8ff3` verwendet den tatsächlichen Test-Merge `913671c4e5e724df28101c14a111b735dc7708a4` mit identischem Tree `00c718e2a10f6d2a540174d66214eb232a96b63f`. FULL-Plan und Quellverträge wählen 266/266 Tests; Windows/Linux-Export, vier Quellshards, Runtime und acht Environment-Captures wurden tatsächlich gestartet. Dashboard, alle acht neuen nativen Modulabläufe (138 originale PNGs), native Audioseite (309 Kontrollen/12 PNGs) und Galerie (200 Kontrollen/45 PNGs) bestehen mit stabilen unveränderten Quellen. [Verifizierte Artefakte und Quellidentitäten](evidence/integration-20261001/full-ci-first-pass/native-verified.json). Dies ist noch keine vollständige technische Freigabe.

Die erste tatsächliche Prüfung findet weitere Eingabeprobleme: Gebäudeprüfung bleibt nach einem falsch positionierten Klick auf den eingebetteten Kopierdialog hängen; Stammesprüfung erreicht nach dem erneuten Öffnen nicht die erwartete Bauplatzierung; beide exportierten Plattformen scheitern im echten Galaxie-Menüablauf. [Ungekürzte ursprüngliche Fehlerlogs](evidence/integration-20261001/full-ci-first-pass) bleiben erhalten. Korrekturen und erneute Ergebnisse werden separat belegt; Fristen und Erfolgsbedingungen werden nicht abgeschwächt.

Die Population-Folgediagnose bleibt beim bisherigen Besitzer. Der Selektor fragt bis zu 25 Regionen vor der vorhandenen 4-ms-Generierungsentscheidung ab; diese Regionen sind bereits gepinnt, daher bedeuten 25 Aufrufe nicht 25 Disk-Lesevorgänge. Zu messen sind Selektionsdauer, tatsächliche Lese-/Schreibdeltas, Veröffentlichungszeit und konkrete Spawn-Aufschubgründe je Tick. Der Messrecorder liest alle 250 ms über den normalen LRU-/Dirty-Pfad; seine Beobachtung kann selbst Speicherarbeit verändern. Diese Messbeeinflussung muss bei der getrennten Tooling-Folgearbeit neutralisiert werden.

Der gemeinsame Scanneranschluss wird in der Population nur bei voller Bewohnerzahl und einer fehlenden Katalogrolle für den Fokus-Schutz abgefragt. Häufigkeit und Dauer dieser bedingten Abfrage gehören separat in die Messung. Keine neue Cache-/Guard-Änderung wird ohne belegten Produktfall vorgenommen. Die ursprünglichen Maximalzähler belegen keine allgemeine IO-Zunahme und keine alleinige Hostlastursache. Nächster Vergleich: ursprüngliche und neue Population mit identischer eingefrorener Route, Regionfixture, Instrumentierung und Renderer seriell messen; vorhandene Grenzen und Fehlprotokolle erhalten.

### Gebäude-Eingabefixture: belegte Korrektur

Die echte Pointer-Gegenprobe bestätigt: lokale Koordinaten des eingebetteten Bestätigungsfensters erreichen beim Dispatch auf den Root-Viewport keinen Button. Der Fixture ergänzt den Fenster-Versatz, prüft das tatsächliche Schließen und prüft beim Löschen jeden einzelnen Fortschritt innerhalb einer begrenzten Schleife. Keine Produktionsänderung; dieselbe 180-s-Helferfrist. Erneuter vollständiger Eingabetest: 563 Assertions, 13,36 s, strikte Fehlerprüfung und saubere Quellintegrität. [Pointer-Probe und erneuter Test](evidence/integration-20261001/ci-input-fixes). Die tatsächliche native Wiederholung auf dem korrigierten gemeinsamen Tree bleibt erforderlich.

### Stammes- und Galaxie-Eingabefixture: belegte Korrekturen

Nach Escape hatte die Stammesprüfung das Scrollziel vor dem fertigen Containerlayout ermittelt. Der Försterbutton wanderte danach aus dem sichtbaren Bereich; die anschließenden Weltklicks erzeugten Laufaufträge. Die Korrektur wartet vor dem Scrollen auf das Layout und prüft den sichtbaren Klickpunkt, echten Hover sowie Platzierungs-/Rollback-/Commitzustand. Der vollständige `tribal_guidance_world_test` besteht in 110,475 s mit allen elf echten Aktionsmeilensteinen, unveränderten Erwartungen und Fristen. [Gegenprobe und strikte Quellenintegrität](evidence/integration-20261001/ci-input-fixes/tribal-world-recheck.json).

Die alte Galaxie-Menüprobe klickte Speichern/Besuchen unterhalb des sichtbaren Scrollbereichs. Fünf ursprüngliche Exportfehler sind im realen Ablauf reproduziert. Der Diagnosepfad scrollt jetzt über den vorhandenen UI-Port und sendet dieselben echten Mausereignisse; sämtliche Notiz-/Wiederbesuchs-/physischer-Planet-/präziser-Rückkehr-Assertions bleiben erhalten, sichtbare Klickpunkte werden zusätzlich geprüft. Korrigierter voller Ablauf und anschließend unveränderter Produktions-Einstieg `--input-smoke` bestehen (45,914 s, keine Fehler, saubere stabile Quellen). [Baseline, Geometrie und unabhängiger Einstieg](evidence/int30-packaged-galaxy-input/README.md). Windows-/Linux-Pakete und FULL-Gates müssen die gemeinsame korrigierte Revision erneut tatsächlich prüfen.

## Abschließender korrigierter Kandidat

Die drei Eingabe-Korrekturen sind gemeinsam enthalten. Es wurden keine Produktregeln, Fristen, Erfolgsbedingungen oder Pflichtgates gelockert. Der korrigierte Quellanker wird als eigener unveränderlicher Commit angelegt; Status/Nachweise folgen als separater Commit, erst danach wird der Kandidatenbranch einmal weitergeschoben. Alle 23 ursprünglichen Lieferköpfe und ihre Besitzer bleiben erhalten. [Revisionszuordnung](evidence/integration-20261001/corrected-source.json).

Die erneute tatsächliche FULL-Prüfung verlangt 266 Quelltests, 27 Runtime-Fälle, acht Environment-Captures, native Modulabläufe und Windows-/Linux-Pakete. Vor dem Branchwechsel bestehen im ersten FULL-Lauf alle acht tatsächlichen Environment-Captures samt Environment render gate. Alle vier Quellshards stehen noch aus; deren spätere Abbrüche sind keine Erfolge. Bekannte rote Export-/Bedienlogs bleiben erhalten. Keine vollständige technische Freigabe oder Ziel-PC-Abnahme wird aus dem gezielten Fixnachweis abgeleitet.
