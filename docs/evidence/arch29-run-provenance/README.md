# ARCH-29-RUN-PROVENANCE – Prüfnachweis

Datum: 2026-09-15. Basis: `1d6573d9551c3f24bf1dd6fa64e5c301583a26c8`.

| Stand | Identität |
|---|---|
| Lokal geprüfter Quellcommit | `daa26abeb4f54ea09c47d226e5606905b9ad456f` |
| Veröffentlichter Quellcommit | `19b85484725203c10314386205092da90335f30c` |
| Identischer Quell-Tree beider Commits | `b938ca9cbfef669214b4a9c6e20f06c68ec511ba` |
| Tatsächliche Quellen zu Laufbeginn | `b43b52a7ce2324789307396db33fc43461c8805edd6f547087aef8da802427c1` |
| Vorbereitete Quellen nach Import / zum Ende | `8137a359b3bb5b7da48f2be98707a4089910d57d6366497a5e7f9560a890cb29` |

Die GitHub-Veröffentlichung vergibt eine andere Commit-ID. Ihr Tree wurde exakt
gegen den lokal geprüften Tree verglichen; die Rohprotokolle bleiben unverändert.
Dieser nachfolgende Nachweiscommit ergänzt ausschließlich Dokumentation/Logs.

## Ausgeführte Prüfungen

```sh
python3 -m unittest discover -s tests/tooling -p 'validation*_test.py' -v

python3 tools/validate_godot.py \
  --godot /workspace/scratch/d2f8e8a15ebb/godot-toolchain/editor/Godot_v4.6.3-stable_linux.x86_64 \
  --tests performance_measurement_test --skip-main \
  --output /workspace/scratch/250f45df1002/provenance-verified-cold-run
```

- **51 Python-Tests bestanden**, 4,139 s. Reale temporäre Git-Repositories und
  Worktrees: saubere/schmutzige Quellen, Staging, Commitwechsel, neue/gelöschte/
  umbenannte Dateien, Ausführbarkeit, wiederhergestellte Inhalte, Änderungen
  während der Inventarisierung, UID-/Importausnahmen, Konflikte und Budgets.
  Runner-Fehlerfälle verwenden ausdrücklich einen simulierten Prüfprozess:
  Quelländerungen trotz Prozess-Pass, späte Änderungen, Timeout, Unterbrechung,
  überholte Auswahl und Schutz bestehender Ausgaben.
- **Godot 4.6.3.stable.official.7d41c59c4**, Linux x86_64, Python 3.12.14,
  isolierte Nutzerdaten je Prozess. Quellgate, frischer Import, Art-Quellgate und
  echter `performance_measurement_test` bestanden; Quellenintegrität bestanden.
- Start auf sauberem Git-Stand, 2.834 erfasste Dateien / 93.992.512 Bytes.
  Der Import erzeugte 184 UIDs und schrieb 245 `.import`-Dateien mit identischen
  Bytes neu. Alle 429 Vorgänge sind im Bericht erfasst. Git-Commit, Tree und
  Index blieben unverändert. Anschließend und am Laufende keine Änderungen.
- Vollständige Erfassung zu Beginn 0,2834 s, vollständiges erneutes Hashen am
  Ende 0,2729 s. Zwischenbeobachtungen 0,1255–0,1538 s; ohne Dateiberührung
  keine erneut gehashten Bytes. Einzelmessung dieser Maschine, kein allgemeiner
  Performance-Nachweis.

Der erste Entwicklungsversuch erkannte Godots identische Import-Neuschreibungen
noch als Quellenänderung und brach nach dem Import korrekt ohne Pass ab. Die
eng begrenzte Importausnahme wurde ergänzt und mit einem neu aufgebauten Import-
Cache erneut geprüft. Der hier archivierte erfolgreiche Lauf ist dieser Nachlauf.

## Rohdaten und Grenzen

[validation-logs.tar.gz](validation-logs.tar.gz) enthält Python-Ausgabe sowie den
vollständigen Godot-Berichtsordner mit Prozesslogs, Vertragsbericht, Startdatensatz,
Endergebnis und beiden Dateimanifesten.

SHA-256 des Archivs:
`f4ac8100a10c99759fe8bc3a4fc4e315a27be828bbc1e8f17a8b5c0a71779f6c`.

Die unversionierten UIDs wurden erst nach Abschluss der protokollierten Läufe
entfernt; die Manifeste behalten den tatsächlich geprüften vorbereiteten Stand.
Keine volle Spielsuite, Exporte, Windows- oder Grafikabnahme. Die CI des neuen
PRs ist gesondert zu beurteilen. Der Integrationsbasis-PR #110 meldete bereits
einen eigenständigen Linux-Frontend-Importabsturz (Exit 139); dieser lokale
erfolgreiche Lauf klärt dessen Ursache nicht.
