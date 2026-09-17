# PERF-COLD-START – Kampagnenstart nach Zeitabschnitten

Basis: `176d088d34324de14952bc7506fe9763a22cf4b0`, eigener Branch
`agent/perf-cold-start-20260916`. Anschluss an `tools/profile_performance.py`;
keine Änderung an Grafikvorgaben, Spielregeln oder Produktions-Timeouts.

## Messung

```bash
python3 tools/profile_performance.py --mode startup --godot /pfad/zu/godot \
  --seed 15838 --cycles 3 --output ../startup-erster-lauf

python3 tools/profile_performance.py --mode startup --godot /pfad/zu/godot \
  --seed 15838 --cycles 3 --replay ../startup-erster-lauf --output ../startup-wiederholung
```

Projekt einmal mit Godot 4.6.3 importieren. Ausgabe außerhalb des Projekts in einem
neuen Verzeichnis. `--renderer forward_plus --size 1920 1080` wählt die echte
Grafikmessung; `headless` misst nur den Startablauf und ist keine Grafik-/FPS-Abnahme.

Ein eigener Vorbereitungsprozess erstellt über SaveGameService einen aktuellen
isolierten Startspielstand einschließlich eingefrorenem Kreaturenentwurf, ohne
eine Welt aufzubauen. Ein danach gestarteter Godot-Prozess lädt diesen Stand über
den regulären SessionFlow: einmal prozesskalt, anschließend im selben Prozess
erneut. Der Betriebssystem-Dateicache wird **nicht** geleert. „Warm“ garantiert
keine bestimmten im Ressourcencache verbliebenen Objekte; `resource_cached` wird
je Start gesondert beobachtet. Rohwiederholungen stehen einzeln im Bericht.

Alle Wiederholungen laden dieselben Bytes und dieselbe Körper-ID. Direkt am
vorhandenen `world_started`-Signal wird die Messwelt pausiert und Autosave
deaktiviert. Für die nächste Wiederholung wird nur diese isolierte Arbeitsszene
verworfen; der normale Befehl „Speichern & zum Hauptmenü“ wird nicht ausgeführt.
Der Prüfstand kontrolliert Save-Versuche, Datei-Hash, Anzahl gestarteter Welten
und den vollständigen Abbau der vorigen Welt. `--replay` kopiert die erhaltene
Fixture in ein neues Benutzerverzeichnis und verändert die Quelle nicht.

## Bedeutung der Abschnitte

| Abschnitt | Gemessener Ablauf |
|---|---|
| `prepare_state` | Ladeoverlay und vorhandene Spielstand-/Kampagnenvorbereitung |
| `state_settle` | Vorhandener Frame für den aufgeschobenen Generatorzustand |
| `threaded_load` | ResourceLoader-Anforderung bis zur Entnahme der PackedScene |
| `scene_instantiation` | Synchroner `change_scene_to_packed`-Aufruf |
| `scene_ready` | Aufgeschobener Szenenanschluss und `_ready` bis `scene_changed` |
| `start_terrain` | Warten auf die vorhandene `world_initialized`-Startkollision |
| `arrival` | Vorhandener Ankunftsabschluss bis zur Spielfreigabe |

Es sind aufeinanderfolgende Wandzeiten einschließlich Scheduling und kleinem
Messaufwand, keine isolierten CPU-Zeiten. Die Summe entspricht der gemessenen
Startdauer. Startkollision bereit bedeutet nicht, dass jede ferne Landschaft
bereits dargestellt ist. Die Messung ruft keinen zusätzlichen Welt-/Terrainbau auf.

`SessionFlow.startup_diagnostics()` liefert eine Kopie des letzten bzw. laufenden
Starts. `startup_phase_changed` meldet nur Phasenwechsel und Abschluss. Diese
Daten bleiben im RAM und erweitern keinen Spielstand. Ohne angeschlossenen
Prüfstand wird keine Diagnosedatei geschrieben. Fehler behalten ihre letzte Phase;
eine Reisewiederherstellung beginnt eine neue Messfolge.

Die bestehende Kugel-Kampagnenprüfung ergänzt `SPHERE_LOAD` um diese Zeitdaten.
Auch die vorhandene Laufroute erfasst `startup_loads` und nennt bei einem
Start-Timeout die letzte Phase.

## Berichte und Fehler

- `summary.md`: Kalt-/Warmvergleich pro Phase und insgesamt.
- `capture.json` / `performance.json`: Rohintervalle, Rezept, Quelle/Tree/Änderungen,
  Engine, Renderer, Hardwareangaben, Körperidentität und unveränderter Datei-Hash.
  Git-Quellstand und Hashes geänderter Dateien werden am Ende erneut verglichen;
  zwischenzeitlich geänderter Quellstand macht die Messung ungültig. Das ist eine
  Prüfung an den Laufgrenzen, keine Sperre gegen fremde Änderungen während des Laufs.
- `startup-progress.json` / `engine.log`: Letzte Phase; auch bei einem blockierten
  `_ready`-Aufruf kann der überwachende Prozess sie nennen. `--stage-timeout`
  begrenzt jede Phase des Prüfstands; die bestehenden Spiel-Timeouts bleiben gleich.
- `startup-fixture.json`, `fixture/`: Startspielstand und isolierte Nutzerdaten
  für Wiederholung und Fehlerdiagnose; auch bei einem fehlgeschlagenen Lauf erhalten.

Die kleine Vorbereitung gehört nicht zur gemessenen kalten Weltladezeit. Ein
Seedwechsel ist ein neues Rezept. Einzelne Werte sind keine belastbare Aussage
zur Zielhardware; `target_pc_acceptance` bleibt `false`.

Abnahme: Trace-Test für Kopien, Phasenabschluss, Fehler und Neustart; Python-Tests
für unvollständige/manipulierte Messberichte sowie echten blockierten Kindprozess;
zwei reale Ladungen und Wiederholung der identischen Fixture; bestehende
Kugelkampagnenprüfung für den regulären SessionFlow. Konkrete Ergebnisse im PR.
