# R32-06 — native Ergebnisse und Kosten

Die Quelle und Methode stehen in [README.md](README.md). Alle Luminanzen sind sRGB-Anzeigewerte aus dem festen HUD-freien Terrainrechteck `(96,270,680,410)`. Keine Lux-, Rohalbedo- oder Ziel-PC-Messung.

## Komponenten bei identischem Tag

| Ansicht / Diagnose | Compatibility Median | Forward+ Median | Weißanteil GL / F+ |
| --- | ---: | ---: | ---: |
| forest-production | 0.5144 | 0.4880 | 0.00% / 0.00% |
| forest-no-sun | 0.1592 | 0.1629 | 0.00% / 0.00% |
| forest-no-ambient | 0.3454 | 0.4569 | 0.00% / 0.00% |
| forest-exposure-half | 0.3531 | 0.3477 | 0.00% / 0.00% |
| forest-white-one | 0.5719 | 0.5443 | 0.00% / 0.00% |
| forest-albedo | 0.4051 | 0.4023 | 0.00% / 0.00% |
| snow-production | 0.8995 | 0.8698 | 0.00% / 0.00% |
| snow-no-sun | 0.3955 | 0.3960 | 0.00% / 0.00% |
| snow-no-ambient | 0.7484 | 0.8476 | 0.00% / 0.00% |
| snow-exposure-half | 0.7807 | 0.7272 | 0.00% / 0.00% |
| snow-white-one | 0.9975 | 0.9636 | 52.88% / 5.10% |
| snow-albedo | 0.8202 | 0.8348 | 0.00% / 0.00% |

Schnee bleibt im Produktionszustand sehr hell (0,8995 / 0,8698), behält aber erkennbare Stufen und Steindetails; in der ROI clippt kein Pixel nach der hier verwendeten Weißdefinition. Ohne Sonne fällt der Median auf rund 0,396, ohne Ambiente bleiben rund 0,748 / 0,848. Die direkte Sonne prägt helle Flächen, das Ambiente erhält Schatten. Eine Halbierung der Belichtung verändert zugleich beide; sie ersetzt keine Komponentendiagnose. Weißpunkt 1 erzeugt in Compatibility 52,88% nahezu weiße ROI-Pixel und wird nicht als Tagesdefault übernommen. Der vorhandene Tag-Weißpunkt 2 und Nacht-Weißpunkt 1 bleiben erhalten.

Der unbeleuchtete Materialpass zeigt bereits hohe Schneewerte und kräftige Vegetationsfarbe. Er verwendet die realen Materialslots ohne Änderung der Pigmente. Wegen Shadern, Normalen, Reflexionen und gemischter ROI ist das keine isolierte Materialmessung und begründet keinen Materialfix. R32-08/09 erhalten die Bildtafeln und protokollierten Slots. Die nichtlinearen Bildwerte dürfen nicht additiv als Beleuchtungsanteile gelesen werden.

## Produktion: Tag und Nacht

| Ansicht | GL Tag / Nacht | F+ Tag / Nacht | Weißanteil in allen vier ROIs |
| --- | ---: | ---: | ---: |
| forest | 0.5144 / 0.0370 | 0.4880 / 0.0572 | 0.00% |
| snow | 0.8995 / 0.1584 | 0.8698 / 0.1696 | 0.00% |
| water | 0.5874 / 0.0443 | 0.5402 / 0.0620 | 0.00% |
| creature-horizon | 0.6612 / 0.0533 | 0.6043 / 0.0740 | 0.00% |
| creature-close | 0.6542 / 0.0603 | 0.6043 / 0.0810 | 0.00% |

Die bestehende rendererabhängige Sonnenkalibrierung bleibt GL 0,875737 / F+ 1,337931 am Waldtag; gleiche tatsächliche Sonnenrichtung und Uhrzeit. Ambiente Tag 0,368248 / Nacht 0,129970, Belichtung 1, Sättigung/Kontrast 1. Nachts ist die Sonne aus. Compatibility unterstützt hier kein SSAO/Bloom, Forward+ aktiviert beide entsprechend dem identischen Preset 1; volumetrischer Nebel ist dort im ausgeglichenen Preset aus, normale Haze/Fog bleibt wie zuvor. Daraus folgt kein Anspruch auf identische Pixel zwischen Renderern.

Der neue Farbvertrag lässt die Forward+-Himmels-ROI-Mediane exakt unverändert und hebt nur die vorher schwarzen Compatibility-Nachtfarben an. Die Heimat-Terrainmediane bleiben exakt unverändert. Kleine Restunterschiede der Kreatur-Pose/Geometrie waren schon in der Negativkontrolle vorhanden. Vollbilddifferenzen stehen im JSON; sie werden nicht pauschal dem Licht zugerechnet.

## Pausierte Renderkosten, Millisekunden

Je Produktionsbild vier Aufwärmzeichnungen, anschließend sechs beibehaltene `force_draw(false)`-Proben. Wall-Zeit umfasst CPU und Zeichnen; CPU/GPU-Werte sind die getrennten Viewportmessungen der Engine. Bildrücklesen ist separat. P95 entspricht bei sechs Proben der höchsten Probe. Das ist weder ein laufendes Frameintervall noch eine FPS-Messung.

