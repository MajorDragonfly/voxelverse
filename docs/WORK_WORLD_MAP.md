# Weltkarte – Übergabe vom 9. September 2026

Quellcommit: **d856526e5d362ac5d2fc26529e0cc16ec597a3c1**. Branch: `agent/world-map-2026-09-09`.
Basis: Minimap-Übergabe `b0e1436`, Minimap-Code `9be889f48acf346650b02137b160bd8fcedf7317`, UI-Paket `c276bdc4452b5585b93b3f81f163738670d98ca8`, integriertes main `3a3e0272375e556f3ff65b7370582af79a9d48b5`.
Keine fremden Fachbranches übernommen. Lokal geprüft und als Windows-Testversion exportiert. Noch nicht öffentlich hochgeladen oder nach main übernommen; die zuvor automatisch abgelehnte öffentliche Veröffentlichung wurde nicht erneut versucht.

## Bedienung und tatsächliches Verhalten

- **M** oder „Weltkarte · M“ unter der Minimap öffnet die pausierende große Karte. Wenn M bereits einer konfigurierten Spielaktion zugeordnet ist, verwendet die Karte Umschalt+M und zeigt diesen Hinweis an.
- Linksklick ziehen oder Pfeiltasten verschieben die Ansicht. Mausrad oder +/− zoomen. „Zu mir“/Pos1 zentriert den eigenen Bewohner; „Erkundetes“ umfasst die bisher aufgezeichneten Gebiete. M/Esc/Schließen kehrt zum Spiel zurück.
- Bekannte Orte stehen in einer filterbaren Liste: Eigene / Freunde. Klick auf Namen oder Marker zentriert den Ort. Auf schmalen Fenstern und bei 150 % UI-Größe wechselt „Orte“ zwischen Liste und Karte.
- Eigene tatsächlich vorhandene Nester und die aktuelle Heimat werden markiert. Befreundete Kreaturen erhalten einen bekannten Lebensraum-Marker, sobald sein Gebiet erkundet wurde. Verstorbene oder nicht mehr verbündete Individuen verschwinden aus dieser Anzeige.
- **Der bestehende Spielstand modelliert individuelle Verbündete, keine pauschale Freundschaft mit einer ganzen Spezies. Physische Nester fremder Spezies existieren in diesem main-Stand noch nicht.** Deshalb sind die Markierungen ausdrücklich Lebensräume; sie behaupten keine vorhandenen fremden Nestgebäude.
- Dunkle Flächen bleiben unbekannt. Spielerbewegung bzw. tatsächliche Bewegung eigener Stammesbewohner deckt Boden auf. RTS-Kameraschwenks, Kartenverschieben, Zoomen und Markerwahl decken nichts auf und erzeugen keine Entdeckungsbelohnungen.
- Bestehende Spielstände werden angenommen. **Vergangene genaue Laufwege sind daraus nicht rekonstruierbar:** Die dauerhafte Kartenaufzeichnung beginnt mit dieser Version. Grobe alte Entdeckungsregionen werden nicht als vollständig besuchte Fläche ausgegeben.
- Die Karten bleiben pro Körper erhalten, auch beim Phasenwechsel. Die kleine Karte nutzt weiter ihre Phasenprofile. Die große Karte startet ebenfalls mit einem phasenabhängigen Maßstab und erlaubt freie Navigation.
- Im Planetenlabor nutzt die Karte die echte Kugeloberfläche; Orbit/System/Galaxie behalten ihre vorhandenen Ansichten. Der globale Kugelatlas ist nordorientiert und längen-/breitengradbasiert. Die Breitenangabe bezeichnet ausdrücklich den Äquator, da diese Projektion zum Pol verzerrt.

## Architektur und Speicherung

Gemeinsame Kartenquellen, Projektion, Rasterarbeit und Marker vermeiden getrennte Implementierungen pro Spielphase. Der neue Tracker arbeitet unabhängig davon, ob die große Karte geöffnet ist.

