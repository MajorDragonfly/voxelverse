# Minimap – Übergabe vom 9. September 2026

Quellcommit: **9be889f48acf346650b02137b160bd8fcedf7317**. Branch: `agent/minimap-2026-09-09`.
Basis: UI-Paket `c276bdc4452b5585b93b3f81f163738670d98ca8` auf integriertem main `3a3e0272375e556f3ff65b7370582af79a9d48b5`.
Keine fremden unfertigen Fachbranches übernommen. Dieses Paket ist lokal geprüft und als Windows-Testversion gebaut; noch nicht öffentlich hochgeladen oder nach main übernommen.

## Architekturentscheidung

Eine gemeinsame Minimap mit Phasenprofilen vermeidet fünf getrennte Kartenimplementierungen. Darstellung, Zoom, Marker und Gelände-Cache bleiben identisch. `minimap_source.gd` liest die jeweils aktive Welt, `surface_map_projection.gd` übersetzt ihre körpergebundenen Orte in Meter. Eine spätere Orbit-/Systemkarte braucht einen passenden Quellen-/Projektionsadapter, keine Kopie des gesamten HUD.

| Phase | Standardbreite der Karte | Anschluss |
|---|---:|---|
| Kreatur | 128 m | Laufende Kampagne |
| Stamm | 320 m | Tatsächlicher bestätigter Übergang, Gruppenansicht |
| Mittelalter | 1,28 km | Profil vorbereitet |
| Neuzeit | 5,12 km | Profil vorbereitet |
| Weltraum – Oberfläche | 25,6 km | Profil vorbereitet; Orbit/System behalten ihre eigene Ansicht |

Die Profile schalten keine fehlenden Spielphasen frei. Plus/Minus wählen 0,5×, 1× oder 2× des Phasenmaßstabs; der Rückstellknopf stellt 1× wieder her. Phasenwechsel, Weltwechsel und Laden setzen den Standard zurück. Auf kleinen Testkugeln wird die lokale Ausdehnung begrenzt, damit sie nicht um die Gegenseite des Körpers läuft.

## Verhalten

- Unten rechts: nordorientiertes Gelände, tatsächlich abgefragtes Wasser, Blickrichtung, Maßstabsbalken. Kartentext zeigt die gesamte Breite; der Balken entspricht einem Viertel davon.
- Heimatmarker bleibt am Kartenrand als Richtungshinweis sichtbar. Eigene Gefährten und im Stamm alle drei Bewohner einschließlich Originalkreatur stammen aus den vorhandenen Körperdaten bzw. aktuellen Actor-Positionen. Gewählte Bewohner erhalten einen Ring. Die Stammeskarte folgt dem Kamerafokus.
- Keine Tiernamen, unbekannten Arten, Rohstoffmarker oder automatisch verdienten Entdeckungen. Wegpunkte und gezähmte Tiere aus D2 sind noch nicht angeschlossen.
- Karte pausiert und verschwindet bei pausierenden Büchern/Menüs. Kartenklicks werden abgefangen und erteilen keine Dorfaufträge. Zoomtasten funktionieren ohne freigegebenen Mauszeiger; die Buttons stehen bei sichtbarer Maus bereit.
- Gruppenaktionen erhalten Platz links neben der Karte. Bei wenig Höhe begrenzt ein Scrollbereich die Dorfbedienung; alle Befehle bleiben erreichbar.
- Im Planetenlabor verwendet dieselbe Karte die echte Kugeloberfläche und den kanonischen Walker-Ort. Sie verschwindet in Orbit, Sternsystem und Galaxiekatalog.

## Daten und Leistung

Keine Schemaänderung, kein zusätzlicher Spielstand, keine Migration. Quellen greifen ausschließlich lesend auf Kampagne, Heimat und Stamm zu. Karte und Marker werden nach Laden aus diesen Daten abgeleitet; Körper-/Kampagnenwechsel verwerfen das Raster.

Kugelkoordinaten werden vor der Umrechnung in Bildschirmvektoren mit skalaren Double-Werten relativ zum Körper verarbeitet. Die Projektion funktioniert über Cube-Face-Grenzen, Pol und Floating-Origin-Verschiebung; große Ortswechsel bauen den lokalen Rahmen neu auf.

Das Raster enthält 48 × 48 Geländepunkte. Sampling läuft schrittweise von innen nach außen: höchstens 32 Punkte je Frame, weiches Zeitbudget von 1,4 ms. Ein einzelner Generatoraufruf kann das Budget überschreiten; dies ist keine harte Framezeitgarantie. Der Cache bleibt auf 6.144 Einträge begrenzt und wird per FIFO-Ring verwaltet. Kein zweiter Welt-Render und keine Minimap-Kamera.

