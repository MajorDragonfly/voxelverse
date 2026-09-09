# Voxelverse: Architekturprüfung und Skalierbarkeit

Stand: 9. September 2026. Geprüfter gemeinsamer Commit: `d94d1e5f8a85b3e1a77d46984f381d14d84a8cf7`.
Diese Prüfung bewertet Erweiterbarkeit, Weltgröße, dauerhafte Zustände und den Anschluss weiterer Spielphasen.
Die ausführbaren Folgeaufträge stehen im [Architektur-Backlog](ARCHITECTURE_BACKLOG.md); ihre Reihenfolge ergänzt die [Roadmap](../ROADMAP.md).

## Ergebnis

Die vorhandene Basis kann weiterverwendet werden. Für Koordinaten, prozedurale Weltgenerierung, Körperidentitäten und begrenzte Terrainlaufzeit bestehen geeignete Grundlagen.
Weitere Inhalte lassen sich darauf aufbauen, sobald Kampagnenanschlüsse, Regionsspeicherung und Simulationsübergaben vervollständigt sind.
Der aktuelle Stand erlaubt noch kein beliebiges Anhängen größerer Spielsysteme ohne Anpassungen an diesen gemeinsamen Grenzen.
Ein vollständiger Neustart, Enginewechsel oder pauschaler Umbau auf ECS ist durch diese Befunde nicht begründet.
Empfohlen wird ein schrittweiser Umbau vorhandener Dienste mit erhaltenen Spielständen und kleinen, überprüfbaren Übergaben.

## Prüfumfang und Aussagegrenzen

- Statische Prüfung des genannten Commits einschließlich vorhandener Tests, Verträge und dokumentierter Grenzen.
- Der Bestand umfasst 460 GDScript-Dateien mit 83.851 Zeilen. Umfang allein ist weder Qualitätsurteil noch Beweis für schlechte Architektur.
- Es wurde für dieses Audit kein neuer vollständiger Laufzeit-, Langzeit-, Export- oder FPS-Test ausgeführt.
- Neu ausgeführt wurde durch den Sprach-/Feature-Prüfstrang ausschließlich `python3 tools/localization/catalog.py --check`: 221 Einträge, zwei Sprachen, erfolgreich.
- Vorhandene Testprogramme zeigen, welche Eigenschaften geprüft werden sollen. Ihre Existenz ersetzt keine erneute gemeinsame Abnahme nach Änderungen.
- Änderungen anderer laufender Arbeitsstände wurden nicht als fertige Funktionen bewertet. Unbekannte Unterschiede in nicht eingecheckten Branches bleiben offen.
- Geplante Eier, Anatomieausbau, Expeditions-/Landungsschiffe und Community-Baupläne wurden zusätzlich bis Planungscommit `61ccebb2c6eec5d6f5826867cc91205265dd7667` gelesen; dessen Inhalte sind nicht als integrierte Implementierung gewertet.

## Verbindliche Produktentscheidungen für die weitere Arbeit

| Thema | Arbeitsgrundlage |
|---|---|
| Oberfläche und Orbit | Kurze Übergänge sind erlaubt; durchgehend nahtloser Flug ist kein notwendiges Architekturziel. |
| Entfernte eigene Siedlungen | Sie arbeiten vereinfacht weiter, solange das Spiel läuft. Vollständige Physik aller Bewohner ist dafür nicht erforderlich. |
| Pause und geschlossene Anwendung | Keine Offline-Produktion; Pause hält auch die Fernsimulation an. |
| Leistung | Vorläufiges Ziel: Gaming-PC, 1080p, 60 FPS. Genaue Hardware und verbindliche Messroute sind noch festzulegen. |
| Spielmodus | Singleplayer bleibt Arbeitsgrundlage. |
| Terrain | Freies Graben und tiefe Volumenhöhlen sind derzeit keine Anforderung. |
| Schiffe | Modularer Entwurf und Ausrüstung sind geplant; begehbare Schiffsinnenräume sind derzeit keine Anforderung. |
| Community-Baupläne | Gemeinsames portables Format und fertige Vorlagen; Editorarbeit freiwillig. Online-Austausch erfordert keine Multiplayer-Simulation, bestehende Downloads bleiben offline nutzbar. |

