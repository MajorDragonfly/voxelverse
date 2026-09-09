# Voxelverse: Spieleinstieg und Menüs

Arbeitszweig: `agent/game-menus`, Stand 9. September 2026.

## Umfang

Das Spiel startet in `ui/frontend/main_menu.tscn`. Die Titelszene zeigt einen eigenen Voxelverse-Schriftzug, einen langsam rotierenden Voxelplaneten und ein passendes Anwendungssymbol. Sie lädt keinen Spieler, kein Gelände und keine Fauna. Die Vorschaugrafik benutzt eine eigene kleine Darstellung und greift nicht auf die Planetengeneration der Kampagne zu.

- **Fortsetzen** lädt den zuletzt gespeicherten lesbaren Spielstand. Ohne vorhandenen Stand ist der Button deaktiviert.
- **Neues Spiel** nimmt einen Namen und optional einen positiven Welt-Seed bis 2147483647 entgegen. Startphase ist die Kreaturenphase; spätere Spielphasen werden hier nicht vorgetäuscht.
- **Spielstände** zeigt Namen, Sicherungszeit (UTC), Phase, Spielminuten und Welt-Seed. Nicht lesbare oder neuere Stände bleiben sichtbar und können nicht versehentlich geladen werden. Eine verwendbare Sicherung wird gekennzeichnet.
- **Esc** öffnet in der normalen Spielwelt ein Pausemenü mit Fortsetzen, Speichern, Einstellungen, Steuerung, Speichern/zum Hauptmenü und Speichern/beenden.
- **F8** öffnet weiterhin die vorhandenen Anzeigeeinstellungen: Bildschirmmodus, Fensterauflösung, Oberflächengröße und VSync. Die Oberfläche funktioniert mit Maus und Tastatur und stellt vorherige Pause, Mausmodus und Fokus wieder her.
- Beim Laden zeigt die Oberfläche zunächst den tatsächlich gemeldeten Ressourcenfortschritt. Danach wird der Geländeaufbau beschrieben; es gibt keinen erfundenen prozentualen Weltfortschritt. Die Steuerung wird erst nach bestätigtem Aufbau des Startchunks freigegeben.

## Speicherung und Übergänge

`SessionFlow` koordiniert den Ablauf; `SaveGameService` bleibt die einzige Kampagnenspeicherung. Neue Abenteuer erhalten zufällige, unabhängige Dateinamen unter `user://saves/slot_<id>.json`. Ihr Anzeigename liegt innerhalb desselben atomaren Kampagnensnapshots, nicht in einer zweiten Datenbank. Der vorhandene `user://voxelverse_save.json` bleibt als „Bisheriges Abenteuer“ auswählbar. Bestehende Migration, Backupprüfung, Design-Snapshots und Schema 4 werden weiterverwendet.

Ein neues Spiel verwendet einen explizit leeren Design-Snapshot. Dadurch werden auf der Festplatte vorhandene Kreatur-/Gebäudeentwürfe nicht ungewollt aus einer anderen Kampagne übernommen. Beim Laden werden die jeweils gespeicherten Entwürfe über den vorhandenen DesignStore wieder wirksam.

Im Hauptmenü sind automatische Wiederherstellung und automatisches Speichern abgeschaltet. Das erste neue Snapshot wird vor dem Laden der Welt geschrieben. Beim Verlassen der Spielwelt muss das Speichern erfolgreich sein; andernfalls bleibt die pausierte Welt verfügbar und zeigt eine Fehlermeldung. Der Szenenwechsel entfernt anschließend die bisherige Welt einschließlich ihrer Worker. Fensterschließen benutzt denselben Speicherpfad. Ein geöffneter Editor fordert zunächst zum Speichern des Entwurfs und Zurückkehren auf.

Die gemeinsamen Einstellungen respektieren fremde pausierte Oberflächen. Skilltree und Entdeckungsbuch können ihre eigenen Esc-Aktionen behalten. F4 und der vorhandene Planetenlabor-Button bleiben erreichbar; die Laborsicherung bleibt die vorhandene separate Prototypensicherung.

## Parallele Arbeit und Integration

Die Ausgangsbasis kombiniert ausschließlich die bereits veröffentlichten Grundlagen `agent/m2-behavior-skilltree` (`f015324`) und `agent/planet-lod-menu` (`0ad98d9`). Der lokale Basiskonflikt in der Roadmap wurde mit beiden Fortschrittsständen aufgelöst. Gemeinsamer Basiskommit: `8a1ef4e`.

Der Kreaturenbranch, die neuere Unterwasser-/Originalmaßstab-Arbeit, Skilltree-Oberfläche und Entdeckungsbuch sind weiterhin eigene Arbeitszweige. Sie sind in diesem Testpaket nicht bereits alle zusammengeführt. `main` und PR #9 bleiben ungemergt. Lars' Ziel echter Planetengrößen und einer bereisbaren Galaxie bleibt maßgeblich; die Titelszene ist keine Änderung an diesen Anforderungen.

