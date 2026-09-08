# M1 – Kugel- und Sternsystemlabor

Stand: 8. September 2026 · Technikprototyp geprüft · Code: `555f9efa2a16d8dde6fbf121157671ef944b2f83` · Lars' manueller Spieltest offen.

## Vorab festgelegte Grenzen

Eigenständige Szene `res://world/planet_lab/planet_lab.tscn`; bestehende Kampagnen bleiben `legacy_plane_v9`.

- Haven: Radius 256 m; Ember: 160 m; Mond Lune: 64 m. Bewusst komprimierte Spielmaßstäbe, deterministische Kreisbahnen.
- 6 Würfelflächen × 4 × 4 Kacheln = 96 feste Fernkacheln pro aktivem Körper; höchstens 24 nahe Kollisionskacheln.
- Gemeinsame Kanten: höchstens 1 mm geometrische Abweichung. Die Fernansicht behält sämtliche Randstützpunkte der Nahkacheln.
- Speichern/Laden und Orbit/Rückkehr: höchstens 2 cm Ortsabweichung, gleiche Körper-ID und Höhenquelle.
- Ergänzende Fern-LOD-Prüfung: maximal 2 m Höhenfehler an allen Dreiecksmittelpunkten auf Haven; Randpunkte bleiben identisch.
- Koordinaten-Stresstest bei 6.371.000 m Radius: höchstens 1 mm Umrechnungsfehler für lokale Positionen innerhalb 128 m. Das ist kein Leistungsnachweis für erdgroßes Terrain.
- Physikprobe: tatsächliche Kapselbewegung über Kachel-/Flächenkanten und Pole, mindestens eine vollständige Umrundung; kein Durchfallen, kein unbegrenztes Kachelwachstum.

## Daten und Bestand

`CelestialBodyProfile` liefert V9-Profile an Katalog und Bestandsgenerator. Alte Katalog-Seeds und RNG-Reihenfolge bleiben erhalten; `effective_seed` beschreibt die schon bestehende Begrenzung des aktiven Weltseeds. Der neue Oberflächenmodus heißt `cube_sphere_m1_v1`.

Kugeladressen speichern Körper-ID, Würfelfläche, u/v und radiale Höhe. Globale kartesische Komponenten bleiben skalare 64-Bit-Zahlen in Arrays. Erst nach Abzug des lokalen Ursprungs entsteht ein `Vector3`. Körperausrichtung wird als Tangentenrichtung gespeichert und nicht als weltweiter Y-Winkel.

Das Labor hat eine eigene atomare Sicherung. Es migriert keinen Kampagnenstand. Der vorhandene Kreaturenentwurf wird nur gelesen.

## Implementierter Prototyp

F4 öffnet das Labor aus der Hauptszene nach erfolgreicher Kampagnensicherung. Alternativ die Laborszene direkt starten. WASD/Maus und Leertaste steuern die Kreatur, Tab Oberfläche/Orbit, M den Körper, B die Sternkonfiguration, T die Systemzeit (0/1/4/20). F5/F9 sichern/laden `planet_lab_m1.json`. Die Oberfläche bleibt beim Orbitwechsel körperfest; die Systemzeit darf weiterlaufen.

Die sechs Würfelflächen bilden eine normalisierte Cube-Sphere. Nahe Kacheln besitzen 16×16 Rasterzellen mit Dreieckskollision. Ferne Kacheln verwenden 8×8 Zellen mit Dreiecksfächern und behalten alle feinen Randstützpunkte (288 statt 512 Dreiecke pro Kachel). Ein Kachelwechsel verändert damit keine gemeinsame Kante. Höhe, Feuchte, Temperatur, Bodenfarbe und radiale Ozeanhöhe stammen aus derselben richtungsabhängigen 3-D-Quelle. Die Orbitdarstellung verwendet diese Fernkacheln, keine andere Planetentextur.

