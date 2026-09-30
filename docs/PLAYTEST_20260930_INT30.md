# Windows-Spieltest INT30 · 30.09.2026

**Kandidat: [PR #221](https://github.com/MajorDragonfly/voxelverse/pull/221). Build-Bezeichnung: `INT30-20260930-WINDOWS-RC1`.**
Dieser erste Kandidat enthält die feste #220-Basis und das neue Dashboard #219. Die Folgelieferungen der neun zugewiesenen Fachchats sind noch nicht Bestandteil dieser Build-Bezeichnung.

## Identität und Download

- Gemeinsame unveränderliche Fachbasis: `2b1ac023db4074c2ce6b7db8fbab09ab929a8435`, Tree `5f815f478ceeabefcfc50a6388e3e4b0daa2ac45`.
- Gemeinsamer Produkt-/Dashboard-Quellstand: `e217ba6fadc29722d37b9be0691981ccac03b4c1`, Tree `4967ca14be41cd886c6d936b1087ebfe5fd37dc3`.
- Windows-Fixture-Korrektur: `6880ab345bc777c4e081a0e14968928c3eeb512c`. Die deutsche Testfixture startet ausdrücklich in DE; ihre DE/EN-Layoutmatrix und sämtliche echten Maus-/Bauprüfungen bleiben erhalten. [Ursache und Gegenprobe](evidence/integration-20260930/windows-locale-diagnosis.json). Die endgültige Build-Identität folgt nach neuen FULL-Gates.
- Messskript-/Prüfquelle: `8cb128c9e570dcd62845e1ee0d3a52315aed1da0`; die Vergleichsszene wird nach Abschluss aller Messungen entladen. [GL-Shutdown-Diagnose](evidence/integration-20260930/surface-teardown-diagnosis.json). Beide Renderer und native Exporte werden auf dem endgültigen Tree neu geprüft.
- Aktuellen Prüfkopf, Windows-Run, Artefakt-ID und SHA256 dokumentiert die Übergabe in #221/#137. Solange der native Windows-Export nicht erfolgreich ist, gibt es keine freigegebene Build-Datei.
- Nach erfolgreichem **Desktop export gate**: in der zu diesem Prüfkopf gehörenden Actions-Ausführung das Windows-Artefakt herunterladen. Ältere #199-/#165-Downloads enthalten die PT18-Folgearbeiten nicht vollständig.
- Das äußere Artefaktarchiv und danach `voxelverse-windows-x86_64.zip` entpacken. `voxelverse.exe` zusammen mit PCK und Begleitdateien im selben Ordner starten.
- `SHA256SUMS.txt` prüfen; `BUILD_INFO.json` im Spielordner enthält den tatsächlich geprüften Quellcommit/Tree, Engine und Plattform. Der CI-Merge-Commit darf vom PR-Kopf abweichen; sein Tree muss dem abgenommenen gemeinsamen Tree entsprechen.
- Zur Ablage den Download als `INT30-20260930-WINDOWS-RC1-<voller-gepruefter-Commit>.zip` benennen. Build-ID, Commit, Tree, Run und SHA256 zusammen aufbewahren. Keine manuelle Änderung von EXE/PCK oder geprüften Paketdateien.

Godot 4.6.3; Referenz-PC Ryzen 7 9800X3D, RTX 4070 Ti, 32 GB / 5200 MT/s. Grafikpreset, Renderer, Auflösung, Treiber und Save/Seed mit jedem Leistungsbericht nennen. Vorläufiges Ziel 1080p/60 FPS; keine automatische Ziel-PC-Freigabe.

## Konkrete Sicht- und Spieltestfälle

| Fall | Vergleich / Handlung | Benötigter Nachweis |
|---|---|---|
| Stufenkamera #171 | Dieselbe Treppe mit identischer Route vor/nach Änderung; kleine und große Kreatur, mehrere tatsächliche Bildraten. Sprung, Fallen, Teleport und Recovery zusätzlich prüfen. | Bewegte Vorher/Nachher-Aufnahmen mit Quellstand, Körpergröße und Bildrate; Kollision und Stufenhöhe unverändert. |
| Scanner #172/#173 | Ein Tier am Kreisrand bei Kamerabewegung, zwei konkurrierende Ziele, Nest, verdecktes Ziel, Zielwechsel und Pause. | Bewegte Rand-/Mehrfachzielaufnahme; Marker folgt tatsächlichem sichtbarem Ziel, kein Scan durch Hindernisse, Fortschritt bleibt dem richtigen Tier/Nest zugeordnet. |
| Trinkhinweis | Vom Wasser weg und auf trockenem Boden nach unten blicken; danach an einem erreichbaren Ufer trinken. | Auf trockenem Boden kein Wasser-/Trinkangebot; korrekt erreichbares Wasser erlaubt tatsächliche Aktion. |
| Materialien / Fernsicht | Holz, Laub und Stein bei Sonne/Schatten, Tag/Nacht, nah/fern und Hin-/Rückweg ansehen. | Gemeinsamer Licht-/Materialvergleich, keine Lücken oder sprunghaften Farbwechsel; GPU-Kosten gesondert messen. |
| Nester / Performance #167 | Identische neue und geladene Route; Tiere, Beeren und Nester beobachten; anschließend mindestens zehn Minuten laufen. | Zeitreihe einschließlich p95/p99 und langen Frames; sichtbare Population und Bewohnerbudgets, Pause, Laden/Neustart. Headless-Zeiten ersetzen keine Ziel-PC-FPS. |
| Stammesbedienung / PT18 | Bei 800×600 und 720p mit 150 % Skalierung Bewohner, Bauplatz und Arbeitsplatz anklicken; Tabs/Buttons scrollen, +/− Zuweisung, Pause/Tempo und Bauplatzwahl bedienen. | Tatsächliche Welt-/Mausklicks erreichen das Ziel; Ressourcenleiste verdeckt keinen Bauklick; DE/EN und Fokus prüfen. |
| Gemeinsame Dorfansicht | Eine fertige Hütte mit Dorfplatz und wirklichen Vorräten gemeinsam zeigen; Kamera bewegen, nah/fern wechseln und speichern/neustarten. | **Eine gemeinsame Aufnahme** mit fertiger Hütte, Platz und Vorräten; Lager/Gebäude am Boden, Beschriftungen passend; Zustände nach Neustart erhalten. |
| Wetter / Wasser | Tageslauf, angekündigte Wetterphase, Wasserströmung/Ufer, Unterwasser, Pause und Rückkehr ansehen. | Gemeinsame Wetter-/Materialansicht, Anzeige folgt tatsächlichem Modell; Strömung/Pause und Ufer unverfälscht. |
| Menü / Audio / Buch | Esc → Einstellungen → Audio, jede Hörprobe, stumm/reset, zurück; Entwicklungsbuch in beiden Phasen und DE/EN öffnen. | Erreichbare Bedienelemente, richtiger Fokus/Pausezustand, keine Überlagerungen; Einstellungen nach Neustart erhalten. |

## Abnahme und PR-Bereinigung

Vollständige aktuelle Gates sind Godot validation gate, Desktop export gate, Environment render gate und Project dashboard gate. Fach-/Grafikläufe und aufgelöste Reviewthreads kommen hinzu. Ein grüner Entwurfsplan oder einzelne Fachtests ersetzen diese Gates nicht. Die Jobdetails müssen tatsächliche native Windows-/Linux-Exporte und beide Renderläufe zeigen; `Desktop draft plan` oder `Render draft plan` mit übersprungenen Export-/Capture-Jobs zählen ausdrücklich nicht. Beim Wechsel zur technischen Review muss der CI-Ereignisstand den PR als bereit erkennen.

Die ausdrücklichen Sichtabnahme-Sperren aus #199/#220 gelten weiter. Dieser Windows-Kandidat macht ihre Prüfung möglich; er bestätigt sie nicht. Ziel-PC-Leistung und persönliche Produktabnahme bleiben getrennte Nachweise. #171, #172, #167 und die übrigen offenen Produktissues werden nicht durch Erzeugen des Builds geschlossen.

Quell-PRs erst nach erlaubter, geprüfter Übernahme nach main und unmittelbar erneut geprüftem unverändertem Kopf schließen. Die [datierte Eingangsliste](evidence/integration-20260930/inputs.json) unterscheidet Abstammung, unveränderten Merge-Tree und konfliktbedingt offenen Abgleich; sie ist keine Live-Zuständigkeitsliste. Fachbranches und ursprüngliche Übergaben bleiben erhalten.