- `core/map/exploration_atlas.gd`: körpergebundene Erkundungsdaten, 16-m-Zellen auf der Ebene, entsprechend quantisierte Cube-Faces auf Kugeln. Je 32 × 32 Zellen werden in 32 JSON-sicheren Bitzeilen gespeichert. Validierung und Normalisierung erhalten auch das höchste Bit nach einem JSON-Roundtrip.
- `core/map/atlas_projection.gd`: Ebenenprojektion bzw. globale Kugelprojektion. Die präzise lokale Minimap-Projektion bleibt erhalten.
- `ui/world_map/exploration_tracker.gd`: erfasst reale Akteure alle 0,5 s und deckt bei einem neuen Zellort einen kleinen Umkreis auf. Ein Speichersignal erfasst den aktuellen Ort nochmals. Öffnen und Schließen besitzen keine eigene Save-Datei.
- Kampagne: optionale Erweiterung `body.exploration_atlas`, eigener Vertrag Schema 1. Die globale Save-Version bleibt 6. Neue, unbekannte Atlas-Versionen werden abgewiesen und nicht durch einen älteren Backupstand ersetzt.
- Labor: optionale `map_atlases` nach stabiler Körper-ID innerhalb des vorhandenen Lab-Spielstands. Bestehende Lab-Schemata bleiben kompatibel. Ein frischer Prozess lädt dieselben Erkundungsdaten.
- `ui/world_map/world_map_source.gd`: liest Orte, bestehende Begegnungen und Beziehungen. Sie besitzt keine zweite Beziehungsdatenbank. Unbekannte Namen und noch nicht erkundete Freundesgebiete werden nicht veröffentlicht.
- Zukünftige physische Nest-/Ortsanbieter können die Gruppe `map_place_source` und `map_place()` verwenden. Körper-ID, stabiler Ort, Eigentum bzw. vorhandene Freundschaft werden geprüft. Dies ist ein Anschluss, keine bereits implementierte fremde Nestsimulation.

Grenzen pro Körper: 8.192 Kacheln und 2.048 Orte; Labor maximal 256 Körperatlanten. Bei voller Sammlung bleiben vorhandene Einträge erhalten; die UI zeigt die Grenze an. Es gibt keine unbeschränkte Gelände- oder Begegnungskopie. Ansichtsposition, Zoom und Filter sind vorübergehende UI-Einstellungen.

## Darstellung und Leistung

Die Designvorgabe 1.0 vom 9. September 2026 (`Voxelverse-Designvorgabe.md`, bereitgestelltes Projektdokument) wurde gelesen. Sie liegt noch nicht kanonisch im Repository; dieses Paket erstellt keine abweichende Kopie.

Die Karte verwendet das vorhandene `MenuStyle` und dessen Schriftübergang, dunkle Flächen, helle Textfarben und Akzente. Der vorgegebene Control-Randtoken `789394` wurde im bestehenden Style ergänzt. Neue Kartenmarker stehen zentral in `ui/minimap/map_markers.gd`; Minimap, Weltkarte und Legende nutzen denselben Heimatmarker. Bestehende Stat-Symbole werden nicht ersetzt. Haupttexte und Bedienelemente skalieren bis 150 %, Karte und Ortsliste passen sich der Fensterbreite an.

Der große Atlas verwendet ein Raster mit 128 × 128 Punkten und einen begrenzten Cache von 49.152 Punkten. Unbekannter Boden wird ohne Aufruf des Geländegenerators dunkel gezeichnet. Aufbau schrittweise: maximal 256 Punkte pro Frame, weiterhin weiches Budget von 1,4 ms. Ein einzelner Generatoraufruf kann dieses Budget überschreiten. Neue Ansichtsanforderungen beim Ziehen werden auf Abstände von 80 ms begrenzt. Die Minimap behält 48 × 48 Punkte, maximal 32 Abfragen pro Schritt und ihren bisherigen Cache von 6.144 Einträgen.

