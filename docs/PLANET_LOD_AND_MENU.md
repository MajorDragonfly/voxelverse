# M1-Ausbau: adaptives Planetengelände und Spielmenü

8. September 2026 · **technisch geprüft** · Code `6916cabc49d6aac546c0e600d735e087e9789b9f` · Branch `agent/planet-lod-menu` · Ausgangspunkt `6e5c6d2`.

Lars' Spieltest bestätigte eine verbesserte bisherige Welt, aber weiter zu grobe entfernte Berge, einen nicht funktionierenden F4-Einstieg in seiner EXE und ein nicht klickbares F8-Menü. Diese Lieferung erweitert die Planetentechnik parallel zum Sozialsystem im anderen Chat.

## Benutzung

- **Esc / F8:** pausiertes Einstellungsmenü. Bildschirmmodus, Fensterauflösung, UI-Größe und VSync übernehmen und speichern. Zurück stellt den zuvor sichtbaren oder eingefangenen Mauszeiger wieder her. Speichern & beenden beendet das Spiel erst nach erfolgreicher Sicherung.
- **F4** oder **Planetenlabor öffnen** im Menü: gemeinsamer gesicherter Einstieg, auch im Release-Build. Fehler beim Sichern oder Laden werden im Menü angezeigt. F4 wird vor fokussierten GUI-Controls verarbeitet und akzeptiert auch physische Tastencodes.
- Im Labor **Aster · 8 km** wählen. Radius 4.096 m, Durchmesser 8.192 m. WASD/Maus, Leertaste, Tab Orbit/Rückkehr; F5/F9 sichern/laden. Alternativ über M durch die Körper wechseln.
- F8 bleibt in Editoren verfügbar; deren eigenes Esc-Zurückverhalten bleibt erhalten. Der globale Beenden-Button wird dort nicht angeboten, weil diese Editoren ihre Entwürfe selbst übernehmen müssen.

## Adaptive Oberfläche

Die kleinen bisherigen Testkörper bleiben bei ihrem geprüften 96-Kachel-Verfahren. Aster verwendet sechs Quadtrees mit Wurzeltiefe 2 und maximaler Tiefe 8. Die feinsten Kacheln sind im Würfelraum 32 m breit und besitzen 16 × 16 Zellen; durch die Kugelprojektion ist die reale Kantenlänge ortsabhängig. Die Höhenquelle, Körper-ID und Cube-Sphere-Adresse bleiben für Boden, Orbit und Sicherung gemeinsam.

Nachbarkacheln unterscheiden sich höchstens um eine Tiefe. An einer gröberen Nachbarkachel liegen ungerade Randstützpunkte auf deren tatsächlichen geraden Segmenten. Das gilt auch an Würfelflächenkanten und Polen. Die Wasseroberfläche verwendet dieselbe Unterteilung und dieselben Randregeln; eine niedrig aufgelöste globale Wasserkugel würde auf diesem Radius sichtbar unter die rechnerische Wasserhöhe sinken.

Ein einzelner Worker berechnet Hierarchie und CPU-Geometrie mit einer eigenen Höhenquelle. Der Hauptthread lädt höchstens zwei neue Geländekacheln samt optionalem Wasser pro Frame hoch, mit einem **weichen 4-ms-Budget**, das nach jedem unteilbaren Upload geprüft wird. Einzelne Treiberaufrufe können dieses Budget überschreiten. Alte Kacheln bleiben sichtbar und begehbar, bis die komplette neue Abdeckung bereitsteht. Kollisionsbesitz folgt währenddessen der aktuell veröffentlichten Oberfläche. Beim Erstplatzieren bzw. Teleport wird die Zielumgebung zunächst vollständig vorbereitet; das kann eine Ladepause verursachen.

