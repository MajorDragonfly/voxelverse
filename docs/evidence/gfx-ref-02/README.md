# GFX-REF-02 – Bodendecker und Waldboden

Gras erhält drei ungleichmäßige Blattfächer, Farne gebogene Wedel mit breiteren Blattpaaren und Blumen besser lesbare Blüten samt niedrigem Blattwerk. Paletteabhängige Moos-/Lehmpigmente unterbrechen große gleichförmige Bodenflächen. Eine zusätzliche native Probe reproduzierte einen bestehenden Rundungsfehler im feinen Korn auf exakt rastergleichen Flächen; die Abtastung ist dort jetzt auch nach einem Ursprungwechsel stabil.

Die Grafikausrichtung folgt Lars’ drei Referenzbildern. Deren vollständige Landschaftsdichte, Geländeformen und Detailqualität sind damit noch nicht erreicht. Dies ist keine Ziel-PC-, FPS- oder Spielkomfortfreigabe.

## Quelle

| Stand | Commit / Tree |
|---|---|
| Feste main-Basis | `64c3ac6bd9797006c5f269f6fb8fa2c7b50d0508` / `fce1f0510947857b4f42b2cdbed0a0a436cd14f1` |
| Veröffentlichter Produktkopf | `eed4d10328eb9646fc2e979c7feb039849f14837` / `2ab6fafd7e850b28cda48fbdb3b31371c23f0095` |
| Inhaltsgleicher lokaler Lieferkopf | `312a1eb11243f1289023a7b90c9c853cdd50c438` |
| Tatsächlicher CI-Mergecheckout | `56a595030ddb6a220b036770c7f5fd378e890953`, identischer Produkt-Tree; Eltern Basis + Produktkopf |
| Vollständiger Linux-Quellenhash | `5409327599b6e887717fe7a42066364d78a98ac1cf0cd4dfa94fde311ce4d2bd` |

[Produkt-PR #290](https://github.com/MajorDragonfly/voxelverse/pull/290) · [Koordination](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-6341578857). Dieser Evidenzbranch ist kein Produktmerge. `product-files.json` bindet alle 42 geänderten Produktdateien; `handoff.txt` stammt vom bestehenden Paketwerkzeug. Keine fremden Diagnosezweige oder zentralen Dashboard-Quelldaten übernommen.

## Abnahme und Bildvergleich

Status: Beide nativen Kampagnenvergleiche bestehen alle 16 exakten Bildpaare (32 Originalbilder), einschließlich vollständiger Body-Daten ohne Cursor-Ausnahme. Boden- und Ursprungsprüfung sind ebenfalls abgeschlossen. Finale Integrations-/Exportabnahme wird ergänzt.

- Import und drei direkte Verbraucher bestanden. Alle 21 registrierten Near-Quellen exportieren bytegleich; die 12 Baum-LOD-Exporte und sieben historischen Negativkontrollen bleiben positiv erkannt.
- Modellbilanz der neun Bodendecker: Near 56.160 → 52.160 Dreiecke (−7,12 %), Mid 17.242 → 16.426 (−4,73 %), Far 5.402 → 5.348 (−1,00 %). Das ist eine Modellbilanz, kein gemessener Gesamtleistungsgewinn.
- Aktiver Kugelboden: zwei native Renderer, je fünf Biome × drei Entfernungen mit echten Vorher-/Nachherbildern. Keine Geometrie-, Kollisions-, Palette- oder Instanzpositionsänderung für den Vergleich; aktive Shader und tatsächliche Palette aus dem bestehenden Materialanschluss.
- Native Ursprungprobe auf einer farbigen Ebene mit dem unveränderten Produktionsshader: ursprünglicher Shader GL 0,006046 mittlere RGB-Abweichung, erster Kandidat 0,003388; beide ursprünglichen Negativläufe bleiben erhalten. Die Korrektur erreicht in GL/Forward+ rund 0,000001–0,000003 und besteht die unveränderte Grenze 0,0001 sowie den 128-m-Periodenwechsel. Eine bewusst fehlende Origin-Aktualisierung bleibt deutlich negativ (>0,018). Die Ebene isoliert den Shader und ist kein Kampagnenersatz.
- Kampagnenbilder laufen über den öffentlichen SessionFlow-Einstieg, denselben vollständigen portablen Save, feste forest/forest-floor/water/creature-close-Kameras, Preset 1, 960×540 und dieselbe autoritative Tag-/Nachtuhr. Originale, Kamera-/Licht-/Palettenprüfung und echte Streaming-Abschlüsse liegen in den Laufarchiven. Je Bild vier Warmup- und sechs gemessene pausierte `force_draw`-Aufrufe; keine Gameplay-FPS-Messung.

Godot 4.6.3; isolierte Nutzerdaten; native Hostabschnitte auf `fa9fa0aa2a99` seriell mit beiden Heavy-Locks; Mesa25.2.8/llvmpipe, LLVM20.1.2. Die reguläre Simulation, Platzierungs-RNG, IDs, Saveformat, Gelände-/Kollisionsflächen und Produktions-/Publikationsbudgets sind unverändert. Softwarekosten sind gemischt und in `native-comparison.json` vollständig sichtbar; insbesondere der Waldüberblick kann trotz kleinerer aggregierter Modelle mehr sichtbare Primitive und höhere Drawzeiten zeigen. Daraus folgt keine Hardware- oder FPS-Aussage.

## Originale

`original-archives.json` nennt Größen, SHA256 und geordnete Teile der vollständigen lokalen Originalarchive. Große ZIPs sind verlustfrei in höchstens 2 MiB große Dateien geteilt. Zum Wiederherstellen die für ein Archiv verzeichneten `parts` in ihrer Reihenfolge zusammenfügen und dessen SHA256 prüfen. Kleine Archive liegen direkt als ZIP vor. Negative Zwischenläufe sind ausdrücklich keine aktuelle Abnahme.

`reference.json.gz` enthält den vollständigen unveränderten Replay-Fixture einschließlich Regionsblobs und expliziter Kameras. `scripts/` dokumentiert äußeren Hostrunner, Proberunner und Paarvergleich; der neue eigentliche native Regressionstest liegt in `tools/review_ground_origin.gd` am Produktkopf. Die absoluten Hostpfade der äußeren Runner sind Laufbelege und müssen für andere Hosts angepasst werden.

`ci/environment-*/` bewahrt ausgewählte unveränderte Modellaufnahmen der vollständigen CI-Artefakte, deren Import-/Quellenbindung, Index und ZIP-Digest. Gezeigt werden echte Near/Mid/Far-Modelle von links nach rechts, keine Konzeptgrafik. Die vollständigen CI-Artefakte sind über ihre beobachteten Artifact-IDs verlinkt.
