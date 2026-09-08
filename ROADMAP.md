# Voxelverse – Entwicklungsroadmap

Stand: 8. September 2026 · M1-Technikprototyp: `555f9efa2a16d8dde6fbf121157671ef944b2f83` · M0-Implementierung: `3f7f2252e3cbce868920dcf7c86beb3b47d17354` · visuelle Ausgangsbasis: `b1f1ef9c2c14a27269505da1d086091a0884563f`

Dieses Dokument bündelt das Zielbild, den tatsächlichen Stand und die Reihenfolge der nächsten Arbeiten. Es ist die zentrale Projektplanung. Die älteren Berichte unter `art/` dokumentieren einzelne Arbeitsstände; ihre Phasen A–F sind keine Spielphasen. M0 ist als Grundlagenpaket technisch geprüft. M1 ist als separates Planetenlabor implementiert und technisch geprüft; Nachweise und Integrationsgrenzen stehen im [M1-Bericht](docs/PLANET_M1.md). Lars' manueller Spieltest und die Produktionsintegration bleiben offen. M0-Verträge: [Kampagne](docs/CAMPAIGN_CONTRACTS.md).

## Ziel und verbindliche Anforderungen

Voxelverse ist ein Einzelspielerspiel mit selbst gestalteter Spezies und der Entwicklung **Kreatur → Stamm → Antike/Mittelalter → Weltmacht → Weltraum**. Das Spielprinzip orientiert sich an Spore: Entdecken, Gestalten und unterschiedliche gesellschaftliche Wege tragen die eigene Spezies durch mehrere Maßstäbe. Gestaltung und Entscheidungen müssen im Spiel erkennbare Folgen haben.

- Planeten sollen endliche, kugelförmige Himmelskörper mit einer zusammenhängenden Oberfläche sein. Die Oberfläche, die später aus dem Orbit sichtbar ist, gehört zur tatsächlich bespielten Welt.
- Sternsysteme enthalten unterschiedliche Sterne, Planeten und Monde. Ein- und Doppelsternsysteme gehören zum Zielumfang; weitere Konfigurationen werden über dasselbe Datenmodell ergänzt.
- Kreaturen-, Gebäude-, Fahrzeug- und Raumschiffeditor nutzen gemeinsame Werkzeuge, aber jeweils passende Regeln für Anatomie, Bauweise und Funktion.
- Soziales und aggressives Verhalten verdient jeweils passende Punkte. Der Spieler verteilt sie bewusst in einem Skilltree; daraus entstehen auch Boni für folgende Phasen.
- Spezies, Entdeckungen, Entscheidungen, Baupläne und Weltveränderungen überdauern Phasenwechsel.
- Die Voxelgestaltung bleibt über Nahansicht, Landschaft, Städte und Planetenansicht erkennbar.
- Bestehende Entwürfe und Spielstände werden beim Ausbau berücksichtigt. Entwicklung der Kreatur bleibt Entdecken und bewusstes Umbauen; ein Genom-/Mutationssystem wird nicht wieder eingeführt.

**Planungsgrenze:** Niemand kann jeden späteren Umbau ausschließen. Wir legen jetzt die teuren Schnittstellen fest und prüfen sie an kleinen spielbaren Beispielen. Die komplette Weltraumphase muss dafür noch nicht gebaut werden. „Immer weiter skalieren“ bedeutet größere Spielräume bei begrenzter aktiver Simulation, keine unbegrenzt gleichzeitig berechnete Welt.

## Tatsächlicher Stand

„Grundlage vorhanden“ bedeutet verwendbarer Code; es bedeutet nicht, dass die komplette Spielfunktion fertig ist.

