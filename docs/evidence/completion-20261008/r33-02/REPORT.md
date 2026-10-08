# R33-02: getesteter Kandidat verworfen

Abschlussbewertung vom 8. Oktober 2026: Die ursprünglichen Funktionsprüfungen bestehen. Die Scheduling- und Stage4-Korrektur erreicht die allgemeine Performanceabnahme nicht. Die reproduzierbare Kaltreturn- und Publikationsregression bleibt bestehen. Dieser begrenzte Versuch ist beendet; es folgen kein Produktmerge, keine Ready-PR und kein weiterer Enginelauf.

PR #272 bleibt auf dem ursprünglichen Head `29b7557ffa3fa1ccd665b664af5b69851c071ef9`. Die Closure wird vom Root nach Veröffentlichung der Abschlussbelege ausgeführt. Die hier gemessenen zusammengesetzten Quellen sind ausdrücklich keine Validierung genau dieses ursprünglichen PR-Heads.

## Neueste gemessene Quellen

Beide Quellen enthalten exakt denselben Root-UI-Stand `0a76b253af72ddb8b2bbf6453ac4209b2600ed7a`; der gemeinsame Minimap-Blob ist `cf558fb6d784f536e164de4909b1d46de5bdfd64`. Before enthält den historischen monolithischen Skinpfad. After enthält die vorbereitete bounded Skinpipeline, die rein rechnerische Schedulingkorrektur `66c2e087647de03e8282028bd876d112b51ad9b1` und den separat statisch freigegebenen Stage4-Port `16c05633427d229d0f4ba6a3c8cb4f1e7ada5ead`.

| Bindung | Before | After |
|---|---|---|
| Commit | `b87bfd8e1c2322fdb3836f150faa9a6025bfb103` | `ac678b3b7999fe90695cc769f4f8f09490eb41c9` |
| Tree | `25bcc6d7a3815f9d21f3dbcf1e7287dbb6849b8e` | `6cf5468bb2d6e57fb73d349eabd26690d96eab2c` |
| Source SHA-256 | `b765f3a87ce35d6690aa3377bc9204ebf2709e7c9a455a9805e75024880fbeb4` | `892b81a10f21bd1c0cee7c112af70740ae30592a2110d5d492431511ecdcce00` |
| Index SHA-256 | `dbcf963bdef2b8bafe57eebcd6f700f9458cf784705215e7207fc169352aa37f` | `1d20c334d7b809cadca6d18438c6c8030c16bbd5768437f02f513f3b43494c77` |
| Dateien | `10000` | `10003` |
| Quellbytes | `902394904` | `902428968` |
| Start/End-Manifest SHA-256 | `947389d24f84e2a13373231147ee3627cce21351abd9d52329516b8fcb7e9ad7` | `732e874a41e707892b8f5db28e705c1ba4ed93445ca277d5f57724e3a4c39770` |

Für beide Quellen sind vollständige Start/End-Manifeste identisch, jedes SourceRun-Observergebnis ist `unchanged`, Status `stable`, `reusable=true`, Tree/Index unverändert und der Checkout sauber. Der überwachte Umfang enthält tracked und nicht ignorierte Repoeinträge; ignorierte/generierte Caches und Symlinkziele sind ausdrücklich nicht Bestandteil dieses Sourcebeweises.

## Reale Durchführung und positive Prüfungen

Root #137 reservierte die Importvorbereitung am `2026-10-08T20:22:24.763Z` und die separate Messsektion am `2026-10-08T20:38:30.643Z`: https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-6035774590 . Beide Originalimporte erfolgten vor dem finalen Freeze, unter den unveränderten 180s-Import-/Art-/Sourceprüfungen. Before Import 7,955s PASS, After 8,955s PASS; Art- und Sourceverträge auf beiden Quellen PASS. Die drei Consumer und Living verwendeten danach den positiv importierten Ressourcenstand mit dem vom Originalvalidator unterstützten `--skip-import`. Der unveränderte AB-Runner behielt seinen eigenen Importcachecheck.