Nur die eigene Spezies entwickelt eine Zivilisation. Fremde gezähmte Tiere bleiben Tiere.
Der Gebäudeeditor beginnt im vorgesehenen Mittelalterpaket; frühe Hütten und Zelte bleiben feste Bauformen.

## Tragfähige Grundlagen

| Bereich | Beleg im geprüften Code | Bedeutung |
|---|---|---|
| Körpergebundene Orte | `world/space/cube_sphere.gd`, Z. 4–67 | Globale Meterwerte bleiben skalare Doubles/Arrays; erst nach Ursprungssubtraktion entstehen lokale `Vector3`-Werte. |
| Gemeinsamer Oberflächenadapter | `world/surface/radial_surface_adapter.gd`, Z. 16–95 | Abtastung, Platzierung, Aufrichtung und Ursprungskorrektur haben einen gemeinsamen Anschluss. |
| Begrenzte Terrainabdeckung | `world/planet_lab/planet_tile_layout.gd`, Z. 31–53 | Die vollständige, ausgeglichene Cube-Sphere-Abdeckung wird innerhalb eines Blattbudgets gewählt. |
| Vorbereitete Übergänge | `world/planet_lab/adaptive_sphere_tiles.gd`, Z. 187–234 | Neue Geländeabdeckung ersetzt die alte erst mit vorbereiteter Spielerumgebung und erneuerten Kollisionen. |
| Deterministischer Galaxiekatalog | `world/space/galaxy_catalog.gd`, Z. 6–8 und 153–173 | Feldweise abgeleitete Seeds und begrenzte Caches erlauben Abfragen ohne vollständige Galaxielaufzeit. |
| Getrennte Systemänderungen | `world/space/galaxy_journal.gd`, Z. 3–9 und 50–79 | Einzelne Systemdateien, Versionsbindung und Revisionsprüfung sind ein brauchbares Muster für spätere Regionsspeicherung. |
| Geschützter Kampagnenumzug | `core/campaign/surface_context.gd`, Z. 56–80 | Noch nicht angebundene Ortsdaten werden ausdrücklich abgewiesen; sie verschwinden nicht still durch Umdeutung. |

Die Produktion benutzt teilweise Klassen unter `world/planet_lab`: `surface_terrain.gd` und `spherical_campaign_player.gd` erben dortige Laufzeitbausteine.
Das ist kein Grund, funktionierenden Code neu zu schreiben. Gemeinsame Laufzeitverantwortung und Laborsteuerung sollten bei den betroffenen Anschlussarbeiten klar getrennt werden.

## Befunde, die vor weiterem Ausbau bearbeitet werden müssen

### 1. Die gemeinsame Kugelkampagne enthält noch nicht die gesamte Spiellogik

`main/spherical_campaign.gd`, Z. 54–68, setzt `wildlife_enabled = false` und beschreibt Bewegung, Karte und Speichern als aktuellen Umfang.
`surface_context.gd`, Z. 70–71, sperrt `home_group`, `tribe`, `tribal_neighbor`, `domesticated_animals` und `fauna_catalog` ausdrücklich.
Das ist eine korrekt sichtbare Migrationsgrenze. M1f und M1g sind tatsächliche Entwicklungsaufträge, keine reine Menüfreischaltung.
Vor weiteren Epochen müssen die bestehenden Kreaturen-, Heimat-, Dorf- und Tierhaltungsdienste auf denselben Oberflächenkontext wechseln.
Abnahme: vollständiger zusammenhängender Ablauf mit denselben Bewohnern, Arten, Tieren, Vorräten und Fortschritten nach Neustart.

### 2. Körperidentität ist in der Kampagne noch an einen Seedindex gekoppelt

