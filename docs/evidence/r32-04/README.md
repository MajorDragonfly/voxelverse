# R32-04 · Stammeskamera und Trinkkontext

Auftrag #179/#210, Vergabe #137. Fachbranch von
`2a738a4891a8de11d682c469833ade4dc9b01dfb` / Tree
`f2bda4f815df1c73b9d740ca5282917523faf618`. PR #189 wurde weder
übernommen noch verändert. Diese Lieferung ist ein Draft und keine Ziel-PC-Abnahme.

## Fachentscheidung: die ursprüngliche Grenze bleibt

`abs(forward · up) < 0.15` begrenzt die tatsächliche Neigung zur lokalen
Kugeltangente auf etwa 8,63°. `<0.55` würde etwa 33,37° zulassen und passt
nicht zum nahezu horizontalen Blick auf Augenhöhe. Der echte reguläre Kugelspielweg
bestätigt die strengere Grenze: 3°-Anforderung, Nahzoom 12, tatsächlicher
Wert 0,066343 (3,804°), Seitenrichtung 0,052338 (3,000°).
Der reguläre Welttest erreicht nach Bewegung/Rebase 0,052338 und besteht
mit wiederhergestelltem `<0.15`. Die Prüfung gilt für die niedrige Ansicht;
die absichtlich steileren 24°/25°/26°-Ansichten sind eigene Bildrandfälle.

Die originale 1080p-[Augenansicht](ci-36975570276-final/after/home-eye-level.png)
und [Seitenansicht](ci-36975570276-final/after/home-eye-level-side.png)
zeigen Boden, Dorf, Bewohner und die reale Minimap. Der sichtbare Körper im
Vordergrund und größere Ressourcenlabels werden in diesen Belegen erhalten.

## Reproduzierter Bildrandfehler und enger Produktfix

Die Kamera prüfte ihre Near-Plane nur bei `low_view > 0.01`. Bei 25° beginnt
bereits die orthografische Projektion: Das Auge kann frei sein, während die
untere Bildecke unter dem Gelände liegt. Im echten Vergleich desselben
Kampagnenslots lag die schlechteste Bildecke bei 25°/Zoom 72 auf −10,716 m;
nach der Korrektur auf +3,675 m. Bei 26° entsprechend −8,890 → +3,382 m.
Die [Originalaufnahme davor](ci-36975570276-final/before/lens-25-wide.png)
zeigt den abgeschnittenen unteren Bildrand; die
[Originalaufnahme danach](ci-36975570276-final/after/lens-25-wide.png)
zeigt dort durchgehendes Gelände. Wasser am oberen/seitlichen Rand wird in
beiden unbearbeiteten Bildern sichtbar erhalten bzw. durch die geänderte
Kamerahöhe anders eingerahmt.

Der einzige Produktcode-Diff ist `world/tribe/tribe_camera.gd`: Beide Linsen
prüfen jetzt das tatsächliche 3×3-Near-Plane-Raster einschließlich exakter
unterer und seitlicher Ecken, mit bis zu vier Korrekturschritten. Dazu wird der durch Ufer-/Hangfreigabe
entstehende zusätzliche Perspektiv-Pitch begrenzt; siehe echte Uferprobe unten.
`project_position(pixel, camera.near)` ersetzt die unzureichenden Perspektiv-
`project_ray_origin`-Assertions im Welttest. Der bestehende 0,2-s-Refresh,
Fokus, Range, Masken, Gebäudekollision, Bewohner, Erkundung, Navigation und
Streamingbudgets bleiben fachlich erhalten.

| Echte Ansicht | Freigabe davor (m) | Freigabe danach (m) | Dot danach |
| --- | ---: | ---: | ---: |
| Übersicht 55° / 26 | 16,374 | 16,374 | 0,819154 |
| Augenhöhe 3° / 12 | 1,963 | 1,963 | 0,066343 |
| Seitlich 3° / 12 | 2,260 | 2,260 | 0,052338 |
| Niedrig / Weitzoom 72 | 4,172 | 4,172 | 0,052351 |
| Linsengrenze 24° / 72 | 35,919 | 35,919 | 0,406737 |
| Linsengrenze 25° / 72 | −10,716 | 3,675 | 0,520965 |
| Linsengrenze 26° / 72 | −8,890 | 3,382 | 0,521535 |
| 64-m-Hang / Nahzoom | 2,984 | 2,984 | 0,052338 |
| 64-m-Hang / Weitzoom | 6,221 | 6,221 | 0,052351 |