Unabhängige Float32-Kacheltransformationen unterscheiden sich an einzelnen gemeinsamen Punkten um wenige Mikrometer. Die Kollisionsränder überlappen deshalb um **0,5 mm**. Das beseitigt Fehltreffer exakt auf einer Kante, liegt innerhalb der 1-mm-Geometriegrenze und ändert keine sichtbaren Vertices. Beim Gehen ersetzt eine Kapsel den alten Heightmap-Ansatz; Schwerkraft, Auftrieb, Boden-Snap und Kreaturenwurzel richten sich radial aus.

Der lokale Ursprung verschiebt sich nach 64 m Bewegung. Nur der aktive Körper besitzt Nahkollision; 96 Fernkacheln und höchstens 24 Nahkacheln bleiben erhalten. Die drei Orbitmeshes werden wiederverwendet. Eine erdgroße Kugel mit diesem festen Raster zu rendern ist ausdrücklich nicht der gewählte Produktionsansatz; weitere Unterteilung ist vor einer solchen Spielwelt erforderlich.

`CelestialSystem` enthält deterministische Kreisbahnen, Rotation und Achsenneigung. Im Ein-Stern-Fall umkreisen zwei Planeten Solis und Lune umkreist Haven. Im Zwei-Stern-Fall umkreisen Solis/Vesper den gemeinsamen Ursprung; die Planeten umkreisen denselben Schwerpunkt. Systemansicht, sichtbare Himmelskörper und gerichtete Lichtquellen verwenden dieselben Positionen und dieselbe gespeicherte Zeit. Keine N-Körper-Physik, Jahreszeiten, Finsternis- oder Gezeitensimulation.

## Prüfung fester Welt-Y-Annahmen

| Bereich | M1-Lösung / Integrationsgrenze |
|---|---|
| Bewegung, Sprung, Boden-Snap | Eigener radialer `CharacterBody3D`; alter Ebenencontroller bleibt im Bestand |
| Kollision / Raycast | Gekrümmte Dreiecke und körperfeste Adressen; gerichtete Strahlen an Flächenkanten und Ecken |
| Kreaturen-/Editorplatzierung | Bestehender Bauplan in lokaler Tangentenbasis; Editor-Pickkollisionen deaktiviert; Identität beim Ansichts-/Körperwechsel erhalten |
| Animation | Bauplan wird dargestellt; vollständige adaptive Beinstellung und Angriffe auf gekrümmtem Terrain folgen M3 |
| Wasser / Shader | Radialer Ozean und eigener Auftrieb; alte Welt-Y-Wassershader werden im Labor nicht verwendet |
| Spawn / Kamera | Höhe und Tangentenbasis aus Oberflächenzugriff; Kamera folgt lokalem Oben |
| Navigation / Tierwelt | Bestehende X/Z-Fauna bleibt in der alten Welt; sphärische Wege und Fauna folgen M4 |
| Speicherzustand | Eigene versionierte Sicherung, atomarer Ersatz und Backup; unbekannte Versionen werden nicht überschrieben |

## Nachweise

- `tests/planet_sphere_contract_test.gd`: alte Seedfolgen gegen M0-Referenzen einschließlich übergroßer Rohseeds; identisches Katalog-/Generatorprofil; Ebenenadapter; Koordinaten bei 64/256/6.371.000 m; alle Würfelflächen einschließlich Pole und Ecken; gemeinsame Höhen-/Wasser-/Klima-/Normalenwerte; Fern-/Nahkanten; Himmelsrichtung, Bahnenabstände, Tageswechsel; Speicherfehler und Versionsschutz.
- `tests/planet_sphere_runtime_test.gd`: echte vollständige polare Umrundung auf Lune, laufende Bodenberührung, mindestens vier Ursprungswechsel, Kachelbudgets, Ozeanauftrieb auf Haven, Orbit/System/Rückkehr, Bauplanidentität, gespeicherter Ort/Zeit/Doppelsternmodus auch in einem separaten Godot-Prozess sowie 48 gerichtete Kollisionsproben auf Kanten/Ecken.
- `tools/validate_export.py`: unveränderter nativer Hauptstart, eigener nativer Laborstart und Vertragstest gegen das exportierte PCK.
- `tools/profile_environment.py --cases planet_lab --seeds 12345`: sieben echte Renderaufnahmen (Oberfläche, Orbit, System, Doppelsternsystem, Doppelsternhimmel, Nacht, Mond) in Forward+ und Compatibility. Die vorhandene Render-CI führt diese Fälle vor den bisherigen Umgebungsprüfungen aus.

