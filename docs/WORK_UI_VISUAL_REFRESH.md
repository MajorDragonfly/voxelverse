# UI-Überarbeitung aus dem Spieltest – 9. September 2026

Basis: gemeinsamer `main` **3a3e027**. Fachbranch: `agent/ui-visual-refresh-2026-09-09`.
Dieses Paket übernimmt den konkreten neuen UI-Auftrag von Lars. Andere Fachbranches wurden nicht zusammengeführt. Maßgeblich für die Übergabe ist der Commit dieses Berichts auf dem Fachbranch; die Windows-Testversion enthält seine Quell-Commit-ID in `TESTEN.txt`.

## Geändertes Verhalten

- Entdeckungsbuch: durchgehende dunkle Blau-/Türkispalette, Auswahl mit Bild, klare Titel und Status, scrollbare Details, Körperteilkarten einer gescannten Art als direkte Verknüpfung zur Teileansicht. Suche, Kategorien, Freischaltfilter, Merkliste, Forschungsziel und Artenvergleich verwenden weiterhin das gemeinsame Buch.
- Körperteile: auswählbare 3D-Ansicht aus `creature_part_geometry.gd` und dem bestehenden Runtime-Renderer; Körper/Farben, Füße/Hände eingeschlossen. Gesperrte Modelle erhalten ein einfarbiges, unbeleuchtetes Silhouettenmaterial. Die Werkstatt-Teilepalette verwendet denselben Renderer statt der älteren groben Rezeptzeichnung.
- Katalogbilder: ein zusätzlicher Offscreen-Viewport rendert Miniaturen nacheinander, begrenzter Cache mit 192 Bildern. Keine laufende Weltkamera pro Listeneintrag. Beim Schließen wird die Warteschlange geleert. Im Headless-Modus ist ausschließlich diese Bildrasterung ausgeschaltet.
- Entwicklungsbuch: kompaktere Fähigkeitenkarten mit Silhouetten bis zum Kauf, ausgewählte Fähigkeit mit eigenem großen Symbol, Voraussetzungen/Wirkung im Detailbereich. Der Entwicklungspfad erhält Bilder für Kreatur, Nestgruppe und Stamm sowie gesperrte Zeitalterbilder für Mittelalter, Neuzeit und Weltraum. Kein neuer Fortschritts- oder Phasenvertrag.
- HUD: drei kompakte Wertezeilen für Leben, Sättigung und Wasser oben links; lesen die ursprünglichen spielereigenen Balken. Buchzugriffe rechts oben, Hinweise aus dem Minimapbereich entfernt. Ein einzelnes normales Fadenkreuz statt zweier übereinander. Kampfanzeige schmaler und ohne Artennamen.
- Lebende Tiere erhalten außerhalb des E-Scanners keine weiße Identitäts-/Rollen-/Wertezeile mehr. Kadaver behalten ihren Fresshinweis; Scanner und tatsächliches Kampfleben bleiben erhalten.
- Beerensträucher: fünf unregelmäßige kleinere Blattgruppen, sichtbare Äste, abgestufte Grünwerte und außen liegende Beerentrauben. Gleicher Standortseed reproduziert die Form; Ernte und Nachwachsen verändern weder Identität noch Kollisionsgröße. `foraging_berry_bush.gd` und der Vorrats-/Save-Vertrag sind unverändert.
- Linksklick-Ziehen im freien Editorbereich dreht das Modell horizontal in Zugrichtung. Andocken, Körperpunktziehen und Alt-Teildrehung behalten ihre vorhandenen Pfade.
- Auf ausdrücklichen Nutzerwunsch ist die **Minimap unten rechts als offener Roadmappunkt** mit Terrain, Wasser, Blickrichtung, Heimat und später eigenen Tieren festgehalten. Sie ist noch nicht implementiert.

## Prüfungen

Godot **4.6.3**, isolierte Testspielstände. Import und Windows-Release-Export ohne Script-/Parsefehler.

Bestanden:

- `ui_visual_refresh_test`: alle Katalogteile erzeugen Meshes; gesperrte Modelle sind vollständig einfarbig; UI verändert keine gespeicherten Entdeckungen; kompakte HUD-Abmessungen; lesbarer Detailbereich bei 800 × 600; keine Tieridentität im normalen Interaktionshinweis; reproduzierbare Buschgeometrie/Kollision; positive horizontale Editor-Zugrichtung.
- `discovery_journal_test`: Filter, gespeicherte Beobachtungen, Buchinstanz, Pause-/Eingabebesitz, Laden.
- `behavior_skill_tree_test`: echte Maus-/Tastatureingaben, Käufe, Fehlerrollback, Speichern/Laden, Buchwechsel und Pausenrückgabe.
- `development_path_test`: vorhandener Phasen-/Nestgruppenvertrag.
- `wildlife_foraging_test`: gemeinsame Nahrung, Ernte/Nachwachsen und Persistenz.
- `creature_scan_test`: Fadenkreuz, Sichtblockierung, E-Wechsel, Scanfortschritt und Speicherung.
- `creature_parts_studio_test` sowie `creature_editor_v7_runtime_test`: Werkstatt-/Körperteilregressionen.

**Offene Sichtprüfung:** Die automatische Freigabe verweigerte den virtuellen Bildschirm (lokale Bildschirmverbindungen im eingeschränkten Prozess). Deshalb entstanden hier keine neuen gerenderten Screenshots. Die Tests prüfen Szene, Geometrie, UI-Rechtecke und Verhalten ohne Bildausgabe; Beleuchtung, Miniaturen-Rasterung, subjektive Lesbarkeit und Ziel-PC-Frametimes müssen in der beigefügten Windows-Testversion geprüft werden. `tests/ui_visual_refresh_test.gd -- --capture <Verzeichnis>` ist für einen lokalen grafischen Godot-Lauf vorbereitet.

## Einbaupunkte für die laufende Runde

- Auftrag 2: nur Orbit-Vorzeichen in `creature_editor_studio.gd`, dazu visuelle `creature_part_card.gd`. Körpervertrag/Anatomie/Gelenke bleiben bei Auftrag 2.
- Auftrag 6: Darstellungsänderungen in `behavior_skill_tree.gd` und `development_path_panel.gd`; dessen neue Stammespunkte/Voraussetzungen müssen bei Integration erhalten bleiben. Keine fremde Kernlogik durch diese Basisversion ersetzen.
- Auftrag 7: `discovery_journal.gd`, `journal_preview.gd` sowie HUD-Positionen. Neue D1-/D2-Register am bestehenden Datenzugriff ergänzen und die neuen Ansichten/Teilevorschauen beibehalten.
- Dorf/Nahrung: lediglich Basismesh des Beerenstrauchs; keine Änderungen an Ressourcenmenge, Wiederwachstumszeit, Food-Key oder Speicherformat.
- `ROADMAP.md` enthält ausschließlich die vom Nutzer verlangte UI-/Minimap-Ergänzung, keine Neuplanung anderer Arbeitspakete.

Keine Schemaänderung, keine Migration und keine automatische Übernahme nach `main`.
