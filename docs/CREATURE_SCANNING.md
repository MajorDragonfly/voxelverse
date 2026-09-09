# Kreaturen im Fadenkreuz scannen

Menü-Branch `agent/game-menus`, 9. September 2026.

E öffnet standardmäßig den Scanmodus. Eine unbekannte lebende Kreatur muss 2,5 Sekunden lang im Zentrum des Fadenkreuzes bleiben. Ein türkisfarbener Kreis und Prozentangabe zeigen den Fortschritt. Die Wertekarte erscheint erst nach Abschluss. Dann wird die Art im vorhandenen Entdeckungsbuch unter J gespeichert und erhält die bestehende einmalige Entdeckungsbelohnung. Beim erneuten Anvisieren derselben Art erscheinen die aktuellen Werte sofort; der Kreis ist grün.

Wegschauen, Sichtblockade, Reichweitenüberschreitung, Wechsel auf ein anderes Individuum, Ausschalten, Pause, Tod oder Kampagnen-/Planetenwechsel setzen einen begonnenen Scan zurück. Die Reichweite ist die vorhandene `inspection_radius` (20 Meter). Teilscans werden nicht gespeichert. Tastaturhinweise verwenden die frei belegbare Aktion `inspection_mode`.

## Anschluss und Speicherung

- `player_controller_v2.get_scan_target()` prüft den ersten Physiktreffer auf dem exakten mittleren Kamerastrahl, einschließlich Weltgeometrie. Der tolerante Interaktionskegel und die Nähe-Suche werden beim Scannen nicht verwendet.
- `creature_scanner.gd` verfolgt das konkrete Ziel; `scan_tracker.gd` hält dessen Zeit. UI und Einführung lesen das Ergebnis. Interagieren und Beißen entdecken neue Arten nicht mehr automatisch.
- `ProgressionService.register_species_scan()` nutzt weiterhin `discovered_species` und die bestehende Belohnungsdeduplizierung. Der Schlüssel bleibt `world_seed:species_seed`. Das optionale Feld `scan: {version: 1, complete: true}` markiert abgeschlossene Scans. Neue Abenteuer starten unabhängig. Snapshot- und Progressionsschema bleiben unverändert.
- Bereits entdeckte Arten aus älteren Spielständen ohne `scan` bleiben bekannt. Fehlende Buch-Anatomie wird beim ersten erneuten Anvisieren ergänzt, ohne weitere Belohnung. Die typisierten Körperdaten werden JSON-sicher im vorhandenen `journal`-Feld gespeichert.
- Speichern, unabhängige Kopien und Sicherungen übernehmen die vorhandenen Progressionsdaten; es entsteht keine zweite Entdeckungsdatenbank.

## Herkunft des Entdeckungsbuchs

Die drei kanonischen Dateien `core/discovery/discovery_records.gd`, `ui/discovery/discovery_journal.gd` und `ui/discovery/journal_preview.gd` sowie der additive Journal-Anschluss im ProgressionService stammen aus dem abgeschlossenen M4A-Stand `73583c0419aa625dbae32af619f11e0ae112ccb4`. Dessen Abschluss ist in `docs/DISCOVERY_JOURNAL_M4A.md` des Buch-Arbeitszweigs dokumentiert. Für diesen Anschluss wurden Hinweise auf den Scanablauf umgestellt und der passive Buchhinweis über die Speicheranzeige versetzt.

Neuere Forschungsziele, Vergleiche, Icons und die Skilltree-Oberfläche werden dadurch nicht zusammengeführt. Bei späterer Integration die kanonischen Dateien fortführen und den Scanvertrag erhalten; kein zweites Buch installieren. `main` bleibt unverändert.

## Abnahme

`tests/creature_scan_test.gd` nutzt die echte Spieler-/Wildlife-Szene und Physikwelt. Geprüft werden mittlerer Kamerastrahl, Wand, Wegschauen, Reichweite, totes Ziel, Pause, Umschalten, Individuenwechsel derselben Art, verzögerte Entdeckung, einmalige Punkte, Buch-Anatomie, sofortige Wiedererkennung, Speichern/Laden/Kopie, ältere Spielstände und Kampagnenisolation.

Die Frontend-Diagnose zielt mit der tatsächlichen Spielkamera auf eine prozedurale Kreatur und wartet den realen Scan ab. Sie prüft die zunächst verborgenen Werte, den Abschluss, J/Bucheintrag, Esc und sofortige Wiedererkennung. Die grafische CI erwartet 17 Aufnahmen einschließlich `scan_progress`, `scan_known` und `scan_journal`. Der neue Vertrag ist auch Teil der nativen Windows-/Linux-Exportprüfung. Aktuelle Laufresultate werden in PR #16 nachgeführt.

Lokaler Abschluss: 6/6 gezielte Prüfungen bestanden; der vollständige grafische Menü-/Scan-/Buchablauf bei 1600 × 900 mit Godot 4.6.3 und OpenGL-Kompatibilitätsrenderer endet mit `FRONTEND_PASSED`. Nachweise liegen unter `art/review/frontend/scan-*` beziehungsweise den drei Scan-PNGs.