Die fokussierte Physikprobe erreichte 6,2836 rad mit 2.028 Bodenkontakten in 2.070 Frames und sieben Ursprungswechseln. Der sichtbare maximale Kantenfehler liegt bei 0,000005055 m. Die ergänzende Fern-LOD-Prüfung misst maximal 1,467347 m Höhenfehler an den Dreiecksmittelpunkten. Der vollständige lokale Prüflauf ist mit **49/49** Prüfungen grün; der Linux-Export mit **11/11** Prüfungen. Nach der letzten Bildkorrektur wurde der komplette M1-Laufzeitfall erneut bestanden. Die aktuelle Fassung besteht auch die Godot-CI sowie die nativen Windows- und Linux-Exportjobs. Der frühzeitige Einstieg vor Abschluss des alten Terrainstarts ist zusätzlich abgesichert.

## Bewusste Grenzen

Das ist die M1-Technikszene, keine fertige Weltraumphase und keine Umstellung der Kampagne. Planetare Fluss-/Seeeinzugsgebiete, produktive Flora/Fauna, blockweise abbaubares Kugelterrain, freier Raumflug und hierarchische Planetengrößen-LOD sind noch offen. Die globale Wasserprobe demonstriert einen zusammenhängenden Ozean. Manuell zu prüfen bleiben Laufgefühl/Kamera mit Lars' Entwurf und Leistung auf seinem Ziel-PC.


## Renderabnahme und Übergabe

Die sieben M1-Fälle wurden mit echten Draw Calls in **Forward+ und Compatibility** erfolgreich aufgenommen. Die Compatibility-Bilder der Codefassung `555f9ef` wurden gesichtet: geschlossene Orbitansicht mit freier Sicht auf den ganzen Planeten, begehbare Oberfläche ohne erkennbare offene Kanten, beschriftete Ein-/Doppelsternkarte, dunkle Nacht ohne Licht von unterhalb des Horizonts und atmosphärenloser Mond mit sichtbarem Mutterplaneten. Der Himmel ist eine einfache Technikdarstellung; Flora und Art-Direction des Hauptspiels wurden nicht auf die Kugel portiert.

- [Messprotokoll](../art/review/m1_acceptance.json)
- [Godot-CI der Codefassung](https://github.com/MajorDragonfly/voxelverse/actions/runs/34247249789)
- [Windows-/Linux-Exporte](https://github.com/MajorDragonfly/voxelverse/actions/runs/34247249854)
- [Renderlauf und M1-Bildartefakte](https://github.com/MajorDragonfly/voxelverse/actions/runs/34247249886) – beide M1-Schritte erfolgreich; der umfangreiche bestehende Forward+-Umgebungslauf kann anschließend noch weiterlaufen.

Die Koordinatenentscheidung für M2 ist damit getroffen: kanonische körperfeste Cube-Sphere-Adresse, skalare globale Koordinaten, Tangentenorientierung und kleiner lokaler Ursprung. Das ersetzt keine Produktionsabnahme erdgroßer Landschaften. Vor der Kampagnenumstellung braucht es hierarchische Unterteilung, Weltobjekt-/Faunaanbindung und eine ausdrücklich geplante Migration.
