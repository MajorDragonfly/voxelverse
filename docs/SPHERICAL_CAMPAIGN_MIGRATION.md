# Voxelverse: vollständiger Umzug auf Kugelwelten

Stand: 9. September 2026. Verbindliche Priorität nach der zweiten Zusammenführung. Ziel ist die Größenordnung einer bereisbaren prozeduralen Galaxie mit begrenztem Aufwand pro Aufenthaltsort. „Wie No Man’s Sky“ bezeichnet das Skalierungsziel; eine vergleichbare Leistung oder ein fertiger Raumflug ist damit nicht nachgewiesen.

## Entscheidung und heutige Grenze

Neue Weltentwicklung baut auf `cube_sphere_m1_v1`, dem vorhandenen radialen Adapter und `living_planet_v1` auf. Die aktive Flachkampagne wird schrittweise in diese Architektur überführt. Zusätzliche Epochen und große neue planare Gameplaybereiche warten auf diesen Umzug. Bestehende Inhalte, Arten, Bewohner, Besitz, Karten, Entwürfe und Fortschritte gehören weiter zur selben Kampagne.

Der reguläre Neue-Spiel-Start verwendet weiterhin `main/main.tscn` mit `legacy_plane_v9`. Zusätzlich bietet das Menü jetzt einen ausdrücklich eingeschränkten Kugelstart über `main/spherical_campaign.tscn`, denselben SaveGameService, dieselben Kampagnenidentitäten und die gemeinsamen Karten. Save 8/Kampagne 2 und eine atomare Kopiermigration früher, noch nicht räumlich entwickelter Stände sind implementiert; größere Ortsbestände werden mit konkreten offenen Fällen gesperrt. [M1e-Vertrag und Nachweise](WORK_M1E_CAMPAIGN.md) beschreiben diese Grenze. Die folgenden M1f–M1i-Abnahmen bleiben verbindlich. Der belebte Kugelbereich besitzt bereits Erdmaßstab, Gelände, Wasser, Flora, Tiere, Kollision, D1.2-Pflichtarten, lokale Ursprünge und Wiederbesuch. Er hat aber eine eigene Sicherung und weder die gesamte Kreaturenphase noch das Stammesdorf. Diese Trennung ist ein offener Implementierungsauftrag. Eine andere Startszene oder ein umbenanntes Labor würde ihn nicht erfüllen.

In dieser Integration werden die vorhandenen Mini-/Weltkarten an die belebte Kugelwelt angeschlossen. Sie verwenden dieselben Kartenbausteine und speichern pro Körper echte Erkundung. D2 und D3 teilen jetzt in der Kampagne denselben tatsächlichen Tierbestand. Das sind nutzbare gemeinsame Anschlüsse; der Kampagnenumzug selbst bleibt offen.

## Architektur, die mit dem Aufenthaltsort wächst

| Ebene | Persistenter Zustand | Aktive Laufzeit |
|---|---|---|
| Universum / Galaxie / Sektor | Stabile IDs, Generatorversionen, Seeds, benannte oder veränderte Einträge | Begrenzte Katalogabfragen und zusammengefasste Ansicht |
| Sternsystem / Körper | Körper-ID, Klasse, Radius, Orbit, Generatorbindung, besuchte Regionen | Nur benötigte Körperdaten und Sichtmodelle |
| Oberflächenregion | Cube-Sphere-Adresse, Terrainänderungen, bekannte Orte, lokale Populationen und Siedlungszustände | Begrenzte Terrain-/Objektaufträge um aktive Beobachter |
| Individuum / Bauwerk | Unveränderliche Objekt-ID, Spezies-/Fraktions-ID, Entwurfsrevision, persistenter Ort, Tätigkeit | Nahe Objekte mit Physik und Animation; entfernte Zustände ohne Node pro Objekt |

- **Koordinaten:** Körperfeste Adresse `{mode, body_id, face, u, v, height}`. Weltweite Meterwerte bleiben skalare Doubles/Arrays bis nach Abzug des lokalen Ursprungs. Erst kleine relative Werte werden `Vector3`. Das bestehende `cube_sphere.gd` löst diese Präzisionsgrenze bereits; keine zweite globale Koordinatenwelt ergänzen.
- **Oberfläche:** `radial_surface_adapter.gd` liefert Abtastung, lokale Position, Aufrichtung, Tangentialrahmen, Bindung und Ursprungskorrektur. Persistente Orte sind keine Szenen-Transforms. Physik, Wasser, Flora, Fauna, Häuser und Audio benutzen denselben Körper und dieselbe Oberflächenquelle.
- **Detailstufen:** Nahe Kollision, sichtbares Gelände und entfernte Oberfläche beruhen auf derselben versionierten Erzeugung. Keine separate dekorative Orbitkugel mit einer anderen Landschaft. Meshes, Tiere, Objektzustände und Hintergrundaufträge besitzen getrennte, gemessene Grenzen.
- **Simulation:** Jedes Individuum, jede Produktion und jede Fracht hat genau einen Simulationsbesitzer. Der Übergang zwischen physischer Nahsimulation und vereinfachter Fernsimulation übergibt Zustand und Zeitcursor atomar. Ein Milchzyklus oder eine Lieferung darf nicht in beiden Systemen laufen.
- **Zeit:** Pause und geschlossene Anwendung erzeugen derzeit keine nachträgliche Produktion. Ein späterer Offline-Modus wäre eine ausdrückliche neue Spielregel mit eigenem Vertrag.
- **Speicherbedarf:** Prozedurale unveränderte Welt entsteht aus Seed und Version. Dauerhaft gespeichert werden Identitäten, Änderungen und Spielerwissen. Besuchte Regionen werden segmentiert; ein wachsendes Universum darf nicht vollständig beim Laden des Startmenüs deserialisiert werden.