| Prüfung auf After | Tatsächliches Ergebnis |
|---|---|
| SurfacePopulationBudget einschließlich rein additiver Cases | PASS, 3,174s |
| RuntimeGeometryBatch | PASS, 2,121s |
| CreatureBodyContract | PASS, 10,044s |
| Original LivingCreaturesWorld, echte 120s-Deadline | PASS, 91,251s |
| Original AB Before | PASS, Exit0, 87,705s |
| Original AB After | PASS, Exit0, 87,762s |

Der Livinglauf behielt die vollständigen Originalprüfungen für reale physische Tiere, Geometrie/Collider/Floor, eingefrorene Identität, Speicherung/Reload, Cancellation und echte teilweise/erschöpfte Kadaver. Nur die originalen 120s statt des späteren LONG_TESTS-420s-Eintrags wurden durch den bereits gebundenen externen Launcher verwendet; kein Oracle wurde abgeschwächt.

Engine: Godot `4.6.3-stable.official.7d41c59c4`, SHA-256 `f64d4ed19fc9df9440321653fcc80df8c6e365ba7b6de0a29e2cfa9fa71bfeb3`. Messung auf Host `7f573e0a2ae8`, headless; CPU-/Wallframebeobachtung, keine GPU-/Forward+- oder Ziel-PC-Abnahme.

Guardbindungen: Originalhostwrapper SHA-256 `a6ee852de140b0b159940873dbf2c386c0255840ef3b56e7b80b29a2cb81c61d`; Importlauncher `56b504f886818938a01f0136613fe83f03306910e1a07db215513f69d3097108`; Messlauncher `757313931b26b41ca5d243e7f9f2b57aeeb10b006efa8ebd0f3e9c0b829958f6`; Original120-Livinglauncher `7fff938f11fa9792f1caf9a4fe3ffb19c9436042591971bd51b8275670d8ad62`.

Die tatsächliche Messsektion endete nach 303,593s mit Exit0, Fehler=null, SourceStamp unverändert. In sämtlichen Hostsnapshots trat keine fremde Godot auf. Alle acht beobachteten Engineprozesse hatten eine tatsächliche Kernel-/Namespace-PID-Bindung. Am END waren Kernel-Godot≠Z leer und beide Locks nonblocking frei: `/tmp/voxelverse-heavy.lock` und `/tmp/voxelverse-r32-db514e109ac6-heavy.lock`.

## Vergleichbare Originalpaarung

`controlled_comparison_allowed=true`, `blockers=[]`. Rezept, Host, CPU, Engine, Renderer, tatsächlicher Walkingstart und Populationcoverage passen. Zwei Zyklen mit je 8s Hin- und Rückweg, Original-60fps-Cap, 60 Settleframes und 120s-Stagelimit bei 1920×1080. Je Zyklus auf beiden Quellen 12 reale Tiere und 12 Pflanzen. Alle Readiness-/Work-Droppedzähler sind 0. Unveränderte Produktgrenzen: 2ms/4096 Skinunits, 250ms-Due-Tick, zwei Spawnversuche, höchstens eine physische Publikation pro Update, Skin-LRU8.

Replayfiles SHA-256 `7f2d9222e27859422bfd13cfe5111c32a70e0dba90668d44252e6882564f6e05`; kanonisches Save `870a0b5998277d7d7cc82d82abadcd56d68604c4eb6be45950ab2776acf34664`; Route `d0565230640b838ee317313c51f8649fa16f41f8bd3f2527f32831d64bf90c70`; Seed15838.

| Bewegung, alle vier Etappen | Before | After |
|---|---:|---:|
| Frames | 1577 | 1627 |
| p50 ms | 16.649 | 16.604 |
| p95 ms | 25.495 | 23.244 |
| p99 ms | 90.365 | 73.875 |
| Max ms | 193.455 | 148.441 |
| >33ms | 53 | 48 |
| >50ms | 37 | 41 |
| >100ms | 10 | 4 |
| Peak Prozess-RSS Bytes | 537288704 | 536326144 |

