# Voxelverse

Ein Spore-inspiriertes Einzelspielerspiel in Voxelgrafik: eine eigene Kreatur gestalten und die Spezies langfristig über Stamm, Antike/Mittelalter und Weltmacht bis in den Weltraum führen.

**Zentrale Projektplanung: [ROADMAP.md](ROADMAP.md).** Sie unterscheidet vorhandene Funktionen von geplanten Phasen, beschreibt die Grundlagen für echte Planeten/Sternsysteme und hält die Reihenfolge der nächsten Arbeiten fest. Vor neuen Entwicklungspaketen lesen und nach der Umsetzung aktualisieren.

Der integrierte Stand enthält Kreaturensteuerung und Überleben, einen gemeinsamen Entdeckungs-/Entwicklungsbuch-Einstieg, Scans und Körperteilfreischaltungen, einen wirkenden Verhaltens-Skilltree, Heimatgefährten sowie den bestätigten Wechsel in ein erstes spielbares Stammesdorf. Hinzu kommen gestreamte Landschaften, Kreaturen- und Gebäudeeditor, Start-/Pausenmenüs und Audio. Das separate M1/M1b-Planetenlabor ergänzt begehbare Kugeloberflächen bis 12.742 km Durchmesser, ein kleines Testsystem, Doppelsterne und Orbit-/Systemansichten. Mittelalter, Neuzeit und Weltraum sind noch keine freigegebenen Spielphasen. Neue parallele Fachpakete gelten erst nach ihrer Integration als gemeinsamer Stand.

M1c ergänzt einen reproduzierbaren Galaxiekatalog: Sektoren und Sternsysteme abfragen, reale Körpergrößen ansehen sowie eigene Namen, Entdeckungen und Notizen speichern. Die Hauptwelt erhält zusammenhängende Baum-Fernmodelle, eine begrenzte Waldvorschau und gemeinsame Nah-/Fernfarben des Geländes. [M1c und Fernlandschaft: Umsetzung und Testpakete](docs/GALAXY_CATALOG_AND_DISTANCE.md).

## Projekt starten

`project.godot` mit Godot 4.6.3 öffnen und **F5 / Projekt ausführen** wählen. Das konfigurierte Startmenü `ui/frontend/main_menu.tscn` führt in die Kampagne. `main/main.tscn` ist die eigentliche Spielszene für gezielte Entwicklerprüfungen. Windows-/Linux-Exporte und ihre Prüfung sind in [DESKTOP_EXPORT.md](docs/DESKTOP_EXPORT.md) beschrieben.

**Einstellungen und Pause:** **Esc** oder **F8** öffnet das mit Maus bedienbare Menü. Bildschirmmodus, Fensterauflösung, Oberflächengröße und VSync lassen sich übernehmen und speichern. „Zurück zum Spiel“ stellt den vorherigen Mausmodus wieder her; „Speichern & beenden“ beendet erst nach erfolgreicher Sicherung.

**M1 ausprobieren:** Im Spiel **F4** drücken oder im Esc-Menü **„Planetenlabor öffnen“** wählen. WASD/Maus bewegen die Kreatur; Tab wechselt zwischen Oberfläche und Orbit, M zum nächsten Körper, B zwischen einer und zwei Sonnen und T durch die Zeitstufen. **„Terra · 12.742 km“** öffnet den erdgroßen Referenzkörper; M wechselt dort zu Neris (100 km) und Orin (1.000 km). **„Aster · 8 km“** führt zum kleinen Testsystem zurück. F5/F9 sichern/laden Ort und Systemzeit. Das Labor benutzt eine eigene Sicherung; der vorhandene Kampagnenstand bleibt auf seiner bisherigen Landschaft. [M1-Grundlagen](docs/PLANET_M1.md) · [Ausbau, Bedienung und Grenzen](docs/PLANET_LOD_AND_MENU.md) · [Unterwasseransicht und Voxelplaneten](docs/UNDERWATER_VOXEL_PLANETS.md) · [Reale Größen: Testbuild, Messungen und Ladegrenzen](docs/REAL_SCALE_PLANETS.md).

**Grafik-Spieltest:** Unter Wasser begrenzt eine eigene Kameraatmosphäre die Sicht; die Wasserunterseite verdeckt Himmel und Wolken. Im Labor besitzen die vier kleinen Testkörper und die drei realgroßen Referenzen adaptive Voxelstufen. Die Durchmesser der kleinen Testkörper sind Lune 1,024 km, Ember 3,072 km, Haven 4,096 km und Aster 8,192 km; alte Labor-Orte werden an die neue Geländeoberfläche angepasst.

**M1c ausprobieren:** Im Planetenlabor **„Galaxiekatalog“** anklicken. Zentrum, Innenarm und Außenrand zeigen verschiedene Sektoren; eigene Sektorkoordinaten sind ebenfalls möglich. Ein System auswählen, Name/Notiz bearbeiten und speichern. Esc führt zum Planeten zurück. Die Einträge bleiben nach Neustart erhalten. Die Referenzgalaxie hat 100.000 Lichtjahre Durchmesser; die Ansicht zeigt ihren Datenkatalog. Galaxiekarte, Systemreisen und Kampagnenintegration folgen in späteren Arbeitspaketen. [Zielmaßstab und offene Nachweise](docs/PLANET_SCALE_AND_GALAXY.md).

- [Kreatureneditor](creatures/editor/README.md)
- [Kreatur im Spiel](creatures/runtime/README.md)
- [Gemeinsames Bauplansystem und Gebäudeeditor](assembly/README.md)
- [Letzter Grafik-/Gewässertiefenbericht](art/VOXEL_STYLE_DEPTH_REPORT.md)
- [Umgebungs- und Assetplanung](art/FINAL_PRODUCTION_ROADMAP.md)
- [Projektbereinigung und sichere parallele Prüfungen](docs/WORK_PROJECT_MAINTENANCE.md)

Entwicklung der Kreatur erfolgt über Entdecken und bewusstes Gestalten. Ein Genom-/Mutationsspielsystem ist nicht Teil des aktuellen Projekts. Ältere versionierte Dateien und Berichte können historische Ansätze enthalten; für den aktiven Stand gelten die Szenenreferenzen und die zentrale Roadmap.
