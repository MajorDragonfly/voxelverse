# R32-08 · aktiver Kampagnenboden · #170

Feste gemeinsame Basis: `2a738a4891a8de11d682c469833ade4dc9b01dfb`,
Tree `f2bda4f815df1c73b9d740ca5282917523faf618`.
Branch `agent/r32-08-ground`, [Draft #254](https://github.com/MajorDragonfly/voxelverse/pull/254),
Ziel `agent/integration-r32-20261002`. Issue #170 bleibt offen.

Bilder: [Compatibility](compatibility/comparison.png) · [Forward+](forward-plus/comparison.png).
Bewegungsvorschauen: [Compatibility](compatibility/motion-comparison.mp4) · [Forward+](forward-plus/motion-comparison.mp4).

## Korrektur und tatsächlicher Verbraucher

Nur `world/surface/visuals/living_ground.gdshader` ist Produktänderung.
Die reguläre Kugelkampagne wird über SaveGameService/SessionFlow mit Seed 15838
geladen, `surface_generation=v2` aufgezeichnet und die Bindung dieses Shaders
an **alle** aktiven Bodenmaterialien geprüft. Auf denselben real gestreamten
Terrainmeshes wird der Shader der festen Basis gegen den korrigierten Shader
getauscht. Alte flache Terrain-Testpfade sind kein Kampagnenbeleg.

Der bisherige Felsstreifen hatte trotz Entfernungs-/Footprint-Ausblendung eine
ungefilterte `step`-Kante. Die Korrektur mittelt die periodische Stripe-Funktion
analytisch über `fwidth(surface_altitude * 2.0)`. Die Periode 0,5 m,
der 35-%-Streifenanteil und die mittlere Helligkeit bleiben erhalten, auch über
den Phasenumbruch. Integration nahe Phase 0 vermeidet unnötige Auslöschung bei
großer Höhe. Keine Textur, zusätzlicher Pass, Vertex-/Normalenänderung,
Materialbindung oder Kollisionsänderung. Gemeinsame Shaderincludes bleiben
bytegleich; Anschlüsse daran gehören zu R32-01.

Zusätzlicher Quellaufwand pro Fragment: ein `fwidth`, zwei Auswertungen einer
stückweise linearen Stammfunktion, Subtraktion/Division/Clamp anstelle von
`step(fract(...))`. Dies ist eine Quellbeschreibung, keine gemessene
GPU-Instruktionszahl. Eigene GPU-Pass-/Shader-Profilierung und Ziel-PC-Kosten
sind nicht verfügbar; native Viewportzeiten unten enthalten den gesamten
sichtbaren Boden-/Wasser-/Atmosphären-Viewport.

## Vergleichsvertrag

960×540, FOV 64°, 12/45/110 m, normale Kamera-Ferngrenze 30000 m.
Kampagnenstart plus echte Grasland-, Wüsten-, Fels-, Schnee- und Küstenorte.
Je Paar identische Kameratransformation, Sonne, Wetter, Clock 0, Origin,
Palette, LOD-Budgets und Terrain-/Kollisionsdigest. Supplementäre Orte richten
den vorhandenen Solarrahmen lokal aus; dies ist **keine** Reise-/Tageszeitabnahme.
Andere Szenerie/Akteure/UI sind für die Bodenansicht ausgeblendet, Simulation
pausiert. Der Startort behält den regulären Solarrahmen.

Bewegung: je 24 Originalbilder vor/nach am Start, im Fels und Schnee,
gleiche laterale Schritte von 0,035 m bei niedriger Kamera. Zusätzlich
Origin-Verschiebung `[83.25, -77.5, 129.125]` mit kompensierter Kamera.
Mesharrays und Kollisionsflächen werden vor/nach gehasht; sichtbare
Draw Calls und Primitive müssen pro Vergleich exakt gleich sein.

Compatibility vollständig positiv auf Commit
`2c30cfba6b81f6f6924a49ef817b6ba040094207`, Tree
`4bf220a16f80ce49fe2e12f5ac708c8e8be1af52`,
[Run 36973975961, Job 110733705686](https://github.com/MajorDragonfly/voxelverse/actions/runs/36973975961/job/110733705686).
18 Ansichten, 144 Bewegungsbilder, vier Rebasebilder und ein Küstenkontrollbild
= 185 Original-PNGs. Godot 4.6.3, llvmpipe/Mesa, native Xvfb-Ausgabe;
kein Headless-Ersatz für Sichtbilder. Fokusvertrag
`living_surface_materials_test`, Import und SourceRun stabil/sauber positiv.

Forward+ ist positiv im
[Run 36977111070](https://github.com/MajorDragonfly/voxelverse/actions/runs/36977111070)
mit sechs eigenständigen Kampagnenprozessen geprüft, Checkout
`d6cca7bf3a1ce290f6b24aa4ddacafc1aa073d2c`, Tree
`ceeb08e3921cf66c5e77a4676e56e6da909fe21d`.
Gegenüber dem grünen GL-Stand änderten sich nur Review-Partitionierung,
negative Zwischenberichtssicherung, Sonnenkontrolle und Offline-Auswertung;
Produktshader und Verbraucher unverändert. Die vorhandene CampaignAtmosphere
verwendet rendererabhängige Sonnenenergiekappen 0,72/1,1. In der eigenen Probe
wird die Energie deshalb in beiden Renderern explizit auf
`0.875736713409424` fixiert, exakt den in allen grünen GL-Originaldaten
aufgezeichneten Wert. Native Kampagnenenergie wird zusätzlich aufgezeichnet;
die Lichtproduktion wird nicht verändert.
Der strikte anschließende Cross-Renderer-Check fand an der Küste eine
Rotationsrundungsdifferenz von etwa 1e-7 nach unterschiedlicher `look_at`-
Historie. Dieser native positive Küstenlauf wurde **ausgeschlossen** und
durch exaktes Replay der originalen GL-Transform3D ersetzt:
[Run 36981050814 / Job 110755417477](https://github.com/MajorDragonfly/voxelverse/actions/runs/36981050814/job/110755417477),
Commit `101c6bfc3e943195ff2fcdfcbdf4b50c310a2b97`, Tree
`29611c9c009fee3eb38504ce0d1f8fd3690d7f76`.
Die anderen fünf Biome bleiben auf dem oben benannten Prüfkopf. Jeder
SourceRun ist sauber/stabil; komplette Produktionsmanifeste müssen über
alle Fälle **und** den GL-Stand bytegleich sein, nur eigene Review-/Belegdateien
dürfen abweichen. Keine Kamera-Toleranz oder andere Assertion wurde gelockert.
`comparison-contract.json` bestätigt alle 18 exakt gleichen Kamera-/Sonnen-
/Origin-/Wetter-/Geometrieinputs und 144 gleichen Bewegungspositionen.
Beide Renderer liefern je 185 originale Kampagnen-PNGs.
Die unveränderte 420-s-Prozessgrenze gilt für jede Kategorie; keine reduzierten
Ansichten, Samples oder Assertions. Die Diagnoseworkflow-Datei liegt nur auf
dem separaten Diagnosebranch und ist kein Eingriff in die gemeinsamen Gates.

## Sichtbefunde und offene gemeinsame Abnahme

| Material/Befund | Ergebnis des abgegrenzten Bodenvergleichs |
| --- | --- |
| Erde/Gras | Nähe zeigt feine Körnung und größere Flecken; mit Entfernung wird sie ausgeblendet. Palette und Maßstab unverändert. |
| Sand/Wüste | Dezenteres Korn als Gras/Fels; Korrektur macht keine Sand-Umgestaltung. |
| Fels | Kanten der halben Meter hohen Strata werden footprintabhängig geglättet; Stufengeometrie bleibt exakt erhalten. |
| Schnee | Helle Oberfläche und geringes Korn erhalten; keine pauschale Abdunklung. Helle größere Rasterlinien bei 45/110 m schon vor der Änderung sichtbar. Gemeinsame Licht-/LOD-Abnahme offen. |
| Küste | Feuchter Rand/Materialmaßstab erhalten. Pixeländerungen treten auch beim **codegleichen** Kandidatenklon auf; genaue Ursache außerhalb dieses Korrekturbelegs offen. |
| Wiederholung | Bestehende bodyfixe Hashperiode 128 m bleibt unverändert; Kornraster 0,125/0,5/2 m, Entfernungsausblendung 20–52/45–110/80–145 m. Bilder sind kein Beweis globaler Musterfreiheit. |
| Chunk-Nähte | Kein zusätzlicher geometrischer Spalt durch den Shader; identische Mesh-/Colliderdaten. Schneeraster und Übergangsverhalten bleiben zur R32-07-Abnahme offen. |
| Bewegung | Original-Sequenzen vorhanden; stärkere Strata-Kantenfluktuation in der getrennten Referenzprobe reduziert. Keine pauschale Flimmerfreiheit der gesamten Kampagne behauptet. |

Forward+ zeigt außerdem dunkle Punktartefakte an entfernten Hang-/Grasflächen
bereits im Basisshaderbild (z. B. Fels 45 m). Deren genaue Ursache bleibt offen;
keine Zuordnung zu Schatten, LOD oder Softwaretreiber ohne weiteren Beleg.
Auch dieser sichtbare Befund gehört in die gemeinsame R32-06/07-Sichtprüfung.

GL-Originprobe: mittlere RGB-Änderung vor und nach jeweils
`0.00025809214098586` im festgelegten Messausschnitt. Das ist gleich, **nicht**
pixelidentisch; radial approximierte Floatdaten/Rebase-Restfehler bleiben.
GL-Küstenklon: `0.00245938381907486` mittlere RGB-Änderung trotz codegleichem
Shader. Dies belegt eine vom Codeunterschied unabhängige Empfindlichkeit,
keine abschließend bewiesene Tiefen-/Draw-Order-Ursache. R32-01 erhält den Befund,
keine Änderung an Wasser, Geometrie oder fremden Materialbindungen.
Forward+-Originprobe: vor/nach jeweils `0.000841627776386246`;
Forward+-Küstenklon `0.000676953047573093`. Auch hier bleibt die vorhandene
Restabweichung erhalten; keine Pixelidentität behauptet.

Der feste Schnee-Vordergrundausschnitt `[240,240,600,500]` bei 45 m hat in
beiden Renderern 0 % vollständig weiße RGB-Pixel, keine relevante Änderung
seines p95 und erhaltene Oberflächenvariation. Die **Ausgabehelligkeit**
unterscheidet sich bei identischem Sonneninput dennoch deutlich:
mittlerer kodierter Luma-Wert GL `0.770043 → 0.770105`, Forward+
`0.589111 → 0.589046`. Dies sind PNG-Werte, keine Photometrie. Gemeinsame
rendererübergreifende Helligkeitsabnahme mit R32-06 bleibt offen; die Probe
ersetzt nicht die normale rendererabhängige Lichtkompensation.

## Strata-Referenz und Softwarekosten

Separate, ausdrücklich verstärkte/unbeleuchtete vertikale Shaderprobe mit
dem tatsächlichen Strata-Ausdruck; 24 Phasen bei 0,0005 m Schritten.
Referenz: unabhängige Schnittlänge projizierter Pixelintervalle mit
Streifensegmenten, keine Wiederverwendung der Shader-Stammfunktion.
Forward+ wird vor der Abdeckungsberechnung sRGB-dekodiert.
PNG-Quantisierung/Raster-Floatfehler sind enthalten. Kein Kampagnen-FPS-Beleg.

| Native Shaderprobe | Abdeckungs-RMSE vorher → nachher | RMS der zeitlichen zweiten Differenz vorher → nachher |
| --- | --- | --- |
| Compatibility | 0,027631 → 0,001537 (−94,44 %) | 0,065016 → 0,010611 (−83,68 %) |
| Forward+ | 0,027605 → 0,002971 (−89,24 %) | 0,064794 → 0,010573 (−83,68 %) |

Kostenprotokoll: automatische Renderschleife aus, sechs Warmläufe und 16
gemessene `force_draw(false)`-Aufrufe pro Version/Ansicht. Native Software-GPU,
zwei llvmpipe-Threads. Kein normaler Spielframe, kein FPS-/Zielhardwarewert.
Die kleine Stichprobe macht p95/p99 jeweils zum Maximum; dies ist keine
belastbare Tail-Latenzschätzung. Reihenfolge vorher→nachher, keine isolierte
Shaderpass-Messung; Runnerlast und Cacheeffekte sind nicht herausgerechnet.

| Compatibility: Mittel der 18 Ansicht-p50 | vorher ms | nachher ms |
| --- | ---: | ---: |
| Pausierter Renderaufruf inklusive Synchronisation | 166,380 | 167,514 |
| Viewport CPU | 164,659 | 165,442 |
| Viewport GPU (Software) | 164,601 | 165,379 |

Auch Regressionen bleiben sichtbar: größter positiver Aufruf-p50-Unterschied
`+5,769 ms`; Mittel der Aufruf-p95/max `182,622 → 189,258 ms`, größter positiver
p95-Unterschied `+38,167 ms`. Vollständige p50/p95/p99/Max-Werte, Counts,
Kamera-/Lichtdaten und Bildhashes in den JSON-Belegen. Kein Performance-Budget
und kein Ziel-PC werden damit freigegeben.

| Forward+: Mittel der 18 Ansicht-p50 | vorher ms | nachher ms |
| --- | ---: | ---: |
| Pausierter Renderaufruf inklusive Synchronisation | 347,191 | 348,271 |
| Viewport CPU-Zähler | 0,779 | 0,767 |
| Viewport GPU (Software) | 345,307 | 346,785 |

Forward+ größter positiver Aufruf-p50-Unterschied `+9,546 ms`; Mittel der
Aufruf-p95/max `364,374 → 368,421 ms`, größter positiver p95-Unterschied
`+98,103 ms`. Kategorien laufen auf getrennten VMs; jedes Vorher-/Nachherpaar
bleibt auf derselben VM. Die Mittelwerte beschreiben diese Stichprobe,
keinen gemeinsamen Hardwarebenchmark. CPU-Zähler haben backendabhängigen
Umfang und dürfen nicht als CPU-Speedup gegenüber GL gelesen werden.

## Belege, negative Versuche und Anschluss

`compatibility/comparison.png` zeigt alle 18 Vorher-/Nachherpaare;
`originals/` enthält ausgewählte unveränderte Original-PNGs. Die MP4 ist eine
12-fps-Vorschau der 24 erfassten Bewegungspositionen, kein gemessenes Spiel-FPS.
Reports/Logs und komprimierte komplette SourceManifeste bleiben im Commit.
Original-Artifacts einschließlich aller PNGs: IDs/ZIP-SHA256 in
`artifacts.json`; GitHub-Aufbewahrung 14 Tage.

Die sechs Forward+-Artifacts werden unverändert in Verzeichnisse mit den
Kategorienamen entpackt. `review_r32_08_assemble.py` prüft Bild-/Log-/Source-
Hashes, vollständige positive Originalreports und den Cross-Renderer-Vertrag
vor dem Zusammenstellen. Body IDs frisch isolierter Slots werden nur für
Adress-/Wettervergleich normalisiert; Geometrie, Position und Physikdigest
werden exakt verglichen. Draw-Call-Gesamtzahlen dürfen zwischen Renderern
abweichen, vor/nach müssen sie je Renderer identisch sein.

```sh
python tools/review_r32_08_assemble.py --cases /path/cases --reference /path/gl/campaign --output /path/combined
python tools/review_r32_08_results.py --root /path/combined --output /path/analysis
```

Native Wiederholung mit bestätigtem Hostsperren-/Messslot, Godot 4.6.3, Xvfb
und Mesa (Ausgabe außerhalb des Checkouts; eigener isolierter Savebereich):

```sh
python tools/review_r32_08_ground.py --godot /path/Godot --renderer forward_plus --mode campaign --category snow --xvfb /usr/bin/Xvfb --vulkan-icd /path/lvp_icd.json --output /path/new-capture
```

`--category all` prüft wieder alle sechs Orte in einem Prozess, für schnelle
Hardware; `--mode probe` ist die getrennte verstärkte Strata-Referenz.
`diagnostic-workflow.yml` dokumentiert den eigenen einmaligen Matrixlauf als
Reviewanschluss; es ist keine Änderung an `.github/workflows` des Fach-PRs.

Erster GL-Gesamtlauf negativ wegen Review-Teardown (Player lief nach
Scene-Freigabe); nur Probe korrigiert, strikter Error-Check erhalten.
Erster und zweiter Forward+-Gesamtlauf negativ wegen 420-s-Grenze.
Originale Ergebnisse/Logs in `negative-first-run/` und
`negative-second-forward/`. Kein negativer Gesamtlauf als positive Abnahme.
Der erste partitionierte Forward+-Felslauf bestand für sich, verwendete aber
die native stärkere Sonnenenergie. `excluded-sun-mismatch/` bewahrt ihn als
ausgeschlossenen Cross-Renderer-Beleg; der restliche eigene alte Run wurde
durch den korrigierten Diagnoseworkflow automatisch abgebrochen.
`excluded-camera-rounding/` bewahrt auch den ausgeschlossenen Küstenlauf;
die exakten Replaydaten sind separat positiv. Der Vergleich prüft auch
die Küstenkamera exakt gegen die Originaldaten.

R32-01: Shaderincludes unverändert übernehmen; bei späteren Änderungen erneut
gemeinsam prüfen. Native Gesamt-/Reisekette, volle Suite, Exporte und vier
Pflichtgates auf dem integrierten Tree ausführen. R32-06/07: Schneehelligkeit,
Rasterlinien, Chunkübergänge und Bewegung auf gemeinsamem Licht-/LOD-Stand.
Zielhardwareprüfung bleibt mangels Ziel-PC ausdrücklich offen. Draft bleibt
Draft, #170 und #166 bleiben offen.
