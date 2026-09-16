# Aktive Weltgenerierung

Der reguläre Spielweg führt vom Startmenü zur Kugelkampagne
`main/spherical_campaign.tscn`. Deren Terrain verwendet
`world/surface/surface_terrain.gd` mit radialem Oberflächenadapter.
Der globale Autoload `WorldGenerator` zeigt weiterhin auf
`world_generator_planetary_v9.gd`: Die planare Generatorlinie wird für vorhandene
Verbraucher, historische Spielstände und Diagnoseprüfungen benötigt.
Aktueller Lieferstand: [PROJECT_STATUS.md](../../docs/PROJECT_STATUS.md).

## Benötigte ältere Grundlagen

Die aktive Generator-Vererbung führt von `world_generator_planetary_v9.gd`
über `world_generator_adventure.gd`, `world_generator_v6_smooth.gd` und
`world_generator_v6.gd` zu `world_generator_v2.gd`. Diese Dateien bleiben
Bestandteil der Laufzeit. Auch ältere Terrain- und Kreaturendateien können
weiterhin Grundlagen oder gezielte Testfälle sein; ihre Versionsnummer
ist kein Löschkriterium.

## Planare Diagnose und gemeinsame Grundlagen

- `world/world_manager.gd` verwaltet Chunks, Aufbau und Entladen.
- Die Terrain-Szene nutzt die vorhandene V8-Vererbung mit V7/V4/V3/V2-Grundlagen.
- `procedural_ecosystem_v6.gd` bindet die gestalteten Umgebungsmodelle samt
  Varianten, Platzierung und Kollision ein.
- Die V9-Generierung verwendet `drainage_network.gd` für Fluss-/Seeprofile
  und `ocean_bathymetry.gd` für Meerestiefen.
- Terrainhöhe, sichtbare Terrassen, Biom, Wasserspiegel und Dichte bleiben
  über die vorhandenen Generator-Methoden erreichbar. Seed und gespeicherte
  Weltidentität werden durch Bereinigungen nicht geändert.

Die unbenutzten V1-/V3-Einstiege wurden entfernt; die oben genannte Vererbung
bleibt erhalten. Weitere Bereinigungsdetails stehen in
[WORK_PROJECT_CLEANUP.md](../../docs/WORK_PROJECT_CLEANUP.md).
Historische Grafikberichte und bearbeitbare Modellquellen bleiben erhalten.
