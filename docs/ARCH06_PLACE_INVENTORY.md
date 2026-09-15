# ARCH-06 – Inventar persistenter Fachorte

Geprüfte Basis: `bb2f83b56267964baa7037720c4daca26fe3d007`.
Aktualisierung durch den [Präzisionsauftrag](WORK_ARCH06_COORDINATE_PERSISTENCE.md).
Dies konkretisiert das [Besitzerinventar](MODULE_CONTRACTS.md), ohne einen
zweiten Orts-, Tier- oder Speicherdienst einzuführen.

## Gemeinsamer Ortsvertrag

Ein dauerhafter Oberflächenort ist ein JSON-Dictionary mit `mode =
cube_sphere_m1_v1`, `body_id`, `face`, `u`, `v`, `height`. `face` bezeichnet eine
der sechs Würfelflächen; `u`/`v` sind normierte Flächenkoordinaten, `height` die
Höhe in Metern. Die Fachorte von Heimat/Dorf/Tieren enthalten zusätzlich den
Körperradius für lokale Entfernungstests. Beim Spieler stammt der Radius aus
`body.surface_context`.

`CubeSphere` rechnet globale kartesische Orte als Arrays aus skalaren Doubles.
Erst nach Abzug des lokalen Ursprungs wird ein `Vector3` erzeugt. Die bestehende
`GameplaySpace.encode()/resolve()`-Brücke verbindet diese Orte mit der Szene;
`track()`/`untrack()` und der radiale Adapter besitzen die Ursprungskorrektur.
Höhe, Wasser, Normale und Bodenbereitschaft stammen aus demselben Adapter.

`SurfaceContext.player_problem()` und `validate_places()` prüfen
Körperzugehörigkeit, Modus, Wertebereiche und gegebenenfalls Radius. Daneben
prüfen die Fachvalidatoren ihre eigenen Felder und erreichbaren lokalen
Entfernungen. `validate_places()` durchsucht JSON-Daten, ist aber allein kein
vollständiger Validator ausgelagerter oder noch unregistrierter Fachmodule.

Planare Altorte sind ausdrücklich Arrays `[x, y, z]` mit
`legacy_plane_v9`. Die reguläre Kampagne bleibt kugelförmig. Die bestehenden
Kopiermigratoren behalten Originaldaten und erzeugen Quell-/Zielzuordnungen;
fehlende Herkunft oder ungeeignete Zielbereiche werden nicht erraten.

## Aktuelle Felder und Besitzer

`S` ist der vollständige Save, `B` der über seine `body_id` adressierte
Körper in `S.game_state.campaign.bodies`. Alle regulären dauerhaften
Veröffentlichungen enden beim gemeinsamen SaveGameService.

