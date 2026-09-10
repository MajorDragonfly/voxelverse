# ARCH-17 – begrenzte Pflanzenpublikation und Tierplatzierung

Stand: 10. September 2026. Basis: `main` `ea900f2e09946660694a9e59399b4680a5655a85`.
Branch: `agent/arch-17-fauna-budget`. Fachzuordnung: M1h, begrenztes Teilpaket von ARCH-17.

## Umfang und Anschluss

Der gemeinsame Kugelhost verwendet bereits `surface_ecosystem.gd` für Landschaftspflanzen und `campaign_population.gd` für gespeicherte Wildtiere/Nahrungspflanzen. Diese vorhandenen Besitzer bleiben bestehen. Speicherformate, Körper-/Arten-/Objekt-IDs, Terrain-/Populationsgenerator und D1-Rollen ändern sich nicht. Keine neue Population oder Speicherung.

Die Änderungen betreffen ausschließlich diese zwei Laufzeitdateien sowie eigenen Probe, Fachtest, Prüffixture und diese Übergabe. ARCH-01/02/05/20/23/24/25/29 bleiben bei ihren Fachchats. Gemeinsame Validator-/CI-Listen und zentrale Roadmap bleiben bei der Integration; der neue `*_test.gd` wird vom vorhandenen rekursiven Testlauf automatisch gefunden.

## Geliefertes Verhalten

- **Flora:** ein laufender CPU-Job, höchstens ein vorbereitetes Ergebnis, ein unfertiger Bereich. Höchstens 25 veröffentlichte Bereiche; keine erhöhte Sichtweite oder Dichte. Mesh-/Materialaufbau erfolgt für eine Pflanzenfamilie pro Schritt, Kollision für ein Exemplar pro Schritt. Die sieben Familien besitzen zusammen höchstens 64 Platzierungsversuche pro Bereich. Assetvorbereitung verwendet weiterhin den vorhandenen gemeinsamen Anschluss mit höchstens einem kalten Resource-Load pro Frame.
- **Atomare Sichtbarkeit:** Der neue `StaticBody3D` bleibt außerhalb des Szenenbaums, bis alle Meshes und Shapes vollständig sind. Erst dann werden Darstellung, Kollision und Oberflächenbindung gemeinsam veröffentlicht. Abbruch gibt auch bereits erzeugte, noch nicht sichtbare Ressourcen frei.
- **Gültigkeit:** Jobtickets enthalten Körper-ID, Zell-ID und Laufzeitgeneration. Gebietswechsel verwerfen alte Ergebnisse, auch nach A → B → A während desselben Workers. Jeder Publikationsschritt prüft das Ticket erneut. Ursprungsverschiebungen benötigen keine Neugenerierung: der Abschluss löst den kanonischen Mittelpunkt gegen den dann aktuellen Ursprung auf.
- **Geometrie:** Nah-/Fern-LOD verwenden ausdrücklich die bereits vom Generator gewählte Geometrievariante; diese war zuvor nur bei der Kollision berücksichtigt. IDs und Rezeptdaten bleiben gleich.
- **Kampagnenpopulation:** Höchstens zwei Platzierungsversuche pro 0,25-Sekunden-Update, einschließlich erfolgloser Boden-/Kapselprüfungen. Nach dem ersten Erfolg endet der Aufbau. Pflanzen und Tiere erhalten abwechselnd Vorrang; fehlgeschlagene Kandidaten rotieren, sodass ein blockierter erster Standort spätere erreichbare Tiere nicht dauerhaft verdrängt. Grenzen bleiben 12 Tiere und 16 Nahrungspflanzen.
- **Lebenszyklus:** Keine gespeicherte Jobqueue. Laden setzt nur die flüchtigen Auswahlcursor zurück. `close()` und Baumabbau invalidieren Jobs, warten den vorhandenen Worker ab und geben unfertige Publikationen frei. Ein geschlossener Host startet keine neue Arbeit.
- **Diagnostik:** `streaming_diagnostics()` liefert Worker, Ergebnis-/Stagingbestand, Publikationsschritte, Verwerfungen und Generation. `max_publish_ms` misst jetzt den größten einzelnen Publikationsschritt, `max_asset_prepare_ms` die Assetvorbereitung getrennt. Die bisherigen Gesamtframe-/Workerwerte bleiben vorhanden. Die Kampagnenpopulation meldet `last_spawn_attempts`, `peak_spawn_attempts` und `max_spawn_attempt_ms`.

Die Flora- und Kampagnenpopulation besitzen getrennte Grenzen. Dies ist kein gemeinsames Zeitbudget aller Terrain-, Tier-, Navigations- und Rendererarbeit. Der vorhandene Labor-Tieraufbau und Floraaufbau werden innerhalb desselben Ecosystem-Ticks nicht gleichzeitig veröffentlicht.

## Fachnachweise

`tests/surface_population_budget_test.gd` verwendet reale Assets, MultiMeshes, Kollisionsshapes, Radialadapter und WorkerThreadPool. Nachgewiesen werden:

- Unfertige Bereiche sind weder in der Szene noch im Adapter registriert; jeder Schritt erzeugt höchstens ein Mesh oder eine Kollisionsform.
- Neun Instanzen und sechs Kollisionsformen bleiben nach mehrstufigem Aufbau erhalten; eingereichte Positionen, Farbdaten und Geometrievarianten stimmen mit den Eingaben überein.
- Ursprungskorrekturen vor und nach Veröffentlichung auf einer Terra-Kugel nahe einer Cube-Flächenkante erhalten den kanonischen Ort.
- Abbruch mitten im Aufbau, fremde Körper-ID, Worker A → B → A, Pause, explizites Schließen und Baumabbau während eines Workers hinterlassen keine aktive fremde Publikation oder Worker.
- Ein isolierter Anschlussprüfstand ruft den echten Auswahlalgorithmus mit 19 blockierten und einem erreichbaren Tierstandort auf. Tiere und Pflanzen erhalten Arbeit, Fehlversuche bleiben begrenzt, leere Kandidatenlisten wiederholen nichts. Physische Tiere/Nahrung werden zusätzlich durch die vorhandenen Spielketten geprüft.

Lokale Prüfungen unter Godot 4.6.3 mit strenger Fehler-/Leakprüfung:

| Prüfung | Ergebnis | Dauer |
|---|---|---:|
| `surface_population_budget_test` | bestanden | 1,874 s |
| `spherical_gameplay_test` | bestanden; echte Kugelpopulation, Heimat, Dorfaufstieg, Fracht, Nachbarn, D1/D2/D3 und frischer Prozess | 328,043 s |
| `wildlife_foraging_test` | bestanden; endliche Nahrung, Körperkollision, Ernte, Wiederaufbau und Speicher-/Neustartfälle | 20,428 s |

Der Spielkettentest lief während der Entwicklung weiterer Diagnosezähler; der abschließende Fachtest prüft auch diese Diagnose- und Teardownanschlüsse. Keine Spielregel wurde nach der gestarteten Spielkettenprüfung geändert. Die zunächst langsam erscheinende Ausgabe war gepuffert; der Lauf beendete die gesamte Kette erfolgreich. Eine zusätzliche Fehlersuche am Start wurde daraufhin beendet. Lokaler Headless-Nachweis, keine Aussage über Ziel-PC-Optik oder Paket-CI.

## Reproduzierbare CPU-Messung

```bash
godot --headless --path . --script tools/benchmark_surface_publication.gd
python tools/validate_godot.py --godot /pfad/zu/godot --skip-import --skip-main --tests surface_population_budget_test spherical_gameplay_test wildlife_foraging_test
```

Der unveränderte Benchmark ist auch auf der Basisrevision ausführbar: nur `tools/benchmark_surface_publication.gd` in deren Checkout übernehmen. Er erkennt den alten vollständigen und den neuen mehrstufigen Publikationsanschluss. Beide Läufe verwenden dieselben sieben echten Assetfamilien und einen synthetischen dichten Bereich mit 64 Instanzen; Assets sind vorher geladen. Zehn Wiederholungen, Linux, Godot 4.6.3, AMD EPYC 9V74. Andere Chats führen parallel Arbeiten aus. Rohwerte: [ARCH17_POPULATION_MEASUREMENTS.json](ARCH17_POPULATION_MEASUREMENTS.json).

| Messwert | Basis | Mehrstufig |
|---|---:|---:|
| Einzelaufruf p50 | 1,137 ms | 0,074 ms |
| Einzelaufruf p95 | 2,159 ms | 0,306 ms |
| Größter Einzelaufruf | 2,159 ms | 0,734 ms |
| CPU-Zeit je vollständigem Bereich p50 | 1,137 ms | 4,416 ms |
| Aufrufe über zehn Bereiche | 10 | 390 |

Die Lastspitze wird auf kleinere Arbeitsschritte verteilt; Gesamtaufwand und Fertigstellungszeit steigen. Die Messung enthält keine GPU, Terrainlast, kalten Asset-Uploads oder Ziel-PC-FPS. Das Einfügen des fertigen Bereichs in den Szenenbaum bleibt ein einzelner begrenzter Abschluss; dessen Renderingkosten müssen mit ARCH-02 auf Zielhardware geprüft werden. Ein Tieraufbau, eine einzelne Material-/Meshoperation oder ein kaltes Asset kann weiterhin das gewünschte Framezeitbudget überschreiten.

## Verbleibende Grenzen / Integration

Dieses Paket schließt **ARCH-17 nicht insgesamt**. Wasser/Audio, geschwindigkeitsabhängige Terrainvorausschau, synchrone Regions-/Habitatprüfungen, portionierter individueller Kreaturenmeshaufbau und lange Ziel-PC-Routen bleiben offen. ARCH-02/05 können unabhängig fertiggestellt werden; dieses Paket setzt keine ihrer unveröffentlichten Änderungen voraus. Die gemeinsame Abnahme muss deren Oberflächenvertrag und Messinstrumentierung anschließend erneut mitprüfen.

Es gibt keine Erhöhung von Objekt-, Bewegungs- oder Speichergrenzen. Keine neuen Saveversionen und keine Migration. ARCH-13/14 bleiben zuständig für dauerhaften Regionsbestand. Die Integration übernimmt nur dieses fertige Teilpaket; ein grüner Fachtest ist keine vollständige M1i- oder Windows-/Ziel-PC-Abnahme.