| Bereich | Im geprüften Code vorhanden | Was noch fehlt | Einstieg im Code |
|---|---|---|---|
| Spielphasen | Bestehendes Enum; vorbereiteter, gespeicherter und wiederaufnehmbarer Debug-Phasenübergang; normaler Übergang bis zur tatsächlichen Spielschleife gesperrt | Spielschleifen nach der Kreaturenphase, echte Übergangsbedingungen, Steuerungswechsel und Übernahme der Gesellschaft | [GameState](autoload/game_state.gd) |
| Sternsystem | Gemeinsame V9-Profilquelle; M1-Labor mit zwei Planeten, Mond, Ein-/Doppelstern, Rotation und Kreisbahnen aus einer Uhr | Produktive Kampagnenanbindung, weitere Konfigurationen und Inhalte | [PlanetCatalog](world/generation/planet_catalog_v7.gd), [CelestialSystem](world/space/celestial_system.gd) |
| Planetenwechsel | Taste P lädt die Szene mit anderem Planetenseed; regionale Ökologie wird beim Wiederbesuch übernommen | Spielbarer Raumflug, produktive Landung und Reise-/Kolonieregeln | [StarSystemRuntime](world/space/star_system_runtime_v7.gd) |
| Planetengeometrie | Bestand auf X/Z-Ebene; zusätzlich M1-Cube-Sphere mit gemeinsamen Nah-/Fernkanten, radialer Physik, globalem Höhen-/Klimafeld und Ozean | Hierarchische Unterteilung großer Planeten, produktive Landschaft/Flora/Fauna auf Kugel, spätere explizite Migration | [WorldGenerator](world/generation/world_generator_planetary_v9.gd), [SphereTiles](world/planet_lab/sphere_tiles.gd) |
| Himmel | Bestandshimmel; im M1-Labor Himmelskörper, Licht, Tageslauf und Systemkarte aus derselben Zeit-/Positionsquelle | Visuelle Atmosphärenausarbeitung und Übernahme in die Kampagne | [PlanetVisualEnvironment](world/visuals/planet_visual_environment.gd), [PlanetLab](world/planet_lab/planet_lab.gd) |
| Kreaturen | Körper/Wirbelsäule, Anbauteile, Oberflächenbindung, Symmetrie, Undo/Redo, gespeicherte Entwürfe, Animation und mehrere angewendete Körperwerte | Bedienungs- und Formüberarbeitung, robuste Bewegung verschiedener Körperformen, vollständig wirksame Fähigkeiten | [Aktiver Editor](creatures/editor/creature_editor_runtime.gd), [Assembly V7](creatures/editor/creature_assembly_blueprint_v7.gd), [Runtime](creatures/runtime/creature_runtime_visual.gd) |
| Tierwelt | Einzeltiere wandern, fliehen und greifen an; regionale Populationen, Pflanzen-/Aasvorräte und abstrakte Räuber-Beute-Berechnung | Sichtbare Herden, Nahrungssuche und Jagd zwischen Tieren; zuverlässige Navigation über Lebensräume | [Wildlife](creatures/wildlife/procedural_wildlife_v7.gd), [RegionEcology](world/simulation/region_ecology_simulation.gd) |
| Fortschritt | Arten-/Regionenentdeckung, Insight, Körperteilfreischaltungen; typisierte Kampagnenereignisse und persistente Sequenzprüfung gegen Wiederholung | Verhaltenspunkte, Skilltree, Phasenvermächtnis, getrennte Technikforschung, gesellschaftlicher Ruf | [ProgressionService](autoload/progression_service.gd) |
| Gebäude | Eigenständiger modularer Editor, mehrere gespeicherte Designs, Gebäudekategorien und berechnete Werte | Platzierung mit Spielkosten, begehbare Zugänge, Wirtschaft, Bewohner und Siedlungsbetrieb | [Building Builder](civilization/buildings/building_builder.gd), [Design Registry](civilization/buildings/building_design_registry.gd) |
| Fahrzeuge/Raumschiffe | Allgemeines Bauplanformat als Grundlage | Eigene Teile, Editoren, Bewegungs-/Antriebssysteme, Besatzung, Einsatz im Spiel | [Modular Assembly](assembly/README.md) |
| Speicherung | Schema 3 mit gemeinsamer Kampagnen-/Entwurfssicherung, Backups und Migration; Kampagnen-/Körper-/Regions-/Spezies-/Fraktions-/Objekt-/Entwurfs-IDs; kompatible Ebenenadresse | Übernahme der Labor-Kugeladressen in produktive Kampagnen, individuelle Weltobjektzustände, Bevölkerung/Wirtschaft/Skilltree und spätere Generator-Migrationen | [SaveGameService](autoload/save_game_service.gd) |
| Skalierung | Chunk-Budgets, gestaffelte Darstellung, MultiMesh, regionale Ökologie und begrenzte Tierzahl | Siedlungs-/Reichssimulation, globale Navigation, mehrere Maßstäbe und messbare Budgets auf dem Ziel-PC | [Produktionsarchitektur](art/PRODUCTION_ARCHITECTURE.md) |

Konkrete Altlasten und Stand nach M0:

- **In M1 umgesetzt:** Katalog und aktiver Generator verwenden dieselbe versionierte V9-Profilquelle. Alte Seedfolgen einschließlich der bereits bestehenden Seedbegrenzung sind gegen M0-Referenzen geprüft.
- Im Bestandskatalog sind einige Planeteneigenschaften weiterhin nur Daten. Im separaten M1-Labor steuern Radius, Gravitation, Rotation und Orbits tatsächlich Physik bzw. Darstellung.
- **In M0 erledigt:** Kreaturenbaupläne verwalten keine zweite Kampagnenphase mehr. Die Phase liegt ausschließlich in `GameState`; alte Enum-Werte bleiben erhalten.
- Phasen-Fähigkeitsnamen wie `socialize`, `colonize` oder `terraform` sind keine implementierten Interaktionen. M0 sperrt den normalen Phasenübergang bis zur jeweiligen Spielschleife. Echte Voraussetzungen/Freischaltungen folgen weiterhin in M4/M5.
- **In M0/M1 vorbereitet:** Körperbezogene IDs und Ebenenadressen bleiben erhalten. Das separate M1-Labor ergänzt Kugeladressen, Tangentenorientierung und Körperhierarchie; bestehende Kampagnenlandschaften werden nicht umgeschrieben.
- **In M0 erledigt:** Kampagne und Entwürfe werden gemeinsam gesichert. Der neue Schreibweg ersetzt die Zieldatei nach geprüftem temporärem Schreiben, ohne sie vorher zu löschen; gemeinsame Backups und Wiederaufnahme sind geprüft.

## Architekturentscheidungen vor dem großen Ausbau

Die folgenden Lösungen sind die empfohlene Arbeitsgrundlage. Noch nicht erprobte Entscheidungen sind ausdrücklich als Prototyp bezeichnet.

### 1. Eine Welt, mehrere Darstellungen

Die Hierarchie lautet Universum → Sternsystem → Himmelskörper → Oberflächenregion → Spielobjekt. Spezies und Fraktionen haben eigene Identitäten; eine Fraktion kann mehrere Regionen und Planeten besitzen, und eine Spezies kann mehrere Fraktionen bilden.

Ein Himmelskörper erhält eine stabile ID, Typ, Elternbezug, Seed, Generatorversion, Radius, Rotation, Achsenneigung, Schwerkraft-/Atmosphärenprofil und gegebenenfalls Orbitdaten. Gemeinsame Umlaufzentren können als eigene Bezugssysteme modelliert werden. Ein Stern, Mond oder Planet wird nicht durch seinen Platz in einer sortierten Liste identifiziert.

Erster Systemumfang: ein Stern, zwei feste Planeten, ein Mond. Danach zwei Sterne und unterschiedliche Konfigurationen. Geplante Vielfalt: Gesteins-, Ozean-, Wüsten-, Eis- und lebensfeindliche Welten; Gasriesen ohne normale begehbare Bodenoberfläche, Monde, Ringe und Asteroidengürtel. Mehrfachsterne und seltene Objekte folgen später als Inhaltserweiterung. Wir verwenden zunächst vorgegebene, deterministisch bewegte Spielorbits mit geprüften Abständen; eine allgemeine gravitative Vielkörpersimulation ist kein Startziel.

