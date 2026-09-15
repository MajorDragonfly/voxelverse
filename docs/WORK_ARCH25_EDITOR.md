# ARCH-25-EDITOR – Kreaturenwerkstatt DE/EN

Basis: `d378ca0ecd7f03429a5150df6358e0646ec06689` (gemeinsames main nach #92).
Branch: `agent/arch25-editor-20260915`. ARCH-26 bleibt beim anderen Fachchat.

## Lieferung

Die aktive Kreaturenwerkstatt zeigt Grundbedienung, 53 Teilnamen und Beschreibungen,
Körperformen, Farben/Hauttypen, Gelenke, Sattel/Geschirr und Bewegungstests in
Deutsch und Englisch. 354 Nachrichten ergänzen den vorhandenen Sprachkatalog.
Die kanonischen Teile, Werte, Freischaltungen und Spielernamen werden nicht übersetzt.

Sprachwechsel aktualisiert bestehende Controls und gespeicherte Darstellungsdaten.
Er ruft weder `_refresh_all()` noch eine Prüfung, einen Befehl oder einen Save auf.
Entwurf, Undo/Redo, aktiver Bearbeitungsschritt, Auswahl, Fokus, Scrollposition,
Sitzvorschlag und laufende Bewegungsprüfung bleiben erhalten. Bekannte Rückmeldungen
des geerbten V7-Editors werden am Darstellungsanschluss übersetzt. Unbekannte
Kompatibilitätsdiagnosen bleiben unverändert sichtbar.

Die Seitenleisten scrollen vollständig. Bei schmaler Arbeitsfläche schaltet die
Schaltfläche oben zwischen Teileauswahl und Eigenschaften um. Die vier Modusreiter,
Speichern/Laden und der Weltzugang bleiben erreichbar; Aktionsleisten und Meldungen
berücksichtigen Zeilenumbruch. Die Kamera passt die Kreatur an die verbleibende
Fläche an. Teilkarten zeigen umgebrochene Namen und die vorhandenen echten Vorschauen.
Der Vorlagenzugang hängt am tatsächlichen Palettenspalten-Container.

## Prüfung

Die Nachweise und genaue Quellrevision stehen in `docs/evidence/arch25-editor/`.
Godot 4.6.3, Linux, isolierte Benutzerdaten. Gezielte Auswahl:

```sh
python3 tools/validate_godot.py --godot GODOT --skip-main --tests \
  editor_localization_test creature_studio_test creature_parts_studio_test \
  creature_joint_studio_test creature_body_fit_test creature_seat_fit_test \
  creature_library_ui_test localization_test --output OUTPUT
```

Der neue Fachtest nutzt den echten Editor: GUI-Aktionen, Sprachwechsel während
Bearbeitung und bei F8, unveränderte Control-Identitäten, Namen mit Platzhaltern,
Undo/Redo, erfolgreiches und blockiertes atomisches Speichern, Neustart,
Anschluss-/Sitzberichte, laufende Bewegungsprüfung und bestehende Vorlagenzugänge.
Der Sprachwechsel setzt die Fachprüfungen nicht zurück und wiederholt keine Aktion.
Die Layoutmatrix umfasst DE/EN, 800×600, 1280×720 und 1920×1080, 100/150 % Text
und alle vier Modi. Der Grafikrunner prüft dieselbe Matrix mit OpenGL-Kompatibilität
und liefert 16 Aufnahmen; repräsentative Ansichten werden visuell kontrolliert.

```sh
xvfb-run -s '-screen 0 1920x1080x24' python3 tools/review_editor_localization.py \
  --godot GODOT --output OUTPUT
```

Kein Windows-Export, gemeinsamer Kugelkampagnentest oder Ziel-PC-/FPS-Nachweis.
Native Godot-Farbwahldialoge und fachfremde Kompatibilitätsdiagnosen verwenden ihre
bestehende Darstellung. ARCH-25 insgesamt bleibt offen.

## Integration

Schreibbereiche: aktive `creature_editor_*studio.gd`-Vererbungskette,
`creature_editor_runtime.gd`, `creature_part_card.gd`, neuer Darstellungshelfer,
`localization/catalog.json` und generierte PO-Dateien, neue Testregistrierung
unter `frontend_locale` sowie Grafikrunner. Keine Änderungen an Save-/Körperformat,
Terrain, Dorf oder Mehrsiedlungslogik.

PR #96 (Rüssel) ergänzt denselben Editor. Bei der Zusammenführung dessen zusätzliche
Kategorie, Kataloganbieter und Anschlusslogik erhalten und die neuen Teiltexte
im gemeinsamen Sprachkatalog ergänzen. Die bereits vorbereiteten Katalogergänzungen
aus #95 und #97 ebenfalls erhalten; PO-Dateien aus dem vereinigten Katalog erzeugen.
Der neue Test gehört genau einmal unter `frontend_locale`. Gemeinsame Statusseiten
und die Gesamt-/Exportprüfung bleiben beim Integrationschat. Kein Merge durch diesen
Fachchat.
