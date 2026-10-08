# R33-02 / #167 — vorbereitete Phasendiagnose, Messslot ausstehend

**Zwischenlieferung. Kein gemessener R33-Performancegewinn und kein Produktfix.**
Basis `94de70cacd250337976b8f63031fff4afc72e2bb`, Tree
`58506a6feba11be547197223fa319e7265cf4d99`; Fachbranch
`agent/r33-02-performance`; Draft gegen `agent/integration-r33-20261007`.
Die historische Diagnose #262 und der behobene Scannerblocker #265 sind bereits
in dieser Basis enthalten. #167 bleibt offen.

## Was vorbereitet und tatsächlich geprüft ist

- Opt-in Populationsphasen für Regionzugriff, Platzierung, Artgenerator,
  Recordschreiben, Kolonieaufbau und Nahrung. Bestehender Aufbau, IDs, Budgets,
  Simulation, Kollisionsprüfung und Saveformat bleiben in diesem Zwischenstand
  gleich. Die Populationshooks sind inzwischen durch die reguläre Godot-CI
  geprüft; der separate Preview-Anschluss und die kontrollierte Phasenroute
  bleiben ungeprüft (siehe Aktualisierung 08.10.).
- `--population-phases` ergänzt den vorhandenen Routenrunner. Ohne den gesonderten
  Preview-Anschluss bricht der Runner vor Start ab. Im Rezept werden tatsächliche
  Replay-Eingangsbytes vor dem Laden gehasht; eine später in der Capture enthaltene
  `initial_save`-Dictionary ist allein kein zuverlässiger Eingangsbeweis.
- Eine nonblocking Hosthülle hält `/tmp/voxelverse-heavy.lock` und den bestehenden
  R32-Legacylock zusammen. Vorhandene Godot-Prozesse verhindern den Start; ein
  fremder Godot-Prozess während des Abschnitts macht den Lauf negativ und stoppt
  ausschließlich die eigene Prozessgruppe. Fremde Jobs werden nicht beendet.
  Start-/Endquelle, Prozess-/Cgroup-Last und Slotverweis werden erhalten. Eine
  lokale Lockübernahme ist keine unabhängige Slotbestätigung.
- Die eigene Rohdatenauswertung clippt Phasen an beiden Framegrenzen und bildet
  die Intervallunion: verschachtelte Tick-/Actor-/Meshzeiten werden nicht addiert.
  Fehlende Bestätigung, fremde Last, schmutzige/geänderte Quellen, Traceoverflow,
  Tod/Fehler und unvollständige Abschnitte sperren kontrollierte Vergleiche.
  p50/p95/p99/max und Spitzen >33/50/100 ms bleiben je Hin-/Rückweg und Zyklus
  getrennt; sämtliche positiven Deltas bleiben als Verschlechterungen sichtbar.

**Tatsächliche leichte Prüfungen:** 23 vorhandene Performance-Toolingtests und
11 eigene Lock-/Teardown-/Rohdaten-/Negativberichtstests bestanden. `git diff
--check` und `git apply --check phase-probe-owner.patch` bestanden. Originale in
`checks/`. Der konservative Änderungsplan verlangt FULL/Main; das ist nur ein
Plan, keine ausgeführte Godot-Suite oder technische Integrationsfreigabe.

### Aktualisierung 08.10.2026: tatsächliche CI statt altem Wartestatus