Alle 18 Bilder befinden sich unter `ci-36975570276-final/before`
und `after`. Seed 15838, echter Titelstart mit ausdrücklicher Stammesbestätigung,
1920×1080, gleiche Fokusadresse/Yaw/Tilt/Zoom/Projektion; danach wird exakt
der vorher gespeicherte Referenzslot geladen. Die echte Kampagnenzeit wird
für reproduzierbare Beleuchtung bei 120 s gehalten, über die vorhandene
Atmosphärenquelle. Vorher benutzt wirklich den Basiscode, keine nachgebaute
alte Kamera. Bewegte Wildtiere können nach dem Laden anders stehen;
Kamera- und Geländevergleich sind adressgleich, kein Pixelidentitätsanspruch.

## Fachtests und Rohbelege

[Finale CI 36975570276](https://github.com/MajorDragonfly/voxelverse/actions/runs/36975570276):
Godot `4.6.3.stable.official.7d41c59c4`, Ubuntu-24.04-Runner, Xvfb und
Mesa-llvmpipe. Compatibility-Job positiv; das finale 20.845.311-Byte-Originalartefakt ist
SHA256 `f6c4892e78c307b0e7cf3638baa39399100552319e15ca66f5c5b5d2b699b4dd`.
Alle Originalartefakte wurden gegen den GitHub-ZIP-SHA256 geprüft.
[artifact-index.json](ci-36975570276-final/artifact-index.json) identifiziert
finalen Head/Tree, Dateien, Größen und Hashes. Frühere Läufe verbleiben unter
ihren eigenen CI-Verzeichnissen: 36973514750 ist der erste Kamerafix und der
negative Forward+-Basislauf, 36974476319 die negative echte Uferprobe.
[final-source.json](final-source.json) bindet die Produkt-/Testbytes an den
final geprüften Diagnosehead. Lieferung und Diagnosehead unterscheiden sich
nur durch Dokumentationsbelege und die diagnoseeigene Workflowdatei; das
ist ein begrenzter Fachnachweis, kein grünes Pflichtgate des Liefer-Trees. Start-/Endmanifeste sind vollständig und als `prepared`,
`reusable: true` bestätigt; Importvorbereitung hat keine Laufzeitquelle geändert.

Der Fokuslauf benutzt die vorhandenen registrierten Tests, `--skip-main`:

- `tribal_camera_preferences_test`: alte Pfeilprofile; Z/X-Rebinding mit
  erhaltenen Pfeilen; obsolete Q/E-Kamerabindungen entfernt, Kreatur-Q/E
  erhalten; Konfliktablehnung; echte Esc-Einstellungen; tatsächlicher frischer
  Godot-Prozess prüft gespeicherte Bindungen, Geschwindigkeit 2,1, 3°-Neigung,
  Sensitivität 1,25 und FPS-Einstellung 60.
- `tribal_camera_test`: Q/E, Pan, Schnellmodus, Rotation, Zoominterpolation,
  GUI-Klickschutz, Pause/Fokusverlust und Bewohner-/Vorrats-/Save-Invarianz.
- `tribal_camera_world_test`: reguläre Kugelwelt, Minimap-Dreh-/Neigungs-/
  Zentrierknöpfe, Klickrichtung ohne Weltauftrag, 720p/1080p-Layout,
  108,555 m Pan, 64-m-Geschwindigkeitsprüfung in simulierter Kamerazeit, Rebase, originale
  Augenhöhengrenze, 24°/25°/26° × Zoom 12/26/72, 40 niedrige Position-/
  Richtungs-/Zoomfälle (schlechtester Dot 0,090693), Laden mit neuer Kamera.
  Bestehende Obergrenzen eingehalten: 573 Tiles, 24 Collider, Peak 707 Meshes.
- `minimap_test`: Richtungen/Zoom/Begrenzung und unveränderter stationärer Cache.
- Direkter Verbraucher `tribal_building_preview_test`: rotierte Platzierung,
  Blocker, GUI-Klickschutz und echte Fehlerspeicherung ohne Mutation.

Alle fünf positiv; zusätzlich Import, Source-Contracts, Art-Sources und
Source-Integrity positiv. Originalbefehle, Ausgänge, Loghashes und Umgebung
stehen in [results.json](ci-36975570276-final/focused-tests/results.json).
Die Save-Warnung im Preview-Test gehört zum absichtlichen Fehlerschreibfall;
keine Script-Errors oder Leaks in den positiven Rohlogs.

Die vorhandene Stationärkollisionsprobe `review_int30_tribal_camera.gd`
besteht auf demselben Kamera-/Teststand: Ein neu gesetzter physischer
Gebäudecollider verschiebt das Auge um 7,15 m; nach Entfernen kehrt die
Ansicht zurück. Bewohnerauswahl und Minimap bestehen. Rohlog:
[finales collision-focused.log](ci-36975570276-final/collision-focused.log). Dieser Kollisions-
aufbau ist eine gezielte Fixture. Die echte 64-m-Hangansicht zeigt außerdem
natürliche Baumverdeckung; sie ist kein pauschaler Beweis für jede Floraform.

## Trinkhinweis und tatsächliche Aktion

Die vorhandene Produktionskette ist bereits konsistent: HUD und Primary-
Action verwenden `reachable_drink_source`; dieser prüft Süßwasser,
Entfernung zur Wasseroberfläche und tatsächlich publizierten Boden.
Ein weiterer Produktpatch an den gemeinsamen Spieleranschlüssen ist durch
die Fachproben nicht begründet.

Der physische Reichweitenrand ist entscheidend: Ray-Untergrund 3,242626 m,
erreichbare Wasseroberfläche 3,086199 m bei Range 3,2. Das echte HUD zeigt
„trinken“ und die Primary-Action erhöht Durst 20 → 55. Unerreichbares Wasser,
unpublizierter Boden, trockener Boden und Meerwasser zeigen keinen Trinkhinweis
und stellen keinen Durst wieder her. Schwimmen verwendet ebenfalls dieselbe
Quelle: Süßwasser true/true/true für Quelle/Hinweis/Aktion; trocken und salzig
jeweils false/false/false. Der native Rohbeleg ist
[drink-native.log](ci-36975570276-final/drink-native.log).

Diese Probe verwendet die echten Wasser-/Spieler-/HUD-Module und den echten
Kugelsampler. Terrainpublikation und physischer Untergrund sind ausdrücklich
Fixtures, kein regulärer Spielwelt- oder Ziel-PC-Trinknachweis. Das frühe
headless Rohlog bezeichnet den trockenen Fall noch mit dem Samplerdefault
`ocean`; der native Endlauf enthält die korrigierte Diagnose `dry`.

## Uferergänzung und gemeinsame Anschlüsse

Die ergänzende reguläre Uferaufnahme sucht eine echte trockene/Süßwasser-Grenze innerhalb der unveränderten
128-m-Kamerarange und prüft Nah-/Weitzoom, Seitenblick und 25°-Rand.
Der erste echte Lauf schlägt fachlich fehl: am Ufer 3° angefordert,
14,48° tatsächlich (`dot=0,250086`). Die ursprüngliche Grenze bleibt strikt;
[Negativbild](ci-36974476319-shore-negative/shore-eye-level.png) und
[Rohlog](ci-36974476319-shore-negative/render.log) werden erhalten.
Die korrigierte Perspektivorientierung begrenzt nur den zusätzlich durch
Bodenfreigabe entstehenden Down-Pitch: maximal `max(Anforderung, 8°)`.
Position, Boden-/Kollisionsfreigabe und Kartenfokus bleiben erhalten; das
Blickziel hebt sich bei Bedarf und der Fokus kann tiefer im Bild stehen.
Damit gibt es keinen sprunghaften Sonderfall beim Überschreiten von 8°.
Der vollständige finale Fachlauf samt erneuter realer Ansicht besteht in
[CI 36975570276](https://github.com/MajorDragonfly/voxelverse/actions/runs/36975570276),
Head `ebe08f98cdf8c1172fc2d79b1bd1a36fe678f8eb`, Tree
`058a6f009bc539a80e967f875fac2152dd75fa78`. Originalartefakt, Rohlogs und Ansichten wurden geprüft: Ufer-Nahblick
0,139173, seitlich 0,139174, Weitzoom 0,139173, jeweils unter `<0.15`.
Die unteren/seitlichen Near-Plane-Punkte bleiben frei: mindestens 2,852 m,
1,951 m bzw. 13,670 m; am 25°-Ufer-Rand 3,330 m.
Fokusabstand 64,583 m innerhalb Range 128; 585 Tiles, 24 Collider,
Peak 611 Meshes. Dorfbestand bleibt unverändert.
[Uferbild](ci-36975570276-final/shore/shore-eye-level.png),
[seitliches Uferbild](ci-36975570276-final/shore/shore-eye-level-side.png),
[Weitzoom](ci-36975570276-final/shore/shore-low-wide.png),
[Rohlog](ci-36975570276-final/shore/render.log).

Die Uferläufe erzeugen unabhängige normale Kampagnen mit Seed 15838;
Face/u/v/Höhe, Auge, Yaw, Zoom und Uhrzeit stimmen überein, die zufälligen
Kampagnen-/Körper-IDs unterscheiden sich. Der Neun-Ansichten-Vergleich oben
lädt dagegen den identischen Referenzslot. Uferkamera und Trink-Fixture
sind getrennte Belege, kein erfundener regulärer Trinkspielweg.

Gemeinsame InputPreferences, Spieler-/TribeController-, Testregistry-,
Lokalisierungs- und Workflowdateien werden im Fachbranch nicht geändert.
Die vorhandenen Tests bleiben genau einmal registriert. Die optionalen
Workflow-Patches [workflow-owner.patch](workflow-owner.patch) und
[workflow-shore-owner.patch](workflow-shore-owner.patch) sowie
[workflow-final-owner.patch](workflow-final-owner.patch) gehen zur Entscheidung
an R32-01; sie dokumentieren die tatsächlich benutzten unabhängigen Runner.
Der automatische Changed-Since-Plan wählt wegen neuer Diagnose-/Evidenzpfade
konservativ die volle Suite. Diese gemeinsame Einordnung und die vollen Gates
bleiben bei R32-01, keine Fachbranch-Abschwächung der Auswahlregeln.

## Grenzen der Übergabe

Forward+ scheitert auf llvmpipe schon an der unveränderten regulären
Kampagnenvorbereitung. [Originalfehler](ci-36973514750/forward-plus-negative/before/render.log)
und Quellstartmanifeste bleiben erhalten. Es gibt dort keine erfolgreiche
Ansicht, keine Endmanifest-Freigabe und keine Forward+-Abnahme; ein längeres
Timeout oder anderer Launcher wurde nicht zum grünen Ergebnis umgebaut.

Frühe leichte lokale Tests liefen auf dem gemeinsam belegten Host
`db514e109ac6` und können mit Messanläufen überlappt haben. Die nachfolgende
Verschärfung auf alle Godot-Prozesse wurde beachtet; native Ansichten und
finale Fachtests liefen auf unabhängigen CI-Hosts. Kein isolierter lokaler
Leistungsnachweis. Das fremde ungetrackte `docs/PLAYTEST_R32.md` blieb erhalten
und wird nicht mitgeliefert.

Sichtkomfort durch Lars, Ziel-PC, Windows/Native-Exporte, Forward+ und volle
Integrationsgates bleiben offen. #179/#210 werden nicht geschlossen; #189
bleibt geschützt. Finale Liefer-SHA/Tree stehen im Draft-PR und der sauberen
`work_packet.py handoff`-Übergabe. Jeder Lauf ist seinem tatsächlichen Produkt-/Teststand zugeordnet;
nachträgliche Änderungen erhalten neue Fachprüfungen. Zusatzbelege sind
keine neue Gesamtfreigabe.