Die eigenen Produktionsdateien liegen überwiegend unter `ui/frontend/` und in `autoload/session_flow.gd`. Gezielte Anschlussänderungen betreffen `project.godot`, `core/display_settings.gd`, `autoload/save_game_service.gd` und den Start der vorhandenen Entwicklungsdiagnostik in `core/development_tools.gd`. Bei späterer Integration diese vier gemeinsamen Dateien prüfen; keine vollständigen fremden Projektordner überschreiben.

## Abnahme

`tests/frontend_test.gd` und die native Diagnose `--frontend-smoke` prüfen tatsächliche Viewport-Eingaben, neue/ladebare Kampagnen, Seedvalidierung, Pauseverschachtelung, fehlgeschlagenes Speichern, Weltabbau, getrennte Designs sowie beschädigte/neue Sicherungen. Die Diagnose muss mit isoliertem Benutzerordner ausgeführt werden; die bestehenden Prüfskripte richten diesen automatisch ein.

`tools/validate_export.py` führt denselben Ablauf zusätzlich im unveränderten nativen Releaseprogramm aus. Die GitHub-Aktion `Voxelverse frontend review` erzeugt fünf tatsächliche Spielaufnahmen mit Softwaregrafik. Prüfresultate und eventuelle verbleibende Einschränkungen werden nach dem Lauf ergänzt. Ziel-PC-Leistung und Lars' manuelle Beurteilung der Optik bleiben ein Spieltest.

Technischer Ladeablauf gemäß [Godot: Background loading](https://docs.godotengine.org/en/4.6/tutorials/io/background_loading.html).

## Lokales Ergebnis

Geprüfter Implementierungskommit: `dc98cb3`.

- **51/51** Projekt-/Laufzeitprüfungen bestanden, einschließlich des neuen Menüablaufs, der bestehenden M2A-Fortschrittsverträge, Editoren, Planetentransitionen und gestuftem Weltabbau. Import und Asset-Quellenprüfung waren in diesem abschließenden Lauf ausgelassen; der vorherige Exportlauf hat den Import bereits fehlerfrei abgeschlossen.
- **13/13** Prüfungen des nativen Linux-Releasepakets bestanden. Darunter der unveränderte Programmeinstieg, tatsächliche Menü-/F4-Eingaben und der vollständige neue Spielstandablauf im Releaseprogramm.
- Windows-EXE und PCK wurden mit Godot 4.6.3 erfolgreich exportiert. Die anschließende [Desktop-CI am veröffentlichten Stand `977aea4`](https://github.com/MajorDragonfly/voxelverse/actions/runs/34319148262) hat die nativen Windows- und Linux-Releaseprogramme erfolgreich gestartet und geprüft. Der folgende Korrekturstand erhält einen eigenen CI-Lauf.
- Die echte grafische Sichtprüfung mit Godot 4.6.3, OpenGL-Kompatibilitätsrenderer und Mesa llvmpipe bei 1600 × 900 ist abgeschlossen. Alle fünf Ansichten wurden geprüft; Titel, neues Spiel, Pause, Einstellungen und Spielstände liegen als PNG neben den JSON-Nachweisen. Der vollständige Ablauf endete mit `FRONTEND_PASSED`, ohne Scriptfehler, Enginefehler oder gemeldete Objektlecks. Der Test provoziert bewusst einen Speicherfehler und prüft, dass die Welt dabei erhalten bleibt.
- Der öffentliche Push wurde zunächst durch die automatische Freigabe abgelehnt. Lars hat anschließend ausdrücklich zugestimmt, `agent/game-menus` öffentlich hochzuladen und einen Entwurfs-PR anzulegen. `main` wird nicht gemergt; die Veröffentlichung und die ausstehenden CI-Abnahmen erfolgen auf dem separaten Menü-Branch.

Die JSON-Nachweise und Spielaufnahmen liegen unter `art/review/frontend/`.

## Korrekturen nach der Bildprüfung

- Der verzögerte LOD-Aufruf prüft vor dem Zugriff, ob sein Chunk noch im Szenenbaum liegt. Ein schneller Wechsel zum Titel kann den Chunk bereits vorher entfernen. Ein gezielter Regressionstest reproduziert genau diesen Ablauf; Menü- und Terraintransitionstest bestehen nach der Korrektur.
- Der fokussierte Hauptbutton verwendet dunkle Schrift auf dem hellgrünen Hintergrund.
- Eine bearbeitete Seed-Eingabe entfernt die vorherige Validierungsmeldung. Die Diagnose prüft das mit tatsächlichen Tastatureingaben im Viewport.
- Die CI-Bildaufnahme benutzt den Dummy-Audiotreiber, weil der Render-Runner kein Audiogerät besitzt.

Veröffentlichung: [Entwurfs-PR #16](https://github.com/MajorDragonfly/voxelverse/pull/16), Zielbranch `agent/m2-behavior-skilltree`.
