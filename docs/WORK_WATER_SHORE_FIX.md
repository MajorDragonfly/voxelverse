# WATER-SHORE-DEPTH – Wasserfehler vom 16.09.2026

Auftrag: durchscheinende Schatten und gerade Wasserwände auf der Kugelwelt
korrigieren; Wasser soll an offenen Ufern ablaufen können.

## Befund und Korrektur

`living_planet_v2` verwendete innerhalb von 22 Metern den Quellpegel eines Sees
und unmittelbar außerhalb Meereshöhe. Die getesteten Seen hatten dadurch
Pegelsprünge bis 59,045 m. Teile dieser Verbindungsflächen lagen über dem Boden.
Der Shader benutzte trotz voller Deckung den transparenten Renderpfad ohne
eigene Tiefe; nachfolgende Bildschirmeffekte sahen weiter den Untergrund.

- Wasser arbeitet jetzt im opaken Renderpfad mit eigener Tiefe. Trockene Flächen
  werden über die vorhandene vorzeichenbehaftete Wassertiefe verworfen. Normale
  Schatten von Objekten über dem Wasser bleiben.
- Ein deterministisches Flutungsverfahren findet die niedrigste Abflussschwelle
  im vorhandenen Gelände. Der zurückbleibende Seepegel liegt darunter. Nur die
  verbundene Senke bleibt gefüllt; getrennte tiefe Stellen werden nicht geflutet.
- Der Übergang zum Meeresspiegel liegt unter dem Boden. Das Raster gehört zum
  See und bleibt bei Kachelwechseln identisch. Höchstens 32 Lösungen mit je
  29 × 29 Werten pro Oberflächeninstanz; keine Berechnung für jeden Frame.
- Terrainhöhen, Kollisionen, Körper-IDs und Speicherformat bleiben unverändert.
  Rendering, Schwimmen, Trinken, Unterwassersicht und Audio teilen einen Pegel.

## Prüfung

Basis: `176d088d34324de14952bc7506fe9763a22cf4b0`.
Geprüfter Code: `357abf05f1cf8de139b733ae195881b2c8ad2707`.
Geprüfter Tree: `b886b37fdde20fdb68df3ea0d180e15243b8eece`.
Godot 4.6.3, Linux/Headless, isolierte Nutzerdaten. Sauberer, während der Prüfung
unveränderter Quellstand; Import zuvor erfolgreich.

```sh
python3 tools/validate_godot.py --godot <Godot-4.6.3> \
  --tests living_lake_water_test living_surface_materials_test \
  spherical_creature_test onboarding_guidance_world_test \
  audio/spherical_water_audio_test --skip-import --skip-main \
  --output <Prüfverzeichnis-außerhalb-des-Projekts>
```

Alle fünf gezielten Tests, Testregistrierung und Quellintegrität bestanden.
Der neue Test enthält 3056 Kontrollen: geschlossenes Becken, offener Abfluss,
getrennte Senke, 15 reale Seen auf drei Seeds, Kantenstetigkeit und kalte Caches.
An der alten Abbruchkante beträgt der größte gemessene Höhenunterschied bei
2 mm Abstand jetzt 1,60 mm. Bestehende Integrationstests prüfen echtes Trinken,
Unterwassersicht, Audio, Anleitung sowie Speichern und Neustart.
Zwei Prüfaufbauten platzieren den Spieler nun relativ zum tatsächlichen Pegel;
ihre bisherigen Ergebnisprüfungen bleiben erhalten.

Die lokale grafische Prüfung konnte nicht starten, weil der Displayserver keine
lokalen Sockets öffnen konnte. Native Exporte, gemeinsame CI und Windows-Spieltest
sind offen. Die Schattenkorrektur ist somit noch nicht grafisch abgenommen.

## Noch offen: WATER-FLOW-01

Diese Korrektur berechnet den abgelaufenen Gleichgewichtszustand. Sichtbare,
zeitabhängige Abflüsse sind noch nicht umgesetzt. Das Folgepaket führt vom
tiefsten Auslass abwärts bis zum Folgebecken oder Meer, mit gerichteter Strömung
und Wasserfall an Höhenstufen. Ein Partikeleffekt allein erfüllt den Auftrag nicht.

Abnahme: kein Bergauffließen, kein Ende an Kachelgrenzen, gleicher Wasserstand
für Bild/Schwimmen/Trinken/Audio, identische Route nach Entladen und Neustart,
begrenzte Arbeits- und Geometriebudgets. Eingriffe in Flussbetten brauchen eine
eigene Generatorversion; vorhandene v1/v2-Geländehöhen bleiben erhalten.

## Veröffentlichung

Branch: `agent/water-shore-flow-fix`. Lars hat nach der ursprünglichen
automatischen Upload-Sperre die Veröffentlichung auf `MajorDragonfly/voxelverse`
und PR-Erstellung ausdrücklich freigegeben. Der PR führt die CI-Nachweise des
veröffentlichten Stands; Integration erst nach allen vier Pflichtprüfungen.
