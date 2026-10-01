# Nachweis für den veröffentlichten Stand 74bb

Dieses Paket ist auf Head `74bbcbcf9854cd35eb0c816f95a65ad17d2e2dfe`, Tree `a1a53c20730b1000e703ff1add4dd854fcdb069a` und den tatsächlichen CI-Merge `2937ac77970da0d9bf3622e83fd4b4894a53949f` festgelegt. Der vollständige Quellenhash ist `c06aed81737a973930f8969b922ac183585dc25dad3ff2dfc8e46f09f0c36ae5`.

- **Native Review:** acht Feature-Jobs plus Building, Gallery und Audio: **11 erfolgreiche Jobs, 202 PNGs**. Die acht Features enthalten 138 PNGs; Building 7, Gallery 45 und Audio 12. Building besteht 569 GUI- und zwei Neustartprüfungen. Sein kompletter Hashsatz entspricht allen **5.400** Dateien des gemeinsamen Quellenmanifests; keine versteckten Quellpatches. Ursprüngliche Budgets bleiben erhalten.
- **Runtime:** tatsächlich **27/27** Prüfungen bestanden; alle 26 hinterlegten Loghashes sowie vollständige identische Start-/Endmanifeste sind enthalten.
- **Environment:** tatsächlich **8/8** Capture-Jobs und der Render-Gate grün. Hier wurden GitHub-Job-/Artefaktmetadaten geprüft; diese Renderarchive und Screenshots wurden für dieses Paket nicht heruntergeladen oder visuell beurteilt.
- **Sourceplan:** **266** eindeutige registrierte/geplante Tests, aufgeteilt in **67/67/66/66**. Dies ist eine Planprüfung und keine Behauptung, dass FULL oder alle 266 Tests abgeschlossen sind. Ursprüngliche Fehlerbefunde und der unvollständige FULL-Status werden nicht ersetzt.

Der visuelle Umfang ist enger als die technische Prüfung aller Bilddateien: Root hat die Originalaufnahmen Stammeshilfe `layout-de-800-150.png`, `10-reserved-site-materials-de.png` und Gebäudevorlage `residence-editor-edited-reload-de.png` angesehen. Stammeskarte und echte Reservierungsdaten sind lesbar; 800×600 bei 150 % verwendet eine Scrollfläche. Das Gebäudevorlagenpanel ist deutsch, während der bestehende Editor weiterhin englische Texte enthält; vollständige deutsche UI-Lokalisierung bleibt offen. Daraus wird weder eine gemeinsame Abnahme einer fertig gebauten Hütte noch eine Abnahme auf dem Ziel-PC abgeleitet. Es wird nicht behauptet, dass alle 202 Bilder visuell geprüft wurden.

`evidence.json` enthält die kompakten Fakten, Run-/Job-/Artefakt-IDs und SHA256 des Roharchivs. `latest-74bb/all-native-verification.json` ist die unveränderte ursprüngliche native Prüfsumme/Ergebnisübersicht. `raw-results.tar.gz` enthält exakte rohe JSON-, JSONL- und Logbytes nach SHA256 dedupliziert, den Index ihrer ursprünglichen relativen Pfade sowie SHA256 und Dimensionen jedes der 202 geprüften PNGs. **Keine PNG-Dateien sind enthalten.** Originale Bilder bleiben in den GitHub-Artefakten; deren ZIP-SHA256 stehen in der nativen Übersicht und in den API-Metadaten.

Offline prüfen, ohne Godot, Netzwerk oder zusätzliche Python-Pakete:

```sh
python3 verify.py
```

Der Prüfer validiert Archiv-/Objekthashes, tatsächliche Jobabschlüsse, Manifestintegrität und den aus allen 5.400 Einträgen neu berechneten Quellenhash, Rohresultate und die genannten Zahlen. Er prüft den aufbewahrten PNG-Hash-/Dimensionsindex; eine erneute Prüfung der Bildbytes erfordert die originalen GitHub-Artefakte. Native Runs: [Features](https://github.com/MajorDragonfly/voxelverse/actions/runs/36824683109), [Building](https://github.com/MajorDragonfly/voxelverse/actions/runs/36824683292), [Gallery](https://github.com/MajorDragonfly/voxelverse/actions/runs/36824683276), [Audio](https://github.com/MajorDragonfly/voxelverse/actions/runs/36824683164). Ergänzende Runs: [Godot Runtime/Sourceplan](https://github.com/MajorDragonfly/voxelverse/actions/runs/36824683190), [Environment](https://github.com/MajorDragonfly/voxelverse/actions/runs/36824683225).
