# INT30-20 – Umgebungskollisionen

Fachbasis: `2b1ac023db4074c2ce6b7db8fbab09ab929a8435`, Tree
`5f815f478ceeabefcfc50a6388e3e4b0daa2ac45`. Branch:
`agent/int30-20-scenery-collision-20260930`. PR-Ziel:
`agent/integration-pt19-20260930`. Zentrale Zuordnung ausschließlich in #137.

## Belegter Fehler und Änderung

Die alten geraden Baumkapseln enden bei 3,4 m (Eiche) bzw. 5,2 m (Kiefer).
Die sichtbaren Hauptstämme aus `tools/art/build_benchmark.py` reichen höher
und weichen seitlich aus. Der unabhängige Test prüft seine Stammproben zuerst
gegen tatsächliche Bark-Dreiecke des importierten Near-Meshes. Physikstrahlen
und echte `CharacterBody3D.move_and_collide()`-Bewegungen passieren auf der
unveränderten Fachbasis sichtbares Holz.

| Familie | Variante 0 | Variante 1 | Variante 2 |
|---|---:|---:|---:|
| Eiche: oberste Hauptstammstation | 5,80 m | 2,70 m | 4,32 m |
| Kiefer: oberste Hauptstammstation | 10,60 m | 8,60 m | 6,80 m |

`environment_obstacles.gd` verwendet für diese beiden Familien je eine
konvexe, verjüngte Hauptstammhülle aus den authored Stammstationen. Acht
Punkte je Station, höchstens 48 Eingabepunkte je Hülle, 0,0625 m Near-Voxel-
Randzugabe. Skalierung und Radialrotation kommen aus demselben Placement wie
das sichtbare Mesh. Die Hülle ist eine kompakte Näherung des Hauptstamms;
einzelne Äste, Wurzelausläufer und Blätter erhalten keine Voxelcollider.
Steinvarianten und der vorhandene holzige Buschkern bleiben beim Katalogrezept.
Die sechs unveränderlichen nativen Baumhüllen werden einmal vorbereitet und
geteilt. Größe und Mittelpunkt liegen im jeweiligen Shape-Owner-Transform;
ein Streamingreturn baut keine Hülle pro Baum. Ein zusätzlicher Physiktest
prüft gleichzeitig kleine und große Instanzen derselben geteilten Form.

Ein Compound-Body je veröffentlichter Zelle, eine Form je solider Pflanze,
keine Pflanzennodes. Keine Spieler-, Populations-, Vegetations-, Save- oder
Kampagnenanschlüsse geändert; der reguläre Produktionsweg nutzt bereits
diesen Kollisionsbaustein.

## Nachweise

- `checks/baseline-geometry.*`: unveränderter Produktstand, neuer isolierter
  Test. 144 Fälle (vier Familien × drei Varianten × drei Größen × vier
  radiale Rahmen), zwei Bewegungsachsen. **216 Erwartungen scheitern**.
- `checks/fixed-geometry.*`: identische Fixture und Engine, Korrektur aktiv.
  **144 Fälle ohne fehlgeschlagene Erwartung**. Leere Bereiche außerhalb
  der Hauptstämme bleiben durchquerbar. Beide Läufe enthalten vollständige
  Quellfingerprints und Logdigests; kein Baselinefehler wurde ausgeblendet.
- Godot `4.6.3.stable.official.7d41c59c4`, Linux-Container. Die JSON-Belege
  enthalten die genauen Befehle und tatsächlich geprüften Arbeitsstände.

| Prüfung | Ergebnis | Beleg |
|---|---|---|
| finale 144 Fälle und unabhängige gleichzeitige Größen | bestanden, 13,328 s | `checks/final-scale-sharing/` |
| begrenzte Compound-Publikation | bestanden, 7,313 s | `checks/cached-core-validation/` |
| bestehender `environment_playtest_test` | bestanden, 27,759 s | `checks/cached-core-validation/` |
| bestehender `living_planet_test` | 120-s-Prozessgrenze, kein Erfolg | `checks/cached-core-validation/` |

