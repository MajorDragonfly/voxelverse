# Spielstandverwaltung

Menü-Branch `agent/game-menus`, 9. September 2026.

## Verhalten

Die Spielstandübersicht zeigt ein Vorschaubild aus der Spielwelt sowie Abenteuername, Planet, Welt-Seed, Phase, Spielzeit und Speicherzeit in UTC. Ein ausgewähltes Abenteuer kann geladen, umbenannt oder kopiert werden. Ältere Spielstände ohne Bild zeigen einen Platzhalter; nach dem nächsten Speichern in der Spielwelt erhalten sie ein Bild.

Eine Kopie wird als eigener Spielstand mit einer neuen Kampagnenkennung angelegt. Fortschritt, bisherige Belohnungen, Entdeckungs-/Ökologiedaten und die im Stand eingebetteten Kreaturen- und Gebäudeentwürfe werden übernommen. Danach können Original und Kopie unabhängig weitergespielt werden. Das Kopieren importiert keine Daten in die gerade vorhandenen Laufzeitdienste.

Vor dem Ersetzen eines gültigen Spielstands wird dessen vollständiger bisheriger Inhalt archiviert. Pro Abenteuer bleiben die acht neuesten archivierten Stände in `<slot>.history/` erhalten, zusätzlich zur vorhandenen atomaren `.bak`-Sicherung. Automatische und manuelle Speicherungen sowie Umbenennungen benutzen denselben Verlauf. Erst nach erfolgreichem Schreiben des neuen Hauptstands werden überzählige Archive entfernt. Schlägt das Archivieren fehl, bleibt der Hauptstand unverändert und der Benutzer erhält einen Speicherfehler. Ein Bereinigungsfehler lässt zusätzliche Archive liegen.

Die Sicherungsauswahl zeigt Zeit, Spielzeit, Anlass und vorhandenes Vorschaubild. **Sicherung als Kopie wiederherstellen** erstellt ein neues Abenteuer aus genau diesem Stand. Hauptstand und ausgewählte Sicherung bleiben dabei erhalten. Auch ein ausschließlich noch als Verlauf vorhandenes Abenteuer bleibt in der Übersicht auffindbar.

Im Spiel erscheint nach erfolgreichem Speichern für drei Sekunden **Gespeichert**, bei einem Fehler für acht Sekunden eine Fehlermeldung. Die Rückmeldung folgt den tatsächlichen Speichersignalen; eine angeforderte Speicherung wird erst nach erfolgreichem Abschluss bestätigt. Bei den synchronen Schreibvorgängen kann die Zwischenmeldung „Wird gespeichert …“ zu kurz für einen gerenderten Frame sein.

## Datenvertrag und Integration

- Schema 4 bleibt gültig. Die optionalen Felder `slot_preview`, `slot_origin` und die Archivmetadaten `slot_history` sind additive Metadaten.
- Vorschauen sind PNGs im vollständigen JSON-Snapshot, maximal 384 × 216 Pixel bei erhaltenem Seitenverhältnis. Kopien und Archive benötigen keine zusätzlichen Bilddateien. Bilder entstehen in der aktiven, unpausierten Spielwelt; Menü-, Lade- und Editoransichten werden nicht aufgenommen. Headless-Läufe erzeugen keine Bilder.
- Kopien erhalten eine neue Kampagnen-ID. Bereits existierende Objekt-, Körper-, Spezies- und Design-IDs bleiben als undurchsichtige Referenzen erhalten. Ereigniscursor und Belohnungsregister werden ebenfalls übernommen, damit ein bereits belohntes Ziel nicht durch Kopieren erneut Punkte liefert. Historische Ereignisse werden auf die neue Kampagnenkennung bezogen; nachträglich eintreffende Ereignisse der ursprünglichen Kampagne werden abgewiesen.
- Umbenennen, Kopieren und Wiederherstellen sind nur außerhalb einer aktiven Spielsitzung erlaubt und nur für bekannte Slotpfade vorgesehen.
- Kopien und Wiederherstellungen benötigen einen vollständigen Snapshot ab Schema 3. Ältere importierbare Spielstände müssen zunächst einmal geladen und gespeichert werden, damit ihre Entwürfe vollständig im Snapshot enthalten sind.
- Ein Hauptstand aus einer neueren Spielversion wird weder geladen noch stillschweigend durch eine ältere Sicherung ersetzt. Die explizite Wiederherstellung eines kompatiblen Archivs als neues Abenteuer ist möglich und verändert die neuere Originaldatei nicht.

Die Speicherung bleibt in `SaveGameService`; `core/persistence/slot_history.gd` verwaltet die Archive. `ui/frontend/save_browser.gd` stellt die Auswahl dar, `save_feedback.gd` liefert Status und Bildaufnahme. `SessionFlow` bindet die Rückmeldung ein. Die eigenständigen parallelen Spielmechanik-Branches werden durch diese Erweiterung nicht integriert.

## Nachweise

`tests/save_slots_test.gd` prüft echte Dateien: unabhängige Kampagnenkopien, erhaltene Entwürfe und Fortschrittsregister, Ablehnung fremder Ereignisse, keine erneuten Punkte für bereits belohnte Ziele, Rotation nach mehr als acht Speicherungen, Wiederherstellung des ausgewählten Inhalts, Umbenennen ohne Änderung der Spielzeit sowie fehlgeschlagene Archivierung und neuere/defekte Dateien.

Die native Frontend-Diagnose benutzt tatsächliche Maus- und Tastatureingaben zum Auswählen, Umbenennen, Kopieren, Laden und Wiederherstellen. Der grafische Lauf prüft außerdem gespeicherte Spielbilder und die sichtbare Speicherbestätigung. Zehn Aufnahmen werden in der Frontend-CI erwartet. Vier gezielte lokale Regressionstests sowie die grafische Abnahme mit Godot 4.6.3, Mesa llvmpipe und 1600 × 900 sind erfolgreich; die Nachweise liegen unter `art/review/frontend/` (`save-management-regression.json`, `save-management-render.log`, PNGs).

`tools/validate_export.py` enthält den Dateitest zusätzlich für die exportierten Pakete. Native Windows-/Linux-Ergebnisse des veröffentlichten Commits stehen im [Entwurfs-PR #16](https://github.com/MajorDragonfly/voxelverse/pull/16).
