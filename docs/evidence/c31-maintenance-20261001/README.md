# C31-MAINTENANCE · 01.10.2026

Feste Basis: `6696ebbece32a3b68fbaeb7eed3d7be8f27a11a3`, Tree
`13de36b0776c8a7c7ec28910a793f4315fda1e25`. Auftrag: den integrierten
Spielstand vor weiteren Fachpaketen prüfen, sichere Altlasten bereinigen und
Entwicklungs-/Prüfzeiten verbessern.

## Änderungen und Grenzen

- Vier disjunkte Quelltestjobs anhand tatsächlicher historischer Laufzeiten
  verteilen; alle 267 Prüfungen, ihre Deadlines und die vier Pflichtgates bleiben
  erhalten. Profil und Originalartefakthashes stehen in
  `tools/validation/source_timings.json`. Historisches Replay derselben 266 Tests:
  längster Job rechnerisch 3232 auf 2304 Sekunden. Aktuell 267 mit 900 Sekunden
  Reserve für den ungemessenen Test: geschätzte 2529 Sekunden. Das ist eine
  Planungsrechnung, keine neue CI-Leistungsmessung.
- Fünf ältere Spezialworkflows nutzen die bereits vorhandene gecachte, jedes Mal
  gegen SHA256 geprüfte Editorinstallation. Elf fehlende Abbruchregeln verhindern
  Prüfungen überholter Revisionen. Der schreibende Live-Status bleibt serialisiert.
- Drei verschachtelte Entwicklungsverzeichnisse aus beiden Exportpresets
  ausschließen. Die fünf Quellen bleiben für Tests und Diagnosen erhalten.
  Der reale, isolierte PCK-Vergleich entfernt zehn Test-/Remap-/Captureeinträge:
  9.889.556 auf 9.862.436 Bytes; alle 1.417 gemeinsamen Ressourcen bytegleich.
  Linux- und Windows-Preset auf Linux ergeben dieselbe Differenz. Dies ist keine
  native Windows-Abnahme und kein Vergleich des gesamten UI-Kandidaten.
- FirstSteps-Karten und Pausenhilfe formatieren identischen Inhalt, Fonts und
  Layout nicht mehr jeden Frame. Sprache, reale Bindings, UI-Skalierung,
  Fenstergröße und nativer Keyboardlayout-Index invalidieren die Präsentation.
  Fortschrittsbeobachtung und Spielereignisse werden unverändert verarbeitet.
- Dashboardquelle und erzeugte Ansichten nennen die tatsächlich abgeschlossene
  main-Übernahme von #245. Sie lassen fachliche Sicht-/Ziel-PC-Abnahmen offen.
- Ein echter Fehler der ersten CI-Runde wurde behoben: Der Bodenmaterial-Wrapper
  verlangte eine sichtbare Änderung auch bei byteidentischen Shaderquellen.
  Unveränderte Quellen müssen nun in allen 15 Fällen identische RGB-Messwerte und
  PNG-Paare liefern. Bei geänderten Quellen bleibt die ursprüngliche sichtbare
  Delta-Grenze von 0,004 erforderlich. Alle 30 Bilder, Renderer-, Draw-Call-,
  Fehler-/Leak- und Zeitgrenzen bleiben erhalten; Quellhashes werden vor/nach dem
  Capture geprüft. Die sechs gezielten Fehler-/Gleichheitsfälle scheiterten vor
  der Korrektur und bestehen danach. `ground-review-negative.json` hält den
  ursprünglichen negativen Workflow samt seinen positiven nativen Captures fest.

## Lokale Vorprüfungen

228 Toolingtests abgeschlossen: 221 bestanden, sieben Tests wegen nicht vorhandener
optionaler Laufzeit-/CLI-Voraussetzungen ausgelassen. Die gezielten Planner-, Hygiene- und
Dashboardfälle bestanden zusätzlich. Vertragsprüfung: 267 registrierte Tests,
18 Verträge, 2596 DE/EN-Texte; Hygiene und erzeugte Ansichten konsistent.
Alle 38 Workflowdateien strukturell geprüft; Tests, Trigger, Timeouts und
Fehlerfilter erhalten. Die gemeinsame vollständige CI wird separat im PR belegt.

Die erweiterte PCK-Probe erkennt auf der Basis genau die fünf unerwünschten
Ressourcen und scheitert erwartungsgemäß. Das bereinigte Paket besteht mit 63
Produktionsmeshes, Weltaufbau und Save-Roundtrip. Originale Probeausgaben und
Packvergleiche liegen neben diesem Bericht.

Die isolierte UI-Probe auf main plus zwei UI-/Teständerungen besteht
`onboarding_guidance_world_test` in 71,670 Sekunden und `hud_layout_test` in
45,100 Sekunden: echte Welt, Nahrung/Wasser, Rollbacks, Sprache, Skalierung,
Neubelegung und frischer Prozess. Unveränderte Karten lösen keine Font-Theme-
Writes aus. `focused-ui.json` nennt den tatsächlich geprüften Quellbestand;
die spätere Keyboardlayout-Index-Ergänzung ist darin ausdrücklich ausgenommen
und separat mit Godot 4.6.3 geparst. Gesamtbeleg folgt aus der gemeinsamen CI.

## Erhaltene offene Arbeit

Keine weitere sichere Löschliste gefunden: verwaiste UID-/Importdateien und
getrackte Cache-/Builddateien fehlen; alte HUD-/Design-/Weltpfade besitzen reale
Verbraucher oder schützen Migrationen. Historische Nachweise und Fachbranches
bleiben erhalten. #189, Draft #246 und die 23 fachlichen Teilissues bleiben offen.
Forward+-Ursache, langfristige Spielleistung und die Prüfung auf Lars' PC werden
durch diese Bereinigung nicht als erledigt erklärt.
