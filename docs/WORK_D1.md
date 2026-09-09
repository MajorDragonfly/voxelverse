# D1 – planetare Tierrollen

Stand: 9. September 2026. Auftrag 3 auf der gemeinsamen Voxelverse-Basis.
Branch: `agent/d1-planet-fauna`. Kein Merge nach main, keine fremden Fachstände.

## Prüfreferenz

- Basis: `3a3e0272375e556f3ff65b7370582af79a9d48b5`.
- Erster geprüfter Datenvertrag: `11a9dbebd73487f09deaf8fecf9a0385dd3f6417`.
- Generator-/Spawnlieferung: `96c61f49213b9906b45b07e7ff3f5d3bb6d1d682`.
- Geprüfter Code-Dateibaum: `1b1afb3a63a5344f9a4a9fdb86f5855b1f789c7d`.
- Lokale Prüfcommits: Vertrag `bb43b61`, Umsetzung
  `08fde2a4d496de2d4538508be5b77016fa7cd1c0`. GitHub erstellt über die verbundene
  Anwendung andere Commit-Metadaten; die Dateibaum-Hashes stimmen exakt überein.
  Der nachfolgende Übergabecommit ergänzt nur diesen Bericht.

## Ergebnis

Jeder unterstützte belebte Kampagnenkörper erhält beim ersten Weltaufbau einen
versionierten Katalog mit drei unterschiedlichen Pflichtarten: Milchweider,
Zug-/Reittier und hundeartiger Spürläufer. Zug- und Reitfähigkeit liegen gemeinsam
beim Arbeitstier. Prozedurale Farben, Hautmuster, Maße und Namen variieren, die
funktionalen Mindestmerkmale bleiben verbindlich. Alle drei Körper besitzen
vier animierte Standbeine mit Füßen; beim Arbeitstier bleibt der Rücken frei.

Der Katalog speichert vollständige Körperentwürfe, Art-Eignung und feste
Vorkommen. Laden stellt diese Daten wieder her. Alte regionale Seedformeln,
Art- und Objekt-IDs, gescannte Entwürfe, Beziehungen und tote Individuen werden
nicht umgeschrieben. Die gleiche Körper-ID mit demselben Ganzzahl-Seed und
derselben Generatorversion erzeugt dieselben neuen Arten – auch nach dem
Laden eines alten Spielstands ohne Katalog.

Die Lebensraumsuche läuft schrittweise. Sie sucht normalerweise zwölf
Alternativvorkommen und prüft trockene Standorte sowie Wege mit Höhenproben.
Bei Inselstarts sind Wege mit Schwimmabschnitt für den Spieler zulässig.
Tiere werden ausschließlich auf geprüftem trockenem Gelände platziert.
Im geladenen Spiel kommen Boden- und Kollisionsprüfung hinzu. Freie Alternativen
im gleichen kleinen Geländefleck werden einmal gewählt und gespeichert.

Drei Plätze im vorhandenen Populationstopf sind für die Pflichtarten reserviert.
Nahrung nutzt echte Beerenpflanzen, dieselbe Nahrungssuche und gespeichertes
Nachwachsen wie andere Wildtiere. Die Daten unterscheiden nahe Süßwasserkörper
von nötigem Wassertransport. Nach Jagd kann jedes betroffene Vorkommen nach
300 Kampagnen-Sekunden einen neuen Repräsentanten mit neuer Objekt-ID stellen.
Alte tote Tiere, Beziehungen und Belohnungssperren bleiben gespeichert.

## Vertrag und Integrationsstellen

Vollständige Felder, Einheiten, API und Grenzen: [D1_DATA_CONTRACT.md](D1_DATA_CONTRACT.md).

| Anschluss | Änderung / Zuständigkeit |
|---|---|
| `world/fauna/domestication/` | Neues Eignungsmodell, gespeicherter Katalog, spezialisierter Generator, Habitatplaner und Laufzeitanschluss |
| `world/fauna/fauna_streamer_v7.gd` | Vorbereitung, vorrangige Pflichtspawns, Schutz des Gesamtlimits, Neubindung nach Laden |
| `creatures/wildlife/procedural_wildlife_v7.gd` | Optionaler sechster configure-Parameter für gespeicherte Art; Körper, Größe, Kollision und Bewegung daraus lesen |
| `creatures/wildlife/procedural_wildlife_v8.gd` | Eignung im vorhandenen Inspektionsdatensatz |
| `creatures/ai/wildlife_brain.gd` | Tatsächliche Wahrnehmungsreichweite und Vorsichtsabstand aus dem Artprofil |
| `autoload/save_game_service.gd` | Validierung des optionalen Katalogs; unbekannte D1-Versionen vor Laden/Überschreiben sperren |
| Tests / `tools/validate_domestic_fauna.py` | Vertrag, Mehr-Seed-Prüfung, Live-Spawn, alte Spielstände und echter Prozessneustart |
| `.github/workflows/domestic-fauna-validate.yml` | Wiederholbare Prüfung einschließlich Zwei-Prozess-Neustart |

