# GFX-REF-02 – Bodendecker und Waldboden

Gras erhält drei ungleichmäßige Blattfächer, Farne gebogene Wedel mit breiteren Blattpaaren und Blumen größere Blüten samt niedrigem Blattwerk. Paletteabhängige Moos-/Lehmpigmente unterbrechen gleichförmige Bodenflächen. Das feine Korn bleibt nach einem Ursprungwechsel auch auf exakt rastergleichen Flächen stabil.

Lars’ vollständiger Referenzlook, Landschaftsdichte und Geländeformen sind noch nicht erreicht. Ziel-PC-, FPS- und Spielkomfortabnahme bleiben offen.

## Aktuelle Quelle

| Stand | Commit / Tree |
|---|---|
| Aktualisierte main-Basis, einschließlich #291 | `ca7ac06b671abceec54a110682c70746bfddde45` / `dd8d5aa1676ba320a37d267d5cf0893134130109` |
| Aktueller Produktkopf | `70b42cfb11868f47c4ffe94a581b54a62f7b2eb9` / `d31860a0ed3a13f8a6c0c77a95d8f79fda212b97` |
| Aktueller CI-Mergecheckout, identischer Produkt-Tree | `3df6727ef184af3d13772aa4e2cf5bf9990399f5`; Eltern aktuelle Basis + Produktkopf |
| Tatsächlich nach main übernommen | `a8d19667d88e0c095eb8e238cdaff6aee10c8992`, identischer geprüfter Produkt-Tree; Eltern aktuelle Basis + Produktkopf |
| Vollständiger aktueller Linux-Quellenhash | `f4eeb33da6ced083efe6e5e062a7ec649a07d63680849ffa9d94be890b19ce5f` |
| Vollständig geprüfter Grafikstand vor Basisaktualisierung | `60a58ae1c9963cebdbbefc4c2896c4da1f996d6c` / `4d73ada2d4bc9e28b01f05b431b6b954b8bb013c` |
| Historischer Kandidat mit vollständigen lokalen Bildpaararchiven | `eed4d10328eb9646fc2e979c7feb039849f14837` / `2ab6fafd7e850b28cda48fbdb3b31371c23f0095` |

