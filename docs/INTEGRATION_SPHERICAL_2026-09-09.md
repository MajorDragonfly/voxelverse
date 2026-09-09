# Zweite Integration: gemeinsamer Stand und Kugelumzug

Stand: 9. September 2026. Zusammengeführter lokaler Integrationsbranch `agent/integration-spherical-2026-09-09`. Basis `3a3e0272375e556f3ff65b7370582af79a9d48b5`. Die vollständigen Quell- und Baumkennungen stehen in [integration-spherical-sources-2026-09-09.json](integration-spherical-sources-2026-09-09.json). Historische Einzelberichte behalten ihre damaligen Grenzen; dieses Dokument beschreibt den gemeinsamen Folgeaufbau.

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
- **Spielstandkopien:** Kopieren eines D2-Spielstands bindet das Tierregister an die neue Kampagnen-ID. Tier-/Körper-/Besitzkennungen und die Quelldatei bleiben erhalten; D3 findet die Tiere auch in der Kopie.
- **D2 → D3:** Die Dorfhaltung liest jetzt direkt den tatsächlichen D2-Bestand, seine D1-Eignung und denselben Tier-Actor. Der Zugriff wird nach Kampagnenladen wiederhergestellt; es entsteht kein zweiter Tierbestand. Die explizite D3-Prüfszene darf weiterhin ihre isolierten Quellen anschließen.
- **Dorfbewegung:** Haus-/Eingangshindernisse, Nachbarraster und D2-Reichweite verwenden denselben Navigationsaufruf. Fracht, Versorgung, Wachstum, Tierhaltung und Nachbararbeit bleiben im gemeinsamen Simulationstakt. Die frühere doppelte Radiusdeklaration ist entfernt.
- **Fortschritt mit Wachstum:** Wirtschaftsnachweise akzeptieren die vorhandenen Dorfversionen 3–5. Neu hinzugekommene, validierte Bewohner werden in den gemeinsamen Arbeitsnachweis aufgenommen. Nachbarvertrag 2 erlaubt bis zu sechs eigene Träger; Vertrag 1 bleibt lesbar und wird beim nächsten Hilfsauftrag ausdrücklich angehoben.
- **Bedienung:** Aufträge, Berufe, Tierhaltung, Nachbarn und Zähmung nutzen die vorhandenen scrollbaren Dorfreiter. Auswahlfehler und fehlendes Werkzeug melden echte Ablehnung. Rückmeldung, Einklappen, kleine Fenster und Pause greifen ineinander. Ein entferntes Hüttenmodell für die Nachbarn wurde wieder angeschlossen.
- **Buch und Gestaltung:** Neue Körperteilvorschauen/Silhouetten bleiben mit D1-Eignung, D2-Tierregister und dem kompakten Buch kompatibel. Zwei konkurrierende Größenberechnungen und doppelte Memberdeklarationen sind zusammengeführt.
- **Karten auf belebten Kugeln:** Dieselben Mini-/Weltkarten lesen die tatsächliche Walker-Adresse und Oberflächenquelle. `M` öffnet dort die Karte, `P` wechselt den Referenzplaneten. Erkundung bleibt beim Wechsel und Neustart erhalten; Zoomen deckt keine unbekannten Regionen auf.
- **Versionierter Kugelspeicher:** Neuer Header 3 für Karten, bestehender D1.2-Inhalt unverändert. Alte Header 1/2 werden weiter gelesen und erst beim regulären Sichern angehoben. Unbekannte neue Atlasversionen sperren auch einen Rückfall auf ein älteres Backup. Vor-Karten-Builds erkennen Header 3 als unbekannt statt Kartendaten wegzuspeichern.
- **Prüfinfrastruktur:** Reale 300-Sekunden-Milchzyklen sowie Wachstum/Wirtschaft erhalten gezielt längere Testfristen. Der vollständige CI-Job erhält Zeit für den gewachsenen Prüfumfang. Echte UI-Ereignisse rechnen Canvas-Transformationen ein; die Headless-Menüprobe benutzt ein unterstütztes 1280×720-Fenster statt des 64×64-Engineplatzhalters.

## Prüfstand

**114/114 Quelltests und 28/28 Linux-Paketprüfungen bestanden**, mit Godot `4.6.3.stable.official.7d41c59c4`. Der [maschinenlesbare Nachweis](../validation/integration-spherical-2026-09-09/results.json) enthält sämtliche Ergebnisse, Herkunft und Grenzen.