Am erhaltenen Fachkopf `4dd3fb490d30b554d8b61147d4eec96792a60187` sind
[Godot 37609359734](https://github.com/MajorDragonfly/voxelverse/actions/runs/37609359734)
und [Performance 37609359336](https://github.com/MajorDragonfly/voxelverse/actions/runs/37609359336)
abgeschlossen und erfolgreich. Godot meldet tatsächliche erfolgreiche Contracts,
vier Quellshards und Runtime sowie `Godot draft feedback`; ein erfolgreicher
Draft-Workflow ist nicht die technische Abnahme des gesamten R33-Trees.

Der Performance-Originallog bestätigt Import/Artquellen, den ausgeführten
`performance_measurement_test`, eine **frische 2×6-s-Headlessroute** und Save-
Skalierung. Der CI-Checkout ist `21c13bdae0a5c7d299c3a3695831a1b9e5d3b9b2`
(PR-Merge mit der festen Basis). Die Route verwendet **weder die Original-
Replaywelt noch `--population-phases` noch den Preview-Besitzerpatch**.
Sie beweist deshalb keinen kontrollierten Vorher/Nachher-Gewinn.
Originaljoblog und abgerufene Jobzustände: `checks/ci-performance-37609359336.log`
und `checks/ci-status-20261008.json`; CI-Artefakt `11477833816`.

Heutiger tatsächlich beobachteter Host: `7f573e0a2ae8`, AMD EPYC 9V74,
Cgroup 8 CPU/8 GiB, Godot `4.6.3.stable.official.7d41c59c4`.
Der frühere Host `3c32128a52fd` wird nicht als heutiger Messhost übernommen.
[Heutige Host-/Patchanmeldung an R33-01](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-6055486686).
Vorbereitung bestätigt alle drei unten angegebenen Originalfixture-Digests und
51 Wegpunkte. Bis zur hostbezogenen R33-01-Bestätigung weiterhin kein eigener
schwerer Lauf und kein Produktfix. Historische Wartemeldungen unten bleiben
datierte Originalnachweise ihres damaligen Zustands.

## Enge Besitzerpatch-Abhängigkeit

`phase-probe-owner.patch` betrifft ausschließlich
`creatures/runtime/creature_runtime_preview.gd`, Basiskontext 94de70ca. Besitzer
R33-01/shared creature runtime. Der Patch fügt eine standardmäßig abgetrennte
statische Callable mit Set-/Clear-Port hinzu. Er beobachtet Skin-Cache-Hit/-Miss,
Skinaufbau/Submission, Body-/Partsaufbau, Runtimeboxen, Körpersockets und
Motionbind. Kein Cache-/Mesh-/Geometrie-/Animations-/Colliderfix ist enthalten.
Die gemeinsame Produktionsdatei ist im Fachbranch unverändert.

Vor Anwendung: dateigenaue Bestätigung durch R33-01 in #137. Danach den Patch in
einem isolierten QA-Checkout anwenden, sauberen QA-Commit/Tree erzeugen und beide
Vergleichsseiten mit identischem Anschluss prüfen. Erst wenn diese Messung den
Einzelengpass bestätigt, folgt die kleinste begrenzte Produktkorrektur. Keine
unbelegte Änderung aus dem langen übergeordneten `actor_ready`-Intervall ableiten.
Der Patch wurde lediglich auf saubere Anwendbarkeit geprüft, noch nicht mit
Godot ausgeführt. Flora-/Forward+-Diagnose bleibt bei R33-08.

## Historischer Befund, keine neue Messreihe

`historical-r32-review.json.gz` ist eine erneute reine Dateiauswertung der
publizierten Originale aus `docs/evidence/r32-02/raw-routes.tar.gz` (SHA256
`128469587e0298153d3728e885f9c7070a0305a6735042cc8a05fadad712144a`).
Es wurde dafür kein Godot gestartet. A und B sind Wiederholungen gleichen
Spielverhaltens am historischen Stand, keine R33-Vorher/Nachher-Läufe.

Die alten Maxima 214,134/223,446 ms enthalten lange synchrone Actor-Ready-
Intervalle; andere Frames enthalten 62–86 ms Generierung. A hatte fremde
Godot-Last; Quellen waren instrumentierte Arbeitsstände. Die erneute Auswertung
bewahrt alle Regressionen und lehnt eine kontrollierte Gewinnbehauptung ab.
Die alten Capture-Savedictionaries unterscheiden sich auch im ausgegebenen
Endzustand; ohne damaligen Eingangshash ist das kein Beweis verschiedener
geladener Replay-Saves. Die negative ursprüngliche Routenquelle (Tod im zweiten
Rückweg) bleibt im Originalarchiv erhalten. Keine Survival-Ausnahme, Heilung,
Teleportation oder verlängerte Frist wird vorgeschlagen.

## Blocker und konkreter nächster Abschnitt

Lars verlangt ausdrücklich: „Messungen nur im bestätigten exklusiven Hostslot.“
Die verbindliche R33-Koordination weist die Bestätigung R33-01 zu.
[Anmeldung](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-6036070915),
[dateigenaue Präzisierung](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-6036102342)
und [Zwischenstand](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-6036192184)
sind veröffentlicht. Bis zu diesem Checkpoint liegt keine R33-01-Bestätigung vor.
Keine eigene schwere Messung oder eigene Godot-Prüfung wurde gestartet. Andere
Fachjobs laufen tatsächlich auf demselben Host; ihre Zeiten werden nicht verwendet.

Vorbereitete Umgebung: Host `3c32128a52fd`, Intel Xeon Platinum 8573C, Cgroup
8 CPU/8 GiB; Godot `4.6.3.stable.official.7d41c59c4`. Zunächst headless; keine
GPU-/Treiber-/VRAM-Freigabe. Die Versionabfrage ist kein Benchmark.

Originalfixture: `route-source` aus dem R32-Archiv. 51 Wegpunkte / 43,722 m,
Seed 15838, 2×8-s-Hinweg mit physischem Rückweg, Save/Menu/Reload, 60 Framecap,
unveränderte 120-s-Stufengrenze. Tatsächliche Eingangsdigests:

| Objekt | SHA256 |
|---|---|
| Original capture.json | `d51df978638b92f805f0b357e8d42c01a953dd356936795c55a5d0d35ac6d305` |
| JSON-sortierte Replay-Eingangs-Save | `870a0b5998277d7d7cc82d82abadcd56d68604c4eb6be45950ab2776acf34664` |
| JSON-sortierte feste Wegpunkte | `d0565230640b838ee317313c51f8649fa16f41f8bd3f2527f32831d64bf90c70` |

Nach Slot- und Patchbestätigung: saubere QA-Basis, Import/engste Fachchecks und
die unveränderte Replay-Route mit `--population-readiness --population-phases`;
anschließend begrenzter belegter Fix mit derselben Route. Keine identischen
laufenden CI-Jobs lokal duplizieren. Entladen/Neuladen, Ursprungwechsel,
Save/kalter Neustart und direkte Verbraucher sind vor einer echten
Produktlieferung noch auszuführen. Mesh/Collider/KI-Ereignisse der bestehenden
Beobachtung bleiben obere Beobachtungsgrenzen, keine GPU-/Physicsserver-Zeitstempel.

Lars' Ziel-PC und 600-s-Windowsroute bleiben getrennt offen. Die aktuell fehlende
Hostbestätigung ist davon unabhängig; neue Softwarekorrekturen sollen nicht
auf die spätere Ziel-PC-Abnahme warten.
