# WEATHER-02B – Prüfnachweise

Quellcommit: `42d774a5c0b689a771f7eba20ef46a79159d93c6`

Tree: `d6168242f251bbd94962e371303b772074309469`

Basis: `d57b1ef385728728b132518a1ea05683888dcae0` / Spieltest-PR #125.

Godot `4.6.3.stable.official.7d41c59c4`, Linux/headless,
synthetische isolierte Nutzerdaten je Prüfung. Kein Windows-/Grafik-/FPS- oder
Vollintegrationsnachweis. Der Quellcommit enthält alle Funktionsänderungen;
der nachfolgende Commit ergänzt ausschließlich diese Nachweise.

[Unveränderte Rohlogs und Quellenmanifeste](validation-logs.tar.gz) ·
[SHA-256 des Archivs](validation-logs.tar.gz.sha256) ·
[Ergebnisse und exakte Quelldifferenzen](summary.json).

## Erfolgreiche Fachprüfungen

| Lauf | Erfolgreiche Tests |
|---|---|
| `qa-contracts` | `weather_model_test`, `regional_weather_test`, `body_identity_test`, `save_participants_test` |
| `qa-runtime` | `weather_runtime_test`, `spherical_campaign_contract_test`, `spherical_developed_migration_test`, `save_slots_test`, `campaign_atmosphere_test` |
| `qa-final` | `planet_climate_test`, `campaign_foundation_test` |

Elf verschiedene Tests bestanden. Import, Art-Quellprüfung und Vertrags-/Sprachgate
bestanden ebenfalls. Alle vier Läufe samt anfänglichen Fehlern bleiben im Archiv.
`qa-contracts` und `qa-runtime` wurden am veränderten Arbeitsstand ausgeführt;
ihre Berichte behaupten keine saubere Commitprüfung. Vollständige Dateimanifeste
belegen: Gegenüber `qa-final` änderten sich danach ausschließlich Dokumentation
und die aufgeführten Tests. Der gesamte Produktionscode ist seit `qa-contracts`
bytegleich. Der erweiterte Wetter-Laufzeittest ist seit `qa-runtime` unverändert.
`qa-final` lief am sauberen oben genannten Quellcommit mit stabilem Quellnachweis.

Der neue Klimatest prüft neue Heimatwelten, gleiche Seeds in verschiedenen
Systemen, Besuchsreihenfolge, historische Kampagnen ohne Herkunftsnachweis,
Wetterwirkungen aller Profile, Cube-Kanten, Prognosen, Slotkopien,
Flachwelt-Kugelkopie, fehlgeschlagene Writes sowie echte frische Prozesse für
normales Laden und gesperrte Zukunftsversionen. Original und Backup bleiben bei
unbekannten Profilen/Versionen bytegleich; Import verändert den Live-Zustand nicht.

Der bestehende Laufzeittest fährt zusätzlich über den tatsächlichen SessionFlow
von der Heimat zu einem synthetischen Vakuumziel und zurück, prüft Descriptor,
Snapshot, Prognose, einzigen Wetterbesitzer und einen gescheiterten Abflug-Write.
Seine bisherigen Prüfungen für Kamerawechsel, Pause, Rebase, Dach/Boden, Schnee,
Unterwasser und Reload bestehen weiterhin. Laufzeit: 53,494 Sekunden.

## Befehle

Gemeinsame Optionen: `--godot <Godot-4.6.3> --skip-main --output <neuer Ordner>`.

```sh
python3 tools/validate_godot.py --tests planet_climate_test weather_model_test regional_weather_test body_identity_test save_participants_test <gemeinsame Optionen>
python3 tools/validate_godot.py --tests planet_climate_test weather_runtime_test spherical_campaign_contract_test spherical_developed_migration_test save_slots_test campaign_atmosphere_test --skip-import <gemeinsame Optionen>
python3 tools/validate_godot.py --tests planet_climate_test campaign_foundation_test --skip-import <gemeinsame Optionen>
```

Die ausführbaren absoluten Originalbefehle stehen in den jeweiligen `results.json`.
Der Import wurde nur bei unverändertem importpflichtigem Ressourcenstand ausgelassen.

## Korrigierte Entwicklungsbefunde

- `qa-initial`: Compilerkonflikt mit der nativen `RefCounted.reference()`-Methode;
  Hilfsfunktion in `make_reference()` umbenannt. Nachfolgender Import erfolgreich.
- `qa-contracts`: Neuer Slotkopietest versuchte die Aktion während aktiver Sitzung.
  Test geht nun vor dem Kopieren in den dafür vorgesehenen inaktiven Zustand.
- `qa-runtime`: Derselbe Test nutzte noch einen freien Dateinamen außerhalb der
  regulären Slotpfade. Umstellung auf `user://voxelverse_save.json` innerhalb der
  isolierten Testdaten; anschließender Test mit echter Slotkopie erfolgreich.

Keine fehlgeschlagene Prüfung wurde als bestanden umgedeutet. Produktseitige
Slot-, Speicher- und Zukunftsschutzregeln wurden für Tests nicht gelockert.
