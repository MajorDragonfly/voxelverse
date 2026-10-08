# R33-02 / #167 — begrenzter Skinaufbau, kontrollierte Phasen-A/B

**Gemessene Senkung hoher Frametime-Spitzen; kein pauschaler Ganzrouten- oder FPS-Sieg.**
Fachbranch `agent/r33-02-performance`, erhaltener Draft [#272](https://github.com/MajorDragonfly/voxelverse/pull/272)
gegen `agent/integration-r33-20261007`. Feste Basis
`94de70cacd250337976b8f63031fff4afc72e2bb` / Tree
`58506a6feba11be547197223fa319e7265cf4d99`. #167 bleibt offen.
Gemeinsame Produktionsdateien bleiben im Fachbranch unverändert; R33-01 erhält den engen Produkt-Besitzerpatch.
Flora-/Forward+-Publikation bleibt R33-08.

## Tatsächliche Prüfung und heutiger Host

Der alte Wartestatus ist aufgehoben: am ursprünglichen Fachkopf
`4dd3fb490d30b554d8b61147d4eec96792a60187` sind
[Godot 37609359734](https://github.com/MajorDragonfly/voxelverse/actions/runs/37609359734)
und [Performance 37609359336](https://github.com/MajorDragonfly/voxelverse/actions/runs/37609359336)
erfolgreich abgeschlossen. Godot: Contracts, vier Quellshards und Runtime/Draftfeedback.
Performance: Import/Artquellen, tatsächlicher Measurement-Test, frische **2×6-s-Headlessroute**
und Saveskalierung. CI-Mergecheckout `21c13bdae0a5c7d299c3a3695831a1b9e5d3b9b2`.
Diese alte CI nutzte weder Original-Replay noch Phasenanschlüsse oder A/B; sie wird nicht
als neuer Produkt- oder finaler Integrationsnachweis umgedeutet. Joboriginale/Status liegen in `checks/`.
Neue Kopfprüfungen werden im PR separat mit ihrer tatsächlichen SHA geführt.

Heutiger tatsächlich gemessener Host **`7f573e0a2ae8`**, AMD EPYC 9V74,
Cgroup **8 CPU/8 GiB**, Godot **4.6.3.stable.official.7d41c59c4**, Headless/Dummy.
Der historische Intel-Host `3c32128a52fd` ist kein heutiger Messhost.
R33-01 bestätigte 02→08 im [verbindlichen Kommentar](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-6035774590).
Preview-/Wildlife-/Produktanschlüsse wurden dateigenau in #137 angemeldet; die dortige ausdrückliche
Erlaubnis für isolierte Besitzerpatch-QA wurde benutzt, keine gemeinsame Produktionsfreigabe behauptet.
Nach fremdem UI-Godot wurde gewartet; kein konkurrierender Replaylauf und keine fremde Prozessbeendigung.

Jeder schwere Abschnitt hielt `/tmp/voxelverse-heavy.lock` **und**
`/tmp/voxelverse-r32-db514e109ac6-heavy.lock` nonblocking/exklusiv bis zum Prozessende.
Start/End-Gitstatus, Host-PID-/Namespacezuordnung, tatsächliche Prozess-/Cgroup-Last und Druckwerte
sind roh erhalten. Alle gültigen Routen: saubere unveränderte Quelle, kein fremder Godot,
kein Traceoverflow, kein Survivalfehler und kein Timeout. Cgroup-Endinventar: keine OOM-Kills;
Memory-Limitkontakte (`max=2452`) sind aufgezeichnet, kein unbelasteter Hardware-PC wird behauptet.
[Gesamtes HOST-END](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-6056337689):
eigene Engines einschließlich Cold-Child beendet, beide Locks tatsächlich frei geprüft/freigegeben;
08 kann seinen nächsten Abschnitt beginnen. Keine weitere lokale schwere Arbeit nach HOST-END.

## Originale Eingänge und saubere Quellen

Original `route-source` aus `docs/evidence/r32-02/raw-routes.tar.gz`, Seed **15838**,
51 feste Wegpunkte / 43,722 m. Beide Seiten: **2×8-s-Rezept**, physischer Hin-/Rückweg,
Save/Menu/Reload, 60 Framecap, 60 Settleframes, unveränderte **120-s-Stufengrenze**,
1920×1080, gleicher Renderer und unveränderte Kamera-/Wetter-/UI-/Survivalbedingungen.
Keine Heilung, Teleportation oder Survival-Ausnahme. Der Eingang wird vor dem Laden gehasht.

| Eingang | SHA256 |
|---|---|
| Original capture.json | `d51df978638b92f805f0b357e8d42c01a953dd356936795c55a5d0d35ac6d305` |
| JSON-sortierte Replay-Save | `870a0b5998277d7d7cc82d82abadcd56d68604c4eb6be45950ab2776acf34664` |
| JSON-sortierte feste Wegpunkte | `d0565230640b838ee317313c51f8649fa16f41f8bd3f2527f32831d64bf90c70` |
| Tatsächliche Replay-Dateimenge | `7f2d9222e27859422bfd13cfe5111c32a70e0dba90668d44252e6882564f6e05` |

| Seite | QA-Commit | Tree |
|---|---|---|
| Vorher: Diagnostik, kein Produktfix | `891390939004d9c4d585d4bf171b3c93a5f5c0f4` | `09774560884fdf9b5ac39847f844fe8584488949` |
| Nachher: gebatchter Skinjob | `7237afe17abe959365128642a5e4d1223e24daba` | `5e455681cf0a5ff4379f02eb7bdf0459b2282667` |

`qa-sources.bundle` enthält beide exakten QA-Refs und deren Zwischenstände; einzige Voraussetzung
ist die feste R33-Basis. `git bundle verify` bestanden. Nach `git fetch` aus diesem Bundle lassen
sich isolierte Worktrees an `refs/r33-02-qa/before` und `refs/r33-02-qa/after` anlegen.
Die Bundle-QA enthält gemeinsame Patches; dadurch werden keine Produktionsdateien des Fachbranches überschrieben.

Die Originalaufrufe stehen vollständig in den jeweiligen Host-JSONL/SourceRun-Dateien:
Hosthülle mit bestätigtem Slotlink → `profile_performance.py --population-readiness --population-phases
--cycles 2 --walk-seconds 8 --replay ORIGINAL --route-from ORIGINAL`; gepinnte Engine und externe Outputordner.
Originalfixtures, Frames, Capture, Engine-/Speicherlogs und Hostinventare: `raw-before-20261008.tar.gz`
und `raw-after-20261008.tar.gz`. Hash-/Größeninventar: `artifact-manifest-20261008.json`.

## Konkreter Engpass und begrenzte Korrektur

Vorher: 11 synchrone Skinmisses, **max 59,727 ms / gesamt 469,897 ms**;
Actor-Ready **132,655 ms**, Artgenerierung **74,035 ms**. Colliderkonfiguration **0,021 ms**
und erste Wanderentscheidung **0,078 ms** sind kein bestätigter Engpass.
Generierung (Region/Placement/Species/Records/Colony/Food), Actor/Stats/Behavior,
Mesh/Cache/Sockets/Motion, Collider, erste KI-Entscheidung und `actor_add_child` sind separat erfasst.
Die Add-Child-Veröffentlichung enthält geschachteltes Ready; die Auswertung bildet die
geclippte **Intervallunion**, addiert niemals Eltern- und Kinderzeiten.
Physischer erster KI-/Mesh-/Colliderstatus bleibt eine nach Physics beobachtete obere Grenze,
kein Physicsserver-/GPU-Upload-/Sichtbarkeitstimestamp.

Die exklusive `campaign_population_state.gd` enthält den resumierbaren geometriegleichen Skinjob.
Ein Owner hat höchstens einen unveröffentlichten Job. `_process` gibt ihm nur das Restbudget von
**2 ms**, zusätzlich höchstens **4096 Einheiten**; ein Batch enthält höchstens 64 Zellen oder
16 Shellkandidaten. Keine vollständige Skinberechnung mehr im Live-Spawn-Ready.
PackedArrays werden innerhalb eines Batches lokal bearbeitet. Vollständige Skins gelangen erst
am Ende in die bestehende exakte **8er-LRU**. Editor/Player und manuell deaktivierte Owner behalten
ihren vorhandenen synchronen Pfad. Spawnversuche/Live-Limits/Kollisionsguards bleiben erhalten.

Aufgeschobene Vorbereitung ist kein blockierter Spawn: der vorbereitete Kandidat behält seinen
Publikationszug. Echte blockierte Platzierung bricht ab und rotiert weiter. Der Cachekey ist das
unveränderte eingefrorene Eingangsdesign; interne Spine-Normalisierung schreibt keinen Record um.
Save, aktive Kandidatenentfernung, Reload und Exit brechen offene Jobs ab.
Ursprungwechsel behalten kanonische Koordinaten; lokale Spawnpunkte werden erst bei Veröffentlichung
neu aufgelöst und physisch geprüft. Keine Threads, Nachlaufcallbacks, neuen IDs oder Save-Schemaänderungen.

Nachher: **242 Slices / gesamt 498,223 ms**, p50/p95/p99/max **1,973/2,536/3,760/4,593 ms**.
Actor-Readymax **84,388 ms**; Skinmiss-Submission entfällt aus diesen 24 Live-Spawns.
Der Zeitwert ist ein Budgetcheck **vor** einem endlichen Batch, keine harte Wallclock-Garantie:
native Allokation/ArrayMesh-Submission und Scheduling sind nicht präemptiv. Im finalen Cold-Child
wurde ein Slice von **6,820 ms** gemessen. Gesamte Skin-CPU-Arbeit steigt leicht, sie wird verteilt.
Verbleibend: Body/Partsmax 54,902 ms und Artgenerierung 72,424 ms; kein weiterer Fix daraus behauptet.

## Vollständige A/B-Zahlen und Grenzen

Frametime in ms; Spitzen sind absolute Framezahlen **>33/>50/>100 ms**.
Beide Zyklen enden mit **12 Tieren / 12 Pflanzen**, je zwei Ursprungwechseln.

| Stand | Zyklus | Weg | p50 | p95 | p99 | max | >33/50/100 |
|---|---|---|---:|---:|---:|---:|---|
| Vorher | Kalt | Hin | 16.617 | 77.519 | 130.465 | 204.769 | 32/29/7 |
| Vorher | Kalt | Rück | 16.637 | 20.358 | 25.287 | 32.272 | 0/0/0 |
| Vorher | Reload | Hin | 16.655 | 22.876 | 82.171 | 146.889 | 13/7/3 |
| Vorher | Reload | Rück | 16.694 | 21.419 | 28.281 | 62.070 | 2/1/0 |
| Nachher | Kalt | Hin | 16.597 | 61.207 | 94.567 | 113.267 | 27/26/1 |
| Nachher | Kalt | Rück | 16.626 | 25.401 | 53.354 | 127.145 | 10/5/2 |
| Nachher | Reload | Hin | 16.540 | 23.263 | 65.153 | 100.114 | 14/8/1 |
| Nachher | Reload | Rück | 16.621 | 23.303 | 34.515 | 51.710 | 5/1/0 |

Framegewichtete gesamte Bewegung (1587→1613 Frames): p50 **16,651→16,598 ms**,
p95 **23,502→26,605 ms** schlechter, p99 **90,846→73,731 ms**, max **204,769→127,145 ms**.
Spitzen **47/37/10→56/40/4**: weniger >100 ms, mehr >33/>50 ms.
Prozess-RSS-Spitze **471560192→488734720 Bytes** höher; VRAM/GPU/Draws nicht verfügbar.
Das ist ein belegter Hochspitzen-/Skinblockgewinn mit **offenen Rückweg-, p95-, RAM- und
Publikationslatenzregressionen**, keine durchgehend schnellere Route.
Erster kalter Actor etwa **465,9→1089,1 ms**, vollständige 12er-Publikation **7169,7→9828,9 ms**.
Kaltes/Reload-Terrainstartup bleibt etwa 22–25 s und wird nicht diesem Skinfix zugerechnet.

`batched-ab.json.gz` enthält alle vier Zeilen, sämtliche positiven Deltas/Regressionflags,
Frameattributionen und Rohbereitschaft. Vergleichsblocker: keine. Der Reporter sperrt zusätzlich
unterschiedliche publizierte Endzahlen; aus 12→11 wird kein Gewinn konstruiert.
Publikationslatenz bleibt separat sichtbar.
Eine kurze Software-A/B-Reihe belegt keinen statistischen Langzeit- oder Ziel-PC-FPS-Gewinn.
Lars' Ziel-PC-/600-s-Windows-/Sicht-/Spielkomfortabnahme bleibt getrennt offen.

## Tatsächliche Fach- und Lebenszykluschecks

Am finalen gebatchten QA: `surface_population_budget_test` **3,732 s**,
`runtime_geometry_batch_test` **2,379 s**, `creature_body_contract_test` **10,145 s**: **3/3**.
Der eigene `r33_02_skin_build_cases.gd` wird genau einmal aus dem vorhandenen exklusiven Budgettest
aufgerufen; keine doppelte Quelltestregistrierung und kein Registry-Anschluss nötig.
Oracle gegen Originalmesher an drei eingefrorenen/serialisierten Spezies: alle Mesharrays und
Voxelbelegungsmetadaten exakt gleich, Eingangsbody unverändert; Zero-/Unitbudget, Abbruch,
Cachewiederverwendung, Kandidatenrotation und eindeutige Publikationszuordnung geprüft.
Unveränderte reale Blockade-/Restore-/Spawnlimits und direkte Körper-/Socketverbraucher bestehen.

`living_creatures_world_test` **88,818 s** innerhalb ursprünglicher 120 s: physische Dreierfamilie,
Pause, echte SaveService-Speicherung, offener Job beim Save, Kandidatenaustritt, Ursprungwechsel,
Weltentladen, Menüreload und tatsächlicher **separater kalter Godot-Prozess** bestanden.
Parent und Child schreiben unabhängige JSON-Ergebnisse: `passed=true`, `failures=[]`, alle
Lifecyclechecks true, sieben kanonische Residents samt Frozenbody/IDs/Home/Seeds geprüft;
dieselbe Familie hat vor/kalt/nach Reload drei physische Bewohner. SourceRun stabil/reusable.
Der Elternstdoutlog endet im OS.execute-Abschnitt vorzeitig; bloßer Exit0 wird dafür nicht als
vollständiger Kaltstartbeleg verwendet. Die separaten JSONs plus erzwungenem Child-Completionmarker
sind in `checks/lifecycle-and-host-end-20261008.tar.gz` erhalten.
Fokusoriginale/SourceRun/Inventare: `checks/native-batched-consumers-20261008.tar.gz` und
`checks/native-batched-lifecycle-20261008.tar.gz`. Alle Zwischenprüfungen liegen ebenfalls in `checks/native-*`.
15 Host-/Teardown-/Reporter-/Negativtests bestanden; Original `checks/host-report-final-20261008.log`.
Validation-Registry statisch: 286 Tests genau einmal/18 Verträge, 2642 Meldungen/2 Sprachen;
keine ausgeführte Vollsuite oder technische Integrationsfreigabe daraus behauptet.

## Erhaltene Negative, keine umgedeuteten Gewinne

- Erster Import erzeugte die fehlende eigene Routeprobe-UID: native Checks bestanden, Hosthülle
  trotzdem Exit2 wegen geänderter Quelle. Original `checks/before-focus-20261008.tar.gz`.
- Erster Produktfokus: dynamischer Class- statt Scriptport konnte nicht compilieren; eigener
  Abschnitt unterbrochen (130, kein vollständiger Host-END). Zweiter Fokus: deaktivierter manueller
  Restoreverbraucher konnte Jobs nicht pumpen; reale Blockadeasserts negativ. Korrekturen erhielten alle Guards.
- Zu früh statisch geladener neuer Casehelper traf fehlenden GameState und echte RID-Leaks im
  Testfixture. Laden nach Autoloadstart behebt den Fehler; finaler Verbraucherlog ist fehlerfrei.
- Erster Nachherentwurf: 12 Tiere, aber erster Actor erst 8,26 s; warmes Ergebnis verlor seine
  Kandidatenzuordnung. `raw-draft-1-20261008.tar.gz` / `draft-1-reviewed.json.gz`.
- Zweiter Entwurf: per-elementare Arbeit kostete 1372,360 ms und veröffentlichte kalt nur 11 Tiere;
  Rückwegmax 172,679 ms. `raw-draft-2-20261008.tar.gz` / `draft-2-reviewed.json.gz`.
  Der aktuelle Bericht sperrt diesen Vergleich wegen reduzierter Publikationsdeckung.
- Historisches R32: gleicher Tree/Wiederholungen, fremde Last/Arbeitsstände und ursprünglicher
  Survival-Tod bleiben in `historical-r32-review.json.gz` bzw. Original-R32-Archiv erhalten.
  Keiner dieser Negativbelege wird als neuer Performancegewinn oder geänderte Replay-Eingangs-Save ausgegeben.

## Besitzeranschlüsse an R33-01

1. **Produkt:** `skin-cache-owner.patch`, ausschließlich
   `creatures/runtime/creature_runtime_preview.gd` am festen Basiskontext. Bestehende `_skin_cache`/
   `_species_skin`; neue statische `cached_species_skin`-/`remember_species_skin`-Ports,
   nur vollständige ArrayMesh, unveränderte LRU8 und synchroner Fallback.
   Zusammen mit den exklusiven Population-/Stateänderungen anwenden; gemeinsame Produktionsdatei
   ist im Fachbranch unangetastet. Keine Diagnoseabhängigkeit im Produktpatch.
2. **Optionale QA-Diagnose:** `phase-probe-owner.patch` für denselben Preview und
   `wildlife-phase-probe-owner.patch` ausschließlich `creatures/wildlife/procedural_wildlife_v7.gd`.
   Standardmäßig ungültige Callables, echte Ready-Phasen, sauberer Clear/Exit; keine Geometrie-/KIänderung.
3. **Messwiederholung:** erst die beiden Diagnosepatches, danach alternativ
   `skin-cache-after-phase-owner.patch` **statt** Produktpatch1. Genau diese Variante liegt im QA-Bundle.
   Beide Cachevarianten sind gegenseitig alternativ, nicht zweimal anwenden.

`git diff --check`, reine Anwendbarkeit beider Diagnosepatches/des unabhängigen Produktpatches,
Reverse-Check der angewandten instrumentierten Cachevariante und Bundleverify bestanden.
Der konservative FULL/Main-Plan ist nur ein Plan; Vollsuite, gemeinsame End-Tree-Prüfung, vier Pflichtgates
und technische Aufnahme gehören R33-01. Draft/Mergesperre bleibt bis konkreter Prüfung der
Produktanschlüsse und Bewertung der genannten Regressionen erhalten; keine Issue-/Backlogschließung.