[Produkt-PR #290](https://github.com/MajorDragonfly/voxelverse/pull/290) · [Koordination](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-6341578857). Dieser Evidenzbranch wird nicht in main integriert. `product-files.json` bindet alle 43 geänderten Produktdateien an den aktuellen Kopf. Gegenüber dem geprüften Grafikstand wurden ausschließlich `AGENTS.md` und `docs/DEVELOPMENT_WORKFLOW.md` aus dem bereits integrierten #291 eingebunden. Keine fremden Diagnosezweige oder zentralen Dashboard-Quelldaten übernommen.

## Abnahme

Abgeschlossen und über PR #290 nach main übernommen: 298/298 tatsächlich ausgeführte registrierte Quelltests über acht disjunkte Shards, 27/27 Runtime-Prüfungen mit 23 echten Headless-Prozessen, beide nativen Desktop-Exporte mit je 42 Prüfungen und drei Planetenproben, beide Renderpfade sowie alle vier offiziellen Pflichtgates. Der aktualisierte gemeinsame Stand wurde vollständig neu geprüft. Der tatsächliche main-Merge besitzt exakt denselben Tree wie der erfolgreiche CI-Mergecheckout; deshalb kein identischer Wiederholungslauf nach dem Merge.

`ci/current/source-execution.json` bindet alle 298 eindeutigen Tests und verifizierten Log-/Quellmanifesthashes. `ci/current/acceptance.json` bewahrt die vier aktuellen Gates einschließlich GitHub-Actions-App15368, Head, Job-IDs und tatsächlichem Merge. Beide Reviewthreads sind erledigt; der Branch enthielt die aktuelle main-Basis und die Queue war vor Übernahme nicht pausiert.

[Windows-Testbuild](https://github.com/MajorDragonfly/voxelverse/actions/runs/39805398953/artifacts/12441650303) · [Linux-Testbuild](https://github.com/MajorDragonfly/voxelverse/actions/runs/39805398953/artifacts/12441465352). Die CI-Downloads laufen nach sieben Tagen ab. `ci/current/desktop-build-verification.json` erhält Größen und SHA256 der tatsächlich heruntergeladenen äußeren und inneren Archive sowie deren eingebettete Build-Informationen. Die Exportberichte enthalten 42 erfolgreiche Prüfungen einschließlich der abschließenden Archivprüfung; das zuvor eingebettete BUILD_INFO nennt korrekt die 41 Prüfungen vor der Archivbildung. Linux und Windows haben denselben Git-Tree; ihre plattformspezifischen Quellenhashes werden getrennt erhalten.

Die Codeprüfung fand zwei korrigierte Fehler: Far-Blumen verschoben ihre erhaltenen Stängel; vierte CLI-Varianten führten zu `IndexError`. Alle LODs verwenden nun dasselbe Sieben-Stängel-Raster, zusätzliche Varianten zyklische Morphologiefaktoren. Alle drei Far-Blumen-GLBs wurden neu exportiert. Zwei neue Regressionen prüfen reale Stängelkurven und einen vollständigen temporären CLI-Export mit vier Varianten. Beide erkennen den alten Fehlerstand; alle vier Authoring-Tests bestehen. Beide Reviewthreads sind erledigt.

Der erste `terrain_lookahead_test` auf `4d73…` scheiterte am unveränderten 45-Sekunden-Kampagnenstart vor den Terrainprüfungen. Originaler negativer Lauf und unveränderter erfolgreicher Wiederholungslauf bleiben unter `ci/reviewed-4d73/` und `originals/current-ci/` erhalten. Die CI-Wiederholung dauerte insgesamt 79,934 s, der ebenfalls unveränderte lokale Gegenlauf 84,315 s. Die Ursache schwankender Startzeiten ist nicht nachgewiesen; keine Frist, Assertion oder Terrainbudgetgrenze wurde gelockert.

Modellbilanz der neun Bodendecker: Near 56.160 → 52.160 Dreiecke (−7,12 %), Mid 17.242 → 16.426 (−4,73 %), Far 5.402 → 5.428 (+0,48 %). Keine Gesamtleistungs- oder FPS-Aussage. Platzierungs-RNG, IDs, Saves, reguläre Simulation, Terrain-/Kollisionsflächen und Produktions-/Publikationsbudgets sind unverändert.

## Bilder und Ursprungsprüfung

`ci/environment-*/` enthält aktuelle native Near/Mid/Far-Modellaufnahmen beider Renderer, Quellenbindung und Artefaktdigests. `ci/current/campaign-*/` zeigt den tatsächlichen öffentlichen Kugelkampagnenweg. `ci/current/ground-*/` und die vollständigen Ground-Artefakte enthalten je fünf Biome × drei Entfernungen mit nativen Vorher-/Nachherbildern. Es sind Engine-Ausgaben, keine Konzeptgrafiken.

Die unveränderten historischen Archive in `original-archives.json` bewahren 16 exakte Kampagnenbildpaare sowie Body-/Save-/Kamera-/Uhr-/Licht-/Palettenbelege des Kandidaten `2ab6…`. Der aktuelle Produktionsshader ist bytegleich zum archivierten Shader; `current-proof-scope.json` bindet Blob und SHA256. Native Ursprungprobe: ursprünglicher Shader GL 0,006046 mittlere RGB-Abweichung, erster Kandidat 0,003388; die Korrektur GL/Forward+ rund 0,000001–0,000003 bei unveränderter Grenze 0,0001, einschließlich 128-m-Periodenwechsel. Bewusst fehlende Origin-Aktualisierung bleibt negativ (>0,018). Die farbige Ebene isoliert den Shader und ersetzt keine Kampagne.

Auf `4d73…` wurden lokal erneut alle 16 exakten Bildpaare ohne Ausnahmen und beide Ursprungsproben erfolgreich beobachtet. Diese letzten lokalen Rohdateien gingen vor Veröffentlichung bei einer Bereinigung der temporären Umgebung verloren. `current-proof-scope.json` benennt diese Grenze; historische Archive werden nicht als finale Roharchive ausgegeben. Aktuelle CI-Originale sind unabhängig wiederhergestellt und per SHA256 geprüft.

Godot 4.6.3; isolierte Nutzerdaten; ursprüngliche native Hostläufe seriell mit beiden Heavy-Locks auf `fa9fa0aa2a99`, Mesa25.2.8/llvmpipe/LLVM20.1.2. Je historischem Bild vier Warmup- und sechs gemessene pausierte `force_draw`-Aufrufe. Softwarekosten sind gemischt, Waldansichten teilweise höher; vollständige historische Messungen in `native-comparison.json`. Keine Hardware-/Gameplay-FPS-Aussage.

## Originale

`original-archives.json` beschreibt unveränderte historische lokale Laufarchive, `ci/current/original-archives.json` die wiederhergestellten CI-Archive einschließlich des erhaltenen Terrainfehlers. Teile in verzeichneter Reihenfolge zusammenfügen und Archiv-SHA256 prüfen. Große ZIPs sind verlustfrei in höchstens 2 MiB große Dateien geteilt. Negative Zwischenläufe sind keine Abnahme.

`reference.json.gz` enthält das vollständige ursprüngliche Replay-Fixture mit Regionsblobs und Kameras. `scope.json`, `handoff.txt`, `ci/merge-source.json`, `ci/runtime-execution.json`, `native-comparison*.json` und `previews/` bleiben historische Belege des Kandidaten `2ab6…`. Aktuelle Bindung: `ci/current/`, `product-files.json`, `current-proof-scope.json`. Absolute Hostpfade der Runner unter `scripts/` müssen für andere Hosts angepasst werden.
