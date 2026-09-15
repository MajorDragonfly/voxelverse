# WEATHER-02A – regionale Wettervertiefung

Die vier gezielten Fachprüfungen sind bestanden. Engine:
`4.6.3.stable.official.7d41c59c4`, Linux x86_64, Headless-Quellprojekt;
isolierte Nutzerdaten des vorhandenen Runners. Kein nativer Grafik-/FPS-Nachweis.

Die Läufe fanden im Arbeitsbaum auf Basis `57cb7e8` statt. Der geprüfte endgültige
Funktionsstand wurde als `3f57f7f8435cabe0487a852d8422819f9fd851b2`
(Tree `b12135ae21222186704a50d85c63e90360009b17`) festgehalten.
[Ergebnisse und exakte Quelldatei-Hashes](results.json) identifizieren die
geprüften Änderungen. Anschließend kamen ausschließlich diese Nachweise hinzu.
Unveränderte Abhängigkeiten bleiben auf der dokumentierten WEATHER-01-Basis.

| Prüfung | Bestandener Umfang |
|---|---|
| [Grundmodell](weather_model_test.log) | Friedlicher Beginn, Seeds/Fronten, Kontinuität, gesperrte Extremprofile, bitgleicher frischer Prozess |
| [Regionalmodell](regional_weather_test.log) | Verschiedene örtliche Fronten, alle Cube-Kanten von beiden Seiten, Pole, feucht/trocken/kalt/Vakuum, milde Grenzen, Niederschlagsaufteilung, Böen nach 100 Stunden, feste Prognose, ungültige Daten, Körperisolation und weiterer frischer Prozess |
| [Laufzeit](weather_runtime_test.log) | Echte physische Bodenprobe, begrenzte Regen-/Schnee-Renderübergabe, helle kompakte Flocken, Schutz/Unterwasser, Verwerfen veralteter Bodenwerte, echte Kampagne, Prognoseport, Pause, Kameratausch, Rebase, Save/Load und Szenenabbau |
| [Unterwasser-Verbraucher](underwater_view_test.log) | Bestehende Prüfung von Wasserlinie, Tiefe, Kameratausch und Environment-Wiederherstellung |
| [Quellverträge](source_contracts.log) | 183 Tests, einmalig in 18 Verträgen registriert; Übersetzungskatalog bleibt gültig |

Ausgeführt mit `tools/validate_godot.py`, festem Godot-Pfad und `--skip-main`:

```sh
python3 tools/validate_godot.py --godot /path/to/Godot_v4.6.3-stable_linux.x86_64 --contracts weather --skip-main --output /tmp/regional-first
python3 tools/validate_godot.py --godot /path/to/Godot_v4.6.3-stable_linux.x86_64 --tests regional_weather_test weather_runtime_test --skip-import --skip-main --output /tmp/regional-corrected
python3 tools/validate_godot.py --godot /path/to/Godot_v4.6.3-stable_linux.x86_64 --tests underwater_view_test --skip-import --skip-main --output /tmp/regional-water
```

Der erste Lauf importierte die neuen Skripte erfolgreich und bestand die
Asset-/Quellgates sowie beide Modellprüfungen. Seine Darstellungsprüfung deckte
auf, dass Godots Dummy-Renderer bei MultiMesh-Abfragen Identitätstransforms und
schwarze Farben liefert. Die Prüfung liest jetzt die tatsächlich übergebenen,
fest begrenzten Transform-/Farbwerte vor dem Rendering-Server-Aufruf. Sie belegt
Geometrie-/Farbeingaben und Bodenbegrenzung, keine gerenderten Pixel. Eine weitere
alte Fixture-Annahme verlangte Regen am Startort zu einer festen Zeit; örtliche
Trockenheit muss dort jetzt erlaubt sein. Niederschlag selbst wird explizit in
feuchten/kühlen Modellfällen und in der physischen Darstellungsfixture geprüft.
Die abschließenden beiden Nachläufe bestanden ohne Skript-/Laufzeitfehler.

Gemeinsame Shader-/Audioinszenierung, nativer Windows-Spieltest, Ziel-PC-Leistung,
präzise kleine Dachkanten und hohe Höhlen bleiben offen. Die drei Prognosen sind
am aktuellen Ort und mit dessen Klima berechnet; eine Wetteranzeige wird nicht
als implementiert behauptet. Feuer-/Sandstürme und Wetterschaden bleiben deaktiviert.
