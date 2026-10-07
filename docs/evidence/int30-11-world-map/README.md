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

- `runs/focused-05`: finaler sauberer Karten-/Teststand
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

Die erweiterte native Eingabediagnose zeichnet tatsächliche logische/physische
Tastencodes auf, prüft M bei eingefangenem Mauszeiger und beendet eine nicht
geöffnete Kampagnenkarte sofort. Die vollständige native Bedienabnahme auf
diesem korrigierten Fachteststand ist vor endgültiger Übergabe noch offen.
Lars' Ziel-PC-, Langzeit-FPS-, Sicht-/Hör-/Spielkomfortabnahme sowie vollständige
R33-Integration/native Exporte bleiben getrennt offen. Keine Fachissue-Schließung.