| Grenze | Festgelegter Umfang |
|---|---|
| Sichtbares Gelände | Höchstens 768 Kacheln, je 512 Dreiecke |
| Wasser | Höchstens ein ebenso unterteiltes Wassermesh je Geländekachel |
| Physik | Höchstens 24 aktive Dreieckskollisionen |
| Vorbereitung | Ein Worker; veröffentlichter und vorbereiteter Satz zusammen höchstens 1.536 Geländekacheln plus deren Wasser |
| Ressourcen | Alte Kacheln werden entfernt, kein unbegrenzter Besuchscache; Worker wird auch bei Szenenwechsel/Abbruch beendet |
| Geometrische Naht | Höchstens 1 mm zwischen gemeinsamem Terrain bzw. Wasser |
| Lokaler Ursprung | Bestehender 64-m-Ursprungswechsel und körperfeste Ortsangabe |

Das Verfahren führt geschlossene, atomare Detailwechsel aus. Zeitliches Geomorphing beim hierarchischen Teilen/Zusammenfassen ist noch nicht enthalten; kleine Silhouettenänderungen beim Wechsel können weiterhin sichtbar sein. Es gibt keinen Nachweis erdgroßer Laufzeitwelten und noch keine Umstellung der Kampagne, Fauna oder Stadtobjekte auf die Kugel.

## Entferntes Gelände der bisherigen Welt

Der Horizont verwendet **2-m- statt 4-m-Voxelstufen**, die mittlere Chunk-Ansicht **1 m statt 2 m**. Nahe Stufen bleiben bei 0,5 m. Dieselben verschachtelten Weltkoordinaten und gespeicherten Morph-Endpunkte verbinden die Ansichten, einschließlich senkrechter Wände und negativer Koordinaten. Die Änderung verfeinert die bestehende Bergsilhouette und entfernt keine Voxelstruktur.

Der feste Horizont bleibt 768 × 768 m groß. Das erhöht seine Obergrenze auf 147.456 Spalten. Die Messszene mit Seed 15838 erzeugt 604.042 Dreiecke und 1.208.084 Vertices; im Ausgangsbericht waren es 170.994 Dreiecke. Der zusätzliche GPU-/Speicheraufwand ist bewusst sichtbar zu bewerten. Die CPU-Prüfung kontrolliert weiter das Vorausladen in allen vier Richtungen. Ziel-PC-FPS sind durch Headless- oder Software-Renderer-Prüfungen nicht belegt.

Die erste Umsetzung überschritt die vorhandene Frist der Wasserprüfung. Der Horizont berechnet seine Höhen jetzt in vier Abschnitten auf höchstens zwei Sampling-Workern; anschließend erstellt ein Worker das Mesh. Die langsam variierende Bodenfarbe wird aus einem gemeinsam ausgerichteten 4-m-Feld interpoliert. Jeder Worker besitzt seine eigenen Generator-Caches. Die unveränderte Wasserprüfung besteht damit wieder, einschließlich Teleport, Besitzwechsel und Abbruch; die aktuelle Richtungsprobe lädt Vegetation mindestens 40,95 m voraus.

## Prüfungen

- `tests/adaptive_planet_test.gd`: vollständige, überlappungsfreie Flächenabdeckung; 2:1-Nachbarschaft an Flächen, Kanten und Ecken; tatsächliche Mesh-/Wasserränder; laufende Kapsel über eine Würfelflächengrenze; Ursprungswechsel; physische Randstrahlen; Ressourcenbudgets; Abbruch während eines Hintergrundauftrags.
- `tests/menu_input_test.gd` und `core/diagnostics/menu_input_probe.gd`: tatsächliche Viewport-Tastatur- und Mausereignisse bei pausiertem Spiel; Einstellung speichern; Esc/F8 schließen; Mausmodus wiederherstellen; physischer F4-Einstieg; Labor-Button; Aster-Gelände und Sichern/Laden im ausgelieferten Build.
- `tools/validate_export.py`: derselbe Eingabeablauf wird über `--input-smoke` mit der nativen Linux-/Windows-Release-Binary außerhalb des Quellprojekts ausgeführt, zusätzlich zum normalen Start und bestehenden Exportprüfungen.
- Bestehende Terrain-, Wasser-, Editor-, Kampagnen-, Streaming- und M1-Prüfungen bleiben im Gesamtprüflauf.
- Die Renderprüfung ergänzt Aster am Boden, im Orbit und das Einstellungsmenü zu den bisherigen sieben M1-Aufnahmen. Die bestehende Weltprüfung zeigt auch die verfeinerte Berglandschaft.

