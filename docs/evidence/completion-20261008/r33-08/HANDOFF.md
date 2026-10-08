# R33-08 H1 Abschluss und Übergabe

Die Diagnose ist abgeschlossen. Der ursprüngliche echte Forward+-Lauf bleibt
negativ: Near-Publikation brach nach 90.298 s mit 5/25 Patches das originale
90-s-Kriterium; der originale 360-s-Prozessguard beendete den Lauf mit Exit124
während Far-Publikation. Return und Final sind nicht abgeschlossen. Alle 120
Originalansichten liegen vor, 30 pro Familie und ohne PNG-Fehler. Ein Produktfix
oder eine allgemeine Forward+-Abnahme liegt nicht vor.

Die passive Methodik hat H1 konkret eingegrenzt: Loopflag, Thread, Phase,
Process-/Physics-/Drawn-Counter und pre/post-draw werden ohne zusätzliche Draws
beobachtet; die originalen ForceDraw-/Readback-/PNG-Captures sind separat
markiert. Vulkan erzeugte bei tatsächlichem Loop=false 529 unmarkierte
pre-draw-/528 post-draw-Signale. Die vollständige Near-Phase enthält 102 Paare
mit Drawn-Delta102; 67.693 s liegen zwischen pre/post-draw. Diese Brackets
enthalten Rendering, Signalverbraucher und Queue-/Schedulingarbeit, keine
gemessene reine GPU-Zeit.

Der Kernel-PIDFD-Hostguard hielt beide Locks durchgehend, löste lokale PIDs in
die gemountete proc-Domain auf und prüfte Namespace/Startticks/lebende Bindung.
17 Offlinefälle und acht unabhängige zusätzliche Faultchecks bestanden. Der
tatsächliche Vulkan-END meldete gültige Bindung, Foreign=false und keine Godot;
beide Locks wurden danach tatsächlich frei geprüft. Der frühere GL-Lauf bestand
die Spielkriterien, bleibt wegen Hostexit76 als Diagnose mit verworfener
Capture-Abnahme erhalten. Sein Originalbefund wurde nicht umgeschrieben.

Quellgebundener Vulkanstand:

- Gemessener QA-Commit `00aabe3299941af468095356fcb67a99416c9f92`,
  Tree `4c086f677e4f7faecc2bec1c52a13dc7b7498b49`.
- Vollständiger sauberer SourceRun START=END:
  `70c68cc5dcb34eb9c63f418d2e0584c6dd97047f6d995e60bb3af1da73829093`;
  Manifest START=END
  `ab2874ecd4884390a9ff22c6e983703c9f085fb8f18a7e726ec872c7b837f0ce`.
- Tatsächlicher Godot-4.6.3-Binaryhash vor/nach gleich:
  `f64d4ed19fc9df9440321653fcc80df8c6e365ba7b6de0a29e2cfa9fa71bfeb3`.
- Originalfixture: 16,167 B,
  `f01e33bb1506bff40ab2641a58f9211dfcbd1aa0db686dde71e0421d1d682569`;
  seed 15838, 960×540, LP2, 25 Zellen/vier Familien und Original90/360 erhalten.
- Echte Vulkan1.4.318/Forward+-Header, explizites portables LVP-ICD;
  Software-Mesa liefert keine Hardwareursache.

Bericht und maschinenlesbare Auswertung sind sauber committed bei
`2712d684d624819f5cdae6b11bf9f79be606b0a2`, Tree
`be7dc7d0496b2dc2d1e8e8b3de029825fd40b05e`:
`docs/evidence/r33-08/H1_REPORT.md` und `h1-observation-summary.json`.
Die ursprünglichen Heads #273 (`18559dda756ac9254f871ee9ad60c7bc61f240ff`)
und #246 (`d5610eaafe43eb6246fc2a99676d064ba035bc78`) sind unverändert.

Der belegte nächste externe Blocker ist die native Symbol-/Quellenbindung.
Das gemessene ELF enthält FULLSHA
`7d41c59c457bd5a245092b4e7eb2d833e3b3f8c3`; der offizielle Commitlookup
liefert422. Das nominale offizielle 4.6.3-Tag ist stattdessen `35e80b3…`.
Seine gepinnten Primärquellen zeigen den Pending-RD-Drawgate und den
Resource-Retirement-Zähler; diese Quellen sind ausdrücklich keine Bindung an
das gemessene Binary. Das vorhandene ELF-Inventar fand weder `.symtab`,
Debuglink/Debugsektionen noch die gesuchten dynamischen Main-/RD-Symbole.
Counterwerte und native Producer wurden daher nicht erfunden.

Benötigter nächster Input: exakt zu diesem Binary gehörender Sourcebaum oder
Symbol-/Debugpaket mit überprüfbarer Build-Zuordnung. Damit ist eine einzige
enge opt-in Trace der Main-Gatewerte und RD-Retirement-Reset-/Decrementkante
mit RID-Typ/Caller möglich, unter derselben Originalroute und denselben
Guards. Eine alternative Zielhardwaremessung kann einen eigenen Hardwarebefund
liefern; sie ersetzt keine native Producerbindung. Ein identischer H1-Retry
ohne neuen Diskriminator ist nicht vorgesehen.

Root veröffentlicht die Quellenevidenz/Roharchive und aktualisiert Status sowie
PR-Beschreibung. Staging enthält keine Remote-Schreibaktion, keinen weiteren
Engineaufruf und keine Produktmerge-Freigabe.

Kleine externe Primärquellenbelege:
`/workspace/scratch/c544365b4f76/forward-source-review-463/REPORT.md`,
`source_bindings.json` und `ELF_BINDING_LIMIT.json`.
Rohdaten: `/workspace/scratch/c544365b4f76/r33-h1-vk/` und
`r33-h1-vk-host.jsonl`; GL-Hostnegative separat unter `r33-h1-gl/`.
