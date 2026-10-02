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

## Vergleichsaufbau

Der Prüfhelfer lädt den regulären SessionFlow-Spielweg
`res://main/spherical_campaign.tscn`. Beide Backends spielen exakt dieselben
[initialen R32-02-Savebytes](fixture/initial-save.json) ab: Seed 15838,
SHA256 `da38d42958e254f3224b9587018c81c88215d98898a5e2ab5268c5b399044029`.
Die Kopie und ihre 159 immutable Regionsblobs werden ausschließlich in isolierte Nutzerdaten geschrieben; jeder Originalblob wird vor/nach dem Restore byte- und SHA-geprüft. Das leere regions_by_body-Feld ersetzt diese verschachtelten SurfacePopulation-Verweise nicht. Neue
zufällige Körper-UUIDs werden damit vermieden.

960×540, FOV 64°, festes Zielobjekt pro Materialfamilie, 6/30/110 m,
Kampagnenclock 120/720 s. Eine normale Wetterprobe wird am Start abgeleitet und
eingefroren. Kamera, Ursprung, Zieladresse, Sonnenrichtung/-farbe/-energie,
Ambientwert, Wetter und Preset stehen in den Capture-Originalen. Die regulären
Backend-Sonnenenergien werden separat protokolliert; für diese Vergleichsbilder
wird nur im Prüfhelfer die Compatibility-Energie auf den regulären
Forward+-Wert normiert. Der Produktionslichtcode bleibt bei R32-06.

Für statische Ansichten folgt der reale Spieler-/Streamingfokus der Distanz.
Bereitschaft verlangt vollständige kanonische Near-IDs, volle Deckung, keinen
Worker/Stagingauftrag und einen aktuellen Fernanker unter 32 m Abstand.
Die 90-s-Publikations- und 600-s-Prozessgrenzen bleiben unverändert. Normale
Publikationsarbeit wird weder synchron durchgedrückt noch budgetiert verändert.

Vorher/Nachher tauscht auf derselben pausierten Geometrie ausschließlich die
beiden Shader aus. Wind ist für die Strukturprüfung abgeschaltet. Near-Mesh-,
Instanz- und Colliderdaten sowie sichtbare Draw-/Primitivezahlen werden gegen
unbeabsichtigte Änderungen geprüft. Die Windgegenprobe verwendet zusätzlich
das echte Eichenmesh unbeleuchtet, um Licht und LOD-Geometrie auszuschließen.

Die bewegte Strukturprobe wiederholt je Materialfamilie 32 Kameraansichten
6→110→6 m mit ±2 cm seitlicher Bewegung. Sie startet vom fertigen Nahsatz und
hält dessen Geometrie fest. Das ist eine Probe für Material-/Projektionsflimmern;
physisches Gehen und die gemeinsame LOD-Übergangsabnahme gehören zur Integration.
Die zweite Probe löst einen echten Terrain-/Adapter-Ursprungwechsel
(+64, −32, +128 m) aus. Ihre beleuchtete Gesamtdifferenz enthält auch Terrain-
und Schattenraster; die isolierte Materialprobe bewertet die Windphase separat.

## Originalnegative und Prüfumgebung

