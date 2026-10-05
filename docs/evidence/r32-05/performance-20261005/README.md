# R32-05: dichte Scannerabfragen, 05.10.2026

Der dokumentierte Mehrkostenblocker aus Draft-PR #265 ist in der kontrollierten Software-Abfragefixture behoben. Sämtliche bestehenden Sichtkorrekturen bleiben nach den Fachtests und nativen GL-/Forward+-Gegenproben wirksam. Die Lieferung bleibt Draft; #172/#173/#166 bleiben bis zur vollständigen Abnahme offen. Dieser Bericht erteilt keine Ziel-PC-, GPU- oder Gesamt-FPS-Freigabe.

## Geprüfte Quellen und Lieferumfang

| Quelle | Commit | Tree |
|---|---|---|
| Basis | `2a738a4891a8de11d682c469833ade4dc9b01dfb` | `f2bda4f815df1c73b9d740ca5282917523faf618` |
| Letzter vorher veröffentlichter Kopf | `1d872b9e000b76fa3c03aa403956de4905b5afd3` | `1c55b455aebd0736d62fdb6e2f44736252ebed41` |
| Final geprüfter lokaler Optimierungsstand | `8a6a1174b2a7f9a0d580911d3010307d3c2051dc` | `b930849770eb3ecd65c4269b5c10b813c7314b2d` |
| Bytegleiche Codeveröffentlichung | `a9efbf836c9578ced35fbc64bfcf6b8cafb7b362` | `b930849770eb3ecd65c4269b5c10b813c7314b2d` |

Fortsetzung auf `agent/r32-05-scanner-nests`, feste Fachbasis unverändert. Seit dem bisherigen Lieferkopf sind nur Scanner/Silhouette, der bestehende `scan_circle_test` und eigene Diagnosehelfer geändert. Der Nestlabel-Fix des bisherigen Kopfes bleibt bytegleich erhalten. Der Commit mit diesem Bericht ergänzt ausschließlich Evidenz und Dokumentation; sein genauer sauberer Liefercommit/Tree steht in #265 und der Übergabe an R32-01. `delivery-source-audit.json` belegt den bytegleichen Runtime-/Test-/Helferstand gegenüber dem geprüften Codekopf. Keine Änderung an Population, Spieler-/Savehosts, Karte, Registry, #189 oder #246.

Jeder Lauf enthält Start-/Endcommit, Tree und vollständige gehashte Quellenmanifeste. Die beiden Vergleichscheckouts erhalten dieselben fünf eingefrorenen Query-Instrumentierungsdateien; die nativen Vorhergegenproben verwenden denselben unveränderten Sicht-Oracle. Die Produktionsdateien wurden für jeden Lauf zusätzlich gegen die Git-Bytes ihres jeweiligen Quellcommits geprüft. Alle übrigen Produktionsdateien sind zwischen den drei Quellen bytegleich (`production-source-diff.json`). Alle 12 Vergleichsläufe und 16 nativen Läufe sind stabil/reusable; die Quellmanifeste sind verlustfrei als `.jsonl.gz` erhalten. `summary.json` enthält den Audit aller Quellen/Instrumentierungen, `SHA256SUMS` alle archivierten Datei-Digests.

Die Git-CLI besitzt hier keine Push-Anmeldedaten. Die verbundene GitHub-API veröffentlicht daher einen Commit mit derselben vollständigen Code-Tree-SHA; nur Commitmetadaten unterscheiden sich vom lokalen Prüfkopf. Die SourceRuns behalten ihren tatsächlichen lokalen Commit. `verified-source.bundle` erhält diesen Kopf und seine fünf originalen Fachcommits ab dem vorher veröffentlichten `1d872b9e`, einschließlich des Zwischenstands `8145596`. Bundle-Prüfung und Runtime-/Test-/Helferbytevergleich sind positiv. Der öffentliche Codecommit oben ist keine behauptete erneute Ausführung; die Wiederverwendung beruht auf dem identischen Tree und der identischen geprüften Umgebung.

## Ursache und begrenzte Korrektur

Das Profil auf dem bisherigen Kopf zählt für 16 dichte Queries 72.814 `occludes`-Aufrufe, 111.156 Aufbereitungen von Batchlayouts/Instanztransforms, 1.130.539 `_ray_mesh`-Aufrufe und 83.404 Dreieckskontaktprüfungen. Bis zu 4.622 Sichtstrahlen pro Query wiederholten dieselben Fremdgeometrie- und Posezugriffe; verdeckte Kandidaten erzeugten eine aufwendige Kontakt-/Verdeckungskette. Die inklusiven Profiltimings überlappen und sind kein unabhängiger Summen- oder Vergleichszeitnachweis. Original: `profile-previous-gl-tcp/query.json`.

