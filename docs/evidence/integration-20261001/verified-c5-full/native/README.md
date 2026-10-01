# Native Nachweise für c5c22efd

Festgelegt auf veröffentlichten Head `c5c22efde7d220169190710037da4f4f12666f02`, Tree `667d4c8963137da3b8c2703f33868e120080b850`, tatsächlichen CI-Merge `33dcc46fa0b2ae7ab6e8dbe4fa1c9a10c2f43cd5` und Source-SHA256 `93f1ff89616f442b042f343dee55b42b0dd5293f980dae89585e0197831b0bec`.

| Workflow | Run | Tatsächliches Ergebnis |
| --- | --- | --- |
| Acht Featureflows | [36832634339](https://github.com/MajorDragonfly/voxelverse/actions/runs/36832634339) | 8/8 Jobs erfolgreich, 138 PNGs |
| Gebäudeeditor | [36832634316](https://github.com/MajorDragonfly/voxelverse/actions/runs/36832634316) | 569 GUI- und zwei Neustartprüfungen, 7 PNGs |
| Community-Galerie | [36832634512](https://github.com/MajorDragonfly/voxelverse/actions/runs/36832634512) | Erfolgreich, 45 PNGs |
| Audio-Einstellungen | [36832634659](https://github.com/MajorDragonfly/voxelverse/actions/runs/36832634659) | Erfolgreich, 12 PNGs |

Insgesamt sind **11 tatsächliche erfolgreiche Jobs und 202 neue PNG-Nachweise** vorhanden. Alle Artefakt-ZIP-SHA256 und API-Head-Identitäten wurden geprüft. Quellenmanifeste sind vollständig, sauber und unverändert; der Sourcehash wird aus **5.448** Dateieinträgen neu berechnet. Die gesamte Gebäudeeditor-Hashkarte entspricht diesem gemeinsamen Manifest. Der Appearance-Helfer verwendet weiterhin den festen Vorläufer `0ab9d20b0f448864c6e104c093b3ce97532e95e5` und stellt den aktuellen kombinierten Tree wieder her. Die Gebäude-/Feature-Workflows und Gebäude-/Vorlagenhelfer entsprechen nach Dateihash unverändert dem zuvor geprüften 74bb-Stand; keine Budgets wurden geändert.

Triggerbeleg: Der verwendete GitHub-Endpunkt für Commit-Workflows filtert laut seiner dokumentierten Schnittstelle auf Pull-Request-Runs und lieferte diese vier Runs für exakt c5c22efd. Keine Retries wurden ausgelöst. Konkrete Job-/Artefakt-IDs sowie unveränderte Rohresultate, Logs und Start-/Endmanifeste liegen im gzip-Archiv. Die technischen Bildprüfungen bestätigen Dateihashes, Dekodierbarkeit und Dimensionen; **es wird keine visuelle Prüfung aller 202 Bilder behauptet**. Originale PNGs bleiben in den GitHub-Artefakten und werden nicht in dieses Paket kopiert.

`evidence.json` enthält die kompakten Fakten und Archiv-SHA256. `latest-c5c2/all-native-verification.json` enthält die terminale Ergebnisübersicht. `raw-results.tar.gz` bewahrt die exakten Rohbytes dedupliziert nach SHA256 sowie den Index aller 202 PNG-Hashes/-Dimensionen. Offline prüfen:

```sh
python3 verify.py
```

Dieser Nachweis betrifft ausschließlich die genannten nativen Workflows. Die festen 74bb-Native-/FULL-Pakete bleiben separate historische Referenzen. Daraus werden keine neue FULL-, Ziel-PC-, fertige-Hütte- oder vollständige deutsche UI-Abnahme abgeleitet. Es wurden keine Repository-Dateien geändert, keine Veröffentlichung vorgenommen und keine lokalen Renderingläufe wiederholt.