| Fachbereich | Dauerhafte Ortsfelder / Version | Besitzer, Prüfung und Laufzeitanschluss |
|---|---|---|
| Körper/Start | `B.surface_context.spawn`; Oberflächenkontext Schema 1, Ortsmodus v1 | `SurfaceContext` prüft Radius, Körper und Startort; `CubeSphere`/`PlanetSurfaceFactory` liefern Geometrie |
| Spieler | `S.player.surface_address`, `surface_forward`, `surface_velocity`, `surface_pitch`; gemeinsames Save-Schema | Aktiver Spieler exportiert; SaveGameService publiziert und prüft über `player_problem()`; Richtung/Geschwindigkeit sind Vektorkomponenten, keine globalen Orte |
| Körperbesuch | `B.visit.player` mit denselben Oberflächenfeldern | SaveGameService/SessionFlow sichern den Quellcheckpoint und rekonstruieren das Ziel; erst nach Kollisionsbereitschaft übernehmen |
| Heimat/Gefährten | `B.home_group.anchor`, `members[].position`; Schema 2 radial, Schema 1 planar | `HomeGroupState`/Controller; `Home.place_valid()`, körpergleicher Radius, `GameplaySpace`; Gefährten-ID bleibt erhalten |
| Wilde Tiere/Pflanzen | `B.surface_population`: Schema 1 inline, Schema 2 mit `storage`; Regionsobjekte `location`, Tiere zusätzlich `home` | `CampaignPopulation`, `CampaignRegionStorage`, `CampaignEcology`; Cube-Zellenschlüssel und Objekt-ID; neue Regionsblobs verwenden präzise JSON-Zahlen |
| D1-Artenvorkommen | `fauna_catalog.surface.anchor`; Habitate `position`, `food_position`, `path[]`; Oberflächengraph `location`; Habitat-Schema 2, migrierter Vertrag 3 | `DomesticSurfaceContract`/Planner und vorhandener Katalog; erreichbare Route und Körper prüfen; vorhandenes deterministisches Dezimalraster bleibt erhalten |
| D2-Tiere | `B.domesticated_animals.registry.animals[id].position`, `home`, `wait_position`; Hülle Schema 1, Register Schema 2 radial/1 planar | `AnimalState` und `CampaignAnimalState` validieren; DomesticationController besitzt Bindung/Befehle, Host publiziert; kein zweiter Tierbesitzer |
| Dorf/Bewohner | `B.tribe.anchor`, `members[].position`, `destination`; Schema 6 radial, 5 planar | `TribeState`/TribeController oder vorhandene Fernsimulation; `Home.local_place()`, gemeinsame Navigation; Ankunft wird durch den aktiven Besitzer bestätigt |
| Bauwerke/Baustellen | `tribe.sites[]`, `project.position`/`entrance`, `housing.homes[].position`/`entrance` | `VillageHousing`, `TribeState`, Controller; Projekt und bewohnbares Haus bleiben unterschiedliche Zustände; Körper und freier Eingang werden fachlich geprüft |
| Ressourcen/Arbeitsplätze | `tribe.deposits[kind].position`, `economy.stations`, Ziel am Bewohner | `VillageEconomy`/`VillageWork`; Stationsbezug und tatsächlich angekommene Arbeit; gemeinsamer Vorrat bleibt autoritativ |
| Tierplätze/Milchfracht | `husbandry.pens[].position`/`entrance`, `husbandry.records[id].pickup`; Trägerposition/-ziel am Dorfbewohner | `VillageHusbandry` und `VillageWork`; Pflege-/Batch-/Frachtidentität bleiben getrennt vom Ort und gemeinsam gespeichert; ARCH-22 erweitert diesen Anschluss separat |
| Eigene Nachbarfraktion | `tribal_neighbor.anchor`, `foundation[]`, `members[].position`/`workplace`; Schema 3 radial, 2 planar | `NeighborState`/Runtime; Hilfsfracht verweist über Lieferetappe auf Heimat- bzw. Nachbardorfanker, Träger bleibt Dorfbewohner |
| Erkundung/bekannte Orte | Atlas Schema 1 inline, 2 Kartenpaging, 3 Ortspaging; `places[id].address`, ausgelagerte `entry.place.address`; Kartenzellen/-ausdehnung sind diskrete Indizes | `ExplorationAtlas`, `AtlasPlaceStore`, `SurfaceMapProjection`; Körper/Modus prüfen; alte Kacheln und Orte bleiben unter ihren existierenden Regionswurzeln lesbar |
| Entwickelter Kopierumzug | `surface_migration` mit Regionen sowie `places` aus `source`/`target`; archivierter Quelltext bleibt unverändert | `SphericalPlaceMigration` wandelt bekannte Felder explizit um, repariert Eingänge und prüft Zielbereiche; `SphericalMigration` erhält historische Fingerprints |
| Schiffe/Personen/Fracht | Nur ARCH-30-Prüfentwurf: diskriminierte `system`-, `surface`-, `dock`- und Innenraum-/Besitzbezüge | `tests/fixtures/expedition_contract_draft.gd`; Systemorte verwenden skalare Double-Arrays, Oberflächenorte Cube-Adressen; noch kein produktiver M9-Saveanschluss |

## Bewusst getrennte Daten

- Bauplangeometrie, Körperanschlüsse, Sattel-/Geschirrpunkte und lokale Mesh-/Kameratransformen sind lokale Maße. Sie erhalten keine künstliche `body_id` und werden bei der Kopiermigration nicht als Landschaftsorte verschoben.
- Die Tierquelldaten `heading`/`preview_offset` sind Darstellungsdaten. Der persistente Aufenthaltsort bleibt im jeweiligen Tierregister.
- Arbeitsfortschritt, Fracht, Batch-ID und Vorrat sind Fachzustand. Eine Zieladresse allein ersetzt weder Reservierung noch tatsächliche Ankunft.
- Alte Begegnungs-/Futter-/Trinkregister können nur Objektkennungen ohne vollständigen Herkunftsort enthalten. Der vorhandene Umzug verlangt einen auflösbaren Herkunftsnachweis; ARCH-14s verbleibende Registerarbeit wird hier nicht vorweggenommen.
- Ein Kartenraster ist absichtlich gröber als eine Körperadresse. Die präzisere Serialisierung ändert weder Erkundungsauflösung noch Kartenwissen.

## Verbleibende Anschlüsse

1. ARCH-07 führt die bestehenden Save-Teilnehmer hinter eine feste Registrierung. Die hier erfassten Felder müssen dabei ihre Validatoren, Import-/Exportanschlüsse und Versionssperren behalten.
2. ARCH-26/27 brauchen identifizierte Siedlungsinstanzen und Frachtziele, bevor mehrere eigene Orte produktiv verbunden werden. Heute gibt es keinen unabhängigen allgemeingültigen Frachtzielvertrag.
3. D4/Reiter/Pflug benötigen ihre realen Zustands- und Übergabeorte; ein Körperanschluss oder geeigneter Artkatalog ist noch kein gesicherter Reiter/Pflug.
4. ARCH-30 braucht einen produktiven Teilnehmer, Flug-/Landungs-/Dockingbesitzer und Übergabeintegration. Die bestandene Serialisierungsprobe allein schaltet das nicht frei.
5. Bei jedem neuen Fachort: Körper-/Objektidentität und Ortsformat nennen, bekannte und zukünftige Versionen validieren, Szenenkoordinaten erst am Adapter auflösen und gemeinsame Save-/Neustart-/Fehlerfälle nachweisen.
