# R32-17 / PT17-16 / #182 – Dorf- und Umweltbewegung

Draft-Fachlieferung gegen `agent/integration-r32-20261002`, feste Basis
`2a738a4891a8de11d682c469833ade4dc9b01dfb` / Tree
`f2bda4f815df1c73b9d740ca5282917523faf618`. Kein Merge, keine Schließung von #182.

## Belegte Korrektur

`VillageWorkMotion` benutzt den bestehenden `GameState.simulation_delta`-Port.
Bei Simulationstempo 0 stehen Lebensdauer und Pose still; Tempo 2 verdoppelt auch
den Darstellungsfortschritt. Die normale SceneTree-Pause funktionierte bereits
vorher. Das Werkzeug folgt nun der gedrehten `CreatureRuntimeVisual`, während
der radiale Physikroot seine Basis behält. Stabile Bewohnerkennungen erhalten
SHA-gemischte Phasen, damit auch benachbarte IDs deutlich auseinanderliegen;
Akteure ohne diesen Port behalten eine feste Nullphase. Wiedererzeugung startet
eine lokale kosmetische Arbeitsbewegung reproduzierbar. Die Amplitude bleibt
0,32 rad (18,33°), ein wiederverwendetes Werkzeug pro Bewohner, Ruhepose versteckt.
Kein Werkzeug erzeugt oder zählt Arbeit: Der unveränderte Controller pulst
weiterhin erst nach tatsächlich fortgeschrittenem `VillageWork`.

Produktion geändert: ausschließlich `world/tribe/village_work_motion.gd`.
Dorfwirtschaft, Arbeits-/Lieferzähler, Saveformat und gemeinsame Clockhosts bleiben
bytegleich zur Basis. `village_visuals.gd` hat bereits begrenzte 55-m-Werkzeugnähe
und 60/70-m-Labelhysterese; hier kein unbelegter Umbau. R32-09 besitzt Windshader.
Die vorhandene Wasserclock ist in der regulären Kampagne bereits an die gemeinsame
Kampagnenzeit gebunden; nötige zusätzliche Besitzeranschlüsse gehen an R32-01.

## Fachnachweis

Finale Runtime-SHA256:
`5a715acbe2d09978bd28c29dec671282d4ac5306f77790fbb003de4fe689e664`.
Godot `4.6.3.stable.official.7d41c59c4`.

`r32_17_work_motion_test`: Basis 6 negative von 10 Kontrollen, Fix 10/10 positiv
mit echten Autoloads. Benachbarte IDs, Körperdrehung, Tempo-/Tree-Pause, Tempo 2,
Wiederverwendung, Auslaufen/Ruhepose, negative Delta und identische Wiedererzeugung.
Originale des finalen Laufzeitcodes: `ci-36973587830/tool-{before,after}.log`.
Die älteren `tool-*.log` und `tool-checks.json` am Verzeichnisroot gehören zur ersten
Phase-Mischung und sind historische Gegenproben, keine zusätzliche finale Abnahme.
`world_motion_visual_test` und `int30_village_view_probe` waren als direkte
Headless-Verbraucher positiv; Logs erhalten, unveränderte Consumerquellen.

`registry-owner.patch` registriert die drei neuen Godot-Einstiege genau einmal in `terrain_art`.
Nur in einer isolierten QA-Kopie statisch geprüft: 270 Tests / 18 Verträge;
konservativer Änderungsplan fordert FULL/Main. Dies war **nur ein Plan**. Die volle
Suite, verpflichtende Gates und Exporte bleiben bei R32-01.

## Produktionsprop-Kosten

Ein isolierter GitHub-Runner, echte Produktions-Pulse plus Updates, 64 warme
Vorlaufgruppen und 512 gemessene Gruppen pro Umfang; gleiche Engine und derselbe
Runner seriell vorher/nachher. Kein Rendern, kein KI-/Routen-/FPS-Benchmark.
SHA-Mischung findet einmal bei Erstellung statt und gehört nicht zu diesen Updates.

| Werkzeuge | Basis p50 / p95 / p99 / max (µs) | Fix p50 / p95 / p99 / max (µs) |
|---:|---|---|
| 1 | 1 / 1 / 1 / 19 | 2 / 2 / 2 / 21 |
| 3 | 2 / 2 / 2 / 22 | 5 / 5 / 5 / 23 |
| 12 | 6 / 6 / 7 / 23 | 19 / 20 / 29 / 30 |
| 32 | 16 / 16 / 25 / 26 | 50 / 60 / 63 / 84 |

