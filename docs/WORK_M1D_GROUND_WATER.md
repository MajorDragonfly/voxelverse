# M1d – Boden, Wasser und Prüfung der Flachwelt-Abschaltung

Stand: 9. September 2026. Nutzerauftrag: Boden und Wasser der Kugelwelt verbessern; vor Entfernung der flachen Welt Abhängigkeiten und parallele Arbeit prüfen.

**Ergebnis:** Boden und Wasser sind überarbeitet. **Die aktive flache Welt wird noch benötigt und wurde nicht entfernt.** Ihre Abschaltung würde aktuell Kampagneneinstieg, Ressourcen, Dorf-Navigation, D1-Habitate und bestehende Speicherpfade betreffen. Die Prüfung der veröffentlichten Fachbranches bestätigt weitere Arbeit an diesen Anschlüssen. Keine fremden Änderungen übernommen, kein Merge nach `main`.

- Eigener Branch: `agent/m1d-surface-adapter`, [Draft-PR #31](https://github.com/MajorDragonfly/voxelverse/pull/31).
- Integriertes `main`: `3a3e0272375e556f3ff65b7370582af79a9d48b5`.
- Ausgangspunkt dieses Pakets: eigener veröffentlichter Stand `593de30cff6db98a95ed4dd13a6e12497b4799ae`.
- Code, Tests und Messartefakte: veröffentlicht als **`006cb6bb5644d1c1e0b08882233915937018fa30`**, lokal validiert als `79fed113873f732aa7ce4366855f2d0f5ac864fe`. Exakt gleicher Git-Quellbaum: **`184ef1db67baf28ab05366c571efc0759bc47f78`**. Dieser Bericht folgt separat.

## Warum die flache Welt noch bleibt

| Aktiver Anschluss | Konkreter Befund | Folge einer sofortigen Entfernung |
|---|---|---|
| Kampagnenstart | `autoload/session_flow.gd` lädt `main/main.tscn`; diese Szene instanziert `world/world_manager.tscn` | Der reguläre Spielablauf verliert seine Welt |
| Generator und Ressourcen | `project.godot` bindet weiterhin den V9-`WorldGenerator` ein; Futterpflanzen und Nester fragen Höhe/Wasser über X/Z ab | Ressourcen, Spawn und Erreichbarkeit müssten zuerst radial angeschlossen werden |
| Speicherung | `core/campaign/campaign_state.gd` verwendet ausdrücklich `legacy_plane_v9`; bestehender Adapter validiert diesen Modus | Ein anderer Oberflächenmodus braucht einen geprüften Erhaltungs-/Migrationsweg |
| D1-Habitate | Der veröffentlichte Habitatplaner setzt `point.y` über `get_visual_terrain_height(point.x, point.z)` und erzeugt `legacy:`-Regionen | Pflichtarten und ihre erreichbaren Wege sind noch nicht an den Kugeladapter gebunden |
| Dorf und Fortschritt | Dorf-Navigation verwendet X/Z-Raster, `Vector3.UP` und vertikale Strahlen; Stammesfortschritt beobachtet diese laufende Dorfwirtschaft | Gruppenbewegung, Bauplätze und Gemeinschaftsfortschritt verlieren ihren geprüften Untergrund |

Die neue Kugelwelt ist bereits begehbar und belebbar, trägt aber noch nicht diese komplette Produktionskampagne. Deshalb reicht die Materialverbesserung allein für den Austausch des Kampagnenuntergrunds nicht aus.

Vor und nach der Umsetzung wurden die Remote-Branches gelesen. Die abschließende Momentaufnahme enthält **zwölf andere Fachbranches** auf der integrierten Basis. Keiner verändert eine Datei dieses Boden-/Wasserpakets. Relevante laufende Stände:

| Bereich | Geprüfter Branch / Commit |
|---|---|
| D1-Planetenfauna | `agent/d1-planet-fauna` / `17b23f568dabbec9f3903217238650f0c9178d04` ([PR #33](https://github.com/MajorDragonfly/voxelverse/pull/33)) |
| D1-Folgearbeit | `agent/d11-fauna-body-evidence` / `3ee18b10…` |
| Dorfwirtschaft | `agent/m6-village-economy` / `a1b3d7cad8e2ec4661675d14b6e59974b27141fe` |
| Dorfwachstum/Hütten | `agent/m6-village-growth` / `09b3b462…` |
| Stammesfortschritt | `agent/tribal-progression` / `ff841110690a6a98d1d37b22bbdab541c9207d66` |
| Buch/Gruppenrückmeldung | `agent/interface-audio-task7` / `6d776a78…` ([PR #32](https://github.com/MajorDragonfly/voxelverse/pull/32)) |
| Bereinigung/Leistungsmessung | `agent/project-maintenance-2026-09-09` / `714a96b5…`; `agent/performance-validation-2026-09-09` / `5ef50281…` |

Alle vollständigen Commit-IDs, Dateilisten, Überschneidungsprüfungen und der genaue Prüfzeitpunkt stehen in `art/review/m1d_ground_water/branch_audit.json`. Zusätzlich erfasst: B1, B2, Sitzpassprüfung und D2. Nicht veröffentlichte Arbeit anderer Chats ist nicht vollständig sichtbar; die bereits sichtbaren Abhängigkeiten reichen jedoch aus, um die Entfernung jetzt auszuschließen. Die separate Bereinigung tatsächlich unbenutzter Prototypen bleibt bei [PR #34](https://github.com/MajorDragonfly/voxelverse/pull/34).

## Was an Boden und Wasser geändert wurde

Der Boden erhält zurückhaltende Details im vorhandenen V9-Rhythmus von 0,125 und 0,5 m. Sie blenden mit Entfernung und Pixelgröße aus. Radiale Oberseiten behalten ihre Biomfarbe; Stufenseiten zeigen Erde beziehungsweise Fels. Küstennaher Boden wird leicht dunkler. Es gibt keine zusätzliche schwebende Geometrie und keine zusätzlichen Bodenkollisionen.

Das Wasser verwendet die vorhandene Planetenpalette mit Flach-/Tiefenfarben, einem begrenzten Ufersaum und schwacher animierter Normalen-/Farbvariation. Die Tiefe kommt aus den bereits berechneten Gelände- und Wasservertices. Dafür wird keine zusätzliche Gelände-/Rauschabfrage ausgeführt. Die Meeresgeometrie wird nicht angehoben oder verformt; Schwimmen und gespeicherte Orte behalten ihren bisherigen Bezug.

Der bisherige Kontaktfehler an Voxelstufen auf exakt null Metern wird gezielt ausgeblendet: Die nahe Wasseroberseite liest den tatsächlichen Abstand zum bereits gerenderten Boden. Der Wasserpass schreibt selbst keine Tiefe und zeichnet seine ausgewählten Pixel deckend nach dem opaken Gelände. Das verhindert, dass die optionale Tiefenvorbereitung das Wasser als seinen eigenen Meeresboden behandelt. Die verwendeten Tiefenschreibmodi sind in der [Godot-Dokumentation](https://docs.godotengine.org/en/4.5/classes/class_basematerial3d.html) beschrieben. Unter Wasser wird diese Bodenabfrage übersprungen; Himmel oder entfernte Objekte erzeugen dort keinen falschen Schaum.

Materialmuster verwenden kleine periodische Reste des präzisen Ursprungs. Große absolute Float-Koordinaten werden dafür nicht voneinander abgezogen. Das vorhandene komplementäre LOD-Raster bleibt erhalten. Ein zusätzlich entdeckter Lichtfehler ist behoben: Die Sonne verwendet beim Laden einen einheitlichen radialen Rahmen und hängt nicht mehr von der gespeicherten Blickrichtung des Spielers ab.

## Dateien und Verträge

| Dateien | Änderung |
|---|---|
| `world/surface/visuals/living_ground.gdshader`, `surface_detail.gdshaderinc` | Radiale Bodenmaterialien, Detailausblendung, Ursprung und LOD-Abdeckung |
| `world/surface/visuals/living_water.gdshader` | Tiefenfarben, Uferkontakt, Bewegung und geschlossene Unterseite |
| `world/surface/visuals/living_surface_materials.gd` | Gemeinsame Materialparameter, vorhandene V9-Farben, präzise Ursprungsreste |
| `world/surface/visuals/living_water_depth.gd` | Zusätzlicher UV-Tiefenkanal ohne neue Geometrie oder Rauschabfragen |
| `world/surface/surface_terrain.gd` | Materialanschluss ausschließlich für `living_planet_v1`, Aktualisierung bei Ursprungswechsel |
| `world/planet_lab/planet_mesh_batch.gd` | Zwei zusätzliche Zeilen im vorhandenen eigenen Fabrikanschluss für den Wasser-Tiefenkanal |
| `world/planet_lab/surface_adapter_lab.gd` | Korrekte Sonnenausrichtung unabhängig von Spielerblickrichtung |
| `tests/living_surface_materials_test.gd`, `tests/living_planet_test.gd` | Geometrie-/Tiefen-/Ursprungsvertrag und Sonnenprüfung beim erneuten Öffnen |
| `tools/inspect_living_surface.gd` | Reproduzierbarer Materialvergleich an derselben Küste, Wasserbewegung und Unterwasseransicht |
| `art/review/m1d_ground_water/` | Vorher/Nachher/Unterwasser, Messwerte und Branchprüfung |

Keine Änderung an Geländeform, Seed, Radius, Generationsrevision, Speicherformaten, `autoload/`, `project.godot`, V9-Generator, Dorf- oder Faunabasis. Die vorherigen Adapterberichte bleiben als historische Nachweise gültig. `ROADMAP.md` bleibt beim Integrationschat.

## Gemessene Prüfung

Godot **4.6.3**, Linux-Container. Die Materialprüfung umfasst 18 Kacheln auf allen sechs Flächen der drei realen Referenzplaneten, einschließlich Kantenanschlüssen.

| Messung | Ergebnis |
|---|---:|
| Bodenarrays vor/nach Ergänzung | bytegleich |
| Wasserpositionen, Normalen und Indizes | unverändert |
| Geprüfte Wasser-Tiefenwerte | 5.202 |
| Größte Tiefenabweichung zum Generator | 0,007843 mm |
| Größte Musterverschiebung bei Ursprungswechsel | 0,015259 mm |
| Berechnung der 18 ursprünglichen Kachelmeshes | 514,770 ms |
| Zusätzlicher Tiefenkanal für alle 18 Kacheln | 4,589 ms insgesamt |
| Bildpunkte mit sichtbarer Wasserbewegung nach fünf Sekunden | 101.624 |
| Gleichzeitig veränderte Bildpunkte im trockenen Vordergrund | 0 |

Die neue Darstellung ist keine nachgewiesene FPS-Steigerung. Sie ergänzt einen kleinen CPU-Tiefenkanal und Materialarbeit auf der GPU; es entstehen keine zusätzlichen Kachelmeshes, Dreiecke oder Kollisionskörper. Die bestehenden Grenzen für Terrain und Tiere bleiben bestehen. Ziel-PC-Framezeiten sind weiter offen.

Abschließend bestanden `living_surface_materials_test`, `living_planet_test`, `living_planet_entry_test`, `surface_adapter_entry_test` und `planet_transition_runtime_test`. In der vorangehenden Regressionsrunde bestanden außerdem `surface_adapter_test` und `campaign_foundation_test`. Import und Kunstquellenprüfung bestanden. Die Prüfungen umfassen tatsächliches Gehen, Bodenkontakt, Hindernisse, Schwimmen, Wasser-/Luftwechsel der Kamera, Planetenwechsel, Speichern/Laden und in einem neuen Prozess wieder aufgebaute Tiere; frühere Speicherdateien bleiben erhalten.

Grafisch geprüft: **Compatibility mit Mesa llvmpipe, 1280 × 720**, ohne Godot-Skript-/Shaderfehler. Die Vorher-/Nachherbilder verwenden dieselbe Küste, Kamera und korrigierte Sonnenausrichtung; der Vordergrund ist für den Materialvergleich freigehalten. Wasserbewegung und Unterseite sind zusätzlich geprüft. **Forward+ konnte nicht abgenommen werden:** Der Container besitzt keinen passenden Vulkan-Treiber (`VK_KHR_surface` fehlt). Der automatische Rückfall auf OpenGL wird ausdrücklich nicht als erfolgreicher Forward+-Test gezählt. Kein neuer Windows-/EXE-Gesamtexport.

```sh
python3 tools/validate_godot.py --godot /pfad/zu/Godot_4.6.3 \
  --tests living_surface_materials_test living_planet_test living_planet_entry_test \
  surface_adapter_entry_test planet_transition_runtime_test --skip-main

# Mit Grafikdisplay; vier Bilder unter user://surface_*.png
godot --path . --rendering-method gl_compatibility --script res://tools/inspect_living_surface.gd
```

## Voraussetzung für die spätere Entfernung

Zuerst müssen produktiver Spieler samt Scan/Nest/Ressourcen, D1-Individuen/Habitatwege sowie Dorfgebäude und Gruppennavigation den gemeinsamen radialen Oberflächenvertrag verwenden. Danach braucht der Kampagnenstart einen ausdrücklich versionierten Kugelpfad mit erhaltenen Identitäten und geprüftem Laden alter Spielstände. Erst nach einem gemeinsamen Ablauf **neue Kampagne → Scan → Stamm/Dorf → Ressourcenversorgung → Speichern → Neustart → Wiederbesuch** lässt sich der flache Spielpfad abschalten. Gemeinsam verwendete V9-Profile, Kunstressourcen und ältere Vererbungsgrundlagen dürfen dabei nicht pauschal mitgelöscht werden.
