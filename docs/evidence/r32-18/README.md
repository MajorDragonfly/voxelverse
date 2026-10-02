# R32-18 / #205 — regulärer Regensturm

Fachlieferung vom 02.10.2026, Branch `agent/r32-18-regular-storm`,
Draft-PR [#263](https://github.com/MajorDragonfly/voxelverse/pull/263).
Feste Basis `2a738a4891a8de11d682c469833ade4dc9b01dfb`,
Basistree `f2bda4f815df1c73b9d740ca5282917523faf618`.
Aktuelle Zuweisung aus #137: normale Wettermodelle/Forecast und eigene Helfer.
Atmosphärenkomposition bleibt R32-06, HUD-Host R32-14, gemeinsame
Save-/Katalog-/Plananschlüsse R32-01. #205 bleibt bis zur gemeinsamen Abnahme offen.

## Verhalten und Grenzen

Die bisher integrierte Tages-/Forecastleiste erhält jetzt eine echte, schadensfreie
Regensturmfront aus `Regional.sample()`. Die Warnung beschreibt ein bevorstehendes
normales Ereignis am aktuellen Ort. Sie erscheint während eines zusammenhängenden
180-Sekunden-Vorlaufs und verschwindet beim Eintritt. Normale Schauer und Diagnose
erzeugen keine reguläre Sturmwarnung; während einer akzeptierten Vorschau liefert
der Kampagnenbesitzer keine normale Forecastanzeige. Nicht akzeptierte Vorschauen
ändern die normale Quelle nicht.

| Phase | Kampagnendauer |
|---|---:|
| Ruhe | 1800–2160 s, aus Körper-ID und Seed |
| Vorlauf | 180 s |
| Anstieg | 45 s |
| Höhepunkt | 90 s |
| Abklingen | 60 s |

Ereignis-ID und Phase werden ausschließlich aus gespeicherter Kampagnenzeit,
Körper-ID und Seed abgeleitet. Es gibt keinen Ereigniswriter, SaveParticipant,
zweiten Clock, Echtzeitdatum oder Offlinefortschritt. Wiederbesuch rekonstruiert
den Zustand zur gemeinsamen Kampagnenzeit. Eine fehlende oder ungültige
Klimareferenz ist keine Freigabe: körpergebundene Referenz und ein explizites
boolesches `home_protected` sind nötig.

Nur ungeschützte `earth_temperate`-Körper mit Atmosphäre und örtlich warmen,
feuchten Bedingungen werden zugelassen. Heimat, historische Schutzreferenzen,
Vakuum, fremde/zukünftige Referenzen, trockene und kalte Regionen sowie alle
anderen Basis-/Extremprofile bleiben ausgeschlossen. `arid_extreme`,
`volcanic_extreme` und `frozen_extreme` bleiben im Modell nicht implementiert.
Sand, Asche, Feuer und Blizzard werden nicht als normale Stürme aktiviert.
`hazard_kind = none`, `hazard_intensity = 0` bleiben erhalten.

Das Sturmfeld hat kompakte, weiche körperfeste Regionen: 6,4-km-Zellen,
1,6-km-Kern und 2,8-km-Rand. Cube-Nähte, Pole, Kamerahöhe und Floating Origin
verschieben das Feld nicht. Regen ist auf 0,90 begrenzt, Wind bleibt unter
9,4 m/s, der Sichtweitenwunsch mindestens 6 km. Die zusätzliche Winddrift ist
analytisch integriert und periodisch begrenzt, auch nach 200000 Zyklen und beim
Überqueren einer Region. Der bestehende 384-Instanzen-Pool und Renderingbesitzer
bleiben erhalten. Die Sturmquelle komponiert kein Environment und löst keine
Schäden, Produktions- oder Ressourcenereignisse aus.

Neue additive Lesefelder: `normal_storm_schema = 1`, `storm_event_id`,
`storm_kind = rainstorm`, `storm_phase`, `storm_intensity`,
`storm_region_strength`, `storm_phase_remaining`, `storm_start_in_seconds`,
`storm_warning`. Die drei bestehenden Forecastfenster transportieren Schema,
Ereignis-ID, Art, Phase, Intensität und Eintrittsrestzeit. Ihre Werte entsprechen
exakt der normalen Quelle für +60/+120/+180 Sekunden am gegenwärtigen Ort.
Die normale Sekundentaktung bleibt erhalten; Phasenwechsel und Clock-Rücksprung
erzwingen eine unmittelbare Aktualisierung.

## Fachprüfung

Godot `4.6.3.stable.official.7d41c59c4`, Linux x86_64, isolierte Nutzerdaten.
Alle Godot-Prozesse dieses abschließenden Fachlaufs liefen unter dem gemeinsamen
R32-Hostmutex. Befehl:

```sh
flock -w 60 /tmp/voxelverse-r32-db514e109ac6-heavy.lock \
  python3 tools/validate_godot.py --godot /path/to/godot \
  --contracts weather --skip-main --output /path/to/weather-locked
```

6/6 Wettertests bestanden: `planet_climate_test`, `regional_weather_test`,
`weather_forecast_ui_test`, `weather_model_test`, `weather_runtime_test` und
`weather_storm_test`. Import, SourceContracts und ArtSources ebenfalls bestanden.
Die Registrierung bleibt bei 267 Tests / 18 Verträgen. Die neuen 1927 Fälle
werden vom bereits registrierten `weather_storm_test` gestartet; ein zweiter
Registereintrag ist nicht nötig.

Die neuen Fälle prüfen alle Phasen, genaue Zukunftswerte, einmalige DE/EN-Warnung,
keine Null-Minuten-Warnung, gewöhnlichen Regen/Diagnose, die Schutz-/Profilgates,
räumliche Grenzen, Cube-Nähte, Höhe, Drift und Langzeit-Wrap. Tatsächliche
SaveGameService-Checkpoints im Vorlauf und Höhepunkt werden in zwei frischen
Godot-Prozessen geladen und mit dem JSON-kanonisierten erwarteten Sample exakt
verglichen. Geschwindigkeit null stoppt den Clock; Geschwindigkeit eins folgt
ihm. Der bestehende `weather_runtime_test` prüft zusätzlich echte Kampagnenszene,
Pause, Laden und A–B–A-Reise. Keine künstlichen gefährlichen Profile werden zur
positiven Bannerprüfung benutzt.

Originale: `weather-contract-originals.tar.gz`, lesbarer Ergebnisbericht
`weather-contract-results.json`, SHA-Zuordnung `tested-source-map.json`.
Der Fachlauf entstand auf der noch uncommitteten festen Basis; die einzige
Importvorbereitung war der neue UID des eigenen Prüfhelfers. Provenienzstatus
`prepared`, `reusable = true`; alle Laufzeitmodule und Fachtests sind gegenüber
dem finalen Code bytegleich. Danach wurden ausschließlich die eigenen nativen
Prüfhelfer korrigiert/erweitert. Das ist kein nachträglich behaupteter sauberer
Gesamttree-Test. Die Originalmanifeste und tatsächlichen Dateihashes bleiben erhalten.

`git diff --check` und Python-Kompilierung des Helfers bestanden.
Der konservative Änderungsplan wählt wegen eigener neuer Helfer und geänderter
Testdatei FULL 267/267. Das war nur ein Plan. Volle Suite, vier Pflichtgates,
gemeinsame Produktions-/Reisekette und Exporte gehören laut R32-Zuweisung auf
den Integrationstree; diese Fachlieferung beansprucht dafür keine Freigabe.

## Sichtbarer Ablauf

**GL bestanden:** 129 native Zeitrafferbilder, 135 protokollierte Wetterproben,
8 zusätzliche native Kontrollbilder, keine Fehler und unveränderte Quelle.
`gl/review.json`, `gl/runner.json`, Originalmanifeste/Logs in
`gl/native-original-reports.tar.gz`; Originalbildhashes in
`gl/original-frame-sha256.json`. [Video](gl/regular-storm.mp4),
[Vorwarnung](gl/frame-0060.png), [Sturm](gl/frame-0080.png),
[wieder ruhig](gl/frame-0128.png). Ein Warnbeginn in der Sequenz;
60 Warn-, 15 Anstiegs-, 30 Peak- und 20 Abklingbilder, zusätzlich 4 ruhige Bilder.
Clock 6910–7294 s; Vorwarnung 6915–7095, Eintritt 7095, Ende 7290 s.
Am tatsächlichen Ort erreicht der Peak ~0,911 regionale Intensität, ~0,820 Regen
und 315 sichtbare Regeninstanzen. Die Prüfung verlangt exakt den Regionalwert
und die volle örtliche Peakstärke; eine maximale Kernintensität wird nicht
pauschal für jeden Ort vorausgesetzt. Nach erneutem Laden sind Clock 7170 s,
Ereignis-ID und Peakphase erhalten. Tatsächlicher Renderer: GL Compatibility /
llvmpipe (LLVM 20.1.2), Xvfb TCP, 960×540, Dummy-Audio.

**Forward+ lokal nicht bestanden:** Vulkan `VK_KHR_surface` fehlt; die Engine
fiel auf GL zurück. Zwar bestanden dort die fachlichen Capturefälle, der Runner
weist den Gesamtlauf wegen Enginefehlern ausdrücklich als `passed = false` aus.
`native-forward-fallback-negative-originals.tar.gz` ist kein Forward+-Nachweis.
Die früheren separaten GitHub-Software-Rendering-Läufe erreichten die unveränderte
300-s-Grenze (teilweise bis 129 Bilder bzw. Kontrollbilder, kein Endnachweis).
Originale Logs/Artefakt-IDs/Digests in `ci-negative-originals.tar.gz`;
[letzter optionaler CI-Lauf](https://github.com/MajorDragonfly/voxelverse/actions/runs/36978167267)
ist jetzt abgeschlossen: GL **success**, Forward+ **failure** durch 300-s-Timeout.
Der GL-CI-Runner bestätigt `passed = true`, 129 Bilder, 135 Proben und
`source_observation = unchanged` auf dem sauberen Quellcommit
`63f93bbec9eb7898274a8ca7c01d530e6a2a8fb6` / Tree
`281accb511ed907af3beb7ad3fcd6740a40d303a`. Kein Godot-Fehler; SourceRun vollständig,
`reusable = true`, SHA256 `8024edaa859b594fd9d0630bff4540394ebbcdd653b49374d0aaa5ba46dd6891`.
[Sauberer CI-Zeitraffer](ci-final/regular-storm.mp4),
[CI-Peakbild](ci-final/storm-peak.png). Originale GL-/negative Forward+-Artefakt-ZIPs,
Joblogs, IDs, Digests und Provenienz liegen unter `ci-final/`. Die beiden Original-
Framehälften des GL-Jobs sind im verlinkten Lauf separat hinterlegt (A 64 / B 65
Bilder; Aufbewahrung bis 16.10.2026). Die heruntergeladenen ZIP-Digests entsprechen
exakt den GitHub-Artefakt-Digests aus `ci-final/metadata.json`.
Forward+ erhielt 129 Sequenzbilder und fünf Kontrollbilder, aber keinen vollständigen
End-/Reloadnachweis; der Job bleibt fehlgeschlagen. Kein Erhöhen der Deadline
oder GL-Rückfall als Ersatz. Ein vollständiger echter Forward+-Endnachweis bleibt
bis zu einem geeigneten Prüfrechner und erfolgreichem Lauf offen.

Auch `native-negative-regional-peak-originals.tar.gz` bleibt erhalten: der ältere
Helfer verlangte fälschlich >0,85 Regen an diesem räumlich skalierten Ort.
Der finale Helfer prüft stattdessen zusätzlichen exakten Niederschlags- und
Condition-Abgleich mit der autoritativen Quelle, volle örtliche Peakstärke und
wirklich eingereichte Regeninstanzen. Er verändert weder Quelle noch Budget,
Qualität, 90-s-Szenenladeguard oder 300-s-Laufgrenze.

Die native Aufnahme verwendet die tatsächliche SessionFlow-Kugelkampagne,
ein natürlich gewähltes ungeschütztes gemäßigtes Ziel in einem anderen System,
Seed 15838 und einen regulären warmen, feuchten, sicheren Landeort.
Heimatschutz oder Klima werden dafür nicht umgeschrieben. GL und Forward+
verwenden dieselbe `reference-save.json`. Aufeinanderfolgende Bilder lesen die
autoritative normale Wetterquelle bei festem Kamerapunkt: 3 Kampagnensekunden
je Bild, 10 Wiedergabebilder/s. Das ist ein stummer Zeitraffer, kein Echtzeit-
oder FPS-Nachweis. Der Helfer prüft tatsächliche Regeninstanzen im Höhepunkt,
unveränderten Partikelpool, normales Regenwetter, separate Diagnose, Pause/
Resume, DE/EN und gespeicherten Clock/Ereignis/Phase nach tatsächlichem Titel-
und Szenenneustart. Die vollständige Sequenz endet im ruhigen Zustand bei
Intensität null und ohne Banner.

Negative Originale bleiben getrennt: lokaler Lauf 08 wurde versehentlich vor
Abschluss unterbrochen (92 Teilbilder, kein Endnachweis). Lauf 09 hat 125 Bilder
und vollständigen Fehlerbericht: der Prüfhelfer erwartete nach Diagnose/Regen
den älteren Peak-Clock, obwohl der vorhandene Titelanschluss korrekt den aktuellen
Clock autospeicherte. Korrektur ausschließlich im Helfer: Peak vor Titelrückkehr
wiederherstellen und speichern; nach Laden zuerst den tatsächlich geladenen
Clock prüfen, dann diesen aufnehmen. Kein Savefehler wird damit überdeckt.
Die 60-Sekunden-Mutexsperren starteten keinen Godot-Prozess. Frühere Zwischenläufe
sind keine positiven Nachweise für den abschließenden Stand.

## Owneranschlüsse und offene Voraussetzungen

Alle drei Patches unter `owner-patches/` sind vorgelegt und mit
`git apply --check` geprüft; die gemeinsam besessenen Zieldateien wurden auf
diesem Fachbranch nicht verändert.

- R32-01: `weather-plan-owner.patch` ergänzt die normale Regenfront und
  Lesefelder in WEATHER_PLAN. `localization-owner.patch` ergänzt genau den
  Katalogschlüssel `WEATHER_FORECAST_RAINSTORM` (DE Regensturm / EN Rainstorm).
  Kataloge mit dem bestehenden Generator regenerieren. Bis zur Übernahme nutzt
  die Leiste den vorhandenen übersetzten Regenbegriff; kein roher Schlüssel.
  Kein SaveParticipant-/Registrypatch erforderlich.
- R32-01: `weather-evidence-workflow-owner.patch` zeigt den optionalen nativen
  Prüfworkflow. Tatsächliche Ausführung liegt nur auf dem separaten Diagnosebranch
  `agent/r32-18-evidence-20261002`, außerhalb des Feature-PR und ohne zusätzlichen
  Integrations-PR. Er ist keine neue Pflichtprüfung.
- R32-06 / R32-14: bestehende Snapshotwerte und Forecastoberfläche lesen;
  Atmosphärenkomposition und HUD-Host bleiben in ihren Zuständigkeiten. Für den
  geänderten Integrationstree die gemeinsame Darstellung/Layout erneut abnehmen.
- Reguläre gefährliche Extremstürme bleiben offen: passender Terrain-/Biosphären-
  und Vakuumhimmelstand, gemeinsamer Expositions-/Schutz-/Schadensvertrag für
  Kreaturen/Bewohner/Gebäude/Ausrüstung, Deckung/Arbeit/Transport/Rückkehr,
  Farbe/Partikel/Audio und genau-einmalige Save-/Reisefälle sind Voraussetzung.
- Wetteraudio, gemeinsame Qualitätsregler, Windows-Spieltest, Ziel-PC-Balancing
  und 1080p60 bleiben offen. Software-Rendering und Fachtestlaufzeiten sind keine
  Ziel-PC-Leistungsmessung. #205s vollständige UI-/Layout-Abnahme auf 720p/1080p
  mit Skalierung gehört zur Integration mit R32-14.

## Quellstände

| Zweck | Lokaler Commit | Veröffentlichter Commit | Tree |
|---|---|---|---|
| Runtime/Fachtests nach 6/6-Lauf | `7f20017fde49cad50fdd95c9f83df4c41a6ec8d6` | `4a70a9ae191cbbcfaab4be6653c83121a2b9a7cb` | `404893c94f49fc5cca0712e20fb435b529643f53` |
| Finaler nativer Prüfhelfer / GL-Lauf | `00f53a70d17e387c5a08720a5272acc90c0a181c` | `63f93bbec9eb7898274a8ca7c01d530e6a2a8fb6` | `281accb511ed907af3beb7ad3fcd6740a40d303a` |

Der abschließende Belegcommit und dessen Tree stehen in der PR-Übergabe.
Native lokale SourceRun-Manifeste enthalten auch die schon vorhandenen eigenen,
noch uncommitteten Belegdateien. Während des jeweiligen Laufs blieben alle
beobachteten Bytes unverändert; `reusable = true`. Sie werden nicht als ein
cleaner Test eines späteren Integrationstrees ausgegeben.

Der GitHub-Connector erzeugt andere Commitmetadaten als der lokale Commit;
die korrespondierenden Trees sind jeweils identisch. Belege nennen den tatsächlich
geprüften Quellstand. Nachfolgende reine Belegdateien ändern weder Runtime noch
Fachtests oder Prüfhelfer und begründen keine Wiederholung dieser Läufe.
