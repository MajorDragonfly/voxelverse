R33-02 wird als getesteter und verworfener Kandidat abgeschlossen. Die allgemeine Performanceabnahme ist nicht erreicht; dieser Entwurf wird ohne Produktmerge geschlossen. Der ursprüngliche PR-Head `29b7557ffa3fa1ccd665b664af5b69851c071ef9` bleibt unverändert.

Die neueste kontrollierte Originalpaarung bindet auf beiden Seiten denselben Root-UI-Stand `0a76b253af72ddb8b2bbf6453ac4209b2600ed7a`. Before ist der historische monolithische Skinpfad; After enthält die Schedulingkorrektur und den statisch geprüften Stage4-Port. Die Ergebnisse beziehen sich auf diese genauen zusammengesetzten Quellen und validieren nicht rückwirkend den unveränderten ursprünglichen PR-Head.

| Neueste Bindung | Before | After |
|---|---|---|
| Commit | `b87bfd8e1c2322fdb3836f150faa9a6025bfb103` | `ac678b3b7999fe90695cc769f4f8f09490eb41c9` |
| Tree | `25bcc6d7a3815f9d21f3dbcf1e7287dbb6849b8e` | `6cf5468bb2d6e57fb73d349eabd26690d96eab2c` |
| Source SHA-256 | `b765f3a87ce35d6690aa3377bc9204ebf2709e7c9a455a9805e75024880fbeb4` | `892b81a10f21bd1c0cee7c112af70740ae30592a2110d5d492431511ecdcce00` |
| Index SHA-256 | `dbcf963bdef2b8bafe57eebcd6f700f9458cf784705215e7207fc169352aa37f` | `1d20c334d7b809cadca6d18438c6c8030c16bbd5768437f02f513f3b43494c77` |
| Identisches Start/End-Manifest | `947389d24f84e2a13373231147ee3627cce21351abd9d52329516b8fcb7e9ad7` | `732e874a41e707892b8f5db28e705c1ba4ed93445ca277d5f57724e3a4c39770` |

Beide SourceRuns sind `stable`, `reusable=true`, clean und vollständig für den gemeldeten Repoquellenumfang; alle Start/End-Bytes, Manifeste, Trees und Indizes passen. Root #137 autorisierte die separate Native-Sektion am `2026-10-08T20:38:30.643Z` unter https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-6035774590 . Originalhostwrapper SHA `a6ee852de140b0b159940873dbf2c386c0255840ef3b56e7b80b29a2cb81c61d`, Messlauncher SHA `757313931b26b41ca5d243e7f9f2b57aeeb10b006efa8ebd0f3e9c0b829958f6`.

Echte positive Prüfungen: beide ursprünglichen 180s-Imports/Art-/Sourcechecks PASS; After SurfacePopulationBudget inklusive additiver Cases 3,174s PASS, RuntimeGeometryBatch 2,121s PASS, CreatureBodyContract 10,044s PASS, vollständiger Original-Livinglauf mit echter 120s-Deadline 91,251s PASS. Beide Original-AB-Runner PASS (Before87,705s / After87,762s). Keine bestehenden Assertions oder Produktgrenzen wurden abgeschwächt.

`controlled_comparison_allowed=true`, `blockers=[]`: gleiche Originalreplay/Route, 2 Zyklen×8s, Seed15838, Headless/1920×1080, 60fps-Cap, 60 Settleframes, 120s-Stagelimit und je Zyklus 12 reale Tiere+12 Pflanzen auf beiden Seiten. Unverändert bleiben 2ms/4096 Skinunits, 250ms-Due-Tick, zwei Spawnversuche, eine physische Publikation pro Update und LRU8. Der Hostabschnitt endete nach303,593s mit Exit0, SourceStamp unverändert, Foreign in sämtlichen Snapshots=false, tatsächlicher Namespacebindung aller Engineprozesse, Kernel-Godot≠Z leer und beiden Locks nonblocking frei.

| Bewegung über alle vier Etappen | Before | After |
|---|---:|---:|
| Frames | 1577 | 1627 |
| p50 ms | 16.649 | 16.604 |
| p95 ms | 25.495 | 23.244 |
| p99 ms | 90.365 | 73.875 |
| Max ms | 193.455 | 148.441 |
| >33ms | 53 | 48 |
| >50ms | 37 | 41 |
| >100ms | 10 | 4 |
| Prozess-RSS Peak Bytes | 537288704 | 536326144 |

