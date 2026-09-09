# D1.2 – drei Pflichtarten auf der spielbaren Kugelwelt

Stand: 9. September 2026. Auftrag 3, Fortsetzung ausdrücklich freigegeben:
D1/D1.1 an den vorhandenen Kugeladapter anschließen, alte Arten und Sicherungen
erhalten, mit Planetenwechsel und Neustart prüfen.

## Basis und Reihenfolge

- Gemeinsamer `main`: `3a3e0272375e556f3ff65b7370582af79a9d48b5`.
- Eigener Branch: `agent/d12-spherical-fauna`.
- Fertiges D1.1: PR #37, `3ee18b1077a54c9b1a117580ac8d31c650221b30`.
- Abgeschlossene M1d-Landschaft: `593de30cff6db98a95ed4dd13a6e12497b4799ae`
  aus PR #31. Dessen laufende Gelände-/Wasseränderungen sind nicht enthalten.
- Veröffentlichter Abhängigkeitscommit: `61e3aafd1c620a563d8eb28fcd157e8127c1d480`,
  Quellbaum `a1236175a3f6d230bc3165c0cc6425eb18dc75af`.
- Datenvertrag zuerst: `e9df29a509454e26f8bf064ba9ad1dd02870ff54`
  (lokal `4a6728f7a0bcb62f7d355019cf168b35ee30b84f`).
- [Versionierter Vertrag](D12_DATA_CONTRACT.md). Code-/Übergabe-Refs folgen unten.

Keine automatische Übernahme nach `main`; `ROADMAP.md` bleibt beim Integrationschat.
Keine fremden unfertigen Änderungen übernommen.

## Sichtbares Ergebnis

Der vorhandene Einstieg **Planetenlabor → Belebter Voxelplanet** trägt jetzt
Milchweider, Lastläufer und Spürläufer aus dem gemeinsamen D1-Katalog.
Alternativ `godot --path . res://world/planet_lab/living_planet.tscn`.
F5 sichert, F9 lädt, M wechselt den Planeten, R führt zum Startort zurück.
Es gibt keinen zusätzlichen Menüpunkt und keine neue Zähmungsoberfläche.

Alle drei Arten sind verschieden, deterministisch, besitzen ihre bestehenden
D1-Eignungsmerkmale und werden mit ihren gespeicherten Körpern aufgebaut.
Die D1.1-Prüfung verwendet den tatsächlich gebauten Körper vor dessen erster
Simulation. Geschwindigkeit und Größe stammen aus D1; die Tiere laufen mit
radialer Schwerkraft und Kollision zwischen lokalen Punkten. Nasses oder noch
nicht geladenes Gelände wird nicht als sicherer Laufbereich behandelt.

Die Pflichtarten teilen sich die bisherigen vier zusätzlichen Tierplätze mit
der allgemeinen M1d-Fauna. Deren gespeicherte Individuen und Entwürfe bleiben
erhalten, auch wenn ein aktiver Platz für eine Pflichtart frei wird. Zusätzlich
bleibt die feste Startkreatur bestehen. Ein gemeinsamer `object_is_reserved`
Callback verhindert eine zweite aktive Kopie später anderweitig gehaltener Tiere.

## Daten und Bestandsschutz

Der gemeinsame `planet_fauna_catalog.gd` erhält eine reine Anlagefunktion.
Generator, Art-ID-Formel und Blaupausenkodierung bleiben gleich. Alte Kataloge
bleiben Schema 1; ausschließlich neue Kugelkataloge verwenden Schema 2.
Die Kugelwelt optiert ihre drei belebten Referenzkörper ausdrücklich ein.
Eine flache Kampagne wird weder gebogen noch automatisch migriert.

Die Suche speichert ein deterministisches 4-m-Raster und vollständige
körperfeste Wege. Sie bleibt über JSON-Neustart und wechselndes Framebudget
reproduzierbar. Gesichtskanten und Pole verwenden denselben CubeSphere-Vertrag.
Kugelkoordinaten werden auf 1e-12 Flächeneinheiten, Geländehöhen auf 1e-6 m
kanonisiert; globale Meterpositionen bleiben vor dem Ursprungsabzug Skalare.
Der erste physisch bestätigte Stellplatz wird gespeichert; vorhandene Individuen
kehren mit derselben ID und gesicherten Pose zurück.

