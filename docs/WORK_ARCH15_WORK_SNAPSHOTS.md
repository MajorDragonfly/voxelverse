# ARCH-15 – gezielte Vorher-Zustände für Dorfarbeit

Stand: 2026-09-10. Basis: `main` bei
`ea900f2e09946660694a9e59399b4680a5655a85`.

## Gelieferter Umfang

Der gemeinsame Arbeitskern bestand bereits. Dieser Anschluss ersetzt seine
breiten Kopien vor jedem angekommenen Bewohner durch einen Vorher-Zustand mit
gezielt kopierten veränderlichen Daten. `TribeController._work` und
`VillageSimulation.advance` übergeben dazu den handelnden Bewohner an
`VillageWork.snapshot(data, member)`.

Der Vorher-Zustand dient ausschließlich dem unmittelbar folgenden synchronen
Vergleich durch die Stammesfortschrittsauswertung. Er enthält weiterhin das
vollständige Dorfmodell, damit dessen Validierung und Mengenbilanz dieselben
Eingaben erhalten. Unveränderte Zweige teilen ihre Referenzen mit dem Dorf.
Das senkt die Kopierkosten, insbesondere bei langen Tier- und Produktionshistorien.

Der offene Kopierpunkt von ARCH-15 ist damit für die Arbeit pro Bewohner umgesetzt.
Die gemeinsamen Backlog- und Roadmap-Dateien bleiben wegen paralleler Arbeit
unverändert; dieser Bericht dokumentiert den gelieferten Stand.

## Lebensdauer und Änderungsumfang

Die Reihenfolge bleibt: Vorbereitung und bestätigte Ankunft → Vorher-Zustand →
Arbeit einschließlich Pflege-/Nachbaradapter → synchrone Fortschrittsauswertung.
Der Vorher-Zustand darf weder über ein `await` hinweg aufbewahrt noch für eine
spätere Speichertransaktion verwendet werden. Ein neuer Adapter, der innerhalb
dieses Abschnitts weitere Dorfdaten verändert, muss die Kopiermenge und den
Vergleichstest erweitern.

| Arbeit | Zusätzlich getrennte Daten |
| --- | --- |
| Jeder Schritt | Dorfwurzel, Bewohnerliste, handelnder Bewohner mit verschachtelten Daten, Lagerzähler und Wirtschaftswurzel |
| Sammeln / Versorgen | Vorkommensverzeichnis und ausgewähltes Vorkommen |
| Milchaufnahme | Eingangsqueue einschließlich veränderlicher Restmengen; Entfernen einer leeren Charge bleibt nachvollziehbar |
| Baustofftransport | Projekt einschließlich reservierter und angelieferter Materialien |
| Passendes Bauprojekt | Alle Bewohner, Projekt, Wohngebäudeliste, Stationsverzeichnis und gegebenenfalls Stationsvorkommen; Fertigstellung kann andere Aufträge zurücksetzen und in der Ferne alle Bewohner blockieren |
| Pflege / Pflegefracht / Bau | Gehege und Pflegebilanzen für Entnahme, Lieferung und Rückgabe |

Positionsdaten vorhandener Gebäude, Stationsdatensätze, Produktionshistorien und
Empfangsbelege werden in diesem Abschnitt nicht verändert und deshalb geteilt.
Die Auswahl einer Versorgeraufgabe erfolgt für die Kopie auf einem getrennten
Bewohnerdatensatz: Das Erfassen selbst verändert keinen Auftrag.

Vollständige Momentaufnahmen für Speichern, Zurückrollen, Befehle und Übergaben
bleiben bestehen. Schemas, Mengenregeln, Arbeitsraten, Ankunftsprüfung und
Simulationsbesitzer ändern sich nicht. Auch die gesonderten Kopien des
Tierproduktionsticks und des Nachbardorf-Bauticks bleiben bestehen. Dieser
Anschluss macht keine Aussage über deren verbleibende Gesamtkosten.

## Nachweise

Der neue `village_work_snapshot_test` vergleicht die gezielte Kopie nach jedem
ausgeführten Schritt mit einer zuvor vollständig eingefrorenen Referenz. Beide
Varianten durchlaufen die echte Dorfdatenvalidierung und die echte begrenzte
Fortschrittsauswertung; Ergebnisse und Belohnungszustände müssen identisch sein.
Wiederholte Auswertung darf nichts erneut auszahlen.

Abgedeckt sind alte ebene und aktuelle radiale Dorfmodelle, Sammeln und Liefern,
Versorgeraufgaben, Essen und Trinken, teilweise und vollständig abgeholte
Milchchargen, alle bestehenden Bauarten einschließlich mehrerer beteiligter
Bewohner, Pflegeentnahme/-lieferung und Frachtrückgabe nach Tierverlust.
Die Bauprüfung berücksichtigt außerdem die Blockierung aller Bewohner im
Fernadapter. Der Temponachweis führt `VillageSimulation.advance` mit dem echten
`GameState.simulation_delta` bei Pause und 1-/2-/4-fachem Tempo aus. Bei gleicher
Kampagnenzeit müssen Dorf und Fortschritt vollständig gleich sein; blockierte
Steinfracht bleibt beim Bewohner.