Sichtbarer Himmel, Beleuchtung, Systemkarte und Orbitansicht lesen dieselben Himmelskörper und dieselbe Simulationszeit. Zwei Sonnen dürfen nicht bloß zwei zusätzliche zufällige Lichtquellen sein. Tageslauf und Mondbewegung zuerst; Jahreszeiten, Finsternisse und Gezeiten später nach ihrem Spielnutzen.

### 2. Echte Kugeloberfläche früh beweisen

**In M1 erprobt:** sechs verbundene Cube-Sphere-Flächen mit begrenzten Nahkacheln; lokal bleibt eine kleine, präzise Simulationsumgebung um Spieler oder Kamera. Körperfeste Adressen und der lokale Ursprung sind als Vertrag für M2 bestätigt. Große Spielplaneten benötigen zusätzlich hierarchische Kachelunterteilung.

Speicherorte enthalten Himmelskörper-ID und eine kanonische Oberflächenadresse samt Höhe und Orientierung. Lokale `Vector3`-Positionen entstehen daraus nur für Darstellung und Physik. Ein verschiebbarer lokaler Ursprung verhindert, dass Planeten-/Systementfernungen in dieselben kleinen Physikkoordinaten gepresst werden. Globale Routen und Entfernungen verwenden das Oberflächenmodell, keine X/Z-Abkürzungen durch die Kugel.

Höhen, Wasser, Biom, Hindernisse und Bodennormale kommen aus einem gemeinsamen Oberflächenzugriff. Der heutige X/Z-Generator wird zunächst über einen Adapter weiterverwendet. Für eine geschlossene Kugel brauchen globale Kontinente, Klima und Gewässereinzugsgebiete anschließend eine kugelweit konsistente Quelle. Eine unendliche Ebene einfach um eine Kugel zu wickeln wäre keine ausreichende Migration.

In M1 gehören dazu: Übergang über Kachelgrenzen, Polregionen, vollständige Umrundung eines kleinen Testplaneten, Stehen/Gehen mit lokaler Schwerkraft und Wiederfinden desselben Küstenortes aus dem Orbit. Shader, Wasserhöhe, Raycasts, Animation, Spawnpunkte und Navigation werden ebenfalls auf feste Welt-Y-Annahmen geprüft. Der vorhandene plane Heightmap-Collider bleibt nur dort, wo die lokale Näherung reicht; gekrümmte Testbereiche benötigen passende Kollisionsgeometrie.

**Bestandsschutz:** Alte Spielstände behalten zuerst ihre alte Generatorversion in einem kompatiblen Oberflächenmodus. Vor einer Überführung auf die Kugel gibt es Backup, Ortszuordnung und einen Migrationsbericht. Neue Kugelwelten können einen neuen Kampagnenstand benötigen, falls alte Landschaften nicht verlustarm abbildbar sind; das wird vor einer solchen Umsetzung mit Lars geklärt. Eine identische Abbildung der gesamten bisherigen unendlichen Ebene wird nicht versprochen.

### 3. Simulation vom sichtbaren Objekt trennen

Ein Tier, Gebäude oder Schiff darf beim Ausblenden nicht aus dem Kampagnenzustand verschwinden. Die Detailstufen sind: nahe Objekte mit Physik und Animation; entfernte Gruppen mit vereinfachten Entscheidungen; Regionen mit Bevölkerung, Vorräten und Beziehungen; entfernte Systeme mit geplanten Ereignissen bzw. begrenztem Nachholen beim Besuch.

Keine permanente Vollsimulation aller Planeten. Jeder Zustand hat genau einen zuständigen Simulationsbesitzer. Beim Wechsel zwischen Gruppe und einzelnen Tieren werden Population, Schaden und Ressourcen einmal übergeben; sichtbare Jagd darf nicht zusätzlich als abstrakter Verlust doppelt abgerechnet werden. Dasselbe gilt später für Armeen, Transporte und Städte.

Gemeinsame Spielzeit, Pause und Geschwindigkeitsstufen werden vor Wirtschaft und Orbits definiert. Kampagnenzeit und reale Uhrzeit sind getrennt; standardmäßig kein ungebremster Fortschritt während das Spiel geschlossen ist.

### 4. Phasenwechsel übernehmen eine Gesellschaft

Phasenwechsel werden als überprüfbarer Ablauf gebaut: Voraussetzungen erfüllen → bewusster Start durch Spieler → sichern → Vermächtnis einmal berechnen → Steuerung und verfügbare Systeme umstellen → am selben Ort fortsetzen. Ein Fehler oder Neustart darf weder doppelte Boni noch verlorene Bewohner erzeugen.

Erhalten bleiben Spezies-ID, Kreaturenentwurf, Entdeckungen, Verhaltenserbe, Beziehungen, relevante Orte, Besitz und Baupläne. Das einzelne Nest kann zum Ausgangspunkt einer Siedlung werden. Bevölkerung wird spätestens vor der Stammesphase ein eigener Zustand, nicht eine Anzahl gerade geladener Tier-Nodes.

Frühe Phase: direkte Kreaturensteuerung. Stamm: kleine Gruppe und Aufgaben. Mittelalter: Siedlungen und regionale Organisation. Weltmacht: Reiche, Produktion und globale Entscheidungen. Weltraum: Schiff, Kolonien und Systeme. Gemeinsame Befehle und Zustandsdaten vermeiden fünf voneinander isolierte Spiele; Kameras und Bedienoberflächen dürfen phasenspezifisch sein.

### 5. Gemeinsame Editoren, getrennte Funktionen

Die bestehende Modular Assembly wird erweitert, nicht durch vier Kopien ersetzt. Gemeinsame Basis: Auswahl, Verschieben/Drehen/Skalieren, Symmetrie, Andockpunkte, Undo/Redo, Katalog, Vorschaubilder, Versionsmigration und Speichern/Laden. Bauplan, platzierte Instanz und gesellschaftliche Freischaltung bleiben getrennt.

