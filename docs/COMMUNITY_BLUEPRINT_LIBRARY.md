# Lokale Kreaturenvorlagen – BP-COMMUNITY.2

Die Kreaturenbibliothek verwendet den portablen Vertrag aus
[BP-COMMUNITY.1](COMMUNITY_BLUEPRINT_CONTRACT.md). Sie ist im Kreatureneditor
unter **Kreaturenvorlagen** und im Menü **Neues Spiel → Startkreatur auswählen**
erreichbar. Sie benötigt keine Verbindung zu einem Dienst.

## Bedienung

- **Startvorlagen:** Wiesenläufer, Dünenwanderer und Mooskrabbler sind drei
  vorgefertigte Körper mit den regulären Startteilen. Alle lassen sich später
  im vorhandenen Editor verändern. Ohne Auswahl bleibt der normale Spielstart.
- **Suchen und filtern:** Alle Vorlagen, Startvorlagen oder die lokale Bibliothek.
  Eigene Namen bleiben beim Wechsel zwischen Deutsch und Englisch erhalten.
- **Vorschau:** derselbe Voxelrenderer wie im Entdeckungsbuch und in der Laufzeit;
  linke Maustaste dreht, Mausrad zoomt. Autor, Herkunftsanzahl, Formbudget und
  fehlende Freischaltungen erklären die Verwendbarkeit.
- **Entwurf ablegen:** Der aktuelle Editorentwurf wird mit dem eingegebenen
  Namen als eigene Variante gespeichert. Die ausgewählte Bibliotheksvorlage
  und die Kampagne werden dabei nicht überschrieben.
- **Importieren / Exportieren:** JSON-Dateiauswahl über den bestehenden Godot-
  Dateidialog. Import legt eine geprüfte lokale Kopie an; die Originaldatei wird
  danach nicht mehr benötigt. Export respektiert den Schutz vorhandener Dateien
  aus BP-COMMUNITY.1. Für andere Revisionen einen neuen Dateinamen verwenden.
- **Im Editor übernehmen:** ersetzt die Arbeitskopie in genau einem Undo-Schritt.
  Rückgängig/Wiederholen erhalten auch Körperform, Farbe und Anschlüsse.
  Der vorhandene Speicherknopf schließt die Änderung im Spielstand ab.
- **Entfernen:** betrifft nach Bestätigung nur den ausgewählten lokalen Eintrag.
  Startvorlagen und bereits übernommene Kreaturen bleiben erhalten.

Unter 900 logischen Bildpunkten wechselt die Ansicht zwischen Liste und Detail.
Im Detail bleiben Übernehmen, Zurück und Schließen erreichbar; die Dateiaktionen
stehen in der Liste. Lange Inhalte sind scrollbar. Escape kehrt zuerst zur Liste
zurück und schließt danach die Bibliothek. Beim Schließen kehrt der Fokus zum
aufrufenden Knopf zurück. Sprachwechsel erhalten Auswahl, Suche, Listenposition
und Vorschaukamera.

## Daten und Zuständigkeit

`assembly/exchange/creature_design_library.gd` verwaltet ausschließlich lokale
Vorlagen in `user://creature_library.json`:

```json
{"schema": 1, "packages": []}
```

Ein Eintrag ist ein vollständiges geprüftes BP-COMMUNITY.1-Paket. Der Schlüssel
besteht aus `design_id` und `revision`, nicht dem sichtbaren Namen. Eine identische
Revision wird ohne erneutes Schreiben erkannt; abweichender Inhalt unter derselben
Kennung/Revision wird abgewiesen. Gleiche Namen mit verschiedenen Kennungen sind
erlaubt. Eigene Varianten erhalten eine neue Designkennung, Revision 1 und die
Herkunftskette der Vorlage bzw. Arbeitskopie.

Die Datei wird über den vorhandenen `AtomicJson`-Schreiber ersetzt. Eine beschädigte
oder künftig versionierte Bibliothek wird nicht durch Import, Ablage oder Entfernen
überschrieben; eingebaute Startvorlagen bleiben durchsuchbar. Ein fehlgeschlagener
Schreibabschluss erhält die bisherige Datei. Der erste lokale Umfang ist auf
128 Pakete und 16 MiB begrenzt. Das sind Grenzen dieses lokalen Katalogs, keine
Grenzen für Kampagnen, Tiere oder Weltregionen. Die Bibliothek ist kein zusätzlicher
Kampagnenspeicher und kein paralleler Synchronisationsdienst.

