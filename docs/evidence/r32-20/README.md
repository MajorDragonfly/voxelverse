# R32-20 · Baustellenmaterialien / #207

Feste Fachbasis: `2a738a4891a8de11d682c469833ade4dc9b01dfb`, Tree `f2bda4f815df1c73b9d740ca5282917523faf618`. Draft: [#251](https://github.com/MajorDragonfly/voxelverse/pull/251), Ziel `agent/integration-r32-20261002`. Kein Merge, keine Schließung von #207.

## Belegter Anzeigefehler und Korrektur

`Construction.summary()` setzte bei vorab bezahlten Werkzeug-/Gartenprojekten ohne `delivered_materials` die vollständigen Kosten als `delivered` ein. Das bisherige Unterpanel zeigte deshalb beispielsweise 3/3 Holz und 2/2 Stein als am Bau angekommen, obwohl das Projekt keine Trägerlieferung führt. Die neue reine `construction_details_view.gd` liest dieselbe Fachquelle, kennzeichnet den vorhandenen Transportvertrag und lässt unbelegte Liefer-, Reservierungs- und Frachtfelder bei diesen Prepaid-Projekten leer. Das Panel zeigt stattdessen benötigte, bereits bezahlte Kosten und den fehlenden Transportnachweis. Physische Materialprojekte behalten ihre bestehenden exakten Zeilen. Nach dem gemeinsamen JSON-Laden kommen ganzzahlige Mengen als Float-Varianten zurück; der Detailhelfer formatiert diese nun unverändert als Stückzahlen (3 statt 3.0), ohne die Quelle zu ändern.

Ein mengenweiser Verbauzähler existiert nicht. Die Anzeige kennzeichnet dies in DE/EN ausdrücklich; Baufortschritt und angeliefertes Material werden nicht ineinander umgerechnet. Kein neues Inventar, kein neuer Bestand, keine neuen Aufträge oder Lieferzähler. Weltklick-/Controller-/Fracht-/Save-/Wirtschaftscode unverändert.

## Quellen und Anschlüsse

- Ausschließlich Produktdateien `ui/tribe/construction_panel.gd` und eigener `ui/tribe/construction_details_view.gd` samt UID.
- Eigene Tests `tests/r32_20_construction_details_test.gd` und `tests/r32_20_construction_world_test.gd`, eigener Runner `tools/review_r32_20_construction.py`.
- `owner-attachments.patch`: zwei neue DE/EN-Schlüssel, generierte PO-Ressourcen, genau eine Registrierung pro Test im Vertrag `village`, bestehendes 900-s-Weltprüfbudget für den neuen echten Weltverbraucher. Zentral seriell durch R32-01 anwenden. Die vorhandenen Work-/Navigation-/Startup-Guards werden nicht entfernt.
- Appenddateien sind semantische Quellen des Patches. `--prepare-owner-attachments` wendet sie ausschließlich in einem getrennten Reviewcheckout an und lehnt Duplikate ab. Nach Anlegen der Kopie einmal den Katalog generieren und importieren.
- `diagnostic-workflow.yml` ist ein enger CI-Anhang. Nur die getrennte Diagnosebranche enthält ihn tatsächlich unter `.github/workflows/r32-20-construction-evidence.yml`; der Fachbranch überschreibt keine gemeinsamen Workflows.

## Tatsächlich geprüfte Teilstände

| Nachweis | Exakter Quellstand | Ergebnis / Grenze |
|---|---|---|
| Bestehende ConstructionControl / SettlementCollection | `local/baseline-model/results.json`; nach erstem UI-Edit, kein unveränderter Basistree | Positiv; ursprüngliche Nutzer-/Modell-/Savefälle. Dateiname ist historisch, kein Vorher-FPS-Beleg. |
| Bestehende drei direkte Verbraucher | isolierter Tree `ea69203026e9f624d63ccfc20824c0e61e696b53`; `local/scoped-model-2/results.json` | ConstructionControl, SettlementCollection, BuildingPreview positiv. Eigene neue Probe dort negativ wegen native-class-shadowing `Panel`. Gesamtlauf negativ erhalten. |
| Neue Zwei-Siedlungs-Fachprüfung / frischer Prozess | sauberer Kopf `2470d64a40bd72adc37024c61206a3d2bd1b250b`, Tree `d770aebcde32231354f191c5c4c6cb0d77a7b989`; `local/scoped-model-4/results.json` | Positiv: 92 Kontrollen plus 18 im frischen Prozess. Reine radiale Arrived-work-Fixture, keine Physik-/Ziel-PC-Freigabe. |
| Erster lokaler X11-Start | `local/world-gl-1/xvfb.log.gz` | Fehlende libxkbfile; Abbruch vor Godot, kein Gameplaybefund. |
| Erster tatsächlicher GL-Kugellauf | Kopf `2470d64...`, Tree `d770aeb...`; `local/world-gl-3/results.json` / `render.log.gz` / `ledger.json` | Werkzeug, Vorschauklick, gültige Hütte, echter Weltklick und unveränderte Materialbelege erreicht. Transportzeitlimit danach negativ. Nicht zum positiven Gesamtnachweis erklärt. |
| Getrennter nativer CI-Kandidat | `0fffd8d07522bbff2e056dcb4320190c05ce8fa9`, Tree `788c96163d541f55e3dd6fef3795d05157a3959e`, [Run 36972954014](https://github.com/MajorDragonfly/voxelverse/actions/runs/36972954014) | Vier Fachverbraucher positiv; native Gesamtprobe negativ mit drei eigenen Prüfablauffehlern (numerischer JSON-Variantvergleich, UI-Refresh noch ausstehend, angehaltene Navigation vor zweiter Baustelle). Unveränderte Originale in `ci-negative-1`, elf Bildhashes im Weltbericht; ZIP-SHA256 `036792b1c73bbe27d163b5be6bd2b45f3aab4bf8cbce899cad9f9519038ab68a`, Artefakt 11212432770. Lokal zusammengesetzter Kopf `a8f8799c5cb7e67581b1c18e868909ec4fb0a6c1` ist treegleich. |

| Finale komponierte Fach- und Kugelprobe | `6ce719827221ff9c18fcf9236b9f0afc03b64995`, Tree `992648ffcbc7e43cc5f9a2ad1656dba09454787f`, [Run 36974376664](https://github.com/MajorDragonfly/voxelverse/actions/runs/36974376664) | **Positiv**: vier Fachverbraucher, 108 eigene Kontrollen plus 22 im frischen Prozess; vollständige echte Zwei-Baustellen-Kette, 18 Laufzeitlayouts, 13 Original-PNGs. Quellenhash `d71b2d62a685cba33a22b7f73466765ed1abbeae98fc6ee871a797041d920a5a` unverändert und reusable. Lokaler Reviewkopf `e1bc85d23ec4daa222cb12414dfa763b1cb41762` ist treegleich. |

Eigene Negativprobe `scoped-model-3` hatte den vom Fixturehelfer auf 0 gesetzten Ferncursor mit Kampagnenzeit 105 verglichen: wiederholte Aufrufe arbeiteten den bestehenden Rückstand ab. Der Fixturecursor wird jetzt vor Beginn des 5-s-Falls auf die aktuelle Kampagnenzeit gesetzt; keine Produktionsclockänderung und keine Assertion entfernt.

Der negative erste Kugelverbraucher schloss auch den nach neuer Hütte notwendigen Wegeaufbau in die 20-s-Transportphase ein. Der Folgeprüfer wartet die vorhandene reale Navigation separat mit ihrem bestehenden Watchdog ab, bevor die unveränderte Transportgrenze startet, und protokolliert bei Fehler tatsächliche Navigation/Clock/Processing/Bewohnerzustände. Dies allein beweist noch keine historische Fehlerursache. Die Bilder scrollen die realen Materialzeilen in Sicht.

Die erste CI-Kugelprobe erreichte tatsächliche Abholung, blockierte Träger, Pause, gemeinsames Fracht-Save/Load, Ankunft an der pausierten Hütte, alle 18 Layouts und vollständige physische Materialrückgabe. Drei unveränderte Holzreservierungen und Baufortschritt 0 sind im Ledger nach dem Laden dokumentiert; der direkte Dictionaryvergleich scheiterte an int/float-Varianten. Der Folgeprüfer normalisiert nur den Vergleich, wartet den echten periodischen UI-Refresh und die echte Navigation vor dem nächsten Bau ab. Keine Mengenassertion, Navigation-/Workgrenze oder Produktionssteuerung wurde entfernt.

## Reale Mengenbelege und Bilder

Originale in `ci-positive-2`: JSON-Berichte, volle gegzipte Logs und Quellenmanifeste sowie alle 13 unveränderten PNGs. Jeder gespeicherte Bytehash und ursprüngliche Hash steht im Manifest. CI-Artefakt 11213485946, ZIP-SHA256 `2b6b3ff9688703a183948355ae4b55d8e4763db22c44321f5112fbf50a013849`; Downloadretention bis 16.10.2026, die hier eingebundenen Belege bleiben im Repository.

`ledger.json` bindet alle zehn aktiven Materialzustände an Dorf-/Projekt-ID und reale Bewohnerpositionen/Fracht. Mengen in der folgenden Tabelle sind Holz/Stein; „verbaut“ ist durchgehend unbekannt und wird ausdrücklich so angezeigt.

| Zustand | Benötigt | Geliefert | Reserviert | Unterwegs | Zurück | Lager |
|---|---:|---:|---:|---:|---:|---:|
| Hütte reserviert | 6/3 | 0/0 | 6/3 | 0/0 | 0/0 | 7/11 |
| Hütte unterwegs / weggesperrt / nach Load | 6/3 | 0/0 | 3/3 | 3/0 | 0/0 | 7/11 |
| Hütte pausiert, Träger angekommen | 6/3 | 3/0 | 3/3 | 0/0 | 0/0 | 7/11 |
| Hütte in Rückgabe, ungenutzte Reserve erstattet | 6/3 | 3/0 | 0/0 | 0/0 | 3/3 | 10/14 |
| Forstplatz reserviert, nach vollständiger Hüttenrückgabe | 4/1 | 0/0 | 4/1 | 0/0 | 0/0 | 9/13 |
| Forstplatz unterwegs | 4/1 | 0/0 | 1/1 | 3/0 | 0/0 | 9/13 |
| Forstplatz erste Ankunft | 4/1 | 1/0 | 1/1 | 2/0 | 0/0 | 9/13 |

Die tatsächliche Hüttenrückgabe wird mit Lager 13/14, leerem Projekt und leerer Bewohnerfracht geprüft. Danach verbraucht der Forstplatz exakt 4/1; Abschluss und erneutes gemeinsames Save/Load lassen Lager 9/13 und eine existierende Station unverändert. Beim Weltklick und bei Vorschau/Linksklick bleiben Projekt und Savebytes unverändert.

Alle 13 Bilder visuell geprüft. 720p und 1080p bei 150 % zeigen beide Materialzeilen und Aktionen in DE/EN. Bei 800×600/150 % müssen die Materialzeilen und Aktionen im vorhandenen Pane gescrollt werden; die Aufnahme zeigt den unteren Teil, keine gleichzeitige Komplettansicht. Der Test prüft die tatsächliche Erreichbarkeit der drei Aktionen nach Scrollen. Der HUD-Host bleibt R32-14; keine pauschale Ziel-PC-Layoutfreigabe.

[DE, pausierte Hütte](ci-positive-2/r32-20-world/layout-de-1280-150.png) · [EN, derselbe Ledgerzustand](ci-positive-2/r32-20-world/layout-en-1280-150.png) · [echte blockierte Fracht](ci-positive-2/r32-20-world/04-first-blocked-de.png) · [zweite Baustelle](ci-positive-2/r32-20-world/06-second-site-de.png).

## Fachfälle und Reproduktion

Fachmodell: zwei gleichzeitig aktive Baustellen in zwei getrennten Siedlungen, unterschiedliche stabile IDs, echte Reservierungsabzüge und `VillageWork.step()`-Pickups/Ankünfte/Rückgabe. Bewohnerfracht ist nur über die Baustellen-ID gebunden; die andere Siedlung bleibt unverändert. Blockierter Fernpfad liefert nichts. Wiederholter Kampagnenzeitpunkt produziert nichts zusätzlich. Pause, Wiederaufnahme, Rückgabe, abgebrochene Details, JSON-Schreibvorgang und frischer Godot-Prozess erhalten die Belege. Die Vorschau-/Terrainphysik wird damit nicht behauptet.

Weltverbraucher: öffentlicher Stammes-Playtest in der normalen Seed-15838-Kugelkampagne, drei tatsächlich aktive Bewohner. Explizite Testvorbereitung transferiert 16 Holz/Stein aus den endlichen Vorkommen in das Dorf; Werkzeugbau, gültige Platzierung und anschließende Transporte laufen durch die vorhandenen Befehle und physische Bewohner. Zwei Projekte werden im selben Dorf nacheinander platziert (Hütte mit Rückgabe, danach Forstplatz mit Abschluss). Das Modell erlaubt nur ein laufendes Projekt je Dorf. Es wird kein zweites Projektschema eingeführt.

Der normale Träger muss selbst abholen, zum Bau laufen und bei Rückgabe das Lager erreichen; keine gesetzten Ankunftsflags, keine Teleports. Eine kontrollierte Wegsperre entfernt Graphkanten, bis der reale Controller blockiert meldet. Weltklick, HUD-Pause, tatsächliche Bestands-/Fracht-/Reservierungszeilen, globaler Pausezustand, gemeinsames Save/Load, bestätigter Abbruch, DE/EN und 18 Laufzeitlayouts (800×600/720p/1080p × 100/125/150 %) werden geprüft. 150 % ist hier eine Laufzeitskalierungsprobe; die bestehende Einstellungs-/Neustartgrenze gehört R32-15/01.

Befehle auf der isolierten Owner-Patch-Kopie:

```sh
python3 tools/validate_godot.py --godot GODOT --tests r32_20_construction_details_test construction_control_test settlement_collection_test tribal_building_preview_test --skip-main --output OUTPUT_MODEL
python3 tools/review_r32_20_construction.py --godot GODOT --xvfb Xvfb --output OUTPUT_WORLD --display-number 220
```

Lokale Läufe halten die gemeinsame Host-flock-Sperre über ihren gesamten Abschnitt. Der CI-Kandidat läuft auf einem getrennten Runner. Godot `4.6.3.stable.official.7d41c59c4`; Software-GL/llvmpipe, Dummy-Audio und isolierte Nutzerdaten. 3D wird an tatsächlichen Aufnahmegrenzen gerendert; dazwischen bleiben Physik, GUI und der Spielzustand live. Dies ist kein FPS-/Hardwarevergleich.

## Offen / Integration

Die vollständige Quellsuite, gemeinsame Produktions-/Reisekette, native Windows-/Linux-Exporte und vier Pflichtgates gehören R32-01. Der konservative Plan der Owner-Patch-Kopie fordert wegen gemeinsamer Katalog-/Registry-/Runneranschlüsse die volle Suite; dieser Plan wurde nicht als Ausführung oder Freigabe ausgegeben. Keine eigene identische Vollsuite.

Ziel-PC-Sichtprüfung auf Lars' Windows-PC sowie gemeinsame HUD-Abnahme mit R32-14 bleiben ausdrücklich offen. Gleichzeitige Baustellen in zwei Siedlungen sind bislang Fachmodellbeleg; der sichtbare physische Zwei-Dorf-Wechsel bleibt eine eigene kombinierte Abnahme. Kein vollständiges per-unit-Verbau-/Inventarmodell und keine Ziel-PC-Leistung daraus abgeleitet.