Die vorhandenen Laborgrenzen (drei große Referenzkörper, begrenzte Habitatsuche, aktive Landschaftszellen und Tiere) sind Prüfumfang, keine künftige Begrenzung des Universums. Einfach diese Konstanten zu erhöhen wäre kein Skalierungskonzept.

## Reihenfolge und verantwortliche Bereiche

| Paket | Konkreter Arbeitsumfang | Gemeinsame Einbaupunkte | Fertig, wenn … |
|---|---|---|---|
| M1e – Kampagne und Orte | Versionierter Oberflächenkontext; Kampagnenstart auf Kugel; oberflächenspezifisches Laden/Sichern; explizite Kopiermigration eines alten Spielstands | `core/campaign`, `GameState`, `SaveGameService`, `world/surface`, Menü-/Szenenübergang | Neue Kugelkampagne und alte Flachkampagne starten getrennt korrekt; ein alter Stand lässt sich mit überprüftem Manifest kopieren; Quelle und unbekannte neuere Daten bleiben geschützt |
| M1f – Kreaturenphase | Spieler, Kamera, Bedürfnisse, Nahrung, Scanner, Forschung, Sozialverhalten, Wildtiere und Heimatgruppe verwenden Kugelorte | `creatures/player`, `creatures/wildlife`, `world/home_group`, bestehende D1-/Fortschrittsdienste | Neue Kampagne → Gestaltung → Bewegen/Scannen/Sammeln → gleiche Gefährten → gleiche Heimat → Neustart auf der Kugel |
| M1g – Stamm und Tierhaltung | Radiale Auswahl/Kamera, lokale Routen, Häuser/Fundamente, Arbeitsplätze, Bewohnerwachstum, Nachbarn, D2-Befehle und D3-Pflege/Transport | `world/tribe`, `world/domestication`, bestehender D2→D3-Leseanschluss | Bestätigter Aufstieg erhält dieselben Bewohner; Zähmung → Tierplatz → Pflege → Milch → physischer Transport funktioniert samt Pause, Laden, blockiertem Weg und Wiederbesuch |
| M1h – Wasser, Fernzustand und Budgets | Körpergebundene Gewässer, Unterwasserzustand, räumliches Audio; Übergabe Nah/Fern; begrenzte Regionsdateien und Auftragswarteschlangen | Oberflächenadapter, Wasser-/Audiolaufzeit, Streaming und Speicherung | Lange Reise und Rückkehr verlieren weder Objekte noch Produktion; Speicher und aktive Objekte bleiben innerhalb expliziter Budgets |
| M1i – Umschalten und Abnahme | Kugelkampagne als regulärer Neue-Spiel-Start; alte Ebene nur noch Kompatibilitätseinstieg; gemeinsame Build- und Ziel-PC-Prüfung | Menü, Export, automatisierte Akzeptanz, Dokumentation | Vollständiger untenstehender Ablauf in einem gemeinsamen Spielstand und einem frischen Prozess bestanden |

M1e muss zuerst den gemeinsamen Orts-/Speichervertrag liefern. M1f und M1g dürfen ihre jeweiligen Verbraucher daran anschließen, ohne konkurrierende Save-Services oder neue Kampagnenmodelle anzulegen. M1h beginnt seine Budgetmessung früh und schließt die Fernsimulation nach dem funktionsfähigen Nahablauf ab. Die gemeinsame Integrationsverantwortung bleibt bei einem Arbeitsstrang; Fachpakete ändern den Vertrag nicht unabhängig voneinander.

## Umzug vorhandener Spielstände

Die bisherige Ebene ist nicht dieselbe Landschaft wie der endliche Planet. Eine stille Umdeutung von `[x,y,z]` in Kugelkoordinaten würde Terrain, Heimorte und Fracht beschädigen. Die Migration ist deshalb ein eigenständiger, wiederholbar geprüfter Kopiervorgang:

