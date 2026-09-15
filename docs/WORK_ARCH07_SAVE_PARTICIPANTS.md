# ARCH-07 – feste Speicherteilnahme

Fachbranch: `agent/arch07-save-participants-2026-09-10`, Basis `bb2f83b56267964baa7037720c4daca26fe3d007` auf gemeinsamem `main`. Implementierung und neue Prüfung: `ce0f84cd6bdd319ce6dce6f443bd2917a9adf918`. ARCH-22 und ARCH-06 sind ausdrücklich anderen Chats zugeordnet. Diese Lieferung ist noch nicht in `main` integriert.

## Ergebnis und Besitzer

`core/persistence/save_participants.gd` enthält eine feste Liste aus sieben Snapshot-Teilnehmern und 14 körpergebundenen Speicherbausteinen. Es gibt keine dynamische Pluginregistrierung, keinen zweiten Save-Service und keine zusätzliche Kopie der Körper-Fachdaten. Die vorhandenen Validierungen und Versionswächter werden an die bestehenden Fachmodelle delegiert.

`SaveGameService` bleibt alleiniger Writer und Besitzer von Slots, Historie, Archivierung, atomarem Abschluss, Fehler-/Erfolgssignalen und Körper-/Epochenübergaben. `save_started` läuft weiterhin vor dem Snapshot, damit Hosts Positionen und Regionswurzeln sichern. `game_saved` folgt erst nach erfolgreichem zentralem Schreiben. `game_loaded` folgt nach vollständigem Import und Wiederaufnahme des Übergangs.

Das persistierte Format bleibt **Save 9 / GameState 4 / Kampagne 3**. Die Registrierung selbst führt kein Speicherformat und keine zusätzliche Pflichtversion ein.

## Snapshot- und Importports

Jeder Eintrag in `SECTIONS` verwendet `_snapshot_<id>(files)` und `_restore_<id>(data)` im zentralen Service. Die Liste bestimmt die Reihenfolge. Vor einem Snapshot und vor dem Laden müssen beide Ports existieren; der Snapshot muss exakt die registrierten aktuellen Felder liefern. Unbekannte Top-Level-Felder werden bei Validierung und Versionsprüfung abgewiesen, auch wenn ein älteres gültiges Backup existiert.

| Teilnehmer | Felder / Eigentümer | Import und Migration |
|---|---|---|
| `metadata` | Saveversion, Zeit, Slotname, Migrationsbericht, Vorschaubild, Kopierherkunft | Slotfelder im Save-Service; Bericht wird vor dem Import einschließlich Wiederherstellungs-/Migrationshinweisen aufgebaut. `slot_history` ist explizit als Archivmetadatum registriert; der vorhandene Kopierpfad entfernt es nach Verwendung. |
| `designs` | `design_files`, vorhandener DesignStore | Exakte eingebettete Entwurfsbytes; Originalschutz und alte Designadapter bleiben bestehen. |
| `onboarding` | `onboarding`, vorhandenes Onboarding-Modell | Optional; fehlende alte Daten verwenden bisherige Defaults. Unbekannte neuere Guide-Daten bleiben unverändert und blockieren die Kampagne weiterhin nicht. |
| `game_state` | `game_state` einschließlich aller Körper | Vorhandener `GameState.import_state`; Körper-ID-Migration erfolgt davor über `BodyRegistry.upgrade_save`, nach Sicherung der Quelle. |
| `progression` | `progression`, ProgressionService | Bestehende Validierung, Pflichtversionsprüfung und Importmigration; keine erneuten Belohnungen. |
| `regions` | `regions_by_body`, historisch `regions_by_world` | Seed-Zuordnung über den vorhandenen Körperadapter, danach Übernahme körpergebundener Regionsdaten. |
| `player` | `player` | Gesicherte Bedürfnisse, Ausdauer und Pose werden als ausstehender Laufzeitzustand übernommen; Anwendung erst über verfügbaren Host. |

## Körperbausteine

Alle nachfolgenden Bausteine sind Bestandteil des einen GameState-Snapshots. `validate_body` und `unsupported_body` laufen über dieselbe feste Liste. Nicht registrierte zusätzliche Körper-Dictionaries mit `schema` werden gesperrt; `surface_context` ist als zentral geprüfte Orts-/Identitätshülle ausgenommen. Unversionierte Identitäts-/Beschreibungsfelder werden weiterhin durch den Körperbesitzer erhalten.

| Baustein | Aktuelle Version / bestehender Adapter |
|---|---|
| `village_simulation`, `visit` | Je 1; vorhandene Simulations- bzw. Besuchsprüfung |
| `home_group` | 2 radial, 1 planar; HomeGroupState |
| `legacy_population`, `wildlife_foraging`, `wildlife_drinking`, `surface_ecology` | Je 1; bestehende Fachvalidatoren |
| `fauna_catalog` | 4 mit alten 1/2/3-Adaptern; PlanetFaunaCatalog einschließlich Unterversionen |
| `surface_population` | 2 segmentiert, 1 inline; PopulationState und RegionStore einschließlich dessen Zukunftsschutz |
| `domesticated_animals` | Kampagnenhülle 1, bestehendes D2-Register; CampaignAnimalState prüft auch Herkunft und Bürgertrennung |
| `exploration_atlas`, `legacy_exploration_atlas` | 3 aktuell, alte 1/2 lesbar; ExplorationAtlas. Das planare Archiv wird weiterhin durch Surface geprüft. |
| `tribe` | 6 radial, bis 5 planar; TribeState und bisheriger Wirtschaftsversionswächter |
| `tribal_neighbor` | 3 radial, alte 1/2; NeighborState |

