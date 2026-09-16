# ARCH-14-ATLAS-SEARCH — Prüfnachweis

## Abschließender Quellstand

- Basis: `d57b1ef385728728b132518a1ea05683888dcae0` (#125).
- Lokal geprüft: `d72f41f88863c52134dc2d2f6e4278e064a17617`, sauberer Arbeitsstand.
- Über die GitHub-Anbindung veröffentlicht:
  `b9c92cf3d203fb760647d717bfb30d6e0e076879`.
- Beide Quell-Trees sind exakt gleich:
  `dbdc471e70f4993752f90517b6374efa22d85b9e`.
- Godot `4.6.3.stable.official.7d41c59c4`, Linux/headless,
  isolierte synthetische Nutzerdaten je Prüfschritt.

## Abschlusslauf

```sh
python3 tools/validate_godot.py \
  --godot /workspace/scratch/2c2866d70564/godot \
  --tests atlas_search_test atlas_places_test world_map_test world_map_localization_test localization_test \
  --skip-main --skip-import \
  --output /workspace/scratch/97e7c57ff0f3/atlas-final-check
```

Alle fünf Fachtests, Quell-/Sprachgate und abschließende Quellintegrität bestanden.
Der neue Test benötigt rund 20 s, der bestehende 3.105-Orte-Test ebenfalls rund
20 s. Die Kartenprüfungen schließen echte Unterprozesse zum Laden gespeicherter
Kampagnen ein. Such-/Filterzustände sind reine Sitzungseinstellungen.

[Originaler Abschlussbericht](results.json) ·
[Rohprotokolle und vollständige finale Quellmanifeste](validation-logs.tar.gz) ·
[Dateiprüfsummen](sha256.json).

Der Ressourcenimport und das Artgate bestanden im ersten Lauf dieses Checkouts.
Anschließend wurden ausschließlich Skripte, Tests und Dokumentation geändert;
kein zusätzlicher Grafik-/Audioimport war für diese Fachprüfungen erforderlich.
Die Abschlussprüfung behauptet keine erneute Vollsuite oder Exportprüfung.

## Ursprüngliche Befunde und Korrekturen

Die ursprünglichen Berichte und Logs bleiben im Archiv erhalten:

1. `atlas-initial-check`: Grundkarte, Import und Quellgates bestanden. Die
   bestehende Sprachprüfung griff nach drei Frames auf eine noch nicht erzeugte
   Trefferliste zu. Sie wartet jetzt mit Zeitgrenze auf die bewusst schrittweise
   Filterabfrage; die folgenden Fokus-/Scroll-/Datenprüfungen bleiben erhalten.
2. `atlas-search-check`: Neue Such-/Speicher-/Eingabeprüfungen funktionierten;
   kleine Fenster und große Schrift zeigten Panelüberläufe. Sprachprüfung und
   vorhandenes Ortsregister bestanden.
3. `atlas-layout-check`, `atlas-resize-check`, `atlas-layout-diagnostic`:
   Legende/Überschrift im kompakten Listenmodus reduziert und die Ursache der
   verbleibenden Überläufe eingegrenzt. Nach dem Fensterwechsel behielt das Panel
   eine vorübergehend zu große Mindesthöhe, obwohl seine Kinder bereits kleinere
   Maße meldeten. Das Panel wird jetzt nach Mindestgrößenänderungen erneut
   eingepasst. Die Protokolle enthalten die tatsächlichen Rechtecke.
4. `atlas-resize-fixed`: Alle neuen Such- und Layoutprüfungen bestanden. Danach
   kamen noch eine explizite Strg+F-Prüfung und das Freigeben der Abfrage beim
   Verlassen der Szene hinzu. Der abschließende saubere Quelllauf prüft diese mit.

## Grenzen

Die zwölf Kombinationen aus DE/EN, drei Fenstergrößen und zwei Schriftgrößen
sind über reale Godot-Controlrechtecke und Eingaben geprüft. Ein zusätzlicher
gerenderter Lauf konnte nicht starten, weil Xvfb in dieser Ausführung keine
lokalen Sockets öffnen konnte ([Auszug](display-attempt.txt)). Es gibt deshalb
keine Screenshot- oder native optische Freigabe. Windows-Export, Ziel-PC-FPS
und eine Gesamtintegration stehen aus. Das 2-ms-Suchbudget ist weich; einzelne
Dateizugriffe können länger dauern.

Der Folgecommit enthält ausschließlich diesen Nachweisordner. Zentrale
Statusseiten und der Gesamtstatus von ARCH-14 bleiben beim Integrationschat.