1. Quelle vollständig validieren; Kampagnen-, Generator- und sämtliche verschachtelten Versionen prüfen. Ein unbekannter neuerer Hauptstand darf nicht durch einen älteren Backupstand überschrieben werden.
2. Besiedelte und veränderte Regionen, eigene/befreundete Individuen, Heimatorte, Besitz, Fortschritt, Entwürfe, Vorräte und laufende Tätigkeiten inventarisieren. Quelle mit Hash und Versionsangaben im Migrationsmanifest festhalten.
3. Einen geeigneten Zielbereich je tatsächlich übernommenem Ort prüfen. Lokale Anordnung innerhalb eines begrenzten Tangentialbereichs erhalten; große Entfernungen über explizite regionale Zuordnung behandeln. Meer, Steilhänge, Überlappungen, gesperrte Wege und fehlende Zielkapazität erzeugen einen konkreten Fehlerbericht statt stilles Löschen.
4. `species_id`, `faction_id`, `object_id`, Entwurfsrevisionen und Eigentum erhalten. Oberflächenreferenzen mit dokumentierter Quell-/Zielzuordnung ersetzen. Globale Fortschritts- und Wirtschaftsbelege behalten ihre Einmaligkeit; Materialien, Tröge und Fracht existieren genau einmal.
5. Entdeckungswissen erhalten. Planare Erkundungszellen werden nicht als bereits erkundete ganze Kugel ausgegeben. Übernommene Orte erhalten eigene Zieladressen; nicht übertragbare alte Kartenbereiche bleiben als Altdaten zugänglich.
6. Vollständigen Zielstand in einen neuen Slot schreiben, zurücklesen und validieren. Erst danach den erfolgreichen Umzug anzeigen. Wiederholung mit demselben Manifest erzeugt weder zusätzliche Bewohner noch neue Belohnungen. Original und Rückkehrweg bleiben erhalten.
7. In einem frischen Prozess am Ziel starten und die Inventare, Personen, Tiere, Orte, Fracht und Fortschrittsstände gegen das Manifest vergleichen.

Die unbegrenzte unbesuchte Ebene wird nicht in die endliche Kugel hineinkopiert. Alle persistenten Spieleränderungen müssen entweder geprüft übernommen oder als konkret benannte offene Migrationsfälle erhalten werden; ein pauschales Abschneiden ist unzulässig.

## Abnahmekette vor Ablösung des aktiven Flachstarts

- Ein neues Spiel auf einer Kugel beginnt mit der gestalteten Spezies. Scanner, Nahrung, Verhalten, Körperteile und Fähigkeiten funktionieren mit dem gemeinsamen Buch und denselben Diensten.
- Heimatgruppe gründen, Stamm ausdrücklich bestätigen, gleiche Individuen wiederfinden, Material holen, Werkzeug bauen, Unterkunft errichten und Bewohner versorgen.
- D1-Milchtier mit realem Bewohner zähmen; D2-Besitz bleibt vom Befreunden getrennt. In D3 halten, füttern, tränken, einen vollständigen Milchzyklus ausführen und die Milch tatsächlich ins Lager transportieren.
- Wege blockieren, Fracht stoppen/fortsetzen, während Produktion und Transport speichern, Anwendung schließen und neu starten. Keine verlorene oder doppelte Ware, keine doppelte Prämie und keine unfreiwillige Wiederbelebung.
- Auf kleinem Körper eine Flächenkante und mehrere Ursprungswechsel überschreiten; denselben Ablauf auf Terra im großen Radius prüfen. Körperwechsel und Rückkehr erhalten Heimat, Tiere, Karte und Tätigkeiten.
- Geladene Objektzahl, Terrainjobs, Queue-Längen, RAM/VRAM und CPU-/GPU-Framezeiten bei Stand, Bewegung und längerer Reise messen. Zahlen mit Hardware, Route und Renderverfahren dokumentieren. Kein FPS-Versprechen aus Headless- oder Software-Renderer-Tests ableiten.
- Linux-/Windows-Paket außerhalb des Quellprojekts sowie Darstellung und Bedienung auf dem Ziel-PC prüfen. Mittelalter und Raumfahrt bleiben bis zu ihren eigenen vollständigen Spielabläufen gesperrt.

## Weiter gültige Produktregeln

Nur die eigene Spezies entwickelt eine Zivilisation. Fremde Tiere werden durch Zähmung keine Bürger. Gebäudeeditor erst im vorgesehenen Mittelalterpaket; feste frühe Hütten/Zelte bleiben bestehen. D4-Reiten und Pflügen bauen auf den übernommenen B3-Anschlüssen und radialen Routen auf. Für sämtliche Oberflächen gilt [VOXELVERSE_DESIGN.md](VOXELVERSE_DESIGN.md).
