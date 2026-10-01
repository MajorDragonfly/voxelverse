# INT30-06 / V30-06 · Stammesbedienung

Beim Weltklick auf eine Rohstoffquelle bzw. Baustelle wurde der Detailtitel nach dem Aufklappen/Tabwechsel außerhalb des Scrollfensters positioniert. `ensure_control_visible()` allein erreichte den verschachtelten Tab-Inhalt nicht. Das Panel wartet jetzt die Containeranordnung ab und korrigiert den tatsächlich dargestellten Abstand. Bewohner, Materialstände und Aktionen bleiben im gemeinsamen Panel/Controller-Vertrag.

Die Produktänderung betrifft ausschließlich `ui/tribe/tribe_panel.gd`. Der vorhandene `tests/tribal_age_test.gd` erhält einen ergänzenden Maus-/Renderablauf; seine normale Prüfkette und bestehenden Zeitbudgets bleiben erhalten. Die deutsche Ausgangssprache der alten caption-basierten Assertions wird ausdrücklich gesetzt (bereits separat vom Integrationschat geliefert).

## Gemeinsame Basis und Anschlüsse

Basis: `2b1ac023db4074c2ce6b7db8fbab09ab929a8435`, Tree `5f815f478ceeabefcfc50a6388e3e4b0daa2ac45` (#220). Eigener Branch: `agent/int30-06-tribe-controls`. Die Funktionalität wird auf dieser festen Basis gemeinsam geprüft; die späteren wörtlichen Köpfe aller gestapelten PRs werden damit nicht als integriert behauptet.

| Anschluss | Geprüftes Verhalten |
| --- | --- |
| #188 | Kompaktes Panel, obere Vorräte, scrollbare Dorfaktionen |
| #213 | Welt-/Listenauswahl, Name, Beruf, Auftrag, Nahrung/Wasser, Mehrfachauswahl |
| #214 | Baustellenklick, Bau-Tab, echte offene/unterwegs/reservierte Materialien, keine Mutation beim Lesen |
| #215 | Pause/Fortsetzen und Mauswahl von 1×/2×/3× |
| #218 | Kanonische Quelle, Rest-/Lagerbestand, Sammler +/−, laufende Fracht erhalten |
| #220 | Ressourcenleiste weicht der Bauplatzwahl; Aktionen im Scrollfenster erreichbar |

Controller, Sprachkatalog, zentrale Registry, Projektkonfiguration, CI und zentrale Statusdaten wurden nicht verändert. Gemeinsame Erweiterungen von Nachbar-/Tierhaltungs-/Weltchats sind über den Integrationsbesitzer anzuschließen.

## Exakt geprüfte Quelle

Finaler lokaler Codecommit: `6c57d5ded52d850ef637fac28b52e2e344680e62`; veröffentlichter identischer Code-Tree: Commit `e087cc3ecb12f14c06d9e4d44adb6bfcc6c5e90b`, Tree `49c6f6c01d427f3133a4c6c87c66d4d60e0bccce`. Der spätere Nachweiscommit fügt nur dieses Evidenzverzeichnis hinzu.

Produktpanel-Blob: `b279b460385d9756567ef026d74e34a87221ec65`; finaler Test-Blob: `4379e152f18fa3b17748fd412b419e7c73173dc4`. Alle Läufe besitzen Quell-/Tree-/Log-Belege. Anfang und Ende der finalen Quellprüfungen waren sauber und identisch.

Godot `4.6.3.stable.official.7d41c59c4`, Linux, isolierte Nutzerdaten. Native Bilder: Xvfb, Mesa 25.2.8 llvmpipe, `gl_compatibility`, Dummy-Audio, ein Software-Renderthread. Import wurde auf demselben unveränderten Ressourcenstand bereits erfolgreich durchgeführt und anschließend wiederverwendet.

| Prüfung | Quelle | Ergebnis / Sekunden |
| --- | --- | --- |
| 18 native Maus-/Layoutfälle plus echte Transporte | Finaler Code-Tree `49c6f6c…` | **Grün, 138,978 s**, 112 Originalbilder |
| `tribal_age_test` | Finaler Code-Tree `49c6f6c…` | **Grün, 82,408 s** |
| `tribal_age_supply_test` | Finaler Code-Tree `49c6f6c…` | **Grün, 38,264 s** |
| Quellverträge / Quellenintegrität | Finaler Code-Tree `49c6f6c…` | **Grün, unverändert** |
| `tribal_building_preview_test` | Vorgänger `ecd472a…`, Tree `786bf240…` | Grün, 24,866 s |
| `tribal_building_preview_world_test` (reguläre Kugelkampagne) | Vorgänger `ecd472a…` | Grün headless, 93,986 s |
| `tribe_localization_test` | Vorgänger `ecd472a…` | Grün, 59,759 s |
| `tribal_age_economy_test` | Vorgänger `ecd472a…` | Grün, 215,947 s |
| `domestication_campaign_test` | Vorgänger `ecd472a…` | Grün, 42,341 s |
| `pause_menu_test` | Vorgänger `ecd472a…` | Grün, 97,178 s |
| Kugel-Bauvorschau als native Einzelaufnahme | Vorgänger `ecd472a…` + dokumentierter Snapshot-Probe | Grün, 65,459 s |

Die sechs Verbraucherläufe und der Kugel-Snapshot sind datierte Teilbelege des Vorgängers, keine neu behauptete Gesamtprüfung des finalen Trees. Die einzige Änderung danach sind fünf Zeilen Warte-/Fehlerbehandlung im ergänzenden Transport-Fixture; siehe `transport-fixture-followup.diff`. Produktpanel und normale Testpfade bleiben identisch. Finaler Stammesablauf, Versorgung und kompletter Maus-/Transporttest liefen anschließend erneut.

Der konservative Änderungsplan wählt 168/247 Tests; dieser Plan wurde **nicht** als vollständige Ausführung behandelt. Gesamtintegration, native Exporte und Ziel-PC-Abnahme gehören weiterhin zu Chat 1.

## Maus- und Layoutnachweis

| Fenster | 100 % | 125 % | 150 % |
| --- | --- | --- | --- |
| 800×600 | DE + EN grün | DE + EN grün | DE + EN grün |
| 1280×720 | DE + EN grün | DE + EN grün | DE + EN grün |
| 1920×1080 | DE + EN grün | DE + EN grün | DE + EN grün |

Jeder Fall benutzt echte `InputEventMouseButton`-/Motion-Ereignisse über das Root-Viewport: Popup öffnen und Tempo anklicken, Pause, Bewohner anklicken/Details lesen, Shift-Mehrfachauswahl, Quelle anklicken, Sammler zuweisen/abziehen, Mausrad verschieben, Rechtsklick im HUD blockieren, Bauplatz setzen, Baustelle öffnen und Material lesen, Abbruch behalten bzw. bestätigen. Die Viewport- und Fontskalierung entspricht der tatsächlichen UI-Einstellung. Die rechte/scrollende HUD-Eingabe verändert weder Weltaufträge noch Auswahl oder Kamerazoom.

Der Layoutteil benutzt das vorhandene flache Kollisions-Fixture. Zwischen Fällen werden Bewohnerzustände zurückgesetzt und die echten Wege über den synchronen Diagnoseadapter vorbereitet; die Bewohnerphysik ruht während statischer Layout-/Platzierungsfälle. Pausenprüfungen laufen mit aktiver Physik. Für den Transportfall wird auf den **produktiven** Wegeumbau gewartet: reale Frachtaufnahme, unveränderte Fracht/Arbeitsreferenzen bei +/−, acht unveränderte Pausenframes und tatsächliche Lieferung nach Fortsetzen. Nur während der gezielten +/−-Kontrolle wird bestehende Fracht kurz festgehalten. Es wird keine Fracht erfunden.

Bei `--capture-on-demand` laufen Input, Layout und Physik weiter; gerendert werden die Vergleichsaufnahmen. Das ist ein Software-Diagnosemodus und keine kontinuierliche Grafik-/FPS-Abnahme. Der Kugel-Snapshot erweitert den vorhandenen regulären Kugeltest außerhalb der Registry: Rendering ruht bis zur fertigen Vorschau; dessen vorhandene Setup-Limits bleiben gleich. Der Probe-Hash steht im Renderbericht, der Probe selbst im vollständigen Nachweispaket.

Reproduktion mit dem vorhandenen Test (Chat 1 kann diesen CLI-Lauf als zusätzliche Bildabnahme anschließen):

```sh
godot --path . --rendering-method gl_compatibility --audio-driver Dummy   --script res://tests/tribal_age_test.gd --   --controls-only --capture OUTPUT --capture-on-demand
python3 tools/validate_godot.py --tests tribal_age_test tribal_age_supply_test --skip-import --skip-main
```

## Bildauswahl

Vor dem Fix lag der Quelltitel bei y=−49 außerhalb des Scrollfensters y=245…461. Der historische Vorherlauf besitzt einen modifizierten Test auf der Basis, aber das ursprüngliche Produktpanel (`bfd0ffd241eb30ce5ff62d294188dbc1bfeb1d2c`). Weitere Fehler dieses frühen Layout-/Material-Fixtures werden ausdrücklich **nicht** als Produktfehler ausgegeben.

| Beleg | Bild |
| --- | --- |
| Quellklick vor dem Fix | [Vorher](scroll-before-800-de.png) |
| Quellklick nach dem Fix | [Nachher](scroll-after-800-de.png) |
| Materialstand bei 800×600 / 150 % / EN | [Baustelle](construction-800-150-en.png) |
| Bedürfnisse und ehrliche Ausrüstungsgrenze bei 720p / 125 % / EN | [Bewohner](resident-720-125-en.png) |
| Quelle und Zuweisung bei 1080p / 150 % / EN | [Quelle](source-1080-150-en.png) |
| Baustelle bei 1080p / 150 % / EN | [Baustelle](construction-1080-150-en.png) |
| Reale Fracht angehalten / ausgeliefert | [Pause](freight-paused.png), [Fortsetzen](freight-resumed.png) |
| Freier Baugeist auf regulärer Kugeloberfläche | [Kugel](placement-sphere.png) |

Vollständige Fallliste: `controls-matrix.json`. Die beigefügten Render- und Headlessberichte nennen Befehle, Quellen, Dauer und Log-Hashes. Das zusätzliche ZIP enthält alle 112 finalen Matrix-/Transportbilder, den Kugel-Snapshot, Rohlogs, vollständige Quellenmanifeste und die dokumentierten Diagnoseversuche.

## Fehlerhistorie und offene Übergabe

- Ein früher kontinuierlicher Matrixlauf wurde nach 1200 s unter hoher gemeinsamer Last beendet. Die vollständige Wiederholung mit Aufnahmen bei Bedarf besteht; keine bestehenden Spiel-/Registry-Budgets erhöht.
- Der erste vollständige Zusatzlauf bestand alle 18 Layouts, sein Transport-Fixture gab den Sammelklick jedoch vor abgeschlossenem Wegeumbau ab. Das wurde durch Warten auf die produktive Wegefreigabe behoben; der vollständige finale Lauf besteht einschließlich echter Fracht.
- Stammesablauf und Versorgung hatten zuvor Zeitabbrüche. Beide bestehen abschließend ohne eigenen parallelen Renderlauf innerhalb ihrer unveränderten 120-s-Grenzen. Die Abbruchlogs bleiben erhalten.
- **Offen:** Der kontinuierlich gerenderte reguläre Kugel-Kaltstart erreichte im Softwarelauf die Stammesbestätigung innerhalb des vorhandenen 90-s-Setup-Limits nicht (`Sphere tribal setup did not complete`). Der Headless- und Einzelaufnahmeerfolg ersetzen diesen Befund nicht. Gemeldet an Chat 1/Kaltstart-/Weltbesitzer in #137.
- **Offen:** Englische Paneltexte bestehen; Weltlabels (`Dorfplatz`, `Leseholz`, `Lose Steine`, `Essbare Wurzeln`) und Kartenbereichstitel bleiben teilweise deutsch. Konkreter Beleg und Anschluss an Welt-/Sprachbesitzer sind in #137 gemeldet. Keine vollständige Sprachfreigabe der Welt.
- **Offene Folgearbeit #206:** Persönliche Werkzeuge, Kleidung und Ausrüstung fehlen im Modell. Das Bewohnerblatt zeigt den Dorfwerkzeugbestand und die fehlende persönliche Ausrüstung ausdrücklich.
- **Offene Folgearbeit #208:** Frei gezeichnete Sammelgebiete und persistente Grenzen fehlen. Geprüft sind vorhandene Vorkommen und platzierbare Arbeitsplätze.
- Kein Merge nach `main`, kein Auto-Merge und kein Schließen der Quell-PRs/Issues. Kein Windows-/Ziel-PC-, Langzeit-, FPS- oder Spielspaßnachweis. Die vollständigen Pflichtgates des neuen gemeinsamen Integrations-Trees bleiben bei Chat 1.
