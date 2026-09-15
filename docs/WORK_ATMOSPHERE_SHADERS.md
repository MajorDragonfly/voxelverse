# ATMOSPHERE-SHADERS · Kugelwelt mit Licht und Himmel

Basis: `1d6573d9551c3f24bf1dd6fa64e5c301583a26c8` aus Integrations-PR #110.
Eigenständiger Nutzerauftrag vom 15.09.2026; kein Gesamtabschluss einer ARCH-Nummer.

## Spielverhalten

Im normalen Kugelkampagnenstart ersetzt ein eigener Atmosphärencontroller die
bisherige einfarbige Umgebung. Himmel und Wolken nutzen einen eigenen Godot-Sky-Shader.
Planetenprofil, örtliche Feuchtigkeit, Höhe und Sonnenwinkel bestimmen Farben,
Wolkendeckung und sanft überblendeten Dunst. Ein fester Stern in Körperkoordinaten
beleuchtet die Heimatseite; auf der Gegenseite gibt es einen Sternenhimmel.
Die sichtbare Sonnenscheibe stimmt mit der Richtung des schattenwerfenden Lichts überein.

Wolken bewegen sich anhand der bestehenden Kampagnenzeit und halten bei Pause/Laden
an. Das Feld liegt in Körperkoordinaten: keine Würfelflächennähte, Welt-Y-Horizonte
oder Sprünge durch die Verschiebung des lokalen Ursprungs. Die Kamera bestimmt
radiales Oben auch in der Stammesansicht. Weltbeleuchtung gehört zum Controller;
der bestehende UnderwaterView behält seine Kameraumgebung und stellt beim Auftauchen
die aktuelle Luftumgebung wieder her.

**F8 → Anzeige → Atmosphäre → Übernehmen & speichern:**

| Stufe | Wirkung |
|---|---|
| Basis | Himmel, zweistufige Wolkenberechnung, Sonnenlicht und Entfernungsdunst |
| Atmosphärisch (Standard) | Detailliertere Wolken, Kontaktschatten/SSAO, weicheres Sonnenlicht, dezentes HDR-Bloom |
| Cineastisch | Zusätzlich volumetrischer Dunst mit gerichteter Lichtstreuung, weitere Wolkendetails und längere Schattenreichweite |

Die Einstellung liegt im vorhandenen `display_settings.cfg`, getrennt von Spielständen,
und gilt sofort auch aus dem pausierten Menü. DE/EN-Texte laufen über den bestehenden
Katalog. Zusatzeffekte werden nur unter Forward+ aktiviert; andere Renderer erhalten
Himmel/Wolken/Dunst und eine niedrigere Sonnenenergie gegen überhelle Farben.

## Abgrenzung und Integrationsanschlüsse

- Neue Dateien unter `world/visuals/atmosphere/` besitzen Himmel, Luftumgebung und Sonne.
- `main/spherical_campaign.gd`: nur Umgebungsaufbau und einmaliger Anschluss nach
  Spielerplatzierung. Beim Zusammenführen mit dem Render-/Ladechat diesen Controller
  erhalten; nicht zusätzlich eine zweite WorldEnvironment/Sonne erzeugen.
- `core/display_settings.gd`: ein neuer Auswahlwert mit vorhandenen Lade-/Speicher-
  und Übernehmenanschlüssen. Bestehende Tastenzuordnung und Sprachverwaltung bleiben Besitzer.
- Fünf `ATMOSPHERE_*`-Schlüssel im Katalog plus generierte PO-Dateien.
- `campaign_atmosphere_test` genau einmal unter `terrain_art` in der Testregistry.
- ARCH-13/-24/-17/-27/-26 und Gelände-, Wasser-, Vegetationsmesh-, Streaming- und
  Ladebereitschaftscode sind nicht Teil dieser Lieferung. Zentrale Statusseiten
  aktualisiert die Integration.

## Aufwand und bewusst offene Grenzen

Atmosphärenparameter werden höchstens zehnmal pro Sekunde aus einer Kameraabtastung
aktualisiert. Die Radiance-Cubemap nutzt Godots vorgeschriebene 256er-Echtzeitgröße;
die teurere Wolkenberechnung läuft ausschließlich im sichtbaren Himmel. Kein
zusätzlicher Fullscreen-Postprocess, kein globales Shader-TIME und keine neuen Texturen.

Dies ist eine eigene Godot-Umsetzung der gewünschten Shaderpack-artigen Stimmung.
Minecraft-Shaderdateien werden nicht importiert. Kein neuer Tag-/Nachtzeitvertrag,
Wetter-/Regenmodell, Wolkenschatten auf Gelände, volumetrische 3D-Wolken, Raytracing,
Wasserumbau oder astronomisches Mehrsternmodell. Die Tageszeit ändert sich hier durch
Ortswechsel relativ zur festen Sonne, nicht durch einen neu eingeführten Tageszyklus.
Eine zukünftig eigene luftlose Mond-/Orbitdarstellung bleibt beim Planeten-/Weltraumpaket.

Native Prüfaufnahmen zeigen eine ausdrücklich synthetische Voxel-Prüfszene mit
identischer Kamera und Geometrie, keine Bilder aus einem normalen Spielstand.
Linux-Softwaregrafik belegt Shaderkompilierung und Darstellung; sie ist keine
Ziel-PC-/FPS- oder Windows-D3D12-Abnahme. Cineastisch deshalb auf Lars' Ziel-PC prüfen.

## Gezielte Prüfung und Nachspielen

```sh
python3 tools/validate_godot.py --godot GODOT --tests campaign_atmosphere_test underwater_view_test spherical_campaign_runtime_test frontend_test --skip-main --output OUT
python3 tools/review_atmosphere.py --godot GODOT --renderer forward_plus --output OUT_RENDER
```

Der Grafikrunner benötigt ein X-Display. `--renderer gl_compatibility` prüft die
abgespeckte Variante. Die Prüfszene enthält Vorher/Atmosphärisch/Cineastisch,
90° gedrehte radiale Ausrichtung, tief stehende Sonne und Nacht.

Im Spiel: neue oder gespeicherte Kugelkampagne öffnen; F8-Stufen vergleichen;
Menü schließen, Wolken beobachten; pausieren; tauchen und auftauchen; speichern,
zum Hauptmenü zurückkehren und erneut laden. Nach Integration zusätzlich die
Stammeskamera sowie einen Körperwechsel im gemeinsamen Windows-Build ansehen.

Enginegrundlagen: [Sky-Shader](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/sky_shader.html),
[Environment](https://docs.godotengine.org/en/4.6/classes/class_environment.html),
[volumetrischer Nebel](https://docs.godotengine.org/en/4.6/tutorials/3d/volumetric_fog.html).
