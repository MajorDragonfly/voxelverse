# ARCH-25 – Fähigkeiten im Entwicklungsbuch DE/EN

Stand: 10. September 2026. Basis: `bb2f83b56267964baa7037720c4daca26fe3d007` (`main`, Integrationsstand mit PR #77).
Branch: `agent/arch25-skills-localization-2026-09-10`.
Implementierungscommit: `072503ecbe092eda7611f3bc70b1dbcf282b00d2`.
Geprüfter Implementierungsbaum: `d56d80ba5780db2fc4505554c9bb8381548ade1d`.

**Status: abgegrenztes Teilpaket geliefert, gemeinsame Integration noch offen.** ARCH-25 insgesamt bleibt offen. ARCH-22, -06, -07 und -24 wurden laut Auftrag parallel bearbeitet; ihre Fachdateien bleiben außerhalb dieser Lieferung.

## Ergebnis

Der vorhandene Fähigkeiten-Reiter übersetzt sämtliche Texte für Deutsch und Englisch: acht echte Fähigkeiten aus Kreaturen- und Stammeskatalog, Beschreibungen, Voraussetzungen, Kosten, Punktebestände, Sperren, Vermächtnisse und Kauf-/Fehlermeldungen. Auch die Vorschau aller sechs vorhandenen Phasen mit ihren Tätigkeiten, geplanten Punktequellen und Grenzen ist übersetzt. Nicht spielbare Phasen bleiben reine Vorschau ohne Käufe.

Der gemeinsame Buchrahmen erhält übersetzte Titel, Navigation, Phasenauswahl, Pausenstatus und Schließen. Der separate Inhalt des Reiters „Entwicklungspfad“, andere Journalbereiche und das allgemeine HUD sind keine vollständige Übersetzungslieferung dieses Pakets.

Beim Sprachwechsel bleiben dieselben Control-Instanzen, gewählte Phase/Fähigkeit, Tastaturfokus, Pause und Kaufbeleg erhalten. Die Scrollposition bleibt in Pixeln erhalten und wird nur am neuen Inhaltsende begrenzt, wenn die Übersetzung kürzer ist. Eine Kaufmeldung wird aus dem bestehenden Ergebnis neu dargestellt, ohne nochmals zu kaufen, Punkte zu vergeben, die Kampagne zu speichern oder den Entwicklungspfad neu aufzubauen.

Die Ansicht unterstützt die vorhandene Schriftpräferenz bis 150 %. Bei schmalen Fenstern stehen die Fähigkeitsäste untereinander; lange Kartentexte vergrößern ihre Karte. Navigation erhält Platz für vollständige Wörter, Schließen bleibt erreichbar und lange Inhalte bleiben scrollbar. Die kleine Ansicht wurde nach Sichtung der ersten Aufnahmen nachgebessert, damit deutsche Reiter nicht mitten im Wort umbrechen.

## Datenbesitzer und Verträge

- `ProgressionService` mit `BehaviorCatalog`, `BehaviorProgression` und `TribalProgression` bleibt alleiniger Besitzer von Regeln, Käufen und Punkten. Verhalten Schema 1 / Regelversion 1, Stammesfortschritt Schema 3 und Kampagnenspeicher bleiben unverändert.
- `SaveGameService` führt den bestehenden atomaren Kaufabschluss samt Rücksetzung bei Fehlern aus. Es gibt keinen neuen Writer, Save-Teilnehmer oder eine Migration.
- `ui/skills_presentation.gd` liest stabile Knoten-/Phasenkennungen. Übersetzungen liegen im vorhandenen Katalogschema 1 und verwenden `UiText`. Die Fachdaten werden nicht übersetzt oder verändert.
- `LocaleManager` bleibt Besitzer der Gerätepräferenz. 130 neue Katalogeinträge ergeben auf dieser Basis 566 Nachrichten für DE/EN. Die PO-Dateien sind aus `catalog.json` generiert.
- Buchpause, Eingabe und Übergabe an das gemeinsame Entdeckungsbuch bleiben beim bestehenden `behavior_skill_tree.gd`; keine zweite Buchinstanz.

## Nachweise

Godot `4.6.3.stable.official.7d41c59c4`, isolierte Einstellungen und Spielstände:

- `skills_localization_test`: 1.534 Bedingungen im Hauptprozess bestanden, zusätzlich frischer Godot-Prozess zum Laden aller sechs gekauften Kreaturenfähigkeiten und des englischen Katalogs. Der Test erweitert den vorhandenen echten Spieler-/GUI-Test, einschließlich Maus/Tastatur, Pausenbesitz, Kauf, Schreibfehler/Rücksetzung, Laden, Journalübergabe und Szenenabbau.
- Sprachwechsel während leerer/verfügbarer Ansichten sowie nach echten erfolgreichen und fehlgeschlagenen Käufen. Kampagnen-/Fortschrittswerte, gespeicherte Datei, Ergebnisdaten, Auswahl, Control-Identitäten und Fokus werden verglichen. Alle acht Knoten und alle sechs Phasenvorschauen werden gegen die tatsächlichen Kataloge geprüft.
- Bestehende `behavior_skill_tree_test` und `localization_test` separat erfolgreich. Ergebnisdatei des exakten Implementierungscommits: [validation.json](evidence/arch25-skills/validation.json).
- Native OpenGL-Ausführung mit Mesa/llvmpipe: derselbe erweiterte GUI-Test erfolgreich, 26 Aufnahmen für DE/EN bei 1920×1080, 1280×720 und 800×600 mit 100/150 % Schrift, einschließlich gescrollter Details sowie Stammes-/Zukunftsvorschau. Vier ausgewählte Aufnahmen sind hier beigefügt; Übersicht und Log unter [native-results.json](evidence/arch25-skills/native-results.json) und [native-render.log](evidence/arch25-skills/native-render.log). Die genannten kleinen und großen Ansichten wurden visuell geprüft.
- `tools/localization/catalog.py --check`, Vertragszuordnung und Python-Syntax erfolgreich. Der neue Test ist genau einmal unter `home_progression` eingetragen; die Registry enthält auf dieser Basis 152 Tests in 17 Verträgen. Dies behauptet keinen erneuten Gesamtlauf aller 152 Tests.

Die absichtliche Meldung zum fehlenden Speicherverzeichnis gehört zur Rücksetzungsprüfung. Native Quellprojekt-Darstellung belegt weder Windows-Export noch Ziel-PC-FPS oder eine vollständige Kugelspielabnahme. Bei 800×600 mit 150 % Schrift sind Details durch Scrollen erreichbar; das Fenster zeigt bewusst nicht den ganzen Baum gleichzeitig.

## Reproduktion

```sh
python tools/localization/catalog.py --check
python tools/validate_godot.py --godot /path/to/godot --skip-main --tests skills_localization_test behavior_skill_tree_test localization_test --output /tmp/skills-validation
xvfb-run -a python tools/review_skills_localization.py --godot /path/to/godot --output /tmp/skills-review
```

Der native Prüfer benötigt ein nutzbares Display. Er erzeugt alle 26 Aufnahmen und verändert keine vorhandenen Kampagnen oder Einstellungen.

## Geänderte Dateien und Integration

- Laufzeit: `ui/behavior_skill_tree.gd`, `ui/skills_presentation.gd` und dessen UID.
- Übersetzungsquelle und erzeugte Ressourcen: `localization/catalog.json`, `localization/de.po`, `localization/en.po`.
- Prüfung: `tests/skills_localization_test.gd`, `tools/review_skills_localization.py`, `tools/validation/contracts.json`.
- Diese Übergabe und ausgewählte Belege unter `docs/evidence/arch25-skills/`.

Bei parallelen Katalogänderungen Schlüssel additiv vereinigen und PO-Dateien erneut generieren. Neue Testeinträge additiv erhalten. Die gemeinsame Roadmap-/Integrationspflege liegt beim Integrationsbesitzer; dieser Bericht schließt nur den Fähigkeiten-Reiter und seine Phasenvorschauen als ARCH-25-Teilumfang ab. Nächster unabhängiger Sprachumfang ist der eigentliche Entwicklungspfad oder ein abgegrenzter Dorf-/HUD-Bereich.