| Editor | Zu überarbeitende bzw. neue Funktionen | Früher Funktionsnachweis |
|---|---|---|
| Kreatur | Körperkurve und Volumen intuitiv formen; stabile Gelenk-/Teilbindung; brauchbare zwei-, vier- und mehrbeinige Körper; verständliche Werte und Kosten; Farb-/Materialgestaltung | Im Editor bearbeiten, laufen/schwimmen/angreifen, zurückkehren und unverändert weiterbearbeiten |
| Gebäude | Einheitliche Bedienung; klare Größen, Bodenauflage, Eingänge und Baufläche; Wohn-/Produktions-/Gemeinschaftsfunktionen; Kosten und Unterhalt | Eigenes Haus im Dorf platzieren, erreichen und tatsächlich nutzen |
| Fahrzeug | Räder/Ketten/Schwimmkörper/Flugteile nach Epoche; Antrieb, Last, Sitzplätze, Transport und Bewaffnung | Eigener einfacher Transporter bzw. eigenes Boot führt einen Auftrag aus |
| Raumschiff | Hülle, Antrieb, Energie, Fracht, Sensorik und Einsatzmodule; Reichweite und Grenzen | Eigenes kleines Schiff startet, fliegt zu einem Mond und landet wieder |

Körperteile schalten tatsächlich passende Fähigkeiten frei; vorhandene Werte wie `swim` allein genügen nicht. Erscheinung, Funktionsmodul und Kosten werden so verbunden, dass Dekoration möglich bleibt und das hundertfache Anbringen desselben Teils keine unbegrenzten Boni erzeugt. Komplexitäts-, Kollisions- und Animationsbudgets gehören zur Validierung. Stadt-Fernansichten verwenden dieselben Spielerentwürfe in vereinfachter Darstellung.

## Skilltree und phasenübergreifendes Vermächtnis

### Grundregel

Der Spieler verdient durch relevante abgeschlossene Handlungen **Sozialpunkte** oder **Aggressionspunkte** und verteilt sie bewusst auf passende Knoten. Die Anzeige erklärt Handlung, Punkte, Kosten, Voraussetzung, aktuellen Effekt und spätere Wirkung. Gemischte Spielweisen sind möglich; das System legt die gesamte Kampagne nicht nach dem ersten Kampf fest.

Vier Dinge werden auseinandergehalten:

| Fortschritt | Quelle und Aufgabe |
|---|---|
| Entdeckung / bisheriges Insight | Arten, Regionen und später Funde kennenlernen; vorhandene Körperteilfreischaltungen erhalten |
| Verhaltens-Skilltree | Soziales/aggressives Handeln; gewählte Spezialisierung und Vermächtnis |
| Technikforschung | Neue Werkzeuge, Produktionsweisen, Fahrzeuge und Raumfahrt; eigene Voraussetzungen |
| Beziehungen / Ruf | Wie eine konkrete Art oder Fraktion auf Handlungen reagiert; kann unabhängig vom dauerhaften Speziesbonus wechseln |

Körperbau ist ebenfalls keine Gesinnung: Zähne erzwingen keinen aggressiven Weg. Technikzugang und Phasenfortschritt müssen mit sozialer, aggressiver und gemischter Spielweise erreichbar sein.

### Beispiele je Phase – Entwurf, noch keine festgelegten Zahlen

| Phase | Sozialpunkte beispielsweise für | Aggressionspunkte beispielsweise für | Mögliche gewählte Wirkung in späteren Phasen |
|---|---|---|---|
| Kreatur | Erstmaliges Befreunden, Helfen, gemeinsames Überleben | Erfolgreiche Jagd oder gewonnener Revierkonflikt | Gruppenkoordination / Einschüchterung und Kampforganisation |
| Stamm | Teilen, Bündnisse, gemeinsam abgeschlossene Aufgaben | Erfolgreiche Überfälle oder militärisch entschiedene Konflikte | Handel und gesellschaftlicher Zusammenhalt / Ausbildung und Verteidigungsorganisation |
| Antike/Mittelalter | Handelspartnerschaften, ausgehandelte Konfliktlösung, Zusammenarbeit | Belagerung, Eroberung oder militärischer Sieg | Diplomatie und Verwaltungszusammenarbeit / militärische Versorgung und Befestigung |
| Weltmacht | Verträge, gemeinsame Forschung, friedliche Einigung | Gewonnene Feldzüge, militärische Expansion | Koloniekooperation und Außenbeziehungen / Flottenführung und Abschreckung |
| Weltraum | Erstkontakt, Hilfe, interstellarer Handel und Bündnisse | Raumgefechte und Eroberungen | Spezialisierung innerhalb der weiteren Weltraumkampagne |

Dies sind Designvorschläge für Voxelverse, keine Behauptung über konkrete Spore-Regeln. Selbstverteidigung und Jagd zum Überleben werden beim Balancing von gezielter Unterwerfung unterschieden. Aggressiv ist ein Spielstil, keine automatische moralische Bewertung.

### Schutz gegen endloses Punktesammeln und widersprüchliche Boni

