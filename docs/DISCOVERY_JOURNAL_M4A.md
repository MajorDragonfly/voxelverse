# Gemeinsames Entdeckungsbuch · M4A

Stand: 9. September 2026. Arbeitszweig `agent/discovery-journal`. Lokal geprüfter Laufzeitcode: `5722e50`. Abhängigkeit: abgeschlossener Skilltree-Stand `60f61e0` aus PR #14 auf M2A / PR #10.

Lars hat diesen Arbeitsstrang mit Artenbuch, Körperteilübersicht, Entdeckungsmeldungen und Einstiegshilfen beauftragt. Auf seinen Hinweis wurde die zweite Entdeckungsübersicht aus dem Skilltree geprüft und in ein gemeinsames Buch überführt.


**Erweiterung M4B:** Forschungsziele, angepinnter Fortschritt im Spiel und Teile-Merkliste sind jetzt ergänzt. [Bedienung, Datenvertrag und aktuelle Abnahme](RESEARCH_GOALS_M4B.md).

## Ein Buch, mehrere Einstiege

`ui/progression_hud.gd` erzeugt genau eine Instanz von `ui/discovery/discovery_journal.gd` am Spieler und übergibt sie als `journal` an den Skilltree. J, der HUD-Button und der Button **Entdeckungsbuch · J** im Skilltree öffnen dieselbe Instanz. Die alte eingebettete Datei `ui/discovery_journal.gd` ist entfernt. Es gibt keinen zusätzlichen Buchknoten in der Hauptszene und keine nachträgliche Suche nach fremden Buttons.

Der Skilltree gibt beim Wechsel seine Pause nach Abschluss des Eingabeframes ab; dann übernimmt das Buch. Esc, J außerhalb des Suchfelds oder der Zurück-Button kehren ins Spiel zurück und stellen den Mausmodus wieder her. Während des Ladens eines deaktivierten Spielers oder bei einer bereits bestehenden Pause öffnet sich das Buch nicht. Szenenabbau gibt die eigene Pause frei.

„Anschluss an den Skilltree“ bedeutet hier ausschließlich diesen Menüwechsel. Sozial-/Aggressionspunkte, Knoten und Freischaltregeln werden weiterhin vom bestehenden Fortschrittssystem verwaltet. Durch Lesen oder Öffnen des Buchs entstehen keine Punkte oder Käufe.

## Inhalt und Bedienung

- **Arten:** beobachtete Spezies nach Name, Fundwelt und Rolle suchen. Die gespeicherte Anatomie erscheint als dreh-/zoombare 3D-Vorschau. Ziehen dreht; das Mausrad zoomt. Es besteht jeweils nur eine Vorschau, die bei Änderungen gerendert und beim Schließen freigegeben wird.
- **Körperteile:** verfügbare und gesperrte Teile mit Kategorien, Katalogbeschreibung und tatsächlicher Herkunft neuer Freischaltungen. Nicht mehr verfügbare gespeicherte Teil-IDs bleiben sichtbar.
- **Regionen:** aus der bisherigen Skilltree-Übersicht übernommen. Angezeigt werden gespeicherte Regionskoordinaten und Fundwelt; gleiche Koordinaten auf verschiedenen Welten bleiben getrennte Entdeckungen. Suche berücksichtigt die Fundwelt. Zahlen bleiben nach dem Laden ohne unnötige Nachkommastellen lesbar.
- **Nächste Schritte:** Hinweise zu erster Beobachtung, Nahrung und Wasser anhand der vorhandenen Spielaktionen. Linksklick beobachtet Tiere; E schaltet die Inspektionsansicht um; F2 öffnet den Editor nach dem Schließen des Buchs. Der kurze HUD-Hinweis lässt sich abschalten.
- Eine neue Entdeckung meldet Art, Entdeckungspunkte und ein gegebenenfalls freigeschaltetes Teil gemeinsam. Alle Listen sind durchsuchbar und zeigen höchstens 100 Einträge pro Seite.

## Daten und Speicherung

`ProgressionService` bleibt alleiniger Besitzer von Punkten, Arten, Regionen und Freischaltungen. Die Oberfläche liest eine exportierte Kopie. Die Anzeigeeinstellung liegt separat in einer lokalen UI-Konfiguration; Kampagnendaten nutzen ausschließlich den vorhandenen gemeinsamen Speicherweg.

Neue Beobachtungen ergänzen optional `discovered_species[key].journal`: versionierter, JSON-fähiger Schnappschuss von Anatomie, Teil-IDs und Fundweltname. Vektoren und Farben werden typisiert kodiert. Spielerfortschritt aus einem Kreaturenentwurf wird nicht in die Vorschau übernommen; das Rendering erhält eine Kopie.

Eine tatsächlich gewährte Teilfreischaltung erhält `species_key`; der Arteintrag erhält `unlocked_part`. Die zusätzlichen Felder werden über den bestehenden Kampagnenspeicher einschließlich Autosave gesichert. Es gibt keine zweite Kampagnendatei oder Änderung der Belohnungsregeln.