- Höchstens fünf ausgewählte Pixel innerhalb des gezeichneten Kreises werden zunächst mit der nativen TriangleMesh-BVH auf echte Körperflächen geprüft. Jeder Treffer geht durch die bestehende Welt-/Fremdmesh-Verdeckungsprüfung. Ein Fehlschlag verwirft kein Ziel: die vollständige Silhouettensuche bleibt für bewegte Randteile und Lücken erhalten. Die Grenze von fünf betrifft diesen Schnellpfad, nicht sämtliche Strahlen des Fallbacks.
- Die bisherige Zielhysterese wird früher geprüft, wenn der kleinste Kandidatenscore bereits beweist, dass das alte sichtbare Ziel innerhalb der bestehenden 0,12-Toleranz bleibt. Zielwechsel und Fortschrittsregeln sind unverändert.
- Während genau einer synchronen Query werden sichtbare Teile, Bounds, Layouts und inverse Instanztransforms einmal aufbereitet. Animierte EyeExpression-Batches verwenden ihren vorhandenen aktuellen CPU-Posebuffer. Unveränderliche RuntimeVoxelBatch-Geometrie bleibt lokal; Parentbewegung wird jede Query neu erfasst. Ersetzte Meshressourcen werden auch bei gleicher Instanzzahl erkannt.
- Native BVHs werden pro Mesh erzeugt; projizierte Dreiecke/Morton-Struktur erst bei tatsächlichem Silhouettenfallback. Node-/Batch-/Meshcaches sind jeweils auf 512 Einträge begrenzt und verwenden schwache Besitzer. Query-Ende entfernt Pose-/Layoutdaten, Fremdakteurverweise und den letzten akzeptierten Kontakt, ohne den bereits zurückgegebenen Kontakt zu verändern. Tote Besitzer werden am nächsten Query-Start entfernt.

Es werden keine Sichtentscheidungen oder Strahltreffer zwischen Queries gespeichert. Das verworfene Nächster-Treffer-Querycacheexperiment bleibt verworfen; seine negativen Originale im historischen Bericht sind kein positiver Nachweis dieser Korrektur.

## Umgebung und identische Eingaben

Host `9583cdd44932`, AMD EPYC 9V74 80-Core Processor, `Linux-6.18.44-x86_64-with-glibc2.39`; Godot 4.6.3 official `7d41c59c457bd5a245092b4e7eb2d833e3b3f8c3`, Engine-SHA256 `f64d4ed19fc9df9440321653fcc80df8c6e365ba7b6de0a29e2cfa9fa71bfeb3`. GL: Mesa 25.2.8 / llvmpipe LLVM 20.1.2; Forward+: echtes Vulkan 1.4.318 / llvmpipe, kein GL-Fallback. TCP-Xvfb mit 1920×1080; Engine unverändert, die lokale Xvfb-Kopie benutzt nur einen angepassten XKB-Helferpfad (Digest in `environment.json`).

