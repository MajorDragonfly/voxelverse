# R32-09 · Materialprüfung für #204

Feste Basis: `2a738a4891a8de11d682c469833ade4dc9b01dfb`, Tree
`f2bda4f815df1c73b9d740ca5282917523faf618`. Fachbranch
`agent/r32-09-materials-20261002`, [Draft #256](https://github.com/MajorDragonfly/voxelverse/pull/256)
gegen `agent/integration-r32-20261002`. Liefercommit und Tree stehen im PR.
AGENTS.md, Projektstatus, [#204](https://github.com/MajorDragonfly/voxelverse/issues/204)
und die aktuelle [R32-Zuordnung in #137](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-5946206999)
wurden vor dem Eingriff gelesen. #204 bleibt offen.

## Belegte Korrekturen

Bei festem Kampagnenclock und demselben importierten Eichenmesh änderte der
Basisshader die Blattpose nach einem Ursprungwechsel. Ursache war die lokale
Welttranslation in der Windphase. Die Phase nutzt jetzt ausschließlich das
kanonische `INSTANCE_CUSTOM.g`.

Die detaillierte Übergangsoberfläche verwendete außerdem Shader-`TIME`, eine
andere Biegeamplitude und eine feste Richtung. Sie erhält jetzt dieselbe
Kampagnenzeit, Geschwindigkeit, Richtung, Höhe und Distanzblende wie das
fertige Nahmaterial. Fernproxies bleiben still. Palette, Fasern, Blattgruppen,
Gesteinsdetail und die komplementäre Deckungsmaske bleiben erhalten.

| Datei / Anschluss | Zuständigkeit | Lieferung |
| --- | --- | --- |
| `assets/catalog/planet_foliage.gdshader` | R32-09 | Stabile Instanzphase |
| `world/surface/visuals/surface_scenery.gdshader` | R32-09 | Gleicher Windvertrag für detaillierte Übergänge |
| `assets/catalog/planet_surface_detail.gdshaderinc` | R32-08 | Gelesen, unverändert; SHA256 `3505b444dead1733d99141e3051c399d349c5b5b5eacef647d8c96257c696b4f` |
| `world/surface/surface_ecosystem.gd` | R32-01 | Nur [Ownerpatch](patches/01-transition-motion.patch) |
| Beleuchtung / LOD-Meshes / Wetter | R32-06 / R32-07 / R32-17 | Befunde und Windanschluss in #137 abgestimmt |

Der Ownerpatch kopiert die vier bestehenden Winduniforms beim Materialwechsel
und für aktive Übergänge unmittelbar vor dem Zeichnen. Das erfolgt nach dem
Weather-Prozess mit Priorität 110; eine Kopie allein im Ecosystem-Prozess wäre
einen Frame zu früh. Vollständig publizierte Pflanzen behalten das gemeinsame
opake Material. Der Patch verbindet und trennt seinen Callback im vorhandenen
Lebenszyklus. Keine zweite Zeit-, Wetter- oder Materialverwaltung.

R32-01 wendet ihn seriell mit
`git apply --unidiff-zero docs/evidence/r32-09/patches/01-transition-motion.patch`
an und führt `tools/review_r32_09_transition.gd` aus. Der echte Consumer wird
ohne Patch negativ und mit isolierter Patchkopie positiv geprüft; 13 Kontrollen,
zwei Uhrenwerte, Änderung nach dem Coverage-Update und Rückkehr zum opaken Pfad.
Die gemeinsame Produktionsdatei ist auf dem Fachbranch unverändert.

## Ergebnis der endgültigen Kampagnenprüfung

Geprüfter Remote-Commit `847de1f542fe36c36c5ee4cf0afbfc69a2c32462`, lokaler Commit `d9156f8994d00adce7fffcf2051c995584cd8f03`, gleicher Tree
`42a7ba29e1434a745f5109c5a85d4556aff70d7b`. Beide vollständigen SourceRun-Manifeste sind sauber und stabil.
Alle sechs Native-Prozesse bestehen Exitcode und strengen ERROR-/Leakfilter.
Die späteren Lieferänderungen ergänzen ausschließlich Evidenz/Workflow-Anhang;
die geprüften Produktionsshader und Prüfhelfer bleiben identisch.

Pro Renderer: zwölf statische Vorher-/Nachherpaare, 64 wiederholte Kameraposen
(128 Bewegungsbilder) und zwei echte Ursprungwechsel. Bei Wind=0 sind alle
statischen und bewegten Vorher-/Nachherbilder pixelgleich. Der
[statische Rendererabgleich](comparability.json) und der
[Bewegungsabgleich](motion-comparability.json) bestätigen identische Seed-,
Save-, Körper-, Ziel-, Kamera- und kontrollierte Sonnen-/Wetterwerte.

| Befund | Beobachtung und Zuordnung |
| --- | --- |
| Holz / Laub / Stein | Die integrierten Fasern, Blattgruppen und Gesteinszeichnung sind nah/mittel sichtbar; feine Struktur nimmt mit Distanz ab. Keine belegte Palette-/Normalen-/Detailkorrektur im R32-09-Bereich. |
| Dunkle Blockflächen / Eigenverschattung | AO-/Schattenisolation hellt Stamm- und Kontaktbereiche auf. Dunkle Unterseiten bleiben lichtabhängig; Nachtkontrast und gemeinsame Schattenabnahme an R32-06. Keine Lichtkorrektur auf diesem Branch. |
| Flimmern | Die kontrollierte Kameraprobe erzeugt zwischen den Materialversionen keine neue Pixeldifferenz. Das ersetzt keinen kontinuierlichen Geh-/Wind-/LOD-Test auf dem Ziel-PC. |
| Materialwechsel / Ursprung | Zwei Fehler der Blattpose sind im echten importierten Eichenmesh isoliert belegt und korrigiert. Die vier Winduniforms der Übergangsmaterialien benötigen den geprüften R32-01-Ownerpatch. |
| Beleuchteter Ursprungwechsel | Near-Mesh-, Instanz- und Colliderdaten bleiben unverändert. Das ganze Bild enthält weiterhin Terrain-/Licht-/Schattenrasterdifferenzen; daraus folgt kein weiterer R32-09-Materialfix. |

## Vergleichsaufbau

Regulärer SessionFlow nach `res://main/spherical_campaign.tscn`, keine Ersatzwelt.
Jede Materialfamilie lädt separat dieselben unveränderten
[initialen R32-02-Savebytes](fixture/initial-save.json): Seed 15838, Körper
`body_52f628e267724cdf4829da56258c2515`, Radius 6371000 m,
SHA256 `da38d42958e254f3224b9587018c81c88215d98898a5e2ab5268c5b399044029`.
Alle 159 referenzierten Originalregionsblobs werden vor/nach dem Restore in
isolierte Nutzerdaten byte- und SHA-geprüft. SaveService/SaveValidator unverändert.

960×540, FOV 64°, feste kanonische Eiche/Steinziele, Distanzen 6/30/110 m,
Kampagnenclock 120/720 s. Eine normale Wetterprobe bei 120 s wird eingefroren.
Die Inspektionskamera liegt 2,5 / 5,38 / 14,98 m über dem jeweiligen Gelände,
damit das Fernziel über der Geländekante sichtbar bleibt. Die bewegte Probe
wiederholt 32 Posen 6→110→6 m mit ±2 cm seitlicher Bewegung, derselben
Höhenfunktion und festgehaltener Nahgeometrie. Das ist eine Material-/Projektionsprobe,
keine physische Gehprobe. Der Spieler-/Streamingfokus folgt den statischen Ansichten.

Vorher/Nachher tauscht nur beide Shader auf derselben pausierten Geometrie.
Wind=0 isoliert Struktur; sichtbare Draw-/Primitivezahlen und Mesh-/Instanz-/Colliderdigest
bleiben gleich. Die unbeleuchtete Eichenprobe ergänzt aktiven Wind bei festem Clock,
Materialhandoff, 600 ms Pause und Ursprungtranslation (+64, −32, +128 m).
Die Kampagne löst denselben echten Terrain-/Adapter-Ursprungwechsel aus.

Kamera, lokale Ursprünge, Zieladressen, Sonnenrichtung/-farbe/-energie, Ambient,
Wetter, Preset und Rohkosten stehen in den Original-Captures. Die reguläre
Backend-Sonnenenergie bleibt separat protokolliert. Nur für den Rendererabgleich
normiert der Helfer Compatibility mit 1,1/0,72 auf dieselbe physische Energie.
Produktionslicht bleibt R32-06.

Vorbereitung: normaler Idle-RadialWalker-Vertrag (`set_motion_hint` + `stream_at`),
normal begrenzte Worker/Publikationsschritte, vollständige kanonische Near-IDs,
Deckung 1, Ground-Ready und aktueller Fernanker unter 32 m. Nur während dieser
unvermessenen Vorbereitung ist Viewport-3D abgeschaltet. Jede Ansicht und jeder
Kostenaufruf zeichnet mit 3D an. Grenzen bleiben 90 s pro Settle und 600 s pro
Native-Prozess; die zwei Familienprozesse umgehen keine Publikationsbudgets.

## Ansichten und Bewegung

Die verlinkten WebP-Ansichten sind verlustfreie RGBA-Kopien. Beide statischen
Materialversionen ergeben jeweils dieselben Pixel. Die SHA-/RGBA-Hashes aller
Original-PNGs und die Decodeprüfung liegen in `final/*/original-png-sha256.json`
und `media.json`; komprimierte Originaldaten sind über `retained-files.json` indiziert.

| Material | Zeit | Distanz | OpenGL | Forward+ |
| --- | --- | --- | --- | --- |
| Holz/Laub | Tag | 6 m | [Ansicht](final/gl_compatibility/views/ancient_oak_v2-day-6m.webp) | [Ansicht](final/forward_plus/views/ancient_oak_v2-day-6m.webp) |
| Holz/Laub | Tag | 30 m | [Ansicht](final/gl_compatibility/views/ancient_oak_v2-day-30m.webp) | [Ansicht](final/forward_plus/views/ancient_oak_v2-day-30m.webp) |
| Holz/Laub | Tag | 110 m | [Ansicht](final/gl_compatibility/views/ancient_oak_v2-day-110m.webp) | [Ansicht](final/forward_plus/views/ancient_oak_v2-day-110m.webp) |
| Holz/Laub | Nacht | 6 m | [Ansicht](final/gl_compatibility/views/ancient_oak_v2-night-6m.webp) | [Ansicht](final/forward_plus/views/ancient_oak_v2-night-6m.webp) |
| Holz/Laub | Nacht | 30 m | [Ansicht](final/gl_compatibility/views/ancient_oak_v2-night-30m.webp) | [Ansicht](final/forward_plus/views/ancient_oak_v2-night-30m.webp) |
| Holz/Laub | Nacht | 110 m | [Ansicht](final/gl_compatibility/views/ancient_oak_v2-night-110m.webp) | [Ansicht](final/forward_plus/views/ancient_oak_v2-night-110m.webp) |
| Stein | Tag | 6 m | [Ansicht](final/gl_compatibility/views/layered_rock_v2-day-6m.webp) | [Ansicht](final/forward_plus/views/layered_rock_v2-day-6m.webp) |
| Stein | Tag | 30 m | [Ansicht](final/gl_compatibility/views/layered_rock_v2-day-30m.webp) | [Ansicht](final/forward_plus/views/layered_rock_v2-day-30m.webp) |
| Stein | Tag | 110 m | [Ansicht](final/gl_compatibility/views/layered_rock_v2-day-110m.webp) | [Ansicht](final/forward_plus/views/layered_rock_v2-day-110m.webp) |
| Stein | Nacht | 6 m | [Ansicht](final/gl_compatibility/views/layered_rock_v2-night-6m.webp) | [Ansicht](final/forward_plus/views/layered_rock_v2-night-6m.webp) |
| Stein | Nacht | 30 m | [Ansicht](final/gl_compatibility/views/layered_rock_v2-night-30m.webp) | [Ansicht](final/forward_plus/views/layered_rock_v2-night-30m.webp) |
| Stein | Nacht | 110 m | [Ansicht](final/gl_compatibility/views/layered_rock_v2-night-110m.webp) | [Ansicht](final/forward_plus/views/layered_rock_v2-night-110m.webp) |

[GL Holz/Laub Bewegung](final/gl_compatibility/ancient_oak_v2-motion.webp) ·
[GL Stein Bewegung](final/gl_compatibility/layered_rock_v2-motion.webp) ·
[FP Holz/Laub Bewegung](final/forward_plus/ancient_oak_v2-motion.webp) ·
[FP Stein Bewegung](final/forward_plus/layered_rock_v2-motion.webp).
32 Posen, nominal 12 fps, verlustfreie Animationen. Jede Pose ist vor/nach identisch;
eine gemeinsame Bildfolge repräsentiert beide Versionen. Alle 32 decodierten
RGBA-Frames wurden gegen die Originale geprüft.

[GL AO aus](final/gl_compatibility/views/ancient_oak_v2-day-ao-off.webp) ·
[GL AO/Schatten aus](final/gl_compatibility/views/ancient_oak_v2-day-ao-and-shadow-off.webp) ·
[FP AO aus](final/forward_plus/views/ancient_oak_v2-day-ao-off.webp) ·
[FP AO/Schatten aus](final/forward_plus/views/ancient_oak_v2-day-ao-and-shadow-off.webp).
Diese Diagnose verändert nur vorübergehend Präsentationseinstellungen und stellt sie zurück.
Stein- und Rebase-Diagnosen liegen ebenfalls unter `final/*/views`.

## Isolierter Materialgegenbeleg

Normierte mittlere RGB-Differenz, 0…1; Nachher-Grenze 0,0001.

| Renderer | Ursprung vorher → nachher | Handoff vorher → nachher | Pause vorher → nachher |
| --- | --- | --- | --- |
| OpenGL | 0.00035218 → 0.00000143 | 0.00120535 → 0.00000000 | 0.00066053 → 0.00000000 |
| Forward+ | 0.00021529 → 0.00000335 | 0.00126694 → 0.00000000 | 0.00123186 → 0.00000000 |

Die echten Consumerprüfungen und drei direkten Fokuschecks
(`resource_visuals_test`, `world_motion_visual_test`, `surface_distance_test` plus
Art-/Quellverträge) bestanden in den drei CI-Versuchen. Die Kampagnenanteile dieser
Versuche bestanden nicht; sie werden nicht als endgültige Abnahme benutzt.
Consumer-/Produktionsänderungen sind funktional unverändert, aktuelle Native-
Shaderkompilation und Kampagnenabläufe sind zusätzlich im finalen Satz geprüft.

## Renderkosten

[24 vergleichbare Kostenzeilen](frame-costs.csv): Median/P95, CPU-/GPU-Zeitstempel,
Draws und Primitive. Die vollständigen acht Rohwerte pro Version stehen in den
Original-Captures. Drei Aufwärmzeichnungen, dann acht pausierte `force_draw`-Aufrufe;
Simulation, PNG-Readback und Publikationsvorbereitung außerhalb der Messung.

| Material / Zeit / Distanz | GL vorher → nachher (ms) | FP vorher → nachher (ms) |
| --- | --- | --- |
| Holz/Laub / Tag / 6 m | 989.3 → 1013.5 | 1277.8 → 1362.9 |
| Holz/Laub / Tag / 30 m | 1056.4 → 1057.0 | 1277.0 → 1305.5 |
| Holz/Laub / Tag / 110 m | 951.4 → 1030.9 | 1414.5 → 1427.4 |
| Holz/Laub / Nacht / 6 m | 565.0 → 517.4 | 766.6 → 745.6 |
| Holz/Laub / Nacht / 30 m | 569.6 → 559.2 | 785.4 → 788.9 |
| Holz/Laub / Nacht / 110 m | 832.9 → 874.5 | 1019.1 → 1004.5 |
| Stein / Tag / 6 m | 891.9 → 927.7 | 1281.4 → 1254.3 |
| Stein / Tag / 30 m | 993.6 → 1015.4 | 1442.6 → 1401.2 |
| Stein / Tag / 110 m | 1090.1 → 1174.7 | 1484.3 → 1360.3 |
| Stein / Nacht / 6 m | 487.5 → 469.9 | 645.8 → 632.2 |
| Stein / Nacht / 30 m | 622.3 → 593.1 | 808.6 → 841.2 |
| Stein / Nacht / 110 m | 843.7 → 837.1 | 1232.2 → 1249.3 |

Godot 4.6.3 stable official (`7d41c59c4`), Engine-SHA256
`f64d4ed19fc9df9440321653fcc80df8c6e365ba7b6de0a29e2cfa9fa71bfeb3`.
Lokales Mesa 25.2.8-0ubuntu0.24.04.2, llvmpipe LLVM 20.1.2; Forward+ Vulkan 1.4.318,
Compatibility OpenGL 4.5. Native Umgebung, Display-/ICD-/Librarypfade und Befehle
sind mitgeliefert. Ein zentral abgestimmter serieller Hostslot verhindert unsere
parallelen Godot-Läufe, belegt aber keine vollständige Isolation des gemeinsamen Hosts.

Vorher/Nachherreihenfolge fest, acht Softwareproben: höhere und niedrigere
Nachherwerte, keine statistische Hardware-Regressionsfreigabe. Null/0 bei
GPU-Viewportstempeln bedeutet nicht verfügbar (GL), keinen kostenlosen Shader.
Die Zeiten betreffen die ganze pausierte Kampagne, keine isolierten Shaderkosten
und keine spielbaren FPS. „Nicht messbar schlechter“ bleibt am Ziel-PC zu prüfen.

## Aufbewahrte Negative

Kein verworfener Satz wird als Abnahme umetikettiert. Große Originaldateien
sind verlustfrei gzip-komprimiert; Index nennt Originalpfad und SHA.

| Versuch | Ergebnis / Grund |
| --- | --- |
| [1 / CI 36973749658](https://github.com/MajorDragonfly/voxelverse/actions/runs/36973749658) | GL vollständig, FP 600-s-Timeout; neue Körper-UUIDs/schwächere Bereitschaft. Spätere Kameraprüfung macht die alten Fernansichten ungültig. |
| [2 / CI 36976399176](https://github.com/MajorDragonfly/voxelverse/actions/runs/36976399176) | Beide öffentlichen Save-Starts lehnen Probe ohne `slot_`-Namen ab. |
| [3 / CI 36976989155](https://github.com/MajorDragonfly/voxelverse/actions/runs/36976989155) | Beide Starts lehnen fehlende referenzierte Regionsblobs ab; Originalsave mit Originalblobs unverändert gültig. |
| 4 | Lokal abgebrochene Probe mit ungeeigneter Kamera; keine Endprovenienz. |
| 5 | Xvfb-Display nicht verfügbar; kein Rendererbeleg. Frische eigene Displays ersetzen den festen Namen. |
| 6 | Abgebrochene Kameraübertragung ohne Rendering-Transformflush; keine Endprovenienz. |
| 7 | GL mechanisch vollständig, Kamera an Zielhöhe statt örtlicher Geländehöhe. Oak 30/110 m −0,24/−3,68 m im Boden, Rock 110 m −0,86 m: keine Fernsichtabnahme. Früherer LOD-Verdacht aus diesen Bildern zurückgenommen. |
| 8 | FP 90-s-Settle und falscher Diagnosemethodenname; unverwertbare Kampagnenmatrix. |
| 9 | FP nach 90 s nur 7/25 Nahpatches; 3D-Zeichnung bremst Softwarevorbereitung. Zusätzlich Cleanup-Probenfehler, behoben. |
| 10 | Drei Tagespaare, danach Ground-Ready negativ: eingefrorener Walker liefert keinen aktuellen Idle-Lookahead. Probe korrigiert, Terraincode unverändert. |
| 11 | Abgebrochene Sichtprobe: Ziel bei Ground+2,5 m durch Gelände verdeckt. Keine Endprovenienz. |
| 12 | 12 statische Paare, 64 Bewegungsframes; 600-s-Timeout und zu strenger Pitch-Guard. Nicht vollständig. |

Der frühere Hinweis auf eine „wirkungslose paused-Variable“ war falsch: es ist
SceneTree.paused. Die endgültige Probe behält diese Pause und deaktiviert zusätzlich
Szenenprozesse. Rollfreie Kameras werden jetzt über die radiale Bild-Up-Projektion
geprüft; eine beabsichtigte Zielneigung ist kein Kamerafehler.
Die früheren Windkontaktansichten unter `views/*-wind-proof.webp` bleiben
historische Gegenbelege; die endgültigen Messwerte stehen unter `final/*/wind`.

## Reproduktion und Übergabe

`python3 tools/review_r32_09.py --godot ENGINE --renderer forward_plus --xvfb XVFB --slot-lock BESTAETIGTER_HOST_LOCK --output NEUER_OUTPUT`

Für den zweiten seriellen Lauf `gl_compatibility` wählen. Originalbasis muss lokal
verfügbar sein; Display/Vulkan/GL-Abhängigkeiten nötig. Der Helfer prüft gesamten
Quellstand und Shader-/Probehashes, schließt Daten/Prozesse und behält Originalkomponenten.
Danach `tools/review_r32_09_report.py OUTPUT` und
`tools/review_r32_09_compare.py GL_OUTPUT FP_OUTPUT --output VERGLEICH.json`.
Die Animationsframes stammen verlustfrei aus den gleichwertigen Originaltracks;
Codec/Framedauern/Decodeprüfung stehen in `final/*/media.json`.

Die optionale [Workflowkopie](patches/02-optional-ci.yml) ist ein R32-01-Anhang auf
geprüfter Quelle; bestehende Fachbranch-CI wird nicht verändert. Die früheren
Diagnoseworkflows sind abgeschlossene Negative, keine ausstehende grüne CI.
[Konservativer Plan](capture-preparation/validation-plan-summary.txt) verlangt
FULL 267/Main. Der Plan führt nichts aus. R32-01 übernimmt Zusammensetzung,
Ownerpatch und erneute Pflichtprüfung des tatsächlichen Merge-Trees.
R32-06 Licht, R32-07 LOD-Geometrie und R32-17 Wind bleiben eigene Anschlüsse.
Ziel-PC-Sichtprüfung, kontinuierliches Gehen/Wind/LOD und Framezeitabnahme separat.
Draft #256 bleibt Draft; #204 bleibt offen.
