# ARCH-02 – Abschlussmessungen vom 10. September 2026

Implementierung: `ff812644ddbe99a348b7182fcd8c55092d930123`, auf Basis `ea900f2` / PR #48. Beide erfolgreichen Abschlussläufe protokollieren diesen Commit mit sauberem Arbeitsverzeichnis. Der längere Fehlversuch lief auf dem vorausgehenden Instrumentierungscommit `f46a233665daa4cba88f252374f149db92535459`; zwischen beiden änderten sich ausschließlich Messung/RAM-Erfassung/Fehlerdiagnostik. [Protokoll und Grenzen](WORK_ARCH02_PERFORMANCE.md).

**Umgebung:** Linux, Godot 4.6.3 stable, AMD EPYC 9V74, Headless/Dummy-Audio, 1920×1080 als konfigurierte Viewportgröße, 60-FPS-Cap. Gemeinsame Entwicklungsumgebung, keine exklusive CPU- oder Datenträgerreservierung. Es wurde kein Frame gerendert; GPU-/VRAM- und Ziel-PC-Werte bleiben offen. Die zwei Abschlussproben liefen nacheinander; andere Chats/Prozesse können die Maschine gleichzeitig belastet haben.

## Funktionierender kurzer Kugelablauf

`--walk-seconds 6 --cycles 2 --settle-frames 60 --stage-timeout 45 --replay <vorheriger Ausgangsstand>`: **bestanden**. Neues Engine-Verfahren lädt denselben archivierten Anfangsstand, geht durch echte Spielerphysik und führt zwei Welt-/Menübesuche durch. Die 6 Sekunden sind die reine Hinwegzeit je Besuch, zuzüglich physischem Rückweg. Kein zehnminütiger Langzeitnachweis.

| Besuch | Welt bereit | Hinweg tatsächlich | Rückkehrabweichung | Hinweg Frame-Median / p95 / p99 |
|---|---:|---:|---:|---:|
| 1 | 14.289 ms | 23,29 m | 0,634 m | 16,64 / 24,63 / 171,89 ms |
| 2 nach Laden | 13.204 ms | 22,57 m | 0,604 m | 16,60 / 28,80 / 118,98 ms |

Die Zeiten „Welt bereit“ sind Ladezeiten, keine normalen Gameplayframes. Der reale Prozess erreichte das fertige Menü nach 2.116 ms und die erste Welt nach insgesamt 16.405 ms (inklusive Menü-Aufenthalt). Die Rückkehr erreicht die definierte Toleranz von 0,65 m; danach erhalten Speichern/Laden die tatsächlich gespeicherte Adresse. Alte Weltszene und Populationshost werden beim Menüwechsel vollständig freigegeben.

Der beobachtete Prozess-RAM-Spitzenwert betrug **435,6 MiB**. Am Ende der Besuche: 501 Terrainblätter, 24 Geländekollisionen, 473/481 Flora-Instanzen, 12/11 aktive Wildtiere und jeweils 16 Nahrungspflanzen. Die Regionscaches lagen bei 78/62 Einträgen. CPU-seitige Terrain-Uploadspitzen: 2,04/1,47 ms; Veröffentlichung: 6,35/4,14 ms. Population-Arbeit hatte Spitzen von 171,90/119,99 ms. Diese Werte liefern Ansatzpunkte für weitere Portionierung; sie sind keine FPS-Prognose für Lars' PC.

Rohwerte: [Bericht](evidence/arch02/verified-route-performance.json), [Frame-Rohdaten](evidence/arch02/verified-route-frames.csv.gz), [RAM](evidence/arch02/verified-route-process-memory.json), [Log](evidence/arch02/verified-route-engine.log). Der [komplette Ausgangsstand](evidence/arch02/verified-route-replay.zip) kann entpackt und mit `--replay <entpackter Ordner>` wiederholt werden. Der Bericht erhält kanonische Körper-/Objektidentitäten und das tatsächliche Rezept.

## Längerer Ablauf: Rückweg blockiert

`--walk-seconds 30 --cycles 2 --stage-timeout 45`: **fehlgeschlagen**, korrekt mit Fehlerstatus. Erster Hinweg: **119,58 m**, 151 Wegpunkte, 30,01 Sekunden. Drei registrierte Ursprungssetzungen/-wechsel bis zum Abbruch; die beiden initialen Setzungen sind darin enthalten. Danach blieb die Figur am Rückweg stehen. Die zusätzliche Rückwegfrist von 105 Sekunden lief ab, ohne die Position zu verändern oder auf den Startpunkt zu setzen.

Letzte stabile Adresse: Körper `body_12252c77442841c6683a9ff27cfc91df`, Fläche 0, `u = 0.0000170577420544192`, `v = -0.879993080542251`, Höhe 20,5119 m. `terrain_wait = false`, keine ausstehenden Terrainuploads und kein Terrainworker. Dadurch lässt sich fehlende Terrainbereitschaft an diesem Punkt ausschließen. Der genaue physische Blocker wurde in diesem älteren Probe noch nicht erfasst; eine konkrete Terrain-/Objektursache ist deshalb **nicht bewiesen**. Der neue Probe protokolliert zusätzlich Zieladresse, Bodenkontakt und Kollisionspartner. Ein physischer Rückweg kann beispielsweise durch eine zuvor heruntergegangene Kante blockiert sein; das ist hier keine nachgewiesene Diagnose.

Hinweg-Framezeiten: Median 16,65 ms, p95 21,35 ms, p99 47,04 ms, Maximum 155,74 ms. Beim Abbruch: 456 Terrainblätter, 24 Kollisionen, 12 Wildtiere, 16 Nahrungspflanzen und 492 Flora-Instanzen. Dieser Lauf zählt ausdrücklich nicht als bestandene längere Rundreise.