Der erste registrierte Durchlauf bleibt als Fehlbeleg erhalten: Der bestehende
Umgebungstest überschritt seinen unveränderten 45-s-Rahmen; in der neuen
Weltfixture waren nach 45 s erst 15/25 Zellen publiziert. Alle 16 tatsächlich
durchgeführten Strahl-/Bewegungsfälle einschließlich Rebase und Wiederkehr
trafen. Das macht diesen Lauf **nicht bestanden** (`checks/first-world.json`).
Gegenprobe auf unveränderter Basis: Umgebungstest 28,800 s; korrigierter Stand
32,552 s, später mit sechs geteilten Hüllen 27,759 s. Die wechselnde Last dieses
Hosts erlaubt daraus keine belastbare Laufzeitverbesserung abzuleiten.
Für die eigene Weltfixture wurde ausschließlich die endliche Vorbereitungs-
wartezeit auf 90 s gesetzt und die tatsächliche Zeit protokolliert. Bestehende
Testgrenzen, Kollisionsaussagen und Publikationsbudgets wurden nicht gelockert.

Die neue Weltfixture startet über `SaveGameService`/`SessionFlow` die echte
Kugelkampagne mit Seed 15838. Sie liest die tatsächlich hochgeladenen
MultiMesh-Transformationsbuffer (der Dummy-Renderer liefert über den
Einzelgetter Identitätsmatrizen), prüft natürlich erzeugte Hindernisse,
zweimalige Ursprungsschiebung, echte Entladung und Wiederkehr sowie
25-Zellen-/24-Formen-/7-Batches-/Einzelpublikationsgrenzen. Ein separater
sichtbarer Physikkörper zeigt die sweeps; er ist kein umgebauter Spieler.
Der Streamingweg bleibt asynchron, wie im laufenden Spiel; die synchrone
Ankunftsfunktion wird nicht für jede kurze Diagnosebewegung aufgerufen.

Die unveränderte Fachbasis wurde danach mit derselben Weltfixture erfolgreich
bis zum Abschluss durchlaufen: **16 fehlgeschlagene Erwartungen**, ausschließlich
Strahl und Bewegung an Eichen-/Kieferoberstämmen. Buschkerne und Steine treffen
in allen vier Stufen (`checks/baseline-campaign/`). Der finale gerenderte Lauf
mit korrigiertem Produktstand besteht **alle 16 Strahl-/Bewegungsfälle** und
den gesamten Entladungs-/Wiederkehrweg (`campaign-gl/`).

| natürlich erzeugte Familie | Größe | Hang | Basis: Treffer / 4 Stufen | Korrektur: Treffer / 4 Stufen |
|---|---:|---:|---:|---:|
| Eiche | 0,831 | 3,214° | 0 | 4 |
| Kiefer | 1,180 | 2,639° | 0 | 4 |
| holziger Buschkern | 1,190 | 2,025° | 4 | 4 |
| größerer Stein | 0,807 | 3,259° | 4 | 4 |

Stufen: Nähe, zwei Ursprungsschiebungen, Wiederkehr. Der normale Producer
liefert hier Variante 0; Varianten 1/2 werden im importierten Near-Mesh und
echter Physik durch die isolierten Fachfälle geprüft. Keine nachträglich
eingesetzten Pflanzen im Kampagnenbeleg. Die ursprünglichen Compound-Bodies
werden bei 360 m Abstand tatsächlich freigegeben. Die Nachbarschaft bleibt
bei höchstens 25 Bodies, höchstens 24 Formen und sieben Meshbatches pro Zelle,
höchstens einer Publikationseinheit pro Schritt. Gemessen: 99 Formen im ersten
Nahbereich, 142 im entfernten Bereich, kein Collideraufbau pro Blatt/Voxel.

Vier Clips, je 30 gerenderte Zustände, 960 × 540, drei Sekunden:

- [Eiche](campaign-gl/ancient_oak_v2.mp4)
- [Kiefer](campaign-gl/tall_pine_v2.mp4)
- [Buschkern](campaign-gl/dense_bush_v2.mp4)
- [Stein](campaign-gl/layered_rock_v2.mp4)

