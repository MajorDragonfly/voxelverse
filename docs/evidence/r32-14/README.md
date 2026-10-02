# R32-14 / PT17-12 / PT18-08 — HUD und Tempo

Basis: `2a738a4891a8de11d682c469833ade4dc9b01dfb`, Tree `f2bda4f815df1c73b9d740ca5282917523faf618`.

## Reproduzierte Befunde

- Kreaturen-HUD: 125/150 % wurden bei physischer Platzierung kompensiert, ohne Schrift zu vergrößern. Negative Widgetprobe: 36 Fontassertions in DE/EN × drei Größen. Änderung: Textskalierung ohne Neuaufbau; gemeinsame Minimap-/Vitalsbreite folgt tatsächlicher Minimalbreite. Vergrößerte Buchknöpfe und Kampfkopf erhalten getrennten Platz.
- Stammes-HUD: die Siedlungsseite hatte einen eigenen vertikalen Scrollcontainer in den gemeinsamen HUD-Tabs; sechs Siedlungs-/Frachtaktionen blieben in allen Matrixfällen abgeschnitten. Host übernimmt vertikales Scrollen. Berufsauswahl behält eine begrenzte Breite.
- Tempo: gültiger gespeicherter Faktor 2× + realer Mausklick auf 3× ergab Engine 3 × Kampagne 2 = 6×. Gespeichert und geladen blieb 2×. Enger Besitzerpatch delegiert an die vorhandene Kampagnenzeit, ergänzt 3× in Setter/Validator und normalisiert den überholten Engine-Multiplikator. Die vorhandenen Werte 0/1/2/4 bleiben lesbar. Keine neue Clock/Saveverwaltung.
- Belohnungs-/Scanmeldungen: feste deutsche Meldungen bei EN. Präzise Textbelege werden mit vorhandener Übersetzungsquelle gerendert; Sprachwechsel liest nur den angezeigten Beleg und verbucht kein Ereignis erneut. 9 Katalog-Appends erforderlich.

## Integration

`r32-01-clock.patch`, `r32-01-clock-tests.patch`, `r32-01-registry.patch` und `localization-append.json` sind Anschlüsse an R32-01. Katalog-Appends seriell übernehmen und `python3 tools/localization/catalog.py` ausführen; der vollständige Katalogpatch ist nur ein enges Anwendungsbeispiel am Basistree. Zentraler Testpatch erhält alle Assertions/Deadlines und ergänzt 3× in die bestehende Gleichzeit-/Doppelbelohnungsprobe. Vier neue Tests genau einmal registrieren. Die gemeinsame Registry/Clock-/Controller-/Save-/Stildateien bleiben im Fachbranch unverändert.

## Nachweise und Grenzen

Originale werden nach Abschluss hier mit Quell-SHA/Tree, Engine, Befehl, Loghash und Screenshotmanifest verlinkt. Widget-/Kollisionsfixture und reguläre öffentliche Kugelkampagne sind getrennte Belege. Ein vollständiger gemeinsamer Merge-Tree, Vollsuite, native Windows-/Linux-Exporte und Ziel-PC-Spieltest sind zentrale Folgeabnahmen. Keine FPS-/Ziel-PC-Freigabe aus llvmpipe. Keine fehlende Pflanzfunktion wurde durch einen Knopf ersetzt; bestehender echter Gartenauftrag bleibt erhalten. Weltkarte, Bewohner-, Bau- und Sammellogik sowie #189/#246 bleiben bei ihren Besitzern.
