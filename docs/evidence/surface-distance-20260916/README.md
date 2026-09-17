# Sichtweite der Kugelkampagne

Auftrag: Die Ferne erscheint als dunkle, leere Fläche; Bäume und größere Details
sollen schon in etwa 200 m Entfernung zur Orientierung sichtbar sein.
Basis: `176d088d34324de14952bc7506fe9763a22cf4b0`.

## Änderung

- Die aus dem groben Geländeraster abgeleiteten Normalen zeigten nach innen.
  Die Kreuzprodukt-Reihenfolge ist auf allen sechs Cube-Flächen korrigiert.
- Das adaptive Gelände behält mittlere Voxel-Silhouetten im 256-m-Bereich.
  Die Entfernung wird auch an Flächenkanten in physischen Metern gemessen.
  Die Obergrenze von 768 Geländekacheln und der nahe Kollisionsbereich bleiben.
- Die reguläre Kugelkampagne bekommt eine eigene Ferndarstellung für Bäume,
  Büsche und Felsen. Sie verwendet die kanonischen Nahplatzierungen und
  vorhandenen vereinfachten Modelle; keine zusätzlichen Tiere oder Kollisionen.
- Voll sichtbar bis 224 m, ausgedünnt bis 256 m, Vorbereitung mit 288 m Reserve;
  nach 32 m Bewegung wird die nächste vollständige Gruppe vorbereitet.
  Die alte Gruppe bleibt bis zum fertigen Ersatz sichtbar. Kleine Gräser,
  Blumen und Farne bleiben Teil der Nahdarstellung.
- Ein Worker, eine vorbereitete Gruppe; Nah- und Fernvegetation teilen sich
  das Budget von höchstens einer visuellen/Kollisions-Einreichung je Frame.
  Die Zellenmaske schaltet erst bei vollständig veröffentlichten Nahkacheln um.
  Double-Anker erhalten die Position beim Verschieben des lokalen Ursprungs.
- Der Welteintritt wartet auf die erste vollständige Fernvegetation.
  Speicherdaten, Welt-Seed, Platzierungen und Spielsimulation werden nicht geändert.

## Prüfung

Godot 4.6.3, Linux, isolierte Nutzerdaten. Befehle, Quellfingerprints und
Log-Prüfsummen stehen in den drei `*-results.json`, Rohlogs in `logs.tar.gz`.
`manifest.json` identifiziert jede geänderte Quelldatei separat. Die beiden
älteren Läufe liegen vor der abschließenden präziseren Shader-Zellcodierung;
die beiden Distanztests und der Grafiklauf prüfen diese Endfassung.

- `surface_distance_test`: 2325 Prüfungen; Außen-Normalen auf allen sechs
  Flächen; 200-m-Abdeckung auf vier Körpergrößen, an Kanten und Ecken;
  maximal 1617 vorbereitete Zellen unter der festen Grenze von 2048.
- Seed 15838: 1144 größere Landschaftsobjekte in acht Rendergruppen;
  davon 364 zwischen 150 und 224 m. Abweichung von den Nahplatzierungen: 0 m.
- `surface_distance_world_test`: echter Kampagneneintritt, gemeinsames
  Veröffentlichungsbudget, Zellenmaske, Ursprungsverschiebung, Pause,
  Bewegung um 40 m und Rückkehr ins Menü mit noch vorhandenem CPU-Auftrag.
- `surface_scale_contract_test`, `surface_population_budget_test`,
  `planet_streaming_test`, `large_planet_geometry_test` bestanden.
- `spherical_campaign_runtime_test` bestanden, einschließlich Speichern,
  frischem Prozess, neuer Kampagne und Rückkehr aus dem Planetenlabor.
- `distance-start.png`: native Aufnahme aus derselben Kugelkampagne,
  1280 × 720, OpenGL Compatibility auf llvmpipe. Der Grafiklauf prüft zusätzlich
  die tatsächlich hochgeladene Zellenmaske; siehe `render.log`.

Reproduktion der Grafikaufnahme mit Display:

```sh
godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --resolution 1280x720 --script res://tests/surface_distance_world_test.gd \
  -- --capture /tmp/surface-distance
```

Das ist eine Funktions- und Sichtprüfung. Hardware-FPS, Windows-Export und
Gesamtabnahme des aktuellen Merge-Stands sind damit nicht nachgewiesen.