| Renderer / Ansicht | Wall Basis Median / P95 | Wall Fix Median / P95 | beobachtete Medianänderung | Fix CPU Median | Fix GPU Median | Readback Fix |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| gl / forest-day | 2675.05 / 2720.76 | 1991.84 / 2093.95 | -25.54% | 2106.396 | 2106.31 | 2.103 |
| gl / forest-night | 2627.52 / 2636.34 | 1990.06 / 2039.37 | -24.26% | 2015.512 | 2015.93 | 2.079 |
| gl / snow-day | 291.25 / 292.14 | 227.90 / 237.79 | -21.75% | 227.895 | 228.16 | 2.090 |
| gl / snow-night | 249.19 / 252.18 | 193.77 / 195.21 | -22.24% | 192.383 | 192.68 | 2.089 |
| gl / water-day | 1401.87 / 1407.85 | 1082.83 / 1088.40 | -22.76% | 1020.009 | 1020.46 | 2.085 |
| gl / water-night | 1284.01 / 1291.28 | 985.52 / 990.08 | -23.25% | 985.128 | 985.40 | 2.259 |
| gl / creature-horizon-day | 913.20 / 914.50 | 660.21 / 663.50 | -27.70% | 664.366 | 664.64 | 2.103 |
| gl / creature-horizon-night | 873.74 / 895.43 | 641.60 / 645.08 | -26.57% | 641.390 | 641.66 | 2.099 |
| gl / creature-close-day | 791.59 / 794.82 | 606.46 / 608.18 | -23.39% | 606.287 | 606.49 | 2.086 |
| gl / creature-close-night | 710.36 / 713.11 | 529.64 / 545.98 | -25.44% | 544.337 | 544.55 | 2.094 |
| forward / forest-day | 3165.78 / 3203.42 | 3068.98 / 3164.03 | -3.06% | 1.055 | 3066.86 | 2.402 |
| forward / forest-night | 3032.43 / 3107.39 | 3039.30 / 3106.16 | +0.23% | 1.030 | 3037.42 | 3.286 |
| forward / snow-day | 492.09 / 494.69 | 496.55 / 535.52 | +0.91% | 0.902 | 491.86 | 2.777 |
| forward / snow-night | 437.24 / 445.68 | 435.32 / 449.09 | -0.44% | 0.843 | 432.72 | 2.218 |
| forward / water-day | 1761.87 / 1780.15 | 1693.23 / 1709.52 | -3.90% | 1.002 | 1695.84 | 2.843 |
| forward / water-night | 1571.12 / 1604.28 | 1488.18 / 1519.23 | -5.28% | 0.954 | 1470.37 | 1.985 |
| forward / creature-horizon-day | 1206.74 / 1210.85 | 1029.64 / 1082.42 | -14.68% | 0.968 | 1054.31 | 2.422 |
| forward / creature-horizon-night | 1129.32 / 1177.87 | 1072.89 / 1082.74 | -5.00% | 0.988 | 1070.60 | 3.427 |
| forward / creature-close-day | 1054.86 / 1069.73 | 1060.30 / 1086.33 | +0.52% | 0.971 | 1058.52 | 4.017 |
| forward / creature-close-night | 972.67 / 974.34 | 979.14 / 984.05 | +0.67% | 0.934 | 978.35 | 3.382 |

Die Compatibility-CPU-Zähler enthalten beim Softwaretreiber Zeichnung/Wartezeit und liegen nahe den GPU-Zählern; sie sind keine isolierte CPU-Arbeitszeit. Viewportzeitstempel können verzögert aus der vorigen Zeichnung stammen. CPU, GPU und Wall werden deshalb nicht addiert.

Der Compatibility-Job lief auf einem anderen CI-Rechner als seine Basis. Seine deutlich niedrigeren Software-Zeiten sind ausdrücklich kein belegter Leistungsgewinn des Farbfixes. Auch Forward+ schwankt: Waldnacht +0,23%, Schneetag +0,91%, Kreaturnähe Tag +0,52% / Nacht +0,67%. Die jeweiligen Erhöhungen bleiben im Bericht. Gleiche Rendereradapterbezeichnung und CPU-Typ garantieren keine gleich belastete VM. Der Fix fügt keine Geometrie, Passanzahl oder Clouditeration hinzu; sein tatsächlicher Aufwand auf dem Ziel-PC bleibt ungemessen.

Alle Rohwerte, Drawcalls/Primitives, Befehle, Prozessbeobachtungen, Adapter/CPU und Bildhashes stehen in `comparison.json` und den verlustfrei komprimierten Originalberichten unter `final/`. Die gesamten Fix-Läufe benötigten GL 261,22 s und Forward+ 493,39 s; beide unterschreiten den unveränderten 600-s-Prozessguard. Basisläufe: GL 345,20 s / Forward+ 501,56 s. Komponenten enthalten nur zwei beibehaltene Kostenproben und werden nicht als belastbare Perzentilvergleiche ausgelegt.

## Belegbestand und offene Abnahme

Basis: Run 36976482545, `before` aus beiden Rendererartefakten. Fix: Run 36983041310, je 20 Original-PNGs. Die 40 weiteren damaligen `after`-Bilder sind eine unveränderte Kontrollquelle; Berichte/Manifeste/Logs und der alte Vergleich bleiben unter `original-runs/` erhalten. Ältere rote Runs bleiben als Helfernegative erhalten. Kein roter Gesamtlauf wird zur Rendererfreigabe umgedeutet.

Die elf Tafeln enthalten unskalierte Originalbildregionen. Roh-PNGs der CI haben 14 Tage Aufbewahrung; ihre SHA-256 sind dauerhaft im Vergleich erhalten. Die Tafeln, portable Referenz mit allen Regionsblobs, vollständige Start-/Endquellen, Originalberichte und Logs liegen dauerhaft im Fachbranch.

Offen bleiben gewöhnliches fortlaufendes Spielen mit weiteren Tagesphasen/Seeds/Kreaturen, Ziel-PC und Exporte sowie der kombinierte neue Material-/Grafik-/Wetter-/Reise-Tree. #168 und die zugehörige #166-Checkbox bleiben offen. Keine Vollsuite-/Merge- oder FPS-Freigabe.