- Punkte entstehen aus geprüften Spielereignissen, nicht aus jedem Klick, jeder Animation oder jedem Schadenspunkt. Ereignisse tragen ID, Phase, beteiligte Objekte und Ergebnis.
- Wiederholtes Laden, Chunk-Neuladen oder Tier-Respawn vergibt keine doppelte Belohnung. Wiederholungen desselben einfachen Verhaltens erhalten Abklingzeiten, abnehmende Erträge oder ein Begegnungslimit.
- Aktionen künstlich zu erzeugen, etwa einen Verbündeten verletzen und anschließend heilen, darf keinen positiven Punktekreislauf liefern.
- Das Spiel speichert verdiente und ausgegebene Punkte, gekaufte Knoten und bereits verrechnete Ereignisse. Der Speicherbedarf der Historie bleibt begrenzt durch abgeschlossene Begegnungen und kompakte Phasenzusammenfassungen.
- Vorläufige Regel: Punkte bleiben an ihre Phase gebunden. Unverbrauchte Punkte können später noch für Knoten dieser Phase eingesetzt werden; deren Kosten und Grenzen bleiben erhalten. Neue Phasen eröffnen neue Knoten und passende Verdienstmöglichkeiten.
- Phasenspezifische Effekte und dauerhaftes Vermächtnis sind getrennt. Bereits gewählte Vermächtnisknoten gelten einmal; spätere Käufe ergänzen sie einmal. Es gibt keine erneute Multiplikation bei Laden oder Phasenwechsel.
- Ein zentraler Effektberechner kombiniert Körperwerte, Technik und Vermächtnis mit begrenzten, erklärbaren Werten. Vergangene Entscheidungen bleiben wirksam, ohne einen Richtungswechsel in der nächsten Phase zu verhindern.
- Startumfang: zwei kleine Äste mit je drei sinnvoll unterscheidbaren Kreaturen-Knoten und je einem nachweisbaren Stammesbonus. Weitere Themen wie Forschung/Kultur ergänzen wir erst nach dem ersten Spieltest, nicht als fünf zusätzliche Währungen vorab.
- Umskillen, konkrete Zahlen und die Bewertung einzelner Grenzfälle sind offene Balancingentscheidungen. Vorschlag: faire Korrekturmöglichkeit in der aktuellen Phase; kein beliebiges Hin-und-her-Wechseln bereits abgeschlossener Vermächtnisse.

## Reihenfolge und Abnahmekriterien

**M0: technisch geprüft** (`3f7f2252e3cbce868920dcf7c86beb3b47d17354`, [Nachweise](docs/CAMPAIGN_CONTRACTS.md)). **M1: begrenzter Technikprototyp geprüft. M2–M10: geplant.** Lars' manueller Spieltest von M0 ist noch offen. Der vorhandene spielbare Stand oben bleibt die Ausgangsbasis für M1. Reihenfolge ist wichtiger als ein unbelegter Kalendertermin. Jeder Meilenstein endet mit einer kleinen prüfbaren Version.

| ID | Arbeitspaket | Voraussetzung | Fertig, wenn … |
|---|---|---|---|
| M0 | **Technisch geprüft:** Kampagnenverträge, IDs, gemeinsame Sicherung, Phasen-/Ereignismodell | Ausgangsstand `e1b0b7f` | Migration mit Kreatur, zwei Gebäuden, Entdeckungen und zwei Planeten; separater Prozessneustart; Ereigniswiederholung und unterbrochener Debug-Übergang geprüft. Commit `3f7f2252e3cbce868920dcf7c86beb3b47d17354`; manueller Spieltest offen |
| M1 | **Technikprototyp geprüft:** Kugelplanet und Sternsystemlabor | M0 | Polare Umrundung mit echter Physik, Kantenstrahlen, begrenztes Streaming, radialer Ozean, Orbit/Rückkehr und Prozessneustart bestanden. 49 Gesamtprüfungen, native Exporte und sieben Renderfälle in zwei Grafikmodi. Manueller Spieltest und produktive große Planeten offen. [Nachweise/Grenzen](docs/PLANET_M1.md) |
| M2 | Verhaltensfortschritt und gemeinsame Editorverträge | M0, Koordinatenentscheidung aus M1 | Echte bzw. im Test ausgelöste Ereignisse vergeben einmal Punkte; Knoten wirken einmal; Blaupausen besitzen stabile Identität und Revision; Import/Undo/Redo bleiben erhalten |
| M3 | Kreaturen und Kreatureneditor überarbeiten | M2; Laufzeit auf M1-Grundlage | Repräsentative Körperformen lassen sich verständlich gestalten und bewegen; Vorschau und Spiel stimmen überein; erste Körperfähigkeiten funktionieren |
| M4 | Lebendige Tierwelt und vollständiger Kreaturen-Spielablauf | M1–M3 | Herde, Nahrungssuche, Räuber-Beute, Befreunden, Entdeckungsbuch und kleiner Skilltree bilden einen spielbaren Ablauf; sozialer und aggressiver Fortschritt funktionieren |
| M5 | Erster echter Wechsel Kreatur → Stamm | M4 | Aus derselben Spezies am bekannten Ort wird eine kleine steuerbare Gruppe mit einer nutzbaren Behausung; Vermächtnis, Besitz und Beziehungen bleiben nach Laden erhalten |
| M6 | Stammesphase und Gebäudeeditor | M5 | Ein kleines Dorf mit selbst gestalteten Gebäuden, Aufgaben, Vorräten und Nachbargruppe ist spielbar; Bündnis und Konflikt sind alternative Fortschrittswege |
| M7 | Antike/Mittelalter und erste Fahrzeuge | M6 | Mehrere Siedlungen handeln/konkurrieren; Landwirtschaft, Handwerk, Wege und ein Transportfahrzeug oder Boot funktionieren; regionaler Fortschritt ist erreichbar |
| M8 | Weltmachtphase | M7, globale Oberfläche aus M1 | Globale Karte, Reiche, Ressourcenketten, Industrie, Diplomatie und Armeen funktionieren mit vereinfachter Fernsimulation; Raumfahrt wird nachvollziehbar freigeschaltet |
| M9 | Weltraumphase und Raumschiffeditor | M8, Himmelskörpermodell aus M1 | Eigenes Schiff startet, besucht einen Mond/zweiten Planeten, gründet eine versorgte Kolonie und kehrt zurück; danach zweites System mit Kontakt, Handel oder Konflikt |
| M10 | Umfang, Balancing und Veröffentlichung | Funktionierender Ablauf bis M9 | Die ganze Kampagne ist wiederholt durchspielbar; Inhalte, Bedienung, Ton, Lernhilfen, Speichern und Leistung erfüllen festgelegte Abnahmen |

