# Quellnachweis des Testläufers

Basis: `1d6573d9551c3f24bf1dd6fa64e5c301583a26c8` / Integrations-PR #110.
Geprüfter Quellcommit: `3c506cd2319ef375fb54657283eb597d5f078486`,
Tree `8a2a53f94ccd881e73a674d3182ff897c055ea88`, sauber zu Laufbeginn.

## Ergebnisse

- **53 Python-Werkzeugtests bestanden**, davon 19 neue Provenienzfälle.
  Echte temporäre Git-Repositories, Worktree, Änderungen/Commit/Staging,
  Binärdaten, Umbenennung/Löschung, symbolische Links und Konflikte.
  Reale Python-Subprozesse ändern absichtlich ihre Fixture-Quelle; der Runner
  erhält das technische Einzelresultat, stoppt Folgetests und lehnt den Gesamtnachweis ab.
  Das sind Werkzeugprüfungen, keine simulierten Gameplay-Erfolge.
- **Godot 4.6.3**, Linux Headless, isolierte Nutzerdaten:
  Quellgate 0,115 s, Import 5,890 s, Asset-Quellprüfung 2,021 s und bestehender
  `performance_measurement_test` 1,419 s erfolgreich.
- Der neue Quellnachweis erfasste zehn Beobachtungen und 184 neue Import-UIDs.
  Status `generated_outputs_only`: gleicher Commit/Tree, keine unerwartete
  Änderung; erzeugte Dateien mit Einzelhashes vollständig erhalten.

```sh
python3 -m unittest discover -s tests/tooling -p 'validation_*_test.py' -v
python3 tools/validate_godot.py --godot <Godot-4.6.3> \
  --tests performance_measurement_test --skip-main --output <neues-Verzeichnis-außerhalb-des-Projekts>
```

Der Enginepfad wird durch den vorhandenen Runner in eine temporäre Kopie ohne
Self-contained-Marker aufgelöst. Die tatsächlichen Befehle und Zeitgrenzen stehen
im vollständigen JSON-Bericht. Die erzeugten unversionierten UID-Dateien wurden
erst **nach** Abschluss des Laufs aus dem Fachcheckout entfernt.

## Konsolenausgabe und anfänglicher Befund

Commit `45b29f717d2ce0b20a8e2fbe041f34a0abee1a62`,
Tree `0dee64898200bf2f5d2906985fe327038dd63550`, kürzt ausschließlich die letzte
Konsolenmeldung auf Status und Zähler. Vollständige Ereignisse bleiben in JSON.
Dieselben 53 Werkzeugtests bestanden anschließend erneut (3,600 s).
Kein erneuter Godot-Lauf für diese Ausgabekorrektur behauptet.

Der erste Python-Lauf meldete eine unregistrierte Stammes-Testdatei aus dem
vorherigen Paket #116. Dessen unveränderte Restdateien wurden anhand der
veröffentlichten Blob-Hashes geprüft und aus diesem eigenständigen Basischeckout
ausgelagert. Der Quelltest wurde weder abgeschwächt noch der alte Test erneut
registriert. Der anfängliche Fehlerbericht bleibt erhalten.

[Zusammenfassung](summary.json) · [Vollständiger Runnerbericht](results.json.gz) ·
[Startstand](source-start.json) · [Python](python-source.log.gz) ·
[Konsolenkorrektur](python-console-summary.log.gz) · [Anfangsbefund](python-initial.log.gz) ·
[Godot-Test](performance_measurement_test.log.gz) · [Import](import.log.gz).

Beobachtungen an Befehlsgrenzen sind keine Dateisystemsperre. Vollständig zwischen
zwei Beobachtungen rückgängig gemachte Änderungen können unbemerkt bleiben.
Keine vollständige Spiel-/Export-/Windows-/Grafik-/Ziel-PC-Abnahme.