Der korrekte Delta-/Transformanschluss kostet hier zusätzlich CPU-Zeit; kein
Performancegewinn behauptet. Auflösung der Uhr 1 µs; kleine Einzelwerte nicht als
präzise absolute Hardwarebudgets ausgeben. Originale und Engine im gleichen
`ci-36973587830`-Verzeichnis.

## Reale kombinierte Kampagnenprobe

`review_r32_17_motion.py` bereitet einen normalen Seed-15838-Save vor: öffentliche
Heimatgründung, ausdrückliche Epochenbestätigung und echte wartende Dorfbewohner.
Beide Quellstände laden danach denselben Save samt unveränderlichen Regionsblobs.
Die Kamera beobachtet reale Bewohner/Vegetation/Wetter; kein nachgespielter
Arbeitspuls und keine hineingesetzten Wassermeshes. Tatsächliche Holzarbeit und
physische Lieferung werden separat geprüft. Clips: Arbeit, Simulationstempo 0,
SceneTree-Pause, Fortsetzung, Nah→Fern→Nah, verfügbare echte Wasseransichten,
öffentlicher Pause/Save/Menu/Load/Fortsetzen-Ablauf. Pro Frame bleiben Kampagnen-,
Wind- und Wasserclock, Wetter, Bewohnerauftrag/Arbeit/Fracht, Werkzeugpose und
Vorrat im Trace. Ein naher Sample allein ist keine Sichtabnahme eines Sees/Meers.

640×360, feste Simulation 30 Hz, native OpenGL/Forward+ auf llvmpipe/Mesa in Xvfb.
PNG-Readback/Encoding und feste Simulation sind ausdrücklich keine FPS-Freigabe.
Draw-Wartezeit und PNG-Lese-/Schreibzeit werden getrennt erhalten. Basis und Fix
werden je Renderer seriell auf demselben unabhängigen Host ausgeführt. Der finale Vergleich benutzt den ursprünglichen GL-Save aus Run 36974907744
in beiden Spalten. Die älteren Forward+-Versuche behalten ihre jeweilige
Quellen-/Fixtureidentität; sie sind keine vollständige Renderabnahme.

## Vereinbarte Gehroute

`agreed-route-reference.json` identifiziert R32-02s Originalsave/Regionsblobs und
51 Wegpunkte / 43,72244 m. Route-SHA256
`d0565230640b838ee317313c51f8649fa16f41f8bd3f2527f32831d64bf90c70`.
Vorhandenes `profile_performance.py` unverändert: zwei Zyklen, erster und geladener
Hin-/Rückweg getrennt, gleiche Referenzpunkte, echte Spielerphysik, keine Heilung
oder Teleports. Diese Kreaturenroute enthält keine aktive Dorfwerkzeugbewegung;
sie kann deren Mehrkosten nicht isolieren. Headless / 1920×1080 im Rezept / 60-cap
ist kein gerendertes 1080p-Ergebnis und keine 600-s-Windows-Abnahme.

## Negative Originale und Besitzeranschlüsse

- Run 36972921981: superseded/cancelled, keine Abnahme.
- Run 36973587830: native GL-Aufnahme überschreitet 600 s in `distance_out`;
  kein fertiggestellter Film. Tooltests/Kosten separat positiv. Originalartefakt
  11213580013, SHA256 `f43b56f5d5b157aa04a2c771606b034a65794db29c08844a6554f05908652f45`.
- Run 36974907744 / Forward+: Replay lädt, Dorfsteuerung wird vor Capture nicht
  aktiv; null Frames, keine Sichtabnahme. Original 11212604718, SHA256
  `9a3e6583846251db91c5fbfd63d8d7ed7908faf003b6cfd99494d91802d0fc9d`.
- Run 36975391617: Basistree durchläuft beide Referenzzyklen, danach wird die
  CLI wegen `--compare` mit falschem `--replay`-Verzeichnis abgewiesen. Original
  11213840681, SHA256 `dad8a38debc5a1883ca4c42d038a07214f2821be5ce9c06e58f69cdc923b85c8`.

Die additiven optionalen Workflows liegen ausschließlich als konkrete
`*-workflow-owner.patch` an R32-01 vor; `.github` im Fachbranch unverändert.
Die Diagnosebranches sind separate Prüfquellen mit genau zusätzlicher Workflowdatei.
Keine lokalen Godot-Prozesse während dieser CI-Aufnahmen. Frühere ungesperrte
leichte Headless-Läufe wurden in #137 als mögliche Fremdlast gemeldet; ihre Zeitwerte
werden nicht als Routen-/FPS-Abnahme verwendet.

