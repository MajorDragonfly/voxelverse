Der originale Forward+-Publikationslauf bleibt negativ: Near überschreitet das
90-s-Kriterium nach 90.298 s bei 5/25 Patches; der unveränderte 360-s-Guard
beendet den Lauf mit Exit124 während Far-Publikation. Dieser Draft dokumentiert
die abgeschlossene Diagnose und die verbleibende native Quellen-/Symbolgrenze.
Ein Produktfix und eine allgemeine Forward+-Abnahme stehen weiter aus.

Die neue opt-in H1-Trace beobachtet die tatsächliche Loopflag, Threads,
Process-/Physics-/Drawn-Counter und Drawsignalgrenzen. Sie erhält alle originalen
Draws, Captures, Kamera-/Qualitäts-/Inputkriterien und 90/360-Guards.

| Aktueller Original-Vulkanbefund | Ergebnis |
| --- | --- |
| Renderer | Echtes Vulkan1.4.318 / Forward+, explizites LVP-ICD, LP2 |
| Originalfixture | 16,167 B, seed 15838, SHA-256 `f01e33bb1506bff40ab2641a58f9211dfcbd1aa0db686dde71e0421d1d682569` |
| Route | 960×540, 25 Zielzellen, vier solide Familien |
| Ansichten | 120, jeweils 30 pro Familie, keine PNG-Fehler |
| Near | 90.298 s, 5/25 Patches, Originalkriterium verletzt |
| Far / Return / Final | Far bei Outer-360s abgebrochen; Return/Final unvollständig |
| H1 | Loop=false und 529 unmarkierte pre-/528 post-draw-Signale |
| Near-Drawbracket | 102 Paare/Drawn-Delta102; 67.693 s zwischen pre/post-draw |
| Host / Source | Kernel-PIDFD-Bindung gültig, Foreign=false, sauberer vollständiger START=END |

Der gemessene QA-Stand ist `00aabe3299941af468095356fcb67a99416c9f92`,
Tree `4c086f677e4f7faecc2bec1c52a13dc7b7498b49`. SourceRun START=END:
`70c68cc5dcb34eb9c63f418d2e0584c6dd97047f6d995e60bb3af1da73829093`;
Manifest START=END:
`ab2874ecd4884390a9ff22c6e983703c9f085fb8f18a7e726ec872c7b837f0ce`.
Der tatsächliche Godot-4.6.3-Binaryhash ist vor/nach unverändert
`f64d4ed19fc9df9440321653fcc80df8c6e365ba7b6de0a29e2cfa9fa71bfeb3`.

Die Signalbrackets grenzen die Hauptwartezeit ein; sie liefern keine reine
GPU-Zeit oder belegte Hardware-/Producerursache. Der GL-Referenzlauf bestand
die Originalspielkriterien, bleibt wegen Hostexit76 diagnostisch und nicht
für Capture-Abnahme wiederverwendbar. Seine Negative ist erhalten. Die
anschließende enge Kernel-PIDFD-Korrektur bestand 17 Offlinefälle plus acht
unabhängige Faultchecks und lief im Vulkanfall ohne Ownershipfehler. Die
beiden Rendererfälle sind einzeln quellengebunden; drei dazwischen integrierte
Minimap-Reflowzeilen verhindern eine Behauptung eines identischen Produkt-A/B.

Die nominalen offiziellen Godot-4.6.3-Primärquellen zeigen, dass Pending-RD
Resource-Retirement einen automatischen `draw(false)` trotz Loop=false zulassen
kann. Die exakte gemessene Build-Identität
`7d41c59c457bd5a245092b4e7eb2d833e3b3f8c3` ist öffentlich nicht aufgelöst
(Commitlookup422); das offizielle Tag zeigt auf `35e80b3…`. Das gemessene ELF
ist für die gesuchten Main-/RD-Pfade ohne nutzbare Symbole/Debuglink. Native
Counterwerte und ein tatsächlicher Producer bleiben offen.

Nächster konkreter Input ist der passend gebundene Source-/Symbolsatz für das
gemessene Binary, anschließend eine enge opt-in Main-Gate-/RD-Retirement-Trace
mit unveränderten Originalparametern. Zielhardware kann separat den echten
Hardwarebefund liefern. Ein identischer uninstrumentierter Retry oder eine
Lockerung von Zeit-/Qualitätskriterien ist nicht vorgesehen.

Die aktuelle Berichtfortsetzung ist committed bei
`2712d684d624819f5cdae6b11bf9f79be606b0a2`:
`docs/evidence/r33-08/H1_REPORT.md` und `h1-observation-summary.json`.
Veröffentlichung der ergänzenden Quellenevidenz/Roharchive erfolgt durch R33-01
im Abschluss. Dieser PR bleibt Diagnose-Draft ohne Produktmerge-Freigabe.
Der ursprüngliche PR-Head `18559dda756ac9254f871ee9ad60c7bc61f240ff`
und Original [#246](https://github.com/MajorDragonfly/voxelverse/pull/246)
bei `d5610eaafe43eb6246fc2a99676d064ba035bc78` bleiben unverändert.