| Zyklus/Etappe | p95 Before→After ms | p99 Before→After ms | Max Before→After ms | >33/>50/>100 Before→After |
|---|---:|---:|---:|---|
| 0 / walk_outward | 78.14→58.885 | 144.882→87.169 | 193.455→102.308 | 39/28/6→27/26/1 |
| 0 / walk_return | 21.875→22.669 | 25.986→50.731 | 27.903→130.196 | 0/0/0→6/5/1 |
| 1 / walk_outward | 27.249→23.244 | 109.968→66.328 | 148.904→148.441 | 13/9/4→15/10/2 |
| 1 / walk_return | 19.39→21.407 | 25.495→29.612 | 39.915→32.096 | 1/0/0→0/0/0 |

| Publikation / Skin-CPU | Kalt Before→After | Reload Before→After |
|---|---:|---:|
| Erstes physisches Tier ms | 864.92→1778.996 | 453.297→459.323 |
| Alle zwölf erstmals physisch ms | 6707.844→12424.65 | 5947.096→6747.564 |
| SkinCPU monolithisch→bounded ms | 321.253→463.243 | 232.677→230.692 |
| Beobachtete maximale bounded Slice ms | 4.838 | 2.752 |

Publikationszeiten beginnen bei der ersten beobachteten Tierrecord-Erfassung, sind durch die bestehende Readiness-Abtastung Obergrenzen und keine exakten Storagewrite- oder GPUzeiten. Auf beiden Quellen wurden kalt 86 und im Reload 88 Tierrecords beobachtet. Die physische Endpopulation ist identisch; keine Population wurde für einen schnelleren Frame reduziert.

## Konkreter verbleibender Fehler

Das bessere aggregierte p95/p99 genügt nicht: Der Kaltreturn steigt von 27,903 auf 130,196ms Max, p99 von 25,986 auf 50,731ms; fünf erste physische Tierpublikationen verschieben sich in den Rückweg. Before publiziert zwei Tiere im Settle und zehn im Hinweg; After sieben im Hinweg und fünf im Rückweg. Die vollständigen zwölf kalten Tiere erscheinen nach 12.424,650 statt 6.707,844ms; im Reload nach 6.747,564 statt 5.947,096ms. Außerdem steigt die Anzahl der >50ms-Bewegungsframes von 37 auf 41. Deshalb ist die allgemeine Performancehypothese verworfen.

Der 130,196ms-Rückwegframe bei Tick39237925 gehört zur ersten physischen Beobachtung von `object_fe9495decf5a74da236ef71e7d929344`. Er enthält tatsächlich SkinCache HIT0,016ms, PreviewBodyParts58,271ms, BodyStats85,417ms und ActorReady85,966ms. Diese Intervalle sind verschachtelt; ihre Intervallunion beträgt90,913ms, der unzugeordnete Rest39,283ms. Kein SkinPrepareChunk überlappt diesen Frame. Derselbe Record wurde auf Before bereits im Hinweg publiziert. Stage4 erklärt die aktuelle Spitze nicht unmittelbar; unverändert schwere erste Parts-/Statskonstruktion wird durch verspätete Publikation in den Rückweg verschoben.

Kein Verlust von Layout-/Partscachewärme wurde belegt. SkinBuild und der monolithische Bodybuilder populieren keine Parts-Meshcaches; diese bleiben unverändert im gemeinsamen ActorPreviewpfad. Die frühere opt-in Diagnose beobachtete keine Primitive-clear96-Ereignisse, ist jedoch ausdrücklich keine gültige Generalabnahme und kein Trace genau des letzten Laufs. Es wurde keine Cachepolicy verändert.

## Erhaltene historische Beweise

