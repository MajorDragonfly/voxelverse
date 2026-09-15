# Nachtrag #109 zur Ressourcenintegration

Neuer veröffentlichter PR-Kopf: `1e850040e7384ac4a077fbb5e253979bf7408421`.
`main` und die zuvor integrierten Köpfe #93–108 waren beim Abruf unverändert.
Merge auf dem vorhandenen Integrationsbranch; kein Push und kein Merge auf `main`.

**Geprüfter Quellcommit:** `d1f92fec1a1c4945bff0dc1481ab0aeb3a5074ae`.
Tree `bb89eb8ad567b56c1062ea89543b5cb1930efe15`. Arbeitsstand während des gesamten
Laufs unverändert und sauber. Danach ausschließlich Status-/Übergabedokumente.

**Ergebnis:** Zehn direkte Godot-Tests sowie Import, Art-Quellen und Quellvertrag
erfolgreich. [Originalbericht](results.json), [vollständige Protokolle](logs.zip).
Godot `4.6.3.stable.official.7d41c59c4`, Linux, headless, isolierte Nutzerdaten über
den vorhandenen Runner. Der Editor wurde nach dem Verlust des früheren temporären
Toolchain-Verzeichnisses über den vorhandenen verifizierten Installer neu bezogen.

Geprüft wurden `journal_localization_test`, `discovery_journal_test`,
`journal_paging_test`, `owned_animal_localization_test`, `domestic_fauna_journal_test`,
`research_goals_test`, `localization_test`, `hud_layout_test`,
`editor_localization_test` und `resource_visuals_test`.

```sh
python3 tools/validate_godot.py --godot ../godot-toolchain/editor/Godot_v4.6.3-stable_linux.x86_64 --skip-main --tests journal_localization_test discovery_journal_test journal_paging_test owned_animal_localization_test domestic_fauna_journal_test research_goals_test localization_test hud_layout_test editor_localization_test resource_visuals_test --output ../qa/journal-integration-109
```

Der Merge dedupliziert die bereits vorhandenen Teiltexte aus #103 und erhält
Sprachschlüssel/HUD-Anschluss der anderen Lieferungen. Ein zusätzlicher Schlüssel
übersetzt die neu hinzugekommene Kopfkategorie im Buch. Fünf zusätzliche Aussagen
im Buchtest prüfen diese Kategorie und die Namen von Rüssel/Katze/Bär/Schwein.
Der gemeinsame Katalog enthält 1285 Nachrichten in zwei Sprachen; die Testregistry
enthält jetzt 180 Tests, davon den neuen Buchtest genau einmal.

Die frühere [volle Integrationsprüfung](../integration-resources-20260915/README.md)
bleibt Nachweis ihres damaligen Standes. Dieser Nachtrag ist eine gezielte Prüfung
der geänderten Ansichten und direkten Verbraucher, **keine erneute volle Suite,
kein neuer Export und keine native Grafik-/Windows-/Ziel-PC-Abnahme**.
Die Fach-Grafikmatrix aus PR #109 bleibt dessen eigener Quellnachweis.

Zusätzlich wurde der lokale Git-Objektspeicher von einem nicht mehr vorhandenen
temporären Checkout unabhängig gemacht: veröffentlichte Objekte neu eingelesen,
unveränderte Objekt-IDs in den eigenen Speicher kopiert und den veralteten
Alternativpfad entfernt. `git fsck --connectivity-only --no-dangling` besteht.
Der Checkout benötigt dieses fremde Verzeichnis nun nicht mehr.
