# Zweite Integration: gemeinsamer Stand und Kugelumzug

Stand: 9. September 2026. Basis `3a3e0272375e556f3ff65b7370582af79a9d48b5`. Die vollständigen Quell- und Baumkennungen stehen in [integration-spherical-sources-2026-09-09.json](integration-spherical-sources-2026-09-09.json). Historische Einzelberichte behalten ihre damaligen Grenzen; dieses Dokument beschreibt den gemeinsamen Folgeaufbau.

## Übernommene Entwicklungsstränge

| Bereich | Übernommener Abschluss |
|---|---|
| M1d: radialer Adapter, belebte Kugeln, Boden und Wasser | `a18536c` |
| B1 → B2 → B3: Körperanschlüsse, Passprüfung, Sattelauflage/Reitermaße | `e34574a` |
| D1 → D1.1 → D1.2: Pflichtarten, Körpernachweise, planare/radiale Habitate | `a629fce` |
| D2: echte Kampagnenzähmung, Betreuer, Besitz, Befehle, gemeinsamer Save | `38d6177` |
| Dorfwirtschaft → feste Häuser/Wachstum → D3 Pflege/Milchtransport | `b2a7432` |
| Stammesfortschritt und Nachbarhilfe | `25c1b77` |
| Gemeinsames Tierbuch sowie Gruppen-/Tierklang und Rückmeldung | `7d6a5be` |
| Bereinigung, Leistungsdiagnose, Export-/Audiolebenszyklus | `4dd9c7ad` |
| Buch-/Skill-/HUD-Gestaltung, Mini- und dauerhafte Weltkarte | `e349a24` |
| Sprachverwaltung Deutsch/Englisch mit gespeichertem Menü | `691d2e5` |

Die Quellhistorien wurden durch echte Merge-Commits erhalten. Bei doppelten D1-/D1.1-/D1.2-Veröffentlichungen wurden identische Bäume und Abhängigkeiten abgeglichen. Ältere eingebettete D1-Dateien aus D2 ersetzen nicht die neueren D1.1-/D1.2-Verträge. Unfertige, uncommittete Zwischenstände anderer Arbeitsverzeichnisse sind kein Bestandteil dieser Integration.

## Behobene gemeinsame Fehler

- **Speicherung:** D1-Kataloge, D2-Tierbestände, D3-/Dorfzustände, Nachbarn, Fortschritt und Erkundungsatlas werden gemeinsam validiert. Sämtliche Schutzprüfungen für unbekannte neuere Unterverträge bleiben erhalten.
- **D2 → D3:** Die Dorfhaltung liest jetzt direkt den tatsächlichen D2-Bestand, seine D1-Eignung und denselben Tier-Actor. Der Zugriff wird nach Kampagnenladen wiederhergestellt; es entsteht kein zweiter Tierbestand. Die explizite D3-Prüfszene darf weiterhin ihre isolierten Quellen anschließen.
- **Dorfbewegung:** Haus-/Eingangshindernisse, Nachbarraster und D2-Reichweite verwenden denselben Navigationsaufruf. Fracht, Versorgung, Wachstum, Tierhaltung und Nachbararbeit bleiben im gemeinsamen Simulationstakt. Die frühere doppelte Radiusdeklaration ist entfernt.
- **Fortschritt mit Wachstum:** Wirtschaftsnachweise akzeptieren die vorhandenen Dorfversionen 3–5. Neu hinzugekommene, validierte Bewohner werden in den gemeinsamen Arbeitsnachweis aufgenommen. Nachbarvertrag 2 erlaubt bis zu sechs eigene Träger; Vertrag 1 bleibt lesbar und wird beim nächsten Hilfsauftrag ausdrücklich angehoben.
- **Bedienung:** Aufträge, Berufe, Tierhaltung, Nachbarn und Zähmung nutzen die vorhandenen scrollbaren Dorfreiter. Auswahlfehler und fehlendes Werkzeug melden echte Ablehnung. Rückmeldung, Einklappen, kleine Fenster und Pause greifen ineinander. Ein entferntes Hüttenmodell für die Nachbarn wurde wieder angeschlossen.
- **Buch und Gestaltung:** Neue Körperteilvorschauen/Silhouetten bleiben mit D1-Eignung, D2-Tierregister und dem kompakten Buch kompatibel. Zwei konkurrierende Größenberechnungen und doppelte Memberdeklarationen sind zusammengeführt.
- **Karten auf belebten Kugeln:** Dieselben Mini-/Weltkarten lesen die tatsächliche Walker-Adresse und Oberflächenquelle. `M` öffnet dort die Karte, `P` wechselt den Referenzplaneten. Erkundung bleibt beim Wechsel und Neustart erhalten; Zoomen deckt keine unbekannten Regionen auf.
- **Versionierter Kugelspeicher:** Neuer Header 3 für Karten, bestehender D1.2-Inhalt unverändert. Alte Header 1/2 werden weiter gelesen und erst beim regulären Sichern angehoben. Unbekannte neue Atlasversionen sperren auch einen Rückfall auf ein älteres Backup. Vor-Karten-Builds erkennen Header 3 als unbekannt statt Kartendaten wegzuspeichern.
- **Prüfinfrastruktur:** Reale 300-Sekunden-Milchzyklen sowie Wachstum/Wirtschaft erhalten gezielt längere Testfristen. Der vollständige CI-Job erhält Zeit für den gewachsenen Prüfumfang. Echte UI-Ereignisse rechnen Canvas-Transformationen ein; die Headless-Menüprobe benutzt ein unterstütztes 1280×720-Fenster statt des 64×64-Engineplatzhalters.

## Prüfstand

Die abschließende gemeinsame Quellprüfung und native Linux-Paketprüfung laufen. Bereits geprüft sind unter anderem Körper-/Sitzverträge, Zähmung mit D3-Leseanschluss, Tierhaltung samt echtem Neustart, wirtschaftliche Fortschrittsnachweise, UI/Bücher, Karten und radiale Landschaft. Der endgültige Ergebnisstand wird vor der Übernahme hier eingetragen. Einzelbranch-Nachweise werden nicht als gemeinsame Abnahme ausgegeben.

## Verbindliche nächste Priorität

Der [Kugel-Migrationsauftrag](SPHERICAL_CAMPAIGN_MIGRATION.md) ersetzt weitere Ausbauten der Flachwelt als Entwicklungsrichtung. Die dazugehörigen [Folgeaufträge](NEXT_PARALLEL_WORK.md) beginnen mit Kampagnenorten und atomarer Speicherung, danach Kreaturenphase und Stamm/Tierhaltung, anschließend Nah-/Fernsimulation und belastbaren Budgets. Die gemeinsame [Designvorgabe](VOXELVERSE_DESIGN.md) liegt nun am kanonischen Projektpfad.

**Noch nicht fertig:** Die normale Kampagne, Heimatgruppe, Dorf und D2/D3 verwenden weiterhin planare Orte. Die belebte Kugelwelt bleibt eine getrennte Laufzeit mit eigener Sicherung. Nicht umgesetzt sind der vollständige Kampagnenumzug, große regionale Fernsimulation, Reiten/Pflügen, Mittelalter, Neuzeit und spielbarer Raumflug. Die bestehende Ebene wird erst nach der im Migrationsauftrag festgelegten durchgängigen Abnahme aus dem regulären Neue-Spiel-Weg genommen. Native Windows-, Hör-/Grafik- und Leistungsabnahme auf dem Ziel-PC bleiben eigene Nachweise.
