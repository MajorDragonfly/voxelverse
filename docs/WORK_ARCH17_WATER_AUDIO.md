# ARCH-17 – begrenzte Ufersuche und radiales Wasser-Audio

Stand: 10. September 2026. Fortsetzung von [PR #56](https://github.com/MajorDragonfly/voxelverse/pull/56), auf dessen veröffentlichtem Commit `1355b741d56164fa277276edf4473493d3b08889`; gemeinsame Basis weiterhin `main` `ea900f2e09946660694a9e59399b4680a5655a85`.

## Gelieferter Umfang

Der vorhandene `world_audio.gd` bleibt Besitzer von Schritten, Umgebungsgeräuschen, Uferstimme und Unterwasserfilter. Der gemeinsame Kugelhost besitzt weiterhin den Radialadapter und `Water.audio_sample` / `Water.view_sample`. Es gibt keinen zweiten AudioManager, Wasser- oder Speicherdienst. Audiodateien und Lautstärkeeinstellungen ändern sich nicht.

Die frühere Ufersuche führte 25 Oberflächenabfragen plus Spieler-/Kameraabfrage auf einmal aus. Jetzt arbeitet ein flüchtiger `shore_search.gd` mit höchstens zwei Uferproben pro Physiktick. Insgesamt entstehen höchstens vier Oberflächenabfragen im Audio-Physikschritt; Spieler- und Kameraabfrage behalten ihren vorhandenen 0,35-Sekunden-Takt. Beim Erstbinden erfolgt keine doppelte Umfeldaktualisierung mehr. Ein Objekt mit 25 festen Probeorten ersetzt die verschachtelte Sofortsuche; es gibt keine wachsende Queue und keine zusätzlichen Threads.

Ein Suchlauf umfasst unverändert Mitte sowie acht Richtungen bei 7, 18 und 30 Metern. Er veröffentlicht erst nach Abschluss die nächste gültige Wasserstelle. Im vorhandenen Kugelkontext liegen diese Punkte im lokalen Tangentialrahmen, Wasserhöhe und Tiefe stammen aus demselben Oberflächenmodell wie die Unterwasseransicht. Ein unvollständiger Suchlauf darf über mehrere Aktualisierungsintervalle bestehen bleiben: auch 10-Hz-Prüfschritte liefern das vollständige Ergebnis. Das 40-Meter-Hörlimit bleibt bestehen.

## Gültigkeit und Lebenszyklus

- Quellenbindung umfasst Szene, Spieler, Kamera, Adapter, Körper-ID, Wasserport und wirksamen expliziten Probecallback. Änderungen stoppen alte Stimmen und verwerfen ausstehende Abfragen. Auch ein Körperwechsel unter demselben Adapter oder ein neuer Kameraknoten gilt als neue Quelle.
- Callback-Methoden eines abgehängten, ausgehenden oder zum Löschen vorgemerkten Szenenknotens sind keine gültigen Wasserquellen für die nächste Szene. Eigenständige Prüfsampler bleiben möglich.
- Ein radial markierter Spieler fällt bei fehlendem Adapter oder Wasserport nie in den alten X/Z-Generator zurück. Der alte Anschluss bleibt für ausdrücklich planare historische Prüfszenen vorhanden.
- Beim bestehenden Ursprungssignal werden Listenerbezug, bestes Zwischenergebnis, aktuelle Wasserposition und räumliche Stimmen gemeinsam verschoben. Die reine Translation verwirft keinen gültigen Suchfortschritt.
- Bei mehr als acht Metern Bewegung des Listeners gegenüber dem Suchzentrum wird die ausstehende Suche verworfen und eine neue Umfeldaktualisierung angefordert. Teleport/Respawn setzt zusätzlich die Bewegungsrückmeldung zurück; dadurch entstehen keine künstlichen Schrittfolgen.
- Pause hält den bestehenden pausable Audio-Director an. Reset, Szenenwechsel und fehlender Spieler entfernen die flüchtige Suche; nichts wird gespeichert oder nach einer Pause in einer großen Schleife nachgeholt.

## Gemeinsame Unterwassergrenze

`water_immersion.gd` enthält dieselbe kleine Tiefenhysterese für Bild und Ton: Eintritt bei mehr als 4 cm unter der lokalen Wasserfläche, Austritt bei höchstens 5 mm. Oberhalb der Wasserfläche bleibt Luft. Die Kameraansicht behält ihr bisheriges Verhalten; der Audiofilter verwendet jetzt dieselben Grenzen. Bei einem Kamerawechsel beginnt die Hysterese neu.

Die unterschiedlichen Aktualisierungsraten bleiben bestehen: Die Ansicht folgt jedem Darstellungsframe, Audio fragt im bisherigen 0,35-Sekunden-Takt ab und blendet den Filter weich ein/aus. Gleiche Regeln bedeuten keine harte zeitgleiche Umschaltung jedes Frames. Die vorhandene `ground_ready`-Prüfung des Audio-Wasserports bleibt erhalten; nicht verfügbare Kollision wird durch diese Optimierung nicht freigegeben.

## Nachweise am Abschlussstand

Godot 4.6.3, Linux, isolierte Nutzerdaten und strenge Scriptfehler-/Leakprüfung:

| Prüfung | Ergebnis | Dauer |
|---|---|---:|
| `audio/spherical_water_audio_test` | bestanden | 1,319 s |
| `audio/audio_runtime_test` | bestanden | 14,628 s |
| `audio/audio_scene_lifecycle_test` | bestanden | 1,218 s |
| `underwater_view_test` | bestanden | 1,218 s |

Der neue Fachtest verwendet den realen Audio-Director, echte Kamera/Atmosphäre, `campaign_water.gd` und den Radialadapter mit einem analytischen See auf einer Kugel mit Terra-Radius. Er prüft positive/negative Tiefe entlang Welt-X bei unverändertem Welt-Y, Bild-/Tongrenzen, trockenen Boden unter dem Wasserniveau, Kamerawechsel, langsame Aktualisierung, Quellenwechsel, Ursprungskorrektur, fehlenden Wasserport, fehlenden Adapter, Pause, Kamerasprung und eine noch lebende ausgehende Szene. Die asymmetrische Uferprobe behält dieselbe nächste Wasserstelle nach exakt 25 Abfragen. Die harte Obergrenze von vier Abfragen pro Physiktick wurde beobachtet und geprüft.

Die bestehenden Tests ergänzen echte Schritte auf Holzkollision, Sprung/Landung, Schwimmen, Filterwechsel, Pause, begrenzte Audiostimmen, ausgehängte Spieler und Wiederherstellung des Kamera-Environment. Die frühere Pflanzen-/Dorf-/Speicherlieferung bleibt dokumentiert in [WORK_ARCH17_POPULATION_BUDGET.md](WORK_ARCH17_POPULATION_BUDGET.md); ihre unveränderten Spielketten wurden für diese reine Audiofortsetzung nicht erneut ausgeführt.

## CPU-Messung

```bash
godot --headless --path . --script tools/benchmark_shore_audio.gd
python tools/validate_godot.py --godot /pfad/zu/godot --skip-import --skip-main --tests audio/spherical_water_audio_test audio/audio_runtime_test audio/audio_scene_lifecycle_test underwater_view_test
```

Der gleiche Probe funktioniert auf der vorherigen Revision: nur die Benchmarkdatei in deren Checkout übernehmen. Zehn stationäre Suchen, echter `living_planet_v2`-Sampler auf Terra mit Seed 15838, freigegebener synthetischer Kollisionsport, AMD EPYC 9V74 und Godot 4.6.3. Keine GPU, Terrainpublikation oder Ziel-PC-FPS. Andere Chats arbeiten gleichzeitig auf dem Host. Vollständige Rohwerte: [ARCH17_WATER_AUDIO_MEASUREMENTS.json](ARCH17_WATER_AUDIO_MEASUREMENTS.json).

| Messwert | Vorher | Portioniert |
|---|---:|---:|
| Abfragen je gemessenem Einzelaufruf maximal | 27 | 2 |
| Gesamte Abfragen über zehn Suchen | 270 | 270 |
| Einzelaufruf p50 | 3,801 ms | 0,409 ms |
| Einzelaufruf p95 | 4,319 ms | 0,594 ms |
| Größter Einzelaufruf | 4,319 ms | 1,639 ms |
| CPU-Summe je Suche p50 | 3,801 ms | 6,236 ms |
| Einzelaufrufe über zehn Suchen | 10 | 140 |

Der Benchmark misst Umfeldaktualisierung und Suchschritte getrennt; im echten Audio-Physiktick können zwei Umfeld- und zwei Uferabfragen zusammenkommen. Die Lastspitze sinkt, während Verwaltungsaufwand und Fertigstellungsdauer steigen. Ein einzelner Sampleraufruf ist weiterhin nicht zeitlich präemptierbar. `sampling_diagnostics()` zeigt Abfragen, laufende Suche, verbleibende Proben, Generation, abgeschlossene/verworfene Suchen und maximale Schrittzeit.

## Abgrenzung und nächster Anschluss

Dieses Paket liefert den Wasser-/Audioanschluss von ARCH-17 mit begrenzter Ufersuche; ARCH-17 insgesamt bleibt offen. Terrainvorausschau und Freigabe schnellerer Bewegungen benötigen den veröffentlichten ARCH-05-Oberflächenvertrag und ARCH-02-Messung. Langzeit-/Ziel-PC-Routen, einzelne kalte Uploads und zeitlich portionierter Kreaturenmeshaufbau bleiben offen. Saveversionen, Generatorparameter, D1/D2/D3, Siedlungen und die anderen vergebenen ARCH-Pakete wurden nicht verändert.