Die bestehenden Laufzeittests ergänzen diese kontrollierten Datenszenarien:

| Prüfung | Zweck |
| --- | --- |
| `tribal_progression_test`, `tribal_economy_progress_test` | Begrenzte Fortschrittsbelege und Wiederholschutz |
| `far_simulation_test` | Zeitgebundener Transport, blockierte Fracht, eindeutiger Besitzer, Pause und Zeitcursor nach echtem Prozessneustart |
| `tribal_economy_progress_world_test` | Wirtschaft mit echter Szene, physischer Ankunft, Berufen, Speicherfehler und Neustart |
| `tribal_neighbors_world_test` | Physische Hilfslieferungen und begrenzte Nachbarbelohnung |
| `tribal_age_housing_recovery_test` | Wiederherstellung von Wohngebäuden und Wegen |
| `spherical_gameplay_test` | Vollständige radiale Kette einschließlich Bau, Tierpflege, Milchtransport, blockiertem Weg, Speichern und Prozessneustart |

Die Ergebnisse mit Laufzeiten, Rohlogs und SHA-256-Dateinachweisen liegen unter
[`evidence/arch15`](evidence/arch15). Der dortige Manifesttext unterscheidet den
ersten Prüflauf von der abschließenden erweiterten Testfassung.

Reproduktion mit Godot 4.6.3:

```bash
python tools/validate_godot.py --godot /path/to/godot --skip-main \
  --tests village_work_snapshot_test tribal_progression_test \
  tribal_economy_progress_test far_simulation_test \
  tribal_economy_progress_world_test tribal_neighbors_world_test \
  tribal_age_housing_recovery_test spherical_gameplay_test \
  --output /tmp/voxelverse-arch15-proof
```

## Kopiermessung und Grenzen

Der neue Test enthält den ursprünglichen Kopieralgorithmus von `ea900f2` als
reine Messreferenz. Das validierte radiale Dorf hält die vorhandenen Obergrenzen
ein: sechs Bewohner, drei Hütten, ein Gehege, 32 historische Tierdatensätze,
64 Empfangsbelege und 48 offene Chargen. Gemessen wird ein Holzarbeiter.

Es entstehen **9 statt 281 getrennte Dictionary-/Array-Container** pro Aufnahme,
also rund 96,8 % weniger. Das ist eine strukturelle Zählung neu kopierter
Container, keine Messung von Bytes oder Gesamtallokationen. Fünf Stichproben
mit je 1.000 Aufnahmen ergaben in der abschließenden Testfassung einen Median
von **12,999 µs statt 254,799 µs**; Rohwerte stehen im Testlog. Zeitwerte dienen
der Dokumentation und sind bewusst keine schwankungsanfällige Testschwelle.

Diese Messung betrifft ausschließlich die Kopierfunktion im Headless-Prozess.
Sie ist weder eine FPS-Messung noch eine Ziel-PC-Freigabe und rechtfertigt keine
höheren Bevölkerungs- oder Produktionslimits. Vollständige Validierungen und
Speichertransaktionen bleiben eigene Kostenstellen.

## Anschluss an parallele Pakete

- ARCH-20 / PR #52 ändert Ressourcenarbeit im selben Arbeitskern. Hier ändern
  sich nur `snapshot` und seine beiden Aufrufstellen. Bei gemeinsamer Integration
  die neue Chargenauswahl erneut gegen diesen Vergleichstest prüfen; die Queue
  wird bereits für gewählte Ressourcen ohne Vorkommen getrennt.
- ARCH-18 kann den Fernsimulationsadapter berühren. Die synchrone Reihenfolge
  um `snapshot(data, member)` und den Beobachter muss erhalten bleiben.
- ARCH-29 / PR #53 führt eine Testregistrierung ein. Nach dessen Integration
  `village_work_snapshot_test` im Vertrag `village` aufnehmen; der bestehende
  Runner auf dieser Basis findet den neuen Test bereits automatisch.
- Andere offene Pakete, Bauplanformate und Produktionsarten werden hier nicht
  verändert. Zusammenführungen paralleler PRs benötigen einen erneuten Lauf
  der konkret betroffenen Vertragsprüfungen.

Lokal geprüfter Quellcommit:
`3f7cc304f986ad6c96ee532db75f6ef412d174a9`.
Inhaltlich identischer GitHub-Quellcommit:
`5ee006c0a4e625d9919ba177b37971005515cca7`.
Gemeinsamer Quellbaum:
`76f5fe668495dc86c080f46747b338ebfcb3903f`.
