# ARCH-29-EXPORT-PROVENANCE: Fachnachweis

15. September 2026; eigener Folgeauftrag auf PR #120.
Feste Basis: `365c402d4e5635c024e96f4299e8b85561c35cd0`.

Lokal geprüft: `d9ca33bbc76f876426a409bbdb469ff318ced8df`.
Veröffentlichter Quellcommit: `5b9907089e0a51569522001d978afa0ce03957e1`.
Beide besitzen den ausdrücklich verglichenen Tree
`cbab04e09f8a09f3576df083535f783c37916824`.
Der nachfolgende Commit ergänzt ausschließlich diese Nachweise; der Bericht
behält seine tatsächlich geprüfte lokale Revision.

| Prüfung | Ergebnis |
|---|---|
| Neue Exportsteuerungs-Regressionen | 13 bestanden. Reale Git-Repositories und Python-Unterprozesse als ausdrücklich simulierte Engine-/Paketprozesse. |
| Bestehende Vertrags-, Auswahl- und Provenienzprüfungen | 51 bestanden. |
| Reales Quell-/Sprachgate des Projekts | Bestanden: 180 registrierte Godot-Tests, 17 Verträge, 1285 Sprachschlüssel. Die registrierten Godot-Tests wurden hier nicht ausgeführt. |
| Prüflauf selbst | Sauberer Start und sauberes Ende, Commit/Tree/Index und SHA-256 der Quelldateien unverändert. |

Die Exportfälle umfassen den vollständigen Steuerungsweg bis zum ZIP mit
Build-Information und SHA-256, zulässige Import-UIDs, einen Commit während des
Exports, Änderungen während Pakettests, Änderung/Wiederherstellung, späte
Änderungen nach Archiverstellung, Timeout, Unterbrechung, falsche Engineversion,
fehlende Git-Herkunft, geschützte Ausgabeordner und Fehler beim Schreiben der
Prüfsumme. Erfolgreiche Prozessresultate bleiben auch bei ungültiger
Quellzuordnung gesondert erkennbar; ein ungültiges Paket wird nicht freigegeben.

Die Tests erzeugen bewusst kleine **Fixture-Dateien statt echter nativer
Spielprogramme oder Godot-PCKs**. Das prüft die geänderte Werkzeuglogik und
behauptet keine native Voxelverse-, Gameplay-, Grafik-, Windows- oder
Ziel-PC-Abnahme. Die unveränderte vollständige Exportmatrix bleibt eine Aufgabe
der Integration auf ihrem tatsächlichen Merge-Tree.

[Ergebnis mit exakten Befehlen, Umgebung und Quellenbeobachtungen](results.json)
und [Zuordnung/Dateihashes](manifest.json) sind direkt lesbar.
[Unveränderte Rohprotokolle und vollständige Quellinventare](validation-logs.tar.gz)
enthalten `export-regressions.log`, `validation-regressions.log`,
`source-contracts.log`, `contracts.json`, `run-start.json`, `results.json` sowie
beide `source-files-*.jsonl`-Manifeste.

Schreibbereich dieses Pakets: ausschließlich `tools/validate_export.py`, der
neue Exporttest und die eigene Dokumentation. `SourceRun`, `validate_godot.py`,
Gameplay, Speicher, Registry und zentrale Statusdateien werden nicht geändert.
Der Entwurfs-PR ist auf #120 gestapelt; dessen Integration muss vor diesem
Anschluss erfolgen.