Der Gesamtlauf umfasste alle 114 Quelltests. Vier zunächst fehlgeschlagene Prüfungen wurden nach Korrektur gezielt erneut ausgeführt: D2-Weltnavigation, Forschungsmenü, Hauseingangsbewegung und gemeinsamer Mahlzeitenfortschritt. Beim letzten Punkt versorgt die Probe nun tatsächlich sämtliche Bewohner; drei Mahlzeiten insgesamt hatten wegen der automatischen Essenspausen noch nicht drei versorgte Bewohner nachgewiesen. Die Belohnungsregel und ihre strenge Punkteprüfung bleiben erhalten. Zusätzlich wurden D2-Kampagnenkopie, Spielstandverwaltung und radiale D1.2-Laufzeit erneut geprüft. Es handelt sich um einen Gesamtlauf während der Integration plus gezielte Nachprüfungen, nicht um einen einzigen unveränderten grünen Lauf am Schlusscommit.

Der Quellstand ist durch Commit `38b93d4` festgehalten. Die Linux-Abnahme gehört zum Paketstand `664bf92`: tatsächlicher Release-Export, native Einstiege/Menüs, ausgelagerte Paketproben, Dorf mit Kaltstart, Forschung, Speicher und drei Welt-Seeds. Die spätere dreizeilige Korrektur der D2-Kampagnen-ID beim Kopieren wurde anschließend mit tatsächlichem Kopieren/Laden/Neustart und Spielstandtests im Quellbetrieb bestanden; dieses Linux-Paket wurde danach nicht erneut gebaut. Weitere Änderungen bis zum lokalen Prüfcommit `38b93d4` betreffen Tests und Prüffristen; die danach bei der Veröffentlichung gefundenen Korrekturen sind unten separat beschrieben.

Separate Prozesse bestätigen außerdem D1.2-Schreiben/Lesen über die drei Referenzkörper, Altspeicher-Übernahme und Schutz vor unbekannten Versionen sowie D3-Pflege/Milchtransport mit anschließendem Neustart. Kartenprüfungen decken Körperwechsel, Wiederherstellung und das Verhindern von Erkundung durch bloßes Zoomen ab.

Die Prüfungen lassen sich aus dem Projektverzeichnis mit den vorhandenen Werkzeugen wiederholen; `GODOT_BIN` bezeichnet den lokalen Godot-4.6.3-Pfad, die passenden Exportvorlagen müssen installiert sein:

```sh
python3 tools/validate_godot.py --godot "$GODOT_BIN" --output /tmp/voxelverse-source-check
python3 tools/validate_export.py --godot "$GODOT_BIN" --platform linux --output /tmp/voxelverse-linux-check
python3 tools/validate_domestic_fauna.py --godot "$GODOT_BIN" --probe d12 --output /tmp/voxelverse-d12-check
```

Diese Aufrufe schließen zusätzlich Import- bzw. Einstiegskontrollen ein; ihre Gesamtzahl kann deshalb über den oben genannten Einzeltests liegen. Die Paketprobe trennt native Tests ausdrücklich von instrumentierten Prüfungen mit dem Editor und dem Release-PCK.

