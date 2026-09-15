# WEATHER-01 – gezielte Fachabnahme

Godot `4.6.3.stable.official.7d41c59c4`, Linux x86_64, Headless-Quellprojekt mit
isolierten Nutzerdaten des bestehenden Runners. Kein nativer Grafik-/FPS-Nachweis.

- Quellbasis: `1d6573d9551c3f24bf1dd6fa64e5c301583a26c8`.
- Produktcode und Dokumentation: `9a87fff3e0d80a7cc456a6587f03b74c67fef4df`.
- Letzter Testquellstand: `41dbeb9e8e91bc084e6f2331ffc33c6dbcf872f6`.
  Dieser Folgecommit korrigiert ausschließlich den Beobachtungszeitpunkt im
  Rebase-Test. Produktcode, Modelltest und UnderwaterView-Test sind unverändert.
- Beide ausgewiesenen Prüfläufe hatten einen sauberen Arbeitsbaum. Danach werden
  nur diese Nachweise ergänzt. Einzelzuordnung samt Zeiten: [results.json](results.json).

Der erste Import sowie die Quellen-/Assetprüfungen waren erfolgreich. Die
abschließenden Fachläufe verwenden denselben importierten Ressourcenstand:

```sh
python3 tools/validate_godot.py --godot /path/to/Godot_v4.6.3-stable_linux.x86_64 --tests weather_model_test weather_runtime_test underwater_view_test --skip-import --skip-main --output /tmp/weather-final
python3 tools/validate_godot.py --godot /path/to/Godot_v4.6.3-stable_linux.x86_64 --tests weather_runtime_test --skip-import --skip-main --output /tmp/weather-runtime-final
```

| Prüfung | Ergebnis / konkreter Umfang |
|---|---|
| [Wettermodell](weather_model_test.log) | Bestanden: mehrere Seeds/10 Stunden, milde Grenzen, erste Regenfront, kontinuierliche Frontwechsel, A–B–A-Leseisolierung, ungültige/extreme Profile abgelehnt, bitgleiche Rekonstruktion im frischen Prozess |
| [Wetterlaufzeit](weather_runtime_test.log) | Bestanden am Folgecommit: begrenzte MultiMeshes, physischer Boden, Schutz-/Unterwasserunterdrückung, sechs Kugelrichtungen, echte Kampagne, Pause, Save/Load, Kameranachführung nach Rebase, keine Environment-Mutation, vollständiger Szenenabbau |
| [Unterwassersicht](underwater_view_test.log) | Bestehender direkter Verbraucher bestanden: Wasserlinie, Tiefe, trockene Bereiche, Kameratausch und Wiederherstellung |
| [Quellverträge](source_contracts.log) | Bestanden: 182 Tests einmalig in 18 Verträgen registriert; 1.285 Übersetzungen, 2 Sprachen |

Während der Entwicklung wurden zwei Testfehler korrigiert: Ein Vergleich über
JSON verlor die letzten Stellen von Floatwerten; der Neustartnachweis verwendet
jetzt verlustfreie Variant-Bytes. Der erste Abschlusslauf verglich Rebase-Posen
vor dem Node-Darstellungsschritt und scheiterte zeitabhängig; der Folgelauf prüft
nach diesem Schritt. Beide Korrekturen behalten die fachlichen Anforderungen.
Die Tabelle enthält die abschließenden bestandenen Einzelprüfungen, keine
behauptete neue Vollsuite.

Offen: gemeinsame Shader-/Rendering-Optik, wetterabhängiger Ton, Windows-Spieltest,
Stammeskamera im nativen Build, kleine Dachkanten/hohe Höhlen und Ziel-PC-Leistung.
Wetterfolgen und Extremstürme sind geplant, nicht als implementiert abgenommen.
