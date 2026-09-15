# Windows-Testkandidat vom 11. September 2026

## Enthaltener Stand

PR #84 vereinigt die sechs Fachlieferungen #78–#83. Der korrigierte Spielcode
ist in `f9488ae5eabe18e8f44c57cb252e4c53f5efba80` enthalten. Die Korrekturen
betreffen den Erhalt eingefrorener Tierkörper beim präzisen JSON-Schreiben,
die Validierung des tatsächlich lesbaren Saves vor dem Ersetzen und die
radiale Kapsel-Stufenprüfung. Schema- und Originalschutz bleiben aktiv.

Der Korrekturlauf [34589316437](https://github.com/MajorDragonfly/voxelverse/actions/runs/34589316437)
bestand 17 gezielte Godot-Tests, Import, Artquellen und Vertragsgate; D1, D1.1
und D1.2 bestanden je einen getrennten Schreib- und Leseprozess. Die
Ergebnisübersicht liegt unter `evidence/integration-2026-09-11/` und benennt
Quellcommit, vollständigen Prüfumfang und Herkunft des Artefakts.

Die beiden einmaligen Integrations-/Korrekturworkflows sind nach ihrem
Abschluss entfernt. Ihre ausgeführten Quellen bleiben in der Git-Historie.
Die regulären Prüfgates und Exportworkflows bleiben unverändert aktiv.

## Freigabekriterium für die Windows-Testausgabe

Der Desktop-Exportworkflow muss auf genau diesem Kandidaten den Windows-
Export und die verpackten Start-, Speicher-, Kugel-, Tier-/Frachtreise- und
PCK-Prüfungen erfolgreich abschließen. Nur sein akzeptiertes ZIP gilt als
Testausgabe; ein erzeugtes EXE ohne bestandene Prüfung genügt nicht. Der
GitHub-Lauf samt Commit und ZIP-Prüfsumme identifiziert die konkrete Ausgabe.
Eine Quellenprüfung ersetzt keine native Windows-Ausführung.

Zum Zeitpunkt dieses Dokuments stehen die vollständige gemeinsame Suite
und die native Ausgabe noch aus. Ihre tatsächlichen Ergebnisse werden
beim Abschluss in PR #84 dokumentiert; hier werden keine geplanten Läufe
als bestanden gewertet. Eine Testausgabe ist keine allgemeine Release-
oder 60-FPS-Freigabe auf Lars' PC.

## Empfohlener manueller Durchtest

1. ZIP vollständig in einen neuen Ordner entpacken; `voxelverse.exe` und
   `voxelverse.pck` zusammenlassen. Zuerst einen neuen Spielslot verwenden.
2. Kugelkampagne: Pflanzen/Tiere, Wasser, Laufen über Kanten, längeren Hin-
   und Rückweg sowie Kameraführung prüfen. F4 ist das Diagnose-Planetenlabor,
   nicht der normale Kampagneneinstieg.
3. Speichern, Anwendung schließen und denselben Slot erneut laden. Position,
   Heimat, Entdeckungen und Kreaturenentwurf kontrollieren.
4. Fähigkeiten und Entdeckungsbuch öffnen; DE/EN wechseln; neue Mundformen
   im Editor nach vorhandener Freischaltung prüfen.
5. Den Stammesaufstieg ausdrücklich bestätigen. Tiere versorgen und Milch/
   Eier über die bestehenden Aufträge sammeln, tragen, einlagern und nutzen.
   Auch mit laufender Fracht speichern und neu starten.

Alte Spielstände vor dem Test zusätzlich sichern. Bei einem Fehler Build-
Commit, Seed/Slot, letzte Aktion und nach Möglichkeit Bildschirmaufnahme
sowie Godot-Protokoll notieren. Keine originalen Spielstände löschen.

## Bewusst offene Grenzen

Lange Reisen auf definierter Zielhardware, 1080p60, alle Pflanzen-/Biome-
Sichtbarkeitsfälle und vollständige grafische Spielabnahme bleiben eigene
Nachweise. Mehrere eigene Siedlungen, spätere Epochen und spielbarer
Schiffsflug sind nicht durch diesen Integrationsabschluss freigeschaltet.