Ziel-PC Ryzen 7 9800X3D / RTX 4070 Ti / 32 GB, reale GPU-/VRAM-/Treiberdaten,
600-s-Route, gemeinsame integrierte Wind-/Wasser-/LOD-Sichtabnahme und #182 bleiben
bis zum jeweiligen Nachweis offen.

## Präzise Fortsetzungsprüfung und visueller Observer

Die historischen Migrationsfingerprints verkürzen Dezimalwerte und sind laut
Quellvertrag keine präzisen Save-Writer. Die ursprüngliche GL-Probe
36979624473 meldete deshalb zusätzlich einen Fingerprintunterschied nach Load.
Originalsave und History-Snapshot unterscheiden sich bei Hydration/Arbeitszeit um
rund 10⁻¹⁴ bis 2×10⁻¹⁶; Aufträge, Fracht, Vorrat und Lieferzähler sind gleich.
Die Abweichung des alten Fingerprints ist damit ein ungeeigneter Prüfvergleich,
kein belegter Verlust von Wirtschaftsfortschritt.
Der neue Prüfvergleich hält alle diskreten Werte exakt, toleriert ausschließlich
nichtganzzahlige Double-Rundung bis 2×10⁻¹⁵ relativ (~9 ULP) und protokolliert
jede solche Differenz mit Pfad, beiden Werten und Budget. Ganze Live-/Disk-/Load-
Dörfer bleiben im Originaltrace. Test `r32_17_checkpoint_test` akzeptiert die
Rundung und weist geänderten Holzvorrat, Auftrag, Arbeitsfortschritt und fehlende
Daten zurück. Kein Wirtschaftscode und kein Save-Writer wurde geändert.

`view-focus-owner.patch` für R32-01 setzt den visuellen Terrainfokus nur, wenn die
Dorfkamera tatsächlich current ist. `set_motion_hint` und `stream_at` bleiben
immer am physischen Dorf. Ohne Anschluss wechseln Dorfkamera und 20-km-
Meeresbeobachter jeden Frame die visuelle Anforderung: 150006 ms / 35157
Vorbereitungsframes, Meeresmesh nicht veröffentlicht. Der echte Kamera-Advance-
Test ist unmodifiziert negativ und mit isoliertem Besitzeroverlay 2/2 positiv.
Die Produktionsdatei `tribe_camera.gd` wird im Fachbranch nicht direkt verändert.
Der finale Videovergleich enthält **denselben** Anschluss in beiden Spalten;
dessen Hash und dirty-Overlay stehen jeweils in `source.json`. Er kann daher
keinen visuellen Vorteil nur in der Fixspalte vortäuschen.

## Routenvergleich: vollständige Läufe, gesonderte Besitzer-Auswertung

Run 36976460860: beide echten Routenprotokolle mit zwei Zyklen vollständig und
positiv, keine Überlebensausnahmen. Die vorhandene Vergleichsauswertung lehnt
jedoch `initial_address` ab: Sie misst vor 60 Settleframes 15 cm verschiedene
Höhen. Die erste tatsächlich gelaufene Breadcrumbposition ist bis 65 nm gleich,
UV bis 1,4×10⁻¹⁴, Körper, Fläche, Route, Host, Renderer und Einstellungen gleich.
Der ursprüngliche CI-Vergleich bleibt negativ. `route-comparison-owner.patch`
für R32-01 benutzt die erste reale Gehposition und behält alle bisherigen
Identitäts-/Rezept-/Renderer-/Hostgates und 0,1-m-Höhentoleranz bei. Fehlende
Breadcrumbs werden abgewiesen. Drei Python-Gegenproben bestätigen: gleiches
Gehen trotz Settleoffset akzeptiert; tatsächliche Körper-/Face-/UV-/Höhen- und
Routenänderung oder fehlende Messung abgewiesen. `owner-preview-summary.*` ist
klar eine spätere Besitzerpatch-Auswertung der unveränderten Originaldaten.

| Zyklus / Abschnitt | p95 Basis→Fix (ms) | p99 Basis→Fix (ms) | max Basis→Fix (ms) | >100-ms-Spitzen Basis→Fix |
|---|---:|---:|---:|---:|
| kalt hin | 79,964→85,531 | 144,946→145,138 | 224,721→212,808 | 9→9 |
| kalt zurück | 19,708→18,497 | 21,320→20,814 | 23,941→23,110 | 0→0 |
| geladen hin | 21,898→22,004 | 107,225→117,272 | 177,832→174,399 | 5→5 |
| geladen zurück | 18,734→19,193 | 21,100→21,555 | 22,846→23,069 | 0→0 |

