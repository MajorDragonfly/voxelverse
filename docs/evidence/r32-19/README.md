# R32-19 · Bewohnerdetails · #206

Feste Fachbasis: `2a738a4891a8de11d682c469833ade4dc9b01dfb`,
Tree `f2bda4f815df1c73b9d740ca5282917523faf618`.
Die einzige Belegung steht in [#137](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-5946206999).
Draft: [#258](https://github.com/MajorDragonfly/voxelverse/pull/258).

## Änderung und Besitzeranschlüsse

Die Erstlieferung ist vorhanden: Die Liste und die Weltselektion verwenden
Bewohner-IDs; die Karte liest Nahrung/Wasser dynamisch. Das Basisblatt lässt
Gesundheit und Arbeitsplatz aus und ersetzt beim Tragen den Auftrag durch die
Fracht. Der Dorfwerkzeugzähler stammt aus `B.tribe.tools`, nicht aus persönlichem
Besitz.

Neue eigene Blätter: `resident_details_view.gd` löst bei jedem Refresh die einzelne
ID aus dem aktuellen Dorfbestand und gibt ausschließlich unabhängige skalare
Anzeigewerte zurück. Mehrfachauswahl, fehlende oder doppelte Identitäten erzeugen
kein Einzelblatt. Die Gesundheit kommt ausschließlich vom gültigen geladenen
Actor dieser ID; fehlende, gelöschte oder unpassende Actors liefern keine erfundene
volle Gesundheit. `resident_details_panel.gd` zeigt Gesundheit, Beruf/Auftrag,
Nahrung/Wasser, separate Fracht, tatsächlich zugewiesenen Arbeitsplatz und die
fehlende persönliche Ausstattung. Das Modul besitzt keine Simulation, Speicherdaten
oder neue Inventarverwaltung.

`patches/tribe-panel.patch` ist der enge Anschluss für R32-14/R32-01. Er ersetzt
nur den Detailaufbau/Refresh, behält die alten sieben Label-/Meterports als Aliase
für bestehende Verbraucher und zeigt den Auftrag neben der Fracht. Gemeinsame
Hostdateien bleiben im Fachbranch unverändert. Der Patch muss seriell auf R32-14s
HUD-Stand übertragen werden; `git apply --check` gilt nur für die feste Basis.

`patches/localization-append.json`: neun DE/EN-Nachrichten an den zentralen Katalog
anhängen und `python3 tools/localization/catalog.py` ausführen.
`patches/test-registry-append.json`: die beiden Tests genau einmal unter `village`
registrieren. Keine bestehende Registry/PO-Datei wird aus diesem Branch ersetzt.
Die eigenen Tests installieren die noch ausstehenden Übersetzungen ausschließlich
in ihrer isolierten Testumgebung.

## Bisherige Originale und ehrliche Testgrenzen

Godot `4.6.3.stable.official.7d41c59c4`, Linux-Container Host `db514e109ac6`,
Seed 15838. Jeder spätere Godot-/Capturelauf hält den gemeinsamen R32-Mutex.
Vor Kenntnis der verschärften Heavy-START-Meldung begonnene leichte Prüfungen
sind mögliche Fremdlast in R32-02s Original; keine Timing-/FPS-Aussage daraus.

- `initial-freed-actor-negative.log`: erster eigener Helper dereferenzierte einen
  bereits gelöschten Actor beim `is`-Check. Guard-Reihenfolge korrigiert; der
  strenge Runner muss auch bei einer positiven JSON-Aussage SCRIPT ERROR ablehnen.
- `fixture-prerequisites-negative.log`: ursprüngliches Testdorf ohne Brunnen,
  hydration 100 und damit kein konsumiertes Wasser. Kein Produktfehler abgeleitet.
- `fixture-freeze-negative.log`: UI-Matrix hatte Tribe-Physik selbst angehalten;
  Reload-Navigation konnte deshalb nicht fortsetzen. Der Test löst seine eigene
  Freeze vor Load. Keine Produktregel, Assertion oder Deadline gelockert.
- `fixture-cold-positive.log`: korrigierte kurze Probe, 56/56 Aussagen sowie echter
  frischer Godot-Prozess `R32_19_COLD_PASSED`. Echte Controller, Mausereignisse,
  Holz-Pickup/Stop, vom normalen Brunnen erzeugtes/geliefertes Wasser und normaler
  Trinkbefehl: drinks 0→1, 60→89,969% Wasser, Detail 89,976% im vorhandenen
  0,2-s-Refreshintervall. Die Testfixture hat einen vorgebauten Brunnen und
  kontrollierten Durst; dies ist keine Prüfung seines tatsächlichen Baus.

Die kurze Probe ist eine flache Testszene, kein Kugelkampagnen- oder Ziel-PC-Beleg.
Der Modelltest enthält 19 Aussagen mit echter `VillageWork`-Arbeit/Verbrauch,
JSON-Wiederherstellung, autoritativer `VillageSimulation.advance`-Fernarbeit,
Near-Ownership-Sperre und Actor-Lifecycle. Er ersetzt keinen visuellen Reiseablauf.
Neue Probe `review_r32_19_world.gd` nutzt den regulären Titel/Kugelslot und echte
Arbeit; eine vorbereitete Probe allein ist ausdrücklich kein Positivnachweis.

## Offene Modell-/Abnahmegrenzen

Persönliche Werkzeug-/Kleidungsslots, Zuweisungsregeln und Speicherung existieren
nicht im Dorfmodell. Das Detail behauptet weder persönliche Werkzeuge noch
persönlichen Besitz aus dem gemeinsamen Dorfbestand. Das bleibt ein separat
zugeordnetes Modellpaket.

`HomeCompanion.current_health/maximum_health` existieren nur am geladenen Actor.
`TribeState.members` enthält keinen persistierten Gesundheitsport für Gefährten;
beim Wiederaufbau initialisiert der bestehende Actor wieder seine Gesundheit.
Die neue Anzeige verändert diese Regel nicht und nennt die Grenze im Tooltip.
Ein allgemeines Gesundheits-/Save-/Fernmodell ist hier nicht implementiert;
R32-01 muss einen solchen Anschluss mit dem Dorfbesitzer separat abstimmen.

150% in dieser Matrix ist ein Laufzeitwert, keine Abnahme des derzeit auf 135%
begrenzten Neustart-/Einstellungsports; dessen Patch gehört R32-15/R32-01.
Die feindliche/unbekannte ID wird in den Fachproben abgewiesen; ein kombinierter
sichtbarer feindlicher Welt-Treffer und Reise-/Nah-Fern-Zyklus bleibt bis zum echten
Kugelbeleg offen. Windows/Lars' Ziel-PC, GPU-Leistung und gemeinsame Integration
werden durch Container-/Fixture-Belege nicht freigegeben. #206 bleibt offen.

## Abgeschlossener fokussierter Quelllauf

Geprüfter sauberer QA-Commit `7b0c33e1f296829d7b7fe7dba6017e62344c3209`,
Tree `589e8b9380a8ed7347ed27bed6904883546ff571`: eigener Fachcode einschließlich
explizit angewendeter TribePanel-/Katalog-/Registryanschlüsse. Eigene Produktdateien
stimmen bytegleich mit der Fachlieferung überein. Import und Kugelhelfer-Parserprüfung
bestanden; danach `validate_godot.py --tests r32_19_resident_model_test
r32_19_resident_ui_test tribe_localization_test --skip-import --skip-main`.
19 Modell-, 452 volle UI-/Cold- und 970 vorhandene Sprachkontrollen positiv;
strenger ERROR-/Leakfilter und SourceRun stable/reusable. Vollständige Originale
und Quellmanifeste in `focused/`, genaue Befehle/Hashes in `focused/results.json`.

Der native lokale Abschnitt bleibt **negativ**: `native-display-negative/` enthält
Xvfb-Socketfehler, DisplayServer-Fehler/Leak beim Abbruch und null Bilder. Nicht als
Spiel-/Renderfehler abgeleitet, nicht mit Headless überschrieben. Getrennter
GitHub-Diagnosehost wird für tatsächliche native Belege verwendet.
