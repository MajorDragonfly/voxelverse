# ARCH-13-SLOT-BROWSE-BUDGET — Prüfnachweis

Datum: 16. September 2026. [Umfang und Grenzen](../../WORK_ARCH13_SLOT_BROWSE_BUDGET.md).

- Lokaler geprüfter Quellcommit: `1bd5dc67beac6e39868183c55fa68445e8a5ffc6`.
- Veröffentlichter Quellcommit: `7d62fe90475daa13fdd57092df401dc5bc4482cc`.
- Exakt gleicher Quell-Tree: `c931ebff8766f550ee623cbba67644b858ce3a45`.
- Quelle sauber und während der gesamten Abschlussprüfung unverändert;
  `source_sha256=af8ed0ede8cd715e3b887248a0b3e1d353ff478bae196e83838928a305989a99`, `provenance.status=stable`,
  `reusable=true`. Der anschließende Nachweiscommit ergänzt nur diesen Ordner.
- Godot `4.6.3.stable.official.7d41c59c4`, Linux x86_64, Headless; isolierte Nutzerdaten je Prüfung.

```sh
python3 tools/validate_godot.py \
  --godot /workspace/scratch/2c2866d70564/godot \
  --tests slot_scan_test save_browser_search_test save_slots_test localization_test frontend_test \
  --skip-main --skip-import \
  --output /workspace/scratch/97e7c57ff0f3/slot-scan-final-check
```

Der identische Ressourcenstand war zuvor erfolgreich importiert. Neue UID-Dateien
gehören zum Quellcommit. Import/Artgate stehen im initialen Nachweis.

| Prüfung | Ergebnis | Sekunden |
| --- | --- | --- |
| `source_contracts` | bestanden | 0.115 |
| `slot_scan_test` | bestanden | 2.324 |
| `save_browser_search_test` | bestanden | 5.883 |
| `save_slots_test` | bestanden | 1.872 |
| `localization_test` | bestanden | 1.874 |
| `frontend_test` | bestanden | 58.254 |
| `source_integrity` | bestanden | – |

`slot_scan_test`: 84 Bedingungen mit echten Dateien; 140 irrelevante
Verzeichniseinträge, Haupt-/Backup-/Historienfälle einschließlich altem
Standardspeicher, Historienüberhang und Deduplizierung, interaktive Tasteneingabe,
Abbruch/Neustart der Ansicht, Sichtbarkeit, Auswahlwechsel und unveränderte
Dateihashes. Nachträglich veraltete Zusammenfassung erlaubt weder Kopie noch
Laden einer inzwischen neueren Datei. `save_browser_search_test`: 771 Bedingungen
mit 31 realen Slotfällen, 1.005 Suchdatensätzen und zwölf DE/EN-/Fenster-/Skalenfällen.
Die zusätzlich gezählten Bedingungen betreffen das Warten auf Ladeabschluss.
Der bestehende Frontendtest durchläuft echte Aktionen und Kugelkampagnenstart.

## Vollständige und frühere Läufe

`results.json` ist unverändert vom Runner übernommen. `validation-logs.tar.gz`
enthält originale Godot-/Runnerlogs, Vertragsberichte sowie beim Abschlusslauf
beide vollständigen Quellmanifeste. Die Quellhashes in den früheren Teilberichten
kennzeichnen deren jeweiligen Arbeitsstand, nicht die finale Quelle.

1. `initial`: Import, Artgate, Scan-, Such- und Slotprüfung bestanden. Der bisher
   synchrone Lokalisierungstest griff vor Ladeabschluss auf ein fehlendes
   Namensfeld zu. Dieser hängende Lauf wurde mit Interrupt beendet (130);
   **kein vollständiger Erfolgsnachweis**. Der Verbraucher wartet nun auf den
   Ladeabschluss, bevor er dieselben Bedingungen prüft.
2. `menu`: Lokalisierung und vollständiger Frontendablauf bestanden. Die ergänzte
   Standardspeicher-Testdatei hatte versehentlich denselben Namen wie der gesuchte
   Vergleichsslot; die Erwartung genau eines Treffers scheiterte korrekt.
   Der Standardspeicher erhielt einen eigenen Fixture-Namen. Keine
   Produktionsbedingung wurde gelockert.
3. `final`: alle fünf Fachtests, Quell-/Sprachvertrag und Integrität bestanden.

Ein einzelner Dateizugriff/Validator bleibt synchron. Keine Garantie für 2-ms-
Frames, keine reine Metadatensuche, kein begrenzter Gesamtspeicher. Kein neuer
persistenter Zustand; die geprüften Ansicht-Neustarts sind keine neue native
Prozess-/Exportabnahme. Native Grafik, Windows, gesamte Spielkette und Ziel-PC-FPS
bleiben der Integration vorbehalten. ARCH-24 unberührt.