Die orange Kapsel ist ein eigener echter Physikkörper, dessen sichtbares Mesh
als Diagnoseoverlay durch Laub/Tiere hindurch angezeigt wird. Ihre Form bleibt
0,12 m Radius / 0,35 m Höhe. Der Clip kennzeichnet das Overlay ausdrücklich;
keine Vegetations- oder Spieleränderung. Anfangs-/Endbilder wurden angesehen,
alle vier Videos haben nach `ffprobe` genau 30 Frames. Die Diagnosekamera hat
24 m Sichtweite; der reguläre Terrain-/Populations-/Kollisionsbereich bleibt
unverändert. Größen und Kampagnenplacements stammen aus dem publizierten Buffer.

Grobe Physikmonitormessung des finalen Linux-Software-GL-Laufs: 180 Samples,
Median 8,978 ms, p95/p99 13,334 ms. Erster bestandener Grafiklauf unter anderer
Hostlast: Median 25,946 ms, p95 48,326 ms. Das sind ganze Kampagnenmonitore,
keine isolierten Colliderkosten und kein FPS-/Ziel-PC-Gate. Der strukturelle
Kostenrahmen und die Wiederverwendung der sechs nativen Baumhüllen sind geprüft.
Die nativen Ziel-PC-Kosten bleiben offen.

Die vollständigen Start-/Endmanifeste liegen verlustfrei als `.jsonl.gz` vor;
nach Dekompression gelten die originalen Pfade und Digests der Ergebnisse.
`checked-source-map.json` belegt, dass Produktdatei und beide Testskripte im
finalen Variantenlauf und Grafiklauf mit den gelieferten Dateien übereinstimmen.
Sonde/Runner entsprechen dem finalen Grafiklauf. Dokumentation und Belege
wurden erst danach zusammengefügt. Quellstand war in jedem Lauf unverändert;
die tatsächlichen Arbeitsänderungen sind über die Einzeldateihashes erkennbar.

## Anschlüsse an Chat 1

- `patches/chat1-validation.patch`: beide Fachtests jeweils genau einmal in
  der bestehenden Registry, Weltfall im bestehenden langen 420-s-Rahmen.
- `patches/chat1-capture.patch`: separater Capturejob für GL/Forward+,
  echte PNG-Sequenzen, vier MP4s, Quellbelege und Physikmessung.
- Patches sind Anhänge, nicht Änderungen an Besitzerdateien. Die Registry-
  Ergänzung wurde auf einer getrennten Prüfkopie gegen den tatsächlichen
  Quellvertrag erfolgreich geprüft. Der konservative Änderungsplan verlangt
  mit gemeinsamen Anschlüssen die vollständige Integrationssuite (249 Tests);
  diese, die vier FULL-Gates und native Exporte bleiben beim Integrationschat.

Direkter Fachlauf vor Registryintegration:

```sh
python3 tools/int30_scenery_collision_check.py --godot GODOT --output NEW_OUTPUT
python3 tools/int30_scenery_collision_check.py --godot GODOT --world --output NEW_OUTPUT
python3 tools/int30_scenery_collision_check.py --godot GODOT --world --renderer gl_compatibility --output NEW_OUTPUT
```

Grafische Läufe benötigen ein Display und ffmpeg. Der optionale `--xvfb PATH`
startet einen portablen X-Server in derselben Prozessgruppe. Jedes Video
enthält 30 tatsächlich gerenderte Physikzustände, abgespielt mit 10 fps;
daraus werden keine gemessenen Spiel-FPS abgeleitet. Godots grobe Physik-
Monitorwerte können sich zwischen Aktualisierungen wiederholen. Kosten-
und Sichtabnahme auf Lars' PC bleiben getrennt offen. Kein main-Merge.
Der Capturelauf deaktiviert automatische Laderenders und rendert die einzelnen
Bewegungszustände ausdrücklich; Spiellogik und regulärer Streamingweg laufen
weiter. Ein vorheriger automatischer Software-GL-Lauf scheiterte beim Terrain-
start nach 282 s; `checks/failed-render-start-*` hält das fest. Forward+ ist
über den Anschlusspatch vorgesehen, lokal noch nicht abgenommen.
Ein weiterer Diagnoseversuch endete an der 360-s-Prozessgrenze. Diese
Vorbereitungsausfälle und der 120-s-Labortimeout wurden nicht als grün gewertet.
PR [#234](https://github.com/MajorDragonfly/voxelverse/pull/234) bleibt Entwurf
bis zur Anschluss-/Integrationsabnahme durch Chat 1.
