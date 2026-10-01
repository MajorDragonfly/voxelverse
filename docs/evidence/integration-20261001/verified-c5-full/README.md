# Historischer FULL-CI-Stand c5c22efd

Die Belege sind offline vollständig geprüft. **Die technische FULL-Abnahme ist fehlgeschlagen:** Windows stoppt im echten Release-PCK-Test `packaged_tribal_age_test`. Dieser Receipt dokumentiert das ursprüngliche Ergebnis und ersetzt keine Fehler durch grüne Vorläufer oder Wiederholungen.

Festgelegt auf PR #245, HEAD `c5c22efde7d220169190710037da4f4f12666f02`, tatsächlichen CI-Merge `33dcc46fa0b2ae7ab6e8dbe4fa1c9a10c2f43cd5`, sauberen Tree `667d4c8963137da3b8c2703f33868e120080b850` und Source-SHA256 `93f1ff89616f442b042f343dee55b42b0dd5293f980dae89585e0197831b0bec`.

| Pflicht-Gate | Run-ID | Job-ID | Tatsächlicher Abschluss |
|---|---:|---:|---|
| Godot validation gate | 36832634517 | 110293735630 | success |
| Desktop export gate | 36832634623 | 110287612481 | failure |
| Environment render gate | 36832634422 | 110280683747 | success |
| Project dashboard gate | 36832634830 | 110272524775 | success |

Der FULL-Plan registriert und wählt 266 Tests. Alle **266 wurden tatsächlich erfolgreich ausgeführt**, verteilt auf 67/67/66/66 ohne Überschneidung oder fehlende Tests. Runtime besteht 27/27 Prüfungen. Environment besteht alle acht tatsächlichen Render-Schritte; deren acht Artefakte gehören exakt zu diesem HEAD. Das eingebettete separate native Paket bestätigt acht Featureflows plus Gebäude/Galerie/Audio: elf erfolgreiche Jobs und 202 technisch geprüfte PNG-Hash-/Dimensionsnachweise. Es enthält keine PNG-Bytes und beansprucht keine Sichtprüfung aller Bilder.

Linux besteht 41/41 Prüfungen und drei Release-PCK-Probes. Sein akzeptiertes inneres Paket `voxelverse-linux-x86_64.zip` hat 35.479.118 Bytes und SHA256 `a4f9826cd4a3afbbea5ada765ee83f653d44e84584e7fbf1e22f0251b9706f70`. Das äußere GitHub-Build-Artefakt `11149432305` hat 35.445.796 Bytes und API-ZIP-SHA256 `42b35a0d2c45bab0d6fcbb3f964a17b914b5572adfeff78588532d9ecf337c3f`. Die unterschiedlichen inneren/äußeren ZIP-Bytes wurden nicht erneut heruntergeladen.

Windows-Job `110272913322` endet wirklich rot: 26 Ergebnisrecords, davon 25 erfolgreich; ein Fehler, **null Probes, kein akzeptiertes Paket**, `complete=false`, `reusable=false`. `packaged_tribal_age_test` endet nach 108,063 Sekunden mit Exit1. Erste konkrete Assertion unmittelbar nach `TRIBAL_STAGE: 03_transport`:

```text
TRIBAL_CHECK_FAILED: Cannot open the action's tab.
```

Danach fehlen `Order_tool`, das gefertigte Werkzeug, Hutsite/Unterkunft und vier Schlafplätze; der Load-Nachweis meldet wiederholte fertige Arbeit. Das Original-Einzeltestlog liegt unter `original-logs/ci245-final-c5-packaged_tribal_age_test.log`, SHA256 `7d1d73d4de702bbad86e5c2e92ad29582ea2e03495fae82645b218ea335f398c`. Der vollständige ursprüngliche Runnerlog und das unveränderte Windows-Diagnose-ZIP sind ebenfalls erhalten.

Die portable `verification.json` nennt alle konkreten Gate-/Run-/Job-/Artefaktidentitäten und Roh-ZIP-Digests. **369 tatsächliche Source-/Runtime-/Export-Logdigests** wurden aus den vorhandenen Payloads neu gezählt und einzeln gegen die deklarierte SHA256 geprüft; die abgebrochenen Windows-Folgeprüfungen werden nicht mitgezählt. Alle echten Source-/Runtime-Start-/End-Manifeste sind bytegleich, SHA256 `04291522dd39f36e5c333b3bf9066856e09ec4347af9bec107959479742203ca`. Der vollständige Sourcehash wurde zusätzlich aus allen 5.448 Manifestzeilen neu berechnet. Sämtliche Ergebnisprovenienzen melden den gleichen vollständigen, sauberen Merge/Tree/Sourcezustand.

Die Export-Diagnose-ZIPs lassen Manifest-Payloads weg; deren deklarierte Digests wurden mit den tatsächlich erhaltenen Source-/Runtime-Payloads verglichen. Environment-Captures wurden hier anhand der tatsächlichen erfolgreichen Schritte und Artefaktmetadaten geprüft, nicht anhand heruntergeladener Render-ZIPs. `exact-head-query.json` bewahrt Anfrage und Antwort des finalen commitgefilterten Workflow-Snapshots. Der Connector liefert nur die erste Seite der PR-Läufe und lässt `head_sha` in Workflow-Zeilen weg; die konkrete Anfrage und unabhängigen Artefaktmetadaten belegen die Zugehörigkeit.

Offline prüfen, ohne Netzwerk, Godot oder einen neuen CI-Lauf:

```sh
python3 verify.py
```

Die Prüfung bestätigt die Integrität des **negativen** Receipts; `evidence_verified=true` bedeutet keine Abnahme. `full_technical_acceptance=false` bleibt bestehen. Das eingebettete native Paket wird separat durch seinen ursprünglichen Offline-Prüfer validiert. Target-PC-, Sicht-, Performance- und zusätzliche Tribal-/Collision-/Baseline-Vergleichsabnahmen sowie alle späteren Quellbäume bleiben außerhalb dieses Nachweises. Die feste 74bb-FULL-Referenz bleibt eigenständig. Keine Repository-Änderungen, neuen Läufe, Retries, Budgetänderungen oder Filterskips wurden vorgenommen.
