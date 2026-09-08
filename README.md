# Voxelverse

Ein Spore-inspiriertes Einzelspielerspiel in Voxelgrafik: eine eigene Kreatur gestalten und die Spezies langfristig über Stamm, Antike/Mittelalter und Weltmacht bis in den Weltraum führen.

**Zentrale Projektplanung: [ROADMAP.md](ROADMAP.md).** Sie unterscheidet vorhandene Funktionen von geplanten Phasen, beschreibt die Grundlagen für echte Planeten/Sternsysteme und hält die Reihenfolge der nächsten Arbeiten fest. Vor neuen Entwicklungspaketen lesen und nach der Umsetzung aktualisieren.

Der aktuelle Prototyp enthält Kreaturensteuerung und Überleben, Entdeckungen/Körperteilfreischaltungen, gestreamte Landschaften, einfache regionale Ökologie, Planetenwechsel per Debug-Taste sowie Kreaturen- und Gebäudeeditor. Das separate M1-Planetenlabor ergänzt begehbare Kugeloberflächen, einen Mond, einen zweiten Planeten, Doppelsterne und Orbit-/Systemansichten. Spätere spielbare Phasen und der Verhaltens-Skilltree sind geplant.

## Projekt starten

`project.godot` mit Godot 4.6.3 öffnen und die Hauptszene `main/main.tscn` starten. Windows-/Linux-Exporte und ihre Prüfung sind in [DESKTOP_EXPORT.md](docs/DESKTOP_EXPORT.md) beschrieben.

**M1 ausprobieren:** Im Spiel **F4** drücken oder `world/planet_lab/planet_lab.tscn` direkt starten. WASD/Maus bewegen die Kreatur; Tab wechselt zwischen Oberfläche und Orbit, M zum nächsten Körper, B zwischen einer und zwei Sonnen und T durch die Zeitstufen. F5/F9 sichern/laden Ort und Systemzeit. Das Labor benutzt eine eigene Sicherung; der vorhandene Kampagnenstand bleibt auf seiner bisherigen Landschaft. [Technik, Prüfkriterien und Grenzen](docs/PLANET_M1.md).

- [Kreatureneditor](creatures/editor/README.md)
- [Kreatur im Spiel](creatures/runtime/README.md)
- [Gemeinsames Bauplansystem und Gebäudeeditor](assembly/README.md)
- [Letzter Grafik-/Gewässertiefenbericht](art/VOXEL_STYLE_DEPTH_REPORT.md)
- [Umgebungs- und Assetplanung](art/FINAL_PRODUCTION_ROADMAP.md)

Entwicklung der Kreatur erfolgt über Entdecken und bewusstes Gestalten. Ein Genom-/Mutationsspielsystem ist nicht Teil des aktuellen Projekts. Ältere versionierte Dateien und Berichte können historische Ansätze enthalten; für den aktiven Stand gelten die Szenenreferenzen und die zentrale Roadmap.
