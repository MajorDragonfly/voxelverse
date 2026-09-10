# ARCH-25 — Teilpaket 3: Heimat & Gruppe DE/EN

Stand: 2026-09-10. Ausgangsbasis: `ea900f2e09946660694a9e59399b4680a5655a85`.
Eigenständiges Teilpaket nach Nachbarstämmen (#51) und Weltkarte (#60).
ARCH-25 insgesamt bleibt offen; diese Lieferung umfasst das Heimatfenster und seinen kurzen HUD-Hinweis.

## Ergebnis

Heimat gründen/verlegen, Gruppen- und Einzelbefehle, Zusammenfassung, Erholungshinweis sowie Erfolgs-/Fehlerrückmeldungen sind auf Deutsch und Englisch verfügbar. Der HUD-Hinweis übersetzt Entfernung und wartende Gefährten einschließlich deutscher Einzahl/Mehrzahl.

Sprachwechsel aktualisieren die vorhandenen Zeilen. Sie erteilen keinen Befehl, bauen keine Gefährten neu auf und schreiben keinen Kampagnenstand. Tastaturfokus, Scrollposition, Pause, Heimatort, Mitgliedsidentitäten, Namen und Befehle bleiben erhalten. Namen werden wörtlich eingesetzt; auch die 3D-Namensschilder übersetzen sie nicht automatisch.

Die vorhandene Gestaltung bleibt bestehen. Die Ansicht berücksichtigt nun die zentrale Schrift-/UI-Skalierung bis 150 %, bricht Buttontexte um und hält die Schließen-Aktion außerhalb des scrollbaren Inhalts erreichbar. Bei ungültigen Gruppendaten steht die Fehlermeldung einmal oberhalb der gesperrten Aktion; eine geänderte Sprache stellt keine ungültigen Daten wieder her.

## Fachanschlüsse und Datenbesitzer

- `home_group_controller.gd`: `establish_home()` und `issue_order()` liefern weiterhin Dictionaries mit `ok` und dem bisherigen deutschen Diagnosefeld `message`. Zusätzlich liefern sie die stabilen Felder `code` und `params`. Das Heimatfenster verwendet ausschließlich diese neuen Felder für die sichtbare Rückmeldung. Alle derzeitigen Ergebnisse haben leere Parameter; dynamische Namen stehen in der Präsentation.
- `home_group_state.gd`: `validation_code()` liefert die Kennung einer ungültigen Gruppe. Die bisherige Funktion `validate()` behält ihre deutschen Diagnosemeldungen für SaveService und bestehende Verbraucher bei. Validierungsbedingungen und deren Reihenfolge bleiben gleich.
- `home_group_controller.problem_code` begleitet die bestehende Diagnose `problem`. Eine erfolgreiche erneute Prüfung entfernt den vorigen Fehler. `home_companion.status_code` liefert den Bewegungszustand an den HUD-Zähler; die bestehende Diagnose `status` bleibt kompatibel.
- `home_group_presentation.gd` ist eine reine Anzeigehilfe. Sie liest die Sprachressourcen und verändert keine Gruppen-/Kampagnendaten. Freie Namen werden einmalig in die Vorlage eingesetzt; darin enthaltene Platzhalter oder Übersetzungsschlüssel bleiben wörtlich.
- Besitzer bleibt `body.home_group` im vorhandenen gemeinsamen Spielstand. Gruppenformat 1 für Altstände und Format 2 für Kugelorte, Körper-/Spezies-/Mitglieds-IDs und gespeicherte Befehle bleiben unverändert. Kein neues Saveformat, keine Migration, keine zweite Gruppe oder Fortschrittsquelle.

## Nachweise

Godot 4.6.3 mit isolierten Spielständen und Einstellungen:

- `home_group_localization_test` erweitert den vorhandenen `home_group_test`: echte GUI-Klicks, zwei physische Gefährten, Folgen/Warten/Heimkehr, Heimatverlegung ohne Teleport der Mitglieder, Schreibfehler mit Rücknahme, Schutz zukünftiger Versionen, Körperwechsel/Wiederbesuch und ein frischer Engine-Prozess.
- Zusätzliche Sprachwechsel prüfen dieselben Controls und Gefährteninstanzen, den exakten Scrollwert/Fokus, unveränderte Kampagnen-/Fortschrittsdaten und bytegleiche gespeicherte Dateien. Fehlgeschlagene Befehle werden beim Übersetzen nicht erneut ausgeführt. Ein übersetzter, gescrollter Einzelbefehl beeinflusst nur das gewählte Mitglied. Auch nach dem frischen Neustart bleiben die Testnamen erhalten.
- Die ursprünglichen `home_group_test` und `localization_test` bestanden. `spherical_creature_test` prüfte die echte Kugelkampagne mit Heimatgründung, zwei Gefährten, Editorbesuch und Rückkehr an den bestehenden Heimatort sowie den bisherigen Scan-/Wasseranschluss.
- Native OpenGL-Aufnahmen: DE/EN bei 1920×1080, 1280×720 und 800×600 mit jeweils 100/150 %. Dazu kommen Leerzustand, gescrollte Befehle und unbekannte Gruppenversion bei 800×600/150 %: insgesamt 18 Aufnahmen. Alle Buttons werden auf Erreichbarkeit geprüft; ausgewählte Aufnahmen wurden visuell kontrolliert.
- Kataloggenerator (269 Einträge je Sprache), Python-Syntax und `git diff --check` bestanden. Messwerte und ausgewählte Bilder liegen unter `docs/evidence/arch25-home/`.

Die Namen `HOME_FOLLOW {name}` und `Schließen` in den Belegen sind absichtliche Testnamen: Sie weisen nach, dass Namen weder übersetzt noch als Platzhalter verarbeitet werden. Die Bilder stammen aus einer kontrollierten Prüfwelt mit der tatsächlichen Heimatoberfläche und den tatsächlichen Bewohnern. Sie belegen keine Ziel-PC-Leistung, Terrainqualität oder vollständige Spiel-/Exportabnahme.

Reproduktion:

```sh
python tools/localization/catalog.py --check
python tools/validate_godot.py --godot /path/to/godot --skip-main --tests home_group_localization_test home_group_test localization_test spherical_creature_test --output /tmp/home-validation
xvfb-run -a python tools/review_home_group_localization.py --godot /path/to/godot --output /tmp/home-review
```

## Integration

Die Basis enthält noch nicht die eigenen Lieferungen #51/#60 oder das ARCH-29-Register #53. Beim Zusammenführen die zusätzlichen Schlüssel aller drei ARCH-25-Katalogänderungen vereinigen und danach `python tools/localization/catalog.py` ausführen. Generierte PO-Dateien nicht durch eine einzelne Branchfassung ersetzen.

Nach Integration von #53 `home_group_localization_test` genau einmal im Vertrag `home_progression` in `tools/validation/contracts.json` registrieren. Der bestehende Runner entdeckt den Test bereits automatisch. Das neue Register und fremde unfertige Branchstände werden hier nicht übernommen.

Die gemeinsame Roadmap und der Gesamtstatus von ARCH-25 bleiben beim Integrationsbesitzer. Weitere Dorfansichten, Entdeckungsbuch und Editor sind eigene Sprachpakete.