[Versuch 1](https://github.com/MajorDragonfly/voxelverse/actions/runs/36973749658):
GL lieferte 12 Vorher-/Nachherpaare, 128 Bewegungsbilder und zwei Rebases.
Forward+ erreichte nach drei Publikationsfristen über 90 s den unveränderten
600-s-Abbruch. Die Quelle erzeugte noch neue Körper-UUIDs und prüfte nur die
Anzahl der Near-Patches. Deshalb ist dieser Satz für den endgültigen
Renderervergleich abgelöst. Originale und Quellenmanifeste liegen unter
`attempt-1`; komprimierte Dateien lassen sich verlustfrei mit gzip lesen.
Die gekennzeichneten Fernflächen-/Schattenansichten in `views/attempt-1-*`
dokumentieren Befunde, keine Abnahme.

[Versuch 2](https://github.com/MajorDragonfly/voxelverse/actions/runs/36976399176):
Die Diagnosesave-Kopie hatte zunächst keinen erlaubten `slot_`-Namen. Beide
Kampagnenstarts wurden vom öffentlichen SaveService abgelehnt. Probe korrigiert;
Originale unter `attempt-2`, keine Produktions-/SaveService-Änderung.

Alle Rendererproben nutzen Godot 4.6.3, offizielle Engine
`4.6.3.stable.official.7d41c59c4`, Binär-SHA256
`f64d4ed19fc9df9440321653fcc80df8c6e365ba7b6de0a29e2cfa9fa71bfeb3`.
Ubuntu-CI-Hosts verwenden Mesa llvmpipe/LLVM 20.1.2 und getrennte Jobs pro
Renderer. Es handelt sich um Softwarezeichnung. Der gemeinsame lokale
Hostslot wurde für diese Kampagnenläufe entlastet.

Ein neuer optionaler Workflow liegt ausschließlich auf
`agent/r32-09-evidence-20261002`. Die Kopie unter `patches` ist ein R32-01-Anhang;
der Fachbranch verändert keine bestehende CI. Import und drei direkte
Verbraucher (`resource_visuals_test`, `world_motion_visual_test`,
`surface_distance_test`) laufen mit dem strengen ERROR-/Leakfilter. SourceRun
prüft den vollständigen Quellstand vor/nach dem Capture und jeden Teilprozess.
Die großen Originalmanifeste werden verlustfrei komprimiert mitgeliefert.

[Versuch 3](https://github.com/MajorDragonfly/voxelverse/actions/runs/36976989155):
Beide Saves wurden wegen fehlender referenzierter Regionsblobs vor dem Weltstart
abgelehnt. Eine kurze lokale Read-only-Validierung lieferte den genauen Hash;
der unveränderte Originalsave besteht mit den 159 Originalblobs. Keine Änderung
am SaveValidator. Nach R32-07s HOST END erfolgt ein serieller lokaler Native-Satz
unter dem gemeinsamen flock; Softwarekosten bleiben diagnostisch.

## Reproduktion und Grenzen

`python tools/validate_godot.py --godot ENGINE --tests resource_visuals_test world_motion_visual_test surface_distance_test --skip-main --output FOCUSED`

`python tools/review_r32_09.py --godot ENGINE --renderer forward_plus --xvfb /usr/bin/Xvfb --slot-lock /tmp/r32-09-heavy.lock --output CAPTURE`

Für den zweiten Backendlauf `gl_compatibility` wählen und einen neuen Outputpfad
verwenden. Native Display-/Vulkan-/GL-Abhängigkeiten und vollständige Gitbasis
sind erforderlich. `tools/review_r32_09_report.py CAPTURE` fasst nur vorhandene
Originale zusammen. Die Workflowkopie enthält auch die Consumer-Overlayprüfung
und die Videocodierung.

Die Kosten sind acht pausierte `force_draw`-Aufrufe pro Ansicht nach drei
Aufwärmzeichnungen. Simulation und PNG-Readback liegen außerhalb der Messung.
CPU-/GPU-Viewport-Zeitstempel und Rohwerte werden mitgeliefert; null/0 auf einem
Backend bedeutet fehlende Messung. Feste Vorher-/Nachherreihenfolge und kleine
Stichprobe erlauben keine Hardware-Regressions- oder isolierte Shaderkostenfreigabe.

Der konservative Plan verlangt FULL 267/Main wegen Prüfhelfern und geteilten
Shaderpfaden. Das ist nur ein Plan: keine lokale Vollsuite, Export- oder
Integrationsfreigabe. R32-01 übernimmt die serielle Zusammensetzung einschließlich
R32-06/07/17 und die zentrale Validierung. Ziel-PC-Sichtprüfung, Gehprobe und
gemeinsame Framezeitabnahme bleiben separat. Draft bleibt Draft; #204 bleibt offen.
