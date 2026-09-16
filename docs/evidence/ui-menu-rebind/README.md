# UI-MENU-REBIND — Prüfnachweis

Sieben Fachtests sowie Quell-/Sprachgate und Quellintegrität bestanden.
Godot `4.6.3.stable.official.7d41c59c4`, Linux/headless; der Runner verwendet
isolierte synthetische Nutzerdaten je Test.

- Lokal geprüfter Quellcommit: `45c254cff7dfa11d4a911dbac5f09bc1747fb49f`.
- Identischer veröffentlichter Quellcommit:
  `55e3deadc9cc90d63a9f2b6ea32a7aa3b3562093`.
- Exakt verglichener Quell-Tree: `27254d87ca0d44c9139477b4fd890bf3b8542739`.
- Arbeitsstand bei Beginn, allen Testgrenzen und Ende sauber/unverändert;
  `provenance.status = stable`, vollständige Anfangs-/Endmanifeste identisch.
- Basis: Atlas-PR #131, veröffentlicht
  `f51bdd023b1d239d392fa6d9bc38340d49ab406b`; gemeinsame Vorgängerbasis #125.

```sh
python3 tools/validate_godot.py \
  --godot /workspace/scratch/2c2866d70564/godot \
  --tests menu_rebinding_test input_preferences_test frontend_test \
          behavior_skill_tree_test discovery_journal_test atlas_search_test localization_test \
  --skip-main --skip-import \
  --output /workspace/scratch/97e7c57ff0f3/menu-rebind-final-check
```

| Prüfung | Ergebnis | Sekunden |
|---|---|---:|
| Neue Menütasten, 74 Prüfungen inkl. eigenem Engine-Neustart | bestanden | 4,73 |
| Bestehende Eingabepräferenzen und Fehlerfälle | bestanden | 1,47 |
| Frontend, Einstellungen, Kugelstart, Spielstandwechsel | bestanden | 57,77 |
| Entwicklungsbuch, modale Eingabe und Pausenbesitz | bestanden | 3,63 |
| Entdeckungsbuch und Suchfokus | bestanden | 5,58 |
| Atlas und archivierte Ortssuche, Speichern/Neustart, Layout | bestanden | 18,36 |
| DE/EN und dynamische Hilfe | bestanden | 1,87 |

[Unveränderter Abschlussbericht](results.json) ·
[Rohprotokolle, frühere Läufe und Quellmanifeste](validation-logs.tar.gz) ·
[Prüfsummen](sha256.json).

`menu-rebind-initial-check` enthält den erfolgreichen Ressourcenimport,
Art-/Quellgate und den ersten bestehenden Eingabetest. Der neue Menütastentest
bestand anschließend in `menu-rebind-contract-check`. Danach wurde eine
gleichwertige Testdatenformulierung vereinfacht, die Fachübergabe ergänzt und
die vom Editor erzeugten Script-UIDs aufgenommen. `menu-rebind-import.log`
dokumentiert den erneuten erfolgreichen Import vor dem sauberen Abschlusscommit.
Keine weiteren Ressourcenänderungen vor dem Abschlusslauf.

Alle ausgeführten Tests dieser Paketentwicklung bestanden. Absichtlich ungültige
Speicherziele/Zukunftsversionen in den bestehenden Negativtests erzeugen erklärte
Warnungen; kein Engine-/Scriptfehler wurde unterdrückt oder als Erfolg gewertet.
Die Testumgebung war während der Ausführung isoliert und nach dem Lauf aufgeräumt.

Keine gerenderte/native Bildprüfung, kein Windows-Export und keine
Ziel-PC-/Tastaturlayout-Abnahme. Die Tests prüfen echte Controls/Eingaben im
Headless-Modus, keine Screenshotdarstellung. Die neu konfigurierbaren
Menüaktionen gelten für die bestehende Spieloberfläche; feste Labor-/Editor-
Aktionen, Controller und Tastenkombinationen sind kein Lieferumfang.

Der folgende Nachweiscommit ergänzt ausschließlich diesen Ordner und verändert
den geprüften Programm-/Teststand nicht.