`CampaignState.body_for_seed()` in `core/campaign/campaign_state.gd`, Z. 47–62, verwendet ausschließlich `str(world_seed)` als Dictionary-Schlüssel.
`system_seed` beeinflusst die ID nur beim ersten Anlegen. Derselbe Weltseed in zwei Systemen kann dadurch auf denselben vorhandenen Kampagnenkörper zeigen.
Das betrifft den Kampagnenindex; der separate Galaxiekatalog besitzt bereits vollständigere Adressen.
Vor Systemreise müssen Körper-ID und Lookup getrennt werden: neue Zugriffe über stabile Körperidentität, alter Seedzugriff als expliziter Kompatibilitätsadapter.
Abnahme: zwei Systeme mit gleichem Weltseed behalten getrennte Körperzustände; bisherige IDs und alte Speicherstände bleiben erhalten.

### 3. Besuche und Änderungen benötigen eine dauerhafte Regionsspeicherung

`world/surface/surface_ecosystem.gd`, Z. 10–12 und 173–186, begrenzt gespeicherte gewöhnliche Wildtiere auf 256 Records.
Ist dieser Bestand voll, werden neue gewöhnliche Tieridentitäten übersprungen. Die Records werden nicht regional ausgelagert.
Die planare `region_background_simulation_v7.gd`, Z. 313–329, entfernt dagegen alte Regionen oberhalb des Cachelimits ohne dauerhaften Schreibanschluss.
`region_ecology_simulation.gd`, Z. 18–37, exportiert nur die noch vorhandenen `_region_states`.
Eviktierte Populations- und Ressourcenänderungen sind daher nicht durch diesen Export erhalten; ein Wiederbesuch kann den Generatorzustand herstellen.
Abnahme: Region verändern, mehr als 96 weitere Regionen beziehungsweise 256 Tieridentitäten besuchen, zurückkehren und neu starten; Änderungen bleiben erhalten und neue Tiere erscheinen weiter.
Das Speicherbudget muss den geladenen Ausschnitt begrenzen, ohne dauerhafte Spieleränderungen zu löschen oder neue Begegnungen global abzustellen.

### 4. Gesamte Speicherstände werden synchron aufgebaut und geschrieben

`autoload/save_game_service.gd`, Z. 103–153, sammelt Zustand und Entwürfe, kopiert Regionsdaten, validiert, liest den alten Stand und schreibt Historie sowie Snapshot im selben Ablauf.
Das bietet derzeit eine nachvollziehbare gemeinsame Sicherung, skaliert aber mit der gesamten angesammelten Datenmenge.
Für viele Regionen und Siedlungen braucht derselbe Speicherdienst ein kleines Manifest, segmentierte Zustände und einen konsistenten Commit-/Wiederherstellungsweg.
Ein zweiter konkurrierender Save-Service oder bloßes Verschieben aller bisherigen Arbeit in einen Thread würde die fachliche Konsistenz nicht automatisch lösen.
Abnahme: Start/Laden eines kleinen Ausschnitts bleibt begrenzt; unterbrochenes Schreiben liefert entweder den alten oder den vollständigen neuen Zustand.

### 5. Dorf und Navigation sind bislang bewusst lokal

`world/tribe/tribe_controller.gd` umfasst 907 Zeilen; `body()` und `village()`, Z. 112–121, greifen auf einen einzelnen `body["tribe"]` zu.
`world/tribe/village_housing.gd`, Z. 10–11, begrenzt Bewohner und Unterkünfte auf jeweils sechs.
Diese Grenzen sind für den ersten Spielablauf sinnvoll. Mehrere Siedlungen benötigen jedoch eigene Siedlungs-IDs, Zustandszugriffe und Aktivierungsverantwortung.
`village_navigation.gd`, Z. 19–36 und 55–64, nutzt Welt-X/Z-Raster, Welt-Y-Rays und direkte Y-Höhenvergleiche.
Bei maximal 20 m Radius und 0,5 m Rasterabstand entstehen bis zu 6.561 Rasterproben je Aufbau; Arbeitsplätze sind zusätzlich lokal begrenzt.
Der nächste Schritt ist ein radial ausgerichtetes lokales Netz. Später verbinden regionale Übergänge solche Netze, statt ein planetengroßes A*-Raster aufzubauen.
Abnahme: Wege, Baufundamente und Fracht funktionieren nach Ursprungskorrektur und an einer Flächenkante; blockierte Wege stoppen und setzen nachvollziehbar fort.

