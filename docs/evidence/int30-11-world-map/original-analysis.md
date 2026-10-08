Source: https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-5918630094

INT30-11-WORLD-MAP: auf ausdrücklichen Nutzerauftrag gestartet, eigener Branch `agent/int30-11-world-map` exakt ab `2b1ac023db4074c2ce6b7db8fbab09ab929a8435` (Tree `5f815f478ceeabefcfc50a6388e3e4b0daa2ac45`). In der aktuellen Rundenliste ist Chat 11 noch nicht zugeordnet; bis zur eindeutigen Zuordnung ausschließlich Analyse, keine Produktänderung.

An Chat 1: vorgeschlagener exklusiver Schreibbereich `ui/world_map/` (Panel, Canvas, Source, AtlasPresentation/AtlasPlaceQuery und eigene neue Kartenhelfer), zugehörige UIDs, eigene neue `tests/int30_world_map_*` sowie `docs/evidence/int30-11-world-map/` für Fachtests/Renderaufnahmen und Anschluss-Patches. Bestehende Atlas-/Kartenprüfungen nur ausführen, zunächst nicht ändern. `core/map/`/Atlasformat, ExplorationTracker außerhalb world_map, Minimap/Kamerasteuerung (Chat 4), Discovery/Nester (Chat 5), SaveService (Chat 10), gemeinsame Registry/CI/Kataloge/Zentralstatus (Chat 1) bleiben unangetastet. Falls `ui/world_map/` einen fremden laufenden Anschluss enthält, bitte konkrete Ausnahme nennen.

Auftrag: verständliche Legende, Filter nur vorhandener bekannter Ortstypen, Ortsdetails, zuverlässiges Zentrieren einschließlich Kugelnaht/großer Distanzen, Suche/Paging erhalten, keine Enthüllung oder Erkundung durch Kartenbewegung; Pause/Rückkehr und DE/EN/kleine Fenster bei erhöhter Skalierung. Fach-PR gegen `agent/integration-pt19-20260930`; Übersetzungs-/Registry-Anschlüsse als Patch an Chat 1. Bitte Zuordnung in der einzigen Rundenliste bestätigen.

---

Source: https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-5918744840

INT30-11 Analyse auf unveränderter Fachbasis abgeschlossen; bestätigte Zuordnung weiterhin ausstehend, Produktdateien unverändert.

Präzisierung des Vorschlags: `ui/world_map/exploration_tracker.gd` und dessen UID bleiben ausdrücklich **lesend** (Erkundungs-/Save-Lebenszyklus). Schreibvorschlag nur Panel/Canvas/Source/AtlasPresentation/AtlasPlaceQuery, eigene Kartenhelfer, eigene Fachtests/Belege. Keine Atlasformat-/Save-/Minimap-/Kameradateien.

Konkrete Befunde:
- Atlas erlaubt `nest`, `home`, `friend_habitat`, `friend_nest`; heutige UI bietet nur Eigene/Freunde und eine feste Dreierlegende. Typfilter müssen sichtbare gespeicherte Orte aller Archivseiten inkrementell zählen; verlorene/tote/fremde Verbündete und nie erkundete Habitate dürfen weder Typen noch Treffer liefern. Keine neuen Kartenorte erzeugen.
- 800×600/150 %: Legende ist in Kartenansicht wegen unsichtbarer Sidebar und in Ortsansicht wegen `compact_places` verborgen. Echte GL-Aufnahmen bestätigen das.
- Ortsname mit zulässigen 180 Zeichen: Detail benötigt 5 Zeilen, `max_lines_visible=2`; nur 2 sind sichtbar. Details brauchen einen erreichbaren Scroll-/Aufklappweg, ohne Suche/Paging zu verdrängen.
- Canvas 600×180, Rasterradius 64 m, bekannter Marker bei Kartenpunkt (80,0): Marker liegt bei Pixel (412.5,90) außerhalb des gezeichneten Quadrats x=210…390 und wird nicht gezeichnet; `_hit()` wählt ihn trotzdem. Treffer müssen dieselben Grenzen wie die Markerzeichnung nutzen.
- `Erkundetes` über Längengradnaht: Bei Radius 6.371.000 m, zwei Besuchen bei ±(π−0.00001), physischer Abstand 127,42 m, erzeugt das kanonische Extent einen Fit-Radius von 24.018.067,7 m. `fit_explored()` hat zudem keine Obergrenze wie `zoom()`. Vorhandene Projektions-Roundtrips bestehen, dieser konkrete Fit-Fall ist davon nicht abgedeckt. Keine Formatänderung ohne Atlasbesitzer; enger Panelanschluss und eigene Regression erforderlich.

Basistests mit Godot `4.6.3.stable.official.7d41c59c4`, Linux, isolierten Nutzerdaten: `world_map_test` 5,235 s, `atlas_search_test` 21,024 s, `world_map_localization_test` 11,762 s, alle streng bestanden (Quell-SHA256 `f7aa780f5695e1ef57d4023e988e6a816542f8681927c4a85b511b78dee0a75d`). Befehl: `python3 tools/validate_godot.py --godot <4.6.3> --tests world_map_test atlas_search_test world_map_localization_test --skip-main --output <isolierter Belegordner>`.

Zusätzlich bestehender `tools/review_world_map_localization.py` tatsächlich gerendert: 16/16 PNGs, GL Compatibility/Software-Mesa, DE/EN × 800×600/720p/1080p × 100/150 %, echte Player/Map/Save/Restart-Fixture. Keine neue Implementierung, keine neue Sichtabnahme behauptet.

Chat 1: Bitte eindeutige Zuordnung bestätigen; erst danach Umsetzung und Fach-PR gegen `agent/integration-pt19-20260930`. Gemeinsame Katalog-/Registry-Anschlüsse werden als Patch geliefert. Für Renderläufe funktioniert hier der vorhandene portable Xvfb mit `-nolisten unix -listen tcp -ac` und eigenem Loopback-Display, ohne Sandboxeskalation.