Alte Spielstände bleiben lesbar. Fehlende Ansichten werden erklärt und erst bei einer erneuten echten Beobachtung ergänzt, ohne weitere Punkte. Eine unbekannte ursprüngliche Teilherkunft wird nicht geraten. Bestehende Ansichten werden nicht aus einem inzwischen veränderten Generator neu erzeugt. Der jeweils installierte Kreaturenrenderer bestimmt weiterhin die Darstellung; es handelt sich um gespeicherte Anatomie, kein eingefrorenes Mesharchiv.

## Abgrenzung zu den anderen Arbeitssträngen

Der fertig veröffentlichte Skilltree-Stand `60f61e0` ist eine ausdrücklich integrierte Abhängigkeit. Weitere laufende Kreaturen-, Planeten-, Menü-, Sound- oder Verhaltensarbeiten sind nicht Bestandteil dieses Branches. `main` und PR #9 werden nicht zusammengeführt. Die Übergabe ist auch in `PLAYER_PROGRESSION_WORKSTREAM.md` vermerkt, damit keine zweite Buchoberfläche entsteht.

Frühere lokale Integrationstests mit Skilltree `3b5153b`, Kreatureneditor `e17f40c` und Planetenstand `4b27e34` sind historische Nachweise im JSON-Bericht. Sie ersetzen keine Abnahme späterer Änderungen anderer Chats. Die Dateien `integrated_*.png` zeigen diesen früheren kombinierten Stand und gehören nicht zum aktuellen Testpaket.

M4-Tierwelt, echte soziale Aktionen und Anwendung der Skilltree-Boni bleiben eigene Aufgaben. Das Artenbuch schlägt solche noch nicht implementierten Aktionen nicht als erreichbare Ziele vor.

## Aktuelle Abnahme

| Prüfung | Ergebnis |
|---|---|
| Import und Art-Quellen | Bestanden |
| Gemeinsame Journal-/Skilltree-Funktionstests | Bestanden: Produktions-Spieler installiert genau eine Instanz; echte Maus-/Tastatureingaben, Pause, Ladeblockierung, Suche, Regionen und Seitenwechsel |
| Speicherung und Fortschritt | Exakte Anatomie, zwei Fundwelten, Altdaten-Ergänzung ohne Doppelbelohnung, unveränderte Punkte durch beide Einstiege; ganzer Spielstand und separater Ladeprozess bestanden |
| Skilltree-Regressionsprüfung | Kauf, Schreibfehler mit Rücknahme, erneuter Kauf, Laden und spätere Vermächtniskäufe bestanden |
| Grafische Prüfung auf Laufzeitcode `5722e50` | Compatibility/Mesa llvmpipe: fünf Artenbuchansichten und sechs Skilltree-/Anschlussansichten; maßgebliche Layouts visuell gesichtet |
| Linux-Release auf Laufzeitcode `5722e50` | Zwölf Prüfungen einschließlich unverändertem Release-Programm, Hauptszene, direktem Planetenlabor, Skilltree/Artenbuch gegen exportierte PCK und drei Planeten bestanden |

Der erste Artenbuchstand hatte zusätzlich einen vollständigen Projektlauf mit 49 Prüfungen bestanden. Für den aktuellen Menüanschluss wurden gezielt seine Daten-, Eingabe-, Grafik- und Exportverträge erneut geprüft.

Nachweise: [validation/discovery-journal.json](../validation/discovery-journal.json), [Arten](../art/review/discovery_journal/species.png), [Regionen](../art/review/discovery_journal/regions.png), [kompakte Darstellung](../art/review/discovery_journal/compact.png).

Der veröffentlichte M4A-Grundstand `73583c0` hat inzwischen auch Windows-/Linux-Export, beide Journal-Renderer, Skilltree-GUI und die allgemeine Godot-Prüfung auf GitHub bestanden. Diese Abnahme gilt für den Grundstand; die neue Forschungserweiterung wird separat geprüft. Lokale Softwaregrafik ersetzt keinen Spieltest auf Lars’ Ziel-PC. Aktuelle CI- und Paketlinks stehen in PR #19.

## Bereitstellung

Lars hat die öffentliche Veröffentlichung des fertigen Branches und das Anlegen eines Draft-PRs in `MajorDragonfly/voxelverse` ausdrücklich freigegeben. Die zuvor fehlende Freigabe ist damit erteilt.

Bereitstellung als eigener Branch `agent/discovery-journal`, Draft-PR gegen `agent/player-progression-ui` (PR #14). Aktuelle Windows-/Forward+-CI- und Paketlinks werden im PR dokumentiert. Der Reviewtext steht in `docs/DISCOVERY_JOURNAL_PR.md`. Keine automatische Zusammenführung mit `main` oder anderen laufenden Arbeitssträngen.
