# ARCH-29-CHECK-PLAN: gezielte Prüfung aus dem tatsächlichen Git-Diff

Basis: `d378ca0ecd7f03429a5150df6358e0646ec06689`.
Branch: `agent/arch29-check-plan-20260915`. Teilauftrag aus ARCH-29 / M0 / M10.

## Verwendung

```sh
# Lokalen Diff gegen die ausdrücklich vereinbarte Basis erklären:
python3 tools/validate_godot.py --changed-since BASIS_SHA --plan

# Nur die ausgewählten vorhandenen Testnamen ausgeben:
python3 tools/validate_godot.py --changed-since BASIS_SHA --list-tests

# Die Auswahl tatsächlich ausführen:
python3 tools/validate_godot.py --changed-since BASIS_SHA --output ../pruefung-meines-pakets
```

Die Basis wird zu einem exakten lokalen Commit aufgelöst. Der Vergleich ist
**Basis gegen den aktuellen Checkout**, einschließlich eigener Commits,
vorgemerkter Änderungen, ungesicherter Änderungen und neuer, nicht ignorierter
Dateien. Es erfolgt kein Netzwerkzugriff und keine versteckte Merge-Base-Suche.
Nach einem Branchwechsel oder einer Integration ist die ausdrücklich vereinbarte
neue Basis einzusetzen. Ein Git-Worktree funktioniert; ein Unterordner innerhalb
eines größeren Repositorys wird als `--project` zurückgewiesen.

`--plan` und `--list-tests` starten weder Godot noch Tests und erzeugen keine
Ausgabedateien. Ein Plan besitzt `tests_executed: false` und kein `passed`-Feld.
Ein ausgeführter Lauf schreibt den verwendeten Plan zusammen mit seinen echten
Prüfergebnissen nach `results.json`.

## Auswahlvertrag

| Änderung | Ergebnis |
|---|---|
| Keine Änderung oder ausschließlich bekannte Markdown-Dokumentation | Quell-/Vertrags-/Sprachgate; keine Engine, Import- oder Spielprüfung. Das Ergebnis nennt `source_only`. |
| Einzelner registrierter Test oder dessen UID | Diesen Test auswählen. Neue Testnamen müssen regulär registriert sein. |
| Zugeordneter Fachbereich | Vereinigung des Fachvertrags und der in den Regeln genannten direkten Verbraucher. |
| Zentrale Speicher-, Kampagnen-, Autoload-, Laufzeit-, Sprach- oder Prüf-Infrastruktur | Alle registrierten Fachtests und die vorhandenen Haupt-/Lebenszyklusprüfungen. |
| Unbekannter Pfad, Symlink oder Dateitypwechsel | Vollständige Auswahl. Keine unbekannte Änderung wird still übersprungen. |
| Konflikt, ungültige Basis, fehlende/mehrdeutige Testregistrierung oder ungültige Regeln | Fehler vor dem Engine-Start. |

Umbenennungen werden absichtlich als alter und neuer Pfad ausgewertet. Eine
Löschung behält damit die Zuständigkeit der bisherigen Datei. NUL-getrennte
Git-Ausgaben erhalten Leerzeichen, Unicode und Zeilenumbrüche in Dateinamen.
Externe Diff-/Textkonverter werden nicht aufgerufen. Symlink-Ziele werden nicht
für den Fingerprint gelesen.

`tools/validation/contracts.json` bleibt die einzige Zuordnung von Tests zu
Fachverträgen. `selection_rules.json` enthält ausschließlich Pfadmuster und
Vertrags-IDs, keine zweite Liste von Testnamen. Ein später unter einem Vertrag
registrierter Test wird unmittelbar mit ausgewählt. Mehrere passende Regeln
werden vereinigt; die Ausgabe enthält jeden Test genau einmal. Die
Pfadentscheidungen wiederholen die große Testliste nicht.

Beispiel auf der Basis: Eine Änderung in `audio/` wählt 20 von 165 Fachtests aus:
Audio, Wildtierverhalten und die gemeinsame Kugel-Spielschleife. Die Anzahl ist
aus der Registry berechnet; sie ist weder eine Zeitersparnis-Messung noch eine
garantierte unveränderliche Zahl. Änderungen am globalen Audio-Autoload wählen
aufgrund seiner zentralen Rolle weiterhin alle Tests.

## Ausführung und Grenzen

Ein gezielter Plan führt seine Fachtests mit Quellgate und standardmäßig Import
aus. Ein vollständiger Plan führt zusätzlich die bestehenden Hauptprüfungen aus;
`--skip-main` darf ihn nicht still verkleinern. Für eine ausdrücklich enger
gefasste Diagnose bleibt der bisherige `--contracts`-/`--tests`-Aufruf erhalten.
`--skip-import` verlangt wie bisher einen bereits erfolgreich importierten
identischen Ressourcenstand. Ausgaben automatischer Pläne müssen in einen neuen
Ordner außerhalb des Projekts gehen, damit sie weder alte Nachweise überschreiben
noch selbst neue Änderungen im ausgewerteten Diff erzeugen.

Die bisherigen Standardaufrufe und die volle Integrations-CI bleiben erhalten.
Der Plan ersetzt keinen Export, Grafiktest, Windows-Test oder Ziel-PC-Nachweis.
Er ist eine konservative Fachzuordnung, **kein vollständiger Abhängigkeitsgraph**.
Neue fachübergreifende Verbraucher brauchen eine Ergänzung der Regeln. Unbekannte
Dateien fallen bis dahin auf die gesamte Suite zurück. Es werden keine früheren
Ergebnisse automatisch als neue Testläufe übernommen.

Der Plan dokumentiert Commit/Tree der Basis bzw. des Checkouts, Status und
SHA-256 der veränderten Dateien sowie die verwendete Registry und Regelversion.
Er wird bei jedem Aufruf neu berechnet; gespeicherte Pläne können nicht zur
Ausführung eingelesen werden. Änderungen während eines bereits laufenden Tests
werden nicht gesperrt: wie bisher auf einem eigenen, ruhenden Checkout prüfen.

## Übergabe

Schreibbereich: neuer Planer, Auswahlregeln, vorhandener Godot-Runner,
Paketbrief-Ausgabe und Python-Fachtests. Keine Änderungen an Spielcode,
Speicherformaten, ARCH-24/-25/-26/-30 oder zentralen Projektstatusseiten.
Kein neuer Godot-Test, keine doppelte Registrierung. Die vorhandene CI entdeckt
die Python-Tests unter `tests/tooling` automatisch.

Nachweise und tatsächlich verwendete Quellstände stehen in
`docs/evidence/arch29-check-plan/results.json`.
