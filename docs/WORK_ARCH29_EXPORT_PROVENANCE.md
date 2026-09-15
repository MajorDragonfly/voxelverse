# ARCH-29-EXPORT-PROVENANCE: Herkunft nativer Prüfpakete

Feste Basis: `365c402d4e5635c024e96f4299e8b85561c35cd0`, veröffentlichter PR #120.
Branch: `agent/arch29-export-provenance-3e3efb2408e2`.
Dieser Folgeauftrag benötigt `SourceRun` aus #120 und erweitert ausschließlich
`validate_export.py`, eigene Python-Tests und diese Fachübergabe.

## Problem und Lieferung

Der Exportprüfer erfasste bisher nur einen Commit vor dem Export. Zwischen
Import, Erstellung des PCK und den später aus dem Checkout kopierten
Prüfskripten konnten sich Quellen ändern. Ein veröffentlichbares ZIP und seine
`BUILD_INFO.json` konnten dadurch eine irreführende gemeinsame Herkunft nennen.
Frühe Enginefehler hatten zudem noch keinen vollständigen Ergebnisbericht.

Der Exportprüfer verwendet jetzt dieselbe `SourceRun`-Implementierung wie der
Godot-Quellprüfer. Er erfasst den Anfang vor dem Engineaufruf, beobachtet vor
und nach jedem Prüfprozess und liest vor der Paketerstellung und am Ende alle
Dateien erneut. Unerwartete Änderungen stoppen folgende Prozesse. Die bereits
vorhandene Ausnahme für eng begrenzte Importvorbereitung wird übernommen:
neue gültige UIDs und identische Importdescriptor-Neuschreibungen bleiben
sichtbar; sie werden nicht als Quelländerung verschwiegen.

| Nachweis | Bedeutung |
|---|---|
| `results.json.source` | Ursprünglicher Commit, Tree und tatsächlicher Dateifingerprint. |
| `results.json.export_source` | Tatsächlicher Stand nach dem erfolgreichen Release-Export, einschließlich dokumentierter Importvorbereitung. |
| `results.json.provenance` | Start, Ende, Zwischenbeobachtungen, Änderungen und Verweise auf die vollständigen Dateimanifeste. |
| Prüfeinträge | Befehl, Log-Hash, Prozess-Exitcode, `process_passed`, Quellstatus und daraus abgeleitetes `passed`. |
| `BUILD_INFO.json` im ZIP | Ursprüngliche Quelle, Exportquelle und Stand am Ende der Paketprüfungen; zusätzlich, ob die Quellinventare vollständig abgedeckt sind. |
| `run-start.json` und `source-files-start.jsonl` | Früher, exklusiv angelegter Startnachweis, auch ohne abschließenden erfolgreichen Lauf. |

Ein zunächst unter `.zip.pending` erzeugtes Archiv wird erst nach der letzten
Quellprüfung unter seinem regulären ZIP-Namen bereitgestellt. Fehler oder eine
späte Quellenänderung hinterlassen keinen erfolgreichen ZIP-/Checksum-Nachweis.
Wenn das Schreiben der Prüfsumme fehlschlägt, wird auch das gerade erzeugte ZIP
wieder entfernt. Der Ergebnisbericht wird atomar ersetzt und bewahrt die
Fehlerdiagnose. Timeout, Unterbrechung und falsche Engineversion behalten
Start-/Endnachweise; `provenance.reusable` bleibt bei fehlgeschlagener Abnahme
ausdrücklich `false`.

## Verwendung und Grenzen

```sh
python3 tools/validate_export.py --godot /pfad/zu/godot \
  --platform linux --output ../export-pruefung
```

Ausgaben benötigen einen neuen oder leeren Ordner außerhalb des Checkouts.
Ein exklusiver Besitzmarker verhindert zwei Schreiber im selben Ausgabeordner.
`--skip-import` behält seine bisherige Voraussetzung eines bereits erfolgreich
importierten Ressourcenstands. Die nativen Zielplattformregeln, Testauswahl und
isolierten Spielstände bleiben erhalten. Neue Spiel-/Godot-Tests oder Änderungen
an der zentralen Testregistry sind für diesen Werkzeuganschluss nicht nötig.

Es handelt sich um Beobachtungen an Prozessgrenzen, keine Dateisystemsperre.
Die Grenzen von `SourceRun` aus #120 gelten auch hier, insbesondere für
ignorierte Dateien, externe Symlinkziele und Submodule. Ein Exportnachweis
ersetzt keine Grafik-, Windows- oder Ziel-PC-Abnahme.

Die eigenen Regressionen benutzen reale temporäre Git-Repositories und reale
Python-Unterprozesse als ausdrücklich simulierte Engine-/Paketprozesse. Die
komplette Exportsteuerung samt Archiv, Build-Information und Prüfsumme wird
ausgeführt; die Fixture-Dateien sind keine echten Godot-PCKs oder nativen
Spielprogramme. Diese Tests beanspruchen daher keinen vollständigen nativen
Voxelverse-Export. Die Integration führt ihre bestehende native Abnahme auf
dem tatsächlich zusammengeführten Quellstand aus.

Fachnachweis: [`evidence/arch29-export-provenance/README.md`](evidence/arch29-export-provenance/README.md).
