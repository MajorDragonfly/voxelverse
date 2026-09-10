# ARCH-25 — Teilpaket 4: Eigene Tiere DE/EN

Stand: 2026-09-10. Basis: `ea900f2e09946660694a9e59399b4680a5655a85`.
Eigenständiges Teilpaket nach Nachbarstämmen (#51), Weltkarte (#60) und Heimat & Gruppe (#64).
ARCH-25 insgesamt bleibt offen; geliefert wird der bestehende Tierregister-Reiter im gemeinsamen Entdeckungsbuch.

## Ergebnis

Das Register übersetzt Besitz, Zustand, Vertrauen, Folgen/Warten/Heimkehr, Ziel-/Heimatorte, Tierkennung und Leer-/Fehlermeldungen. Kugelorte zeigen Breite/Länge/Höhe mit sprachabhängigen Dezimalzeichen; alte Flächenorte behalten ihre X/Y/Z-Anzeige. Verstorbene Tiere zeigen den letzten Besitzer und keinen aktiven Auftrag.

Suche, Filter, Seite, Auswahl, Tastaturfokus, Caret, markierter Suchtext, beide Scrollpositionen und Pause bleiben beim Sprachwechsel erhalten. Die bestehenden Detail-Labels werden weiterverwendet. Deutsche und englische Fachbegriffe sind gleichzeitig durchsuchbar, sodass eine Suche nach „Heimkehr“ auch in Englisch dieselben Treffer liefert. Die Reihenfolge folgt den gespeicherten Namen und stabilen IDs, unabhängig von übersetzten Ersatznamen.

Tier-, Arten-, Stammes-, Betreuer- und Weltnamen bleiben wörtlich. Übersetzungsschlüssel und Platzhalter innerhalb eines Namens werden nicht verarbeitet. Der gemeinsame Buchrahmen erhält DE/EN für Titel, Reiternamen, Tierfilter, Suche, Seitenzähler, Schließen und Hinweis-Schalter. Andere Reiterinhalte sind damit noch nicht vollständig übersetzt.

Die Tieransicht berücksichtigt Schriftvergrößerung bis 150 %. Auf kleinen Fenstern wechseln Überschrift/Aktionen in mehrere Zeilen; Liste und Details bleiben getrennt scrollbar. Der Schließen-Button erhält eine Mindestbreite und Textumbruch. Eine zuvor nach Tierauswahl unsichtbare Meldung bei leeren Suchergebnissen wird wieder eingeblendet.

## Datenbesitzer und Anschlüsse

- `owned_animal_reader.gd` bleibt der lesende Anschluss an den vom Host gebundenen aktiven D2-Controller. Validierung, Kampagnen-/Körper-/Stammesabgleich und bestehende Änderungs-/Ladeereignisse bleiben erhalten. `scope_error()` behält seine deutsche Diagnose-API; `scope_code()` und das neue Ergebnisfeld `code` liefern stabile Präsentationskennungen.
- `owned_animal_presentation.gd` formatiert ausschließlich kopierte Werte und liest die vorhandenen Sprachressourcen. Die Zeilen behalten ihre bisherigen Felder; `_display_data` enthält die kopierten Ausgangswerte für einen Sprachwechsel ohne erneuten Datenabruf oder Filterlauf.
- Das gemeinsame Buch besitzt weiter Pause, Auswahl, Suche, Seiten und Scrollcontainer. Es aktualisiert beim Übersetzen vorhandene Listeneinträge und Details, ohne Befehle auszulösen oder Fortschritt zu vergeben.
- D2 bleibt Besitzer von Tieridentität, Vertrauen, Gesundheit, Besitz und Auftrag. D1-/D2-/D3-Verträge, SaveGameService, Kampagnenschemata und Produktionsdaten sind unverändert. Das Paket erzeugt keine zweite Tierhaltung und keine Migration.

## Nachweise

Godot 4.6.3, isolierte Spielstände und Einstellungen:

- `owned_animal_localization_test`: 248 Bedingungen im Hauptprozess bestanden. Er erweitert den bisherigen Registertest mit echten D2-Zähmungs-/Futtertransaktionen, Folgen/Warten/Heimkehr, Schreibfehlern, Tod, Kontextwechsel, stummen Ladeereignissen und einem frischen Engine-Prozess. Originaldateien bleiben bei Sprachwechsel bytegleich; Kampagnen-/Fortschrittszustand, Befehlszähler, Control-Instanzen, Fokus und Scrollwerte werden verglichen.
- Eine tiefe Kopie des tatsächlich erzeugten Registers wird zu einer gültigen 127-Tier-Kugelort-Testsammlung erweitert. Sie prüft zweite Seite, zweisprachige Suche, wörtliche Namen, lebende/verstorbene Tiere sowie die unveränderte Ablehnung von Schema 99. Diese Sammlung wird nicht als Spielerbestand gespeichert; anschließend wird der Originalbestand wieder gebunden.
- Die ursprünglichen `owned_animal_register_test`, `discovery_journal_test` und `localization_test` bestehen. Der Buchtest prüft auch die bisherige 3D-Vorschau mit Drag/Wheel und kleine Fenster.
- `domestication_campaign_test` besteht mit 50 Bedingungen im Hauptprozess und eigener Neustartprüfung: tatsächlicher Kampagnen-/Stammesanschluss, Futter, physische Tierbewegung, Speicherfehler, Kopie mit neuer Kampagnen-ID, Tod und Schutz neuerer Versionen. Das ist ein zusätzlicher D2-Kampagnen-Regressionsnachweis, keine vollständige Kugelspielabnahme.
- Native OpenGL-Prüfung: DE/EN bei 1920×1080, 1280×720 und 800×600, jeweils 100/150 %. Dazu gescrollte Details, verstorbene Tiere, leere Suche und ungültiges Register bei 800×600/150 %: 20 Aufnahmen. Die 248 Bedingungen bestehen auch im nativen Lauf; ausgewählte Bilder wurden visuell kontrolliert.
- Kataloggenerator: 280 Nachrichten in beiden Sprachen konsistent. Python-Syntax und `git diff --check` bestanden. Messwerte und vier Aufnahmen: `docs/evidence/arch25-animals/`.

Die Namen `Tier {name}`, `Schließen {species}` und `Eigene Tiere` sind absichtliche wörtliche Testnamen, auch in englischen Bildern. Die Aufnahmen zeigen die tatsächliche Oberfläche mit der kopierten Prüfsammlung. Sie belegen keine Ziel-PC-/FPS-Leistung, vollständige Terrainansicht oder Exportabnahme. Bei kleiner Auflösung und großer Schrift sind lange Details über den vorhandenen Scrollbereich erreichbar.

Reproduktion:

```sh
python tools/localization/catalog.py --check
python tools/validate_godot.py --godot /path/to/godot --skip-main --tests owned_animal_localization_test owned_animal_register_test discovery_journal_test localization_test domestication_campaign_test --output /tmp/owned-validation
xvfb-run -a python tools/review_owned_animal_localization.py --godot /path/to/godot --output /tmp/owned-review
```

## Integration

Die Basis enthält #51/#60/#64 noch nicht. Deren zusätzliche Katalogschlüssel mit diesem Paket vereinigen und anschließend `python tools/localization/catalog.py` ausführen. Keine generierte PO-Datei pauschal durch eine einzelne Branchfassung ersetzen.

Die parallele Arbeit an HUD und responsivem Entdeckungsbuch betrifft den gemeinsamen Host `discovery_journal.gd`. Bei Integration die Layoutänderungen des Hosts erhalten und die hier ergänzten Sprachereignisse, kopierten Anzeigezeilen, Literalnamen und erhaltenden Aktualisierungen einpassen. Das fremde unfertige Layout wird in diesem Paket nicht übernommen. Anschließend Register- und Buchtests auf dem vereinigten Stand ausführen.

Nach Integration von ARCH-29 / #53 `owned_animal_localization_test` genau einmal im Vertrag `discovery_map` in `tools/validation/contracts.json` registrieren, neben dem bestehenden Registertest. Der bisherige Runner entdeckt ihn bereits automatisch. Kein fremdes Register wird hier vorgezogen.

Gemeinsame Roadmap, Gesamtstatus und Integration bleiben beim Integrationsbesitzer. Weitere Dorf-, Buch- und Editorinhalte sind eigene ARCH-25-Teilpakete.
