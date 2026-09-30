# Anschlüsse an Chat 1 · INT30-13

Basis: `2b1ac023db4074c2ce6b7db8fbab09ab929a8435`.

- Der enge `discovery_journal.gd`-Diff hängt ausschließlich `OwnedAnimalControls` in die bestehende Filterzeile, blendet sie im Tierregister ein und reicht das lesende gespeicherte Artverzeichnis weiter. Buchnavigation, Pause und Scanner bleiben unverändert. Die Zuordnungs-/Anschlussmeldungen stehen in #137; eine Antwort von Chat 1 wurde bisher nicht vorausgesetzt oder behauptet.
- Die 12 Nachrichten aus `localization-append.json` an `localization/catalog.json.messages` anhängen und bestehende Übersetzungserzeugung ausführen. Bis dahin liefert nur der eigene kleine Präsentationshelfer diese DE/EN-Texte; zentrale Kataloge haben Vorrang. Kein paralleler Gesamtkatalog im Fachbranch.
- **Kein neuer Registryeintrag:** `owned_animal_localization_test` ist bereits genau einmal unter `discovery_map` registriert. Der neue Fixturehelfer erweitert diesen bestehenden Test. Keine zusätzliche Test-ID oder zweite Registrierung ergänzen.
- Optionaler CI-Aufruf im vorhandenen Journal-/GUI-Job: `xvfb-run -a -s '-screen 0 1920x1080x24' python3 tools/review_int30_owned_animals.py --godot "$GODOT" --output "$RUNNER_TEMP/int30-owned-review"`; den Ordner als Artefakt hochladen. Dies ersetzt keine FULL-Gates. `.github` bleibt bei Chat 1.
- Der vorhandene `review_owned_animal_localization.py` behält seinen Vertrag von 20 Bildern. Nur der neue Helfer aktiviert `--browser-capture` und erwartet die sieben Zusatzansichten.
- D2-Host, Scanner (Chat 5), Verhalten (Chat 7), Dorfwirtschaft und SaveService (Chat 10) benötigen keinen Schreibanschluss. Dieselbe Host-Aktualisierung nach Laden bleibt maßgeblich.