Gemessen mit echtem V9-Generator im Headless-Lauf dieser Umgebung: 2.304 Abfragen pro vollständigem Erstaufbau, circa 145 ms Gesamtarbeit bei 64 m Radius bzw. 108 ms bei 160 m. Verteilt auf 85 bzw. 76 Arbeitsschritte. Größter gemessener Sampling-Schritt 8,31 bzw. 1,47 ms bei gleichzeitig laufenden anderen Prüfungen. Stillstand: **0 neue Geländeabfragen**. Eine Rasterzelle Bewegung benötigt nur 48 neue Punkte; unmittelbarer Wiederbesuch nutzt den Cache. Grafik-/Ziel-PC-Frametimes sind damit nicht gemessen.

## Prüfung

Godot **4.6.3**, jeweils isolierte Testspielstände. Bestanden:

- `minimap_test`: Bewegung/Blickrichtung, echte Tastatureingaben, alle Phasenprofile ohne Phasenfreischaltung, Cache-Reuse und feste Speichergrenze, Pause, Wasser aus dem echten Generator, Körpertrennung, unveränderte Kampagnen-/Entdeckungsdaten, Save/Load mit zuvor manuellem Zoom, neuer Seed und Freigabe beim Verlassen der Szene. Kugelprojektion mit Erdgröße, Face-Grenze, Pol und Submeter-Präzision.
- `tribal_age_test`: real bestätigter Aufstieg, Minimap bleibt sichtbar und wechselt auf 320 m Breite; Heimat und drei eigene Bewohner; kein UI-Überlappen bei 1280 × 720 und 800 × 600; letzter Dorfauftrag per Scrollen erreichbar, Kartenklicks lösen keine Weltaktionen aus. Bestehende Produktion, Bewegung, Aufträge und Save/Load bestanden.
- `large_planet_lab_test`: Kartenanschluss an Terra, reale Floating-Origin-Verschiebung ohne Kartenversatz; Orbit-/System-/Katalogrückkehr, präziser Ort und frischer Prozess mit geladenem Erdspielstand.
- `behavior_skill_tree_test`, `discovery_journal_test`: Menüs, Eingabe-/Pausenbesitz, Fortschritt und Laden.
- Echte Kampagnen- und Planetenlabor-Einstiege sowie Shutdown-Prüfungen ohne Script-/Ressourcenfehler.
- Windows-Release-Export erfolgreich; exportiertes PCK mit realem Kampagnenstart und geordnetem Shutdown im Headless-Runtime geprüft.

Die neuen Layoutchecks fanden zunächst einen überhohen Dorfbereich bei 800 × 600; dieser wurde durch den Scrollbereich behoben und erneut erfolgreich geprüft. Eine fehlerhafte Testansteuerung des noch nicht geöffneten Galaxiekatalogs wurde auf dessen echten Öffnen-/Schließen-Ablauf korrigiert und erneut geprüft.

**Offene optische Abnahme:** Der zuvor automatisch abgelehnte virtuelle Bildschirm steht weiterhin nicht zur Verfügung. Hier wurden Szene, Daten, UI-Rechtecke und Bedienung ohne Bildausgabe geprüft. Minimapfarben, subjektive Lesbarkeit und Performance sind in der beigefügten Windows-Testversion auf dem Ziel-PC zu beurteilen. Die Windows-EXE selbst wurde hier nicht auf Windows ausgeführt.

## Geänderte Anschlüsse

- Neue eigene Module: `core/map/` und `ui/minimap/`; neuer `tests/minimap_test.gd`.
- `ui/progression_hud.gd`: genau eine Minimap am bestehenden Spieler-HUD.
- `world/tribe/tribe_controller.gd`: Minimap beim Gruppenwechsel erhalten, lesender Kamerafokus-Zugriff.
- `ui/tribe/tribe_panel.gd`: reservierte Kartenbreite und begrenzter, scrollbar bleibender Aktionsbereich.
- `world/planet_lab/planet_lab.gd`: ein Minimap-Anschluss und benannter unterer UI-Bereich zur Platzierung.
- Bestehende Tests `tribal_age_test.gd` und `large_planet_lab_test.gd` um die neuen Vertrags-/Bedienchecks ergänzt.
- Roadmap: ausschließlich Status des zuvor ausdrücklich beauftragten Minimap-Punkts aktualisiert; restliche Fachplanung bleibt bei der Integration.

Bei Übernahme parallel entwickelten Stammes-/Planeten-Code erhalten und die genannten schmalen Anschlüsse einbauen. Eigene D2-Tiere später über stabile Individuen- und Körper-IDs in den vorhandenen Markeradapter einlesen.