| Zyklus/Etappe | p95 Before→After ms | p99 Before→After ms | Max Before→After ms | >33/>50/>100 Before→After |
|---|---:|---:|---:|---|
| 0 / walk_outward | 78.14→58.885 | 144.882→87.169 | 193.455→102.308 | 39/28/6→27/26/1 |
| 0 / walk_return | 21.875→22.669 | 25.986→50.731 | 27.903→130.196 | 0/0/0→6/5/1 |
| 1 / walk_outward | 27.249→23.244 | 109.968→66.328 | 148.904→148.441 | 13/9/4→15/10/2 |
| 1 / walk_return | 19.39→21.407 | 25.495→29.612 | 39.915→32.096 | 1/0/0→0/0/0 |

Die konkrete Ablehnung folgt aus dem Kaltreturn: Max27,903→130,196ms, p9925,986→50,731ms und 0/0/0→6/5/1Spitzen. Fünf Tiere werden erstmals im Rückweg physisch; Before keines. Ab erster beobachteter Tierrecord-Erfassung steigt kalte Erstpublikation864,920→1.778,996ms und die vollständige Zwölferpopulation6.707,844→12.424,650ms; im Reload Erstpublikation453,297→459,323ms und vollständige Zwölferpopulation5.947,096→6.747,564ms. Diese Publikationswerte sind beobachtete Obergrenzen, keine exakten Storagewritezeiten. Kalte SkinCPU321,253ms monolithisch vs463,243ms bounded; Reload232,677 vs230,692ms. Bounded Maxslice kalt4,838ms / Reload2,752ms. Der bessere aggregierte p95-Wert genügt deshalb nicht für die allgemeine Akzeptanz.

Die 130,196ms-Spitze betrifft `object_fe9495decf5a74da236ef71e7d929344`: bereits fertiger SkinCache HIT0,016ms; darin verschachtelt PreviewBodyParts58,271ms, BodyStats85,417ms, ActorReady85,966ms. Kein SkinPrepareChunk liegt in diesem Frame. Beobachtete Intervallunion90,913ms, unzugeordnet39,283ms. Die verspätete erstmalige Parts-/Statskonstruktion liegt im Rückweg. Kein Verlust von Layout-/Partswärme und keine Cachepolicykorrektur sind belegt.

Die historischen Quellen und Rohbelege bleiben erhalten: 6ac/5ac (`current-ab.json`), 16d9/3d90 (`final-ab.json`) und der opt-in Tracef677. Dessen exakt erhaltene negative Bindung ist Commit `f67728df126f6a7208de8fabaac2a97e3caf0cfb`, Tree `a8575fa65b9c4850cf58f544e2716d2acc3d4764`, Source SHA `e5f979fb2dd5f31bce4ce52454d3ab6b7cd2d5ebb099bb7958251d6f0e6479e3`, identisches Start/End-Manifest `099be3a4c1ef660baaec24f883339a450034951f53c2c663d35c01d6b64ddd08`; Index SHA `7a73ed6efe0bc785e5179efb11e992e2b5731cf09aff21073c52e45aa60269cf`; 177 bytegleiche Importdeskriptor-Touches ohne erlaubten Vorbereitungsabschnitt ergeben weiterhin `changed_or_unavailable`, `reusable=false`, externen Exit3. Daraus wird keine erfolgreiche Abnahme abgeleitet. Der ältere Before6ac bleibt dagegen korrekt `prepared`/reusable=true durch seinen tatsächlich erlaubten Importvorbereitungsabschnitt; er wird nicht als `stable` umetikettiert.

Vollständiger Abschlussbeleg: `REPORT.md`, `source-bindings.json`, `ui-matched-ab.json`, `ui-matched-ab-supplement.json`, beide vollständigen SourceRun-Manifestsätze, Originalcaptures/frames/logs und `ui-matched-measurement-end.json`. Historische Nachweise werden nicht überschrieben. Das ist eine Headless-CPU-/Wallframeprüfung; GPU-/Forward+- und Ziel-PC-Abnahme werden nicht behauptet.

Der optionale Stage3-Locals-Patch auf exakter Basis `3d90eaa26979fabbe94e10052b69f867007394ac` ist ausdrücklich **UNMEASURED / NOT ADOPTED**: nur statisch gelesen, nie angewendet/importiert/ausgeführt. Kein spekulativer Speedup. Eine allgemeine Produktverbesserung bleibt eine künftige Aufgabe mit den unveränderten Kaltreturn-/Readiness-/Vollpopulationkriterien; dieser gestartete Diagnoseversuch ist beendet.
