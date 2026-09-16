# ARCH-25-TRIBAL-PLAYTEST – Stammeszeitalter ausprobieren

Basis: `1d6573d9551c3f24bf1dd6fa64e5c301583a26c8` aus
`agent/integration-vegetation-nest-20260915` (PR #110).
Fachbranch: `agent/arch25-tribal-playtest-20260915`.

## Bedienung

1. Hauptmenü → **Stammeszeitalter testen**.
2. **Testwelt vorbereiten** erzeugt einen eigenen Spielstand mit Seed 15838.
   Die vorhandene Kugelkampagne lädt Gelände, Heimat und zwei Gefährten.
3. **Jetzt ins Stammeszeitalter fortschreiten** bestätigt den normalen,
   gespeicherten Wechsel zur Übersicht mit drei Bewohnern.
4. Bewohner auswählen und Holz/Stein/Nahrung sammeln; anschließend Werkzeuge
   herstellen und das Dorf ausbauen. Speichern und Fortsetzen funktionieren
   über dieselben Menüs wie in anderen Kampagnen.

Zurück auf der Beschreibungsseite erzeugt keinen Spielstand. Abbruch der
Vorbereitung oder des Epochenfensters lässt die eigene Testwelt in Phase 0.
Sie bleibt spielbar; der normale Stammesknopf kann später erneut geöffnet werden.
Frühere Abenteuer stehen weiterhin unter **Spielstände** zur Verfügung.

## Anschluss und Umfang

`ui/frontend/main_menu.gd` enthält einen zusätzlichen Menüpunkt und seine
Beschreibungsseite. `ui/frontend/tribal_playtest.gd` lebt nur bis zur Übergabe
an das reguläre Epochenfenster. Es wartet auf `SessionFlow.world_started`,
Terrainkollision und die Heimatcontroller, legt den Heimatplatz über
`HomeGroupController.establish_home()` an und öffnet `TribePanel.open_confirmation()`.
Die Spielfigur erhält während der Vorbereitung keine Eingaben; Abbruch und
Aufräumen stellen ihren vorherigen Prozessmodus wieder her.

Der Launcher schreibt weder Phasenflags noch Fortschrittspunkte oder Dorfmodelle.
`SaveGameService` erzeugt den getrennten Slot und führt den vorhandenen atomaren
Epochenwechsel aus. Normales Fortsetzen startet die Vorbereitung nicht nochmals.
Ein Doppelklick kann keine zweite Vorbereitung starten. Fehler beim Laden
beenden den Launcher; ein nicht vorbereitbarer Heimatplatz bietet den Wechsel
zur Kreaturensteuerung mit einem konkreten Hinweis an.

Die vom Nutzer belegten ARCH-13/-17/-24/-26/-27 bleiben unberührt. Es gibt keine
Änderungen an `SessionFlow`, Terrain, Speicherverträgen oder Dorfwirtschaft.
Gemeinsame Anschlussdateien bei Integration: Hauptmenü, Sprachkatalog plus
generierte PO-Dateien, Testregister. Neue Texte sind auf Deutsch und Englisch
vorhanden. Zentrale Statuslisten aktualisiert der Integrationschat.

## Gezielte Prüfung

Godot 4.6.3, Headless, je Prüfung isolierte Nutzerdaten. Fachauswahl:

```sh
python3 tools/validate_godot.py --godot "$GODOT" \
  --tests tribal_playtest_test phase_handoff_test frontend_test localization_test \
  --skip-main
```

`tribal_playtest_test` bedient den öffentlichen Hauptmenüpfad, prüft Abbruch,
einen unveränderten fremden Slot, bestätigte Gruppensteuerung, echte Holzlieferung
und die Wiederaufnahme in einem frischen Prozess. `phase_handoff_test` deckt die
unverändert verwendete Übergabe einschließlich Schreibfehler/Rollback,
abgelaufener Bestätigung, Identitätserhalt und gesperrter Folgeepochen ab.
Hauptmenü und Katalogprüfung sichern die direkten Verbraucher.

Exakter Prüfstand und Ergebnisse stehen in der PR-Übergabe. Kein neuer vollständiger
Integrationstest, nativer Windows-Export oder Ziel-PC-Grafik-/FPS-Nachweis.