Rohwerte und Reproduktion: [Bericht](evidence/arch02/blocked-route-30s-performance.json), [Frames](evidence/arch02/blocked-route-30s-frames.csv.gz), [Log](evidence/arch02/blocked-route-30s-engine.log), [Ausgangsstand](evidence/arch02/blocked-route-replay.zip). Der gespeicherte Fehlerstand ist ein Messbefund, keine allgemeine Aussage, dass man im Spiel nicht manuell zurückgehen könnte. Die Messroute benutzt keine Sprung-/Umgehungsplanung.

## Speicherwachstum

Neun Fälle: **bestanden**. Alle persistierten Pflanzen-IDs und Nahrungsmengen wurden nach normalem Save/Load mit neuen Regionsreadern erneut bestätigt. Das gilt auch nach Überschreiten des 96-Einträge-Caches. Drei Wiederholungen je regulärem Save/Load; Tabellenwerte sind deren Median. „Erste Delta-Charge + Save“ enthält die Einfügung aller Änderungen, bereits dabei nötiges Rückschreiben bei Cacheverdrängung und den gemeinsamen Snapshot. Das ist ein gebündelter Belastungsfall, keine Behauptung, dass ein normaler Autosave immer alle 1.000 Regionen erst dann anlegt; laufendes Streaming kann diese Arbeit vorher verteilen.

| Körper | Geänderte Regionen gesamt | Erste Delta-Charge + Save | Danach Save mit Historie | Laden | Kampagnen-JSON | Neue Regionsblobs |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 0 | 2,20 ms | 2,13 ms | 1,75 ms | 13.254 B | 0 B |
| 1 | 10 | 7,62 ms | 2,72 ms | 2,17 ms | 13.318 B | 13.688 B |
| 1 | 1.000 | 840,05 ms | 4,72 ms | 3,86 ms | 13.318 B | 3.834.636 B |
| 10 | 0 | 3,55 ms | 4,32 ms | 2,87 ms | 22.353 B | 0 B |
| 10 | 10 | 8,40 ms | 5,73 ms | 4,52 ms | 22.993 B | 7.748 B |
| 10 | 1.000 | 459,66 ms | 9,13 ms | 8,06 ms | 22.993 B | 2.633.439 B |
| 100 | 0 | 10,58 ms | 19,99 ms | 13,54 ms | 113.343 B | 0 B |
| 100 | 10 | 47,15 ms | 21,48 ms | 15,95 ms | 113.983 B | 7.748 B |
| 100 | 1.000 | 358,58 ms | 64,05 ms | 54,06 ms | 119.743 B | 1.379.692 B |

Das Kampagnen-JSON bleibt bei mehr Regionen auf demselben Körper klein, weil die Regiondaten in Blobs liegen. Die gesamte Ablage wächst dennoch; neue unveränderliche Indexgenerationen sind in den Blobgrößen enthalten. Mit mehr Körpern wachsen Manifeste, Validierung und normale Save-/Ladekosten. Diese Lastprobe hält explizit einen Store pro Körper; eine globale RAM-Grenze aller Welten wird damit weder implementiert noch abgenommen. Prozess-RAM-Spitze im Speicherlauf: **132,0 MiB**. Keine Grafik-/Terrain-/Dorf-Arbeitslast in diesen Minimalfällen.

[Alle Rohwiederholungen und isolierten Teilzeiten](evidence/arch02/save-scaling-performance.json), [Log](evidence/arch02/save-scaling-engine.log), [RAM](evidence/arch02/save-scaling-process-memory.json). Kopie, Validator, JSON und Write/Verify/Rename sind einzeln gemessen und dürfen nicht zur tatsächlichen gesamten Save-Latenz addiert werden. Caches wurden nicht geleert; keine Ziel-Datenträgerzusage.

## Technische Abnahme / Übergabe

- Import und vorhandene Artquellenprüfung bestanden; Messstatistik mit korrekter Median-/p95-/p99-Berechnung und fehlenden Instrumenten bestanden. Linux-RSS aus dem Engineprozess selbst zusätzlich bestanden. [Prüfberichte](evidence/arch02/import-and-statistics.json), [RAM-Prüfung](evidence/arch02/ram-statistics.json).
- Drei Python-CLI-Prüfungen bestanden: Quellprojekt vor Berichten schützen, vorherige Berichte/Rohdaten erhalten, ungültige Seeds/NaN-/Inf-Längen vor Engine-Aufruf abweisen.
- Die eigene CI führt den kurzen 6-Sekunden-Ablauf und die neun Speicherfälle aus. Veröffentlichte CI-Ergebnisse gehören zum Pull Request und werden durch diese lokalen Ergebnisse nicht ersetzt.
- ARCH-02-Status: **Instrumentation und begrenzte Nachweise geliefert; vollständige Abnahme offen.** Noch erforderlich: lange begehbare Messroute einschließlich Klärung des Rückweg-Blockers, definierter Ziel-PC mit GPU-/Framebeleg, entwickelte Dorf- und Körperreise-Rezepte. Kein neuer Leistungsgrenzwert wurde eingeführt.
- Konkrete Anschlüsse: ARCH-13 für Kosten und vollständige Lebensdauer der Regionsblobs sowie globale Speicherbudgets; ARCH-17 für Terrain-/Populationsspitzen; vorhandener Oberflächen-/Bewegungsstrang für den dokumentierten Rückweg. ARCH-20/23/25 bleiben in ihren eigenen Branches.
