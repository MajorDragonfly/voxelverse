# Kreatur vom Editor ins Spiel

Stand: 8. September 2026. Die geplante Überarbeitung ist in [ROADMAP.md](../../ROADMAP.md) beschrieben.

Die Szene `creatures/editor/creature_editor.tscn` nutzt den Runtime-Editor auf Basis von V7. `CreatureAssemblyBlueprintV7` speichert den aktuellen Entwurf unter `user://creature_assembly_v7.json` und kann ältere V5-/Basisdateien als Migrationseingang lesen. Ein Genom-/Mutationssystem ist nicht Teil des aktiven Ablaufs.

`creature_runtime_visual.gd` lädt denselben Entwurf, normalisiert die Teilbindungen und erzeugt daraus das Spielmodell. Es überträgt bereits mehrere Körperwerte auf den Spieler. Das bedeutet noch nicht, dass jeder im Editor angezeigte Wert eine vollständige Fähigkeit besitzt; diese Verbindung ist ein Ziel von M3 der Roadmap.

F2 führt aus dem Spiel zurück in den Kreatureneditor. Bearbeitung, Speichern, Wiedereintritt und Animation müssen bei weiteren Änderungen erhalten bleiben. Der aktuelle Spieler verwendet `player_controller_v2.gd`, die Laufzeitanimation `adaptive_locomotion_animator_v2.gd`.

Die aktuelle Bauplan-Datei enthält zusätzlich einen eingebetteten Fortschrittsbereich. M0/M2 der Roadmap trennen dessen Zuständigkeit klar von der dauerhaften Kampagnenphase und dem neuen Verhaltens-Skilltree, damit spätere Phasen und alte Entwürfe nicht widersprüchlich gespeichert werden.