Zusätzlich wurden bereits bestehende, verworfene Tiefenkopien des gesamten Körperdatensatzes aus häufigen Heimat-, Stammes- und Minimap-Lesezugriffen entfernt. Diese Kopien wären mit wachsender Erkundung teuer geworden. Die Controller geben wie zuvor den maßgeblichen Datensatz zurück; lediglich dessen vorherige Kopie zur Seed-Abfrage entfällt. Es wurden keine Ziel-PC-Frametimes gemessen.

## Prüfung

Godot **4.6.3**, isolierte Spielstände. Bestanden:

- `world_map_test`: Zellgrenzen mit negativen Koordinaten, JSON-Bitzeilen, fremde Körper, ungültige/zukünftige Verträge, Kugel-Face-Grenzen und Pole; tatsächliche M-/Esc-/Zoom-Bedienung, Pausenbesitz, keine Fremdaktionen und kein Aufdecken durch Kartennavigation; eigene Nest- und bekannte Freundesmarker, ausgeschlossene unbekannte Lebensräume, Beziehungs-/Todesfilter; Save/Load und frischer Prozess; neuer Seed übernimmt keine fremden Daten.
- Layoutprüfungen mit 1920 × 1080, 1280 × 720, 800 × 600 und 2560 × 1080 jeweils bei 100 und 150 %: Fenstergrenzen, erreichbare Bedienelemente, passende Listenansicht und lesbare Schriftgrößen. Anfangs festgestellte Fokus- und Platzprobleme wurden behoben und erneut geprüft.
- `minimap_test`: bestehende Minimap-Verträge einschließlich Cachegrenze unverändert bestanden.
- `tribal_age_test`: echter bestätigter Phasenwechsel, pausierende große Karte, keine Erkundung durch RTS-Kameraschwenks, bestehende Stammesbewegung und Speicherung. Nach den letzten Änderungen erneut bestanden.
- `large_planet_lab_test`: Erdoberfläche, Kartenöffnung/-navigation ohne zusätzliche Erkundung, Floating Origin, Oberflächen-/Orbit-Wechsel und persistenter Atlas nach frischem Prozess.
- `behavior_skill_tree_test`, `discovery_journal_test`, `save_slots_test`: bestehende Buch-, Eingabe-, Fortschritts- und Speicherverträge.
- Finaler Windows-Release-Export erfolgreich. Das endgültige exportierte PCK startet den echten Kampagneneinstieg und beendet sich geordnet, ohne Scriptfehler oder gemeldete Ressourcenlecks.

Die letzten gezielten Läufe benötigen circa 2,5 s für Weltkarte, 1,8 s für Minimap und 37,5 s für den vollständigen Stammestest. Dies sind Testlaufzeiten, keine Framerate-Benchmarks.

**Offene optische Abnahme:** Der bereits automatisch abgelehnte virtuelle Bildschirm wurde nicht erneut angefordert. Szene, Layoutrechtecke, Daten und Bedienung wurden ohne Bildausgabe geprüft. Die Windows-EXE selbst wurde hier nicht auf Windows ausgeführt; Farben, tatsächliche Bildschirmlesbarkeit und Performance auf dem Ziel-PC sind in der Testversion zu beurteilen.

## Integration mit weiteren Facharbeiten

Neue Module sind auf `core/map`, `ui/world_map` und die gemeinsamen Kartenmarker beschränkt. Schmale bestehende Anschlüsse liegen in `minimap_hud`, `minimap_source`, `minimap_terrain`, `SaveGameService`, `planet_lab`, `planet_lab_save`, `HomeGroupController` und `TribeController`.
Bei Übernahme parallel entwickelte Planeten-/Heimat-/Stammesarbeit erhalten und diese Anschlüsse zusammenführen. Besonders die vermiedenen Tiefenkopien erhalten. Die zentrale Roadmap wurde in diesem Schritt nicht verändert.
