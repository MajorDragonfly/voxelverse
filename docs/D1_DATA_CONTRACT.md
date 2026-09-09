# D1 – Art-Eignung, Vertrag 1

Ausgangsbasis: `3a3e027`, gemeinsames main vom 9. September 2026.
Eigentümer: Auftrag 3. Implementierung: `world/fauna/domestication/`.

## Identität und Ablage

Pro Kampagnenkörper liegt ein optionaler `fauna_catalog` in
`game_state.campaign.bodies[world_seed]`. Katalogschema `1`, Generator
`domestic_fauna_v1`, unveränderte `body_id` und vorhandene `species_id(body_id,
species_seed)`-Funktion. Genau drei neue, unterschiedliche Pflichtarten:
`milk`, `work` (Fähigkeiten `draught` und `riding`), `companion`.
Die alten regionalen Seeds, IDs, Rollen, Begegnungen und Entdeckungen bleiben
unverändert. Fehlendes Feld bedeutet Altstand, nicht ungültiger Spielstand.
Neue Arten werden einmal ergänzt. Vorhandene Kataloge und vollständige
Körperentwürfe werden geladen; ein neuer Generator würfelt sie nicht neu aus.
Unbekannte Versionen werden vor Laden und vor Überschreiben abgewiesen,
auch wenn eine ältere Sicherung vorhanden ist.

## `species.domestication`

Die gleiche Eignung steht am Katalogeintrag und im Laufzeit-Blueprint unter
`species.domestication`. Sie beschreibt die Art, niemals Besitz oder Zähmung.

| Feld | Bedeutung / Einheit | Bereich |
|---|---|---|
| `schema` | Vertragsversion | 1 |
| `roles` | Fähigkeiten | milk, draught, riding, companion; ohne Duplikate |
| `tameable` | Grundsätzliche Eignung | true für Pflichtarten |
| `temperament` | Grundtemperament | calm / social |
| `trainability`, `sociality`, `bonding` | dimensionslose Eignung | 0–1 |
| `diet` | Nahrungsklassen der vorhandenen Nahrungssuche | plant / meat |
| `water_need` | Liter je 300 Kampagnen-Sekunden | >0–100 |
| `strength` | nachhaltige Zugkraft, Newton | 0–10.000 |
| `stamina` | Sekunden Arbeit bei Nennlast | >0–3.600 |
| `carry_capacity` | zusätzliche Traglast, kg | 0–1.000; Reiten ≥100 |
| `milk_yield` | Liter pro abgeschlossenem Produktionsintervall | 0–100 |
| `milk_interval` | aktive Kampagnen-Sekunden | Milch ≥1–86.400; sonst 0 |
| `perception_range` | Wahrnehmungsradius, Meter | 0–100 |
| `movement_speed` | unbeladenes Bodentempo, Meter/Sekunde | 0,1–20 |
| `anatomy` | Bodenbewegung, ≥4 Standbeine, Laktation, freier Rücken | geprüfte Körperanforderungen |
| `anatomy.attachment_requirements` | benötigte funktionale Anschlüsse | saddle / harness beim Arbeitstier |

Alle Zahlen sind endlich. `milk` benötigt Laktation und positive Menge/Intervall.
Ein Begleiter benötigt Lernfähigkeit, Sozialität und Bindung jeweils ≥0,75.
Der Generator erzeugt dafür vier Standbeine mit Füßen, einen tragfähigen freien
Rücken beim Arbeitstier und einen beweglichen Körper mit Schnauze und Schwanz
beim Begleiter. Pflanzenfressende hundeartige Alienarten sind bewusst zulässig.
Ökologische Rollen (`grazer`, `forager` usw.) bleiben ein getrenntes Feld.

## Grenze zum Körpervertrag und zu D2–D4

D1 liefert Anforderungen an `saddle`/`harness`, keine erfundenen Sitztransformationen.
Auftrag 2 besitzt gespeicherte Anschluss-IDs und Transformationen. D4 muss diese
am konkreten Entwurf prüfen, bevor Aufsitzen oder Pflügen erlaubt wird. Die
Art-Eignung allein aktiviert keine dieser Aktionen. D2 besitzt individuelle
Tier-ID, Besitzer, Vertrauen und Auftrag; D3 besitzt Versorgung, Zeitkonten und
Milchtransfer. Offline-Zeit erzeugt hier weder Milch noch gezähmte Tiere.

## Vorkommen und Lebensräume

Die Implementierung ergänzt gespeicherte Vorkommen mit Körper-/Art-/Objekt-ID,
Position, geprüftem Landweg und festem Ersatzzyklus. Die Oberflächenversion
bleibt `legacy_plane_v9`. Die Kugeladapter und unbelebten Laborkörper bekommen
keine stillschweigende Landtierpopulation. Aktive Kampagnenplaneten sind heute
belebte Landspielwelten; explizit lebenslose Körper, Gasriesen und Sterne sind
von der Garantie ausgeschlossen. Der Generator-/Spawnbericht dokumentiert
Messgrenzen, Nahrung/Wasser und Neustartprüfung.

