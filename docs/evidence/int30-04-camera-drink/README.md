# V30-04 / INT30-04: Kamera und Trinkkontext

Fachlieferung zu PT17-05 (#171 / PR #199), Stammeskamera (#179 / PR #189) und Trinkkontext (#211). AGENTS.md und die fixierte Vergabe in #137 sind Grundlage. PR [#223](https://github.com/MajorDragonfly/voxelverse/pull/223) richtet sich an `agent/integration-pt19-20260930`; keine main-/Auto-Merge-Freigabe.

## Basis und Umfang

Gemeinsame unveränderliche Basis: `2b1ac023db4074c2ce6b7db8fbab09ab929a8435`, Tree `5f815f478ceeabefcfc50a6388e3e4b0daa2ac45`. Lokaler finaler Codecommit `a8ea5bbb7347aa34fd443d7a01af2bdee6b19406`, veröffentlichter Codecommit `f53308b6a28116bdff4c35883b5a132bb0a15ac9`, identischer Tree `e6548c77d1a669265b7d63f33c31b407f16392db`. Die spätere Nachweislieferung verändert keine Produkt-/Prüfquelle. Einzeldatei-Digests: [source-sha256.json](source-sha256.json).

Produktänderungen ausschließlich in `creatures/player/player_controller.gd`, `player_controller_v2.gd` und `world/tribe/tribe_camera.gd`; Regression im bereits registrierten `tests/step_camera_test.gd`; eigene Capture-/Review-Helfer unter `tools/`. Scanner bleibt Chat 5; Stammespanel/Controller bleibt Chat 6. Gemeinsame Registry, Übersetzungen, CI, Projektkonfiguration und Statuskataloge unverändert.

## Vier belegte Korrekturen

1. **PT17-05 nach langen Renderframes:** Im unveränderten Welttest wurde bei geneigtem Up-Vektor ein Kamera-Zielsprung von 0,340 m gemessen (erlaubt <0,22 m). Unbegrenztes `delta` konnte den Schrittversatz in einem Frame fast vollständig löschen. Nur die Kamera-Nachführung begrenzt nun die verbrauchte Zeit pro Renderframe auf 1/30 s. Bei normalen 30/60/120-Hz-Takten bleibt die Exponentialkurve gleich. Der neue deterministische 250-ms-Gegenfall ergibt 0,150 m und verändert die Körperposition nicht; normale und geneigte physische Stufe bestehen, Recovery besteht.
2. **Neue Kamerahindernisse im Stillstand:** Der Pose-Cache übersprang neu gestreamte/errichtete Gebäudekollisionen. Gleiche Pose wird jetzt spätestens alle 0,2 s sowie bei geänderter Viewportgröße neu geprüft. Echter Box-Collider auf der Sichtlinie: vor Korrektur 0 m Reaktion / Fehler, danach 7,150 m Reaktion; Entfernen stellt die alte Lage wieder her. Niedrige Perspektive bleibt mit echter Bewohnerauswahl und Minimap-Mausklick bedienbar.
3. **Flacher Stammesblick:** Die hohe orthografische Bildfläche zwang die 3°-Kamera am Seeufer/Hang effektiv auf 21,62–30,71°. Unter 25° verwendet die Kamera nun eine zur Fokusgröße passende Perspektive; Übersicht bleibt orthografisch. 24 reale Terrain-/Wasseransichten (Ufer und Hang, vier Richtungen, 800×600/1280×720/1920×1080) zeigen 3,00–9,44°. Die Kollisionsanhebung an Hängen bleibt bewusst erhalten. Der finale geometrische Lauf prüft die tatsächliche Near-Plane über `project_position`, einschließlich voller unterer Ecken: Mindestfreiheit 1,975 m. Die originalen nativen Vorher-/Nachherbilder und finale Geometriedaten sind im Medienpaket.
4. **Trinkhinweis und Klick am Rand:** Ein physisch getroffener Seegrund lag 3,243 m entfernt, seine erreichbare Süßwasseroberfläche 3,086 m (Reichweite 3,2 m). HUD zeigte Trinken, Klick brach beim festen Boden ab. Beide Controller prüfen nun vor der festen Bodenentfernung dieselbe `reachable_drink_source` wie das HUD. Reproduzierte Aktion erhöht Durst von 20 auf 55. Trockener Boden, tatsächliches Meerwasser, entfernte Quelle und nicht veröffentlichter Boden werden verworfen. Nativer GL-HUD-Test prüft zusätzlich sichtbaren Hinweis am Süßwasser und dessen Verschwinden an trockenem Boden/Salzwasser.

## Vergleichbare Stufenvideos

Alle Seiten verwenden dieselbe physische Treppe aus drei vollen 0,5-m-Stufen, dieselbe Produktion-Spielerszene, Eingabe, Kollisionskapsel, SpringArm und Strecke. Links ist eine isolierte Kontrollaufnahme mit dem starren Pivot vor PT17-05 auf ansonsten gemeinsamer Quelle; rechts die kompensierte Produktionskamera. Das ist kein vollständiger historischer main-Build. Nach dem Anstieg folgen 1,5-m-Absturz, Landen, echter Sprung, eine explizit getrennte Rückplatzierung auf das Plateau und Abstieg. Körper, Kameraziel, tatsächliche Kamera, Bodenkontakt, Vertikalgeschwindigkeit und SpringArm-Länge sind je Frame protokolliert.

| Replay-Takt | Visuelle Größe | Anlauf | größter Zielsprung vorher → nachher | tatsächliche Kamera nachher |
| --- | --- | --- | --- | --- |
| 30 Hz | 0,65× | gerade | 0,580 → 0,150 m | 0,177 m |
| 30 Hz | 0,65× | schräg | 0,580 → 0,150 m | 0,177 m |
| 30 Hz | 1,50× | gerade | 0,580 → 0,150 m | 0,177 m |
| 30 Hz | 1,50× | schräg | 0,580 → 0,150 m | 0,177 m |
| 60 Hz | 0,65× | gerade | 0,580 → 0,081 m | 0,094 m |
| 120 Hz | 1,50× | schräg | 0,580 → 0,042 m | 0,056 m |

Die sechs Videopaare sind eine gezielte Abdeckung aller Faktoren, keine vollständige 12-Kombinationen-Matrix. Die beiden Größen skalieren das tatsächliche Runtime-Modell; die Kollisionskapsel bleibt identisch. Aufnahmen entstanden vor dem abschließenden Schutz gegen lange Renderframes; die Glättung bei diesen festen Takten bleibt mathematisch unverändert, der zusätzliche Stall wird separat am finalen Produkt geprüft. Die normale Laufsteuerung/Physik wurde für die Filme nicht verzögert.

`--fixed-fps` ist ein fester Replay-Takt. Die Softwareaufnahmen erreichten im Median etwa 5–13 gezeichnete Frames/s und wurden im Replay-Takt kodiert. Sie belegen keine echten 30/60/120 FPS auf dem Ziel-PC. Alle zwölf zu den sechs Paaren gehörenden Prozesse haben vollständige Trace-Daten und Erfolgsmarker. Ein zusätzliches isoliertes 60-Hz-Vorher ist Messdaten, kein siebtes Videopaar. Messwerte: [motion-measurements.json](motion-measurements.json).

## Konkrete Abnahmebewertung

| Kriterium | Bewertung und noch nötiger Nachweis |
| --- | --- |
| #171: kein abrupter Stufensprung im Vergleichsvideo | **Für kontrollierte Fälle belegt:** native Kameraspitzen 0,177/0,094/0,056 m statt ca. 0,60 m; Stall-Regressionsfall korrigiert. Subjektive Sicht-/Komfortabnahme bleibt beim Ziel-PC. |
| #171: Bodenkontakt, kein Durchdringen/Schweben | **Nicht vollständig abgenommen.** Bei jeder Stufe meldet die bestehende `Space.step`-Routine kurz `is_on_floor=false`: sie hebt zunächst um 0,58 m statt der 0,50-m-Stufe und landet rund 0,1 s später. Maximal etwa 8 cm Überhöhung, kein dauerhaftes Schweben. Diese gemeinsam genutzte Bewegungsroutine liegt außerhalb des fixierten Kamera-Schreibbereichs; konkreter Anschluss an Chat 1/Körper-/Bewegungsbesitzer. Originalframes sind Gegenbelege und werden nicht als durchgehend geerdet gewertet. |
| #171: Nachschwingen und Eingabe | **Begrenzte Fälle bestanden:** Versatz endet bei 0; keine dauerhafte Oszillation, unveränderte unmittelbare horizontale Physik. Fuß-/Animationskomfort und Körperformen weiterhin sichten. |
| #171: Sprung/Fall, Kamerakollision, Kugel-Up/Rebase | **Fachprüfungen bestanden:** echte Sprünge ca. 0,95 m; Fall/Abstieg landen; SpringArm verkürzt an echtem Collider; radiale Schrittprüfung und Stammes-Welttest mit Originwechsel/Reload bestehen. Weitere steile reale Hänge und andere Kollisionsprofile bleiben Ziel-PC-/Integrationsfälle. |
| #171: mehrere Bildraten und Kreaturenkörper | **Teilbeleg:** drei Replay-Takte, zwei visuelle Größen, zwei Anläufe. Echte unterschiedliche Render-FPS, weitere Blueprints/Körperformen und Kapseln sind offen. #171 nicht schließen. |
| #179: schnelle feste Kamerastrecke | **Simulationsvertrag belegt:** 64 m in 2,11 Kamera-Simulationssekunden, 32 m/s Standard; Shift-Schnellmodus im vorhandenen Test. Reale Ziel-PC-Zeit/FPS unter normaler Last offen. |
| #179: Augenhöhe/Ufer/Hang/Kollision | **Belegte Verbesserung:** reale 24 Ansichten und 24 finale Near-Plane-Kontrollen. Genau 3° ist an Hängen wegen Clearance nicht garantiert. Sichtprüfung des Linsenwechsels bei 25° und Ziel-PC-/Forward+-Ansicht offen. |
| #179: Q/E, alte Profile, Minimap | **Bestanden:** echte Q/E-Events, alte Pfeilprofile bekommen Q/E und behalten Pfeile; phasenspezifische E-Nutzung konfliktfrei. Blickkegel/Minimap-Klick, Buttons, Auswahl und 720p-Layout werden geprüft. Keine Scannerdatei geändert. |
| #179: Einstellungen/Reload/Arbeitsradius/Erkundung | **Bestanden:** Präferenztests und echter Weltsave/Reload; Fokus 0 m, gespeicherter Default 55°; 111-m-Pan erweitert weder Erkundung noch Arbeits-/Navigationsradius. 24 Collider, 573 Tiles, Peak 707 Meshes bleiben im vorhandenen Budget. |
| Trinken: trocken/Salzwasser/erreichbares Süßwasser | **Fachvertrag und natives HUD bestanden:** tatsächlicher V2-Sampler und Kampagnen-Wasserquelle, echter Spieler/Ray/Box-Collider. Nur Boden-Veröffentlichung ist ein Fixture. Der reale Kugel-Onboarding-Test scheitert auch im finalen Wiederholungsversuch vor dem Kugelstart; dieser Gesamtpfad bleibt offen. |

## Prüfbefehle und Nachweise

Godot `4.6.3.stable.official.7d41c59c4`; Linux, isolierte Nutzerdaten je Prozess. Registrierte Prüfungen verwenden unveränderte Timeouts/strikte Fehlererkennung. Native Belege: X11, Compatibility/OpenGL, Mesa llvmpipe, Dummy-Audio. Software-Renderer liefert keinen Windows-/Export-/Ziel-PC-Gate.

- `python3 tools/validate_godot.py --godot GODOT --tests step_camera_test radial_step_test player_recovery_test input_preferences_test tribal_camera_preferences_test tribal_camera_test minimap_test tribal_camera_world_test onboarding_guidance_world_test --skip-import --skip-main`: stabiler Quellstand `1dba530...`, sieben Einzelprüfungen bestanden; Kamera-Stall fehlgeschlagen und korrigiert; Onboarding scheiterte vor Kugelstart unter Last. Der Gesamtlauf bleibt `passed=false`.
- Finale Kamera-/Recovery-Prüfung auf `a0cb124...`: `--tests step_camera_test player_recovery_test`, beide bestanden, Source-SHA256 `506224e7dd6310ea4a376f25c595b0ac60948015f50332e96745015bd84fd30d`, Source-Integrity stabil. `a8ea5bb...` ändert danach ausschließlich eigene Review-/Capture-Helfer.
- `GODOT --headless --path . --script res://tools/review_int30_tribal_camera.gd`: bestehende echte Tribe-Fixture plus neue Hindernis-/Pointer-/Minimap-Fälle, bestanden.
- `GODOT --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://tools/review_int30_drink_contract.gd`: natives HUD und Quellen-/Aktionstest, bestanden in 17,319 s auf finalem Code.
- `GODOT --headless --path . --script res://tools/capture_int30_low_view.gd -- AUSGABE`: finaler tatsächlicher Near-Plane-Test, 24/24 bestanden in 7,684 s. Ohne Headless rendert derselbe Helfer die Bilder. Zwei finale native Wiederholungen erreichten unter Speicherlast keine Bilder bis 180 s und bleiben fehlgeschlagen; die bereits vollständigen originalen 24 Vorher-/24 Nachherbilder bleiben datierte Pixelbelege ihres Kamerastands.
- Video-Reproduktion: `python3 tools/review_int30_camera_motion.py --godot GODOT --output AUSGABE --case 30hz-0.65-straight --case 30hz-0.65-diagonal --case 30hz-1.5-straight --case 30hz-1.5-diagonal --case 60hz-0.65-straight --case 120hz-1.5-diagonal` in einem nativen Display. Render-Zeitfenster des eigenen Capture-Helfers ist getrennt von den unveränderten Produkt-/CI-Budgets.

Der finale unveränderte Onboarding-Wiederholungsversuch ist ebenfalls rot: `Sphere did not load` vor Gameplay nach 66,753 s, Source-Integrity stabil. Keine Trink-/Kameraaktion dieses Weltpfads wird daraus als geprüft abgeleitet. [Registrierte Ergebnisse](registered-checks.json) und [native HUD-Ergebnisse](drink-native-clean.json) sind im Fachbranch lesbar.

Die ersten Fehlbelege bleiben im Medienpaket. Ein früher Prüflauf hatte zusätzlich während des Laufs geänderte eigene Helfer und wird wegen `source_integrity=false` nicht wiederverwendet. Ein nativer Trinklauf mit automatischer ALSA-Wahl enthielt einen Audio-Initialisierungsfehler; er bleibt rot. Der anschließende identische Produkt-/HUD-Fall mit für diese Umgebung ausdrücklich gewähltem Dummy-Audio besteht ohne diesen Fehler. Keine Fehlerfilter oder Erwartungen wurden abgeschwächt.

## Übergabe an Integration

Chat 1 übernimmt die drei Produktdateien, bestehende Kamera-Regressionsprüfung und eigenen Helfer von #223, prüft den neuen Integrations-/Merge-Tree mit FULL und den vier Pflichtgates. Die eigene Codebasis wurde nicht auf fremde Fachköpfe umgehängt. Die kurze Verlustphase des Bodenkontakts ist als konkreter Gegenfall mit `Space.step`-Besitzer abzustimmen. Chat 5 hält Scannerzuständigkeit, Chat 6 das Stammespanel; niedriges Kamera-Picking/Minimap sind gegen den bestehenden Controller verifiziert.

Offen bleiben Ziel-PC-/Windows-/native Exportgates, vollständige echte Render-FPS-/Körpermatrix, Sichtkomfort, der Linsenübergang bei 25° und der kurzfristige Bodenkontakt. Kein Issue geschlossen, kein Akzeptanzhaken pauschal gesetzt, kein main-/Auto-Merge.

## Medienlieferung

Sechs MP4-Videopaare sowie `INT30-04-camera-drink-evidence.zip` sind als separate Dateien mit dieser Lieferung bereitgestellt. Das ZIP enthält alle sechs Filme, 48 native Ufer-/Hangbilder, einzelne Originalbilder und vollständige Traces/Prüflogs/Quellmanifeste samt Fehlbelegen. Dateinamen, Größen und SHA256: [media-sha256.json](media-sha256.json). Es wird kein voller grüner Testlauf aus Teilbelegen abgeleitet.