Die maschinenlesbaren lokalen Messwerte und Prüfergebnisse stehen in `art/review/planet_lod_menu_acceptance.json`. Die zugehörige Pull Request dokumentiert zusätzlich native Build- und Rendernachweise.

**Abnahme der Codefassung `6916cab`:** Der vollständige [Godot-CI-Lauf](https://github.com/MajorDragonfly/voxelverse/actions/runs/34254347167) besteht **51/51 Prüfungen**. Die nativen [Windows-/Linux-Exportprüfungen](https://github.com/MajorDragonfly/voxelverse/actions/runs/34254347129) bestehen jeweils **13/13**, einschließlich tatsächlicher GUI-Klicks, F4, Labor-Button und Aster-Sicherung. Die [Renderprüfung](https://github.com/MajorDragonfly/voxelverse/actions/runs/34254347158) besteht in Compatibility vollständig mit **68 Aufnahmen**; die zehn M1-Fälle sind auch in Forward+ erfolgreich, dessen umfangreicher übriger Umgebungslauf bei der Dokumentation noch läuft. Die neuen Compatibility-Bilder wurden gesichtet: bedienbares, vollständig sichtbares Menü, geschlossene Aster-Kugel, erhaltene Terrain-/Wasserränder und reduzierte Überstrahlung im Doppelsternlicht. Die neue Hauptwelt zeigt feinere Voxelstufen an den Bergen. Die Beleuchtung wurde auf 1,0/0,45 Sonnenenergie und maximal 0,35 Tages-Umgebungslicht im Labor abgestimmt.

**Testpakete:** [Windows](https://github.com/MajorDragonfly/voxelverse/actions/runs/34254347129/artifacts/10067336538) · [Linux](https://github.com/MajorDragonfly/voxelverse/actions/runs/34254347129/artifacts/10067313761). Vollständig entpacken und EXE sowie zugehörige PCK im selben Ordner belassen. [Draft PR #11](https://github.com/MajorDragonfly/voxelverse/pull/11) bleibt zur getrennten Integration offen.

Lokaler Aster-Nachweis: 29.172 Terrainrandproben einschließlich 2.652 Proben an Würfelflächenkanten; maximale Abweichung 0,0763 mm am Boden und 0,0800 mm am Wasser. Die Laufprobe legte 245,44 m zurück, wechselte die Würfelfläche und verschob viermal den Ursprung. 748 physische Randstrahlen trafen Gelände. Die Auswahlprüfung über Flächen, Kanten und Ecken erreichte maximal 672 Kacheln; im Lauf waren es höchstens 462 sichtbare und zusammen 504 sichtbare/vorbereitete Geländemeshes. Die Upload-Zeit lag im 95. Perzentil bei 1,334 ms, mit einzelnen Ausreißern bis 17,534 ms; die größte laufende Veröffentlichung brauchte 19,969 ms. Diese CPU-Messwerte sind keine FPS-Zusage.

## Parallelität und Rest

Dieser Branch ändert keine Dateien in `autoload/`, keine soziale Interaktionslogik und keine Registry-/Kampagnenschemas. Die einzige bestehende Spieler-HUD-Änderung ist der sichtbare Hinweis auf Esc und F4 in `ui/hud_presentation.gd`. Bei der späteren Integration sind gemeinsame Änderungen an HUD, Tests und Roadmap abzugleichen.

Der aktuelle Vergleich mit dem parallelen Sozialsystem in PR #10 zeigt nur `ROADMAP.md` als gemeinsam geänderten Pfad. Die größere Systemübersicht braucht noch Feinschliff bei der engen Beschriftung von Haven/Lune; die separate Mondreise bleibt über M erreichbar.

Lars' nächster Spieltest sollte das Klicken im Menü, Vollbildwechsel, F4/den Labor-Button, Aster beim Laufen und Orbit/Rückkehr sowie die entfernten Berge im Hauptspiel umfassen. Weiter offen bleiben Ziel-PC-Leistung, zeitliches planetarisches Geomorphing, produktive Weltobjekte/Fauna, Kampagnenmigration und der Ausbau der Kreaturen aus M2/M3.
