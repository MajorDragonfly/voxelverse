# R32-14 — HUD und Tempo · #178 / #209

Draft [#267](https://github.com/MajorDragonfly/voxelverse/pull/267), Branch `agent/r32-14-hud-tempo`, feste Basis `2a738a4891a8de11d682c469833ade4dc9b01dfb` / Tree `f2bda4f815df1c73b9d740ca5282917523faf618`. AGENTS.md, #137 und die aktuellen Kommentare beider Issues wurden zum Paketstart gelesen. Dateigrenzen entsprechen der R32-Zuordnung.

## Ergebnis und verbleibende Befunde

Die eigene HUD-Schrift wächst jetzt tatsächlich mit 125/150 %. Vitals und Minimap berücksichtigen dieselbe verfügbare Dockbreite; Buchknöpfe und Kampfkopf erhalten getrennten Platz. Die gemeinsamen Stammes-Tabs scrollen auch die sechs Siedlungs-/Frachtaktionen bis zu einer vollständig sichtbaren Position. Lange Berufs- und Zähmungsauswahlen bleiben begrenzt, statt ihre Nachbarn aus dem Panel zu schieben. Scan-/Belohnungsanzeigen werden aus einem bereits verbuchten Beleg in DE/EN gerendert; Sprachwechsel löst keine zweite Buchung aus.

Das Tempo-HUD liest den gespeicherten Kampagnenfaktor. Ein gültiger alter 2×-Save und echter Mausklick auf 3× ergaben vorher Engine 3 × Kampagne 2 = **6×**, gespeichert blieb 2×. Der mitgelieferte R32-01-Patch setzt Engine auf 1 und verwendet den vorhandenen Kampagnen-Setter. 3× bleibt beim Save/Load und frischen Prozess erhalten. Die alten zulässigen 0/1/2/4-Werte bleiben lesbar; 0×/4× werden ehrlich angezeigt, ohne zusätzliche wirkungslose Menüeinträge. Reale Körperbewegung verwendet ebenfalls den vorhandenen Simulationsfaktor. Keine zweite Clock, Produktion, Inventar- oder Saveverwaltung.

Die Fachproben sind grün, die vollständige Produktabnahme bleibt offen:

- In echten Bildern **überlagert die Wetterkarte die Minimap in der Kreaturenphase** bei 800×600 und 720p. Die Rechtecke liegen im Fenster, weshalb Bildschirmgrenzen-Assertions diese Überdeckung nicht als Fehler melden. Anschluss R32-18 (`forecast_panel.gd`) / R32-04 (`minimap_hud.gd`) über R32-01. Bei 1080p/100 % besteht dieser Konflikt im gezeigten Zustand nicht.
- Das offene Stammes-HUD mit ausgewähltem Bewohner lässt bei 800×600 nur **17,94–26,83 %** zusammenhängende Weltfläche frei. Geprüfte Aktionen sind durch Scrollen erreichbar und freie Welt-Rechtsklicks funktionieren; kleiner Bildschirm mit großem Text bleibt eng. Keine allgemeine Komfortfreigabe aus grünen Assertions.
- Fremde Minimap-Schriften bleiben teilweise feste 12/13/15 px; Tooltip „Gesamte Kartenbreite“ bleibt in EN deutsch (R32-04). Im Zähmungs-Unterpanel bleiben deutsche Überschriften/Aktionen/Statuswerte (`world/domestication/domestication_controls.gd`, Besitzeranschluss zentral). Einzelne EN-Bilder zeigen außerdem noch „Buch · J“ im gemeinsamen Auswahlfeedback und eine deutsche Session-Bezeichnung im Esc-Menü; `group_feedback.gd`/Sessionanschluss an R32-01. Gespeicherte Bewohnernamen sind keine Übersetzungsfehler.
- Im Basistree hat das Heimat-HUD ein veraltetes 413-px-Rechteck unterhalb des Fensters: 17 negative Assertions in der vollständigen gezeichneten Vergleichsmatrix. `r32-01-home-hud.patch` korrigiert Größe/Position und macht den reinen Text mausdurchlässig. Eine konkret durch diesen Text blockierte Weltaktion wird damit **nicht** behauptet.

Bewohner-, Bau- und Sammeldetails bleiben R32-19/20/21. Weltkarte, #189 und Draft #246 wurden nicht verändert. Keine fehlende Pflanzfunktion wurde mit einem wirkungslosen Knopf ersetzt; der bereits vorhandene echte Gartenauftrag bleibt erhalten.

## Fachtests und exakter Quellstand

Godot `4.6.3.stable.official.7d41c59c4`; CI Ubuntu 24.04.5, Runner-Image `20260927.320.1`, Linux 6.17.0-1022-azure, Python 3.12.14. Native Aufnahmen: Xvfb 1920×1080, GL Compatibility, Mesa 25.2.8 / llvmpipe LLVM 20.1.2, Dummy-Audio. Isolierte Nutzerdaten, ein schwerer Lauf je eigener Runner-Umgebung, keine FPS- oder Ziel-PC-Aussage. Nach Import dokumentieren vollständige Start-/End-Dateimanifeste einen stabilen, sauber getrackten Quellstand.

| Probe | Ergebnis | CI / exakter Commit und Tree |
|---|---|---|
| Öffentliche Kugelkampagne, Seed 15838; beide Phasen, 36 DE/EN-/Größen-/Skalierungsfälle; Auswahl, Weltauftrag, Bücher, Karte, Esc, Modalblockade; Holzaufnahme/-lieferung, Pause, Wetterclock, 1/2/3×, Bauvorschau, Save/Load | **877 Assertions**, keine Fehler, **48 native Bilder** | [36981430733](https://github.com/MajorDragonfly/voxelverse/actions/runs/36981430733): `a4a3f5f9bbaf640d297865dfd4ad742259007ee0` / `13e8049d149a1a9c08e91ddc5639c895849e3dcd` |
| Echter Dropdown-Klick auf 3× aus gültigem 2×, wirksamer/gespeicherter Faktor, 0×/4×-Anzeige, Pause, atomarer Save, tatsächlicher neuer Godot-Prozess, kollidierende Körperbewegung 1/2/3× | grün; Engine 1, Kampagne 3; Bewegung nach jeweils 12 Physik-Ticks **0,760 / 1,520 / 2,280 m** | [36979922400](https://github.com/MajorDragonfly/voxelverse/actions/runs/36979922400): `e3c1a757cc8ff804abc4fff69ad7db26dc44c22a` / `e3a51edc1b4c126b65e72db050c38a92e3e2c8d8` |
| Gezeichnetes Stammes-Widget, 18 Fälle, alle Tab-Aktionen bis zu einer vollständig sichtbaren Position gescrollt; Ressourcen-/Tempo-/Map-Grenzen | **727 Assertions**, keine Fehler | [36977008828](https://github.com/MajorDragonfly/voxelverse/actions/runs/36977008828): `63b6d0922846ce166142f2fc6bdfe928d827c01f` / `3b84908e2526de8324ce42075129149388edf263`; Gesamtjob wegen damaliger Weltprobe **negativ**, diese Lane grün |
| Kreaturen-Widget, 18 Fälle, eigene Fontskalierung/Dockgeometrie; readonly DE/EN-Belohnungsbeleg | grün | [36976007682](https://github.com/MajorDragonfly/voxelverse/actions/runs/36976007682): `3e0239e617658dce1915275eeffe5453e7e804fa` / `5ef0daa879dba0e9769bebb1bd9ef693937e23aa`; Gesamtjob damals **negativ**, diese Lane grün |
| `campaign_foundation_test`, `far_simulation_test` mit echtem Neustart, `village_work_snapshot_test` inkl. 0/1/2/**3**/4 und exakten Ledger-/Cargo-Vergleichen, `settlement_collection_test` | **4/4 grün**, Source-Contracts und Source-Integrity grün | derselbe Lauf **36976007682** |

Das sind acht abgegrenzte Proben, **keine auf einem gemeinsamen finalen Merge-Tree ausgeführte Vollsuite**. Der finale Code-Tree des Fachbranches ist `cbeb5b6fc5f6017f7ac51a707439624312e2d5ff` (veröffentlichter Codecommit `5a8ec3f1129f07c25afa683efcbef674babc3b96`; lokal `dffc0c6510158b975462e77b1c97ab6424447e3b`, identischer Tree). Die letzte öffentliche Kugelprobe enthält alle eigenen Produktions-/Testdateien bytegleich zu diesem Code-Tree, zusätzlich zentrale Anschluss-Patches. Die Tempo-Lane unterscheidet sich davon nur in der später korrigierten Welt-Testinstrumentierung. Die ältere gezeichnete Stammes-Lane liegt vor der anschließend separat geprüften 0×/4×-Anzeige; ältere Kreaturen-/Vertrags-Lanes vor späteren UI-/Instrumentierungsänderungen. Die vollständigen Trees werden nicht als gleich ausgegeben.

### Tatsächlich bediente Abläufe

In jedem der 36 regulären Kugelfälle: öffentlicher Spielstart und echter bestätigter Phasenwechsel; K/J per InputEvent; Weltkartenknopf per Maus; Esc zum Schließen und erneut zum Pausenmenü; erneut Esc zurück. In jedem Stammesfall: Bewohnerknopf, freier Welt-Rechtsklick mit gespeichertem Ziel/Bewegen-Auftrag, anschließend echter Anhalten-Knopf. Ein Rechtsklick durch das offene Esc-Menü darf den exportierten Kampagnenzustand nicht verändern. Beide Bücher und Karte übernehmen die Pause und geben sie wieder frei.

Danach in derselben Kugelkampagne: Holz sammeln per Knopf, echtes Cargo unterwegs, Pause friert Cargo/Arbeit/Kampagnenzeit ein, Resume liefert Holz ins Lager. 1/2/3× werden mit dem echten Dropdown gewählt; Wetter-Snapshot und Kampagnenclock stimmen überein. Der separate Save-/Neustarttest und bestehende Nah-/Fernsimulationstests vergleichen gleiche vergangene Simulationszeit, Bestände und Ledger. Beim öffentlichen Reload waren geladene und im atomaren JSON gespeicherte Clock exakt `21.4295467222196`; Lagerfingerprint gleich, Faktor 3×. Vergleich mit der serialisierten Clock vermeidet eine falsche Produktionsdiagnose durch Float-Rundung.

Die Bauvorschau verwendet **nach** dem realen Liefernachweis eine deklarierte Fixture: höchstens je 16 endliche Holz-/Steineinheiten werden aus bestehenden Quellen umgelagert, ein Werkzeug gesetzt. Reale Ground-Raycasts/Platzierungsprüfung liefern den grünen Ghost; Esc cancelt die Vorschau vor dem Pausenmenü. Das ist kein Nachweis der gesamten Bau-/Werkzeugproduktionskette.

Die Stammes-Widgetprobe setzt Lagerzahlen auf 12345 als Text-/Umbruch-Stresstest. Die Kreaturen-Widgetprobe überspringt ausdrücklich den Kugelteil; den regulären Weg belegt die öffentliche Kugelprobe. Für Layoutbilder ist der bestehende GameState-Prozess ausgeschaltet, ohne zusätzliche Zeitquelle; für Produktion danach wieder aktiv. Vorher/Nachher-Kugelläufe frieren nach dem echten Einstieg unterschiedliche Clockwerte ein (`0.483021250002311` / `0.379008666666663`), beide Tag 1 / 15:00 und klares Wetter. Daher **kein exakt zeitgleicher Atmosphären-/Performancevergleich**. Widgetvergleich und geometrische Messwerte bleiben davon getrennt.

## Zusammenhängend freie Spielfläche

Die Messung vereinigt Rechtecke aller tatsächlich sichtbaren/gezeichneten `PanelContainer`, zusätzlich eigene Basisflächen und Heimattext; scrollende Kinder werden an Vorfahren beschnitten. Die größte über gemeinsame Kanten zusammenhängende Restfläche wird durch Rechteck-Unterteilung/Floodfill bestimmt. Keine Schätzung aus nur dem eigenen HUD. Dialogflächen zählen nicht zur normalen Gameplay-Messung. Aufnahmen enthalten Anleitung und im Stammesmodus den ausgewählten Bewohner; andere Zustände können andere Werte liefern.

| Größe / Skalierung | Kreatur DE / EN | Stamm DE / EN |
|---|---:|---:|
| 800×600 / 100 % | 60,10 / 60,10 % | 17,94 / 20,63 % |
| 800×600 / 125 % | 53,87 / 53,87 % | 23,78 / 26,83 % |
| 800×600 / 150 % | 47,69 / 50,64 % | 19,58 / 20,89 % |
| 1280×720 / 100 % | 72,32 / 72,32 % | 43,13 / 44,27 % |
| 1280×720 / 125 % | 69,24 / 69,24 % | 47,57 / 47,57 % |
| 1280×720 / 150 % | 66,49 / 67,46 % | 46,01 / 46,01 % |
| 1920×1080 / 100 % | **86,36 / 86,36 %** | **78,15 / 78,66 %** |
| 1920×1080 / 125 % | 84,91 / 84,91 % | 69,12 / 69,12 % |
| 1920×1080 / 150 % | 82,76 / 83,71 % | 67,84 / 67,84 % |

[Originale 36 Fallwerte und Assertions](world-matrix.json). Die #178-Grenze von mindestens 70 % bei **1080p/100 %** ist in beiden Phasen/Sprachen erfüllt. Keine 70-%-Behauptung für andere Größen/Skalierungen; die Basiskampagne erfüllte die 1080p-Grenze bereits.

## Echte Bedienbilder und Originalprotokolle

[PNG-Manifest](native-screenshots.json) enthält Namen, Größe und SHA256 sämtlicher heruntergeladener nativer Aufnahmen; 21 repräsentative Original-PNGs sind dauerhaft im PR eingebettet. Kein KI-Bild oder nachträglicher Bildumbau. Alle 48 finalen Weltaufnahmen enthält [Artefakt 11216390930](https://github.com/MajorDragonfly/voxelverse/actions/runs/36981430733/artifacts/11216390930), SHA256 `f9a264c49b6c37e544b62ea1278f7b5128f6f6834d8e2396f20c3241d7b8ebc3` (Actions-Aufbewahrung bis 01.11.2026).

| Ansicht | Original |
|---|---|
| Kreatur DE, 800×600/150 %; Wetter-/Map-Überdeckung sichtbar | [PNG](images/36981430733-creature-de-800x600-150.png) |
| Kreatur EN, 720p/125 % | [PNG](images/36981430733-creature-en-1280x720-125.png) |
| Kreatur DE, 1080p/100 % | [PNG](images/36981430733-creature-de-1920x1080-100.png) |
| Stamm EN, 800×600/150 % | [PNG](images/36981430733-tribe-en-800x600-150.png) |
| Stamm DE, 720p/125 % | [PNG](images/36981430733-tribe-de-1280x720-125.png) |
| Stamm EN, 1080p/100 % | [PNG](images/36981430733-tribe-en-1920x1080-100.png) |
| Kreaturenbuch / Journal / Weltkarte / Esc | [Buch](images/36981430733-creature-development-book.png), [Journal](images/36981430733-creature-discovery-book.png), [Karte](images/36981430733-creature-world-map.png), [Esc](images/36981430733-creature-escape-menu.png) |
| Stammesbuch / Journal / Weltkarte / Esc | [Buch](images/36981430733-tribe-development-book.png), [Journal](images/36981430733-tribe-discovery-book.png), [Karte](images/36981430733-tribe-world-map.png), [Esc](images/36981430733-tribe-escape-menu.png) |
| Echte Holzfracht während Pause / danach Lager / echter Ghost / Reload | [Pause](images/36981430733-tribe-running-transport-paused.png), [Lager](images/36981430733-tribe-delivered-stock.png), [Vorschau](images/36981430733-tribe-hut-preview.png), [Reload](images/36981430733-tribe-cold-reload.png) |
| Basistree: unsichtbare Siedlungsaktionen nach Scrollversuch | [PNG](images/36977204591-clipped-800x600-150-de-6.png) |
| Basistree: Kreaturen-Schrift bei 150 % | [PNG](images/36974773014-creature-de-800x600-150.png) |
| Gezeichnetes Stammes-Widget mit 12345er Lagerzahlen | [PNG](images/36977008828-tribe-layout-800x600-150-de.png) |

Die `*-original-metadata.tar.xz` enthalten unveränderte Import-/Testlogs, Start-/End-Manifeste, Kommandos, Source-/Loghashes und vollständige Ergebnisse, inklusive negativer Originale. [Dateihashes](files-sha256.json), [alle CI-Commits/Trees/Statuswerte](ci-runs.json).

Negative Ergebnisse werden nicht entfernt oder grün umbenannt: Baseline **36974773014** reproduziert Font-/Scroll-/6×-/Savefehler; **36977204591** die gezeichneten Scrollfehler. **36983041811** beendet dieselbe vollständige Weltmatrix mit 17 Heimat-Rechteckfehlern, Probe `passed=false`, Exit 1; nur der explizite Erwartungstest des Vergleichsworkflows ist grün. **36974380265** enthält zusätzlich Zähmungs-Dropdown-Clipping und frühe Instrumentierungsfehler. **36976007682** enthält alte Popup-Koordinaten-/JSON-Float-Vergleiche. **36977008828 / 36978128148 / 36978661321 / 36978915848**: unveränderte 900-s-Grenze erreicht, weil die Probe unnötig jeden Zwischenframe zeichnete; keine Weltfreigabe daraus. Zeichnen wurde auf Layout-/Bedien-/Capturegrenzen begrenzt, Assertions/Deadline blieben erhalten. **36979757219**: nicht unterstützte Formatierung für 0×/4× (`%g`); auf `%d` korrigiert und in **36979922400** erfolgreich geprüft. Der frühere grüne Weltlauf **36976607638** wird durch die vollständige gezeichnete Probe ersetzt. Frühe lokale Proben unter möglicherweise gleichzeitigem Performance-Lauf sind separat archiviert und keine Performancebelege.

## Zentrale Anschlüsse, Prüfplan und Reproduktion

R32-01 integriert seriell: `r32-01-clock.patch` (GameState/Savevalidator/TribeController), `r32-01-clock-tests.patch` (bestehende Assertion auf autoritativen Faktor, 3× zusätzlich in gleiche-Zeit-/Ledgerprobe), `r32-01-home-hud.patch`, genau vier Einträge aus `r32-01-registry.patch`, neun DE/EN-Appends aus `localization-append.json`. Danach vorhandenen Kataloggenerator ausführen. `r32-01-localization.patch` ist ein enges Basistree-Anwendungsbeispiel; kein konkurrierender Katalog. `.github`, zentrale Registry, Save/Clock/Controller und gemeinsame Styles bleiben im Fachbranch unverändert. Die zwei Workflow-Patches sind optionale Reproduktionsbeispiele; tatsächliche Diagnoseworkflows sind in den exakten CI-Trees einsehbar.

Der Feature-Plan beendet sich mit **Exit 2 wegen vier noch nicht zentral registrierten Tests**, [Beleg](feature-plan-not-executed.txt). Der separate lokale QA-Checkout mit Anschluss-/Registry-Patches wählt konservativ **271/271 Tests und Main**, [vollständiger Plan](qa-plan-not-executed.json). Das ist ausschließlich ein Plan eines schmutzigen QA-Checkouts mit darin erfassten Dateihashes, **kein ausgeführter Vollsuite-Pass**.

```sh
# Nach zentralem Patch-/Kataloganschluss, Godot-Import und in isoliertem Checkout:
python3 tools/validate_godot.py --tests campaign_foundation_test far_simulation_test village_work_snapshot_test settlement_collection_test --skip-main --skip-import --godot /path/to/Godot4.6.3 --output /tmp/r32-14-contracts
python3 tools/review_r32_14_hud.py --godot /path/to/Godot4.6.3 --headless --script r32_14_speed_test --output /tmp/r32-14-speed
python3 tools/review_r32_14_hud.py --godot /path/to/Godot4.6.3 --xvfb /usr/bin/Xvfb --script r32_14_creature_layout_test --output /tmp/r32-14-creature
python3 tools/review_r32_14_hud.py --godot /path/to/Godot4.6.3 --xvfb /usr/bin/Xvfb --script r32_14_tribe_layout_test --output /tmp/r32-14-tribe
python3 tools/review_r32_14_hud.py --godot /path/to/Godot4.6.3 --xvfb /usr/bin/Xvfb --timeout 900 --script r32_14_hud_world_test --output /tmp/r32-14-world
```

Neue Outputverzeichnisse außerhalb des Checkouts verwenden; der Helfer belegt den vorhandenen Host-Mutex vor Godot-Start. Keine fremden Locks/Prozesse verändern. Gemeinsame Produktions-/Reisekette, finaler Integrations-Tree, Vollsuite, vier Pflichtgates, native Windows-/Linux-Exporte und Ziel-PC-/Spielkomfort-/Sichtabnahme bleiben bei R32-01 offen. Beide Issues bleiben offen, PR bleibt Draft.
