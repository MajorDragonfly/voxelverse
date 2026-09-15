# Stammes-Testeinstieg: Fachnachweis

Quellcommit `853e7baa113cebddf28de3886fcf92ea5b9ce82c`, sauberer Arbeitsstand.
Tree `71f8b6e8bb996385a09b86c07825d052bc067e04`.
Godot `4.6.3.stable.official.7d41c59c4`, Linux Headless, isolierte Nutzerdaten
mit `tools/validation_support.py`. Dieser Nachweiscommit ergänzt ausschließlich
Dokumentation/Protokolle; er ändert den geprüften Code nicht.

## Abschlussprüfung

```sh
python3 tools/validate_godot.py --godot <Godot-4.6.3> \
  --tests tribal_playtest_test --skip-main --skip-import \
  --output <neues-Protokollverzeichnis>
```

`source_contracts` und `tribal_playtest_test` erfolgreich. Testdauer 72,254 s.
Der echte Titelpfad prüft Beschreibung/Abbruch ohne Slotanlage, Deutsch/Englisch,
Abbruch während der Vorbereitung per Escape mit freigegebener Kreaturensteuerung,
Doppelklickschutz, getrennte Testkampagne, unveränderten Originalspielstand,
Abbruch und Bestätigung des Epochenfensters, drei ursprüngliche Bewohner und
Gruppenkamera, Holzlieferung auf dem Kugelgelände und Wiederaufnahme in einem
frischen Prozess. Der Neustartmarker wird im Elterntest ausdrücklich geprüft.

[Runnerergebnis](playtest-results.json) · [Laufprotokoll](tribal_playtest_test.log.gz) ·
[Quellmanifest](source.json).

## Wiederverwendete direkte Prüfungen

Import (8,967 s), Asset-Quellprüfung (2,228 s), `phase_handoff_test` (9,151 s),
`frontend_test` (66,427 s) und `localization_test` (2,077 s) erfolgreich.
Die Paketimplementierung, Menütexte und Testzuordnung waren dabei bereits
identisch zum Abschlussstand. Danach kamen nur der ausführlichere Testablauf
und Dokumentation hinzu. Deshalb wurden die unveränderten Verbraucher nicht
nochmals geprüft; der neue Ablauf wurde am sauberen Abschlusscommit geprüft.
Der Import desselben lokalen Ressourcenstands wurde beim Nachlauf ausgelassen.

[Teilergebnisse](regression-results.json) · [Import](import.log.gz) ·
[Übergabe/Rollback](phase_handoff_test.log.gz) · [Hauptmenü](frontend_test.log.gz) ·
[Sprache](localization_test.log.gz).

Keine volle Integrationssuite, nativer Windows-Export, grafische Abnahme oder
Messung auf Lars' Ziel-PC. Der neue Menüpunkt erfordert einen Build dieses
Branches bzw. seine Übernahme in den gemeinsamen Spieltest.