Diese Werte zeigen gemischte Änderungen einschließlich p95/p99-Regressionswerten;
kein Verbesserungs- oder Budgetbeweis. Native Render-Warte-/Readbackkosten der
Kampagnenaufnahmen werden davon getrennt berichtet.

## Weitere erhaltene Negativversuche

- Run 36974907744 GL: mechanisch 600 Frames pro Quelle, Arbeit/Lieferung/Save-Load
  positiv; HUD verdeckt die Szene, Pause startet mit inaktiven Tools und Wasser
  nur gesampelt. Teilkontrolle, ausdrücklich kein verlangtes fertiges Vergleichsvideo.
- Run 36976575413 Forward+: null Frames, Navigation nicht innerhalb 45 s fertig.
  Artefakt 11213029352 / SHA256
  `4b90fda35eaec9001a64d093209117105d0c11314f0125e15576971a6005c6f6`.
- Run 36977412373 Forward+: beide 900-s-Aufnahmen unvollständig; Teilfilme erhalten,
  kein Endgatevergleich. Artefakt 11214324361 / SHA256
  `664e40782376b4ecbdf69c9ed2ed317bda6b6f7921ab353e28225ff27181a334`.
- Run 36979624473 GL: tatsächliche aktive Werkzeugpause korrekt negativ an Basis,
  fehlendes Meeresmesh und historischer Save-Fingerprint zusätzlich negativ;
  Fixfilm wurde von der damaligen Endassertion nicht gestartet. Artefakt
  11215313421 / SHA256
  `037cca64c9758fad370cd31bc84d4353814109bffef96d26d7c209ea0b9cdaba`.
- Run 36979624473 Forward+: beide Teilstücke 360 Frames, 900-s-Grenze; Original
  11216522614 / SHA256
  `c859c303b6a608a42a6e83ab8fb78175798be6adc2a0121fde9922b7d8f66125`.
- Run 36984887046: Kamera-Fachtest negativ/positiv korrekt; neue eigene Rundungsprobe
  5/6, vor Capture abgebrochen. Original 11217435169 / SHA256
  `d453132ead31eea78fd32f6a6727654f4e7e43e13e30c48898212a9eb76d4a39`.
  Korrigiert, weil Variantgleichheit winzige Doubledifferenzen verschlucken kann;
  Subtraktion erfasst sie vor der expliziten Budgetentscheidung. Kein Gate entfernt.

`unchanged-owner-files.json` belegt die bytegleichen fremden Produktionsbereiche.
Die native Szene nutzt echtes klares Wetter mit ca. 20 % Wolkendecke, leichtem
Wind und Böen. Kein Regen-/Schneefrontwechsel wird in diesem kurzen Clip behauptet.

Für R32-01: `registry-owner.patch`, `view-focus-owner.patch` und
`route-comparison-owner.patch` seriell übernehmen, danach die volle Auswahl mit
Main und die vier Pflichtgates/Exporte auf dem tatsächlichen Merge-Tree ausführen.
Die optionalen Workflowpatches sind additive Reproduktionsrezepte. `registry-static.json`
und `registry-plan.log` sind ausdrücklich keine ausgeführte Godot-Suite.

## Finaler nativer GL-Vergleich – vollständiger positiver Fix

