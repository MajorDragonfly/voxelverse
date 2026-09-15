# ARCH-26.1 – Siedlungsinstanzen: Übergabe

## Auftrag und Stand

Übernommen: **ARCH-26, erstes Teilpaket Siedlungs-/Arbeitsplatzvertrag** aus `NEXT_PARALLEL_WORK.md`, Vorbereitung M6 → M7. Basis ist der veröffentlichte Integrationsstand `bb2f83b56267964baa7037720c4daca26fe3d007`. Branch: `agent/arch26-settlement-contract-2026-09-10`. Code und Vertragsbeschreibung: **`072c701b7b12733156827177e40dd23cb811923b`**.

ARCH-22, -06, -07, -24, -25, -14, -13 und -17 sind laut Lars parallel belegt. Keine fremden Branches wurden übernommen. Zentrale Roadmap und Arbeitsverteilung bleiben für die gemeinsame Integration unangetastet. Dieses Teilpaket ist geliefert und geprüft; die vollständige spielbare ARCH-26-Abnahme bleibt offen.

## Lieferung

- [Siedlungsvertrag 1](SETTLEMENT_CONTRACT_V1.md) mit genau einer autoritativen Dorfstruktur pro Instanz, stabiler ID, getrennten Orten und eigener Auswahl. Das erste Dorf behält seine bisherige `tribe.id`.
- Reine, wiederholbare Kopiermigration: bestehendes radiales `body.tribe` samt `village_simulation` wird im vorbereiteten Körper in die erste Instanz verschoben. Quelle, IDs, Vorräte, Arbeitsfortschritt, Fracht, Baumaterialreservierung, Produktion und sonstige Körpermodule bleiben erhalten.
- Kurzlebiger Instanzadapter für den bestehenden `VillageWork`-/`VillageSimulation`-Kern und ein lesender Arbeitsplatzindex. Zwei gleichartige Arbeitsplätze und Baustellen in **verschiedenen** Siedlungen sind getrennt adressierbar.
- Validator für höchstens zwei Siedlungen und weiterhin insgesamt höchstens sechs Bewohner. Körper-/Radius-/Herkunftsprüfung, eigene Fraktion/Spezies, einmaliger Bewohnerbesitz, genau eine Tierplatz-/Produktionshistorien-/Lieferquellenzuordnung und höchstens ein Nahbesitzer je Körper.
- Bestehende Dorf-/Simulationsprüfungen bleiben die normalen Speicherprüfungen. Neue ausdrücklich benannte Instanzprüfungen teilen ihre Fachbilanzen, ohne bestehende Heimat-/Spieleranforderungen im bisherigen Einstieg aufzuheben.

Es wurde **kein** zweiter Vorrats-, Tier-, Produktions- oder Speicherdienst eingeführt. Der SaveGameService ist nicht geändert und kennt das neue Register noch nicht vollständig. Die Kopie darf deshalb noch nicht in eine laufende Kampagne eingesetzt werden.

## Geänderte Dateien und Integrationsstellen

| Datei | Änderung |
|---|---|
| `world/tribe/settlement_collection.gd` + UID | Neuer Vertrag, Kopiermigration, Validator, gemeinsame Instanzansicht und Arbeitsplatz-Lesemodell |
| `world/tribe/tribe_state.gd` | `validate_settlement` und gemeinsamer interner Validator; alter Einstieg bleibt bestehen |
| `world/tribe/village_economy.gd` | Optionaler expliziter Ressourcen-ID-Besitzer im bestehenden Validator; unveränderter Standard für bisherige Aufrufer |
| `world/tribe/village_simulation.gd` | Ausdrücklicher Instanzvalidator mit Kampagnen-Spieler-ID; Arbeits-/Produktionsschleife unverändert |
| `tests/settlement_collection_test.gd` + UID | Migration, zwei radiale Instanzen, Produktionsduplikate, Bau-/Frachtunterbrechung, atomarer Schreibfehler und echter Neustart |
| `tools/validation/contracts.json` | Test genau einmal dem Dorfvertrag zugeordnet; Abnahmeszenario `settlement_instances` bewusst `partial` |
| `docs/SETTLEMENT_CONTRACT_V1.md` | Format, Besitz, API und erforderliche Folgeanschlüsse |
| `docs/WORK_ARCH26_SETTLEMENT_CONTRACT.md`, `docs/evidence/arch26/` | Übergabe und tatsächliche Prüfnachweise |

Die kleinen Validatorergänzungen in `village_economy.gd` und `village_simulation.gd` sind die gemeinsamen Integrationsstellen mit ARCH-22. Bei dessen Übernahme müssen neue Ressourcen-/Produktionsformate hier weiter vom **gleichen** Fachvalidator geprüft werden; keine ältere Milchschleife aus diesem Branch über neue Eierarbeit kopieren.

## Ausgeführte Prüfungen

Godot **4.6.3.stable.official.7d41c59c4**, Linux, headless, isolierte Nutzer-/Speicherverzeichnisse. [Ergebnisübersicht](evidence/arch26/summary.json). Alle neuen Prüfungen sind im gemeinsamen Vertragsgate registriert.