M2-Datenarbeit kann nach M0 schon stattfinden, während die M1-Entscheidung reift. Größere neue Welt-, Navigations- oder Stadtfunktionen warten auf den Koordinatennachweis. Wir bauen zunächst ein einziges gutes Beispiel pro System und verbreitern es danach. Alle Phasen werden nicht gleichzeitig als halbfertige Baustellen begonnen.

### M0 – technisch geprüft, manueller Spieltest offen

1. Stabile IDs für Kampagne, Körper, Region, Spezies, Fraktion, Objekt und Entwurf einführen; Seed und Anzeigename bleiben separate Felder.
2. Speicherbesitz klären: Kampagne besitzt Gesellschaft/Fortschritt, Registry die Entwürfe, Weltregionen die Instanzen. Keine zweite Kampagnenphase im Kreatureneditor. Bauplanrevisionen werden von gespeicherten Instanzen gezielt referenziert.
3. Schema- und Generatorversionen, Migrationsschritte und Backups definieren. Kampagne und separate Kreaturen-/Gebäude-Dateien gemeinsam sichern; fehlende Teile erhalten einen erklärbaren Ersatz statt stiller Löschung.
4. Phasenverwaltung um Voraussetzungen, Übergabedaten, sicheren Abschluss und Wiederaufnahme ergänzen. Bestehende Enum-Werte in alten Saves nicht umnummerieren. Debug-Phasenwechsel bleiben getrennt vom normalen Fortschritt.
5. Kleine typisierte Spielereignisse für Entdeckung, Interaktion, Konfliktergebnis und Phasenwechsel einführen. Ereignismodell anhand des kleinen Skilltrees prüfen, keine allgemeine Großarchitektur bauen.

**Technische Abnahme ausgeführt:** Schema-2-Beispiel mit Kreatur, zwei Gebäuden, Entdeckungen und zwei besuchten Planeten; identische IDs und Revisionen in einem zweiten Godot-Prozess; wiederholte Entdeckung ohne zweite Insight-Belohnung; Ereignisse nach Wiederholung abgelehnt; unterbrochener Debug-Übergang wird einmal abgeschlossen. Dazu Schreibfehler, beschädigter Hauptstand, gemeinsame Wiederherstellung ohne lose Editor-Dateien und Schutz unbekannter Versionen. Vollständiger bestehender Prüflauf und Linux-Export erfolgreich. Nachweis: `tests/campaign_foundation_test.gd` und [Kampagnenverträge](docs/CAMPAIGN_CONTRACTS.md).

**Rest bewusst in späteren Paketen:** echter Skilltree M2/M4, persistente Einzeltiere/Ressourcen M4, Bevölkerung und produktiver Phasenwechsel M5. Die Normalprüfung von Phasenvoraussetzungen sperrt unfertige Phasen. Die bisherige Ebenenadresse ist kein Kugelnachweis. Die Uhr steuert Kampagnenzeit/Ökologie; ein globales Geschwindigkeitsmenü ist noch nicht vorhanden.

### M1 – begrenzter Technikprototyp geprüft

1. Systemkatalog auf gemeinsame versionierte Himmelskörperprofile umstellen, V8/V9-Doppelquelle auflösen. Alten Seed→Planet-Bezug erhalten.
2. Oberflächenadresse, globale/lokale Umrechnung und gemeinsamen Terrain-/Wasser-/Normalenzugriff bauen; bisherigen Generator über Adapter anschließen.
3. Einen kleinen geschlossenen Testplaneten mit Kollisionsoberfläche bauen. Kachelkanten, Pole, Umrundung, Origin-Wechsel und Editor-/Kreaturenplatzierung prüfen. Anschließend die künftig benötigte größte Planetengröße gezielt auf Präzision prüfen.
4. Globale Höhen-/Klimaquelle und Gewässerkontinuität demonstrieren. Nahterrain und Orbitansicht teilen dieselben Küsten und Landmarken; beide besitzen unterschiedliche Detailstufen.
5. Planet, Mond und Sonne in einer Systemansicht anzeigen; Bodenhimmel aus denselben Daten. Dann denselben Test mit zwei Sonnen, Tag-/Nachtwechsel und gespeicherter Zeit durchführen.
6. Kontrollierten Wechsel Oberfläche → Orbit → derselbe Ort demonstrieren. Ein Lade-/Kameraübergang ist für den Techniktest zulässig; ob später vollständig nahtlos geflogen wird, ist eine gesonderte Umfangsentscheidung.

**Implementiert:** F4 öffnet das eigenständig gespeicherte Labor mit Haven (256 m), Ember (160 m) und Lune (64 m), gemeinsamen V9-Profilen, sechs geschlossenen Kugelflächen, höchstens 24 Nahkacheln, radialer Bewegung und gemeinsamem Himmel/Orbit/System. Die bisherige Welt bleibt im Modus `legacy_plane_v9`. Koordinaten bei Erdradius sind rechnerisch geprüft; erdgroßes Terrain ist noch kein Laufzeitnachweis. Die konkrete M1-Entscheidung für M2 ist eine körperfeste Cube-Sphere-Adresse mit lokalem Ursprung; große Kugeln benötigen weitere Kachelunterteilung.

**M1-Ausbau, eigener Branch `agent/planet-lod-menu`:** Aster ergänzt einen Planeten mit 4.096 m Radius, hierarchischer Unterteilung und Terrain-/Wasserübergängen. Die Hierarchie bleibt vollständig geschlossen, enthält höchstens 768 sichtbare Geländekacheln und 24 Kollisionskacheln. Ein Hintergrundauftrag berechnet die nächste Unterteilung; die alte Oberfläche bleibt bis zur vollständigen Veröffentlichung erhalten. Zusätzlich werden die fernen Voxelstufen der bisherigen Welt feiner und Esc/F8-Menü sowie F4-/Menüeinstieg im nativen Export geprüft. [Umsetzung und Nachweise](docs/PLANET_LOD_AND_MENU.md).