Das übergreifende Save-Schema bleibt 6, das Kampagnenschema bleibt 1. Neu ist nur
`campaign.bodies[world_seed].fauna_catalog` mit Schema 1 und Generator
`domestic_fauna_v1`. Der bisherige Encounter-Vertrag bleibt unverändert. Bei
fehlendem Katalog erfolgt eine additive Ergänzung; unbekannte Versionen werden
nicht mit einer älteren Sicherung überschrieben.

Auftrag 2 besitzt konkrete Sattel-/Geschirr-Anschluss-IDs und Transformationen.
D1 beschreibt Anforderungen und erfindet keine Sitzposition. D2 kann mit
`domestic_fauna.object_is_reserved(object_id)` Individuen aus dem normalen
Spawn-/Ersatzablauf herausnehmen. Die Stammesfreigabe und der Bewegungsbesitz
gehören D2; die bestehende Wildtier-KI und Nahrung/Wasser sind noch auf Phase 0
begrenzt. D3 übernimmt Versorgung, Produktionszeit und Milchtransport. Die
bestehende Buchbeobachtung enthält bereits `species.domestication`; Auftrag 7
kann diese gespeicherten Werte lesen. Es wurde keine Zähmungsoberfläche ergänzt.

## Abnahme

Godot 4.6.3, isolierte Spielstandverzeichnisse, Headless-Linux:

| Prüfung | Ergebnis |
|---|---|
| Import und vorhandene Artquellen | 2/2 bestanden |
| Datenvertrag, Katalog, Laufzeit | 3/3 bestanden |
| KI, KI in echter Welt, Sozialspiel, Spielstandplätze, Buch, Weltkontinuität | 6/6 bestanden |
| Schreiben und Lesen in getrennten Engine-Prozessen | 2/2 bestanden |
| Planetensampling | 78 Seeds, 234 Pflichtarten, 932 Vorkommen; mindestens 8 Vorkommen je Testplanet |
| Live-Szene | Alle drei Rollen, je vier animierte Beine, drei nutzbare Futterquellen |
| Population / Verlust | Limit 3 eingehalten, alle drei Rollen erhalten; bejagte Milchvorkommen bekommen neue IDs nach Ablauf des Timers |
| Altstände / Versionsschutz | Alte Scans/Beziehungen und IDs erhalten; Besuchsreihenfolge stabil; Zukunftskatalog, -generator und -eignung trotz kompatiblem Backup nicht geladen/überschrieben |

[Zusammenfassung](../validation/d1/summary.json),
[Planetenwerte](../validation/d1/planet-samples.json),
[Quell-Hashes](../validation/d1/source-sha256.json),
[Neustart-Leseprotokoll](../validation/d1/restart-read.log).
Die erwarteten Warnungen im Leseprotokoll stammen von absichtlich manipulierten
Zukunftsständen. Erstläufe fanden unter anderem Schlüsseltyp-, Inselweg-,
Spawnradius- und Futterplatzprobleme; die dokumentierten bestandenen Prüfungen
enthalten die gezielten Wiederholungen nach deren Korrektur.

Nach Import wiederholbar mit:

```sh
python tools/validate_godot.py --godot /pfad/zu/godot --tests domestication_contract_test domestic_fauna_catalog_test domestic_fauna_runtime_test --skip-main --output /tmp/d1-checks
python tools/validate_domestic_fauna.py --godot /pfad/zu/godot --output /tmp/d1-restart
```

## Verbleibende Grenzen

Die Garantie bezieht sich auf die heutige belebte `legacy_plane_v9`-Kampagne.
Sterne, Gasriesen, ausdrücklich unbelebte Körper und noch nicht angeschlossene
Kugeloberflächen erhalten keine künstlichen Landtiere. Die endliche
Lebensraumsuche behauptet bei einem ungeprüften Extremseed keinen Erfolg:
`unavailable` bleibt ein sichtbarer Prüfstatus für Integratoren. Der Test belegt
78 Seeds, keine vollständige Enumeration aller möglichen Seeds.

Die längste geprüfte Route ist 222 m lang. Terrainrouten ersetzen noch kein
weltweites Navigationsnetz um sämtliche später gebauten Hindernisse. Freies
Aufsitzen, Pflügen, Milchproduktion und eine langfristig durchgängig gesicherte
Wasserversorgung sind die folgenden D2–D4-Pakete. Eine Süßwasserentfernung allein
bestätigt keine Trinkstelle. Native Windows-Ausführung, Sichtprüfung der neuen
Tiere und Ziel-PC-Framezeiten wurden hier nicht abgenommen. ROADMAP.md bleibt
entsprechend der Arbeitsaufteilung beim Integrationschat.
