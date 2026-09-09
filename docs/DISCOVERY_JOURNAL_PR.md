# Ein gemeinsames Entdeckungsbuch für J und Skilltree

Arten und Teile wurden bereits gespeichert, aber die beobachtete Körperform und der konkrete Ursprung neuer Teile fehlten. Parallel hatte der Skilltree eine eigene einfache Entdeckungsübersicht bekommen. Dieser PR führt beide auf Lars’ Wunsch in einem vollständigen Buch zusammen.

- Genau eine Instanz im Spieler-HUD; J, HUD-Button und Skilltree-Button öffnen dasselbe Buch. Die alte `ui/discovery_journal.gd` ist entfernt.
- Beobachtete Arten mit gespeicherter 3D-Ansicht, Teilherkunft, Suche/Filtern und Seitenwechsel. Die Regionenübersicht aus dem Skilltree bleibt erhalten.
- Gemeinsamer Kampagnenspeicher mit additiven Beobachtungsdaten. Altdaten bleiben lesbar; erneute Beobachtung ergänzt fehlende Ansichten ohne weitere Belohnung.
- Saubere Pause-/Mausübergabe beim Menüwechsel; Einstieg während Laden oder fremder Pause gesperrt. Bestehende Verhaltenspunkte und Kaufregeln bleiben beim Fortschrittssystem.

Abhängigkeit ist der abgeschlossene Skilltree-Stand `60f61e0` / PR #14. Der PR richtet sich deshalb gegen `agent/player-progression-ui`. Weitere laufende Planeten-, Kreaturen-, Menü-, Sound- oder Verhaltensarbeiten sind nicht enthalten. Keine automatische Zusammenführung mit `main` oder PR #9.

Geprüfter Laufzeitcode `5722e50`: Journal und echter Produktions-Spieler, Skilltree-Käufe samt Schreibfehler/Rücknahme, Pause, Suche, Regionen, große Sammlungen und Speichern/Laden im separaten Prozess bestanden. Elf echte Compatibility-Aufnahmen geprüft; zwölf Linux-Releaseprüfungen einschließlich Skilltree/Artenbuch gegen exportierte PCK bestanden. Der ursprüngliche Journalstand hatte zusätzlich 49 Projektprüfungen bestanden.

Windows und Forward+ werden durch die GitHub-Workflows geprüft; Ergebnisse und Testpaket folgen hier. Softwaregrafik ersetzt keinen Spieltest auf dem Ziel-PC. Details und Nachweise: `docs/DISCOVERY_JOURNAL_M4A.md`, `validation/discovery-journal.json`.