### 6. Nah- und Fernsimulation brauchen genau einen Besitzer

Die vorhandene regionale Ökologie ist eine nutzbare Aggregation, aber kein vollständiger dauerhafter Übergabevertrag für individuelle Tiere, Dorfproduktion und Fracht.
Der bestätigte Wunsch nach weiterarbeitenden entfernten eigenen Siedlungen verlangt einen gespeicherten Simulationsbesitzer und Zeitcursor je Auftrag beziehungsweise Bestand.
Beim Entladen übernimmt die vereinfachte Simulation den Zustand; beim Laden gibt sie ihn an die physische Laufzeit zurück.
Abnahme: während Milchproduktion und Transport wiederholt Nah/Fern wechseln und speichern; keine doppelte Ware, verschwundenen Tiere oder mehrfachen Belohnungen.
Fortschritt folgt ausschließlich Spielzeit. Pause und geschlossene Anwendung erzeugen keine nachträgliche Produktion.

### 7. Neue Inhalte berühren noch mehrere fest verdrahtete Fachlisten

`village_economy.gd`, Z. 5–19, enthält feste Ressourcen, Berufe, Aufträge, Zielbestände sowie milchspezifische Zähler.
`world/fauna/domestication/domestication_contract.gd`, Z. 5–27 und 54–58, definiert feste Tierrollen und ausdrücklich Milchparameter.
`planet_fauna_catalog.gd`, Z. 86 und 136, verlangt genau drei Pflichtarten beziehungsweise repräsentierte Gruppen.
Eier sind deshalb kein einzelner zusätzlicher Listeneintrag. Rollen, Produktion, Pflege, Transport, Darstellung und Migration müssen denselben erweiterten Vertrag benutzen.
Ein kleiner versionierter Ressourcen-/Produktionskatalog sollte diese konkreten Erweiterungen tragen; eine universelle Pluginplattform ist dafür nicht erforderlich.
Die Fachaufträge `D1-EIER`, `D3-EIER` und `M3-TEILE` bleiben maßgeblich; dieses Audit legt keine konkurrierenden Feature-IDs an.

### 8. Baugruppen benötigen ausdrückliche Behandlung unbekannter Versionen

`assembly/core/modular_assembly.gd`, Z. 24–30, setzt in `normalize()` die übergebene `schema` ohne vorherige Versionsentscheidung auf 1.
Diese Hilfsfunktion allein schützt deshalb keine unbekannte zukünftige Baugruppe vor stiller Normalisierung. Daraus folgt nicht, dass jeder aktuelle Lader ungeschützt ist.
Vor dem Ausbau gemeinsamer Gebäude-/Fahrzeug-/Schiffsentwürfe müssen Prüfung, bekannte Migration und Normalisierung getrennte Schritte sein.
Abnahme: ein neueres unbekanntes Blueprint bleibt unverändert erhalten; nur bekannte alte Versionen werden nachvollziehbar migriert.
Das geplante BP-COMMUNITY verwendet denselben Vertrag für deklarative, größenbegrenzte Baupläne ohne Skripte oder Kampagnenbesitz. Herkunft/Revision, lokale Fähigkeitsprüfung und vom Online-Katalog unabhängige gespeicherte Entwürfe gehören früh in diesen Anschluss; der Dienst bleibt ein eigenes geplantes Fachpaket.

