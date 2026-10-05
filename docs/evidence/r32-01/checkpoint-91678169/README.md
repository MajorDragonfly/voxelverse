# R32-01: unveränderlicher Integrationscheckpoint

**Kein R32-Finalstand, kein freigegebener Windowsbuild, kein main-Merge.**
Aktuelle Besitzer- und Lieferbelegung ausschließlich in [#137](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-5946206999), Integration in [Draft #249](https://github.com/MajorDragonfly/voxelverse/pull/249).

Dieser Nachweis beschreibt Quellcommit `916781695650756438ae4b86a0ae179237c1273f`, Tree `adf10119f542006f0276c021b0404fdc3c982d50`, feste Fachbasis `2a738a4891a8de11d682c469833ade4dc9b01dfb`. Er ist ein historischer Prüfcheckpoint und keine zweite Live-Statusquelle.

## Serielle Fachaufnahme und gemeinsame Anschlüsse

19 tatsächliche Lieferköpfe wurden als echte Mergeparents aufgenommen: #262, #269, #260, #270, #252, #254, #256, #261, #264, #266, #255, #267, #253, #250, #257, #263, #258, #251, #268. Der Quellkopf/Tree jedes Inputs, dessen Dateiliste, Besitzerpatch-Anhänge und tatsächlicher Integrationsmerge stehen im gespeicherten `inputs.json`-Datensatz. #265 bleibt ausgeschlossen; sein ursprünglicher Kopf `1d872b9e000b76fa3c03aa403956de4905b5afd3` besitzt einen dokumentierten Scanner-Performanceblocker. Nur eine neue geprüfte Veröffentlichung kommt als Lieferung infrage.

Controller-/Save-/Clock-, Styles/Buch-, HUD-Unterpanel-, Wind/Wasser/Dorf- und Katalogports wurden aus den veröffentlichten Besitzeranhängen integriert. 46 DE/EN-Ergänzungen ergeben 2642 Katalogmeldungen. Registry: 286 Quelltests in 18 Verträgen, neue Tests jeweils einmal; zusätzliche Python-Fachprüfungen einmal im bestehenden Tooling-Lauf. ExpressionDriver gehört R32-10, Körperpose R32-12.

Die fünf geschützten Weltkarten-Produktdateien sind bytegleich zur Fachbasis. #189 (`ed68295fce162e2495920edd61afcf38717bf5e0`) und #246 (`d5610eaafe43eb6246fc2a99676d064ba035bc78`) bleiben offen und unverändert. #259 (`56235292896c123d0030cab3c89ab635d03eedb1`) ist ausschließlich Diagnose und kein Featureinput.

## Tatsächliche gemeinsame Prüfungen

| Nachweis | Tatsächliche Quelle / Ergebnis | Grenze |
|---|---|---|
| [Vollsuite 37273366027](https://github.com/MajorDragonfly/voxelverse/actions/runs/37273366027) | Gemeinsamer Tree `dfd76367b0fbbef4b1c8ba6c08b066bda4313fd0`; 286 disjunkte Quelltests: 280 grün, 6 rot | Kein Gesamtgate bestanden |
| Derselbe CI-Runtimejob | 27 Checks grün, SourceRun wiederverwendbar | Kein Ersatz für Exporte oder native Fachansichten |
| Source-Shard 3 desselben Runs | Vollständig grün, SourceRun wiederverwendbar | Nur dieser disjunkte Shard |
| Lokaler Clock-Anschluss auf Tree `07cc200c5b197dd91d6dba5ed7814164f5ac4c5a` | Holz, Stein, Tool und Hütten passieren nach dem Engine-Restorefix; ursprünglicher Test bleibt wegen New-campaign-Readiness rot | Exakte tatsächliche Quelle und Logs im `clock-reload-and-hud`-Datensatz; keine Gesamtfreigabe |
| 58 bestehende Tooling-Tests | Vertrags-/Provenienz-/Planprüfungen grün auf lokalem `4617494b…`, Tree `adf10119…` | Python-Tooling, kein Gameplay-/Exportnachweis |
| [Folge-CI 37281326821](https://github.com/MajorDragonfly/voxelverse/actions/runs/37281326821) | Checkpoint `91678169` veröffentlicht; Prüfungen zum Schreibzeitpunkt laufen | Ergebnisse nicht vorweggenommen |

Die sechs roten Quellfälle des ersten gemeinsamen Trees sind `r32_14_hud_world_test`, `r32_21_resource_area_world_test`, `r32_15_campaign_menu_test`, `tribal_age_test`, `tribal_progression_world_test`, `hud_layout_test`. Originale inklusive SourceRun-Manifeste sind erhalten. Die 11 beim Import erzeugten UIDs wurden anschließend versioniert.

Enge Folgekorrekturen des Checkpoints: Tempoauswahl löscht auch den alten Engine-Wiederherstellungsfaktor, damit Reload ihn nicht erneut multipliziert; HomeGroup reagiert nach Welt-/Save-/Phasenwechsel im nächsten Frame. Eigene gemeinsame Source-Verbraucher deklarieren die 1280×720-Startfixture bereits vor dem öffentlichen Einstieg. Der erste Fachdialog stand vorher headless in einem tatsächlichen 64×64-Fenster; der Abbrechen-Knopf lag außerhalb des Fensters. Fachassertionen und echte Maus-/Weltklicks bleiben unverändert. Die gelieferten äußeren Reviewfristen 900 s (R32-14) und 720 s (R32-15) sind im gemeinsamen Runner zugeordnet; innere Load-/Input-/Saveguards bleiben erhalten. Diese Folgekorrekturen benötigen ihre aktuelle Gameplay-Prüfung.

## Negative native Wetterproben

Godot `4.6.3.stable.official.7d41c59c4`, Host `9583cdd44932`, tatsächliche native X11-Aufnahmen, isolierte Nutzerdaten und serialisierter lokaler flock. Kein Ziel-PC-Nachweis.

Die unveränderte originale R32-18-Probe mit nur deaktivierter Spielerphysik erreicht auf `a2e5ac82…` 60/129 Sequenzbilder: SpringArm/Kamera-Basis driftet über die unveränderte Kameraassertion; der öffentliche Reload wird tatsächlich erreicht. Dies ist ein negativer Originalbefund.

Die eigene gemeinsame Probe friert den Beobachter-Unterbaum und setzt einmal pro geladenem Save dieselbe aus Seed, Körper/Spawn, Heading, Pitch und Arm abgeleitete Vergleichskamera. Ursprüngliche Wetter-, Kamera-, Pause-, Budget- und öffentliche Reloadassertionen bleiben geerbt und unverändert.

| Renderer auf sauberem Tree `136a869c6ee71b2419cde534eae2afb40782aff4` | Ergebnis bei weiterhin 300 s |
|---|---|
| Compatibility, Mesa llvmpipe, `LP_NUM_THREADS=2` | 129/129 Sequenzbilder, 136/137 Gesamtbilder; letztes öffentliches Reloadbild/Abschluss fehlt, Exit 124 |
| Tatsächliches Vulkan 1.4.318 Forward+, llvmpipe LLVM 20.1.2, `LP_NUM_THREADS=2` | 103/129 Sequenzbilder, Exit 124; kein GL-Fallback |

**Beide sind negativ.** Teilbilder, stabile SourceRun-Manifeste und erfolgreich gestartetes Vulkan ersetzen keinen vollständigen Ablauf. Die gemeinsame Probe allein belegt auch keine Wetter-/Minimap-Freiheit: der Minimap-Verbraucher blendet bei deaktivierter Spielerphysik außerhalb der Stammesphase aus. Lifecycle-/Teilzeilen-/isolierte Save-Diagnose ist vorbereitet; sie wurde zu diesem Checkpoint noch nicht ausgeführt. Paket-/GPU-/FPS-Freigabe daraus nicht ableiten.

## Offene Anschlüsse und Finalkriterien

R32-05 führt den Scannervergleich unter exklusivem Hostslot fort. R32-01 hat seinen Slot freigegeben; ein geplanter lokaler Folgelauf wurde durch den Lock verhindert und hat keinen Godot-Prozess gestartet. Gemeinsame Source-CI läuft auf getrennten Runnern; keine identische lokale Vollsuite.

Explizite Forecast-/Minimap-/HUD-Reserveports wurden bei R32-18/04/14 angefordert. `hud_layout_test` belegt Entry-/Minimap-Überlagerung. Kleine Fenster benötigen einen abgestimmten Höhen-/Ausweichdockvertrag. Bestehende Nichtüberlappungs-, Metrik-, echte Weltklick-/Scroll- und 70%-1080p-Kriterien bleiben erhalten. Vollständige gemeinsame Forward+-End-/Pause-/Reloadproben sind noch offen.

Finalfreigabe erst mit vollständig geprüftem Scannerkopf, gemeinsamen Anschlüssen und finalem Tree: volle Quellsuite, Produktions-/Reisekette, native Windows/Linux und alle vier tatsächlichen Pflichtgates. Draftpläne sind keine Code-Abnahme. Keine Fachissues geschlossen, kein Auto-Merge. Lars' Ziel-PC-, Sicht-, Hör- und Spielkomfortabnahmen bleiben getrennt offen. Der datierte zentrale Repo-Status wird einmal nach abschließender technischer Abnahme aktualisiert.

## Originaldaten lesen

`index.json` ordnet jedes ursprüngliche Resultat, Log und vollständige SourceRun-Manifest einem SHA256-geprüften, verlustfrei gzip-komprimierten Objekt zu. Identische Inhalte werden einmal gespeichert. Das Original ergibt sich durch gzip-Dekompression; Länge und SHA256 sind im Index angegeben. `ci-first-candidate.json` nennt originale CI-/Artefakt-IDs und tatsächliche Quellidentitäten; `inputs.json` hält die immutable Lieferaufnahme fest. Alle dekomprimierten Längen und Hashes wurden gegen den Index geprüft. Negative Ergebnisse werden nicht durch neue Darstellungen überschrieben.
