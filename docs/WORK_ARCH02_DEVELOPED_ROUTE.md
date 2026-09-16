# ARCH-02-DEVELOPED: Dorf, Tierhaltung, Fracht und Reise messen

Basis: `d378ca0ecd7f03429a5150df6358e0646ec06689` (gemeinsames `main` nach #92).
Branch: `agent/arch02-developed-route-20260915`. Fachpaket aus ARCH-02 / M1h / M10.
ARCH-24, -25, -26 und -30 sind parallel belegt und werden hier nicht bearbeitet.

## Lieferung

`tools/profile_performance.py --mode developed` instrumentiert den vorhandenen
`spherical_gameplay_probe`. Es entsteht keine zweite Spiel-/Produktionssimulation.
Der Ablauf nutzt die reguläre Kugelkampagne und die bestehenden Prüfungen für:

- Heimat und bestätigten Stammesübergang; physisch gesammelte Holzfracht;
- Werkzeuge, Brunnen, Faserbeet, lebendes D1-Tier, Annäherung/Zähmung und Haltung;
- Versorgung und echte Milch- bzw. Eierproduktion, beladener und blockierter Träger;
- fehlgeschlagenen Abreisesave, A–B–A mit gleichem Weltseed in verschiedenen Systemen;
- Fernproduktion, Pause, exklusive Simulationszuständigkeit und Rückkehr desselben Tiers;
- frischen Prozess auf B und nach Rückkehr auf A; abschließende reale Einlagerung
  sowie bei Eiern den bestehenden Mahlzeitenauftrag.

Die Fachassertionen bleiben verbindlich. Ein vollständiger Bericht benötigt alle
Abschnitte und **zwei erfolgreiche gemessene Kindprozesse je Zyklus**. Fehlende,
doppelte, fremde oder fehlgeschlagene Neustartnachweise werden abgelehnt.

## Aufruf

Nach dem normalen Godot-Import, mit Godot 4.6.3 und einem neuen Ausgabeordner
außerhalb des Quellprojekts:

```sh
python tools/profile_performance.py --godot /pfad/zu/godot --mode developed --output ../messung-milch
python tools/profile_performance.py --godot /pfad/zu/godot --mode developed --production eggs --output ../messung-eier
python tools/profile_performance.py --godot /pfad/zu/godot --mode developed --renderer forward_plus --size 1920 1080 --output ../messung-grafik
python tools/profile_performance.py --godot /pfad/zu/godot --mode developed --compare ../messung-milch --output ../messung-vergleich
```

Das entwickelte Profil hat standardmäßig einen vollständigen Zyklus, optional
`--cycles 1..3`. Der vorhandene Fachablauf verwendet Seed 15838 und das zweite
System 23757. Andere Seeds und `--replay` werden für dieses Profil abgelehnt.
Die Lauf-/Save-Profile behalten ihr Protokoll 2 und bisherige Standardwerte.
Parameter für Gehdauer und Beruhigungsframes gehören nur zum Laufprofil; sie
stehen nicht im entwickelten Messrezept. Ein Zyklus darf bis zu 1.000 Sekunden
benötigen. Ein Timeout beendet unter Linux/Windows auch laufende Kindprozesse.

## Berichte und Bedeutung

| Datei | Inhalt |
|---|---|
| `summary.md` | Lesbare Abschnittstabelle mit Wandzeit, Frame-Median/p95/p99 und verfügbarem GPU-p95; optional Differenz zu einer kompatiblen Ausgangsmessung. |
| `frames.csv`, `cycle_*-frames.csv` | Getrennte Rohframes je Prozess mit Zyklus, Abschnitt, Pause, tatsächlichem Simulationstempo und Frame-Cap. |
| `capture.json`, `cycle_*-capture.json` | Engine/CPU/Renderer, Quellcommit/Tree/Änderungshashes, Abschnitte und einmal pro Sekunde Objekt-, Terrain-, Dorf-, Vorrats-, Fracht- und Speicherdaten. |
| `engine.log`, `cycle_*-engine.log` | Eigene Logs für Hauptprozess und beide Neustarts; unveränderte Fachfehler bleiben sichtbar. |
| `performance.json`, `process-memory.json` | Zusammenfassung einschließlich validierter Kindberichte und getrennten Prozess-RAM-Proben. Die größte Einzelprozessspitze ist keine gemeinsame RAM-Spitze. |
| `fixture/` | Erhaltene isolierte Benutzerdateien einschließlich Slots, Produktionscheckpoints und referenzierter Regionsarchive. |

Kindprozesse werden synchron geprüft. Ihre gesamte Wandzeit steht separat im
Bericht; die Wartezeit geht nicht als einzelner Riesenframe in die
Frame-Perzentile des Elternprozesses ein. Der erste Frame nach einer
Abschnittsgrenze wird nicht als vollständiges Frameintervall ausgegeben;
die gesamte Abschnittswandzeit bleibt erhalten. Berichts- und Sortierkosten
liegen außerhalb dieser Wandzeiten, laufende Aufzeichnungskosten in den Frames.
GPU-Zeitstempel ohne Messwert bleiben `null`, auch bei einem gemessenen Nullwert
anderer Instrumente. Linux-RSS stammt aus dem jeweiligen Godot-Prozess.

Vergleiche benötigen ein bestandenes Ausgangsergebnis mit gleichem Rezept,
Godot und derselben gemeldeten Hardware. Abweichende Rezepte oder Geräte werden
nicht still gegenübergestellt. Neue Kampagnen erhalten neue IDs; Scheduling,
OS-Cache und Last können variieren. Einzelmessungen beweisen keine statistisch
gesicherte Verbesserung. Die Aufzeichnung ersetzt keine identische Save-Wiedergabe.

## Zuständigkeiten und Grenzen

Schreibbereich: Messwerkzeuge, zwei Python-Fachtests, bestehender Messworkflow
und drei Diagnosehelfer. Die Diagnosehelfer bekommen Abschnittsmarken und einen
überschreibbaren Kindprozessaufruf; ihr regulärer Prüfweg verwendet weiter
`OS.execute`. Spielzustand, zentraler Writer, Dorfcontroller, UI, Kataloge,
Speicherschema und gemeinsame Statusseiten bleiben bei ihren Fachbesitzern.
Keine zusätzliche Godot-Testdatei: die vorhandene Prüfstrecke wird instrumentiert;
`performance_measurement_test` bleibt genau einmal registriert.

Der bestehende Diagnoseaufbau verwendet einen mengenmäßig ausgeglichenen
Startvorrat, 4× Simulation und für offene Fernsimulationszeit zeitweise 2 FPS.
Diese Einstellungen werden ausgewiesen; der 2-FPS-Abschnitt ist getrennt.
Dies ist ein entwickeltes Diagnoseprofil, keine normale Echtzeitmessung.
`target_pc_acceptance` und `full_walk_protocol` bleiben `false`.
Keine zehnminütige Laufroute, Mehrsiedlungs- oder Windows-/Ziel-PC-Abnahme.
Die komplette ARCH-02-Abnahme bleibt offen.

Im bestehenden Performance-Workflow lässt sich die lange Messung ausdrücklich
per `workflow_dispatch` mit `developed: milk` oder `eggs` starten. Sie wird nicht
zusätzlich zu jedem allgemeinen Fachlauf automatisch wiederholt.

Prüfstand, Befehle, Ergebnisse und verbleibende Grenzen:
`docs/evidence/arch02-developed/results.json` (wird bei Übergabe ergänzt).