`living_planet_v1.json` liest Schema 1 und 2. Erst ein regulärer Speichervorgang
schreibt Schema 2, damit ältere Leser die neuen Felder nicht verwerfen können.
Die bisherigen Felder `fauna` und `fauna_codec = godot_native_v1` bleiben erhalten;
je Körper kommen der gemeinsame `fauna_catalog` und referenzierende
`domestic_fauna` hinzu. Individuen speichern keine zweite Körperkopie.
Unbekannte Header, Katalog-, Oberflächen-, Such-, Körpernachweis-, Individuen-
und Futterversionen schützen Primärdatei und Backup vor Überschreiben.

Die vorhandene Buschdarstellung erhält einen kleinen radialen Futteradapter.
Er bewahrt endlichen Vorrat und Regeneration im Habitat. Er schreibt weder
flache Koordinaten noch Vorräte in `GameState.campaign`. Pausierte/entladene
Pflanzen simulieren nicht weiter. Dies ist ein Futtervorkommen; Tierhaltung,
Bedürfniskreislauf und Milchproduktion bleiben D2/D3. Meerwasser ist keine
Süßwasserversorgung: `requires_transport` bleibt ausdrücklich gesetzt.

## Einbaupunkte und parallele Arbeit

| Datei/Modul | Änderung |
|---|---|
| `world/fauna/domestication/domestic_surface_contract.gd` | Kugelhabitate, Versionen, Identitäten, Suchvalidierung |
| `domestic_surface_planner.gd` im selben Ordner | Fortsetzbare trockene Wege und Futterplätze |
| `domestic_surface_runtime.gd`, `domestic_surface_creature.gd` | Bestehende Tierplätze, tatsächliche Körperprüfung, radiale Bewegung, Wiederbesuch |
| `domestic_surface_food.gd`, `domestic_surface_store.gd` | Körperfeste Vorräte und validierte individuelle Speicherung |
| `planet_fauna_catalog.gd` | Gemeinsame reine Anlage, Schema-2-Validierung; Legacy-Algorithmus bleibt gleich |
| `world/planet_lab/living_planet.gd` | Ausdrückliches Einoptieren, Konfiguration, Pause und neuer Speicherheader |
| `world/surface/surface_ecosystem.gd` | Optionaler D1-Adapter innerhalb vorhandener Tierverwaltung; Capture/Close |
| `world/surface/living_planet_store.gd` | Schema 1/2 und optionale D1-Körperdaten |
| `tests/living_planet_test.gd` | Kleiner Neustart-Prüfanschluss für D1; vorhandene native M1d-Vergleiche bleiben exakt |

Der letzte Test wird auch vom Planetenchat bearbeitet: bei der Integration
**nur den kleinen D1-Vergleichsblock übernehmen**, dessen laufende Wasser- und
Geländetests erhalten. `surface_adapter_lab.gd`, `surface_terrain.gd` und
`planet_mesh_batch.gd` werden durch D1.2 nicht geändert.
Autoloads, globale Kampagnenschemata, D2-Besitz, Dorf, UI und B2 bleiben unberührt.

## Nachweise

Godot `4.6.3.stable.official.7d41c59c4`, Linux, Jolt, ohne Grafikfenster.
[Prüfübersicht](../validation/d12/summary.json) und Einzelprotokolle liegen unter
`validation/d12/`. **13 abschließende Prüfungen bestanden:** Import, Kunstquellen,
D1-Vertrag, ursprünglicher D1-Katalog, Kugelkatalog, Kugellaufzeit, vorhandener
Menüeinstieg, Oberflächenvertrag, vollständiger M1d-Landschaftstest und jeweils
zwei Prozesse für D1.1- sowie D1.2-Neustart.

