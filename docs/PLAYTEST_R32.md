# R32 – gemeinsamer Windows-Spieltest

Stand: 02.10.2026. Die verbindliche Vergabe und alle Messslots stehen ausschließlich
in [R32 / Issue #137](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-5946206999).
Dieser Bogen beschreibt den Testablauf, keine zweite Besitzerliste.

## Stand eindeutig unterscheiden

- Feste R32-Fachbasis: `2a738a4891a8de11d682c469833ade4dc9b01dfb`.
- Basistree: `f2bda4f815df1c73b9d740ca5282917523faf618`.
- Integrationsbranch: `agent/integration-r32-20261002`.
- Der verfügbare C31-Windows-Export ist die **R32-Basisreferenz**, nicht der
  abschließend integrierte R32-Spielstand. Er entstand im
  [Exportlauf 36912645535](https://github.com/MajorDragonfly/voxelverse/actions/runs/36912645535)
  für [#248](https://github.com/MajorDragonfly/voxelverse/pull/248), dessen geprüfter
  CI-Mergetree identisch zur R32-Basis ist. Originalartefakt: `11190378384`.
- Ein R32-Finalstand ist erst nach den Fachlieferungen und der zentralen Abnahme
  verfügbar. Namen, Hashes und offene Prüfungen werden dann im BUILD_INFO des
  ausgelieferten Pakets und in #137 festgehalten.

## Vergleich vorbereiten

Godot 4.6.3; Standardprobe Seed **15838**, 1920 × 1080, identisches Preset,
Körperdesign, Startsave und dieselbe aufgezeichnete Route. Hardware, GPU-Treiber,
Renderer, Auflösung, UI-Skalierung und tatsächliche Kampagnenzeit/Wetter notieren.
Vorher und nachher denselben Save/Route-Digest verwenden. Forward+ und Compatibility
separat vergleichen; Software-Renderer nicht als GPU-/Ziel-PC-Beleg ausgeben.
Andere Seeds, Biome und Szenen bleiben ergänzende Fälle.

Referenz-PC: Ryzen 7 9800X3D, RTX 4070 Ti, 32 GB / 5200 MT/s. Vorläufiges Ziel
1080p / 60 FPS. Vor schweren Leistungsmessungen exklusiven Slot für den konkreten
Host in #137 bestätigen lassen. Fachprüfungen und Integrations-CI nicht identisch
zusätzlich lokal ausführen.

## Kurze gemeinsame Testliste

1. **Bewegung und Streaming:** erste und wiederholte zehnminütige Gehroute samt
   physischem Rückweg. Frametime p50/p95/p99/max, Spitzen >33/50/100 ms und
   Sichtbarwerden von Tieren/Nestern/Beeren festhalten. Kollision, Ursprungwechsel,
   Save → Menü → Laden prüfen. Tod oder blockierte Route als negativen Lauf
   erhalten, keine Survival-Overrides. (#167)
2. **Kameras und Trinken:** dieselbe Voxelstufe aufwärts/abwärts, gerade/schräg,
   mehrere Körper/Bildraten, Sprung/Fall. Stammesstrecke, Augenhöhe, Nah-/Fernzoom,
   Ufer/Hang und alle Bildränder; Minimap, Q/E/Rebinding/alte Profile/Neustart.
   Trinkhinweis und Aktion auf trockenem Boden, Süßwasser, Salzwasser und beim
   Schwimmen vergleichen. Ursprüngliche strenge Niedrigwinkelanforderung aus
   #189 erhalten und fachlich begründet prüfen. (#171/#179/#210)
3. **Scanner und Nester:** kleine/große bewegte Tiere am Kreisrand, zwei Ziele,
   Sichtverlust/Verdeckung, getrennten Fortschritt, Pause. Zwei gleichartige
   Nester vor/nach Scan sowie Bewohnerwechsel/Entladen/Neustart; keine vorher
   sichtbaren Art-/Zahlendaten. Kalte und dichte Scanlast messen. (#172/#173)
4. **Licht, Materialien und Bewegung:** gleiche Ansichten nah/mittel/fern,
   Wald/Hang/Boden/Stein/Horizont/Wasser/Schnee bei Tag/Nacht in beiden Renderern.
   Hin-/Rückbewegung, Wind, LOD und Rebase filmen; helle Struktur, Schatten,
   Flimmern, Nähte und Framekosten vergleichen. Tatsächliche Dorfarbeit und
   Wasserbewegung mit Pause/Tempo prüfen. (#168/#169/#170/#204/#182)
5. **Kreaturen:** Ruhe, Neugier, Gefahr/Flucht, Fressen/Trinken sowie erfolgreiche,
   abgelehnte und unterbrochene Befreundung bei mehreren Formen und nahen Tieren.
   Zeichen, Fußkontakt, Körperanschlüsse, Übergänge und Framekosten prüfen;
   gehaltenes F, Pause und Save/Neustart dürfen kein Vertrauen farmen.
   (#174/#175/#176)
6. **HUD, Buch und Menüs:** echte Maus-/Tastaturwege in beiden Spielphasen,
   DE/EN × 800×600/720p/1080p × 100/125/150 %. Auswahl, Bücher, Karte, Bauvorschau,
   Esc → Einstellungen → Grafik/Audio → zurück; keine Weltklicks hinter UI.
   Bei 1080p/100 % mindestens 70 % zusammenhängende freie Spielfläche; gespeicherte
   Grafikwerte, Fähigkeiten und bewusste Epochenbestätigung prüfen.
   (#177/#178/#180/#209)
7. **Dorf und Wetter:** Bewohnerblatt, zwei Baustellen und zwei Sammelgebiete;
   Zuweisung 0..n, Reassign, Wegsperre/Erschöpfung, Entnahme → Fracht → Lager,
   Reservierung/Unterwegs und Bauverbrauch mit realen Datensätzen vergleichen.
   Pause/Tempi, Nah-/Fernwechsel und frischer Neustart ohne Doppelauszahlung oder
   Offlineproduktion. Ausstattung nur aus echter Fachquelle. Tages-/Wetterclock
   und Warnung vor einem tatsächlich kommenden regulären Sturm prüfen;
   Diagnose-Sturm separat. (#205/#206/#207/#208/#209)
8. **Hören:** Master/Musik/Umgebung/Effekte/UI getrennt mit echten Emittern,
   Hörprobe, 0 %/Stumm/Reset, Pause/Oberflächenwechsel und Neustart bedienen.
   Gespeicherte Buswerte und tatsächliche hörbare Wirkung prüfen. Musik- und
   Unterwasser-Fachbesitzer behalten ihre Arbeiten. (#181)

## Zentraler technischer Abschluss

R32-01 führt auf dem gemeinsamen finalen Tree volle Quellsuite und Runtime-/
Produktions-/Reisekette, native Windows-/Linux-Exporte und die vier Pflichtgates
aus: Godot validation gate, Desktop export gate, Environment render gate,
Project dashboard gate. Jeder neue Test wird genau einmal in
`tools/validation/contracts.json` registriert. Assertions, Fehlerbedingungen und
Deadlines bleiben erhalten. Neue Merge-Trees erhalten eigene Belege; identische
CI-Prüfungen nicht lokal duplizieren.

Finalpaket: `R32-20261002-WINDOWS-FINAL-<kurze Quell-SHA>`. BUILD_INFO enthält volle
Quell-SHA/Tree, wirklichen CI-Run/Build-ID, Engine, Originalartefakt, Paket-SHA256
und offene fachliche Abnahmen. Kein Basisbuild wird als Finalpaket umbenannt.

Prüfbericht pro Punkt: Build-ID, Bedingungen, tatsächlicher Ablauf, Ergebnis,
Log/Bild/Video/Hörprobe und verbleibende Grenze. Technischer Merge allein schließt
keines der Teilissues. Ziel-PC-, Sicht-, Hör- und Spielkomfortprüfungen bleiben
offen, solange die jeweiligen Originalkriterien nicht vollständig belegt sind.
Weltkarte INT30-11 sowie PRs #189/#246 bleiben geschützt.
