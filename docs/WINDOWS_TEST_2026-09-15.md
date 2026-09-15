# Voxelverse – Spieltest vom 15. September 2026

Der gemeinsame Testbranch enthält die Lieferungen #78–89. Als Download wird ausschließlich das ZIP des erfolgreichen Windows-Jobs im Workflow **Desktop export validation** für diesen Quellcommit verwendet. Die native Prüfung startet das exportierte Spiel außerhalb des Projektverzeichnisses und prüft Menüs, Slots, Kugelstart, echte Milch-/Eierproduktion, Transporte, Körperreisen, Neustarts und das gepackte Spielarchiv. Lauf, Quellcommit und SHA-256 identifizieren den Build.

## Start

1. Das Windows-ZIP vollständig in einen neuen Ordner entpacken.
2. `voxelverse.exe` starten; `voxelverse.pck` muss daneben liegen. Godot muss nicht installiert werden.
3. Zuerst einen neuen Slot anlegen. Vorhandene Spielstände für Vergleichstests zusätzlich sichern.

## Testablauf

| Reihenfolge | Prüfen |
|---|---|
| 1 | Neues Spiel: sichtbare Pflanzen und Tiere, Boden, Wasser, Kamera und Eingaben |
| 2 | Mehrere Minuten laufen; Hügel/Kanten überqueren, umdrehen und zum Start zurückkehren |
| 3 | Tier scannen; Entdeckungsbuch öffnen, blättern und Details ansehen; Fähigkeiten und DE/EN prüfen |
| 4 | Kreatureneditor: freigeschaltete Mundformen, Vorschau, Speichern und Rückkehr ins Spiel |
| 5 | Speichern, Anwendung beenden und denselben Slot laden: Position, Heimat, Entdeckungen und Entwurf vergleichen |
| 6 | Stammesaufstieg ausdrücklich bestätigen; geeignetes Tier zähmen und versorgen |
| 7 | Milch/Eier produzieren, einsammeln, tragen und einlagern; während laufender Fracht speichern und neu starten |

`F4` öffnet das zusätzliche Planetenlabor; der normale Spielstart erfolgt über die Kampagne. Die neuen Siedlungs-/Transportmodelle sind technische Grundlagen und schalten noch keine Siedlungsgründung frei.

Bei Fehlern bitte Build-Commit, Slot/Seed, letzte Aktion und ein Bild oder kurzes Video festhalten. Protokoll: `%APPDATA%\Godot\app_userdata\Voxelverse\logs\godot.log` (bei abweichendem Projektnamen im entsprechenden Unterordner).

Der Spieltest dient besonders der visuellen Beurteilung und Leistung auf dem eigenen PC. Eine bestandene automatische Prüfung ist keine bestätigte 60-FPS-Zusage.