Alle vergleichenden und finalen positiven Läufe erfolgen seriell unter dem mit R32-01 abgestimmten exklusiven `/tmp/voxelverse-r32-db514e109ac6-heavy.lock`, CPU-Affinität 0–3, `LP_NUM_THREADS=2`, `LIBGL_ALWAYS_SOFTWARE=1` und derselben Vulkan-ICD. Kein paralleler eigener Heavy-Lauf. Die Query-Rohberichte enthalten Affinität, Renderer-Umgebung sowie `/proc/stat` vor/nach; dies kontrolliert die eigene Last und dokumentiert den geteilten Host, garantiert aber keine exklusive physische Maschine. Slotfreigabe durch R32-01: [#137, 5990454033](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-5990454033).

Ein unveränderter Referenzsave `query-reference.json`, SHA256 `502b9a100e011613c961de2bbfeba3e663acdb81119557fc65c6db5993f8d2a1`, Seed 15838, Produktionsart 2771337, Objektseeds 950–961 und feste Positionen. Die Query-Probe liest den identischen Save in isolierte Nutzerdaten und erzeugt gekennzeichnete Freiraum-Produktionskörper auf dem Legacy-Diagnoseweg. Sie ist keine reguläre Kampagnenroute. Fenster 1280×720, UI 100 %, FOV 66; interne Content-Skalierung bleibt in allen Quellen gleich (1920×1080).

```text
Transform3D(1, 0, 0, 0, 0.97062165, 0.24061096, 0, -0.24061096, 0.97062165, 0, 103.563484, 6.9546685)
```

Je Quelle/Renderer/Tierzahl ein frischer Prozess. `erste Query` ist die tatsächliche erste Messung einschließlich der initialen Mesh-BVH-Kosten. Die zwölf als `cold` gespeicherten Werte starten jeweils eine neue Silhouette und setzen den Scanner zurück; nach dem ersten Wert ist der engineinterne Meshcache bereits warm. Sie sind deshalb Scanner-kalt, nicht zwölf unabhängige Engine-Kaltstarts. Anschließend 100 warme Queries mit echter Produktionsanimation, gleicher Zeitschrittfolge und beibehaltenem Ziel. p50 ist die obere Medianposition des unveränderten Helfers; p95/p99 verwenden nearest-rank. Bei n=12 sind p95/p99 zwangsläufig das Maximum; diese kleinen Stichproben sind keine Schätzung seltener Langzeitspitzen.

## Gepaarte Einzel- und 12-Tier-Abfragen

Alle Zeiten in ms. Rohwerte, Strahlzahlen, Ziele und Ränge unter `triple-*/query.json`; Prozesse und Lastdaten unter `run.json`. Die historischen 36,373→472,278 ms (GL) und 27,613→354,903 ms (Forward+) bleiben im bisherigen Bericht erhalten. Die folgenden Werte stammen aus der neuen identischen Dreifachserie; keine Vermischung verschiedener Hosts oder Messreihen.

| Renderer | Quelle | Tiere | Erste Query | Scanner-kalt p50 | p95 | p99 | max (n=12) |
|---|---|---|---|---|---|---|---|
| GL | Basis | 1 | 40,924 | 25,452 | 40,924 | 40,924 | 40,924 |
| GL | Basis | 12 | 64,180 | 52,814 | 64,180 | 64,180 | 64,180 |
| GL | Bisherige Sichtkorrektur | 1 | 38,463 | 25,751 | 38,463 | 38,463 | 38,463 |
| GL | Bisherige Sichtkorrektur | 12 | 302,000 | 301,565 | 381,548 | 381,548 | 381,548 |
| GL | Optimiert | 1 | 14,068 | 0,593 | 14,068 | 14,068 | 14,068 |
| GL | Optimiert | 12 | 15,924 | 4,321 | 15,924 | 15,924 | 15,924 |
| Forward+ | Basis | 1 | 42,372 | 25,788 | 42,372 | 42,372 | 42,372 |
| Forward+ | Basis | 12 | 62,100 | 52,778 | 72,258 | 72,258 | 72,258 |
| Forward+ | Bisherige Sichtkorrektur | 1 | 39,314 | 24,083 | 39,314 | 39,314 | 39,314 |
| Forward+ | Bisherige Sichtkorrektur | 12 | 331,828 | 331,828 | 362,714 | 362,714 | 362,714 |
| Forward+ | Optimiert | 1 | 13,262 | 0,522 | 13,262 | 13,262 | 13,262 |
| Forward+ | Optimiert | 12 | 19,329 | 3,704 | 19,329 | 19,329 | 19,329 |

| Renderer | Quelle | Tiere | Warm p50 | p95 | p99 | max (n=100) | >33/>50/>100 |
|---|---|---|---|---|---|---|---|
| GL | Basis | 1 | 0,407 | 0,624 | 0,839 | 0,875 | 0/0/0 |
| GL | Basis | 12 | 25,997 | 31,044 | 35,117 | 35,708 | 2/0/0 |
| GL | Bisherige Sichtkorrektur | 1 | 0,403 | 0,582 | 0,630 | 0,640 | 0/0/0 |
| GL | Bisherige Sichtkorrektur | 12 | 86,682 | 355,660 | 364,974 | 374,973 | 100/100/32 |
| GL | Optimiert | 1 | 0,549 | 0,803 | 0,863 | 1,393 | 0/0/0 |
| GL | Optimiert | 12 | 3,017 | 3,835 | 4,280 | 4,386 | 0/0/0 |
| Forward+ | Basis | 1 | 0,379 | 0,632 | 0,882 | 0,914 | 0/0/0 |
| Forward+ | Basis | 12 | 25,545 | 29,273 | 34,945 | 36,195 | 4/0/0 |
| Forward+ | Bisherige Sichtkorrektur | 1 | 0,382 | 0,597 | 0,678 | 0,915 | 0/0/0 |
| Forward+ | Bisherige Sichtkorrektur | 12 | 85,513 | 360,086 | 382,486 | 391,404 | 100/100/30 |
| Forward+ | Optimiert | 1 | 0,467 | 0,716 | 1,474 | 2,141 | 0/0/0 |
| Forward+ | Optimiert | 12 | 2,737 | 3,391 | 4,651 | 4,810 | 0/0/0 |

GL dicht warm p95: Basis 31,044, bisher 355,660, optimiert 3,835 ms. Reduktion gegenüber der bisherigen Korrektur 98,922 %.
Forward+ dicht warm p95: Basis 29,273, bisher 360,086, optimiert 3,391 ms. Reduktion gegenüber der bisherigen Korrektur 99,058 %.

Einzelabfragen warm p95: GL Basis 0,624 / bisher 0,582 / optimiert 0,803 ms; Forward+ Basis 0,632 / bisher 0,597 / optimiert 0,716 ms. Der absolute Mehrpreis gegenüber der Basis beträgt 0,179 bzw. 0,084 ms. Er wird nicht als Verbesserung ausgegeben. Die tatsächlichen ersten Queries sinken in beiden Tierzahlen deutlich.

Der isolierte dichte Scannerkostenblocker ist in dieser Serie beseitigt. Kalte Silhouettenrandfälle unten bleiben teurer; die Messung ersetzt keine Kampagnen-/Framezeitabnahme.

## Fachtests und Lebenszyklus

Import und Quellenverträge erfolgreich; `scan_circle_test`, `creature_scan_test`, `nest_discovery_test`, `wildlife_colony_test` und abschließende Quellenintegrität grün auf dem final geprüften Optimierungsstand. Originale: `focused-final-head/results.json` und Fachlogs. Die Registry bleibt unverändert bei 267 Tests auf der Fachbasis. Die inzwischen erweiterten Integrationsgates gehören zu R32-01.

Der bestehende `scan_circle_test` prüft zusätzlich: echter MultiMesh-Kontakt und passender Pixel (<0,002 px Projektionsfehler), Verdeckung vor/hinter dem Endpunkt, gleiche Instanzzahl/Identität mit geänderter Pose im selben Frame, aktuellen CPU-Eye-Posebuffer, Parentbewegung, Austausch der Meshressource, Hide/Show, Entladen und Entfernen schwacher Cacheeinträge sowie Leeren aller Querydaten. Der neue Kontakt-Teardowntest reproduziert den intern gehaltenen Fallbackkontakt vor dem Fix und prüft nachher sowohl Freigabe als auch unveränderten Rückgabekontakt. Negativer Originalbeleg unter `negative/focused-teardown-before/`; diagnostischer schmutziger Teststand, kein positiver Liefernachweis.

Der konservative `--changed-since ... --plan --summary` wählt FULL 267/Main; er führt keine Tests aus. Volle Suite, gemeinsame Produktions-/Reisekette, Pflichtgates, native Exporte und geänderter Merge-Tree bleiben bei R32-01. Keine Tests/Assertions/Deadlines abgeschwächt, keine Registrierung doppelt angelegt.

## Native gerenderte Gegenproben

| Renderer | Fall | Quelle | Sprache | Exit | Frames | Ergebnis |
|---|---|---|---|---|---|---|
| Forward+ | motion | Optimiert | de | 0 | 696 | grün |
| GL | motion | Optimiert | de | 0 | 696 | grün |
| Forward+ | motion | Optimiert | en | 0 | 696 | grün |
| GL | motion | Optimiert | en | 0 | 696 | grün |
| Forward+ | nests | Optimiert | de | 0 | 176 | grün |
| GL | nests | Optimiert | de | 0 | 176 | grün |
| Forward+ | nests | Optimiert | en | 0 | 176 | grün |
| GL | nests | Optimiert | en | 0 | 176 | grün |
| Forward+ | occlusion | Basis | de | 1 | 0 | exakt 4 erwartete Negative |
| GL | occlusion | Basis | de | 1 | 0 | exakt 4 erwartete Negative |
| Forward+ | occlusion | Bisherige Sichtkorrektur | de | 0 | 0 | grün |
| GL | occlusion | Bisherige Sichtkorrektur | de | 0 | 0 | grün |
| Forward+ | occlusion | Optimiert | de | 0 | 0 | grün |
| GL | occlusion | Optimiert | de | 0 | 0 | grün |
| Forward+ | world | Optimiert | de | 0 | 76 | grün |
| GL | world | Optimiert | de | 0 | 76 | grün |

Die Basis-Sichtprüfung bleibt negativ und reproduziert unter beiden Renderern exakt vier Fehler: leere fremde Kapsel blockiert sichtbares Tier; sichtbarer Fremdteil außerhalb der Kapsel verdeckt nicht; näherer Punkt behält falschen Pixel; unsichtbarer Nestzylinder erfindet einen Kontakt. Nur Exit 1 plus genau diese Fehlermenge gilt als erwartetes Negativ. Parser-/Leakfehler werden nicht als Vorhererfolg akzeptiert. Bisheriger und optimierter Kopf bestehen dieselben Gegenproben.

DE/EN-Bewegung je Renderer: 18 Kombinationen (800×600/1280×720/1920×1080 × UI100/125/150 % × Körper0,65/1,35), je 30 animierte Randqueries und insgesamt 696 gerenderte Schritte. Mittelpunkt/Mehrfachziele, volle/teilweise Verdeckung, unsichtbare Geometrie, Reichweite, FOV42/88, Pause, bekannte Art/ein Reward, Zielwechsel und kurzer Sichtverlust ohne Fortschrittsübertragung bleiben positiv. Eigenes Beobachtermodell in einigen Verdeckungsbildern gehört zur Kamerafigur und ist kein gescanntes fremdes Ziel.

Die Matrix verwendet kontrollierte Produktionskörper/-Animation/-Scanner/-HUD in einer beschrifteten Freiraumfixture. UI150 ist dort direkt gesetzt; der reguläre Einstellungsanschluss und spontane Kampagnen-Tierrandfälle bleiben Integrations-/Abnahmeaufgaben. Die Aufnahme ist kein vollständiger HUD-Lokalisierungsnachweis.

### GL / DE bewegte Silhouettenränder

[Film](final-motion-de-gl_compatibility/capture.mp4), [Rohmessungen](final-motion-de-gl_compatibility/measurements.json), native Originalbilder unter `final-motion-de-gl_compatibility/native/`. Kleinste physische Überlappung 0.520660400 px. Kalte Query 25,625–71,536 ms; schlechteste warme p95 2,724 ms. Sämtliche Maxima und Ausreißer sind erhalten.

| Fenster | UI | Körper | Kalt | Warm p50 | p95 | p99 | max (n=30) |
|---|---|---|---|---|---|---|---|
| 800×600 | 100 % | 0,65 | 26,369 | 0,819 | 1,331 | 25,423 | 25,423 |
| 800×600 | 100 % | 1,35 | 26,119 | 1,068 | 1,683 | 29,202 | 29,202 |
| 800×600 | 125 % | 0,65 | 25,625 | 0,898 | 1,914 | 26,188 | 26,188 |
| 800×600 | 125 % | 1,35 | 49,492 | 1,237 | 2,599 | 2,952 | 2,952 |
| 800×600 | 150 % | 0,65 | 49,604 | 1,045 | 1,761 | 3,586 | 3,586 |
| 800×600 | 150 % | 1,35 | 66,326 | 1,227 | 2,724 | 3,823 | 3,823 |
| 1280×720 | 100 % | 0,65 | 57,815 | 0,849 | 1,313 | 1,535 | 1,535 |
| 1280×720 | 100 % | 1,35 | 55,168 | 1,083 | 1,466 | 1,470 | 1,470 |
| 1280×720 | 125 % | 0,65 | 52,346 | 1,029 | 1,309 | 1,312 | 1,312 |
| 1280×720 | 125 % | 1,35 | 53,409 | 1,102 | 1,646 | 1,681 | 1,681 |
| 1280×720 | 150 % | 0,65 | 71,536 | 1,126 | 1,682 | 1,792 | 1,792 |
| 1280×720 | 150 % | 1,35 | 49,964 | 1,164 | 1,411 | 2,715 | 2,715 |
| 1920×1080 | 100 % | 0,65 | 54,000 | 0,915 | 1,644 | 2,042 | 2,042 |
| 1920×1080 | 100 % | 1,35 | 50,111 | 0,900 | 1,304 | 1,314 | 1,314 |
| 1920×1080 | 125 % | 0,65 | 53,626 | 0,917 | 1,322 | 1,730 | 1,730 |
| 1920×1080 | 125 % | 1,35 | 54,781 | 1,024 | 1,458 | 1,495 | 1,495 |
| 1920×1080 | 150 % | 0,65 | 51,618 | 1,031 | 1,547 | 1,702 | 1,702 |
| 1920×1080 | 150 % | 1,35 | 51,447 | 1,138 | 1,448 | 1,662 | 1,662 |

### GL / EN bewegte Silhouettenränder

[Film](final-motion-en-gl_compatibility/capture.mp4), [Rohmessungen](final-motion-en-gl_compatibility/measurements.json), native Originalbilder unter `final-motion-en-gl_compatibility/native/`. Kleinste physische Überlappung 0.520629883 px. Kalte Query 23,666–58,393 ms; schlechteste warme p95 1,937 ms. Sämtliche Maxima und Ausreißer sind erhalten.

| Fenster | UI | Körper | Kalt | Warm p50 | p95 | p99 | max (n=30) |
|---|---|---|---|---|---|---|---|
| 800×600 | 100 % | 0,65 | 25,422 | 0,818 | 1,296 | 26,211 | 26,211 |
| 800×600 | 100 % | 1,35 | 23,666 | 1,008 | 1,764 | 27,591 | 27,591 |
| 800×600 | 125 % | 0,65 | 24,232 | 0,734 | 1,555 | 25,818 | 25,818 |
| 800×600 | 125 % | 1,35 | 53,154 | 1,152 | 1,659 | 3,241 | 3,241 |
| 800×600 | 150 % | 0,65 | 49,092 | 1,123 | 1,321 | 1,646 | 1,646 |
| 800×600 | 150 % | 1,35 | 55,650 | 1,158 | 1,937 | 2,030 | 2,030 |
| 1280×720 | 100 % | 0,65 | 50,675 | 0,867 | 1,454 | 1,650 | 1,650 |
| 1280×720 | 100 % | 1,35 | 51,643 | 1,090 | 1,467 | 1,520 | 1,520 |
| 1280×720 | 125 % | 0,65 | 51,522 | 1,147 | 1,569 | 1,846 | 1,846 |
| 1280×720 | 125 % | 1,35 | 54,064 | 1,145 | 1,602 | 1,929 | 1,929 |
| 1280×720 | 150 % | 0,65 | 57,126 | 1,143 | 1,581 | 1,707 | 1,707 |
| 1280×720 | 150 % | 1,35 | 52,390 | 1,207 | 1,488 | 1,795 | 1,795 |
| 1920×1080 | 100 % | 0,65 | 49,099 | 0,894 | 1,558 | 3,285 | 3,285 |
| 1920×1080 | 100 % | 1,35 | 49,964 | 0,905 | 1,328 | 1,494 | 1,494 |
| 1920×1080 | 125 % | 0,65 | 52,528 | 1,014 | 1,189 | 1,849 | 1,849 |
| 1920×1080 | 125 % | 1,35 | 58,393 | 1,066 | 1,372 | 1,388 | 1,388 |
| 1920×1080 | 150 % | 0,65 | 48,498 | 1,033 | 1,323 | 1,426 | 1,426 |
| 1920×1080 | 150 % | 1,35 | 51,727 | 1,044 | 1,393 | 1,744 | 1,744 |

### Forward+ / DE bewegte Silhouettenränder

[Film](final-motion-de-forward_plus/capture.mp4), [Rohmessungen](final-motion-de-forward_plus/measurements.json), native Originalbilder unter `final-motion-de-forward_plus/native/`. Kleinste physische Überlappung 0.520660400 px. Kalte Query 24,739–65,493 ms; schlechteste warme p95 2,107 ms. Sämtliche Maxima und Ausreißer sind erhalten.

| Fenster | UI | Körper | Kalt | Warm p50 | p95 | p99 | max (n=30) |
|---|---|---|---|---|---|---|---|
| 800×600 | 100 % | 0,65 | 26,008 | 0,759 | 1,172 | 26,151 | 26,151 |
| 800×600 | 100 % | 1,35 | 24,739 | 1,097 | 1,794 | 26,078 | 26,078 |
| 800×600 | 125 % | 0,65 | 25,458 | 0,876 | 1,228 | 25,308 | 25,308 |
| 800×600 | 125 % | 1,35 | 50,937 | 1,185 | 1,373 | 2,773 | 2,773 |
| 800×600 | 150 % | 0,65 | 52,289 | 1,038 | 1,188 | 1,301 | 1,301 |
| 800×600 | 150 % | 1,35 | 50,211 | 1,200 | 1,565 | 1,582 | 1,582 |
| 1280×720 | 100 % | 0,65 | 65,493 | 0,832 | 1,197 | 1,213 | 1,213 |
| 1280×720 | 100 % | 1,35 | 53,406 | 1,076 | 1,445 | 1,534 | 1,534 |
| 1280×720 | 125 % | 0,65 | 56,468 | 1,022 | 1,586 | 1,932 | 1,932 |
| 1280×720 | 125 % | 1,35 | 49,712 | 1,080 | 1,706 | 1,721 | 1,721 |
| 1280×720 | 150 % | 0,65 | 51,982 | 1,151 | 1,635 | 1,841 | 1,841 |
| 1280×720 | 150 % | 1,35 | 52,666 | 1,121 | 1,322 | 1,485 | 1,485 |
| 1920×1080 | 100 % | 0,65 | 50,768 | 0,847 | 1,895 | 1,992 | 1,992 |
| 1920×1080 | 100 % | 1,35 | 54,576 | 0,887 | 1,181 | 1,275 | 1,275 |
| 1920×1080 | 125 % | 0,65 | 49,121 | 0,944 | 1,490 | 1,713 | 1,713 |
| 1920×1080 | 125 % | 1,35 | 52,344 | 0,999 | 2,107 | 2,165 | 2,165 |
| 1920×1080 | 150 % | 0,65 | 50,010 | 1,011 | 1,446 | 1,962 | 1,962 |
| 1920×1080 | 150 % | 1,35 | 49,380 | 1,040 | 1,570 | 1,667 | 1,667 |

### Forward+ / EN bewegte Silhouettenränder

[Film](final-motion-en-forward_plus/capture.mp4), [Rohmessungen](final-motion-en-forward_plus/measurements.json), native Originalbilder unter `final-motion-en-forward_plus/native/`. Kleinste physische Überlappung 0.520660400 px. Kalte Query 24,067–62,785 ms; schlechteste warme p95 2,637 ms. Sämtliche Maxima und Ausreißer sind erhalten.

| Fenster | UI | Körper | Kalt | Warm p50 | p95 | p99 | max (n=30) |
|---|---|---|---|---|---|---|---|
| 800×600 | 100 % | 0,65 | 24,067 | 0,752 | 1,114 | 29,740 | 29,740 |
| 800×600 | 100 % | 1,35 | 34,585 | 0,984 | 2,637 | 26,043 | 26,043 |
| 800×600 | 125 % | 0,65 | 25,078 | 0,858 | 1,364 | 25,435 | 25,435 |
| 800×600 | 125 % | 1,35 | 51,970 | 1,147 | 1,672 | 3,181 | 3,181 |
| 800×600 | 150 % | 0,65 | 50,925 | 1,088 | 1,465 | 1,600 | 1,600 |
| 800×600 | 150 % | 1,35 | 51,511 | 1,188 | 1,523 | 1,579 | 1,579 |
| 1280×720 | 100 % | 0,65 | 52,988 | 0,851 | 1,247 | 1,493 | 1,493 |
| 1280×720 | 100 % | 1,35 | 51,622 | 1,187 | 1,713 | 3,115 | 3,115 |
| 1280×720 | 125 % | 0,65 | 51,445 | 1,126 | 1,633 | 2,420 | 2,420 |
| 1280×720 | 125 % | 1,35 | 62,785 | 1,129 | 1,536 | 1,548 | 1,548 |
| 1280×720 | 150 % | 0,65 | 54,358 | 1,190 | 1,887 | 1,912 | 1,912 |
| 1280×720 | 150 % | 1,35 | 51,277 | 1,151 | 2,383 | 3,654 | 3,654 |
| 1920×1080 | 100 % | 0,65 | 49,456 | 0,866 | 1,757 | 4,031 | 4,031 |
| 1920×1080 | 100 % | 1,35 | 54,413 | 0,896 | 1,114 | 1,289 | 1,289 |
| 1920×1080 | 125 % | 0,65 | 48,851 | 0,891 | 1,565 | 1,732 | 1,732 |
| 1920×1080 | 125 % | 1,35 | 55,588 | 1,022 | 1,310 | 1,360 | 1,360 |
| 1920×1080 | 150 % | 0,65 | 60,472 | 1,039 | 1,399 | 1,418 | 1,418 |
| 1920×1080 | 150 % | 1,35 | 49,889 | 1,010 | 1,148 | 1,176 | 1,176 |

### Nester, Entladen und Neustart

Die vier DE/EN-Nestpaarläufe verwenden zwei gleichzeitig sichtbare gleichartige Produktionsnester mit getrennten IDs. Unbekannte Labels vor Scan, erster Scan, erster echter Kindprozessneustart, Entladen/Neuerzeugen, geänderter gezielter Zähler, zweites Nest weiterhin unbekannt ohne übertragenen Fortschritt, zweiter Scan und zweiter Prozessneustart sind grün. Je 176 Frames; beide Neustarts jeweils Exit 0. Die Zähler 4/2/3 sind eingespeiste Testwerte, keine behauptete generierte Population. Die Rollenlabel-Korrektur und unveränderte Quelldaten bleiben geprüft.

| Renderer | Gezieltes Nestlabel | Kanonisch vorher | Geladen | Nach Reload | Scanschritte | Zielverlust | Fresh-process Exit |
|---|---|---|---|---|---|---|---|
| GL | Nest: Orbivek · 3 Bewohner | 3 | 3 | 3 | 76 | 1 | 0 |
| Forward+ | Nest: Senuvek · 4 Bewohner | 4 | 4 | 4 | 76 | 1 | 0 |

Die separaten Weltläufe starten den regulären öffentlichen Kugelkampagnenweg, prüfen echte generierte kanonische lebende, nicht reservierte Koloniemitglieder, speichern, prüfen einen frischen Prozess und entladen/laden öffentlich vollständig neu. Der erste Tick hat jeweils keinen Kontakt; der tatsächliche Zielverlust setzt Fortschritt zurück. Karte vor/nach Entdeckung bleibt auf eigene Heimat-/verbündete Orte begrenzt, ohne fremde Nestnamen/Zähler/IDs. Die Weltsaves entstehen separat pro Lauf; ihre Ladezeiten sind kein gepaarter Scannerperformancevergleich.

Alle Filme sind aus den protokollierten Prüfschritten mit festem 30-fps-Zeitmaß erzeugt; das ist keine gemessene Spielbildrate. Benannte PNGs und jeder 30. Randframe behalten zusätzlich die native Fensterauflösung. Die vollständigen Matrixframes sind im Film enthalten; der öffentliche Kugelweg erhält seine native 1600×900-Auflösung. Originallogs, Messdaten und Quellmanifeste unverändert archiviert.

## Negative Vorbereitungen und Wiederholung

`pre-teardown/` enthält Rohberichte/Logs/Quellmanifeste des vollständig positiven ersten Optimierungsstands `8145596`; diese Werte werden nicht als finaler Stand ausgegeben. Der anschließend reproduzierte Kontaktlebenszyklusfehler führte zum finalen Teardownfix und zur Wiederholung von Fachtests, kompletter Dreifach-Queryserie und sämtlichen optimierten nativen Fällen. Die unveränderten Basis-/Bisher-Sichtgegenproben wurden aus ihren stabilen ursprünglichen SourceRuns übernommen.

`negative/` erhält fehlgeschlagene Xvfb-Vorbereitung (keine Spielprüfung), frühere schmutzige Diagnoseproben, Headless-Fixturefehler und typisierte Array-Helferfehler. Der Lifecycle-Batchaufbau wurde auf denselben Bulkbuffer wie die Produktion umgestellt, weil einzelne RenderingServer-Setter im Headlessdriver keinen auslesbaren Buffer liefern; Assertions bleiben erhalten. Die abschließende Array-Konstruktion ist ausdrücklich typisiert. Kein unvollständiger oder fehlgeschlagener Lauf zählt als positiver Nachweis.

## Reproduktion und Übergabe an R32-01

Die Originalbefehle stehen in jedem `run.json`, die ausgeführte serielle Host-Orchestrierung in `host-runner.py`. Dafür in einem unabhängigen Workspace die drei genannten Gitköpfe auschecken, die fünf Query-Helfer aus dem finalen Codekopf identisch in Basis/Bisher übernehmen, Sicht-Oracle ebenfalls unverändert übernehmen, Ressourcen einmal je Checkout importieren und isolierte Nutzerdaten/Ausgaben außerhalb aller Quellen verwenden. Dieselbe Referenzsavedatei, Engine, Software-ICD, TCP-Xvfb und Hostlastparameter benutzen. Beispiel unter gehaltenem gemeinsamen Lock und deklarierter Umgebung:

```bash
python tools/review_r32_05_query.py --godot /absolute/godot --project /absolute/checkout \
  --output /absolute/new-output --save /absolute/query-reference.json \
  --renderer gl_compatibility --count 12
python tools/review_r32_05_capture.py --godot /absolute/godot --project /absolute/checkout \
  --output /absolute/new-native-output --renderer forward_plus --case motion --language en
```

R32-01 erhält den sauberen veröffentlichten Lieferkopf und Tree über #265/#137; er ersetzt den gesperrten `1d872b9e` zur Besitzerprüfung. Die SourceRuns belegen den hier genannten Codekopf; ein neuer Integrations-Merge-Tree gilt dadurch nicht als geprüft. Kein erforderlicher Produktpatch an Controller, Save, Population, Karte oder Lokalisierung. Keine neuen Registryeinträge; bestehender `scan_circle_test` enthält die Lebenszyklusfälle. Frühere optionale Workflow-Patches bleiben historische Anschlüsse, keine direkte `.github`-Änderung dieser Fortsetzung. Gemeinsame Integration, aktuelle Gates, Exporte, Ziel-PC-/Bedienabnahme und Issue-Abschluss liegen weiterhin bei R32-01/Lars.
