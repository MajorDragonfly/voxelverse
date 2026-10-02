# R32-02 / #167 – Population und Gehroute

**Diagnoselieferung, kein behaupteter Performancegewinn.** Feste Basis
`2a738a4891a8de11d682c469833ade4dc9b01dfb`, Tree
`f2bda4f815df1c73b9d740ca5282917523faf618`; Zielbranch
`agent/integration-r32-20261002`. #167 bleibt offen.

Die vorhandene zentrale Zellen-/Familienpriorisierung, begrenzten Spawnversuche,
Generierungsstaffelung und Meshwiederverwendung sind bereits enthalten. Der alte
PT18-Vergleich verschlechterte Hinweg-p95 von 61,8 auf 115,8 ms. Der INT30-Vergleich
verschlechterte kalt Hinweg-p95 186,859 → 201,059 und Rückweg 195,238 → 547,981 ms;
dort liefen acht Godot-Prozesse unter unkontrollierter Last. Keiner dieser Befunde
rechtfertigt eine neue pauschale Budget-/Sichtweitenänderung.

## Tatsächliche Messung

Godot 4.6.3.stable.official.7d41c59c4; Linux, Host `db514e109ac6`, AMD EPYC 9V74,
Cgroup 8 CPU / 8 GiB, headless, Framecap 60, 1920×1080 im Rezept, Seed 15838.
Kein gerendertes GPU-/Treiber-/VRAM-Ergebnis. Vorhandenes `profile_performance.py`,
2×8-s-Routenquelle mit physischem Rückweg/Save/Menu/Reload; anschließend zweimal
derselbe originale Replay-Save und dieselben 51 Wegpunkte. Die tatsächliche
Referenzwegstrecke beträgt 43,722 m. Unveränderte Schutzgrenzen und Spielerphysik.
Ein Seed allein wäre wegen der Kampagnen-/Körperidentitäten kein gleicher Save.

Beide festen Protokolle bestehen vollständig. Die erste Routenquelle bleibt
**negativ**: Tod im zweiten Rückweg, health=0, terrain_wait=false, vier nahe
Predatoren (drei verfolgen) und reale Kollisionskontakte. Keine Heilung, keine
Survival-Ausnahme, kein Teleport und keine verlängerte Frist.

Alle Zahlen sind Wall-clock-Processframes in ms. A ist die erste feste Referenz,
B ihre identische Wiederholung mit gleichem Spielverhalten – kein Optimierungs-A/B.

| Zyklus / Abschnitt | Lauf | p50 | p95 | p99 | Maximum | >33 / >50 / >100 ms |
|---|---|---:|---:|---:|---:|---|
| kalt / hin | A | 16,681 | 77,880 | 128,753 | 214,134 | 36 / 28 / 9 |
| kalt / hin | B | 16,689 | 71,399 | 127,407 | 223,446 | 35 / 29 / 7 |
| kalt / zurück | A | 16,575 | 21,052 | 25,806 | 48,039 | 1 / 0 / 0 |
| kalt / zurück | B | 16,681 | 23,652 | 32,243 | 57,203 | 4 / 1 / 0 |
| reload / hin | A | 16,711 | 32,104 | 81,875 | 176,036 | 17 / 8 / 3 |
| reload / hin | B | 16,671 | 29,530 | 112,087 | 170,846 | 13 / 9 / 4 |
| reload / zurück | A | 16,636 | 22,722 | 33,961 | 51,247 | 5 / 1 / 0 |
| reload / zurück | B | 16,646 | 19,518 | 22,853 | 27,564 | 0 / 0 / 0 |

Verschlechterungen bleiben sichtbar: kalt hin Maximum und >50-ms-Zahl, kalt
zurück alle Perzentile/Maximum/Spitzen, reload hin p99 und >50/>100-ms-Zahlen.
**A hatte fremde Godot-Prozesse; B hatte im 250-ms-Logger keine.** Die gemeinsame
flock-Sperre verhindert teilnehmende Heavy-Läufe, keine fremden Fachtests oder
sonstige Hostlast. Deshalb keine kontrollierte Leistungsverbesserung ableiten.
RAM/Cgroup- und Process-RSS-Daten stehen in den Originalen; kein VRAM-Schätzwert.

## Zeitlich belegte Arbeit und Grenzen

Im 214,134-ms-Frame von A ist `actor_ready` mit **154,730 ms** enthalten;
Generierung dort 0,010 ms, Kandidaten 1,310 ms, Priorisierung 0,501 ms.
Andere Hinwegframes enthalten 62–86 ms Generierung. Actor-Ready blockiert den
synchronen Aufruf `add_child(actor)` einschließlich bestehendem Körperaufbau.
Dies isoliert weder CPU-/GPU-Arbeit noch eine einzelne Meshcache-/Animationsursache.
Große Actor-Ready-Phasen und einzigartige Artgenerierung bleiben zentrale
Messkandidaten; gemeinsame Runtime-/Meshanschlüsse an R32-01, keine fremde
Körperanimation, LOD-Arbeit oder #246 übernommen.