## Tatsächlich codierte Grenzen und noch fehlende Leistungsnachweise

| Laufzeitbereich | Grenze im geprüften Stand | Einordnung |
|---|---|---|
| Gelände | 768 Blätter, 24 nahe Terrainkollisionen | Geeignete begrenzte Abdeckung; kein Beleg für vollständige Kampagnenleistung. |
| Terrainaufbereitung | Höchstens vier Meshworker, zwei Uploads pro Frame | `planet_patch_job.gd:5,47`; `adaptive_sphere_tiles.gd:7–8,145–149`. |
| Uploadzeit | 4 ms als weiches Budget | Prüfung erfolgt nach vollständigem Upload; ein einzelner teurer Upload kann darüber liegen. |
| Meshcache | 256 Cacheeinträge; Ziel 1.536 residente Meshes | Cachetrim und vorhandene Tests berücksichtigen vorbereitete und sichtbare Geometrie. |
| Belebte Kugellandschaft | 25 Flora-Zellen, vier aktive Tiere | `surface_ecosystem.gd:10–12`; für vorhandenen Ausschnitt, nicht beliebig viele Gruppen. |
| Bewegung | Maximal 32 m Vorgriff; Warten vor unvorbereitetem Boden | `radial_walker.gd:90–101`; sicherer Gehbetrieb ist kein Nachweis schnellen Landeflugs. |
| Galaxie | 16 Sektor-, 32 Systemcacheeinträge | Metadaten bleiben begrenzt; daraus folgt keine fertig spielbare Raumfahrt. |

Zusätzlicher Vertragsfehler: `surface_context.gd:22,72` akzeptiert Radius bis 10¹⁰ m, während `planet_tile_layout.gd:17` die Tiefe auf 24 begrenzt.
Bei 16 Zellen pro Patch bleiben dort mindestens etwa 74,5 m je Zelle; `adaptive_sphere_tiles.gd:319–322` fordert höchstens 4 m für vorbereiteten Boden.
Die akzeptierte Körperklasse muss deshalb begrenzt oder nachweisbar erweitert werden. Der bereits geprüfte Erdmaßstab fällt nicht unter diesen Extremfall.
Ein gemeinsamer Benchmark muss Queue-Längen, Uploadzeiten, aktive Objekte, RAM/VRAM sowie CPU-/GPU-Zeiten auf definierter Hardware erfassen.
Bestehende Headless-CPU-Messungen dürfen nicht als 60-FPS-Nachweis für einen Windows-Gaming-PC ausgegeben werden.

## Reihenfolge für die weitere Entwicklung

1. Gemeinsame Identitäts-, Orts- und Versionsverträge schließen; bestehende Save-/Kampagnendienste beibehalten.
2. M1f/M1g als zusammenhängende Kreaturen- und Stammeskampagne radial anbinden; erweiterte Ortsmigration daran prüfen.
3. Budgetmessung früh parallel beginnen; Regionsspeicherung und Nah-/Fernübergabe an den tatsächlichen Spielablauf anschließen.
4. Erst nach gemeinsamer Abnahme M1i umschalten und weitere Epochen beziehungsweise mehrere Siedlungen freigeben.
5. Eier, Anatomie und Schiffsmodule über ihre bestehenden Fachaufträge ergänzen; technische Voraussetzungen im [Architektur-Backlog](ARCHITECTURE_BACKLOG.md) abarbeiten.
6. `M9.1`–`M9.6` bleiben die Fachplanung für Expedition, Landungsschiff und Ausbau. Erlaubte kurze Übergänge vereinfachen den Anschluss, ersetzen aber keine Fracht-/Identitätsübergabe.

Ein Folgechat liefert einen begrenzten Auftrag, betroffene Verträge, konkrete Prüfergebnisse und verbleibende Grenzen.
Ein integrierter Commit mit bestandener Abnahme ist die Übergabegrundlage; unfertige fremde Änderungen und frühere Einzelbranch-Nachweise ersetzen sie nicht.
