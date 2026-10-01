# PT17-06 · Sichtbarer Scankreis als Zielfläche

Auf dem gemeinsamen PT17-Preview neu umgesetzt, weil die vorher gemeldete lokale Fachbranch hier nicht veröffentlicht oder erreichbar war. Refs #172, #199.

Die tatsächliche Transform-/Skalierungsfläche des HUD-Rings bestimmt die Zielfläche. Nahe physische Tierkapseln und Nestzylinder werden in Bildschirmkoordinaten projiziert; der Schnitt mit dem Kreis liefert einen Prüfpunkt. Ein Weltstrahl bestätigt Sicht und verhindert Scans durch Hindernisse. Der gewählte, sichtbare Punkt erhält einen Marker; bei annähernd gleich guten Zielen wird das bisherige Ziel kurz gehalten. Der Scanner führt den Fortschritt weiter ausschließlich pro konkretem Individuum oder Nest und setzt ihn bei Zielwechsel, Pause und Sichtverlust zurück. DE/EN-Hinweise beschreiben den Kreis.

Godot 4.6.3, Linux/headless: `scan_circle_test` prüft den tatsächlichen Randtreffer unter 1 Pixel, Marker, Wand, Zielwechsel, UI-Skalierung, zwei Sichtfelder, zwei Körpergrößen, 1280 × 720, Nest, Rückseite und Pause. `creature_scan_test`, `nest_discovery_test`, `localization_test`, `onboarding_test`, `journal_localization_test` und `frontend_test` bestanden auf demselben Quellstand; der Übersetzungskatalog wurde daraus neu erzeugt. `last_scan_rays` zählt bestätigende Physikstrahlen zur Diagnose.

Grafische Beurteilung bei Bewegung, Vergleich mehrerer Tiere und Bildraten sowie Ziel-PC-Spieltest stehen aus. Der Scan benutzt weiterhin die bestehende Entdeckungs-/Speicherverwaltung.
