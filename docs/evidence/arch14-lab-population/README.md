# ARCH-14-LAB-POPULATION: gezielte lokale Abnahme

Ergebnis: fünf Godot-Fachprüfungen und eine native Backup-Wiederherstellung
bestanden. 388 erhaltene Tieridentitäten, höchstens vier aktive Tiere, 96
Tierdatensätze und 128 Trie-Seiten im Cache. Beim Neustart ist der Tiercache
zunächst leer. Das Backup enthält 1.172 Dateien mit 6.568.511 Bytes und wurde bei
entferntem Original-Ladepfad in einem separaten Benutzerverzeichnis geprüft.

| Geprüfter Quellcommit lokal | Identischer GitHub-Tree | Erfolgreicher Nachweis |
|---|---|---|
| `a1515e623a650b862b28f09d9e7ac7ef9dce24c0` | `69ad1beff45b2f1946f6011949cafffab5c083e0` | `living_planet_map_test`, `domestic_surface_runtime_test`, `surface_population_budget_test`; native Backup-Prüfung |
| `f58509f45b0181f5f08c164f62a7b688605d1a94` | `d37c15e64cc1342610692ab7dc71a968812d1f41` | `living_fauna_archive_test` |
| `f8a32838ae0867f823458fe1729309ab08189924` | `8438a25112c1535730ad2d46857a1582f8691539` | `living_planet_test` |

Die zweite Spalte nennt den GitHub-Commit mit demselben Tree wie die lokale Quelle;
vollständige Tree-SHAs stehen in `environment.json`. Alle Runtime-Implementierungen
sind seit `a1515e6` unverändert. Die Folgecommits korrigieren ausschließlich Tests
und Dokumentation. Alle drei Runner-Ergebnisse melden einen sauberen getrackten
Arbeitsstand. Die Uploads wurden durch Übereinstimmung der Git-Tree-SHAs geprüft.
Der Evidenzcommit fügt nur diese Dateien hinzu.

## Befehle und Wiederverwendung

Engine: Godot 4.6.3, `7d41c59c4`, Linux headless. Der Runner verwendet isolierte
Nutzerdaten. `$GODOT_BINARY` steht hier für den installierten Editor aus
`/workspace/scratch/391d67669cd0/godot-toolchain/editor/`.

```sh
python3 tools/validate_godot.py --godot "$GODOT_BINARY" --skip-main --tests living_fauna_archive_test --output /workspace/scratch/8bb39b18595a/check-lab-fauna-diagnostic
python3 tools/validate_godot.py --godot "$GODOT_BINARY" --skip-import --skip-main --tests living_fauna_archive_test living_planet_test living_planet_map_test domestic_surface_runtime_test surface_population_budget_test --output /workspace/scratch/8bb39b18595a/check-lab-fauna-final
python3 tools/validate_godot.py --godot "$GODOT_BINARY" --skip-import --skip-main --tests living_fauna_archive_test living_planet_test --output /workspace/scratch/8bb39b18595a/check-lab-fauna-corrected
python3 tools/validate_godot.py --godot "$GODOT_BINARY" --skip-import --skip-main --tests living_planet_test --output /workspace/scratch/8bb39b18595a/check-lab-living-final
GODOT_BINARY="$GODOT_BINARY" python3 -m unittest discover -s tests/tooling -p lab_fauna_backup_test.py -v
```

Der erste Lauf importierte den neuen Ressourcenbestand erfolgreich; das Importlog
liegt bei. Danach änderten sich keine Importressourcen. Bereits erfolgreiche
Fachprüfungen wurden nach reinen Änderungen anderer Tests nicht wiederholt.

Die rohen Ergebnisdateien bewahren auch frühere Fehlstände: Der erste Archivlauf
in `results-regressions.json` erfüllte seine Assertions, wurde aber wegen der
Engine-Fehlermeldung des absichtlich blockierten `mkdir` vom strengen Runner
abgelehnt. Der finale Fehlerfall blockiert die echte atomare temporäre Datei;
der FileAccess-Schreibfehler bleibt erhalten und erzeugt keine fremde
mkdir-Diagnose. `living_planet_test` verglich zunächst Zahlen im Manifest und in
kodierter Anatomie typstreng bzw. als JSON-Text; Godot liest JSON-Zahlen als
Floats (`8.0` gegenüber `8`). Der vorhandene rekursive native Vergleich prüft
jetzt Struktur und Werte; Körper-ID und Archivwurzel waren schon zuvor identisch.
Ein zusätzlicher Diagnose-Lauf zeigte genau diese Werteabweichung. Die beiliegenden
fünf Fachlogs enthalten jeweils den abschließenden erfolgreichen Lauf.

Die native Backup-Prüfung verwendet `--create-only` und `--verify-only` des
Archivtests. Diese beiden Ablaufzweige sind nach `a1515e6` unverändert; geändert
wurde dort nur der ausgelassene Fehlerzweig. Ihre Wiederverwendung ist damit
auf denselben tatsächlich ausgeführten Code beschränkt.

Keine Gesamtfreigabe, native Exportprüfung, Windows-Sichtprüfung oder FPS-Aussage.
Integration prüft ihren resultierenden Merge-Tree. Gemeinsame Ergänzungen in
`contracts.json`, `MODULE_CONTRACTS.md` und dem Backup-Workflow mit den übrigen
Fachbranches zusammenführen. `PROJECT_STATUS`, Rundenliste und zentrale
Backlog-Häkchen bleiben beim Integrationschat.
