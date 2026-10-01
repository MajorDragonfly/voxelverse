# PT17-01 · Bewegungsruckler messen

## Befund auf der festen Basis

Die Kugelkampagne wurde auf Basis `0e0a1cda0d645f872cecd42881b3f6e53b3ba34e`
mit Godot 4.6.3, Seed 15838 und einer echten physischen Hin-/Rückroute
(je 15 Sekunden hinaus, zwei Ladezyklen) in einer Linux-Headless-Umgebung gemessen.
Der erste Versuch im frischen Checkout war ungültig: fehlende Godot-Importe
blockierten den Weltstart. Der Profilrunner importiert Assets nun vor der Messung,
wenn der Importcache fehlt.

| Route | Frames | p50 | p95 | p99 | >33 ms | >50 ms | >100 ms |
|---|---:|---:|---:|---:|---:|---:|---:|
| Erster Hinweg | 673 | 16,6 ms | 40,5 ms | 229,8 ms | 44 | 31 | 18 |
| Erster Rückweg | 831 | 16,5 ms | 25,5 ms | 35,4 ms | 13 | 2 | 1 |
| Nach Laden, Hinweg | 718 | 16,6 ms | 33,8 ms | 203,8 ms | 37 | 17 | 8 |
| Nach Laden, Rückweg | 736 | 16,6 ms | 26,9 ms | 56,0 ms | 20 | 8 | 3 |

Die Terrain-Upload-/Publikationsmaxima lagen beim ersten Lauf bei 7,3/6,1 ms,
die Populationsarbeit bei 241,7 ms. Eine zweite Messung mit gleichem isoliertem
Startspielstand zeigte Spawn-Maxima von 176,4/187,5 ms. Die zusätzliche
Phasenmessung ergab bei der Aktivierung eines Kreaturen-Nodes 228,0/183,3 ms;
Positionierung und Konfiguration lagen jeweils unter 1 ms. Die Maxima sind
Szenenlaufzeitwerte und keine Behauptung, dass sie im selben Frame wie ein
bestimmtes Rohsample auftraten. Sie grenzen den nächsten Optimierungsschritt auf
den Laufzeit-Körperaufbau beim `add_child(actor)` ein.

## Begrenzte Laufzeitkorrektur

Die Tier-Vorschau baute beim Einhängen in die Szene zuerst einen Standardkörper
und danach den gespeicherten Körper. Der Spawner setzt nun den vorhandenen
Blueprint vor `_ready()`. Damit entsteht nur der gespeicherte Körper; ein
Regressionstest prüft Anzahl, Geometrie und Farben. Im Voxelkörper werden
unveränderliche Farbwerte einmal statt für jede Zelle aus dem Blueprint gelesen;
drei generierte Körper hatten vor und nach dieser Änderung identische Mesh-Arrays
und belegte Voxel.

Ein kurzer Headless-Vergleich mit gleichem Rezept und Replay zeigte beim
Tier-Aktivierungsmaximum im ersten Zyklus 215,7 → 182,5 ms, nach Laden
176,9 → 99,9 ms. Der geladene Hinweg hatte p99 204,2 → 134,8 ms und
13 → 10 Frames über 100 ms. Der erste Hinweg blieb uneinheitlich:
p95 47,6 → 54,6 ms und 20 → 24 Frames über 100 ms, obwohl p99
242,1 → 219,3 ms sank. Die kurzen Softwareläufe schwanken; daraus folgt
keine allgemeine Leistungsfreigabe. Eine weitere Phasenmessung fand bis zu
95,7 ms bei der erstmaligen Regionsgenerierung und 38,0 ms für Nester.

PT17-10 besitzt die aktuelle Laufzeitpose und Artikulation. Diese Änderung
bleibt im Spawner und in der unveränderten Geometrieerzeugung; die gemeinsame
Animation muss nach der Integration geprüft werden. Sichtweite,
Kreaturenanzahl, Kollision und Speicherdaten bleiben gleich. PT17-01 bleibt
offen für die 10-Minuten-Messung und Vorher/Nachher-Abnahme auf dem Ziel-PC.

## Wiederholbarer Windows-Lauf

Godot 4.6.3 und Python 3 verwenden. Im Repository ausführen; das Ausgabeverzeichnis
muss außerhalb des Checkouts liegen. Der Runner importiert Assets bei einem
frischen Checkout automatisch. Voreinstellung: Seed 15838, 60 FPS und 1080p.

```powershell
python tools/profile_performance.py --godot C:\Pfad\Godot_v4.6.3-stable_win64_console.exe --mode route --renderer forward_plus --walk-seconds 600 --cycles 2 --output C:\Voxelverse-Messungen\vorher
```

`performance.json` enthält Quellstand, Hardware/Renderer, Startadresse,
Szenenzähler und Grenzen. `frames.csv` enthält alle Framezeiten; `summary.md`
und `route-summary.json` trennen ersten/geladenen Hin- und Rückweg mit
p50/p95/p99/Maximum und Häufigkeiten über 33/50/100 ms. Bei einem späteren
optimierten Build denselben Seed, Auflösung, Preset, Treiber und PC verwenden:

```powershell
python tools/profile_performance.py --godot C:\Pfad\Godot_v4.6.3-stable_win64_console.exe --mode route --renderer forward_plus --walk-seconds 600 --cycles 2 --replay C:\Voxelverse-Messungen\vorher --compare C:\Voxelverse-Messungen\vorher --output C:\Voxelverse-Messungen\nachher
```

Der Vergleich verlangt gleiches Rezept, Gerät/Renderer, Planet und nahezu
identische Startadresse. Rohdaten, Szene, RAM/VRAM, Treiber, echte Route und
Bildqualität gemeinsam prüfen; ein Headless- oder Softwarewert belegt keine
60-FPS-Freigabe auf Lars' Referenz-PC.
