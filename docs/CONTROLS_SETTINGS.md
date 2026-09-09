# Voxelverse: Steuerung und Komfort

Stand: 9. September 2026, `agent/game-menus`, Fortsetzung von Entwurfs-PR #16.

## Bedienung

F8 oder „Einstellungen“ im Titel-/Pausemenü öffnet die Bereiche **Anzeige** und **Steuerung**. Die Steuerungsseite enthält Mausempfindlichkeit (20–300 Prozent), vertikale Umkehrung der Spielkamera und die maximale Bildrate (unbegrenzt, 30, 60, 90, 120, 144, 165 oder 240 FPS). VSync kann die Bildrate zusätzlich begrenzen.

Acht Spielaktionen haben jeweils eine Haupt- und eine Zweitbelegung: vorwärts, rückwärts, links, rechts, springen/aufsteigen, interagieren, beißen und untersuchen. Einen Belegungsbutton anklicken und eine einzelne Tastatur- oder Maustaste drücken. Esc bricht nur die laufende Tastenauswahl ab. Rücktaste/Entfernen löscht die ausgewählte Belegung, sofern mindestens eine andere Belegung für diese Aktion übrig bleibt. Konflikte werden beschrieben und nicht automatisch überschrieben. Mausrad und Tastenkombinationen sind in dieser ersten Fassung keine Belegungen.

J und K bleiben für Entdeckungsbuch und Skilltree reserviert. Menü-/Editorfunktionstasten sowie Esc, Tab und Enter bleiben fest. Die Steuerungshilfe, der Interaktionshinweis und die bestehende Kreaturenuntersuchung zeigen die tatsächlich aktive Belegung. Tastaturlayouts werden über physische Tastenpositionen und deren aktuelle Beschriftung berücksichtigt.

Änderungen und „Standard zurücksetzen“ sind zunächst vorgemerkt. Erst **Übernehmen & speichern** aktiviert sie. Zurück/Schließen verwirft den Entwurf. Bei fehlgeschlagenem Speichern bleiben die bisherigen Steuerungswerte aktiv. Status- und Konfliktmeldungen bleiben außerhalb des scrollbaren Bereichs sichtbar.

## Anschlüsse für die anderen Arbeitszweige

`core/input_preferences.gd` verwaltet die lokalen Einstellungen in `user://input_preferences.cfg`; sie gehören nicht zum Kampagnensnapshot. Die Datei enthält nur einfache Werte und zweistellige Listen von Tastencodes. Ungültige Belegungen fallen auf vollständige Standardbelegungen zurück; unbrauchbare Kamera-/FPS-Werte werden geprüft. Schreiben erfolgt zuerst in eine temporäre Datei, danach durch Umbenennen.

`DisplaySettings.input_preferences` besitzt den aktiven Zustand und `ui/frontend/controls_settings.gd` den verwerfbaren Entwurf. Die vorhandene Anzeigeeinstellungsdatei bleibt separat. `DisplaySettings.camera_motion()` wird vom vorhandenen Spielercontroller abgefragt; die unabhängigen Editor-/Planetenlaborkameras behalten ihre eigenen Kamerasysteme. `InputPreferences.binding_label(action)` ist der gemeinsame Anschluss für weitere dynamische HUD-Hinweise.

Gemeinsame Dateien beim späteren Zusammenführen: `core/display_settings.gd`, die beiden Spielercontroller, `ui/context_action_hud.gd`, `ui/creature_inspection_hud.gd` und `autoload/session_flow.gd`. Der Spielercontroller v2 benutzt für das Untersuchen jetzt die vorhandene InputMap-Aktion `inspection_mode` anstelle einer festen E-Abfrage. An Kreaturenwerten, Skilltree-Punkten, Journalinhalten, Welten und Sounds wurden keine Änderungen vorgenommen.

## Prüfung

Die Menügrundlage `e30e316` hat alle sechs GitHub-Workflows bestanden, einschließlich nativer Windows-/Linux-Ausgaben und beider Umgebungsrenderer.

Die neue Erweiterung besteht lokal den Einstellungsvertrag, den vollständigen Menüablauf und die bestehende Gameplay-Abnahme. Der Einstellungsvertrag prüft echte Dateispeicherung und Ersatz einer bestehenden Datei, aktive InputMap-Belegungen, FPS-Limit, Kameraachsen, Belegungskonflikte, reservierte Tasten, leere Aktionen, fehlgeschlagenes Schreiben und fehlerhafte Konfigurationswerte. Er läuft zusätzlich gegen das exportierte Paket.

Der Menüablauf benutzt tatsächliche Viewport-Eingaben für Tabwechsel, Slider, Belegung, Konfliktbehandlung, Abbruch und Standardrücksetzung. In der echten grafischen Ausführung wird zusätzlich die Rotation der aktiven Spielkamera nach Mausbewegung geprüft. Der Headless-Treiber kann keinen Cursor einfangen; dort wird diese eine Kamerainteraktion durch den separaten Rechenvertrag ergänzt.

Sieben echte Ansichten und die lokalen Resultate liegen unter `art/review/frontend/`. Die erneuten nativen CI-Prüfungen werden nach der Veröffentlichung im PR dokumentiert.