| Prüfung | Ergebnis |
|---|---|
| Editorimport und Art-Quellen | Bestanden |
| Vertrags-/Sprachgate | Bestanden; 152 Tests in 17 Verträgen, 436 Nachrichten je Sprache |
| `settlement_collection_test` | Bestanden am Codecommit `072c701…`: **86 Bedingungen plus 11 im neuen Prozess** |
| Wirtschaft, Wachstum, Wohnungsbau-Wiederaufnahme, Tierhaltung | Vier bestehende Vertragstests bestanden |
| `resource_production_contract_test` | Bestanden; bisherige Ressourcenbatches/Versionssperren erhalten |
| `far_simulation_test` | Bestanden; bestehende Fernarbeit, Nachbarhilfe, Milch und Pause erhalten |
| `village_work_snapshot_test` | Bestanden; bestehender gemeinsamer Arbeitskern erhalten |
| `spherical_developed_migration_test` | Bestanden; Heimat, Bewohner, Hütte, Nachbarn, Tiere, begonnene Produktion, Milch und Holzfracht erhalten |

Die acht Regressionen liefen vor dem abschließenden Codecommit gegen die hier unverändert übernommenen gemeinsamen Validatoren. Danach wurden ausschließlich der neue isolierte Vertrag, sein Test und seine Dokumentation ergänzt; die neue Prüfung wurde am exakten Codecommit erneut ausgeführt. Import erfolgte vor diesen reinen GDScript-Ergänzungen; der Abschlusslauf hat die finalen Skripte tatsächlich geladen und ausgeführt. Keine erneute Vollsuite behauptet.

Ein zusätzlich eingeführter Beleg-Test verwendete zunächst den Anzeigenamen `milk` statt der vorhandenen Rezeptkennung `husbandry.milk`. Die ungültige Fixture wurde erwartungsgemäß abgewiesen. Der Test verwendet jetzt die Katalogkonstante und besteht; der fehlerhafte Zwischenlauf bleibt im Evidenzverzeichnis nachvollziehbar. Es war keine Änderung an der bestehenden Produktionslogik erforderlich.

Der neue Nachweis prüft konkret:

- unveränderte Quelle und idempotente Migration, auch mit gehaltener Baufracht, Teilzeit und gespeicherter Wegstrecke;
- zwei Siedlungen nahe einer Cube-Flächenkante mit gemeinsamem Facharbeitskern, aber getrennten Brunnen, Baustellen, Lagern und Bewohnern;
- Fertigstellung in A, während B sein blockiertes Holz samt Reservierung behält;
- Neustart mit B-Fracht, gezieltes Fortsetzen bis zu genau einer Fertigstellung und anschließende Naharbeit in A;
- unabhängige Produktionswerte beider Brunnen, Auswahl ohne Teleport oder Simulationswechsel, Pause ohne Zeitfortschritt;
- fehlgeschlagenes atomisches Staging ohne Veränderung des letzten vollständigen Vertragsdokuments;
- Ablehnung unbekannter Versionen, fremder Orte/Fraktionen/Arten, doppelter Bewohner, konkurrierender Nahbesitzer, fremder Baustellenfracht sowie doppelter Tier-/Produktions-/Lieferquellenzuordnung.

Die Neustartdatei ist eine isolierte **Vertragsfixture** über den bestehenden `AtomicJson`-Writer. Sie belegt noch keine neue SaveGameService-Teilnahme. Die Testwege werden als Modellfixture bereitgestellt; es gibt keinen neuen grafischen, Kollisions-, Ziel-PC-, FPS- oder nativen Exportnachweis.

## Nächster Anschluss

1. ARCH-06/07/13 integriert übernehmen und den Siedlungsvertrag als einen vollständigen Save-Teilnehmer mit Zukunftsversionsschutz, Regionsreferenzen, Slot-/History-/Archivkopien und Rollback registrieren. Dafür alle aktuellen `body.tribe`-/`village_simulation`-Verbraucher zusammen umstellen; keine dauerhafte Alt-/Neu-Doppelhaltung.
2. Controller, Fernscheduler, Fortschritt, Körperreise, Karten/UI und Tierhaltung auf die konkrete Siedlungs-ID binden. Die vorhandene Instanzansicht kann Facharbeit anbinden; sie ersetzt keine Lebenszyklusübergabe.
3. Erreichbare zweite Siedlung gründen und Bewohner/Ressourcen atomar zuordnen, ohne Bürger oder Material zu duplizieren. Mehrfachbaustellen innerhalb derselben Siedlung anschließend mit echten gespeicherten Instanzen aufbauen.
4. Erst danach regionale Transporte gemäß ARCH-27 samt Ankunft, Blockade, Reservation und Neustart anschließen.

Mittelalter, Neuzeit, Weltraum und Gebäudeeditor werden durch diesen technischen Vertrag nicht freigeschaltet.

## Veröffentlichungsstatus

Code, Vertragsbeschreibung, Übergabe und Evidenz sind lokal committed. Der Upload von `agent/arch26-settlement-contract-2026-09-10` nach `MajorDragonfly/voxelverse` wurde durch die automatische Freigabeprüfung blockiert: Sie erkannte für die Veröffentlichung von Code, Dokumentation und Testnachweisen am Ziel keine ausdrückliche Nutzerfreigabe. Es wurde kein Umgehungsweg verwendet. Noch kein veröffentlichter Branch oder Pull Request und keine Übernahme in `main` behauptet; Upload und PR bleiben bis zur Freigabe offen.
