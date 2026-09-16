# M4-WILDLIFE-HUNTING · abgeschlossene Fachprüfung

- Basis: `df3aab820a92fa0f62ae52ccf557a6c70e6f1851` / PR #128.
- Geprüfter lokaler Quellcommit: `4731c25b85e54217966b3bbd481a8781b014ed56`.
- Inhaltlich identischer veröffentlichter Quellcommit: `79530178fa1f54b4e4762cf7e2755da33d51887d`.
- Gemeinsamer Quell-Tree: `b312ae37b04d7b4fc32c46c737aa2eded9647bee`.
- Arbeitsstand vor/nach beiden Läufen sauber; unveränderte Quellen.
- Godot `4.6.3.stable.official.7d41c59c4`, Linux headless, isolierte Nutzerdaten.
- Der folgende Nachweiscommit ergänzt ausschließlich Dokumentation/Prüfbelege.

```sh
python3 tools/validate_godot.py \
  --godot /workspace/scratch/2c2866d70564/godot \
  --tests wildlife_hunting_test wildlife_hunting_world_test wildlife_ai_test \
    wildlife_foraging_test wildlife_drinking_test wildlife_social_play_test \
    creature_behavior_gameplay_test \
  --skip-main --output /workspace/scratch/176ae31ef22c/hunting-final-01
```

Alle sieben Prozesse, Import und Quellenprüfungen bestanden. Der Haupt-Runner
meldet `stable` und `reusable: true`. Sein Kugel-Testlog endet jedoch vor dem
Abschlussmarker und ist deshalb allein kein vollständiger Abnahmebeleg.
Nur dieser Test wurde mit unverändertem Quell-Tree nochmals mit Pipe-Erfassung
ausgeführt; der vollständige Nachweis liegt in `world-complete.log` und
`world-complete-report.json`. Das verwendete Skript ist `capture_world.py`:

```sh
python3 /workspace/scratch/176ae31ef22c/run-hunting-pipe.py \
  /workspace/scratch/176ae31ef22c/hunting-final-world-pipe
```

Dieser zweite Lauf bestätigt den Testabschluss und Exit 0 des frischen
Unterprozesses. Alle sechs übrigen Hauptlogs enthalten ihre Abschlussmarker.
Kein Scriptfehler. Die absichtlichen Schreibfehler-Warnungen prüfen Rücknahme
und erneuten Versuch; sie sind keine übersprungenen Fehler.

| Prüfung | Beleg |
|---|---|
| `wildlife_hunting_test` | 42 Prüfungen: reale Verfolgung/Flucht, Tod und endliches Fressen; Schutzregeln, Sichtwand, fehlender Boden, entferntes Ziel, Stillstand, Suchbudget, Pause, zwei Verbraucher, Fehler-Rücknahme in Phase 0/1, Speichern/Laden und frischer Prozess |
| `wildlife_hunting_world_test` | Normaler Kugel-Einstieg, generierte IDs/Rollen/Körper, radialer Boden und 2,79 m Annäherung, 10 verbrauchte Futtereinheiten; regionaler Save, Fehler-Rücknahme ohne veraltete Referenzen, Entladen/Wiedererscheinen und frischer Prozess |
| `wildlife_ai_test` | Vorhandene Wahrnehmung, Warnung, Kampf, Revier, Herde und Hindernissteuerung |
| `wildlife_foraging_test` | Vorhandene endliche Pflanzenkost, Hunger, Gefahrenpriorität und Lebenszyklus |
| `wildlife_drinking_test` | Bestehende Wasserbeschaffung, reale Erreichbarkeit und gespeicherter Durst |
| `wildlife_social_play_test` | 76 Prüfungen des gestapelten #128-Pakets: kompletter Spielablauf, Prioritäten, Unterbrechung und Neustart |
| `creature_behavior_gameplay_test` | Bestehende Freundschaft, Belohnungen, Kampf, Fehler-Rücknahme und Persistenz |

Die erfolgreiche Jagd verwendet bewusst langsamere Beute im Physikprüfstand;
die Weltprüfung stellt einen Kadaver für ein generiertes Tier bereit. Die
Nachweise belegen damit die produktiven Abläufe, keine Langzeitbalance einer
unbeeinflussten Population. Generierte Aasfresser kommen nur in neuen Regionen
hinzu; gespeicherte Rollen und Körper bleiben erhalten.

`results.json`, Logs und Pipe-Bericht wurden unverändert übernommen.
`sha256.json` sichert diese Belege. Die identischen Start-/End-Manifeste liegen
zusammen in `source-manifest.jsonl.gz`; entpackter SHA-256:
`a837bcb59b4cbfefd06595f5ecadd2332dddf846059a118ccb85cdc21b35313f`.
Absolute Pfade dokumentieren die tatsächliche Prüfungsumgebung.

Kein nativer Export, keine gerenderte Windows-/Ziel-PC-Abnahme, keine Gesamt-
oder FPS-Freigabe. Offen: Langzeitbalance und Snapshotkosten bei vielen
zeitgleichen Mahlzeiten. Die Integration prüft ihren tatsächlichen Merge-Tree.
