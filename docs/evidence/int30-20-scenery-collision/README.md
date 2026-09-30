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

Die neue Weltfixture startet über `SaveGameService`/`SessionFlow` die echte
Kugelkampagne mit Seed 15838. Sie liest die tatsächlich hochgeladenen
MultiMesh-Transformationsbuffer (der Dummy-Renderer liefert über den
Einzelgetter Identitätsmatrizen), prüft natürlich erzeugte Hindernisse,
zweimalige Ursprungsschiebung, echte Entladung und Wiederkehr sowie
25-Zellen-/24-Formen-/7-Batches-/Einzelpublikationsgrenzen. Ein separater
sichtbarer Physikkörper zeigt die sweeps; er ist kein umgebauter Spieler.
Der Streamingweg bleibt asynchron, wie im laufenden Spiel; die synchrone
Ankunftsfunktion wird nicht für jede kurze Diagnosebewegung aufgerufen.

**Welt-/Rendernachweis wird separat ergänzt; aus den isolierten Tests folgt
noch keine Kampagnen-, Sicht- oder Ziel-PC-Abnahme.**

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
enthält 60 tatsächlich gerenderte Physikzustände, abgespielt mit 20 fps;
daraus werden keine gemessenen Spiel-FPS abgeleitet. Godots grobe Physik-
Monitorwerte können sich zwischen Aktualisierungen wiederholen. Kosten-
und Sichtabnahme auf Lars' PC bleiben getrennt offen. Kein main-Merge.
