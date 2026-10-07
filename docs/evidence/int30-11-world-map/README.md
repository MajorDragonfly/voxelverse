# INT30-11-WORLD-MAP – fortgesetzte Bedienlieferung

Bestehender Besitzer/Branch: `agent/int30-11-world-map`. Historische Fachbasis
`2b1ac023db4074c2ce6b7db8fbab09ab929a8435`, Tree
`5f815f478ceeabefcfc50a6388e3e4b0daa2ac45`. Vergleich R33/main
`94de70cacd250337976b8f63031fff4afc72e2bb`, Tree
`58506a6feba11be547197223fa319e7265cf4d99`.
[Draft #271](https://github.com/MajorDragonfly/voxelverse/pull/271) geht gegen
`agent/integration-r33-20261007`. Kein Rebase und keine Ersatzkarte.

## Produktdelta

- Erreichbare Legende und vollständige scrollbare Ortsdetails; der kompakte
  Karten-/Ortswechsel behält ein vollständiges Ergebnis und beide Seitentasten.
  Auf kleinen Fenstern liegen Ortstyp/Eigene/Freunde im Legenden-Drawer; die
  Typauswahl kehrt zur Trefferliste zurück. Große Fenster zeigen die Filter
  direkt bei der Liste. Spielposition, Norden und unbekannter Boden sind erklärt.
- Ortstypen werden inkrementell über alle bestehenden archivierten Seiten
  gezählt. Nur tatsächlich sichtbare bekannte Marker liefern Filter/Anzahlen.
  Liste und Canvas bleiben auf 64 Resultate begrenzt. Standard- und Suchpaging
  teilen denselben Sichtbarkeitsport; rohe Archivtotale erscheinen nicht mehr.
- Spieler-/Bewohnerpunkte werden skaliert über überlappenden Ortsglyphen
  gezeichnet; der Spieler bleibt auch genau im eigenen Nest/Heim sichtbar.
- Maus-Hitbox und Zeichnung teilen dieselbe quadratische Texturgrenze und den
  skalierten Rand. Ein unsichtbarer Marker in den Letterboxrändern ist nicht
  anklickbar. Native Steuerelemente behalten ihre Pfeiltasten.
- `Erkundetes` liest vorhandene Kugelzellen mit vier Längengrad-Schnitten,
  64 Arbeitsschritten/soft 2-ms-Budget, festen Extents und begrenztem Trie-Stack.
  Es behält jede bekannte Zelle, einschließlich archivierter Kacheln; keine
  heuristische Umkehr eines mehrdeutigen Min/Max-Extents. Maximalzoom bleibt
  `PI * radius`. Trie-Tiefe/Schlüssel-/Kachelvalidierung und Lebenszyklus gelten.
  Der schmale `atlas_chart`-Adapter erbt die bestehende Core-Projektion und
  ersetzt ausschließlich die ungenaue Randumwicklung bei Kugelprojektion/
  Zentrumsklammerung. Adresse, Format, inverse Projektion und Ebenenverhalten
  bleiben beim vorhandenen Core; keine gemeinsame Core-Datei wird geschrieben.
- Kartenöffnen ruft keinen Exploration-Schreiber auf. Kartenbewegung, Suche,
  Filter, Zentrieren und Sprachwechsel verändern keine Erkundung/Progression.
  Freundschaft/Tod/Körperidentität bleiben beim existierenden Eigentümer;
  nie erkundete Habitate werden auch bei gespeicherten Markern nicht gezeigt.

Nur die fünf zugewiesenen Kartenblätter, eigene `atlas_fit_query.gd` und `atlas_chart.gd`/UIDs,
zweier eigener Fachtests/UIDs und diese Belege ändern sich. ExplorationTracker,
Core-Map/Atlasformat, Save-Lebenszyklus, Minimap und Kamera bleiben bytegleich
zur jeweiligen Basis. Keine Kartenorte, neue Speicherstruktur oder Migration.

## Enge Besitzerports an R33-01

`patches/apply_append.py ISOLIERTER_CHECKOUT` ist eine reproduzierbare Vorlage,
keine Berechtigung zum parallelen Umschreiben gemeinsamer Produktionsdateien.
R33-01 wendet die Änderungen seriell am Integrationsstand an:

1. `localization-append.json`: zehn neue DE/EN-Einträge an den vorhandenen
   Nachrichtenkatalog anhängen, bestehende Schlüssel erhalten; vorhandenes
   `tools/localization/catalog.py` erzeugt PO/Registry.
2. `registry-append.json`: die zwei neuen Tests genau einmal in `discovery_map`
   registrieren. Der Kampagnentest nutzt dieselbe bestehende Long-Test-Frist
   wie die anderen echten Kaltstart-/Reiseketten; keine Assertion/Loadfrist
   im Godot-Test wird gelockert.
3. Die vorhandenen `world_map_localization_test.gd` und `atlas_places_test.gd`
   warten an ihren bisherigen Seitenwechseln auf die jetzt begrenzte asynchrone
   Sichtbarkeitsabfrage. Die 1000-Frame-Grenze und alle Assertions bleiben.
   Die Ally-Fixture besucht ausdrücklich ihr Habitat vor der Sichtassertion;
   ohne diesen Besuch muss der Marker verborgen bleiben.

Ports wurden ausschließlich im eigenen isolierten Vergleichscheckout auf
R33-Basis angewandt. Der Fachbranch schreibt keine der gemeinsamen Dateien.
Der konservative Änderungsplan des Vergleichsstandes fordert die vollständige
288-Test-/Runtime-Integration wegen gemeinsamer Katalog-/Registry-Anschlüsse;
Fachproben ersetzen diese R33-01-Abnahme nicht.

## Originale und fachliche Prüfung

`original-analysis.md` sichert den ursprünglichen Auftrag und die unveränderte
Analyse aus #137 samt Links. Frühere GL-Aufnahmen/Basisbelege bleiben ihre
historischen Belege; sie werden nicht als neue Produktabnahme ausgegeben.

- `runs/focused-01`: eigener negativer Originalstand `aef92e7c` /
  `ce757951`, 5/7 Quelltests positiv. Neue kompakte Such-/Paging-Überhöhe;
  zusätzlich nicht erkundete historische Ally-Fixture korrekt verborgen.
- `runs/focused-02`: eigener negativer Originalstand `187fee25` /
  `c866b4e6`, Layout weiter negativ; bekannte Habitat-Fixture/Asyncports
  korrigiert, Assertions/Fristen unverändert. Kein grüner Gesamtstatus.
- `runs/focused-03`: sauberer Stand
  `da430dc60af55151233e470dd8b1ed863ef9d3ed`, Tree
  `594ae80e86e569a1fe735691c1b29c34e8f2c8d4`. Import und
  `atlas_search_test` 32,282 s, `atlas_places_test` 44,968 s,
  `int30_world_map_model_test` 13,635 s streng positiv. Source-Provenienz
  stable/reusable, tatsächliche Start-/End-JSONLs und originale Loghashes.
  3105 archivierte Orte, 1025-Orts-Typcensus, cache <=96 / Triepages <=128;
  gepagter/inline Kugelnaht-Fit, breites Erkundungsgebiet, Abbruch/Body-Rebind,
  unsichtbare Hitbox und Save-/Neustart-/Fehlerfälle.

Engine überall `4.6.3.stable.official.7d41c59c4`, Linux. Fachrunner-Aufrufe
stehen unverändert in den JSON-Ergebnissen. Die `.gz`-Dateien enthalten die
originalen Bytes, deterministisch komprimiert. Ein Heavy-Lauf pro Host,
beide zentralen hostlokalen Locks durchgehend gehalten.

- `runs/native-01-display-negative`: originale negative Umgebungsprobe,
  Xvfb fehlte zunächst `xkbcomp`; kein gestartetes Spiel und keine Produktabnahme.
- `runs/native-02`: sauberer `90881e80f9c6a806a668bf71f43cf787a74b7746`,
  Tree `d436042776d03a9eddfa36df8c9020482dd94708`, 55 Original-PNGs,
  Source stable/reusable. Gesamtprobe bewusst negativ: die neue Fixture
  vermischte physische Bildschirm-/gestreckte Viewportkoordinaten und schickte
  Dropdown-Tasten an das Elternfenster. Kaltstartvergleich normalisierte nur
  eine Seite der JSON-Floats. Zusätzlich konkreter Bildbefund: überlappende
  Ortsglyphen verdeckten den Spielerpunkt. Unveränderte ursprüngliche Logs,
  Assertions und Bilder bleiben erhalten. Körperreise/ID-Isolation bereits
  durch die tatsächliche Produktionskette im Originalprotokoll dokumentiert.

- `runs/focused-04`: sauberer `c913613dbe66b2596b611704cfc063dc9d03a494`,
  Tree `5b0529b44484483193828f16da73829001e74a48`, Sprache und Minimap
  positiv. Der verschärfte Nahttest ist negativ: tatsächlicher Besuchsdelta
  -110 m bei gefittetem Radius 64 m. Frühere reine Bounds-Assertions reichten
  dafür nicht aus; die neue Besuchsassertion bleibt unverändert bestehen.

- `runs/seam-diagnosis-01`: sauberer `c73a5108f8c5dc3f7122d5829b4b162749ccf153`,
  Tree `af5994f7af748bdeeac365f035ef169009b67720`, ursprünglicher negativer
  Fit mit gespeicherten beiden Besuchszellen (`known=true`) und allen vier
  Extents. Drei Schnitte haben 182 m, der Schnitt nahe `PI` fehlerhaft 90 m.
  Der genaue Wrap-Fix wird gegen dieselben Besuchsassertionen geprüft.

- `runs/focused-05`: damals geprüfter sauberer Karten-/Teststand
  `827e99df22cb55267828f625c87332334ea43e75`, Tree
  `78326bee0ce8503261f5e1718b00508d95e1a4d8`. Frischer Import 16,063 s,
  Modell 546 Checks / 11,998 s und direkter `atlas_search_test` 43,065 s
  streng positiv. Vollständige Quellenprovenienz stable/reusable, Start-/End-
  SHA256 `7b3cbac5c1d5175f696f6b2363de365051fe09a20797f8ad4ade578efa29fcf4`.
  Engine-Wrap-Original `-PI` versus präziser Kartenwert `PI-0,00001`, Fit
  182 m und echte Besuchsdelta -64/+62 m. Dieselben Besuchsassertionen,
  zusätzlich asymmetrische Zentren/Roundtrip, inline/gepaged und breite
  Erkundung positiv. Keine Assert-/Fristenlockerung.

- `runs/native-03`: sauberer Stand wie focused-05, präzisierte physische
  Fenster-/Viewportkoordinaten und beidseitig normalisierter JSON-Vergleich.
  55 Originalbilder; tatsächlicher Naht-Fit und heller Spielerpunkt positiv,
  neue synthetische GUI-Eingabe weiterhin negativ. Alter Launcher bricht nach
  420 s ab und hat keinen regulären SourceRun-Endreport geschrieben. Die
  getrennte `timeout-source-observation.json` ist ausdrücklich ein späterer
  unveränderter Quellenvergleich (originales Start-/separates Endmanifest
  bytegleich), keine nachträglich erfundene erfolgreiche Laufcompletion.
- `runs/input-probe-01`: erste echte X11-/XTest-Probe negativ; der erste Klick
  erreichte das Fenster nicht rechtzeitig, der zweite öffnete die Legende.
- `runs/input-probe-02`: nativer Fensterfokus, tatsächliche Mausposition und
  empfangenes Buttonsignal: 22 Checks in 16,770 s positiv; SourceRun
  stable/reusable. Nur kurze Titel-/Paneldiagnose, keine Kampagnenabnahme.
- `runs/native-04`: sauberer `a2a6186d6823c784159f2e8cb050702b80991207`,
  Tree `e61ea2d6b5727571b9698bc66bb875f76839ceb1`. Gesamtprobe negativ:
  erste native M-Taste öffnete die Karte nicht. Folgeprüfungen trafen die
  geschlossene Karte; nach 420,521 s beendet, 30 unveränderte Originalbilder.
  Kaltstartsegment wurde nicht begonnen. Vollständiger SourceRun
  stable/reusable bedeutet hier nur unveränderte Quellen, keinen positiven Test.

## Fortsetzung und endgültiger Fachbeleg

- `runs/native-05`: `c15e1d47450680717c199d6a021b444fdf1ec166` /
  `106810c5c960020fb2610d7bef7b405e070a41b0`, negativ nach 100,405 s,
  null Bilder. Tatsächliches M=77 wurde über schwere Spiel-Frames gehalten und
  erzeugte Echo; frühe Abbruchassertion verhindert positive Folgebehauptungen.
- `runs/native-06`: `6e739b035c7917d43ee46af7ca80bc8e70f0e84f` /
  `27793ae71e63bc17d7149b324effc9eb89efc6b0`, negativ nach 128,392 s,
  null Bilder, dieselbe Eingabe. Die versuchsweise Produkt-Input-Hypothese
  wurde vollständig verworfen; final bleibt der ursprüngliche Unhandled-Key-Port.
- Nach Verlust der fremden Scratch-Objektbasis wurden beide eigenen Checkouts
  als unabhängige Git-Repositories aus dem bereits veröffentlichten Checkpoint
  `63c19debdb8405a0ca790d500bd72892ddbd8d70` wiederhergestellt. Die eigenen
  erhaltenen Rohbelege wurden unverändert zurückkopiert; nichts als neuen Lauf
  ausgegeben. Originalbranch und Fachbasis bleiben Vorfahren. Die neuen
  Quelleninventare stammen aus diesen unabhängigen Checkouts.
- `runs/focused-06`: `71b3c190020669f122a98dfebcaac686d1ea54d4` /
  `f0ea59d24d8b299da59d1d7700497efb02de7cbf`, frischer Import 15,476 s,
  world_map 8,906 s, atlas_search 25,475 s, localization 17,394 s und Modell
  8,888 s / 414 Checks positiv. Produktionsblätter und Modelltest sind
  bytegleich focused-05. Die Anzahl inkrementeller Stepchecks variiert mit der
  CPU-/2-ms-Aufteilung (dort 546); keine Assertion wurde entfernt.
  SourceRun stable/reusable, vollständiger Start-/End-SHA256
  `2faa16b1ebd23c88fa4a4e97fa3b6b9770c26ff3277095d95d7122cfbacf420e`.
- `runs/input-probe-03`/-04: kurze positive Tastaturdiagnosen, keine
  Kampagnenabnahme. -05 und -06 bleiben negative Umgebungsbelege (entferntes
  Xvfb bzw. fehlendes xkbcomp); -05 enthält ausdrücklich nur Launchfehler und
  Startmanifest, keinen erfundenen Endreport. -07 prüft echte atomare 50-ms-
  XTest-Press/Release-Pulse, Textfokus und Captured-M positiv, 27 Checks/9,178 s.
- `runs/native-07`: `a62fddbdc87ce5f088b590a211eefba40e85aada` /
  `2c2d159e1963484d9bb17bac640cada0175ac529`, negativ, 357,045 s,
  457 Checks/56 Originalbilder. Matrix/Input/Save positiv, Raster-Completion,
  Dropdownziel und voller Detailscrollweg negativ; zusätzlich griff die
  Fixture auf einen im Auswahlcallback erneuerten Ergebnisbutton zu.
  Der ursprüngliche negative Gesamtstatus bleibt erhalten.
- `runs/input-probe-08`/-09: ursprüngliche negative Dropdowndiagnosen.
  Das Maus-Popup startet focused=-1; Home ändert das nicht, erster Down
  fokussiert Alle (0). -10 benutzt echte Pfeile bis zur gemessenen Zielzeile,
  Enter, anschließendes Alle, Suche, stabile-ID-Auswahl und volle Wheel-Details:
  positiv in 18,348 s. Kein neues Produktwidget/kein abgeschwächter Guard.

### Native-08: abgeschlossene Bedienlieferung

**Sauberer Prüfhead `5e59bc5b42ac1b1b47f57878e0b2c9a5c39a6bf6`, Tree
`2661e09b4b15bebb1d27e1d17c1ed78ea8935fb3`.** Dieser isolierte Checker enthält
R33/main 94de70ca, den bestehenden Fachbranch und ausschließlich die unten
beschriebenen seriellen Besitzer-Appends. Der Lieferhead/-tree stehen exakt
im Draft-PR; `delivery-file-hashes.json` bindet alle 15 Produkt-/Test-/Runner-
Dateien an diesen tatsächlich geprüften Stand. Neue Belegdateien sind keine
Behauptung eines identischen gesamten Integrationstrees.

`runs/native-08/results.json`: beide Segmente streng PASS, exit=0, originale
OK-Tokens, kein ERROR, genau 56 PNGs. Echter Titel → `SessionFlow.new_game`
→ reguläre Kugelkampagne, tatsächlicher Kampagnenatlas und Geländesampler,
keine Labor-/Ebenenroute. DE/EN × 800×600/1280×720/1920×1080 × 100/125/150 %:
54 unbeschnittene Originalfensterbilder, außerdem vollständige Naht und
vollständig gelesene lange Details. [Bildreview und Bedienfolge](rendered-review.md).

| Segment | Ergebnis | Zeit / unveränderter Guard |
| --- | --- | --- |
| Native X11-Kampagnenbedienung | 493 Checks, 56 PNGs | 154,821 s / 420 s |
| Neuer Godot-Prozess: Save laden und echter Körperwechsel | 10 Checks, PASS | 82,830 s / 420 s |
| Produktladegrenzen / Naht-Completion | PASS | je 150 s / 10 s |

M öffnet/pausiert und schließt/restauriert, Esc verlässt erst Details und dann
Karte. Mausrad und +/- zoomen, Drag/Pfeile verschieben, Home zentriert den
wirklichen Spieler. Ctrl+F und echtes Tippen suchen, native Dropdownpfeile/
Enter wählen einen tatsächlich bekannten Typ und Alle. Mausklick wählt die
exakte gespeicherte ID, echtes Wheel erreicht die letzte lange Detailzeile.
Heller Spielerpunkt über Ortsglyphen ist zusätzlich per Renderpixel geprüft.
Buch-Open-Port bleibt über Karte gesperrt; tatsächliches F8/M prüft den
Settingsblocker, Produktions-Pause-Port prüft den Pauseblocker. Invalidation
beendet Fit/Suche/Census und Pause, Titelrückkehr entfernt den Kartenbesitzer.

Kartenbedienung verändert Atlas-JSON und Progression nicht. Der gespeicherte
unbekannte Südpolmarker mit `SECRET SPECIES 99 NESTS` bleibt aus Treffern und
Typcensus ausgeschlossen. Der Nahtfall bindet ausschließlich deterministische
bereits gespeicherte Nebelzellen am echten Kampagnenatlas, ohne Actor-/Kamera-
bewegung; danach wird der ursprüngliche Atlas restauriert. Beide real bekannten
Besuche liegen im gefitteten Viewport. Vollständiger Rasterbeleg:
coverage=1.0, completed=true, pending=false, 16744 Samples; letzter gemeldeter
Step 24 Samples / 344 µs. `Erkundetes`-Bounds und Zoomobergrenze bestehen.

Save läuft über den echten SaveService. Der neue Prozess verwendet dieselben
isolierten Nutzerdaten und prüft vor dem Resume den gespeicherten Atlas sowie
nach Öffnen die erhaltene bekannte ID/verborgene unbekannte ID. Die tatsächliche
`SessionFlow.travel_to_planet(23757,0,15838)`-Kette bindet danach den Zielkörper
und dessen Atlas, ohne Quellorte oder zweiten Kartenbesitzer. Dieser separate
Neustart-/Reiseabschnitt ist **headless**, also Lebenszyklusbeleg und keine
zusätzliche native Bild-/Eingabeabnahme am Zielkörper.

Vollständige Start-/Endmanifeste: 9565 Dateien / 780240673 Bytes gehasht, sauber
und unverändert, SourceRun stable/reusable. Quellen-SHA256
`1eb051a0ac63a67fd9c1227bd41864f7e6545d0e41a36b0f4c0692a3b1eadee7`,
beide originale JSONL-Manifest-SHA256
`ceb2ae0ec064eb1046954f1a2cfc4b06501649e423c7b8622c7b1ccc50589070`.
Der exakte geprüfte Quellcommit ist in
`runs/native-08/checked-source.bundle` erhalten (9163 Bytes, SHA256
`78110042d350f6eb8c712e59a69c84c07f1233caaaf7927f72b40761442a865d`).
`git bundle verify` ist positiv. Voraussetzungen sind die beiden veröffentlichten
Commits 63c19deb und 94de70ca; der Bundle enthält den exakten Originalhead 5e59bc5b,
nicht einen neu erzeugten ähnlichen QA-Commit. Zur unabhängigen Rekonstruktion
im eigenen Clone mit diesen beiden vorhandenen Commits:

```bash
git bundle verify docs/evidence/int30-11-world-map/runs/native-08/checked-source.bundle
git fetch docs/evidence/int30-11-world-map/runs/native-08/checked-source.bundle HEAD
git worktree add ../int30-native-08 5e59bc5b42ac1b1b47f57878e0b2c9a5c39a6bf6
```

Befehle, Engine, Grenzen, Umgebung und einzelne PNG-SHA256 stehen in Results;
Rohlogs/Manifeste sind verlustfrei `.gz`, JSON unverändert. Der Renderer ist
GL Compatibility/Mesa llvmpipe, Audio Dummy, privates Xvfb; tatsächlich native
XTest-Ereignisse statt synthetischer Viewport-GUI für den ersten Abschnitt.
Nur der **pausierte 3D-Hintergrund** wird im UI-Prüfer ausgeschaltet, damit
Software-Rendering den Kartenraster-/Bedienbeleg nicht verdrängt. Kampagnenszene,
Sampler, Spielzustand und UI bleiben echt. Keine Produktionskameraänderung,
keine Ziel-PC-/3D-Welt-/FPS-Freigabe aus diesen Kartenbildern.

Die Produktlieferung ist damit fachlich abgeschlossen. R33-01 übernimmt die
Appends seriell und prüft den kombinierten R33-Tree einschließlich Vollsuite,
Runtime, vier Integrationsgates und nativen Exporten. Lars' Ziel-PC-/Windows-,
Langzeit-FPS-, Sicht-/Hör-/Spielkomfortabnahme bleibt offen. Draft bleibt offen,
kein Merge und keine Fachissue-Schließung.