**Spieltest-Rückmeldung von Lars:** Der bisherige Spielstand sieht besser aus; die entfernte Berglandschaft braucht weitere Verbesserung. F4 funktionierte in seiner EXE nicht, und das F8-Menü nahm keine Linksklicks an. Das ist eine positive Teilrückmeldung zur bisherigen Welt, noch keine manuelle Abnahme des Planetenlabors oder sämtlicher M0-Kriterien.

**Abnahme:** Keine sicht-/begehbaren Nahtlöcher, kein Wechsel in eine andere Landschaft beim Landen, kein Verlust des gespeicherten Orts, keine ungebundene Zunahme geladener Kacheln. Abweichungsgrenzen für Höhe/Ort, Planetengrößen und Messszene vor dem Test festhalten. M1 darf erst als abgeschlossen gelten, wenn der verwendete Kugelansatz funktioniert; eine gezeichnete Planetenkugel allein reicht nicht.

### M3–M6 – zuerst ein vollständiger Spielablauf

Kreatureneditor zuerst an wenigen Referenzkörpern prüfen: Zweibeiner, Vierbeiner und ein weiterer Körperplan; Schwimmen als Bewegungsfall. Nicht sofort dutzende neue Teile produzieren. Die visuelle Abnahme umfasst Silhouette, Gelenkanschlüsse, Fußkontakt, Angriff und Rückkehr aus dem Wasser.

Tierwelt zuerst mit einer Pflanzenfressergruppe und einer jagenden Art. Lebensräume, sichere Trinkstellen, Flucht und Ende einer Jagd sind konkrete Situationen. Darauf folgen Befreunden und Hilfe als ebenso ausgearbeitete Alternative zum Kampf. Das Entdeckungsbuch verwendet die bestehende Registrierung und Teilfreischaltung.

Die erste Stammesprobe braucht nur wenige Mitglieder, eine Aufgabe, Nahrung, eine nutzbare Behausung und eine Nachbargruppe. Sie muss den gewählten Kreaturenbonus wirklich anwenden. Erst danach kommen mehr Gebäude, Berufe, Stammesausrüstung und größere Siedlungen. M5 prüft die erste platzierte Behausung; M6 überarbeitet dafür den vollständigen Gebäudeeditor.

### M7–M9 – Gesellschaften und Raumfahrt schrittweise verbreitern

M7 führt regionale Produktion, Versorgung, Territorien, Forschung und Diplomatie zu einer spielbaren Einheit zusammen. Fahrzeuge nutzen gemeinsame Aufträge und Routen; zuerst eine Transportklasse, dann Land-/Wasser-/Luftvarianten passend zur Epoche. Bewohner brauchen nur dort Einzelverhalten, wo es spielerisch relevant ist.

M8 ergänzt globale Interessen, Infrastruktur, Energie, Umweltfolgen und Versorgung von Armeen. Diplomatische, wirtschaftliche und militärische Wege erhalten jeweils Ziele und Gegenreaktionen. Konkurrenzfraktionen verfolgen eigene begrenzte Ziele und Ressourcenregeln. Globale Wege und Besitz referenzieren dieselben Orte, die in der Nahansicht existieren.

M9 beginnt im Heimatsystem mit Start, Reise, Landung und Versorgung einer Kolonie. Danach Systemreise, Erstkontakt und fremde Reiche. Schiffsdesign, Technik und Verhaltenserbe beeinflussen Optionen. Terraforming und größere Flotten folgen erst nach dieser Schleife; Änderungen eines Planeten müssen seine versionierten Oberflächendaten verändern und bei einem Besuch erhalten bleiben.

## Ergänzungen, die sonst leicht fehlen

| Thema | Warum es zur Roadmap gehört | Spätestens einplanen |
|---|---|---|
| Kampagnenziel und Phasenkriterien | Der Spieler braucht mehr als neue Menüs: erkennbare kurz- und langfristige Ziele, mehrere erreichbare Wege | M0 Entwurf; M4/M5 erster Nachweis |
| Tod, Niederlage und Erholung | Verlust einer Kreatur, eines Stammes oder einer Kolonie braucht eine klare Fortsetzungsregel, ohne unbeabsichtigten Kampagnenverlust | M4, dann jede neue Phase |
| Bevölkerung und Identität | Individuum, Spezies und Fraktion sind verschiedene Dinge; Nachwuchs/Bevölkerungswachstum erfordert kein Genommodell | M0 Modell, M5 Spiel |
| Navigation und Befehle | Tiere, Bewohner, Fahrzeuge und Armeen brauchen gemeinsame Ortsdaten, aber verschiedene Bewegungsregeln | M1 Schnittstelle, M4 erster Einsatz |
| Ressourcen und Versorgung | Nahrung, Material, Produktion, Kosten und Transport verbinden Gebäude mit wirklichem Nutzen | M5 Grundbedarf, M6–M8 Ausbau |
| Beziehungen und Diplomatie | Sozialer Fortschritt braucht eigene Interaktionen, Ziele und Konsequenzen über alle Phasen | M2 Modell, M4 erste Interaktion |
| Technik versus Verhalten | Forschung darf nicht versehentlich ausschließlich durch Kampf erreichbar sein | M2 Trennung, M6/M7 Technik |
| Lernen und Bedienung | Neue Maßstäbe benötigen verständliche Kamera, Auswahl, Befehle und Hinweise; Kreaturenbedienung nicht einfach zum RTS aufblasen | M3, M5 und jeder Phasenwechsel |
| Ton und Rückmeldung | Tierlaute, Schritte, Treffer, soziale Reaktionen, Bau- und Interface-Ton machen Zustände lesbar | Ab M4 schrittweise |
| Leistung und Simulationszeit | Mehr Einwohner/Planeten dürfen nicht linear mehr aktive 3D-Objekte bedeuten | M0/M1 Grundlage; Messung pro Meilenstein |
| Inhalte und Entwurfskatalog | Eigene Arten und Architektur sollen wiedererkennbar sein; kuratierte Teile/Referenzen vor Massenproduktion | M3, danach phasenweise |
| Einstellungen und Zugänglichkeit | Skalierbare Schrift/UI, Tastenbelegung, Lautstärke und brauchbare Grafikstufen | Ab M3; vor M10 vollständig |
| Langzeitstände | Ein erfolgreicher kurzer Test beweist keine stabile mehrphasige Kampagne | Ab M5 wiederkehrende Speicher-/Langzeittests |

