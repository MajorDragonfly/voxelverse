# PT17-03 – Fernlandschaft: Kachelbeleuchtung und Vegetationsübergänge

Auftrag: [#169](https://github.com/MajorDragonfly/voxelverse/issues/169), Spieltest
[#166](https://github.com/MajorDragonfly/voxelverse/issues/166). Basis:
`0e0a1cda0d645f872cecd42881b3f6e53b3ba34e`. Zuordnung ausschließlich in #137.
PT17-02 und PT17-05 bleiben bei ihren laufenden Fachchats.

## Befund und Änderung

Der reguläre Einstieg verwendet `surface_terrain`, `surface_ecosystem` und
`surface_distant_scenery`. Die im Issue genannten planaren Einstiegspfade sind
hier nicht aktiv. Die Änderung greift deshalb im gemeinsamen Kugelmodus.

Die äußeren Voxeloberseiten werden geometrisch an die Nachbarkacheln angeschlossen.
Ihre bisherigen Flächennormalen interpretierten diesen Anschluss als geneigte
Bodenfläche: Sonne und Bodenmaterial verstärkten eine regelmäßige Kachelkante.
Oberseiten verwenden jetzt ihre radiale Spaltennormale; echte Wände behalten ihre
seitliche Normale. Positionen, Indizes, Stufen und Kollisionsflächen bleiben gleich.
Das ist ein nachgewiesener Codebefund; die exakte Kamerapose von Screenshot A ist
nicht gespeichert, daher keine Behauptung, alle dortigen Linien hätten dieselbe Ursache.

Die Nahvegetation ersetzte die Fernvegetation in einem einzigen Bild. Die Übergabe
dauert jetzt 0,35 Sekunden mit komplementärer opaker Rasterabdeckung. Beide Seiten
verwenden dieselbe R8-Quantisierung, Position, Artpalette und Windbewegung.
Beim Verlassen bleiben nur die ausblendenden Darstellungen kurz erhalten, ohne
aktive Kollision; beim Umkehren werden dieselben Kacheln wiederverwendet. Bei
Ursprungwechseln folgen sie weiterhin ihrer kanonischen Bindung. Pause hält den
Übergang an. Keine neue Speicherung oder Tier-/Wirtschaftssimulation.

Nach vollständiger Einblendung wird das ursprüngliche gemeinsame, opake
Vegetationsmaterial wiederverwendet. Der erste Software-Grafikvergleich zeigte
Zusatzaufwand durch einen dauerhaft aktiven Discard-Shader. Der Übergangs-Shader
ist deshalb nur während der tatsächlichen 0,35 Sekunden aktiv; beim Ausblenden
wird dieselbe vorbereitete Materialinstanz wiederverwendet.

Budgets: weiterhin 25 aktive Nahkacheln, ein Vegetationsupload pro Bild, ein ferner
Worker und ein vorbereiteter Satz. Höchstens 25 zusätzliche ausblendende Kacheln
für 0,35 Sekunden; bei großen Teleportfolgen werden ältere Ausblendungen freigegeben.
Fernbereich unverändert: voller Bestand bis 224 m, Ausblendung bis 256 m,
Generationsreserve bis 288 m und höchstens 2048 Zellen. Kein neuer unbegrenzter Wald.

## Prüfung und reproduzierbare Sichtkontrolle

Godot 4.6.3, Linux, isolierte Nutzerdaten. Vier gezielte Tests bestanden:
`surface_distance_test`, `surface_distance_world_test`,
`surface_population_budget_test`, `large_planet_geometry_test`.
Die bestehenden Tests prüfen jetzt zusätzlich Beleuchtung an gestitchten Rändern
aller sechs Kugelseiten, Zwischenphasen, komplementäre Abdeckung und Richtungswechsel.
2.326 Fernsichtkontrollen, 1.135 Fernobjekte in acht Batches, 359 Objekte zwischen
150 und 224 m; maximale Nah-/Fernpositionsabweichung 0 m. Keine FPS-Freigabe.

Der lokale Quellenstand und die Ergebnisse sind in
`evidence/pt17-03/headless-results.json` und `tested-files.json` festgehalten.
Diese Fachprüfung lief vor Ergänzung der Grafikmesswerkzeuge; die sechs geprüften
Runtime-/Testdateien sind über ihre SHA256 eindeutig zugeordnet. Gemeinsame
Integration, Exporte und Grafik werden durch die PR-CI geprüft.

Nach der Materialoptimierung wurde `surface_distance_world_test` erneut bestanden:
`optimized-headless-results.json` und `optimized-tested-files.json` beziehen sich
auf die beiden geänderten Dateien. Der Test verlangt nun auch die Rückkehr zum
ursprünglichen opaken Material. Die übrigen vier Fachdateien bleiben unverändert.

`tools/review_surface_transitions.py` rendert denselben Messcode auf dem festen
PR-Basisstand und dem Kandidaten. Nur das Messskript wird in den temporären
Basischeckout kopiert. Es verwendet Seed 15838, 960×540, Hin-/Rückweg bei
0/40/100/200/100/0 m, Seitenblick und tief stehende Sonne. UI und Akteure werden
für den Landschaftsvergleich verborgen, Wind und Wolkenzeit festgehalten.
Acht Bildpaare pro Renderer, Objektzahlen, zwölf Framezeitproben je Ansicht und
ein SHA256 der realen Kollisionsflächen werden gemeinsam hochgeladen. Der
Runner verlangt identische Kollisionsflächen und korrekte Oberseitennormalen.
Die Bilder müssen zusätzlich visuell beurteilt werden; die kurzen Messungen
am Software-Grafiktreiber sind keine Leistungsabnahme auf Lars' PC.

Der erste GL-Vergleich auf `d2984d5602002d79a69ebd6ca7a48817b4bb77d2` bestand;
die maximale künstliche Oberseitennormalen-Abweichung sank von 0,2021865 auf 0,
der Kollisions-Hash blieb identisch. Der Vulkan-Vergleich scheiterte bereits am
unveränderten Basisstand: bei ungefähr einer Software-GPU-Sekunde je Bild konnte
der reguläre Einzelschritt-Publisher nicht alle 25 Nahkacheln in 60 Sekunden
bereitstellen. Der Messaufbau leert deshalb bis zu 64 vorhandene Flora-Schritte
pro ungemessenem Vorbereitungsbild. Die nachfolgende Darstellung bleibt regulär;
Laufzeitbudgets werden weiterhin im unveränderten echten Weltprüfablauf geprüft.

## Offene gemeinsame Abnahme

PT17-02 verändert Licht/Atmosphäre separat. Der gemeinsame Look und die
Referenz-PC-Framezeiten aus PT17-01 müssen auf dem integrierten Stand geprüft
werden. #169 bleibt dafür offen. Die begrenzte Vegetationsreichweite, die
gröbere Horizontgeometrie außerhalb des Nah-/Mittelbereichs und deren weiterer
Ausbau werden durch diese Korrektur nicht als vollständig abgenommen erklärt.
