# INT30-02 / V30-02: Performance und Population-Streaming

30.09.2026 · Fachlieferung für [PR #226](https://github.com/MajorDragonfly/voxelverse/pull/226) und die bestehende Runde [#137](https://github.com/MajorDragonfly/voxelverse/issues/137).

## Ergebnis und feste Quelle

Die Spielerzelle bleibt zuerst dran. Danach baut die Population die physisch nächste noch fehlende Region auf, statt zunächst die entfernten Ecken eines festen 5×5-Rings abzuarbeiten. Sobald neue Regionen vollständig sind, bleibt der rotierende Pflegepfad für additive Kolonie-Upgrades erhalten. Kandidaten und Beeren sortieren mit einmal pro Tick berechneten Distanzen und Prioritäten; der Cache lebt nur während dieses Ticks. Herkunft, bewegte Orte und Origin-Rebases werden deshalb nicht über einen veralteten Cache verfolgt.

Feste gemeinsame Basis: `2b1ac023db4074c2ce6b7db8fbab09ab929a8435`, Tree `5f815f478ceeabefcfc50a6388e3e4b0daa2ac45`. Lokal geprüfter Codecommit: `daa1e2417cb990c46b85c1353d69ebb88124a668`; veröffentlichter identischer Codekopf: `453f9957e0a5fe48725238dbc6752e45df9db67e`; gemeinsamer Code-Tree `e882319484fbc20700f10a52f88038a759646671`. Nachfolgende Bericht-/Evidenzcommits verändern diesen Produktionscode nicht.

Die bereits enthaltenen Anschlüsse aus #202 sind vorhanden: eingefrorener Blueprint vor Preview-`_ready()`, konstante Sculpt-Farbwerte und Routen-/Spawnphasenmessung. #216 ist ebenfalls im gemeinsamen Code vorhanden: Spielerzellen-Priorität, Trennung von teurem Regionsaufbau und folgendem Spawnframe sowie Runtime-Skin-LRU mit acht Designs. Diese Körper-/Meshdateien wurden nicht geändert. Maximal zwölf freie Tiere, sechzehn Pflanzen, sechs Nester, zwei Spawnversuche und ein erfolgreicher Tier-/Pflanzenaufbau pro Update gelten weiterhin. Körperpose, Animation und Mesh-Arbeit bleiben bei Chat 7; Scanner und Nestlabels bei Chat 5.

## #219: reproduzierte Slotkonkurrenz, vorhandener Fix

Das ursprüngliche CI-Artefakt `11054453297` aus Run `36607399055`, Job `109543225224`, wurde vollständig heruntergeladen. ZIP-SHA256: `f380b583a63e33bb299cc7e71589a3ac97cac923c2116fcfd6abfe89bd9cea27`; ursprünglicher Testlog: `9a9aa90296a66d9a03dd9dd9c84690b31c1eea195857ba42a3240cf3181251dd`.

| Gegenprobe | Ergebnis | Quelle / Grenze |
|---|---|---|
| Exakter damaliger #219-Kopf `862dbed90a23df903f7589f6001fd9dbeee4edf3` | Exit 1, 83,267 s; vier Kolonien mit jeweils zwei physischen Bewohnern | Vollständige Quelle unverändert, SHA256 `7e4382f5fb2acf2fd02b4fc7668ddd8699473230e5e2b206880f8ae8d110f8f1`, identisch zur ursprünglichen CI-Quelle |
| Derselbe Altstand ausschließlich mit dem Population-Hunk aus `76920f58cda28e1ea51db9579f416a5a33f2a1d9` | Exit 0, 125,105 s | Quelle stabil, SHA256 `e68a21d7b6626830da46e6bc16771564b0e1f200df6d9fd370f8c36f7c2efc0d`; unveränderte Fixture, Assertions und Zeit-/Mengenbudgets |
| Heutige gemeinsame Basis ausschließlich ohne diese Familienpriorisierung | Exit 0, 52,933 s | Andere enthaltene Änderungen, besonders die zentrale Regionspriorisierung, können den alten Sättigungsfall vermeiden; der Familienpatch ist nicht die einzige Einflussgröße |
| Neuer Fachstand mit zusätzlichen Reihenfolge-/Pause-/Reload-Prüfungen | Exit 0, 100,978 s | Code-Tree oben; vollständige Quelle stabil, SHA256 `9d75a871011c5edea1996c3acef5925a2547d4d9d5259fd4c0b0a104888210eb` |

Die Ursache ist Konkurrenz um die begrenzten freien Slots: Der alte Sortier-/Cursorpfad verteilt verfügbare Plätze, bevor eine sichtbare Familie vervollständigt wird. Der bereits enthaltene Patch priorisiert fehlende Katalogrollen, anschließend Geschwister bestehender Familien und setzt nach einem erfolgreichen Tieraufbau den Cursor zurück. Der neue deterministische Anschlussfall prüft diese Reihenfolge ausdrücklich. Es gibt hier keinen zweiten Nest-Fix, keine abgesenkte Dreier-Erwartung und kein verlängertes Timeout. Die realen Weltstarts erzeugen jeweils neue Kampagnen-/Körperidentitäten; diese Verhaltensgegenproben sind kein identischer Körper-/Leistungsvergleich. Eine erste Altstand-Gegenprobe mit während des Laufs verändertem Quellinventar wurde verworfen und nicht als gültige Abnahme verwendet.

## Vergleich derselben physischen Route

Godot 4.6.3, Linux headless, Seed 15838, 1920×1080-Fensterrezept, 60-FPS-Cap, 60 Settle-Frames, unveränderte 120-s-Startgrenze. Beide Seiten verwenden dieselbe isolierte Startdatei und deren Regionsblobs, denselben Körper `body_7036bcf3947230b62233ef44502e0448`, dieselben gespeicherten Wegpunkte mit normaler Physik/Kollision und ohne Teleport. Wegpunkt-SHA256: `428f5886aedbef5d554f672e3a1390a58a0ea877d8a1a6e9b612474e979db1be`. Die Wegpunkttoleranz beträgt 0,65 m; tatsächlich zurückgelegter erster Hinweg: 79,320 / 78,467 m. Die Start-Richtungskoordinaten sind identisch; die normale Standhöhe weicht um 0,090 m ab.

Kontrollquelle `5b11b7df04d508f9a3fa92474af3d9961ce72380` stellt nur die beiden Produktionsdateien `campaign_population.gd` und `campaign_population_state.gd` auf die gemeinsame Basis zurück. Alle Messskripte entsprechen dem Kandidaten. Der CLI-Zusatz `--route-from` bindet dieselben physischen Wegpunkte an beide Seiten; die bisherige zeitbasierte Steuerung bleibt verfügbar. Der Bericht toleriert ausschließlich F64-Rundtripabweichungen von höchstens 1e-12 in u/v und ergänzt p99/Maxima. Echte Adress-/Körper-/Rezeptwechsel werden weiter abgewiesen.

**Beide vollständigen Zwei-Zyklen-Protokolle sind fehlgeschlagen.** Deshalb folgt hier ausschließlich ein beschreibender Vergleich ihrer abgeschlossenen ersten Wege, keine bestandene Gesamtmessung:

| Erster Weg | p95 vorher → nachher | p99 vorher → nachher | Maximum vorher → nachher | Frames >33 / >50 / >100 ms vorher → nachher |
|---|---:|---:|---:|---|
| Hinweg | 186,9 → **201,1 ms** | 220,0 → **263,6 ms** | 353,3 → 278,3 ms | 125/90/55 → **126/104/58** |
| Rückweg | 195,2 → **548,0 ms** | 322,1 → **730,0 ms** | 456,1 → **855,5 ms** | 160/97/46 → 139/**113/84** |

Die Verschlechterungen bleiben ausdrücklich offen. Auf dem gemeinsam genutzten Host liefen acht Godot-Prozesse bei fast vollständig belegtem 8-GiB-Cgroup-Limit und wechselnder hoher CPU-Last. Die Hintergrundlast war nicht kontrolliert. Das verhindert eine belastbare kausale FPS-Bewertung; es beweist ebenso wenig, dass jede Verschlechterung ausschließlich vom Host stammt.

Die Kontrolle scheiterte beim Reload: `scene_ready` 204,363 s, danach unveränderte 120-s-Startgrenze überschritten. Der Kandidat erreichte den Reload (81,625 s im Startup-Trace), benötigte anschließend aber 127,416 s für 60 Settle-Frames. Sein zweiter Hinweg endete mit p95 1095,4 ms / p99 12856,6 ms / Maximum 14322,1 ms. Der zweite Rückweg scheiterte an der physischen Rückkehrgrenze: Teilstrecke p95 8103,2 ms, p99/Maximum 59073,3 ms. Der Spieler war dabei am Leben, nicht auf dem Boden, ohne Terrain-Warteflag; ein Predator befand sich 5,26 m entfernt. Die Auflösung dieses Stillstands und die Trennung von Last-/Physik-/Kreaturenursache bleiben offen. Keine Timeout-Erhöhung und keine Wiederholung nur zur Erzeugung grüner Zahlen.

Vor der starken Parallelbelastung bestand ein unveränderter normaler Zwei-Zyklen-Lauf der Basis (anderes zeitbasiertes Routenrezept): kalter Hinweg p95 48,8 ms, p99 114,2 ms, Maximum 210,9 ms, 19 Frames >100 ms. Dieser Lauf ist ein Kontextbefund, kein Vergleich mit der festen Route.

## Spawnzeiten und Nähe-Pop-in

Zeitnull ist das erste aktive Populations-Sample nach Loading. Veröffentlichungen werden pro Prozessframe beobachtet; ausstehende Datensätze nominell alle 250 ms. Bei den langen Frameaussetzern werden auch diese Poll-Lücken größer. Wartezeiten sind daher Untergrenzen. Distanz bei physischer Veröffentlichung misst Nähe-Pop-in; sie ersetzt keine Prüfung tatsächlicher GPU-/Kamerasichtbarkeit.

| Beobachtung im ersten Zyklus | Vorher | Nachher |
|---|---:|---:|
| Erstes freies Tier | 530 ms | **1093 ms** |
| Erster Predator | 3769 ms | **4046 ms** |
| Erste Beere | 85 ms | **211 ms** |
| Größte beobachtete Tierwarte-Untergrenze | 5576 ms | **8239 ms** |
| Größte beobachtete Beerenwarte-Untergrenze | 27750 ms | **46242 ms** |
| Erstveröffentlichte Tiere innerhalb 20 m | 9 von 12 | 9 von 12 |
| Erstveröffentlichte Beeren innerhalb 20 m | 6 von 17 | 7 von 16 |
| Erstveröffentlichte Nester innerhalb 20 m | 2 von 7 | 3 von 7 |

Lebenszeit-Erstveröffentlichungen sind keine gleichzeitig aktiven Mengen. Die Zahlen zeigen keine allgemeine Pop-in-Abnahme. Im kontrollierten Quellpfad ist die Reihenfolge korrigiert: Auf der Basis erscheinen zunächst auch 61–108-m-Regionen vor fehlenden 34–38-m-Regionen. Der Kandidat füllt zuerst die fehlenden 19–36-m-Regionen und danach den weiteren Ring. Die beobachtete Sortierphasen-Spitze sinkt 148,421 → 17,003 ms; Actor-`_ready` steigt dagegen 162,626 → 178,599 ms und Gesamt-Populationsarbeit 253,235 → 269,104 ms. Diese Szenenmaxima sind nicht einzelnen Rohframes kausal zugeordnet. Weitere Körperaufbau-Arbeit nur als abgestimmter Anschluss an Chat 7.

## Fachprüfung und Übergabe

`python3 tools/validate_godot.py --changed-since 2b1ac023db4074c2ce6b7db8fbab09ab929a8435 --plan --summary` wählt konservativ 247/247 Tests und volle Runtimeprüfungen. Das ist ein Plan; keine behauptete Vollsuite. Gesamtsuite, neue Integrationstrees, native Exporte und Renderer gehören zu Chat 1.

Ausgeführte Fachbefehle, jeweils Godot 4.6.3 und isolierte Nutzerdaten:

```sh
python3 tools/validate_godot.py --godot GODOT --tests living_creatures_world_test surface_population_budget_test wildlife_colony_test wildlife_spawn_budget_test population_register_test campaign_scaling_test performance_measurement_test domestic_surface_runtime_test --skip-main --output OUT
python3 tools/validate_godot.py --godot GODOT --tests living_creatures_world_test --skip-import --skip-main --output OUT_FINAL
python3 -m unittest discover -s tests/tooling -p 'performance_route_report_test.py'
```

Der erste Fokuslauf auf `01afc28` hatte sieben bestandene Verbraucher-/Budgettests und fachlich bestandene Bewohnerprüfungen, wurde aber wegen zweier SceneTree-Transformfehler der neuen isolierten Fixture ausdrücklich als fehlgeschlagen gewertet. Der Observer wird inzwischen korrekt an den SceneTree gebunden. Der anschließende endgültige Bewohnerlauf auf `daa1e24` ist ohne Fehler/Leak grün, einschließlich Dreier-Bewohnern nach Reload, Pause, nächster fehlender Region, Cube-Seams, alter Regionspflege, Rollen-/Familienpriorität und frischen Tick-Distanzen. Drei Python-Berichtstests, Projekt-Hygiene und `git diff --check` bestanden. Die Produktionsdateien der sieben Verbraucherfälle wurden seit deren Prüfung nicht verändert; deren ursprüngliche Quell-/Tree-Nachweise bleiben getrennt im Archiv. Das ist keine acht Tests umfassende identische Gesamt-Tree-Abnahme.

Neue Fälle hängen am bereits registrierten `living_creatures_world_test`; kein zusätzlicher Registry-Eintrag, keine gemeinsame Übersetzung und keine zentrale Statusänderung nötig. [Rohdaten, Replay-Fixture und Logs](evidence/int30-02-performance/raw-evidence.tar.gz), [maschinenlesbarer Vergleich](evidence/int30-02-performance/measurements.json). Archiv-SHA256: `6f811d830b56fdf2038604bad06d417e6928fe3b9b799e34564c685f9e89d89e`.

Reproduktion nach Entpacken des Archivs außerhalb des Quellcheckouts:

```sh
python3 tools/profile_performance.py --godot GODOT --seed 15838 --cycles 2 --walk-seconds 20 --renderer headless --replay RAW/baseline-instrumented --route-from RAW/baseline-instrumented --output OUT
```

Für den Kontrollcode ausschließlich die beiden Population-Produktionsdateien auf die volle gemeinsame Basis zurückstellen; Messskripte auf beiden Seiten bytegleich halten. `--compare` erst mit vollständig bestandenen, gleichartigen Protokollen verwenden. Unter der beschriebenen Last sind die vorliegenden Läufe keine solche Freigabe.

**Offen:** ruhiger vergleichbarer Host für vollständigen Kalt-/Reload-Rundweg, Ursachenabgrenzung des zweiten Rückweg-Stillstands, gerenderte Pop-in-Prüfung sowie #167 auf Lars' Ryzen 7 9800X3D / RTX 4070 Ti / 32 GB, festem Treiber/Preset und zehn Minuten bei 1080p. Dieser PR bleibt Draft; kein Auto-Merge, kein main-Merge und keine Schließung von Quell-PRs. Die fachlich belegten Nähe-/Sortierkorrekturen sind reviewbar; eine bessere Gesamtleistung wird nicht behauptet.
