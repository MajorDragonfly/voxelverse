# Projektbereinigung – 16. September 2026

Auftrag: nicht mehr benötigte Altlasten entfernen und neues Ansammeln begrenzen.
Paket `PROJECT-CLEANUP`, Branch `agent/project-cleanup-20260916`, Basis
`7c10e7fb910566000f5bf01913396016197c8c55` (main nach Integration #141).
Die parallele M4-Navigation bleibt bei ihrem Fachchat; ihre Steuerungsdateien,
Speicheranschlüsse und die gemeinsame Godot-Testregistrierung werden nicht geändert.

## Entfernt

153 Dateien, zusammen 152.576 Bytes im Quellbestand:

| Bereich | Entfernte Ressourcen |
|---|---|
| Unbenutzte Generatoren | `autoload/world_generator.gd`, `world/generation/world_generator_v3.gd`, das nur vom ersten verwendete `world/visuals/world_visual_profile.gd` |
| Ersetzte Grafik | `world/visuals/scenery/terrain_scenic_dressing.gd`, `voxel_asset_library_v4.gd`, `world/visuals/terrain/terrain_surface.gd` |
| Unbenutzte Einstiege | `world/resources/terrain/terrain_chunk.tscn`, `creatures/runtime/procedural_locomotion_animator_v2.gd` |
| Veraltete Texturen | `bark_01`, `leaves_01`, `nest_fiber_01`, `white_01`, `ruin_stone_01` unter `world/visuals/voxel/textures/`, jeweils PNG und Importdatei |
| Metadaten | Zugehörige Script-UIDs; bereits verwaiste `landscape_horizon.gdshader.uid` und `voxel_scenery_styler.gd.uid` |
| Importduplikate | 63 `*_0.png`-Paletten und 63 Importdateien aus `assets/packs/temperate_forest_v1/environment/benchmark_v2/` |

Die acht Quellressourcen sind weder von Spiel-Einstiegen noch von Tests,
Diagnoseszenen oder Werkzeugen erreichbar. Geprüft wurden Pfade, Dateinamen,
Klassen-/UID-Verweise, die Vererbung und dynamische Kataloglader. Historische
Inventare behalten ihre damaligen Dateilisten und Hashes unverändert.

Alle 63 extrahierten PNGs wurden **vor dem Löschen bytegenau** mit dem jeweiligen
eingebetteten GLB-Bild verglichen. Die GLB-Dateien selbst bleiben unverändert.
Ihre Importdateien verwenden nun `gltf/embedded_image_handling=3`, sodass Godot
die Bilder verlustfrei in der importierten Szene behält und keine PNG-Kopien
erzeugt. Siehe [Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_gltfstate.html#enum-gltfstate-handlebinaryimagemode).

## Grenzen und laufende Pflege

- Die V9→Adventure→V6 Smooth→V6→V2-Generatorvererbung, aktive Terrain-/Körperbasen,
  Spielstandmigrationen und die planare Diagnoseszene werden weiter verwendet.
  Eine alte Versionsnummer allein macht eine Datei nicht entbehrlich.
- Bearbeitbare Modelle, Lizenzen, Regressionstests und historische Prüfnachweise
  bleiben erhalten. Ihre Aussage gilt weiterhin ausschließlich ihrem Quellstand.
- `docs/`, `validation/` und `evidence/` erhalten Importgrenzen. Beide Desktop-
  Exporte schließen alle sechs Entwicklungsverzeichnisse ausdrücklich aus.
- `python3 tools/check_project_hygiene.py` prüft im bestehenden CI-Quellgate
  verwaiste UID-/Importdateien, eingecheckte Caches/Builds, Palettenduplikate sowie
  Import-/Exportgrenzen. Es löscht nichts und erklärt unreferenzierte Dateien
  nicht automatisch für unbenutzt. Neue Modelle außerhalb des Benchmark-Packs
  erhalten keine pauschale Änderung ihrer Texturpolitik.
- Testausgaben weiter außerhalb des Checkouts erzeugen. Nutzerdaten, fremde
  Arbeitszweige und die Git-Historie werden durch diese Bereinigung nicht verändert.

Die Löschliste ist im Git-Diff vollständig nachvollziehbar. Einzeldateien können
mit `git restore --source=7c10e7fb910566000f5bf01913396016197c8c55 -- DATEIPFAD`
wiederhergestellt werden. Kein gemessener FPS- oder Kompressionsgewinn behauptet.

Prüfbefehle, geprüfter Commit/Tree und Ergebnisse stehen in der PR-Übergabe.
Linux-/Headless-Prüfungen ersetzen keine native Windows-/Ziel-PC-Abnahme.