## Produktiver Anschluss

`planet_fauna_catalog.gd` stellt `ensure(GameState)`, `validate(catalog, body)`,
`species_for(catalog, species_id)`, `object_id(GameState, habitat)` und
`cell_key(habitat)` bereit. `ensure` ergänzt nur einen fehlenden Katalog am
aktuellen belebten Kampagnenkörper. Vorhandene Daten bleiben autoritativ.
Lesende Verbraucher nehmen eine Kopie des Eintrags; Mutationen gehören dem
jeweiligen Datenbesitzer. Das Buch kann das bereits gespeicherte
`journal.visual.species.domestication` lesen. Nicht gescannte Arten werden
hierdurch nicht automatisch als entdeckt freigeschaltet.

| Katalogfeld | Inhalt |
|---|---|
| `schema`, `generator_version` | 1, domestic_fauna_v1 |
| `body_id`, `seed` | vorhandene Körperidentität und normalisierter Ganzzahl-Seed |
| `species` | drei vollständige Einträge, inklusive `id`, `species_seed`, `group`, ökologischer `role`, `domestication`, `visual_scale`, `blueprint` |
| `blueprint` | vollständiger JSON-Entwurf, Vector3 als `{"$vector3":[x,y,z]}`; über Contract.decode laden |
| `habitat_status` | pending während der schrittweisen Suche; ready nur mit allen drei Arten; unavailable bei fehlgeschlagener Prüfung |
| `habitats` | angestrebt zwölf feste Vorkommen, gleichmäßig nach Rolle; unabhängige Alternative zu alten regionalen Populationen |

Jedes Vorkommen enthält `key`, `species_id`, `region_id`, `position`, `path`,
`travel_mode` (walk oder swim_walk), `biome`, `food`, `freshwater_distance`,
`water_supply`, `generation` und `replacement_at`. `spawn_position` wird bei
erster kollisionsfreier Platzierung ergänzt und danach beibehalten.
`freshwater_distance=-1` bedeutet kein erfasstes Süßwasser. Eine Entfernung zum
Wasserkörper ist **keine** bestätigte begehbare Trinkstelle. `requires_transport`
verlangt eine spätere Wasserversorgung; D1 erfindet keine Quelle.

Die Wege bestehen aus Terrainproben mit etwa einem Meter Abstand und geprüften
Höhenschritten; Landwege berücksichtigen einen seitlichen Korridor. Beim
Inselstart darf der Spieler vorhandene Schwimmbewegung nutzen. Die Tiere
bleiben auf trockenem Gelände. Der Spawner prüft zusätzlich geladenen Boden
und Körperfreiheit gegen Terrain, Bäume, Felsen und Kreaturen. Innerhalb eines
kleinen geprüften Geländeflecks darf er einmal eine freie Alternative wählen.
Eine dauerhaft verstellte gespeicherte Position wird nicht per Teleport
aufgelöst. Szenenobjekte entlang des gesamten Weges sind kein globales Navmesh.

Drei reservierte Plätze im bestehenden Populationstopf verhindern Verdrängung
durch zufällige Wildarten. Pflichtvorkommen werden bis 40 m geprüft, mit
unverändertem globalem Maximum. Ein aktives Tier je Pflichtart genügt; die
anderen Vorkommen erlauben Wiederbesuche und Ersatz. Kleine natürliche
Futtergruppen nutzen vorhandene Beeren-/Nahrungssuche und gespeichertes
Nachwachsen. Trockene Hochlagen sind zulässige Habitate dieser Landtierarten.

Nach dem Tod wird für das betroffene Vorkommen einmal `replacement_at =
elapsed_seconds + 300` gesetzt. Danach steigt `generation` um eins; eine neue
Objekt-ID ersetzt den Repräsentanten. Alte Begegnungen, tote IDs und
Belohnungssperren bleiben erhalten. Neuladen oder bloßes erneutes Anfragen
verkürzen den Ersatzzeitraum nicht; es gibt keine Echtzeit-/Offline-Ernte.

D2 kann `FaunaStreamerV7.domestic_fauna.object_is_reserved` mit einem Callable
`(object_id: String) -> bool` anschließen. Ein über die eigene Haltung verwaltetes
Tier wird dann weder erneut gespawnt noch ersetzt. Den Callable nach Aufbau
der Szene setzen; er bleibt über Spielstand-Neubindung derselben Szene erhalten.
Die bestehenden AI-/Futter-/Wasser-Phasengrenzen sind weiterhin Phase 0.
D2 muss sie gemeinsam mit seinem Bewegungsbesitz für die Stammesphase erweitern.
