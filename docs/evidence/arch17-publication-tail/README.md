# Prüfnachweise ARCH-17-PUBLISH-TAIL

[Paketübergabe](../../WORK_ARCH17_PUBLICATION_TAIL.md)

| Datei/Verzeichnis | Bedeutung |
|---|---|
| `acceptance.json` | Anerkannte Fachnachweise, konkrete Abschlussmeldungen und verworfener unvollständiger Erstversuch |
| `comparison.json` | Quellen und Mediane der drei Basis-/Kandidatenläufe |
| `baseline-1` bis `baseline-3` | Unverändertes Terrain, gleiche ergänzte Messroute; Rohlog, Aufruf, Hashes und Ergebnis |
| `candidate-1` bis `candidate-3` | Optimiertes Terrain auf sauberem `6dcddc0`; identischer Messcode |
| `baseline-diagnosis` | Frühe Engpassdiagnose auf Integrationsbasis mit erster Instrumentierung; vom Dreiervergleich ausgeschlossen |
| `import` | Erfolgreicher Import desselben lokalen Ressourcenstands sowie Quell-/Art-Gates |
| `fachtests` | Erster Fachlauf auf `6dcddc0`; adaptive und große Planeten anerkannt, Kampagnentest ohne Abschlussmarker nicht anerkannt |
| `lookahead-completion` | Erfolgreicher Kampagnennachlauf auf `2569690`, vollständiger Marker und 520 Bestandsprüfungen |
| `change-plan.json` | Unveränderter konservativer Diffplan; keine Testausführung |
| `validation-scope.json` | Begründung für abgegrenzte Fachtests und Importwiederverwendung |
| `executed_probe_runner.py` | Unverändert ausgeführter isolierender Messrunner; originale lokale Pfade |

Die Quellcommits und Dateihashes sind Prüfidentitäten. Ein nachfolgender Commit
ergänzt ausschließlich diese Nachweise und Übergabetexte. Godot erzeugte beim
Import lokale `.gd.uid`-Metadaten; ungetrackte generierte UIDs wurden nur im
lokalen Git-Ausschluss geführt, bestehende getrackte UIDs bleiben unverändert.

Die Ergebnisse sind Linux-/Headless-Fachnachweise. Keine Freigabe für den
gesamten Integrationsbaum, native Exporte, Grafikqualität oder Ziel-PC-FPS.
