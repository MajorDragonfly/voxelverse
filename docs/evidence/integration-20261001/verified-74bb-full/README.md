# FULL-CI-Nachweis für Voxelverse 74bb

Alle vier technischen Pflicht-Gates sind auf HEAD `74bbcbcf9854cd35eb0c816f95a65ad17d2e2dfe` abgeschlossen und erfolgreich. Dies ist ein unveränderlicher Nachweis für PR #245 und diese konkrete Quellbaumversion, keine Freigabe von `main` oder einer späteren Version.

| Pflicht-Gate | Run-ID | Job-ID | Ergebnis |
|---|---:|---:|---|
| Godot validation gate | 36824683190 | 110265402900 | success |
| Desktop export gate | 36824683231 | 110261263800 | success |
| Environment render gate | 36824683225 | 110253685960 | success |
| Project dashboard gate | 36824683092 | 110247614691 | success |

Die Offline-Prüfung bestätigt 266 tatsächlich ausgeführte Quelltests ohne Lücken oder Duplikate, verteilt auf 67/67/66/66; 27 Runtime-Prüfungen; je 41 Export-Prüfungen und drei erfolgreiche Probes mit dem Release-PCK unter Windows und Linux. Alle acht Environment-Capture-Jobs und ihre eigentlichen Render-Schritte liefen erfolgreich. Das Quelltest-Plan-Artefakt wählte 266 von 266 registrierten Tests im FULL-Modus aus; diese Auswahl stimmt exakt mit allen vier Ergebnisartefakten überein.

Der CI-Merge-Commit ist `2937ac77970da0d9bf3622e83fd4b4894a53949f`, der saubere Baum `a1a53c20730b1000e703ff1add4dd854fcdb069a`. Alle Ergebnisartefakte melden dieselbe vollständige Quelle mit 5.400 Dateien und SHA256 `c06aed81737a973930f8969b922ac183585dc25dad3ff2dfc8e46f09f0c36ae5`, Godot `4.6.3.stable.official.7d41c59c4` und wiederverwendbare Provenienz. Alle tatsächlichen Start-/End-Manifeste aus Quelltest- und Runtime-Artefakten sind bytegleich, SHA256 `9463c6cf91d9877ef2be3cf11bec9375e54880a11cadafafdba3febc92c144ef`. 384 deklarierte Einzel-Log-SHA256 stimmen mit den gesicherten Logdateien überein.

| Erhaltener Rohbeleg | Run-ID | Job-ID | GitHub-Artefakt-ID |
|---|---:|---:|---:|
| artifacts/source0.zip | 36824683190 | 110249451976 | 11145429131 |
| artifacts/source1.zip | 36824683190 | 110249451917 | 11145998426 |
| artifacts/source2.zip | 36824683190 | 110249451899 | 11146411211 |
| artifacts/source3.zip | 36824683190 | 110249451878 | 11147306378 |
| artifacts/runtime.zip | 36824683190 | 110249451927 | 11145327082 |
| artifacts/plan.zip | 36824683190 | 110249064735 | 11144981634 |
| artifacts/windows.zip | 36824683231 | 110249603491 | 11146481099 |
| artifacts/linux.zip | 36824683231 | 110249603521 | 11146810813 |

Die ZIP-Dateien sind unverändert erhalten. `manifest.json` bewahrt die authentifizierten Artefaktmetadaten mit API-Digest, Größe, Herkunfts-Run und exaktem HEAD sowie vollständige Job-/Schrittsnapshots. `exact-head-query.json` enthält Anfrage und Antwort des finalen commitgebundenen Workflow-Snapshots. Der Connector liefert nur die erste Seite der PR-Läufe und lässt `head_sha` in Workflow-Zeilen weg; die Anfrage dokumentiert deshalb den exakten Commitfilter. Artefaktmetadaten pinnen Quelltest-, Export- und Environment-Läufe zusätzlich unabhängig auf den HEAD. Es wird keine Vollständigkeit aller existierenden Workflow-Läufe behauptet.

Die akzeptierten inneren Paketidentitäten kommen aus den Export-Diagnosen:

| Release-Paket | Bytes | Paket-SHA256 |
|---|---:|---|
| voxelverse-windows-x86_64.zip | 44315698 | fd18d29ca0188c37cecc8f585a1da7accd4ffb7e1bee692575aa3c0a88c9b44b |
| voxelverse-linux-x86_64.zip | 35479182 | 11fb7ae9c759bebfe24405158c6d13fbff298ed482f3ef2bbeb65f2a835ababb |

Die zugehörigen äußeren GitHub-Build-Artefakte sind `11146391242` (`voxelverse-windows-pull_request`, 44169174 Bytes, API-ZIP-SHA256 `f37babcd7702716c172f752d4c24e1a52b78bff2e2cfb1ea44720c43637e173c`) und `11146830649` (`voxelverse-linux-pull_request`, 35445943 Bytes, API-ZIP-SHA256 `49e1eba887656a42517853d9aa7c7a21fc30b63fc260faf7b9ef7a427bd4428b`). Inneres Release-Paket und äußeres GitHub-Artefakt sind unterschiedliche Archive. Die Build-ZIP-Bytes wurden hier nicht erneut heruntergeladen oder unabhängig gehasht.

Die Export-Diagnosen enthalten keine Manifest-Payloads; ihre deklarierten Manifest-Digests stimmen mit den tatsächlich erhaltenen Quelltest-/Runtime-Manifeste überein. Environment wurde anhand erfolgreicher tatsächlicher Render-Schritte und acht zugehöriger Artefaktmetadaten geprüft; Render-ZIPs und PNGs sind nicht Teil dieses Pakets und wurden hier nicht visuell begutachtet. Das separate Paket `latest74bb-evidence` hält weitere native CI-Metadaten fest.

Target-PC-Abnahme, subjektive Sichtprüfung, Performance-Abnahme und zusätzliche native Vergleichsflows bleiben offen. Die bekannten roten Zusatzläufe Tribal tutorial, Surface transition comparison und INT30 scenery collision capture bleiben eigene Fehlernachweise und werden durch die vier grünen Pflicht-Gates nicht aufgehoben. Spätere Quellbäume benötigen erneut ihre eigenen vollständigen Ergebnisse.

Offline prüfen, ohne Netzwerk, Godot oder einen neuen CI-Lauf:

```sh
python3 verify.py
```

`verification.json` ist die gespeicherte Ausgabe dieser Prüfung. `SHA256SUMS` listet die Bytes aller enthaltenen Dateien außer sich selbst.