Alle historischen Checkouts, Commitheads, Start/End-Manifeste, Rohreports und negativen Befunde bleiben unverändert. Vollständige historische Bindungen stehen auch maschinenlesbar in `source-bindings.json`.

### current-before-source

Commit `6acdc61f4d532dfa1fc15b1676ae0637ce11dc84`; Tree `34eec087353cdf7571517d2bc0b61dde0f1cf1cf`.

Source SHA-256 `3ef1f76d16211ed777f2756b54bec88dc0cfcca5e6e24ea3d81242a7198c7fe1`; identisches Start/End-Manifest `46a14bceea93eab6398a31e9916f1ed2c2579af4910658494aa2ff2a10bfdbb1`. Index SHA-256 `71ed577fa9aa9943e7ce4b323d8e2395c6d5b3e6ec3573a9e896cae442cedaf8`; 9989 Dateien / 902293751 Quellbytes.

Tatsächlicher SourceRunstatus `prepared`, reusable=`true`.

177 bytegleiche Importdeskriptor-Touches sind hier als tatsächlich zugelassene `import_preparation` erhalten; die anschließende Route ist `unchanged`. Dies wird nicht in `stable` umbenannt.

### current-after-source

Commit `5ac290a5fab2589eac8e798a588a128d3cd38719`; Tree `950042b7d62f2440f9dea7364ff35f8b663eac33`.

Source SHA-256 `5e38760269348cb69915665fbca517ef32ebd076f4aa7c33e1f84cb6b64468ca`; identisches Start/End-Manifest `54701cf854017cb80756724a53ae28a2a441efd0e0e8da3ce3c6dfc7020e4e30`. Index SHA-256 `de4c73bb9d7179096c8f972efb42c16c4286690e682407517c8adf5f79e6a60f`; 9991 Dateien / 902319579 Quellbytes.

Tatsächlicher SourceRunstatus `stable`, reusable=`true`.

### phase-diagnosis-source

Commit `f67728df126f6a7208de8fabaac2a97e3caf0cfb`; Tree `a8575fa65b9c4850cf58f544e2716d2acc3d4764`.

Source SHA-256 `e5f979fb2dd5f31bce4ce52454d3ab6b7cd2d5ebb099bb7958251d6f0e6479e3`; identisches Start/End-Manifest `099be3a4c1ef660baaec24f883339a450034951f53c2c663d35c01d6b64ddd08`. Index SHA-256 `7a73ed6efe0bc785e5179efb11e992e2b5731cf09aff21073c52e45aa60269cf`; 9992 Dateien / 902326430 Quellbytes.

Tatsächlicher SourceRunstatus `changed_or_unavailable`, reusable=`false`.

177 bytegleiche Importdeskriptor-Touches erfolgten ohne zugelassenen Importvorbereitungsabschnitt. Der Runtime-Trace-Runner endete0, der externe Provenienzlauncher3; der SourceRun bleibt `changed_or_unavailable`/reusable=false trotz identischer Quellbytes. Nur kausale Job-/Stagebeobachtungen, kein akzeptierter AB-/Performancebeweis.

### final-before-source

Commit `16d9c7c1b69c71fb03e875d97601d3c39b224d92`; Tree `d8b444d52646be16a527935d1d45d007090f12e3`.

Source SHA-256 `310d9e701553a8b9c4b4ecf219880769384b230d11244a2f2a85e4109860ecce`; identisches Start/End-Manifest `1f2e5018db2e6390080fdb654bf3dbd0f146b47041247032517df6a9c267ce0f`. Index SHA-256 `3704b98ae2e64ed954c5d0e574fded3b01daa6e58d1a162a39a3454f9e8b0072`; 10000 Dateien / 902394433 Quellbytes.

Tatsächlicher SourceRunstatus `stable`, reusable=`true`.

### final-after-source

Commit `3d90eaa26979fabbe94e10052b69f867007394ac`; Tree `667022fc1c9873283248cf3701b0aef5b1c239b1`.