Die anschließende GitHub-Prüfung deckte zusätzlich einen Importfehler in der Prüfinfrastruktur auf: Drei grafische Körper-/Sattelprüfungen importieren `tools.validate_godot` als Modul, während der Hilfsimport bislang nur beim direkten Skriptstart funktionierte. Der Import unterstützt jetzt beide Aufrufarten; die Fehlererkennung und eigentlichen Spielprüfungen bleiben erhalten. Die aktuellen Remote-Ergebnisse sind im [Integrations-PR #41](https://github.com/MajorDragonfly/voxelverse/pull/41) nachvollziehbar.

Weitere Remote-Nachprüfungen fanden zwei Laufzeitfehler: Ein aufgeschoben initialisierter Beerenbusch konnte nach dem Entfernen seiner Szene noch Weltkoordinaten lesen und Nahrung registrieren; beide Initialisierungswege brechen jetzt vor solchen Zugriffen ab. Ein gezielter Test prüft entfernte sowie zum Löschen vorgemerkte Pflanzen, und der echte Szenewechsel wurde mit begrenzter CPU-Leistung vor und nach der Korrektur reproduziert. Beim D2-Annähern wird außerdem die tatsächliche Ankunftstoleranz des Dorfbewegungssystems berücksichtigt, damit ein Bewohner innerhalb der Fütterungsreichweite stehen bleibt; die reale Zähmungsprüfung besteht danach.

Die grafische Dorfweltprobe überschritt auf dem Software-Renderer ihre Frist während der automatischen Transporte. Sie rendert jetzt gezielt das Ergebnis nach denselben tatsächlichen Simulationsschritten, mit vier sichtbaren Vorlaufbildern vor der Aufnahme; der Modus wird im Ergebnis ausgewiesen. Die übrigen GUI-Eingabeprüfungen zeichnen unverändert laufend. Dieser Aufnahmeablauf ist kein Nachweis flüssiger Darstellung auf Zielhardware.

Die native Windows-Menüprobe wählt nun ausdrücklich Deutsch für ihre deutschen Textprüfungen. Windows startete durch die neue automatische Spracherkennung korrekt auf Englisch; die Tastenbelegung selbst war erfolgreich gespeichert und wirksam, während drei alte deutsche Textvergleiche deshalb fehlschlugen. Die Geräte-Sprachwahl im normalen Spiel bleibt automatisch bzw. nutzerbestimmt.

Die Dorfweltprobe wartet außerdem auf fertig erzeugtes Gelände und Hindernisse im gesamten Such-/Navigationsbereich, einschließlich der anschließenden Physikaktualisierung. Eine leere Erzeugungswarteschlange garantierte das bisher nicht. Ihr Suchraster berücksichtigt jetzt auch die Ein-Meter-Zwischenräume; sämtliche realen Boden-, Trockenheits-, Freiraum- und Transportprüfungen bleiben erhalten. Beim grafischen Vergleich des Planeten-Detailwechsels wird die unabhängig weiterladende Minimap vorübergehend angehalten: Die ursprüngliche Remote-Abweichung lag ausschließlich in dieser Anzeige, während das Gelände pixelgleich war. Vergleichsgrenzen, beide Übergangsphasen und die absichtlich entfernte Geländeabdeckung als Negativkontrolle bleiben unverändert.

Der vollständige Quelllauf dauerte lokal bereits knapp 30 Minuten. GitHub verteilt die automatisch gefundenen Tests deshalb überschneidungsfrei auf vier Läufe (29/29/28/28 beim aktuellen Bestand), jeweils mit Importprüfung. Ein eigener Lauf prüft die tatsächlichen Einstiege, Abschaltpunkte und das Streaming. Die gemeinsame Abschlussprüfung `validate` verlangt den Erfolg sämtlicher Teilläufe; Testumfang und individuelle Fristen bleiben erhalten.

## Veröffentlichung

Der Nutzer hat die Veröffentlichung im öffentlichen Repository `MajorDragonfly/voxelverse` und die anschließende Übernahme nach `main` ausdrücklich freigegeben. Die ursprüngliche Ablehnung der automatischen Freigabeprüfung gehört zum vorherigen Prüfstand; der entsprechende Eintrag im Ergebnisnachweis dokumentiert diesen Zeitpunkt.

Die Übertragung erfolgt über die verbundene GitHub-App, weil dem lokalen Git-Client die Zugangsdaten fehlen. Bereits veröffentlichte Quellcommits behalten ihre Kennungen. Nur lokal vorhandene Commits werden mit identischen Dateibäumen, ursprünglicher Elternreihenfolge und Herkunftsangaben übertragen; die App vergibt dabei neue Commit-Kennungen. Die lokale Prüfhistorie bleibt erhalten. Die Zuordnung steht im [Veröffentlichungsnachweis](integration-spherical-publication-2026-09-09.json); sämtliche übertragenen Dateibäume wurden gegen ihre lokalen Originale abgeglichen. Die oben genannten Prüfergebnisse beziehen sich weiterhin auf ihre ausdrücklich angegebenen lokalen Quell- und Paketstände.

## Verbindliche nächste Priorität

Der [Kugel-Migrationsauftrag](SPHERICAL_CAMPAIGN_MIGRATION.md) ersetzt weitere Ausbauten der Flachwelt als Entwicklungsrichtung. Die dazugehörigen [Folgeaufträge](NEXT_PARALLEL_WORK.md) beginnen mit Kampagnenorten und atomarer Speicherung, danach Kreaturenphase und Stamm/Tierhaltung, anschließend Nah-/Fernsimulation und belastbaren Budgets. Die gemeinsame [Designvorgabe](VOXELVERSE_DESIGN.md) liegt nun am kanonischen Projektpfad.

**Noch nicht fertig:** Die normale Kampagne, Heimatgruppe, Dorf und D2/D3 verwenden weiterhin planare Orte. Die belebte Kugelwelt bleibt eine getrennte Laufzeit mit eigener Sicherung. Nicht umgesetzt sind der vollständige Kampagnenumzug, große regionale Fernsimulation, Reiten/Pflügen, Mittelalter, Neuzeit und spielbarer Raumflug. Die bestehende Ebene wird erst nach der im Migrationsauftrag festgelegten durchgängigen Abnahme aus dem regulären Neue-Spiel-Weg genommen. Native Desktopprüfungen werden zusätzlich in GitHub ausgeführt; deren aktueller Stand ist im Integrations-PR verlinkt. Hör-/Grafik- und Leistungsabnahme auf dem tatsächlichen Ziel-PC bleiben eigene Nachweise.
