# ARCH-15 – Begrenzte Momentaufnahmen für Dorfarbeit

## Umfang

Dieses Teilpaket senkt den Kopieraufwand der synchronen Fortschrittsbeobachtung nach Ankunft eines Bewohners. Nah- und Fernsimulation übergeben dessen Kennung an den gemeinsamen Arbeitskern. Die Spielregeln, Zeitbudgets, Speicherformate und Fortschrittsbeobachter bleiben identisch.

- Ausgangspunkt: `main` bei `ea900f2e09946660694a9e59399b4680a5655a85` (PR #48).
- Branch: `agent/arch15-work-observation-2026-09-10`.
- Geprüfter Code einschließlich Test und Messprogramm: lokal `2ac8c509c69289ee0109d73225cf29aa32b26d5b`, veröffentlicht als `3e20839dabc1f5d3dfc051a58599997b846a01be`. Beide haben exakt den vollständigen Git-Baum `bc9c4071a964af47331722de56a754232b84b6fc`; die späteren Nachweisdateien ändern keinen Laufzeitcode.
- Eigener Bereich: `village_work.gd::snapshot` und seine beiden Aufrufe in `tribe_controller.gd` / `village_simulation.gd`.

Der noch offene ARCH-15-Punkt ist damit teilweise umgesetzt. Die vollständigen Rücksetzstände für Benutzerbefehle, Tierbindung, Produktionsabschlüsse und gespeicherte Besitzerwechsel bleiben bestehen. Weitere Umstellung auf gezielte Transaktionen braucht eine eigene Prüfung der Speicherfehler- und Rücksetzpfade.

## Vertrag der Momentaufnahme

`Work.snapshot(village, actor_id)` liefert weiterhin ein vollständiges Dorf-Dictionary. Es dient genau einem synchronen, bereits angekommenen Arbeitsschritt einschließlich Pflege-/Nachbareffekten und der direkt anschließenden Fortschrittsbeobachtung. Es darf weder über einen weiteren Tick gehalten noch als allgemeiner Rücksetzstand verwendet werden. Die Beobachter lesen ausschließlich.

| Daten | Kopie | Grund |
|---|---|---|
| Dorfwurzel, Vorräte | flach | Zähler und Bestände ändern sich direkt |
| Bewohnerliste | Liste und handelnder Bewohner | Arbeit, Fracht, Bedürfnisse und Auftrag ändern sich am Handelnden |
| Bewohner bei aktivem Bauprojekt | alle Bewohner-Dictionaries | Bauabschluss setzt weitere Bauarbeiter zurück; ferne neue Hindernisse sperren alle Bewohner bis zur Wegprüfung |
| Fehlende/unbekannte Bewohnerkennung | alle Bewohner-Dictionaries | konservativer Aufruf ohne bekannte Zuordnung |
| Rohstoffquellen | äußeres Dictionary und jede Quelle | Mengen ändern sich; fertige Arbeitsplätze ersetzen Quellenpositionen |
| Bauprojekt | tief | reservierte und angelieferte Materialien sind verschachtelt |
| Wohnraum | äußeres Dictionary und Häuserliste | Bauabschluss hängt ein Haus an |
| Tierhaltung | äußeres Dictionary, Tierplatzliste, Tierplätze, Entnahme-/Rückgabe-/Liefermengen | Pflege bewegt Fracht und Futter zwischen Lager, Bewohner und Tierplatz |
| Wirtschaft | äußeres Dictionary, Eingangsliste mit jeder Zeile, Arbeitsplatz-Dictionary | Milchabholung verändert/entfernt Zeilen; Bau ersetzt einen Arbeitsplatz |

Koordinatencontainer werden während dieses Arbeitsschritts nur gelesen oder durch neue ersetzt. Bestehende Häuser und Arbeitsplatzdaten werden nicht in-place verändert. Produktionsnachweise, Rezepte, Verbrauchs- und Produktionsuhren werden im getrennten Produktionstick geändert. Dieser liegt außerhalb der Beobachtung; seine vorhandene Absicherung bleibt bestehen. Dadurch wächst diese Kopie nicht länger mit der historischen D3-Nachweisliste.

Wird der Arbeitskern um neue verschachtelte Mutationen erweitert, müssen Kopierumfang und Vergleichstest gemeinsam angepasst werden. Das gilt insbesondere bei der späteren Integration des Ressourcenpakets ARCH-20. Eine allgemeine Schreibschutz- oder Transaktionsbibliothek wird hier nicht eingeführt.

## Nachweise

`tests/village_work_observation_test.gd` prüft 142 Schritte. Vor jedem Schritt entsteht unabhängig eine vollständige tiefe Referenzkopie. Nach dem echten Arbeitsschritt muss die begrenzte Momentaufnahme exakt dem ursprünglichen vollständigen Zustand entsprechen. Beide Varianten laufen durch den echten Dorfvalidator und Fortschrittsbeobachter; gespeicherte Belege und Belohnungen müssen übereinstimmen. Wiederholung derselben Beobachtung darf den Fortschritt nicht verändern.

Abgedeckt sind Holz, Stein, Nahrung, Wasser und Fasern bei Arbeitsraten 1/2/4, Versorgung, Bewegung, Warte-/Essens-/Trinkzustände, Milchabholung mit verbleibender oder entfernter Eingangszeile, Lieferung und Mahlzeit, Neuladen eines Belegs während des Transports sowie alle neun Bauarten. Werkzeug, Hütte und Garten müssen ihre tatsächliche Gemeinschaftsbelohnung erhalten. Pflege prüft die Lieferung und Rückgabe von je einer Einheit. Nachbartransport und ein wirklicher Fernsimulations-Bauabschluss einschließlich aller Wegsperren sind enthalten.

Zusätzlich laufen die vorhandenen `far_simulation_test` und `tribal_economy_progress_test`. Sie prüfen unter anderem Mengenbilanz, blockierte Fracht, genau einen Simulationsbesitzer, Pause, Laden und einen frischen Prozess sowie die bestehenden Berufs- und Versorgungsbelege.

Die vollständigen Testergebnisse stehen in `ARCH15_WORK_SNAPSHOT_VALIDATION.json`. Der erste Kugelwelt-Lauf brach nach funktionierendem Holztransport, Pause, Wiederladen und Arbeitsplatzbau mit `No live D1 milk animal` ab (146,359 s). Ein Kontrolllauf auf dem unveränderten Ausgangscommit bestand vollständig (334,595 s). Der erste Abbruch ist damit noch nicht ursächlich erklärt; er bleibt im Prüfbericht sichtbar. Die Wiederholung auf dem unveränderten neuen Code bestand vollständig (334,636 s), einschließlich der Milchtransportkette und eines frischen Prozesses. Es gab dabei keine vom strikten Läufer erkannten Skript-, Engine- oder Leckfehler. Der erste Abbruch wird nicht als durch ARCH-15 behoben ausgegeben.

## Messung

`tools/benchmark_village_work_snapshot.gd` vergleicht die unveränderte bisherige `snapshot`-Implementierung aus dem Ausgangscommit mit der neuen Funktion auf validierten Dorfständen. Je Variante: 200 Aufwärmkopien, danach 15 abwechselnd angeordnete Messpaare mit je 500 Kopien. Gemessen werden Erstellung und Freigabe der Momentaufnahme. Die Rohwerte stehen in `ARCH15_WORK_SNAPSHOT_MEASUREMENTS.json`.

| Bewohner | D3-Nachweise | Fall | Kopierte Container vorher → jetzt | Median µs vorher → jetzt |
|---:|---:|---|---:|---:|
| 3 | 0 | normale Arbeit | 47 → 22 | 18,166 → 15,902 |
| 3 | 8 | normale Arbeit | 79 → 22 | 32,932 → 16,164 |
| 3 | 32 | normale Arbeit | 175 → 22 | 79,120 → 17,852 |
| 6 | 0 | normale Arbeit | 65 → 22 | 33,018 → 19,630 |
| 6 | 8 | normale Arbeit | 97 → 22 | 40,508 → 17,180 |
| 6 | 32 | normale Arbeit | 193 → 22 | 87,824 → 16,410 |
| 6 | 32 | Bauprojekt | 197 → 31 | 83,458 → 25,970 |
| 6 | 32 | 48 Milch-Eingangszeilen | 289 → 70 | 139,600 → 59,068 |

Containerzahlen zählen neue, vom Ergebnis erreichbare Dictionary-/Array-Instanzen anhand ihrer Identität. Temporäre Hilfsarrays sind ausgenommen; dies ist keine Messung des Allokators oder des gesamten Prozessspeichers. Die Zeitwerte stammen aus einem gemeinsam genutzten Linux-Container mit Godot 4.6.3. Sie belegen den lokalen Kopieraufwand und sind keine FPS-, GPU- oder Ziel-PC-Abnahme.

## Wiederholen und integrieren

```sh
python tools/validate_godot.py --godot /path/to/Godot_v4.6.3-stable_linux.x86_64 --project . --output /tmp/arch15-validation --tests village_work_snapshot_test far_simulation_test tribal_economy_progress_test spherical_gameplay_test --skip-main
```

Das Messprogramm benötigt dieselbe importierte Godot-Projektbasis:

```sh
godot --headless --path . --script res://tools/benchmark_village_work_snapshot.gd -- --report /tmp/arch15-measurements.json
```

Die durchgeführten Läufe nutzten die bestehende Isolation aus `tools/validation_support.py`, einschließlich eines Editors ohne Self-contained-Marker und eigener Benutzerdatenverzeichnisse. Die bestehende Testsuche auf dieser Basis findet den neuen `*_test.gd` automatisch. Falls ARCH-29 bei Integration eine ausdrückliche Testregistrierung einführt, muss dieser Test dort ergänzt werden.

Andere offene Pakete sind keine Abhängigkeiten dieses Branches. Die globale Roadmap bleibt beim Integrationspaket. Vor dem gemeinsamen Merge sind die Änderungen in den geteilten Dorfdateien und die aktualisierten Arbeitsregeln zusammen zu prüfen.

## Gemeinsame Integration vom 10. September

Die Laufzeit verwendet den gezielten `snapshot(data, member)`-Anschluss aus PR #73. Die ergänzenden Vergleichsfälle dieses Pakets bleiben als `village_work_observation_test` erhalten; die Messhilfe verwendet denselben gemeinsamen Anschluss. Die oben dokumentierten Rohwerte beziehen sich weiterhin auf den ursprünglichen Fachbranch.