[Run 36985268590 / Job 110768755930](https://github.com/MajorDragonfly/voxelverse/actions/runs/36985268590/job/110768755930)
ist erfolgreich. Geprüfter Featurecommit `f2b0669a60db33ddecfe6704294add5f0219e910` /
Tree `21ae6873ae5eeb3e4b1e608c196af780c916be43`; Diagnosecommit
`0c48d235f52e89c060222d8d5a7d2c7d5c6fd10d` enthält zusätzlich nur den Workflow.
Die ursprüngliche Basisspalte hat die kopierten identischen eigenen Proben;
beide Spalten enthalten identisch den angekündigten Kamera-Besitzerpatch.
Die Basisspalte hat zusätzlich die zwei kopierten eigenen Testdateien; die
Fixspalte hat die zwei frisch importierten Test-UIDs als protokollierten dirty-Anteil.
Das abschließende Fachdiff ergänzt UID-/Auswertungsdateien und Nachweise;
keine zusätzliche Änderung der geprüften Werkzeugproduktion.
Originalartefakt 11218286484 / SHA256
`9b19ddf89d705d458937a07d1e724416f10779ef5346dc1f205a9baa3513b048`.
Originale komprimiert im Unterverzeichnis `ci-36985268590-native`.

Beide Spalten liefern 510 Frames / 17 s bei 30 Hz. **Fix 23/23 positiv**;
Basis einzig erwartungsgemäß negativ bei `tempo pause freezes tool pose/lifetime`.
23 Kontrollen enthalten tatsächlich fortgeschrittene Dorfarbeit mit sichtbar
aktiven Werkzeugen vor Pause, physische Holzlieferung, beide veröffentlichten
Wassermeshes, beide Pausen und öffentlichen Save/Menu/Load/Fortsetzen-Ablauf.
Fixture-SHA, Grafikeinstellungen, Kamerapositionen, Kampagnenclock sowie alle
Auftrag-/Arbeit-/Fracht-/Vorratswerte sind frameweise exakt gleich, auch nach Load.
Nur die zu prüfenden Werkzeugposen unterscheiden sich; fremde Shader und der
Kameraanschluss sind gleich. Vorrat 0→3 beim Save→4 nach Load. Die Load-Daten
stimmen mit dem gespeicherten Dorf ohne Rundungsrest überein; Live→Disk hat drei
vollständig protokollierte Double-Rundungen, maximal 1,421×10⁻¹⁴.

Sichtprüfung anhand unverdeckter Originalbilder und vier Pausenvergleichsbilder:
Basis 3→0 sichtbare Werkzeuge in Tempo-Pause; Fix 3→3 und exakt unveränderte
Pose/Lebensdauer in allen 30 Tempo- und 30 Tree-Pause-Frames. Tatsächliche
Arbeit zeigt verschiedene Werkzeugstellungen. Spitze ≤0,32 rad, höchstens
3 Werkzeuge. Beim Fernweg sind Werkzeuge aus; nach Rückkehr erscheinen wieder
2 aus wirklicher Arbeit. Labels behalten ihre bestehende Entfernungshysterese.
Wasser und Vegetationsclock stoppen in beiden Pausen; Meer und See bleiben
als echte Oberflächen sichtbar. Die Meerespublikation benötigt nun 39,010 /
38,518 s statt des negativen 150-s-Limits mit ständigem Fokuswechsel.

**Keine pauschale Flimmerfreiheit:** In beiden Spalten zeigt die erste
Meeresansicht kurz das bestehende Screen-Space-Ditherraster der LOD-Publikation;
die anschließende Meerespause zeigt eine geschlossene blaue Oberfläche. Feine
Voxel-/Foliageraster und entfernte LOD-Wechsel bleiben gemeinsame Sichtbefunde,
keine bewiesene neue Werkzeugregression. Wind-/Rebase-/Transitionskorrekturen
R32-09 sowie gemeinsame Terrain-/LOD-Abnahme bleiben außerhalb dieses Fachdiffs.
Vegetation wirkt im tatsächlichen leichten Wind dezent; keine Starkwind-/Regen-/
Schneefreigabe aus dem kurzen Klarwetterclip. 640×360 begrenzt die Sichtprüfung.

| Native Capturekosten | Basis p50 / p95 / p99 / max (ms) | Fix p50 / p95 / p99 / max (ms) |
|---|---|---|
| Warten auf Prozess + Draw | 999,788 / 1505,452 / 1536,129 / 1832,119 | 980,719 / 1480,645 / 1531,507 / 1783,085 |
| PNG-Readback/-Schreiben | 43,746 / 51,453 / 52,909 / 76,773 | 43,544 / 51,414 / 52,910 / 77,374 |

Je 510 Messwerte, Mesa 25.2.8 llvmpipe (LLVM 20.1.2), X11, tatsächliche Aufnahme
670,061 / 664,013 s. Diese instrumentierten Softwarekosten sind **keine FPS**,
kein isolierter GPU-Timer und kein Ziel-PC-Beweis. Der native negative/positive
Kameratest (1/2→2/2), präzise Checkpointtest (6/6) und originaler Tooltest (4/10→10/10)
sind getrennte Fachnachweise; der Tooltest stammt aus dem bytegleichen früheren
Produktionsstand. Drei Route-Besitzerpatch-Gegenproben sind ebenfalls positiv.

Videos: `R32-17-Vergleich.mp4` fügt nur Spalten-/Abschnittstitel hinzu;
`R32-17-Basis.mp4` und `R32-17-Fix.mp4` sind unveränderte native Einzelspalten.
Beide Vergleichsspalten enthalten den identischen R32-01-Kameraanschluss.
Originale einschließlich alter negativer Versuche sind im separaten Rohpaket
mit Dateihashes erhalten. Vollständige Merge-Tree-Prüfung, Exporte, Forward+,
R32-09-Anschlüsse, Ziel-PC und #182 bleiben offen; Draft bleibt Draft.