Source SHA-256 `88d0a99723b1dd39fc497bfae3526bdcafb6fa1e8882b07e753b163d3491f8aa`; identisches Start/End-Manifest `5c611d6781f76952d96cea68f39d7c45539dfe0c7f4cc8f52ab713800a361253`. Index SHA-256 `0f10e722efd54b39f7d804f59e98e9f0e6d6e71bad7b12cf57a4f2008535a3b6`; 10003 Dateien / 902428311 Quellbytes.

Tatsächlicher SourceRunstatus `stable`, reusable=`true`.

Historische gepaarte Gegenbelege: `current-ab.json` (6ac→5ac) zeigte p95 27,533→29,601ms, Kaltreturn-Max37,830→125,131ms und kalte Vollpopulation6.745,224→13.448,554ms. `final-ab.json` (16d9→3d90, gemeinsamer Rootfae) zeigte p95 27,985→26,167ms, Kaltreturn-Max49,156→133,381ms und kalte Vollpopulation6.763,700→12.482,133ms. Kein Vergleich zwischen diesen getrennten Paarungen wird als isolierter kausaler Stage4-Speedup ausgegeben.

Echte historische Original120-Lifecycleläufe bleiben PASS: Before6ac59,553s, After5ac94,759s, After3d9089,919s. Der neueste Afterac678-Lauf ist ein eigener echter91,251s-Lauf; alte Ergebnisse werden nicht auf neue Quellen übertragen.

## Nicht übernommene Option und Abschluss

Der enge Stage3-Locals-Patch auf Basis `3d90eaa26979fabbe94e10052b69f867007394ac` ist nur statisch geprüft. Er liegt unter `stage3-locals-optional/stage3-locals.patch` samt Kandidatdatei und STATIC_REVIEW.md. Er wurde weder angewendet noch importiert oder ausgeführt und ist ausdrücklich UNMEASURED / NOT ADOPTED. Es gibt keine Speedup- oder Acceptancebehauptung dafür.

Die allgemeine Produktverbesserung bleibt eine künftige Aufgabe mit unveränderten Kriterien für Kaltreturn, echte Publikationsreadiness und vollständige Population. Der aktuelle Diagnose-/Korrekturversuch ist abgeschlossen und wird ohne Produktübernahme geschlossen. Der ursprüngliche PR272-Head und sämtliche FrozenSources bleiben erhalten.

## Rohbelege und Reproduktion

Neuester Satz: `ui-matched-before/` und `ui-matched-after/` mit capture.json, frames.csv, route-summary.json und Originallog; `ui-matched-consumers/`, `ui-matched-living-after/`, beide `ui-matched-*-import/`; `ui-matched-*-source/` mit run-start.json, source-files-start/end.jsonl und provenance.json; `ui-matched-measurements-host.jsonl`, `ui-matched-measurement-end.json`, `ui-matched-imports-host.jsonl`, `ui-matched-import-end.json`, `ui-matched-measurements-launch.json`.

Ableitungen: `ui-matched-ab.json`, `ui-matched-ab-supplement.json`, `ui-matched-return-attribution.json`, `analyze-ui-matched-return.py`. Originalreport reproduzierbar mit `tools/review_r33_02_report.py --run before <ui-matched-before> <ui-matched-measurements-host.jsonl> --run after <ui-matched-after> <ui-matched-measurements-host.jsonl> --output <ui-matched-ab.json>` auf dem gefrorenen Afterwerkbaum. Bereits abgeschlossene Engine-/Importläufe werden dafür nicht erneut gestartet.

Das externe `analyze-paired-ab.py --runs <performance-runs> --output <neue-json-Datei>` berechnet alle hier verwendeten Aggregat-/Publikations-/CPUwerte reproduzierbar aus vorhandenen CSV-/Originalreports. Die mitgelieferte `ui-matched-ab-recomputed.json` ist strukturell exakt zum angegebenen Supplement gleich. Es startet keine Engine und überschreibt keine Originalbelege.