`creature_start_templates.gd` erzeugt drei deterministische Vorlagen aus dem
bestehenden Teilekatalog. Die Startfreischaltungen stammen aus einem frisch
zurückgesetzten `ProgressionService`-Modell, ohne den aktiven Fortschritt zu ändern.
Vorlagen enthalten keine fremden Spielstände, Ressourcen, Freischaltungen oder
Ausführungsskripte. Ein neues Abenteuer erhält eigene Kampagnen-, Spezies- und
Designkennungen.

Der vorhandene `SaveGameService.create_slot` erhält lediglich einen optionalen
vierten Parameter `creature_template`. Die Prüfung erfolgt vor Änderung der
aktiven Kampagne; der bestehende erste Speicherabschluss enthält bereits den
gewählten Entwurf. `SessionFlow.new_game` reicht diesen Parameter durch. Aufrufer
mit den bisherigen Argumenten behalten ihr Verhalten.

Für den Editor bereitet der Paketvertrag eine Kopie im aktuellen Freischaltungs-
und Phasenkontext vor. Anschließend prüft `for_editor`, dass die vorhandene
Anschlussnormalisierung die Form unverändert lässt. Aktuell verfasste Anschlüsse
werden mit den vorhandenen Migrationsmarkern versehen, damit Laufzeit und Editor
sie nicht als alte Platzierungen reparieren. Inkompatible Anschlüsse werden erklärt
und abgewiesen. Undo, Revisionen und Speichern gehören weiterhin dem Editor.

## Abnahme

[WORK_COMMUNITY_BLUEPRINT_LIBRARY.md](WORK_COMMUNITY_BLUEPRINT_LIBRARY.md) benennt
Basis und Integrationspunkte. [COMMUNITY_BLUEPRINT_LIBRARY_VALIDATION.json](COMMUNITY_BLUEPRINT_LIBRARY_VALIDATION.json)
enthält Prüfergebnisse und Quell-/Logprüfsummen.

Die UI-Abnahme nutzt echte Controls und Eingabeereignisse. Bei Dateidialogen wird
die Dateiauswahl nach dem Öffnen mit dem ausgewählten Testpfad eingespeist; der
Dateisystem-Picker selbst wurde nicht manuell auf Windows bedient. Ein eigener
Kindprozess beweist Laden ohne ursprüngliche Importdatei. Zusätzlich wird über
das echte Startmenü die Kugelkampagne geladen und der Entwurf der spielbaren Kreatur
mit der gewählten Vorlage verglichen.

Native Aufnahmen mit Godot 4.6.3, OpenGL-Kompatibilitätsrenderer und Mesa llvmpipe:

- [Editor, 1280 × 720](evidence/community-blueprint-library/editor-templates-de.png)
- [Desktop, 1920 × 1080](evidence/community-blueprint-library/desktop-1920-de.png)
- [Breitbild, 2560 × 1080](evidence/community-blueprint-library/desktop-2560-de.png)
- [Lokale Variante, Englisch](evidence/community-blueprint-library/local-variant-en.png)
- [Liste, 800 × 600 bei 150 %](evidence/community-blueprint-library/narrow-list-en-150.png)
- [Detail, 800 × 600 bei 150 %](evidence/community-blueprint-library/narrow-detail-en-150.png)
- [Fehlerhafte Importdatei](evidence/community-blueprint-library/invalid-import-de.png)
- [Ausgewählte Startkreatur](evidence/community-blueprint-library/new-game-selected-de.png)

Die Aufnahmen sind eine Darstellungs- und Bedienungsprüfung, keine Messung des
60-FPS-Ziels auf einem Gaming-PC. Windows- und Zielhardware-Abnahmen stehen aus.
Onlinekatalog, Anmeldung, Bewertungen und automatischer Austausch sind kein Teil
dieses Pakets.
