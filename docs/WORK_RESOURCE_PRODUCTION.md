# ARCH-20 – Gemeinsamer Ressourcen- und Produktionsvertrag

Stand: 10. September 2026. Basis: `ea900f2` (veröffentlichter `main`, PR #48). Fachbranch: `agent/arch20-production-contract-2026-09-10`. Implementierungscommit: `a1ff333e69eda85f803aa68881d82d7ee5ca23f4`. Dieses Paket ist separat zu integrieren; ARCH-23/Baupläne werden nicht übernommen.

## Gelieferter Umfang

Die bestehende D3-Milchproduktion benutzt einen allgemeinen Ressourcenbatch. Abholen, Fracht, Einlagern und Verbrauchen richten sich nach `resource_id`; dieselben Regeln laufen in `village_work.gd` für nahe und entfernte Bewohner. Der physische Controller bestätigt weiterhin den tatsächlichen Weg und die Ankunft. Produktion, Beleg und offene Ladung bleiben innerhalb desselben Kampagnenabschlusses samt bestehendem Rollback bei Schreibfehlern.

Es gibt keine neue Tierverwaltung, keine zweite Speicherung und keine Eierproduktion. Ressourcen/Rezepte sind feste Datenkataloge; fremde Rezept-IDs oder Revisionen werden nicht dynamisch ausgeführt.

## Datenbesitzer und Anschlüsse

| Daten / Aufgabe | Einziger Besitzer / Anschluss |
|---|---|
| Ressourceneinheiten, Nährwerte, Anzeige-/Icon-Schlüssel, Frachtfarben | `world/tribe/resource_catalog.gd`, Revision 1, reine Definitionen |
| Rezept, Eignungsvoraussetzungen und Verarbeitung bestehender D1-Parameter | `world/tribe/production_catalog.gd`, `husbandry.milk` Revision 1 |
| Art, Körperrevision, Tieridentität, Besitz, Befehle | Vorhandene D1-/D2-Verträge; `husbandry_source.gd` liest nur |
| Futter, Wasser, angebrochener Zyklus, kumulierte Produktion, Ausgabezähler | Vorhandene `tribe.husbandry`-Daten; `village_husbandry.gd` |
| Annahmebelege, offene Abholung, Vorräte und Verbrauch | Vorhandene `tribe.economy`, `tribe.stock`, `tribe.members` |
| Atomarer Abschluss, Laden, Versionssperre und Backup | Bestehender `SaveGameService`; ein zusätzlicher Aufruf des Wirtschaftsschutzes |
| Einmalige Nah-/Fernzuständigkeit und Simulationszeit | Bestehende `village_simulation.gd` / Kampagnenzeit |

`ResourceCatalog` liefert die vorhandenen sechs IDs: `wood`, `stone`, `food`, `water`, `fiber`, `milk`. Nahrung und Milch sättigen weiter um 25, Wasser stillt Durst um 30. Ein Milchvorrat entspricht weiter einem Liter; Material und Wasser behalten ihre abstrakten Bestandseinheiten. Lagerkapazität bleibt 48 je Ressource. Deutsche Titel und Frachtfarben verwenden die Katalogwerte. Die Anzeige-/Icon-Schlüssel sind der Anschluss für die gemeinsame Präsentation; zusätzliche Übersetzungen oder neue Icon-Grafiken gehören nicht zu diesem Paket.

## Ressourcenbatch 2

| Feld | Bedeutung |
|---|---|
| `schema` | `2`; bisheriges Milchformat `1` bleibt lesbar |
| `resource_id`, `resource_revision` | Bekannte Ressource und Revision (`milk`, `1`) |
| `recipe_id`, `recipe_revision` | Bekanntes Rezept (`husbandry.milk`, `1`) |
| `source_id` | Bestehende Produzenten-ID; bei D3 die unveränderte Tier-ID |
| `body_id`, `faction_id` | Annahme nur auf demselben Körper und für denselben Besitzer |
| `sequence` | Fortlaufende Ausgabenummer dieser Quelle; Beginn bei 1 |
| `receipt_id` | Deterministisch aus Körper, Quelle und Sequenz; unabhängig von Position/Ursprung |
| `amount` | Ganze transportierbare Einheiten, 1–48 je Ausgabe |
| `position` | Vorhandener validierter Ortsvertrag: historisch planar oder radial auf dem Dorfkörper |
| `remaining` | Nur bei offener Fracht im Posteingang; nicht Teil des unveränderlichen Belegs |

`ResourceBatch.create` erstellt das deklarative Angebot. `Economy.receive_batch` prüft es, reserviert Kapazität einschließlich bereits getragener und wartender Ware und speichert den Beleg. Identische Wiederholung der letzten Sequenz wird ohne Mutation quittiert; veränderte Wiederholung, Reihenfolgelücke, fremder Körper/Besitz oder unbekannte Revision wird abgelehnt. Alte Sequenzen hinter dem letzten Beleg werden abgelehnt. Eine Quelle besitzt aktuell einen Rezept-/Ressourcenstrom; eine spätere Umwidmung braucht einen ausdrücklichen Vertrag.

`Economy.pickup` findet die passende Ressource. `collect` prüft freien Träger, Kapazität und tatsächliche Nähe erneut und verschiebt genau eine Einheit aus dem Posteingang in die vorhandene Bewohnerfracht. Die bestehende Ankunftsregel lagert sie ein und erzeugt das gemeinsame Lieferereignis. `food_kind`/`consume` verwenden Katalogwerte; gemeinsame Mahlzeit-/Fortschrittsereignisse bleiben erhalten. Auf heißen Lesewegen werden keine JSON-Kopien oder Beleg-Hashes je Tick erzeugt.

## Altstände und Grenzen der Migration

Das Dorf-, Wirtschafts- und Haltungsformat wird nicht neu nummeriert. Das eigenständig versionierte Batchformat wird additiv unterstützt. `ResourceBatch.canonical` ist die reine, geprüfte Migration einer Lesekopie: Milchbatch 1 erhält Resource-/Recipe-Referenz und stabile Beleg-ID. Originaldaten, bestehende letzte Belege und alte offene Batches werden beim Lesen nicht umgeschrieben. Die nächste tatsächlich angenommene Ausgabe verwendet Batch 2. Alte und neue Batches dürfen zusammen in der begrenzten Warteschlange liegen.

Die bisherigen Felder `milk_received` und `milk_meals` bleiben die autoritativen Speicherfelder. Katalogzugriffe bilden allgemeine Mengen-/Verbrauchsanfragen darauf ab; es gibt keine parallel geführten Zähler. Ebenso bleiben die gespeicherten D1-Parameter und `clock`, `cycles`, `produced`, `pending_milk`, `handed_over`, `sequence` erhalten. Das Rezept wird daraus als Lesekopie aufgebaut. Erzeugte Einheiten bleiben `floor(cycles * milk_yield)` ohne Aufrundung; damit gehen auch Ausbeuten unter einem Liter nicht verloren. Große Ausbeuten werden nach freier Lagerkapazität in mehrere Belege geteilt.

Unbekannte Batch-/Ressourcen-/Rezeptrevisionen sperren den bestehenden Save-/Backup-Pfad vor einem Rückfall auf einen älteren Stand. Beschädigte Mengen, doppelte offene Batches und Widersprüche zwischen letztem Beleg und offener Ausgabe werden verworfen. Original-/Backup-Dateien bleiben beim Versionsfehler unverändert.

## Prüfung

Godot 4.6.3, Linux, headless; isolierte Nutzerverzeichnisse. Headless-Prüfungen sind keine Sicht-/Leistungsabnahme auf Lars' Ziel-PC.

- Frischer Editorimport ohne Parser-/Ladefehler.
- `resource_production_contract_test.gd`: unabhängig konstruierter Altbatch 1, reiner Adapter, gemischte Batchversionen, falsche/neuere Referenzen, unveränderte Wiederholung, manipulierte offene Lieferung, echter Prozessneustart mit 3 abgeschlossenen Viertelliterzyklen plus halbem begonnenem Zyklus und pausierter Milchfracht. Fortsetzen erzeugt genau einen Liter. Allgemeine Abholung, Lieferung, Verbrauch und Mengenbilanz werden geprüft.
- Derselbe Test prüft die verschachtelte Save-Versionssperre einschließlich tatsächlichem Lade-/Schreibversuch bei vorhandener älterer Sicherung und Erhalt beider Dateien.
- Bestehende `tribal_age_economy_contract_test`, `tribal_age_husbandry_contract_test` und `tribal_age_economy_test`: bestanden; einschließlich 100-Liter-Ausgabe in Teilbatches und Bruchteilen knapp unter einem Liter.
- Bestehende `tribal_age_husbandry_test` plus separater Neustart: bestanden. Tatsächliche Versorgung und Milchfracht, unterbrochene Aufträge, fehlender/geänderter D1-/D2-Anschluss, Schreibfehler mit Rollback und Wiederanlauf bleiben erhalten.
- `far_simulation_test`: bestanden; gemeinsame Milchfracht über Fern-/Nahübergabe, blockierte Fracht, eindeutiger Besitzer, Pause-/Menü-/Offline-Sperre und Prozessneustart.
- `spherical_developed_migration_test`: bestanden; entwickelte Altstände behalten Heimat, Bewohner, Hütte, Nachbarn, Tierplatz, angebrochene Produktion, offene Milch und Materialfracht nach dem Kopierumzug.
- `spherical_gameplay_test`: bestanden; gemeinsame radiale Bevölkerung, Dorf, D1→D2→D3, versorgter Tierplatz, echte Milchfracht, blockierter beladener Träger, Ursprungswechsel und frischer Prozess. Abschlussmarker nach 333,9 Sekunden. Das ersetzt keine vollständige M1i-/Ziel-PC-Abnahme.

[Ergebnisse und Rohprotokolle](evidence/arch20/results.json) liegen bei der Übergabe. Neun gezielte Prüfungen sowie der abschließende Editorimport sind bestanden.

Die neue Testdatei wird vom vorhandenen `godot-validate.yml` automatisch als Source-Test gefunden. Keine weitere CI-Struktur nötig.

## Anschluss für ARCH-21 / ARCH-22

ARCH-21 ergänzt die Eierrolle und erreichbare Art am bestehenden D1-Vertrag. ARCH-22 ergänzt anschließend eine feste Ressourcen-/Rezeptdefinition, einen versionierten Haltungs-/Legestellenzustand und passende Aufträge. Der allgemeine Batch-/Fracht-/Verbrauchsweg wird weiterverwendet. Neue gespeicherte Zähler oder Produzentenzustände benötigen geprüfte Migration und Versionsschutz; kein zweiter Tierbestand und keine zusätzliche Save-Datei. Die bestehenden Milch-Speicheradapter bleiben bis zu einer ausdrücklich geprüften Migration erhalten.

Unverändert offen: vollständige M1i-/Ziel-PC-Abnahme, weitergehende Langzeit-/Regionsbudgets, zusätzliche Siedlungen und sämtliche Eierinhalte. ARCH-23 bleibt beim anderen Fachchat.

## Veröffentlichungsstand

Lars hat den Upload dieses fertigen Branches in `MajorDragonfly/voxelverse` und die Erstellung eines separaten PR gegen `main` ausdrücklich freigegeben. Die Implementierung, neun gezielte Prüfungen und die Übergabe sind abgeschlossen. Die Integration in den Hauptzweig erfolgt separat nach Prüfung des PR; dieses Paket führt keinen automatischen Merge aus.