Die bisherige `Tribe.upgrade`-Schleife läuft über `migrate_bodies`, nach Validierung und Quellsicherung. Andere Teilnehmer behalten ihre bisherigen unterstützten alten Repräsentationen bzw. ihre vorhandenen Import-/Leseadapter. Es gibt keine automatische Normalisierung beim Inspektieren eines Slots. Kampagnenidentität, Beziehungen zwischen Fachmodulen, Oberflächenadressen, Quellarchive und bestätigte Nachbarbelohnungen werden weiterhin zentral geprüft.

## Neue Module anschließen

1. Bestehenden Datenbesitzer beibehalten und in `SECTIONS` bzw. `BODY_SECTIONS` aufnehmen. Körperbausteine erhalten keine zweite Top-Level-Kopie.
2. Snapshot-/Importports und die tatsächliche Validierung ergänzen; unterstützte Version, Zukunftsschutz und expliziten Migrations-/Erhaltungspfad festlegen. Unbekannte Adapter werden nicht still übersprungen.
3. Körperübergreifende oder fachübergreifende Invarianten zentral prüfen, soweit sie einen gemeinsamen Abschluss benötigen. Keine Schreiboperation im Teilnehmeradapter einführen.
4. Roundtrip, Zukunftsversion und Schreibfehler des betroffenen Ablaufs prüfen. Neue Tests genau einmal im bestehenden Vertragskatalog registrieren.

## Prüfung und Integrationsgrenzen

Die neue `save_participants_test` prüft Registrierung/fehlende Ports, echten gemeinsamen Snapshot, Überschreiben veränderter Laufzeitdaten durch Laden, einen getrennten Godot-Prozess, alle 14 Körper-Versionswächter, Fortschritts-Zukunftsschutz, unbekannte Top-Level-/Körperbausteine sowie unveränderte Original-/Backupbytes. Sie prüft auch die ausdrücklich erlaubte unveränderte Weitergabe optionaler zukünftiger Guide-Daten. JSON-Zahlen werden beim Vergleich nach demselben JSON-Roundtrip verglichen; die unterschiedliche int/float-Laufzeitrepräsentation ist kein Datenverlust.

**Abschluss: 19/19 ausgewählte Godot-Tests bestanden**, zusätzlich Editorimport, Art-Quellenprüfung und Vertrags-/Sprachgate. Enthalten sind alte Save-/Slot-/Schreibfehlertests, Körperidentität, Phasenübergabe, Bauplanversionen, Karte, D2, Dorfwirtschaft/Milch, Nachbarn, Fortschritt, Regionsskalierung, regulärer Kugelstart und entwickelter Kugelumzug mit tatsächlichem Tierbesitz, Fracht und getrenntem Neustart. Die letzte Kugelmigrationsprüfung bestand in 57,673 Sekunden. Die Abschlussprüfung und exakte Quellversion stehen in `docs/evidence/arch07/results.json`; die Protokolle der neuen Registrierung und des entwickelten Neustarts liegen daneben. Sie verwendet Godot 4.6.3 und isolierte Nutzerverzeichnisse. Der Testkatalog enthält nach der Erweiterung 152 Tests; die gezielte Fachabnahme ist keine Behauptung eines erneuten vollständigen 152-Test-Laufs.

Wiederholung: `python3 tools/validate_godot.py --godot /pfad/zu/Godot-4.6.3 --skip-main --tests` mit den 19 Namen aus `results.json.selected_tests`. Der Runner isoliert Nutzerverzeichnisse und prüft vollständige Fehlerprotokolle.

Geänderte Dateien: `autoload/save_game_service.gd`, neue Registrierung und Test einschließlich `.uid`, `tools/validation/contracts.json`, Roadmap, Arbeitsverteilung, Architekturliste, Modulvertrag, dieses Dokument und Prüfergebnisse.

ARCH-06 muss mit der zentralen Save-Datei sequenziell integriert werden: Der JSON-Schreiber und Ortsmodelle wurden hier nicht geändert. Falls ARCH-06 zusätzliche Fachvalidierung in den bisherigen Inline-Zweigen ergänzt, muss diese in den entsprechenden registrierten Adapter übernommen werden; aktuelle Schema-/Koordinatenregeln nicht mit den alten Zweigen überschreiben. ARCH-22 verwendet weiter denselben TribeState-/Wirtschaftsvalidator; Eierproduktion und Tierhaltung wurden hier nicht umgebaut. Andere unfertige Fachbranches wurden nicht übernommen.

Grafik, Windows-Export, lange Reise und Ziel-PC-Leistung sind keine Abnahme dieser Architekturänderung. Die bestehenden Versionswächter werden übernommen; diese Lieferung behauptet keine allgemeine Absicherung jedes bislang unversionierten Metadatenfelds.