| Prüfung | Ergebnis |
|---|---|
| Ursprünglicher D1-Katalog | 78 Seeds, alte IDs/Artkörper/Habitate weiterhin gültig |
| Neue Kugelkataloge | 21 Fälle / 63 Pflichtarten: sechs Flächen × drei Radien plus drei echte Landschaften |
| Flächengrenzen, Pole und Suchneustart | Identisches Resultat nach Unterbrechung innerhalb eines Knotens; Budgetvariation geprüft |
| Tatsächliche Terra-Tiere | Drei Pflichtarten, drei erreichbare Futterpflanzen, höchstens vier zusätzliche aktive Tiere |
| Radiale Physik | 540/540 Tier-Bodenkontakte über 180 Ticks; reale Bewegung |
| Erreichbarkeit | Spieler läuft physisch bis auf 3 m an jede der drei Pflichtarten heran |
| Nachladen | Entladen nach 220-m-Ortswechsel, Ursprungsfehler unter 1 mm, Rückkehr mit denselben IDs |
| Kaltstart | Terra, Neris und Orin in anderer Reihenfolge; gespeicherte Artkörper und individuelle Daten erhalten |
| Alte Kugelsicherung | Schema 1 geladen, vorhandene M1d-Tierdaten erhalten, neuer Header erst beim Sichern |
| Versionsschutz | Acht inkompatible Varianten trotz kompatiblem Backup weder heruntergestuft noch überschrieben |
| Bisherige Kampagne | D1.1-Neustart bestanden; Kugeltiere/Futter verändern den alten Kampagnenzustand nicht |

Native Vector3-/Color-Körperwerte werden exakt verglichen. Skalare JSON-Doubles
können in ihrer letzten Dezimalstelle abweichen; die Körperprüfung erlaubt hier
höchstens 1e-12, bei identischen Schlüsseln, Teilen und nativen Typen.
So wird kein JSON-Formatunterschied mit einer neu erzeugten Art verwechselt.

Ein geplanter zusätzlicher Screenshot konnte nicht aufgenommen werden, weil der
lokale X-Server keine Verbindung öffnen konnte. Es gibt daher **keine neue
Grafik-, Windows-/EXE- oder Ziel-PC-Abnahme**. Der Headless-Landschaftstest prüft
weiterhin echte Hindernisabfragen, Gehen, Wasser und Kamera-Wasserwechsel.

## Grenzen und nächste Integration

- Begrenzt auf den spielbaren M1d-Kugelbetrieb. Die volle Kampagne mit Dorf,
  Scan/Entdeckungsbuch und D2-Aufträgen ist weiterhin gesondert anzuschließen.
- Die Suche hat höchstens 4096 Knoten und 128 m Radius. Unmögliches Gelände
  meldet `unavailable`; daraus folgt keine Garantie für beliebige Seeds.
- Routen belegen trockenes Gelände. Der konkrete Startbereich wurde auch mit
  Spielerphysik geprüft; es gibt noch keine allgemeine Navigation um jedes
  später gebaute Hindernis. Besetzte Stellplätze bleiben ausstehend.
- Vorhandene 256 allgemeine M1d-Individuen bleiben erhalten; keine entfernte
  Populationssimulation, Fortpflanzung, Milch, Reiten oder Zähmung in diesem Paket.
- Die Suche hat ein weiches 2-ms-Budget zwischen Kanten, kein hartes Frame-Limit.
  Tierkörperbau erfolgt höchstens einmal pro Ökosystemaktualisierung; die bereits
  bekannten Aufbauzeitspitzen bleiben Aufgabe der Leistungsarbeit.

Integration: fertiggestellte D1.1-/M1d-Grundlagen und dieses Paket zusammen
prüfen; laufende M1d-Materialarbeit gezielt erhalten. D2 kann den bestehenden
Reservierungsanschluss und die stabilen IDs verwenden, benötigt aber weiterhin
einen eigenen radialen Bewegungs-/Kampagnenanschluss. Die flache Kampagne erst
nach diesem Gesamtanschluss ablösen.
