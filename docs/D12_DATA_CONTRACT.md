# D1.2 – Fauna auf Kugeloberflächen

Version 1, 9. September 2026. Aufbau auf D1/D1.1 und dem abgeschlossenen
M1d-Landschaftsstand `593de30cff6db98a95ed4dd13a6e12497b4799ae`.
Dieser Vertrag wird vor dem Laufzeitanschluss versioniert.

## Identität und Kompatibilität

Es bleibt ein gemeinsamer `fauna_catalog` mit genau drei verschiedenen Arten:
`milk`, `work`, `companion`. Generator `domestic_fauna_v1`, Saatformel,
Art-IDs, eingefrorene Blaupausen und optionale D1.1-Körpernachweise bleiben gleich.
Die Anlage wird aus dem Kampagnenservice als reine Funktion herausgezogen;
vorhandene Kataloge werden weder neu erzeugt noch umetikettiert.

Schema 1 bleibt unverändert für `legacy_plane_v9`. Neue Kugelkataloge verwenden
Schema 2 und einen Oberflächendeskriptor `surface`: `schema = 1`,
`mode = cube_sphere_m1_v1`, `generation = living_planet_v1`, `radius`,
`terrain_revision` und einen festen `anchor` am ersten gespeicherten Startort.
Nur ausdrücklich belebte Planeten/Monde sind geeignet. Es gibt keine stille
Migration einer flachen Kampagne oder ihrer Habitat-/Individuen-IDs.

## Habitat und Suche

Kugelorte verwenden den vorhandenen CubeSphere-Vertrag: `mode`, `body_id`,
`face`, `u`, `v`, `height`. Zahlen bleiben JSON-Skalare mit doppelter Genauigkeit;
globale Meterpositionen werden nie vor dem Ursprungsabzug in Vector3 umgewandelt.

Habitate behalten `key`, `species_id`, `region_id`, `generation`,
`replacement_at`, `position`, `path`, `travel_mode`, `food`, `water_supply`,
`freshwater_distance`. In Schema 2 sind `position`, alle `path`-Punkte und
optionales `spawn_position` Kugelorte. `food_position` ist ein geprüft erreichbarer
Platz für eine vorhandene Futterpflanze. Schlüssel stammen aus einem festen
Suchraster am Anker, Regionen aus der körperfesten Habitatadresse.
Individuen werden wie bisher aus Region, Habitat und Generation abgeleitet.

Deterministische, fortsetzbare Breitensuche: 4-m-Raster, acht Nachbarn,
höchstens 4096 Knoten, 128 m Ankerabstand und 512 Wegpunkte. Kanten werden
in höchstens 2-m-Abständen auf trockenem, ausreichend flachem Terrain geprüft.
Mindestens 12 m Startabstand und 10 m Abstand zwischen den drei Habitaten.
`surface_search` enthält Schema 1, Algorithmus `domestic_surface_search_v1`,
Knoten mit Rasteradresse, Vorgänger und Kugelort, aktuellen Kopf und Richtung.
Framebudget und Neustart ändern weder Reihenfolge noch Resultat.
Erschöpfte Suche meldet `unavailable`; sie erfindet keine Erreichbarkeit.

Meerwasser gilt ausdrücklich nicht als Süßwasser. Bis zum Ressourcenanschluss
bleibt `water_supply = requires_transport`, `freshwater_distance = -1`.
Der Katalog enthält Eignung, keinen Besitz und keine Milchproduktion.
Optionales `habitat.food_state` enthält Schema 1, `remaining` (0–30) und
`regrow_remaining` (0–180 aktive Sekunden). Die vorhandene Futterpflanze
verwendet diese körperfeste Sicherung statt flacher Kampagnenkoordinaten.
Pausierte/entladene Pflanzen simulieren keine Regeneration.

## Laufzeit und Sicherung

Die vorhandene belebte Kugelszene erhält einen Faunaadapter unter
`world/fauna/domestication/`. Drei der bestehenden vier zusätzlichen Tierplätze
werden bei erreichbaren Pflichtarten verwendet; die feste M1d-Startkreatur bleibt
erhalten. Allgemeine M1d-Tiere und ihre gespeicherten Körper werden nicht ersetzt.
Aktivierung nur mit fertiger Nahkollision und freiem physischem Stellplatz,
Entladen mit Erhalt von Individuum, Körper, Position und Bewegungszustand.
Der erste bestätigte Stellplatz wird gespeichert. D1.1 prüft den tatsächlichen
neu aufgebauten Körper vor seiner ersten Simulation.

Die vorhandene Datei `living_planet_v1.json` erhält äußeres Schema 2.
Schema 1 wird weiterhin gelesen; seine Daten bleiben erhalten und erhalten erst
beim regulären Speichern den neuen Header. Das verhindert, dass ältere Leser
die neuen Tierdaten unbemerkt verwerfen. `fauna_codec = godot_native_v1` bleibt
für die vorhandenen M1d-Tiere erhalten. Pro Körper kommen optional der gemeinsame
`fauna_catalog` und `domestic_fauna` mit gespeicherten Individuen hinzu.
Diese referenzieren Art und Habitat; es gibt keine zweite Blaupausenkopie.
Unbekannte Versionen schützen Primärdatei und Backup vor Überschreiben.
Kampagnenschema, Sessiondienst und Autoloads ändern sich nicht.

## Abnahme

Prüfen: gleiche Seeds/verschiedene Besuchsreihenfolge; echte drei Pflichtarten
und Körpernachweise; radiale Bodenhaftung und Hindernisse; aktive Obergrenze;
Entladen, Ursprungswechsel und Rückkehr; Speichern und Laden in zwei Prozessen;
alte Kugelsicherung ohne D1 sowie unveränderte D1/D1.1-Kampagnensicherung;
geschützte zukünftige Versionen. Keine Zähmungsoberfläche oder Dorfmigration.
