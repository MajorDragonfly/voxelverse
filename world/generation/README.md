# Aktive Weltgenerierung

Die bestehende Kampagne verwendet `legacy_plane_v9`. Der globale Autoload
`WorldGenerator` zeigt in `project.godot` auf `world_generator_planetary_v9.gd`.
Kugelplaneten und deren Kampagnenanbindung sind ein getrenntes Arbeitspaket;
maßgeblich sind [ROADMAP.md](../../ROADMAP.md) und die jeweilige Fachübergabe.

## Benötigte ältere Grundlagen

Die aktive Generator-Vererbung führt von `world_generator_planetary_v9.gd`
über `world_generator_adventure.gd`, `world_generator_v6_smooth.gd` und
`world_generator_v6.gd` zu `world_generator_v2.gd`. Diese Dateien bleiben
Bestandteil der Laufzeit. Auch ältere Terrain- und Kreaturendateien können
weiterhin Grundlagen oder gezielte Testfälle sein; ihre Versionsnummer
ist kein Löschkriterium.

## Laufzeit und Verträge

- `world/world_manager.gd` verwaltet Chunks, Aufbau und Entladen.
- Die Terrain-Szene nutzt die vorhandene V8-Vererbung mit V7/V4/V3/V2-Grundlagen.
- `procedural_ecosystem_v6.gd` bindet die gestalteten Umgebungsmodelle samt
  Varianten, Platzierung und Kollision ein.
- Die V9-Generierung verwendet `drainage_network.gd` für Fluss-/Seeprofile
  und `ocean_bathymetry.gd` für Meerestiefen.
- Terrainhöhe, sichtbare Terrassen, Biom, Wasserspiegel und Dichte bleiben
  über die vorhandenen Generator-Methoden erreichbar. Seed und gespeicherte
  Weltidentität werden durch Bereinigungen nicht geändert.

Nicht mehr angebundene Prototypen sind mit Pfadliste und Wiederherstellungspunkt
in [WORK_PROJECT_MAINTENANCE.md](../../docs/WORK_PROJECT_MAINTENANCE.md) dokumentiert.
Historische Grafikberichte und bearbeitbare Modellquellen bleiben erhalten.
