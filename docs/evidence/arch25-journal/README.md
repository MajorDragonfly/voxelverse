# Prüfnachweise ARCH-25-JOURNAL

Godot **4.6.3.stable.official.7d41c59c4**, Linux, isolierte synthetische
Benutzerdaten. [Befehle und Bedienung](../../WORK_ARCH25_JOURNAL.md).
Genaue Trees und SHA-256 der abschließenden Quelldateien: [Manifest](results.json).

| Quellcommit | Prüfung | Ergebnis |
|---|---|---|
| `e1e01a1` | Sieben Fachtests und Quellgates | Bestanden: [headless/results.json](headless/results.json) |
| `ac64277` | Nach leerer Überschrift-/Testaufbaukorrektur: Sprachtest, Buch und Tierregister | Drei Fachtests bestanden: [layout-final/results.json](layout-final/results.json) |
| `ac64277` mit ausschließlich dokumentiertem Textdelta | Echte grafische Matrix, DE/EN, drei Größen, 100/150 %, fünf Reiter + Vergleich | 72 Kombinationen, 18 Aufnahmen und 653 protokollierte Sprach-/Layoutprüfungen bestanden: [render/results.json](render/results.json) |

Der Grafikbericht meldet korrekt `dirty=true`: Während der Prüfung wurde eine
Zeile im Übergabedokument präzisiert. Der vollständige Unterschied steht in
[render-docs-delta.patch](render-docs-delta.patch). Spielcode und Tests blieben
unverändert. Der Ressourcenimport war zuvor erfolgreich; es kamen keine neuen
Grafik-/Audiodateien oder importpflichtigen Spielressourcen hinzu.

Der Sprachtest erweitert die vorhandene Artenvergleichsprüfung. Ihre echten
GUI-Aktionen, atomaren Speicherfehler, Rücknahme, Save/Load und Modellfreigabe
laufen ebenfalls. Die Buch-/Pagingtests prüfen zusätzlich echte Prozessneustarts.
Es werden weder Punktvergabe noch Besitz- oder Speicherregeln übersetzt.

Sechs repräsentative der 18 Aufnahmen sind beigefügt. Visuell geprüft wurden
insbesondere das englische Teilebuch und der Vergleich bei 800×600/150 %, das
deutsche Forschungsziel bei 800×600/150 % und der Vergleich bei 1920×1080/100 %.
Die Namen `Entdeckungsbuch {name}` und `Schließen {world}` sind absichtliche
Prüfdaten und müssen auch in der englischen Ansicht wörtlich erhalten bleiben.

| Ansicht | Aufnahme |
|---|---|
| Teile, EN, klein/große Schrift | [PNG](render/journal-en-800x600-150-tab1.png) |
| Forschung, DE, klein/große Schrift | [PNG](render/journal-de-800x600-150-tab4.png) |
| Vergleich, EN, 1080p | [PNG](render/journal-en-1920x1080-100-compare.png) |
| Vergleich, EN, klein/große Schrift | [PNG](render/journal-en-800x600-150-compare.png) |
| Anleitung, EN, klein/große Schrift | [PNG](render/journal-en-800x600-150-tab3.png) |
| Arten, DE, 1080p | [PNG](render/journal-de-1920x1080-100-tab0.png) |

Anfängliche Fehler bleiben unter `development/` nachvollziehbar: zu wenig Platz
im kleinen Teile-Reiter und ein Messaufbau, der parallele Miniaturzugriffe dem
Sprachwechsel zurechnete. Beide sind korrigiert; keine fehlgeschlagene Prüfung
wurde als bestanden umgedeutet.

Kein Windows-Export, gemeinsamer Kampagnenkandidat oder Ziel-PC-/FPS-Nachweis.
Die abschließenden Evidenz-/Übergabecommits ändern keinen Spielcode.

Die Veröffentlichung über die GitHub-App erzeugt neue Commit-IDs. Die jeweiligen
Git-Trees wurden auf exakte Übereinstimmung geprüft; die Testberichte behalten
ihre tatsächlich geprüften lokalen Referenzen.

| Lokaler Quellcommit | Veröffentlichter Commit | Identischer Tree |
|---|---|---|
| `e1e01a160df4a68e1a82ac3c830d112d3cd5e169` | `65d17448315082aed5a2744bda99a8cbd84f7ccf` | `5f35123bc55af5ffa242b548903254aa6c65da9c` |
| `ac64277491523dab590b3487a105875647db0974` | `d1e8dc2f412e83abd9cc9a07b9e3042bc9db0016` | `0a3438fe5020bfe536b2f88cb67dd7dddc0b3688` |
