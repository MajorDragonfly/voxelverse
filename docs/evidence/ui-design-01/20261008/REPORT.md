UI-DESIGN-01 · geprüfte Fortsetzung vom 08.10.2026

Die konkreten Symbol-, Audio-/Modal- und Layoutregressionen sind behoben. Expedition, die bestehende Branchlinie und die fachlichen Daten-/Save-/Aktionsverträge bleiben erhalten. Draft #281 bleibt offen; gemeinsame Integration und Gesamtgates führt R33-01.

Geprüfter und veröffentlichter Head: `2ec14bbd2e1dbc01e7f50f5e9b41c8cae35c8132`, Tree `12716e8ab3da73320ee183b3f32863ef6d1db056`, Branch `agent/ui-design-language-20261007`. Elternlinie über f504d085 → 8c33bb5e → cb298dd5 → ursprünglichen UI-Head7555b145; feste Basis94de70ca bleibt erhalten. Keine Fachbranches verschoben.

Godot `4.6.3.stable.official.7d41c59c4`; SourceRun jeweils sauber, vollständig und stable/reusable=true. Identische Start-/Endquelle `0bdab23c0f407fb867acf6bdc490f7d315b0346168cb207a1753fde220cfaa90` mit 9310 Dateien/751456247 Bytes. Zwei Heavy-Locks und Fremdprozessprüfung während des gesamten eigenen Laufs; kein Source-Edit während Ausführung. Native X11/GL-Compatibility unter Xvfb, Mesa llvmpipe; Maus-/Tastaturereignisse laufen durch die tatsächlichen Controls. Originalfristen und sämtliche bisherigen Assertions bleiben erhalten. Ergänzt sind72 Heading-Kriterien und2 Browser-Heading-Kriterien; keine neue Testregistrierung.

Originalnegative und konkrete Korrektur