Die Probe protokolliert Record, Terrainbereitschaft, physische Veröffentlichung,
Mesh, Collider und ersten **beobachteten** KI-Schritt pro Identität. In A kalt:
12 Tiere mit Mesh/Collider/KI-Beobachtung, sechs Nester, zwölf Beerenbüsche.
Maximal beobachtete Record→Mesh-Wartezeiten: Tiere 6043,893 ms, Nester 1163,431 ms,
Beeren 14601,762 ms; dies sind Poll-Beobachtungen, keine exakten Aufbau-Startzeiten
oder garantierten Sichtbarkeitslatenzen. Einige Meshes liegen vor dem ersten
Record-Poll. Die JSONs weisen diese Fälle separat aus.

Record-/Bodenbeobachtung alle 250 ms; Mesh bedeutet vorhandene MeshInstance mit
Mesh, Collider bedeutet aktivierter veröffentlichter Shape. Kein GPU-Upload-
Zeitstempel, kein Beweis der Camera-Sichtbarkeit/Physics-Server-Synchronisierung.
KI-Beobachtung folgt einer Änderung des vorhandenen Entscheidungs-Timers;
frühere unobservierte Schritte bleiben möglich. Diagnosekosten werden ausgewiesen.
`spawn`-Unterphasen nicht nochmals zu den umschließenden Tickzeiten addieren.

## Änderungen und Quellen

- Optionaler `work_probe` im zugeordneten Populationshost: Zeitstempel pro
  vorhandener Tick-/Spawnphase; normale Spiele behalten keine Tracearrays.
- Opt-in `--population-readiness`, eigener Route-Untertyp und begrenzter Recorder.
- Finaler Recorder liest nur bereits residente Cachepages. Die gemessene ältere
  Probe verwendete `storage.region()`, das Pages als schreibbar berührt; diese
  zusätzliche Diagnosebeeinflussung ist im finalen Helfer entfernt und durch
  einen Cache-only-/Unverändertheitsfall geprüft. **Kein gemessener Gewinn für
  den finalen Helfer behauptet.**
- Hostslot-/Fremdlastlogger und Bericht, der negative/unvollständige Abschnitte
  sowie Regressionen erhält. Keine Spawn-/Sichtweiten-/Testgrenze geändert.

Routen liefen auf der festen Basis plus ausdrücklich gehashter Instrumentierung
im damals schmutzigen Arbeitsstand. `raw-routes.tar.gz/measured-source/` enthält
die tatsächlich für beide festen Läufe geladenen fünf geänderten Implementierungen,
einzeln gegen die Original-Capture-SHA256 geprüft. Tests/Reportdateien, die während
eines Laufs ergänzt wurden, wurden von der Route nicht geladen. Die Originale
identifizieren ihre Quelländerungen; die Routen gelten **nicht** als Performance-
Freigabe des späteren finalen Fachtrees.

Sauber geprüfter Codecommit `a792710ec051a95c38d0f3f7f8b558964c08e922`, Tree
`10940d76defe45fa895c3f971f7d4d599597a383`. Der abschließende Belegcommit fügt nur
dieses Verzeichnis hinzu. `provenance.json` enthält SHA256/Bytes der Belege.

## Prüfung und Übergabe

Auf dem sauberen Codecommit: `surface_population_budget_test`,
`performance_measurement_test`, `region_store_test` alle erfolgreich, strenger
Fehler-/Leakcheck und unveränderte Quellmanifeste. Der bestehende Budgettest ruft
eigene Fälle für staged/veröffentlichte/fehlende Meshes, deaktivierte Collider,
abgetrennte Diagnostik, Cache-only-Beobachtung und KI-Erstbeobachtung auf.
Registry bleibt bei 267 Tests; kein neuer Godot-Einstieg, kein zentraler Append nötig.
23 bestehende Performance-Toolingtests plus ein neuer negativer Berichtstest
bestanden. Ein Zwischenlauf mit zu frühem PackedScene-Preload war negativ;
der Helfer lädt diese Abhängigkeit jetzt nach den Autoloads. Negative Originale
bleiben im Prüfarchiv. Erneuter Import/Artquellencheck erfolgreich.

Der konservative Änderungsplan fordert volle 267 Tests/Main-Runtime. **Nur Plan**;
Vollsuite, Pflichtgates, native Exporte und Merge bleiben bei R32-01. Keine lokale
Vollsuite und keine zentrale Registry/Statusänderung. 600-s-Windowsroute, reale
CPU-/GPU-Frametimes, Renderer-/Pop-in-Sichtabnahme und Lars' Ziel-PC bleiben offen.

Nach Entpacken des Originalarchivs außerhalb des Checkouts:

```sh
python3 tools/profile_performance.py --godot GODOT_4_6_3 --population-readiness \
  --cycles 2 --walk-seconds 8 --replay ORIGINAL/route-source \
  --route-from ORIGINAL/route-source --output NEUER_BERICHT
```

Vor einem schweren Lauf den aktuellen Hostslot in #137 abstimmen und die gemeinsame
Sperre mit `review_r32_02_host_slot.py` halten. Neue Instrumentierungsbytes oder
Umgebungen erzeugen neue Belege; keine alte Performanceabnahme übertragen.
