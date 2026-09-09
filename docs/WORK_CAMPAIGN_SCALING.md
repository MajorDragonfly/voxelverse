# Kampagnenskalierung und sichere Körperreisen

Stand: 9. September 2026. Gemeinsame Basis ist `main` `ca02572c199b1fe4b70174ac027359eaf2c588da` nach PR #45. Diese Runde erweitert die vorhandene Kugelkampagne und deren SaveService. Sie ist eine Grundlage für größere Welten, kein Nachweis einer fertigen No-Man’s-Sky-Skalierung.

Das inzwischen fertig übergebene Animationspaket aus [PR #46](https://github.com/MajorDragonfly/voxelverse/pull/46), Commit `f7da7921b0b25303e9141c81a00c1d1062a774b3`, wird in denselben Integrationsstand übernommen. Die zuletzt ausgeführte PR-Prüfung dieses Fachpakets war erfolgreich, einschließlich beider nativer Plattformen. Gemeinsame Neuprüfung bleibt erforderlich; Bewegungsübergänge ändern keine IDs, Aufträge oder Saveformate. Anschlussregeln: [WORK_CREATURE_ANIMATION.md](WORK_CREATURE_ANIMATION.md).

## Gelieferte Änderungen

| Bereich | Datenbesitzer und Verhalten |
|---|---|
| Körperidentität | `CampaignState` und `body_registry.gd`: `bodies[body_id]`, separater Index aus System-ID und Weltseed. Lesekopie, gemeinsamer Datensatz und ausdrückliche Anlage sind getrennt. Gleiche Seeds in verschiedenen Systemen bleiben getrennt. |
| Speicherung | Save 9, GameState 4, Kampagne 3, Progression 6. Regionen gehören zu `regions_by_body`. Schema 1–8 wird mit erhaltenen IDs, unverändertem Quellarchiv und validierter Zuordnung geladen. Mehrdeutige Körper oder unbekannte Versionen blockieren das Überschreiben und den stillen Rückfall auf eine ältere Sicherung. Alte Slotkopien behalten ihre opaken Körper-/System-IDs. |
| Dorfregeln | `village_work.gd` enthält Bedürfnisse, bestätigte Arbeit, Reservierungen, Fracht und Lieferung. Der nahe Controller bestätigt physische Ankunft; die Fernsimulation bestätigt das Ende eines gespeicherten Wegs. Für Fortschrittsbelege werden veränderbare Teile kopiert, der langfristige Milchbelegbestand wird geteilt. |
| Navigation | Aufbau in Punkte-/Kantenphasen, maximal 128 Zellen und ein kooperatives 2-ms-Budget je Aufruf. Ein unvollständiger Graph liefert keine Route. Körper-ID und Laufzeitgeneration verwerfen alte Aufträge; Ursprungskorrekturen verschieben den angefangenen Graphen mit. Normale Arbeitsbefehle bauen unveränderte Hindernisse nicht erneut auf. |
| Fernarbeit | `village_simulation` Format 1 speichert Besitzer, Kampagnenzeitcursor, zertifizierte Wege, Teilwege und tatsächlich am Tierplatz anwesende D2-Tiere. `far_scheduler.gd` behandelt ausschließlich besuchte ferne Dörfer, reihum mit maximal 32 Aufgaben und kooperativem 2-ms-Budget. Eine Aufgabe holt höchstens 0,25 Spielsekunden nach; offene Zeit bleibt erhalten. |
| Reise | `SessionFlow` friert den alten Host ein, sichert Auftrag/Fracht/Spieler, baut den Host ab und aktiviert den Zielkörper. Steuerung folgt erst nach der Bereitschaft der Zielkollision und erfolgreichem Ankunfts-Commit. Schreib- und Zielfehler stellen den bisherigen Körper wieder her. |

Beim Verlassen werden Wege vom Dorfplatz zu Arbeitsorten, aktuellen Bewohnerorten, Baustelle, Milchabholung, Tierplätzen und Nachbarlager mit der tatsächlichen Navigation geprüft. Die vereinfachte Fernbewegung benutzt diese Wege über den Dorfplatz; sie kann deshalb länger dauern als ein direkter naher Weg. Höchstens 128 Endpunkte und 256 Punkte pro zertifiziertem Weg decken den bestehenden lokalen Dorfvertrag ab. Eine fehlende Verbindung liefert keine Ware. Der reisende Spieler arbeitet währenddessen nicht auf dem verlassenen Körper.

Ferne Bewohner sammeln, arbeiten, essen, trinken, pflegen und transportieren nach denselben Regeln. D3 benutzt den vorhandenen D2-Besitz und dieselben Produktions-/Milchquittungen. Nachbarschaftshilfe behält die zehn tatsächlichen Transporte und den anschließenden Bau durch die Nachbarn; der bestehende Meilenstein wird einmal verbucht. Pause, Menü, Editor, Ladeübergang und geschlossene Anwendung erzeugen keine zusätzliche Spielzeit oder Offlineproduktion.

Neue feste Bauhindernisse stoppen betroffene Fernwege bis zur erneuten physischen Prüfung beim Besuch. Neue Bewohner werden weiterhin im nahen Dorf mit dem vorhandenen atomaren Geburtsablauf erzeugt. Ferne wilde Tiere werden nicht individuell physikalisch simuliert. Mehrere spielbare eigene Dörfer auf demselben Körper bleiben ARCH-26.

## Nachweise

- `body_identity_test`: zwei Systeme mit demselben Seed, getrennte Vorräte und Entdeckungen, A–B–A, frischer Prozess, unveränderte alte IDs, alte Slotkopie, unbekannte/mehrdeutige und falsch zugeordnete Daten, geschützte Quelle.
- `far_simulation_test`: tatsächliche Weg-/Arbeitszeit, blockierte Fracht, abwesender Spieler, genau ein Besitzer, Pause/Menü/Neustart, Nachbartransporte/Bau/Einmalbelohnung. Ein separater D2-Leseport-Prüfstand kontrolliert halben Milchzyklus, JSON-Rückkehr, blockierte Milchfracht und einmalige gemeinsame Nahannahme; er ersetzt keinen dargestellten Tiertransport zwischen Planeten.
- `village_navigation_budget_test`: echte Bodenkollision und Wand, keine halbfertigen Routen, harte Zellgrenze und Abbruch bei Körperwechsel.
- `body_travel_test`: reale Kugelszenen mit Heimat/Dorf, gleicher Seed in zwei Systemen, vollständiger Hostabbau, entfernte Holzarbeit, erhaltene Wartefracht, Rückkehr, fehlgeschlagenes Schreiben mit erhaltener Autosave-Einstellung, ungültiges Ziel mit zuletzt geändertem regionalem Pflanzenbestand und frischer Prozess. Die Rückkehr übernimmt den nach dem regionalen Flush gesicherten Zustand; eine ältere Indexwurzel darf die letzte Ernte nicht zurücksetzen. Derselbe Probe ist über `--body-travel-smoke` im nativen Paket verfügbar.
- `spherical_gameplay_test`: vollständige reale Dorf-/D1-/D2-/D3-Kette einschließlich blockierter Milchfracht und separatem Neustart erneut bestanden. Der Probe wartet jetzt auf das vollständige Navigationsnetz statt auf eine feste Anzahl Ladeframes.
- Bestehende Regressionen verwenden weiterhin echte historische Formate. Synthetische ältere Save-Versionen müssen auch das alte Seedlayout enthalten; bloßes Herabsetzen der Versionsnummer eines neuen ID-Layouts ist bewusst ungültig.

Die abschließenden Quell-/Grafik-/Audio- und nativen Linux-/Windows-Ergebnisse gehören zum Integrations-PR dieses Stands. Ein lokaler Teilnachweis ersetzt diese gemeinsame CI nicht. In der gemeinsamen nativen Prüfung wurden zwei bisher sofort bzw. gemeinsam bewertete Bereitschaftsschritte sichtbar: Der D1-Controller kann vor dem gesuchten lebenden Individuum bereit sein, und das Reservieren einer Baustelle startet zunächst den portionierten Graphaufbau. Der Kugelprobe wartet deshalb höchstens 30 Sekunden auf ein sichtbares lebendes Milchtier und prüft die Navigationsbereitschaft innerhalb von 45 Sekunden separat. Erst anschließend beginnt das unveränderte 45-Sekunden-Limit für den echten Gehegetransport und -bau. Ein fehlendes Tier liefert Katalog-, Körperfreigabe- und Populationsdiagnostik; es wird keines ersatzweise erzeugt. Die Versorgung muss ebenfalls echte Einzelgänge abwarten: Der Pfleger füllt erst vier Wassereinheiten auf und trägt danach Futter. Diese fünf Rundwege einschließlich eigener Bedürfnisstopps erhalten bis zu 60 Sekunden. Im kombinierten Lauf lieferte die gesamte Milchkette bereits korrekt; die vorherige 28-Sekunden-Prüfung war vor der ersten Futterankunft abgelaufen.

## Reproduzierbare Messung

```bash
godot --headless --path . --script tools/benchmark_campaign_scaling.gd -- --report /tmp/campaign-scaling.json
```

Der Probe verwendet 1/10/100 besuchte Körper mit je drei Bewohnern, 1.200 simulierte Frames und dem tatsächlichen Fortschrittsbeobachter. Gemessen werden aktive Körperzugriffe, Scheduler-Wandzeit, vollständiges Speichern/Laden, Dateigröße und Godots statischer Allokator. Die Rohwerte mit Engine, CPU und Umgebung stehen in [CAMPAIGN_SCALING_MEASUREMENTS_2026-09-09.json](CAMPAIGN_SCALING_MEASUREMENTS_2026-09-09.json).

| Besuchte Körper | 10.000 aktive Zugriffe | Fernschritt p95 | Speichern | Laden | Save-Größe |
|---|---:|---:|---:|---:|---:|
| 1 | 9,48 ms | 0,001 ms | 2,35 ms | 2,31 ms | 11.615 B |
| 10 | 9,39 ms | 2,24 ms | 8,22 ms | 12,71 ms | 96.926 B |
| 100 | 9,00 ms | 2,91 ms | 70,02 ms | 89,70 ms | 974.438 B |

Linux, Godot 4.6.3, AMD EPYC 9V74; gleichzeitig liefen weitere Prüfprozesse. Maxima betrugen 0,075 / 27,75 / 3,85 ms. Das 2-ms-Zeitbudget wird zwischen Aufgaben geprüft: Eine einzelne Aufgabe und Betriebssystemunterbrechungen können es überschreiten. Die harte Aufgabenzahl bleibt begrenzt. Diese synthetische Messung enthält kein Terrain, keine GPU-Last und keine Ziel-PC-FPS.

## Nächste Skalierungsgrenzen

1. ARCH-13/14: Körper-, Dorf-, Atlas- und Fortschrittsbestand befinden sich weiterhin im gemeinsamen Snapshot. Speichern/Laden und Gesamtspeicher wachsen mit besuchten Körpern. Ein kleines Manifest und segmentierte Änderungen müssen unter Erhalt der gemeinsamen Transaktionen folgen. Der vorhandene Regionsstore besitzt noch keine sichere Bereinigung historischer Blobs.
2. ARCH-02/17: lange reale Reise mit Richtungswechseln sowie CPU/GPU, Uploads, RAM/VRAM auf definierter Zielhardware messen. Explizite Bau-/Nachbarkontakt-Vorprüfungen enthalten weiterhin synchrone Navigation; der normale Graphaufbau wird bereits portioniert.
3. ARCH-16/18: weitere lange Abwesenheiten und entwickelte historische Dörfer abnehmen, einschließlich echtem gebundenem Tier in der A–B–A-Reiseszene. Ferne Bauänderungen benötigen eine erweiterte Wegprüfung, bevor entfernte Expansion freigegeben werden kann.
4. ARCH-19: Ziel-PC-Spieltest für Darstellung, Bedienung und 1080p60. Danach den regulären Neuspielstart umstellen. Die Kugelkampagne ist weiterhin ausdrücklich über **„Kugelwelt ausprobieren“** erreichbar. **Pause → „Reiseziel wählen“** wechselt zwischen vorbereitbaren Planeten desselben Systems. Es ist noch kein Schiffsflug oder Galaxie-Reisemenü enthalten.

PR #42 bleibt der getrennte Entwurf für spätere Inhalte. Diese Runde eröffnet keine konkurrierende Tier-, Produktions- oder Speicherarchitektur.