| Originalnachweis | Befund | Korrektur / Abnahme |
|---|---|---|
| [Godot37613919638](https://github.com/MajorDragonfly/voxelverse/actions/runs/37613919638), Sourcejobs112779905704/731/739/950 | `.text` auf TextureRect nach Symbolumstellung; Nil-HUD-Titelfelder im Minimalfixture | Explizites `JournalHeading`-Label und direkte Label-Verbraucher; StateSigns-Minimalfixture legt tatsächliche neue Label/Icon-Controls an. Register, StateSigns, AnimalFoley und direkte Journalverbraucher positiv. |
| [Frontend37613919807](https://github.com/MajorDragonfly/voxelverse/actions/runs/37613919807), Job112767578146 | `Category click failed: 4`, anschließend Nil-`_sliders`, Audio-/Fokus-/Modal-/Phasen-/Weltklickkaskade | Tatsächliche18px-Tabtexturen,6px-Tababstände und viewportbegrenzte Seitenminimums. Bestehende Esc-/Kampagnen-/Audio-Inputasserts bleiben unangetastet und bestehen. |
| Godot-Journal, 800×600/150%, DE/EN | Liste unter60px, Filter-/Detailplatz unbrauchbar | Kompakte eigene Panel-/Headingabstände, skalierte Fonts, Filterfluss statt überbreitem HBox. Alle72 Layouts positiv; 18 vollständige native Bilder. |
| `interface_task7` im Originaljob | Tatsächlicher `ToggleAnimalSuitability` außerhalb/verdeckter Klickbereich: z.B.786/790 bei1280×720,510.5/626 bei800×600,431/791 bei640×480; zusätzlich Tab5überlauf640×480 | Tierrollen-Toggle vor Vorschau/optionalen Beschreibungen; vorhandene kompakte Tabwahl erhalten. Originale echte Klickkriterien bestehen an allen3 Größen. |
| Entwicklungsbuch1280/1920 bei150% | Tatsächlicher Stammesübergang nach optionalen Meilensteinen unter Scrollanfang | Eigene Kapitelabstände kleiner; Übergang unmittelbar hinter Kapitelüberschrift. Original1149 Headlesskriterien und native1513 bestehen; Lock-/Zustands-/Meilenstein-/Eingabekriterien erhalten. |
| [INT3037613919863](https://github.com/MajorDragonfly/voxelverse/actions/runs/37613919863), Werft960×640 | Bottomstatus/Actions außerhalb; Seitenleisten verdrängen Arbeitsraum | Lokale Buttonabstände und kleine Seitenleisten; fachliche Editorrollen/Aktionen unverändert. Originalrollen/Neustart/echte Inputs positiv. |
| INT30 Medieval, 800×600/150% (logischer Viewport533×400) | Aktionen und nützlicher Detail-Scrollraum fehlen | Lokale kompakte Button-/Panelabstände; Footerwarnungen im eigenen Detail-Scroll. Original>=60px-Kriterium sowie tatsächliche Wheel/Tab/Enter/Esc-Eingaben positiv. |

Zusätzliche Sichtbefunde wurden trotz grüner Formularprüfung korrigiert: erster EN-Owned-Filterheader lag aufcb298dd5 bei y=-16/137px Höhe. Responsive Titel bekommen ihre eigenen Fontgrößen, kurze Journalüberschrift bleibt einzeilig; bei Platzmangel wird der Header gestapelt. Theme-/Fontinvalidierung wird nur bei tatsächlicher Änderung ausgelöst. Vollständige DE/EN-Filter- und Tabbilder am Endhead geprüft.

Beim Buch passten die Kontrollrechtecke, einzelne erste Bilder nach erneut eingeschaltetem Renderloop enthielten aber alte Text-Zeichenbefehle. Der bestehende Bildverbraucher wartet nun nach Wiedereinschalten zwei vollständige frame_post_draw statt einem; Inputs, Kontrollasserts, Fristen und Simulationsgeschwindigkeit bleiben erhalten. Vollständige Bilder zeigen jetzt auch DE-Nestgruppe/DE-Weltraum/EN-Neuzeit korrekt. Die negativen Originalbilder bleiben in den vorherigen Belegstufen erhalten.

Geprüfte Endquelle

| Probe | Ergebnis | Vollständige native DE/EN-Bilder |
|---|---|---|
| 21 gezielte Regressionen/direkte Verbraucher + Source contracts | PASS | [Originalberichte, alle Logs und komplette Start-/Endmanifeste](checked-2ec14bbd/focused-21-checks.zip) |
| Journal | PASS, 1885 native Kriterien / 72 Layouts | 18; [DE](checked-2ec14bbd/journal-de-complete.zip), [EN](checked-2ec14bbd/journal-en-complete.zip) |
| Eigene Tiere | PASS, tatsächliche Dropdowns, D2-Transaktionen und separater Kaltstart | 27; [DE](checked-2ec14bbd/owned-de-complete.zip), [EN](checked-2ec14bbd/owned-en-complete.zip) |
| Entwicklungsbuch | PASS, 1513 native Kriterien /108 Fälle | 182; alle6 Kapitel, DE/EN, 800/1280/1920,100/125/150%;18 vollständige Größensprachenarchive in [checked-2ec14bbd](checked-2ec14bbd) |

Alle227 PNGs sind vollständige Originalframes mit geprüften Abmessungen; kein Beschnitt und keine Bildnachbearbeitung. 150% wird wie im ursprünglichen Buchtest gezielt injiziert (Settings exponieren bis135%). Vollständige native Quellmanifeste, Kommandos, Logs und tatsächliche Befunde: [native-metadata.zip](checked-2ec14bbd/native-metadata.zip). Jedes Archiv und jeder enthaltene Frame besitzt SHA256 im [archive-index.json](archive-index.json); Gitblobs bei Upload lokal gegen Git-SHA geprüft.

| Test | Ergebnis | Laufzeit | Log SHA256 |
|---|---|---|---|
| `pause_menu_test` | PASS | 50.777 s | `86ec7e4add6bc8541877bd341066a878c9d981099a22f77e42007849c38f987a` |
| `r32_15_campaign_menu_test` | PASS | 121.715 s | `b05deebc7cbc0799a5fa11db395755253f32ebb7848bee364c5e234a22d6a13f` |
| `int30_menu_audio_book_test` | PASS | 75.531 s | `0d38380190e8f10a84168008e962d9900bff3ecae24f23ee5974e25b5ef66755` |
| `r32_13_book_test` | PASS | 18.722 s | `c763ff53db2d6e2d6f7d6967afe067d9bc54b78d49b5765ae10f5dfb5b26eb20` |
| `journal_localization_test` | PASS | 36.797 s | `ff30b25c29271738ad70a1dbfdca168b061b4289375a207e6385e1d2b18b2857` |
| `interface_task7_test` | PASS | 10.647 s | `428fbda96a741804137b39bba27206fd8b06ac39c2020081ab82cd50faf6b3f0` |
| `owned_animal_localization_test` | PASS | 7.439 s | `5bee99a16c32ccae63d5c87a9ef11f40eb0815ce65f8a43c10cbea49cc2f63e1` |
| `int30_medieval_technology_test` | PASS | 7.891 s | `6133dcc7d5dda40cfd5b2440529d739baa7256bf261c703153caf7f415aa3fe8` |
| `audio/animal_action_feedback_test` | PASS | 5.583 s | `7a330bbb5ccb59e0c9d7672c3a18848d6c15647c5f07d800e1a30ad85b0900bf` |
| `audio/audio_settings_test` | PASS | 18.721 s | `0fc91f2d06eb4bea6729896149066842455cf039a28362beadf0291392482812` |
| `audio/interface_audio_test` | PASS | 10.045 s | `e6829268809f2e875a844356361eead9c784d83deb0ea60ffd1c40b9b9ae9dd3` |
| `discovery_journal_test` | PASS | 7.238 s | `99f4ad3876ecaa8492ef1017c527640419bf34c1af98379b8328e2031d6e70f7` |
| `journal_paging_test` | PASS | 13.407 s | `733bb148b54fbf2378a0e22f1ba0326dde0e9ff1426aa4e8f15bc6a093f2d124` |
| `journal_preview_rotation_test` | PASS | 2.222 s | `95c57248150ffba4de784344c39d1d0fa0a84bad861409588df9cb6b840e4ec7` |
| `domestic_fauna_journal_test` | PASS | 11.054 s | `785e041e442b0fcebc821430c5e3205d034b58c344e390d9162d1d24d93ddd33` |
| `behavior_skill_tree_test` | PASS | 5.135 s | `4a97f623b2bcb4020549d06670d2a15fa9aaca89a486dcca03b64270bb74a6c9` |
| `development_path_test` | PASS | 6.537 s | `5c1f2a47e7e67a7deea0969e97208443b8ff1786af3c01835bbd6cad10bec263` |
| `skills_localization_test` | PASS | 25.100 s | `16d4fd168e07e801fe25d342c3f78a49a72ca674b7c2fad6f978cf98e5c2e1b8` |
| `shipyard_test` | PASS | 4.843 s | `567ae5d0d52864928f0614e7c1273bbdeb3a7d1e959d5ec78600172e6706f902` |
| `r32_10_state_signs_test` | PASS | 3.075 s | `7a887063d1f285b2055a5cad7f53e1beeb5e1569638211165c17635c60c5071e` |
| `r32_15_settings_navigation_test` | PASS | 3.982 s | `b84c69c533603369a5f3b356d9585b0e118da47d3d0092a82fb56b68e214dbf4` |

Quellverträge am eigenen Endhead:18 Verträge,287 genau einmal registrierte Tests,2642 DE/EN-Meldungen. Dies ist nicht die weiterentwickelte vollständige R33-Integration.

Historische CI-Folgebelege mit genauer Quellbindung

[Frontend37749284582](https://github.com/MajorDragonfly/voxelverse/actions/runs/37749284582), Job113218257460: PASS;224 vollständige PNGs,283 Pause-/913 kombinierte Audio-Buch-/617 Buchhostkriterien sowie reale Menü-/HUD-Eingaben. Alle242 Archivmitglieder bytegleich in12 kleineren Packs erhalten; ursprüngliche ZIP-SHA24227f9354ed6295248a8029a5219aa9b6edb53afffe5626c148102a2af5f048. [Logs/Manifeste und alle DE/EN-Bilder](corrected/frontend).

[INT3037749284466](https://github.com/MajorDragonfly/voxelverse/actions/runs/37749284466): Shipyard113218258011/art11538405885 PASS,18 Vollbilder+Inputs+Kaltstart; ZIP-SHA7e122c768889daca30eeed42f27e18e0c7cfbf57584eb91234397f4376ca5e20. Medieval113218258098/art11537304988 PASS,10 Vollbilder+Wheel/Tab/Enter/Esc; ZIP-SHA00e783a660f64d0c353a07e01a0e6a02337deffa0b1d56580f2a883e557501b9. Beide Original-ZIPs unverändert unter[corrected](corrected). Owned113218258117 technisch positiv, enthielt den zusätzlich erkannten EN-Headerfehler; seine27 Frames/Reports bleiben vollständig erhalten und gelten nicht als abschließende Sichtfreigabe.

Diese CI-Läufe prüften tatsächlich Mergeca6b526a0a4c2a764b5e3fc0dd75f6b9245588b5/Treee2a6f6c409eb47de66db4bc92529fd5860975b8b, Elternc3b2efc2 + cb298dd5. Die8 damaligen Korrekturdateien waren SHA256-identisch zum eigenen cb298dd5; vollständige Trees werden nicht gleichgesetzt. Zusätzlich sind die3 betroffenen Settings-/Werft-/Mittelalterdateien und4 gemeinsamen Stil-/Symbolquellen bytegleich zum Endhead2ec14bbd ([exakter Vergleich](ci-component-comparison.json)). Die finale eigene Kopfzeilen-/Capturekorrektur ist separat am Endhead geprüft. Vollständige kleine DE/EN-Vorschaubilder unter[previews](checked-2ec14bbd/previews); CI-Bilder sind dort ausdrücklich ci-ca6 genannt.

Godot37749284383 Source0 Job113221028877 ist weiterhin konkret negativ: Karte Legend/Places/Dropdown-Koordinaten, Fiberbed-Save, Guidance-Kontextkaskade und Missing resource storage area. Source1/2/3 wurden nach Folgecommit abgebrochen; kein Gesamtpass. [Vollständiges lossless Source0-Log](corrected/godot-37749284383-job113221028877.log.gz). INT30 TribalGuidance113218258168 ist ebenfalls negativ; komplette Originalmitglieder inklusive34 Frames erhalten. Ursache beginnt beim kanonischen Bau-/Savebudget, wodurch die echte Baustelle/Kontextkarte fehlt. R33-01s gemeinsame Admission-/LocalSources.initial-/Inputadapterkorrekturen und spätere Diagnosen bleiben bei[R33-01s Antwort](https://github.com/MajorDragonfly/voxelverse/pull/281#issuecomment-6056413277) und [#283](https://github.com/MajorDragonfly/voxelverse/pull/283); keine fremde Kontextkarte/Savefunktion hier überschrieben. Neuere aktuelle Gesamtgates sind gesondert abzunehmen.

Erste ausdrücklich negative Korrekturstufe54807151/Tree7b60038d plus vollständiger Binärdiff: [first-correction-negative.zip](local/first-correction-negative.zip). Zwischenstufe cb298dd5:21 Zielfälle positiv, nativer EN-Header noch negativ; kompletter Geometrie-/Bildbeleg in[local](local). f504d085:21 Zielfälle positiv,227 native Frames; einzelne Buchkopfzeilen vor zusätzlicher Render-Synchronisierung verschoben. Vollständige Zwischenbelege unter[final](final). Endhead2ec14bbd ersetzt diese Zwischenbefunde als geprüfter eigener Korrekturstand.

Fachbesitzer und serieller Anschluss

| Besitzer | Tatsächlich gelesener Fachkopf | Konkreter Austausch |
|---|---|---|
| Weltkarte #271 | a3cc0a85c5a39ca419a703005d2e372ea928f249 | [6055884760](https://github.com/MajorDragonfly/voxelverse/pull/271#issuecomment-6055884760) |
| Minimap/Kamera #277 |7587489e8b08f3e00d6d8f0cae6fe2618d29f309 | [6055885042](https://github.com/MajorDragonfly/voxelverse/pull/277#issuecomment-6055885042) |
| Ressourcen #280 |cc12aeba46169023dbdb370577b604372cc7318c | [6055885307](https://github.com/MajorDragonfly/voxelverse/pull/280#issuecomment-6055885307) |
| Ausrüstung #275 |ba1db78b2314b9ff0a1493c05daf142c1dd11d56 | [6055885498](https://github.com/MajorDragonfly/voxelverse/pull/275#issuecomment-6055885498) |
| Wetter #282 |fe736eec83e0ba562063ea86ec5c2345826da679 | [6055885723](https://github.com/MajorDragonfly/voxelverse/pull/282#issuecomment-6055885723) |

Die8 bestehenden unangewandten Gestaltungshunks wurden auf diesen tatsächlichen Kontexten gelesen;3 veraltete Stellen eng an neue Places/Equipment/Exposure angepasst. `git apply --check` auf allen8 aktuellen Dateien positiv; Patch-SHA2563e7bb3e8ef5a07aa9bdfc2daf787f9a57f5cd59ffd444de5d34f28e14029e9e2. [Patch](owner-design-proposals.patch), [exakte Head-/Blobkontexte](owner-contexts.json). Keine Engine-/Fachfreigabe dieser zusätzlichen Hunks behauptet; Besitzerantwort/kleine skalierte Fachbilder stehen aus. Nur jeweilige Besitzer übertragen ihre Funktionen und R33-01 führt bestätigte gemeinsame Hunks seriell zusammen. #189/#246/#259 und sämtliche fremden Panels erhalten.

Draft #281 und die vier vollständigen Integrationsgates bleiben R33-01 zugeordnet. Neue CI-Runs am Endhead: Godot37758443642, Frontend37758443947, INT3037758443708, Desktop37758443747 (Status gesondert im PR festgehalten, nicht aus Teilbelegen abgeleitet). Ziel-PC/FPS/Sicht/Hören/Spielkomfort sind keine Folgerung aus diesen Software-Renderer- und UI-Prüfungen.
