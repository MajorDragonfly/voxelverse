# ARCH-02 – Messrouten für die Kugelkampagne

Auftrag: ARCH-02 / M1h, M10. Basis: `ea900f2` (veröffentlichtes `main`, PR #48). Eigener Branch: `agent/arch02-spherical-performance-2026-09-10`.

**Lieferumfang:** Messwerkzeuge und kurze Headless-Nachweise. Die zehnminütige Ziel-PC-Route, Grafikmessung und die Dorf-/Reiserezept-Erweiterung bleiben getrennte Abnahmen. ARCH-02 ist deshalb insgesamt noch nicht geschlossen. ARCH-20, ARCH-23 und ARCH-25 gehören anderen Chats. Gemeinsame Save-, Katalog-, Controller- und Roadmap-Dateien werden in dieser Lieferung nicht verändert.

## Vertrag und Anschluss

`tools/profile_performance.py` startet Protokoll 2. Die frühere Messroute führte über die inzwischen nur diagnostische Flachwelt. Ihr historischer Bericht in `WORK_PERFORMANCE_VALIDATION.md` bleibt als alter Nachweis erhalten; neue Läufe verwenden ausschließlich `SessionFlow` und `main/spherical_campaign.tscn`. Die alten Parameter `--distance`/`--step` entfallen: Die Spielfigur bewegt sich durch ihre bestehende Physik und echte Eingabe. Tempo, Kollision, Bedürfnisse und Angriffe werden nicht manipuliert. Eine blockierte Strecke oder ein toter Spieler liefert einen fehlgeschlagenen Bericht, keine teleportierte Rückkehr.

Der reguläre Ablauf enthält Kaltmenü → neue Kugelkampagne → Bodenkollision bereit → Beruhigung → Gehen mit drei Richtungen (0°, +45°, −45° zur anfänglichen Richtung) → physischer Rückweg entlang aufgezeichneter Oberflächenadressen → Speichern/Pause/Menü → Laden und Wiederholung. Standard sind 600 Sekunden Hinweg, danach Rückkehr; zwei Besuche prüfen zusätzlich Lebenszyklus und erhaltene Position. Der Rückweg darf höchstens die doppelte Hinwegdauer plus Stufen-Timeout benötigen. Wegpunkte werden nach mindestens 0,75 m aufgezeichnet, die Rückkehrtoleranz beträgt 0,65 m. Lokale Welt-Y-Koordinaten oder Positionssprünge werden nicht verwendet.

SessionFlow, Spieler, Terrain/Population, zentraler SaveService und `RegionStore` bleiben autoritative Besitzer. Die Messung liest bestehende Diagnostik. Das einzige zusätzliche Save-Signal im synthetischen Speicherprobe ist ein prozesslokaler `save_started`-Beobachter, wie ihn die echte Population bereits verwendet. Er schreibt vollständig validierte Regionsänderungen vor dem gemeinsamen Snapshot. Er wird danach wieder getrennt; kein zweiter Speicherdienst oder neues Schema entsteht.

## Ausführen

Godot 4.6.3 und einmal importierte Projektquellen werden vorausgesetzt. `--output` muss neu und außerhalb des Quellprojekts liegen. Jeder Lauf verwendet eigene Einstellungen und Spielstände. Mit `--godot` den lokal installierten Editor angeben.

```bash
# Kurzer Test der Instrumentierung und zweier echter Spielbesuche:
python tools/profile_performance.py --godot /pfad/zu/godot --walk-seconds 12 --cycles 2 --output ../arch02-kurz

# Zehn Minuten Hinweg mit Richtungswechseln plus Rückkehr, anschließend Wiederbesuch:
python tools/profile_performance.py --godot /pfad/zu/godot --renderer forward_plus --size 1920 1080 --walk-seconds 600 --cycles 2 --output ../arch02-zielpc

# Derselbe eingefrorene Ausgangsstand in einem frischen isolierten Prozess:
python tools/profile_performance.py --godot /pfad/zu/godot --replay ../arch02-kurz --seed 15838 --walk-seconds 12 --cycles 2 --output ../arch02-wiederholung

# 1/10/100 Körper × insgesamt 0/10/1000 geänderte Regionen:
python tools/profile_performance.py --godot /pfad/zu/godot --mode saves --output ../arch02-speichern
```

Ein Lauf mit 600 Sekunden Hinweg ist deutlich länger als zehn Minuten: Rückweg, zwei Besuche und Ladezeiten kommen hinzu. Kurze Läufe setzen `full_walk_protocol` auf `false`. `target_pc_acceptance` bleibt immer `false`: Eine technische Messung ersetzt Lars' Spieltest auf festgelegter Hardware nicht. `--replay` übernimmt den eingefrorenen ersten Snapshot und dessen unveränderliche Regionsdateien, nicht die am Ende fortgeschrittene Kampagne. Die ursprünglichen Dateien werden ausschließlich in das isolierte Arbeitsverzeichnis kopiert. Gleicher Seed allein garantiert bei neu erzeugten Kampagnen keine gleichen Objekt-IDs; deshalb werden Anfangssnapshot und Körperdescriptor mitgeliefert.

## Messbedeutung

| Wert | Bedeutung / Grenze |
|---|---|
| `frame_ms` | Tatsächliche Intervalle zwischen Prozessframes einschließlich Wartezeit, Messaufwand und FPS-Begrenzung. Median, p95, p99 und Maximum; keine reine CPU-Auslastung. |
| `process_monitor_ms`, `physics_monitor_ms` | Grob aktualisierte Godot-Monitore; wiederholte Werte, keine unabhängige Messung jeder CPU-Phase. |
| `render_cpu_ms` | Viewport-Renderzeit auf CPU plus Framevorbereitung, ohne Gameplay-CPU. |
| `render_gpu_ms` | GPU-Zeitstempel des Renderers. Bei Headless oder fehlenden Zeitstempeln `null`, niemals als 0-ms-GPU-Leistung ausgeben. |
| Upload / Veröffentlichung / Worker | Vorhandene CPU-Wandzeiten und Spitzen des Geländes; keine gemessene GPU-Transferdauer. Die bisherigen Rohpuffer sind auf die ersten 2.048 Uploads bzw. 256 Jobs begrenzt; diese Grenze steht im Bericht. |
| Objekt-/Queue-Zustand | Einmal pro Sekunde: Nodes, Ressourcen, aktive Physikobjekte/Kollisionspaare, Geländekollisionen, Tiere/Pflanzen, Flora, Terrainjobs, ausstehende Uploads, Caches, Dirty-Zustand, Reads/Writes und Ursprungswechsel. |
| Speicher | Godots statischer Allokator plus unter Linux gesondert Prozess-RSS aus Godots eigenem `/proc/self/status`. Andere Betriebssysteme erhalten für fehlendes RSS `null`. Renderallokationen sind keine Messung physisch residenten VRAMs. |
| Speicherproben | Drei Rohwiederholungen je Fall; daraus keine belastbaren p95/p99 ableiten. Erstes Dirty-Speichern wird von späteren unveränderten Saves getrennt. |

`frames.csv` enthält jeden aufgenommenen Frame; `capture.json` und `performance.json` enthalten Zusammenfassung, Quellencommit/Dirty-Status, CPU, Engine, Renderer, Seed, tatsächliche Adressen und Snapshot-Zeitreihe. `process-memory.json` enthält die gesonderten RAM-Proben. Die Messung liest im Godot-Prozess selbst, damit abweichende Prozess-ID-Namensräume im Container keinen fremden Prozess erfassen. `fixture/` erhält Einstellungen, Ausgangsslot/-historie und Regionsblobs, auch wenn ein Lauf scheitert. Diese Kopie wird vor Entfernung des temporären Benutzerverzeichnisses erstellt. Generierte Berichte überschreiben keine früheren Messungen.

Das Messwerkzeug verursacht selbst CPU-/Speicher-/Dateiarbeit. Es protokolliert Raw-Frames gepuffert und erhebt die umfangreicheren Zähler nur einmal pro Sekunde. Die Ramwerte enthalten auch anwachsende Berichtsdaten. Der Kaltstart ist pro neuem Prozess kalt für Godots Ressourcencache, aber nicht notwendigerweise für den Betriebssystem-Dateicache. Audio nutzt den Dummy-Treiber und ist keine Audio-Gerätemessung. Grafikvoreinstellungen sind die isolierten Projektstandards, VSync aus; Renderer, Auflösung und Frame-Cap stehen im Rezept. Die tatsächliche Darstellung und GPU-Zeit wurden in dieser Headless-Umgebung nicht abgenommen.

## Speicherproben und deren Grenzen

Die neun Fälle enthalten aktuelle, minimale Kugelkörper und pro geänderter Region eine persistente geerntete Pflanze mit unveränderter ID, `remaining = 2`, `regrow_at = 600`. 0/10/1000 Regionen sind die **Gesamtzahl**, verteilt auf 1/10/100 Körper. Regionen werden beim ersten gemessenen Speichern über den echten Store eingefügt; Cache-Eviction und Checkpoint sind eingeschlossen. Die zentrale Kampagnendatei enthält weiterhin deren Root-Manifeste. Neue Blobdateigröße wird zusätzlich zur JSON-Save-Größe ausgewiesen. Nach Laden werden alle Regionen mit neuen Store-Instanzen erneut gelesen und auf die ursprüngliche ID/Menge geprüft.

`save_total_with_history_ms` und `load_total_ms` messen die tatsächlichen bestehenden Aufrufe. Kopieren (`duplicate(true)` eines echten Snapshots), Validator, JSON-Serialisierung und Schreiben/Lesekontrolle/Umbenennen sind **isolierte Teilproben**, keine addierbaren Zeitabschnitte innerhalb des zentralen Speicherdienstes. Der erste Dirty-Save enthält zusätzlich den realen Regionsbeobachter. Beim wiederholten Speichern werden vorhandene Historien-/Backupregeln angewandt. Datenträgercache und OS-Puffer werden nicht geleert; keine neue fsync-Garantie wird behauptet.

Die separate vorhandene Dorf-/Fernsimulationsmessung `tools/benchmark_campaign_scaling.gd` bleibt unverändert. Diese neuen Minimalfälle ersetzen weder ihre Drei-Bewohner-Dörfer noch große Arten-/Entwurfs-/Fortschrittsbestände. Die Regionsprüfung verwendet neue Reader nach Save/Load; ein echter neuer Prozess wird zusätzlich durch die gespeicherte Kugelroute und `--replay` geprüft.

## Vorläufiges Budgetinventar

| Bereich | Bereits geltende Grenze auf der Basis |
|---|---|
| Ziel | 1080p60 = 16,67 ms pro Frame; CPU, GPU, RAM und Preset des Ziel-PCs noch festzulegen |
| Terrain | 2 Uploads und kooperativ 4 ms pro Frame; maximal 256 Cacheeinträge / 1.536 residente Meshes; 24 lokale Geländekollisionen |
| Terrainworker | Höchstens 4 Meshworker; Auswahljob separat |
| Regionsstore | 96 Datensätze und 128 Indexseiten pro Store; maximal 2 MiB pro Blob. Das sind keine globalen Grenzen für alle besuchten Körper zusammen. |
| Aktive Population | 12 Wildtiere und 16 Nahrungspflanzen im Kampagnenhost; Flora separat maximal 25 Patches |
| Navigation | Maximal 128 Zellen und kooperativ 2 ms pro Scheibe |
| Fernsimulation | Maximal 32 Aufträge und kooperativ 2 ms pro Aufruf |

Die Werte sind bestehende Implementierungsgrenzen, keine neue Aufteilung des 16,67-ms-Ziels. Einzelne Aufgaben und Betriebssystemunterbrechungen können kooperative Zeitbudgets überschreiten. Diese Lieferung erhöht keine Grenze.

## Nachweise und nächste Anschlüsse

Die konkreten Abschlusswerte und getesteten Commits stehen in `ARCH02_MEASUREMENTS_2026-09-10.md` und `docs/evidence/arch02/`. Die CI führt den kurzen Kugelablauf, Speicherfälle, Messstatistik und CLI-Schutzprüfungen aus. Eine unabhängige Grafikmessung oder Windows-/Paket-FPS-Abnahme ist damit nicht verbunden.

Für ARCH-13 sind Dirty-Commit-Spitzen, Wachstum von Manifest/Blobs und weiterhin pro Store geltende Caches maßgeblich. ARCH-17 bekommt Terrain-/Upload-/Queue-Spitzen und die Zeitreihe tatsächlicher Terrainwartezeiten. Weitere Abnahmen: zehnminütige Route auf festgelegtem Ziel-PC; entwickeltes Dorf mit Arbeit/Fracht; A–B–A mit längerem Fernbetrieb. Dafür vorhandene `body_travel_test`-/`spherical_gameplay_test`-Abläufe als nächste Rezepte anschließen, deren Fachregeln nicht neu implementieren. Roadmap-Integration darf ARCH-02 erst mit diesen Grenzen und zugehörigen Nachweisen entsprechend teilweise markieren.