## Noch zu entscheiden – blockiert die Roadmap nicht

| Entscheidung | Vorgeschlagener Ausgangspunkt | Entscheidung spätestens |
|---|---|---|
| Planetengrößen und Zeitmaßstab | Spielbare komprimierte Maßstäbe; kleiner Testplanet plus größerer Präzisionstest, keine realistischen Entfernungen als Pflicht | M1 vor dem Geometrieausbau |
| Nahtloser Flug | Oberfläche und Orbit teilen dieselbe Welt; sichtbare Ladefreiheit erst nach funktionierendem Streaming bewerten | M1 technische Machbarkeit, M9 Produktumfang |
| Umfang der Mittelalterphase | Antike/Mittelalter zunächst eine gemeinsame Phase wie im bestehenden Enum; Epochen als interne Technikstufen | Vor M7 |
| Steuern in späteren Phasen | Gruppen-/Strategiesteuerung als Hauptmodus, direkte Kreaturenansicht als separat zu prüfende Zusatzfunktion | M5 |
| Umbau der Spezies nach der Kreaturenphase | Aussehen und Identität behalten; Umbauten an definierten Orten/Meilensteinen, Wirkungen auf vorhandene Einheiten klar regeln | M3 Entwurfsmodell, M5 Spielregel |
| Skilltree-Balancing | Zwei Verhaltensäste, begrenzte Boni, Mischwege, Korrekturmöglichkeit in aktueller Phase | M2/M4 |
| Niederlagenmodell | Wiederaufnahme mit nachvollziehbarem Verlust statt ungefragter Löschung der Kampagne | M4 |
| Ende der Weltraumkampagne | Langfristige Ziele und freies Weiterspielen; nicht von einer zusätzlichen Multiversumphase abhängig machen | Vor M9 |

Das bestehende `MULTIVERSE`-Enum bleibt zur Kompatibilität erhalten. Eine spielbare Multiversumphase ist ein späterer optionaler Ausbau und kein Hindernis für die fünf jetzt gewünschten Phasen. Multiplayer, tiefe Höhlenwelten und vollständige physikalische Orbit-/Klimasimulation gehören nicht zum aktuellen Kernumfang.

## Prüfungen und Pflege der Roadmap

Vor jeder Umsetzung: aktuellen Branch und vorhandene Änderungen prüfen, passenden Meilenstein und Abhängigkeiten lesen, das kleinste nutzbare Ergebnis festlegen. Nach jeder Lieferung: betroffene Zeile mit Status, Commit, Nachweis und Restpunkten aktualisieren. Eine angelegte Klasse, ein Enum oder ein Screenshot zählt nicht als fertige Spielschleife.

Statusbegriffe: **geplant → in Arbeit → technisch geprüft → im Spiel abgenommen**. Technische Prüfung und Lars' Spieltest werden getrennt dokumentiert. Wenn sich eine Grundentscheidung ändert, werden die betroffenen späteren Meilensteine und Migrationen hier angepasst.

Die vorhandenen Prüfungen zu Editor, Assembly, Speichern, Planetenwechsel, Wasser und Streaming bleiben relevant. Neue Tests betreffen tatsächliche Risiken: Kugelnähte/Koordinaten, doppelte Ereignisse, Phasenübernahme, Sichtbar-/Fernsimulation und Entwurfskompatibilität. Reine Dokumentationsänderungen erfordern keinen neuen Spiel-Build.

Leistungsziel vorläufig: flüssige 60 FPS auf einem noch konkret zu dokumentierenden Ziel-PC bei festgelegter Auflösung/Qualität. Dies ist ein Ziel, kein gemessener Ist-Wert. Pro Messszene werden aktive Tiere/Einheiten, Regionen, Draw Calls, Speicher, Framezeiten und Speicher-/Ladezeiten erfasst. Vor M6 wird eine größere Siedlung, vor M8 eine globale Kampagne und vor M9 ein Körperwechsel geprüft. Software-Renderer-CI ersetzt diese Ziel-PC-Messung nicht.

Letzter dokumentierter visueller Ausgangsstand: [Voxel-/Wassertiefenbericht](art/VOXEL_STYLE_DEPTH_REPORT.md). Die M0-Prüfungen sind separat in den [Kampagnenverträgen](docs/CAMPAIGN_CONTRACTS.md) dokumentiert; sie ersetzen keinen neuen visuellen Spieltest durch Lars.

**Parallele Arbeit:** Lars hat einen zweiten Chat mit dem Sozialsystem beauftragt. Dieser Branch bearbeitet Planetengelände, Detailstufen, Kollisionen und das Einstellungsmenü. Kampagnen-, Fortschritts-, Spielerinteraktions- und Speichervertragsdateien werden hier nicht umgebaut. Beide Arbeiten bleiben auf getrennten Branches; vor der Integration werden gemeinsame UI-, Prüf- und Dokumentationsänderungen abgeglichen.

**Nächster Arbeitsauftrag nach dieser Lieferung:** Aster, Menü und fernes Gelände auf Lars' Ziel-PC spielen und Leistung beurteilen. Für die produktive Kugelwelt fehlen weiterhin Weltobjekt-/Faunaanbindung und eine geplante Kampagnenmigration; M2-Editorverträge und anschließend M3/M4 bauen auf der bestehenden Koordinatenentscheidung auf. Der Sozialsystem-Fortschritt wird anhand der Ergebnisse des parallelen Chats eingetragen.
