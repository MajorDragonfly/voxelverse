# ARCH-26.1 – Siedlungsvertrag 1

Status: isolierter, ausführbarer Datenvertrag auf dem gemeinsamen Stand vom 10. September 2026. [Übergabe](WORK_ARCH26_SETTLEMENT_CONTRACT.md). **Noch kein registrierter Speicherteil und keine spielbare Siedlungsgründung.** ARCH-26 als Ganzes bleibt offen.

## Besitz und Format

`world/tribe/settlement_collection.gd` bereitet einen kopierten Körper für die spätere gemeinsame Migration vor. Im vorbereiteten Körper ersetzen die Instanzen `body.tribe` und `body.village_simulation`. Beide alten Felder gleichzeitig mit dem neuen Register werden zurückgewiesen. `GameState`, `SaveGameService`, die laufenden Controller und ihre Schemas bleiben in diesem Teilpaket unverändert.

| Pfad im vorbereiteten Körper | Vertrag |
|---|---|
| `settlements.schema` | 1 |
| `settlements.body_id` | Unveränderte Körper-ID; kein Seed als Identität |
| `settlements.selected_settlement_id` | Ausgewählter Ort; unabhängig von Fraktion, Spezies und Simulationsbesitzer |
| `settlements.entries[settlement_id]` | Maximal zwei Instanzen; Schlüssel und `settlement_id` stimmen überein |
| `entry.schema` | 1 |
| `entry.village` | Einziger Besitzer der Dorfbestände: vorhandener radialer Dorfdatensatz 6 mit `id == settlement_id` |
| `entry.simulation` | Vorhandener Simulationsvertrag 1 oder leer, solange keine zertifizierte Fernübergabe besteht |

Ort, Fraktion und Spezies stehen ausschließlich im Dorfdatensatz (`anchor`, `body_id`, `species_id`, `faction_id`). Es gibt keine zweite mutable Kopie dieser Werte im Register. Bewohneraufträge, Arbeitsetappen, Timer, Ladung, Baumaterialreservierungen, Produktionshistorien und Lieferbelege bleiben in ihren vorhandenen Fachfeldern.

Heimat, D1/D2, Nachbarfraktion, Atlas und sonstige Körperfelder bleiben am Körper. `home_group_id` bezeichnet weiterhin die ursprüngliche Heimatgruppe. Die erste `settlement_id` ist exakt die bisherige `tribe.id`; keine bestehenden IDs werden neu erzeugt. Für spätere Neugründungen ist eine einmalig angelegte, gespeicherte `CampaignIds.create("settlement")`-Identität vorgesehen. Der Test verwendet ausschließlich für seine reproduzierbare Fixture eine scoped ID.

## Anschlüsse

| Funktion | Verhalten |
|---|---|
| `prepare_legacy(body, campaign)` | Prüft das bestehende radiale Dorf, erzeugt eine tiefe Kopie und verschiebt darin den unveränderten Dorf-/Simulationsdatensatz. Liefert `ok`, `code`, `changed`, `body`; bei Fehler kein teilweise migriertes Ergebnis. |
| `validate(body, campaign)` | Reiner Validator für das vorbereitete Format. Prüft Ort, Herkunft, eigene Spezies/Fraktion, Identitäten, Fachbilanzen, Arbeitsorte, Produktionsbesitzer und Simulationscursor. |
| `instance_view(body, settlement_id)` | Kurzlebige gemeinsame Fachansicht für `VillageWork` und `VillageSimulation`; `tribe` und `village_simulation` sind geteilte Referenzen auf genau eine Instanz. Kein Speicherabbild. |
| `select(body, settlement_id)` | Ändert nur eine vorhandene Auswahl. Legt keine Siedlung an, bewegt niemanden und überträgt keine Simulationshoheit. |
| `workplaces(body, settlement_id)` | Tiefe Lesekopien vorhandener Ressourcenplätze, Stationen, Unterkünfte, Tierplätze und Baustellen; Schema 1, Arbeitsplatz-/Siedlungs-ID, Rolle, Typ, Ort und Eingang. |

`instance_view` darf erst nach erfolgreicher Gesamtvalidierung gebunden werden. Die Ansicht ist flach; Änderungen **innerhalb** ihres Dorf-/Simulationsdatensatzes ändern die Instanz. Eine Ersetzung des obersten Ansichtsfeldes ist keine Rückschreibung. Ansichten nach Snapshotwechsel, Laden oder Rollback neu binden. Nur das ursprüngliche Dorf erhält den vorhandenen Nachbaranschluss; fremde Vorräte werden durch eine zweite Siedlung nicht verändert.

