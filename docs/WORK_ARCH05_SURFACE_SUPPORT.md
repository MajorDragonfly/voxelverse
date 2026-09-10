# ARCH-05 – Begehbare Oberflächen und geprüfte Abfragen

Basis: veröffentlichter `main` `ea900f2e09946660694a9e59399b4680a5655a85` (PR #48).
Arbeitsbranch: `agent/arch05-surface-contract-2026-09-10`.
Zuständigkeit: ARCH-05; ARCH-02, ARCH-20, ARCH-23 und ARCH-25 bleiben bei ihren Fachpaketen.

## Lieferumfang

`world/surface/surface_support.gd` prüft den vorhandenen adaptiven Terrainvertrag rein lesend. `inspect(descriptor, campaign)` unterscheidet anzeigbare Katalogkörper von unterstützten Planeten/Monden. Sterne und Gasriesen bleiben im Katalog, erhalten aber keine begehbare Oberfläche. Der Kampagnenvalidator verwendet denselben Anschluss; das Planetenlabor prüft vor dem Abbau des bisherigen Terrains und vor einer Katalogreise. Die Katalog-Landeauswahl filtert ungeeignete Körper, ohne ihre Daten zu verändern.

| Oberflächenklasse | Radius | Einordnung |
| --- | --- | --- |
| Kleine Testkörper | 64 m bis unter 50.000 m | Vorhandene Labor-/historische Testskala; keine neue Kampagnengröße |
| Kampagnengröße | 50.000 m bis einschließlich 100.000.000 m | Vorhandene Grenzen bleiben erhalten |
| Katalogkörper | Beliebige katalogeigene Größe | Keine automatische Landefreigabe; Körperart, Version und Radius separat prüfen |

Die Prüfung benutzt `PlanetTileLayout.MAX_LEVEL = 24`, dessen unveränderte Zielbreite 32 m und `PlanetPatchMesh.CELLS = 16`. Die nominale Zellweite ist `2 × Radius / (2^LOD × 16)`; der vorhandene Bereitschaftsgrenzwert beträgt 4 m. Die tatsächliche Auswahl bleibt auf 768 Blätter begrenzt. Radiusfreigabe bedeutet, dass diese Auflösung unterstützt wird, nicht dass die Kollision an jedem Ort bereits geladen ist.

Alle Radiusprüfungen erfolgen vor einer Generatoranlage. Ungültige, zu kleine und zu große Werte werden weder begrenzt noch in Testplaneten umgewandelt. Auch der zuvor durch die `MAX + 1`-Prüfung ausgelassene Bereich direkt über der Grenze und Werte oberhalb von `1e10` sperren jetzt als nicht unterstützte Oberflächen den Speicherfallback. Bestehende Körper-/Arten-IDs, Seeds, gespeicherte Radien und Save-Schemata bleiben erhalten. Bekannte Oberflächengenerationen werden weiter gelesen; unbekannte Versionen werden nicht durch die alte Terrainquelle ersetzt.

## Tatsächliche Bodenkollision

`AdaptiveSphereTiles.ground_ready(absolute_position)` erfordert jetzt gleichzeitig:

- einen gültigen absoluten Körperpunkt und eine geladene Geländekachel mit höchstens 4 m Zellweite;
- den aktiven Kollisionsbesitzer dieser Kachel im Szenenbaum, unter genau ihrem Meshknoten;
- eine aktivierte Kollisionsform auf der Boden-Kollisionsebene.

Ein gerendertes Mesh ohne aktiven Besitzer, eine entfernte/abgeschaltete Kollision oder ein unbekannter Ort gibt `false` zurück. `RadialSurfaceAdapter.collision_ready` verwendet exakt dieselbe Prüfung. Spieler, Kampagnenankunft und Population behalten ihre vorhandenen Bereitschaftsanschlüsse. Physikalische Abfragen erfolgen wie bisher nach der Registrierung im nächsten Physikframe.

Die obere Größenprüfung deckte zusammenfallende Meshzellen auf: `Vector2` rundete UV-Koordinaten vor der lokalen Ursprungsabziehung auf Float32. Wasser-/Geländeraster und Voxelspalten berechnen UV-Zwischenwerte nun als skalare Doubles. Die Generatoren, Terrassierung, gemeinsame Kachelgrenzen und die lokalen Float32-Meshdaten bleiben dieselben Anschlüsse.

## Gemeinsamer Anschluss für Verbraucher

Der bestehende `RadialSurfaceAdapter` bleibt der einzige Besitzer der angebundenen Szenenwurzeln und Ursprungsverschiebung. Seine bisherigen internen Methoden behalten ihre Vorbedingungen. Der neue öffentliche Anschluss `query(address, capability)` gibt `{ok, code, schema, parameters, value}` zurück; `value` existiert nur bei Erfolg. Ergebnisformat: Version 1, kein neues Saveformat.

| Bedarf | Anschluss | Ergebnis / Grenze |
| --- | --- | --- |
| Dauerhafter Ort | `location(node)` / `Cube`-Adresse | Körper-ID, Fläche, u/v und radiale Höhe; keine absolute `Vector3`-Speicherung |
| Lokales Szenenabbild | `query(address, "local_position")` | Ursprung zuerst in Double-Präzision abziehen, danach `Vector3` |
| Gelände, Wasser, Normale | `query(address, "sample")` | Lesekopie des vorhandenen Samples: `height`, `water`, `normal`, Biome; `water_level` bei den belebten v1/v2-Oberflächen |
| Radiales Oben | `query(address, "up")` | Einheitsvektor vom Körperzentrum, unabhängig von Welt-Y |
| Tangentialrahmen | `query(address, "frame")` | Radiale `Basis`; gerichtete interne Variante bleibt `frame_at(address, forward)` |
| Bodenbereitschaft | `query(address, "collision")` | Erfolg erst mit aktiver Bodenkollision; ansonsten `ground_not_ready` |
| Ursprung | `query(address, "origin")` | Kopie des Double-Arrays; kein veränderbarer Zugriff |
| Physikalischer Treffer | `GameplaySpace.floor_hit` | Bestehender radialer Raycast nach `ground_ready`; keine Höhen-Teleportation |
| Verschiebung / Lebenszyklus | `offset`, `bind`, `unbind`, `origin_shifted`, `close` | Bestehende Bindungen; pro Szenenwurzel genau ein Ursprungsbesitzer |

Definierte Abfragefehler: `surface_unavailable`, `invalid_address`, `foreign_body`, `unsupported_capability`, `ground_not_ready`. Fremde Körperadressen werden nicht auf den aktiven Körper umgedeutet. Die Abfrage erzeugt weder Terrainjobs noch Körperdatensätze. Die Größenprüfung liefert zusätzlich `invalid_radius`, `radius_too_small`, `radius_too_large`, `catalog_only`, `invalid_body_identity`, `unsupported_surface_version` und `ground_resolution_unavailable`.

## Abnahme und Übergabe

`tests/surface_support_test.gd` prüft Grenzen einschließlich NaN/Unendlich/falscher Typen, erhaltene Katalog-/Speicherdaten, bekannte und unbekannte Generationen sowie Landefilter. Für vier Radiusklassen prüft der tatsächliche begrenzte Layoutselektor alle sechs Flächen mit Zentrum, Kante und Ecke. Die Laufzeit prüft an der unteren Testgrenze, einem kleinen Mond, 50-km-Radius, Terra und der oberen Grenze jede der 256 Spalten eines tatsächlich aufgebauten Kollisionsmeshes. Deaktivierte, fehlende und entfernte Besitzer sowie Ursprungsverschiebungen gehören zum selben Probe. Die bestehende Source-CI entdeckt den Test automatisch.

Reproduktion mit Godot 4.6.3:

```bash
python tools/validate_godot.py --godot /path/to/godot --skip-main \
  --tests surface_support_test surface_adapter_contract_test campaign_foundation_test \
  large_planet_runtime_test adaptive_planet_test spherical_campaign_runtime_test galaxy_visits_test
```

Abschlussprüfung am 10. September 2026, Codecommit `5cd89473ac611fab716de6f0a0997238c3e846a9`: alle sieben Fachtests sowie Import und Art-Quellenprüfung bestanden. [Rohwerte und Prüfergebnisse](ARCH05_SURFACE_RESULTS.json) dokumentieren die Messung. Der veröffentlichte Codebaum ist identisch mit dem lokal geprüften Baum `687ce19e569459dc4abce33459f466dda6050cf2`. Diese geometrische Abnahme ist keine 1080p60-/GPU-/Ziel-PC-Zusage. ARCH-02 behält Messroute und Performancebudgets; ARCH-19 behält den umfassenden Spieltest. Allgemeines Graben, unterirdische Navigation und neue Oberflächenarten sind keine verfügbaren Fähigkeiten.

| Radius | LOD am Prüfpunkt | Nominale Zellweite | Treffer auf dem eigenen Kollisionsmesh |
| --- | --- | --- | --- |
| 64 m | 2 | 2,00 m | 256 / 256 |
| 512 m | 5 | 2,00 m | 256 / 256 |
| 50 km | 12 | 1,53 m | 256 / 256 |
| 6.371 km (Terra) | 19 | 1,52 m | 256 / 256 |
| 100.000 km | 23 | 1,49 m | 256 / 256 |

Alle 1.280 Strahlen trafen den konkreten Kachelbesitzer. Die fünf Prüfstellen benötigen höchstens 525 Geländekacheln und jeweils 24 aktive Kollisionen. Der bestehende Bewegungsprobe durchlief auf drei großen Körpern je über 167 m und eine Flächenkante bei je drei Ursprungswechseln; der adaptive Nahtprobe prüfte 12.852 Verbindungen einschließlich 2.244 Flächenübergängen, größter Spalt etwa 0,077 mm. Die gemeinsame Kugelkampagne und Katalog-Wiederbesuche bestanden ihre vorhandenen Laufzeittests.

Integration: ausschließlich diesen Branch prüfen; keine unfertigen Fachbranches übernehmen. Die drei ARCH-05-Teilpunkte können nach Integration mit diesem Bericht und dem neuen automatischen Test verknüpft werden. Gemeinsame Roadmap- und Arbeitsverteilungsdateien bleiben beim Integrationsbesitzer.
