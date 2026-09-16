# Nachweis ARCH-30-SHIP-INSTANCES

Basis: `d57b1ef385728728b132518a1ea05683888dcae0` / PR #125.
Endgültiger Quellcommit: `843aa6858b8465a3e1df6d5b7e97c9be0aebab6b`.
Quell-Tree: `de54b7c8196c97540a1606e5d11b8c1b8cffd75b`.
Godot `4.6.3.stable.official.7d41c59c4`, Linux, isolierte Benutzerdaten.

## Prüfungen

- `final/`: sauberer, unveränderter Quellcommit. Gemeinsames Quellgate und
  `fleet_runtime_test` mit 83 Prüfpunkten bestanden (4,383 s). Enthält echten
  SaveService, Schreibfehler/Rollback/Original-/Backupbytes, neue Prozesse,
  feste Pins ohne Autorenoriginale, zwei Revisionen, Hangarbelegung, Fracht,
  Zukunftsschutz, große Double-Positionen, Kopien, Hauptmenü und DE/EN.
- `consumers/`: alle sieben ausgewählten Tests bestanden: Flotte, historischer
  Expeditionsvertrag, Schiffswerft, SaveParticipants, SaveSlots, Frontend und
  Lokalisierung. Geprüfter Arbeitsbaum vor dem Quellcommit, exakte Fingerprints
  in den komprimierten Quellmanifesten; Quellen blieben während des Laufs gleich.
  Danach geändert: zusätzlicher Typguard für den Flotten-Befehlsnamen,
  übersetzte Werft-Schaltfläche und Fachdokumentation. Der endgültige Flottentest
  prüft diesen Anschluss erneut. Kein zweiter Voll-Frontendlauf behauptet.
- `native/`: derselbe saubere Quellcommit, OpenGL-Kompatibilität, Xvfb/Mesa,
  derselbe vollständige Flottentest mit echten UI-Aktionen und Neustart bestanden.
  `fleet-de.png` bei 1280 × 900 wurde visuell geprüft: Texte/Listen/Aktionen
  sichtbar, keine Überschneidung oder abgeschnittene Bedienung.
- Initialer Godot-Import und Art-/Quellgates bestanden; PO-Ressourcen nach
  Ergänzung der 40 Sprachschlüssel erneut importiert. Spätere Läufe verwenden
  denselben Ressourcenstand und daher `--skip-import`.

Befehle (vollständige aufgelöste Aufrufe jeweils in `results.json`):

```sh
python3 tools/validate_godot.py --godot /pfad/godot --skip-main --skip-import \
  --tests fleet_runtime_test expedition_contract_test shipyard_test \
  save_participants_test save_slots_test frontend_test localization_test \
  --output /tmp/flotte-verbraucher
python3 tools/validate_godot.py --godot /pfad/godot --skip-main --skip-import \
  --tests fleet_runtime_test --output /tmp/flotte-final
# Mit vorhandenem Display und isolierten Nutzer-/Konfigurationsverzeichnissen:
godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --script res://tests/fleet_runtime_test.gd -- --capture /tmp/flotte.png
```

## Korrigierte Anfangsbefunde

- `initial-pin-keys/`: Modulautoren verwenden intern StringName-Schlüssel.
  Pins werden jetzt ausdrücklich als vollständige JSON-Payload kanonisiert,
  bevor der streng begrenzte Kampagnenvertrag sie annimmt.
- `initial-pin-numbers/`: JSON liest Ganzzahlen als Double. Fähigkeitsvergleich
  verwendet den gemeinsamen präzisen Writer/Reader, ohne Werte zu runden.
- `initial-test-oracles/`: Das 60-m-Array-Orakel verlangte Ints statt der
  vorhandenen Float-Komponenten; die Frachtgrenzen-Fixture fügte versehentlich
  einen StringName-Schlüssel ein. Beide Prüfungen korrigiert, Funktionsgrenzen
  unverändert. Anschließend alle Fach-/Verbrauchertests bestanden.
- `display-startup/`: Erster Grafikaufruf erreichte seinen X-Server nicht und
  startete keinen Spieltest. Server und Godot wurden danach im selben
  Ausführungskontext gestartet. Das erfolgreiche native Ergebnis steht separat.

Rohprotokolle bleiben erhalten; erwartete absichtlich ausgelöste Save-Warnungen
sind keine gelöschten Befunde. Die Nachweisergänzung nach dem Quellcommit enthält
nur diese Dateien. Keine Vollsuite-, Windows-, Export-, Ziel-PC- oder FPS-Abnahme.