`Tribe.validate_settlement()` und `Simulation.validate_settlement()` stellen ausdrücklich benannte Instanzprüfungen bereit. Die bisherigen `validate()`-Einstiege behalten Herkunfts- und Spieleranforderungen für den aktuellen Speicherweg. `VillageEconomy.validate(data, resource_owner)` verwendet denselben Fachvalidator mit explizitem Besitzer der Ressourcen-IDs. Normale Aufrufer behalten den bisherigen Standardwert.

## Erhaltung und Grenzen

- Wiederholte Vorbereitung eines gültigen Registers liefert denselben Inhalt mit `changed = false`. Änderungen am Ergebnis verändern das Original nicht. Auch gehaltene Fracht, Teilzeiten und begonnene Baustellen bleiben erhalten.
- Ein radialer Ort muss zum Körper und seinem Radius gehören. Planare Quellen benötigen zuerst die bestehende geschützte Kugelkopiermigration; dieser Vertrag erzeugt keinen zweiten Ortsmigrator.
- Die ursprüngliche Siedlung und die drei ursprünglichen Bewohner bleiben erhalten. Bewohner dürfen auf zwei Siedlungen verteilt sein, aber jeder Bewohner hat genau eine Instanz. Es werden insgesamt höchstens die bisher unterstützten sechs Bewohner akzeptiert. Vorhandene Wachstums-IDs bleiben gültig; freie neue Bürger werden nicht erfunden.
- Ressourcen-IDs des ursprünglichen Dorfes bleiben an dessen Heimatgruppe gebunden. Weitere Siedlungen verwenden ihre eigene ID als Ressourcenbesitzer. Stationen/Bauwerke behalten ihre bereits siedlungsbezogenen IDs. Gleiche Stationstypen in zwei Siedlungen sind damit getrennte Arbeitsplätze.
- Tierplatzbelegung, auch ungebundene Produktionshistorien und Lieferquellen dürfen nicht in zwei Siedlungen vorkommen. Ein Tierumzug braucht später eine atomare Übertragung der Historie; eine neue Belegung darf den bisherigen Produktionszähler nicht zurücksetzen. Tierbesitz selbst bleibt ausschließlich D2.
- Es gibt höchstens einen nah simulierten Ort je Körper; entfernte Instanzen verwenden den vorhandenen Arbeitskern und jeweils eigene Wege/Cursor. Auch eine Siedlung ohne Spieler referenziert ausdrücklich dessen Kampagnen-ID als abwesenden Reisenden. Auswahl überträgt keine Simulation.
- Legacy-Baustellen ohne eigene Kennung erhalten lediglich eine deterministische Leseadresse im Arbeitsplatzindex. Für mehrere gleichartige Baustellen **innerhalb derselben Siedlung** fehlen noch dauerhaft gespeicherte Baustelleninstanzen und deren Aufträge. Der Index ist kein zusätzlicher Reservierungs- oder Auftragsdienst.
- Unbekannte Register-, Instanz-, Dorf- oder Fachversionen werden abgelehnt und nicht normalisiert. `prepare_legacy` ändert auch im Fehlerfall keine Quelle.

## Vor regulärer Nutzung noch erforderlich

Der vorbereitete Körper darf noch **nicht** in die aktive Kampagne eingesetzt werden. Die normale Speicherung kennt dieses Format nicht vollständig. Eine nächste, koordinierte Integration muss nach ARCH-06/07/13 alle Save-Teilnehmer, Versionssperren, Slotkopien, History, Migrationsarchive, Regionsreferenzen, Rollback und Quellschutz anschließen. Der gemeinsame SaveGameService bleibt alleiniger Writer.

Danach folgen Siedlungsgründung/Umzug mit tatsächlich erreichbarem Ort, Bewohnerzuordnung und Kosten; Controller-, Scheduler-, Fortschritts-, Reise-, Atlas-/UI- und D2/D3-Verbraucher mit `settlement_id`; mehrere Baustellen pro Siedlung; schließlich regionale Transporte gemäß ARCH-27. Bestehende Körperreise ist kein Siedlungstransport.

Die Modellprüfung verwendet bereitgestellte radiale Wege und den echten Facharbeitskern. Sie ist kein Nachweis kollisionsgeprüfter Siedlungsgründung, physischer Navigation, Regionsauslagerung, Ziel-PC-Leistung oder einer bereits spielbaren zweiten Siedlung. Geschlossene Anwendung und Pause erzeugen weiterhin keine neue Kampagnenzeit.
