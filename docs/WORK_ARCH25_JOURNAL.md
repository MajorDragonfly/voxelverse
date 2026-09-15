# ARCH-25-JOURNAL – Entdeckungsbuch DE/EN

Basis: `d378ca0ecd7f03429a5150df6358e0646ec06689`; eigener Branch
`agent/arch25-journal-20260915`. Folgeauftrag nach ARCH-25-EDITOR / #103.

Das gemeinsame Entdeckungsbuch übersetzt Arten, Körperteile und Herkunft,
Regionen, nächste Schritte, Forschungsziele und Artenvergleich. Die bestehenden
Tierregister bleiben angeschlossen. Der Sprachwechsel aktualisiert Texte in den
vorhandenen Controls: Suche, Textauswahl, Filter, Seite, Auswahl, Scrollpositionen,
aufgeklappte Tierrollen sowie Modelle, Kameradrehung und Zoom bleiben erhalten.
Er führt keine Befehle aus und schreibt keine Spielstände.

## Daten und Grenzen

`journal_presentation.gd` projiziert kopierte Datensätze und bestehende stabile
Fachresultate. Gespeicherte Namen, Orte und IDs bleiben wörtlich erhalten. Nur
fehlende, vom Buch erzeugte Weltbezeichnungen werden übersetzt. Unbekannte alte
Teile bleiben über ihre ID sichtbar; unvollständige Körper erhalten keine
erfundenen Werte oder Vorschauen.

Der Katalog erhält einen optionalen Suchadapter und ein Kennzeichen für erzeugte
Ortsbezeichnungen. Arten-/Regionssuchen und Teil-/Zielsuchen akzeptieren DE/EN
unabhängig von der gerade angezeigten Sprache. Sortierung und Seitenzuordnung
bleiben stabil. Die vorhandenen Grenzen von 100 Zeilen pro Seite, gezieltem
Lesen der ausgewählten Anatomie und 192 Miniaturen bleiben erhalten; der Index
hält weiterhin O(N) kleine Metadatensätze. Es entsteht kein Entdeckungsarchiv.

264 zusätzliche Katalogeinträge: 158 Buchtexte sowie die 106 **identischen**
Teilnamen/-beschreibungen aus #103. Die 53 Teile behalten die bisherigen IDs.
Scanhinweise verwenden die eingestellte Scantaste. Die Eierbeschreibung nennt
jetzt die vorhandene Stammeshaltung statt eines nicht mehr zutreffenden
„noch nicht verfügbar“.

Schriftgröße 100–150 % gilt für alle Reiter. Kleine Ansichten verwenden die
Reiterauswahl, eine kurze Zurück-Schaltfläche und zweizeilige Such-/Filterwerkzeuge.
Details bleiben scrollbar; der Artenvergleich ordnet Modelle und Werte abhängig
von der verfügbaren Breite untereinander an.

## Prüfung

[Prüfnachweise](evidence/arch25-journal/README.md) nennen genaue Quellstände,
Engine, Befehle, Ergebnisse und Grenzen. Der neue Test erweitert die bestehende
Artenvergleichsprüfung mit echten Steuerelementen, beiden Vorschauen, atomarem
Schreibfehler und Save/Load. Er prüft zusätzlich 206 Arten, zweite Katalogseite,
Sprachwechsel ohne Neuaufbau oder zusätzlichen Detailzugriff, wörtliche Namen,
beide Suchsprachen, leere Ergebnisse und erhaltene Fachrückmeldungen.

```sh
python3 tools/validate_godot.py --godot GODOT --skip-main --tests journal_localization_test discovery_journal_test journal_paging_test owned_animal_localization_test domestic_fauna_journal_test research_goals_test localization_test
xvfb-run -s '-screen 0 1920x1080x24' python3 tools/review_journal_localization.py --godot GODOT --output /tmp/journal-review
```

Grafikmatrix: DE/EN, 800×600 / 1280×720 / 1920×1080, 100/150 % Text,
fünf Reiter plus Artenvergleich: 72 Kombinationen, 18 Aufnahmen.
Keine Änderung an Speicherformaten oder Spielregeln; keine Windows-,
Gesamtkampagnen- oder Ziel-PC-/FPS-Abnahme aus diesem Fachpaket ableiten.

## Integration

- #97 überarbeitet den HUD-Einstieg des Buchs. Dessen
  Zugangs-/Sichtbarkeitslogik erhalten; die hier übersetzten Buchansichten ergänzen.
- #103 liefert dieselben 106 `EDITOR_PART_*_NAME`/`*_DESCRIPTION`-Einträge:
  nach Schlüssel **einmal** übernehmen. Andere Ergänzungen (#95/#97/#99) erhalten;
  danach PO-Dateien mit `tools/localization/catalog.py` neu erzeugen.
- Neue Körpermodule/Schnauzen aus #96/#100 und ihren Folgepaketen bleiben bei
  ARCH-24. Zusätzliche Teiltexte und Kategorien bei der Integration anschließen.
- `journal_localization_test` genau einmal unter `frontend_locale` registrieren.
  Der Suchadapter ist optional; andere Katalogleser behalten ihren Anschluss.
- ARCH-26 wird nicht geändert. Zentrale Statusseiten und gemeinsame Abnahme
  bleiben bei der Integration. Kein Merge im Rahmen dieses Fachauftrags.
