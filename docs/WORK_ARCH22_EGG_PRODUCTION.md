# ARCH-22 – Eierproduktion im gemeinsamen Stammesdorf

Stand: 10. September 2026. Basis: `bb2f83b56267964baa7037720c4daca26fe3d007` (`main`, nach PR #77). Fachbranch: `agent/arch22-egg-production-2026-09-10`. ARCH-06/07/13/14/17/24/25 und weitere parallele Facharbeiten werden nicht übernommen. Implementierung veröffentlicht als `68bf25e0f39175c96c29c42dae027e2fb9105d56`; Dateibaum `b6d44cf52b45e76b127e807ec6d85a9f1519cfbe` stimmt exakt mit dem lokalen Implementierungscommit `fb39c01409a252f9756a99b1e5387376bb184d2e` überein. Die Fachbranch-Lieferung ist separat in `main` zu integrieren.

## Umfang und Bedienung

Ab Stammesphase kann ein tatsächlich gezähmtes D1-Tier mit Rolle `eggs` an einer Legestelle gehalten werden. Im gemeinsamen Dorfpanel unter Tierhaltung eine Legestelle bauen, das Tier über D2 hinführen und warten lassen, den Platz auswählen und das passende Tier zuordnen. Tierpfleger bringen vorhandenes Futter und Wasser; Eierträger sammeln die Ausgabe und bringen jede Einheit ins gemeinsame Lager. Erst dort steht sie als normale Mahlzeit zur Verfügung. Das Panel zeigt Eierbestand, passende Kandidaten und Produktionsstatus. In der Welt kennzeichnen ein kleines Voxel-Nest und Eier die Legestelle und abholbare Ware.

Milch- und Legestellen teilen weiterhin die bestehende Grenze von zwei Tierplätzen. Eine Legestelle kostet wie der Milchplatz vier Holz und zwei Fasern und braucht denselben Werkzeug-/Bauanschluss. Ein leerer bezahlter Platz lässt sich über „Freien Platz umstellen“ umnutzen. Identität, Standort, Versorgung und bisherige Produktionsbelege bleiben erhalten. Belegte Plätze und Plätze mit laufender Versorgungsfracht sind gesperrt; fehlgeschlagene Speicherung rollt die Änderung zurück. Damit blockieren zwei alte Milchplätze den neuen Inhalt nicht dauerhaft.

## Verträge und Datenbesitzer

| Teil | Vertrag und Verhalten |
|---|---|
| D1 und D2 | Bestehende Art-Eignung, Individuen, Besitz, Befehle und gespeicherte Körperrevision. Der D3-Leseanschluss verlangt die zum Platz passende Rolle, Pflanzennahrung und gültige Mengen/Intervalle; kein neues Tierregister. |
| Ressource | `eggs`, Revision 1, Stück; Sättigung 25, keine Durstwirkung, Lagergrenze 48 einschließlich reservierter Fracht/offener Abholung. Bestehende Ressourcenrevisionen bleiben erhalten. |
| Rezept | `husbandry.eggs`, Revision 1. Menge/Intervall stammen aus `egg_yield`/`egg_interval`; D1 liefert derzeit ein Ei je 300 aktive Spielsekunden. Ein Futterpunkt und `water_need` Wasser je 300 versorgte Sekunden. |
| Dorf / Unterformate | Dorf radial 6, historisch planar 5 unverändert; Wirtschaft und Tierhaltung von 1 auf 2, Wohnraum unverändert 1. Unterstützte Altformen bleiben lesbar. |
| Produktionszustand | Bestehendes `husbandry.records[animal_id]`: D1-Snapshot, `clock`, `cycles`, `produced`, `handed_over`, `sequence` und Abholort. Eier verwenden `pending_output`; alte Milchdatensätze behalten ausschließlich `pending_milk`. |
| Lieferung / Vorrat | Vorhandener Ressourcenbatch 2 und gemeinsame Annahmebelege. `stock.eggs`, `economy.eggs_received` und `economy.eggs_meals` sind die autoritativen Eierfelder; Fracht liegt weiterhin am Bewohner. |
| Arbeit / Simulation | Gemeinsames `VillageWork` für Sammeln, Tragen, Lieferung und Essen; vorhandene `VillageSimulation` mit genau einem Nah-/Fernbesitzer und Kampagnenzeit. |
| Speicherung | Bestehender `SaveGameService` bleibt alleiniger Writer; sein Zukunftsversionsschutz umfasst jetzt auch die verschachtelte Haltung und gespeicherte Rezeptrevisionen. |
| Fortschritt | Eierlieferung und Eiermahlzeit fließen in die bestehenden begrenzten Wirtschaftsnachweise ein. Wiederholte Produktionszyklen schaffen keinen neuen unbegrenzten Punktepfad. |

Versorgung und tatsächliche Anwesenheit am richtigen Platz sind erforderlich. Fehlendes Futter/Wasser hält den angebrochenen Zyklus an; Pause, Editorpause und geschlossene Anwendung liefern keine Produktionszeit. Ein ausstehender voller Produktionsbatch bremst weitere Ausgabe, Versorgungskosten laufen bei aktiver, anwesender Haltung weiter. Große Ausbeuten werden kapazitätsgerecht aufgeteilt. Ein Ei wird erst über den bestehenden körperlichen Abhol-/Ankunftspfad eingelagert. Tod oder fehlende Eignung stoppt weitere Produktion; bereits erzeugte Nahrung bleibt erhalten.

## Migration und Mengenschutz

Auch ein bereits aktuelles Dorf Schema 6 erhält die ausdrücklich versionierte Migration seiner alten Wirtschafts-/Haltungsunterformate. Sie ergänzt nur die drei leeren Eierfelder und erhöht die beiden Unterversionen. Alte Milchbelege, Tier-/Platz-IDs, Bewohner, Fracht, Bruchteile und angefangene Zyklen werden nicht normalisiert oder neu erzeugt. Wiederholte Migration ist wirkungslos. Alte Milchbatches 1 und aktuelle Ressourcenbatches 2 bleiben zusammen lesbar.

Die Produktion prüft `produced = pending + handed_over`. Für angenommene Eier gilt zusätzlich exakt `received = offene Abholung + Fracht + Lager + gegessene Eier`. Doppelte Ausgabezähler, falsche Ressourcenbelege, ungültige Werte, fehlende Einheiten und unpassende Tier-/Platzbezüge werden abgelehnt. Schema 1 akzeptiert keine nachträglich eingeschmuggelte Eierproduktion. Neuere Wirtschafts-, Haltungs- oder Rezeptversionen sperren Laden und Schreiben einschließlich Rückfall auf ein älteres Backup; beide Dateien bleiben unverändert.

## Prüfungen

Godot `4.6.3.stable.official.7d41c59c4`, Linux, Headless-Quellprojekt mit getrennten Nutzerverzeichnissen. Alle **13 gezielten Tests bestehen**. [Maschinenlesbare Ergebnisse](evidence/arch22/summary.json), SHA-256-Prüfsummen und komprimierte Originalprotokolle stehen unter `docs/evidence/arch22/`.

- `egg_production_contract_test`: ausdrücklich konstruierte Altformate, erhaltene Viertelliterzyklen, gemischte Milch-/Eierhaltung, ungeeigneter Platz, 100-Eier-Ausgabe mit 48/52-Aufteilung, volles Lager, pausierte Fracht, fehlende/doppelte Mengen, Tierverlust und alleiniger Simulationsbesitzer. Ein echter neuer Prozess lädt die unterbrochene Fracht, liefert, isst und setzt die offene Ausgabe ohne neuen Zyklus fort. Nah-/Fernproduktion werden über 305 Kampagnensekunden verglichen. Tatsächliche Save-/Backup-Versionssperren werden mit Bytevergleich geprüft.
- `egg_husbandry_ui_test`: reale Panel- und Platzierungseingaben, Materialtransport, Bauabschluss, Tierfilter und Zuordnung, Umwidmung sowie Rollback bei Schreibfehler. Bediengeometrie und Scroll-Erreichbarkeit bei 1280 × 720 und 800 × 600. Die begrenzte historische Laborumgebung stellt D1/D2 bereit; sie ist keine reguläre Flachweltkampagne und ersetzt nicht die Kugelprobe.
- Bestehende Regressionen: `resource_production_contract_test`, `tribal_age_husbandry_contract_test`, `tribal_age_husbandry_test`, `tribal_age_economy_contract_test`, `tribal_age_growth_contract_test`, `village_work_snapshot_test`, `far_simulation_test`, `tribal_economy_progress_test`, `tribal_progression_test` und `spherical_developed_migration_test` bestehen. Damit bleiben insbesondere reale Milchversorgung, Milchfracht, Altstandmigration und die gemeinsamen Arbeits-/Fortschrittspfade abgedeckt.
- Editorimport, Art-Quellenprüfung und Vertragszuordnung bestehen. Die drei neuen Tests sind jeweils genau einmal registriert: insgesamt 154 Tests in 17 Verträgen. Das ist die Registry-Größe, keine Behauptung einer ausgeführten vollständigen 154-Test-Suite.
- `spherical_egg_production_test` besteht auf dem abschließenden Quellstand in **424,189 Sekunden**: echte Eierart, Zähmung, Bau, Versorgung, Produktion, blockierte Eierfracht, Schreibfehler-Rollback, A–B–A, zwei frische Prozesse, körperliche Lieferung und Mahlzeit. Auf dem entfernten Körper werden 5,236444 versorgte Sekunden tatsächlich gespielt; bei Rückkehr werden weitere 5,639610667 bereits geschuldete Sekunden exakt mit Futter/Wasser abgeglichen. Warten und Pause liefern die getragene Einheit nicht heimlich ab.

Reproduktion der neuen Abnahme nach frischem Import:

```sh
python tools/validate_godot.py --godot /pfad/zu/Godot_4.6.3 --skip-main --tests egg_production_contract_test egg_husbandry_ui_test spherical_egg_production_test --output /tmp/voxelverse-arch22
```

Die Kugelprobe verwendet den bestehenden vollständigen Gameplay-/Reiseablauf mit dem Parameter `eggs`: echte erzeugte Eierart, Zähmung, Bau, Versorgung, Produktion, blockierte getragene Ware, fehlgeschlagene Abreise, A–B–A, kalte Prozesse und abschließende körperliche Lieferung/Mahlzeit. Sie erzeugt kein künstliches Produktionsregister und verstellt keine Kampagnenzeit.

## Diagnose und verbleibende Abnahme

Frühe Läufe fanden einen Parserfehler sowie einen Vergleich von JSON-Fließkommaschemata mit einer Integer-Liste; beide sind korrigiert. Zwei Testvergleiche wurden auf die tatsächlich serialisierten Werte beziehungsweise unescaped Prozessausgabe korrigiert. Die erste Kugelvorbereitung verlangte pauschal 1,2 m Abstand vom Tierursprung zum Bodenplatz; das aufrechte Eiermodell hat einen höheren Ursprung. Die Probe verwendet hierfür 1,75 m innerhalb der unveränderten tatsächlichen 1,8-m-Zulassungsregel und prüft danach weiterhin echte Anwesenheit. Ein weiterer Lauf verfolgte nach einer Wegblockade einen veralteten Wildtierort. Die Probe löst jetzt den normalen Annäherungsbefehl am aktuellen Tierstandort erneut aus und wartet vor dem Füttern. Diese Vorläufe gelten nicht als bestandene Abnahme.

Grafische Sichtprüfung auf dem Ziel-PC, echte Screenshots und native Exportabnahme sind in dieser Umgebung nicht erfolgt. Die Bedienprüfung misst echte Controls im Headless-Fenster; daraus folgt keine grafische Qualitäts- oder FPS-Zusage. Dorftexte sind wie der bestehende Bereich deutsch; der vollständige DE/EN-Anschluss bleibt ARCH-25. Bebrüten/Zucht, zusätzliche Tierplatzkapazität, mehrere Siedlungen und spätere Epochenübergänge bleiben eigene Pakete. Die reguläre Kampagne bleibt ausschließlich kugelbasiert.
