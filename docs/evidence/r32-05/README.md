# R32-05 – sichtbarer Scanner und unabhängige Nestentdeckung

Auftrag: #172/#173, eigener Branch `agent/r32-05-scanner-nests` von
`2a738a4891a8de11d682c469833ade4dc9b01dfb` (Tree
`f2bda4f815df1c73b9d740ca5282917523faf618`). Fach-Draft: [#265](https://github.com/MajorDragonfly/voxelverse/pull/265).
AGENTS.md, #137 und die aktuellen Abgleiche in #172/#173 wurden gelesen.

## Verhalten und Schreibbereich

Der vorhandene Scanner bleibt bestehen. Seine Sichtprüfung liest nun auch bei
fremden Tieren/Nestern die tatsächlich sichtbaren Meshes. Eine leere Stelle in
einer Bewegungskapsel darf ein sichtbares Ziel nicht verstecken; ein sichtbarer
Körperteil außerhalb dieser Kapsel muss umgekehrt verdecken können. Nester
verwenden denselben visuellen Kreisprädikat wie Tiere, statt Sichtbarkeit aus
dem Abfragezylinder abzuleiten. Gültige AABB-Treffer bei `Vector3.ZERO` werden
mit einem ausdrücklichen Nullvergleich erhalten.

Bei zwei Kontakten im selben Viertelpixel-Bucket übernimmt der nähere Kontakt
unmehr auch den zu seinem Oberflächenpunkt passenden Bildschirm-Pixel. Die
Basis aktualisierte nur den Punkt; ein eigener kontrollierter Zweidreieckstest
belegt die Inkonsistenz und prüft die tatsächliche Projektion.

Die zusätzlichen Mesh-Strahlen benutzen die vorhandenen lokalen
Instanz-BVHs und Godots native TriangleMesh-BVH (einmal je Meshcache). Sie ändern weder den Kontaktpunkt des ausgewählten Ziels noch die laufende
Konturabfrage. Solide Weltwände und die vorhandene Hysterese bleiben erhalten.

Produktänderungen: `creatures/player/creature_scanner.gd`,
`core/discovery/scan_silhouette.gd` und gezielte Nestlabels in
`world/resources/nests/wildlife_nest.gd`. Die Regression liegt im bereits registrierten
`scan_circle_test`; eigene Aufnahmehelfer erweitern vorhandene Szenarien.
Population/Streaming bleiben R32-02. Spieler, Progression, SaveService, Karte,
DisplaySettings, Katalog und gemeinsame Registry werden im Fachbranch nicht
geändert. Die vorhandenen Spieler-Getter sind Bestandteil des Fachtests.

## Prüfaufbau

Die native Bewegungsmatrix verwendet echte prozedurale Tierkörper, Animation,
Spieler, Kamera, Scanner und HUD in einer gekennzeichneten Freiraumfixture:
800×600/1280×720/1920×1080 × UI 100/125/150 % × Körper 0,65/1,35.
Je Kombination sind 30 Bewegungs-/Animationsschritte mit etwa 0,52–0,70
physischem Pixel Randüberlappung vorgesehen. Hinzu kommen konkurrierende Ziele,
Zielwechsel, kurzer Sichtverlust, volle/teilweise Verdeckung, unsichtbare fremde
Kapsel, Reichweite, FOV 42/88, Pause, vollständiger Artenscan, anderes Individuum
derselben bekannten Art und genau eine Belohnung.

Der Vergleich arbeitet in jeder Renderer-Umgebung zuerst auf der festen Basis
mit bytegleicher, eigens kopierter Instrumentierung und danach auf der Fachquelle.
Die vier bekannten negativen Sichtfälle werden streng als erwartete Negative
geprüft; Parser-/Leakfehler werden dadurch nicht akzeptiert. Die Basis-Laufzeit
wird nicht verändert. Native Originalbilder jeder 30. Matrixaufnahme behalten
ihre tatsächliche Auflösung; nur der Film hat einen festen 1920×1080-Canvas.

Der Nestpaarfilm zeigt zwei gleichzeitig geladene gleichartige Produktionsnester
mit verschiedenen IDs: beide vorher unbekannt, erster Scan, erster echter
Prozessneustart, Entladen/Neuerzeugen, aktualisierter gezielter Zähler, zweites
Nest weiterhin unbekannt ohne übertragenen Fortschritt, zweiter Scan und zweiter
Prozessneustart. Seine Werte 4/2/3 sind ausdrücklich eingespeiste Testwerte,
keine behauptete Population.

Echte Bewohner werden separat im vorhandenen `wildlife_colony_test` geprüft:
generierte Kolonie, grenzüberschreitend gespeicherter/ungeladener Bewohner,
Todesstatus, Save/Reload und frischer Prozess. Der native Kugelhelfer nutzt
öffentliche SessionFlow-Ladung, echte generierte Kolonien, normale Reichweite,
Weltverdeckung und gespeicherte Mitglieder. Er vergleicht den angezeigten Zähler
mit lebenden, nicht reservierten kanonischen Records, erfasst geladenen Anteil,
Karte vor/nach Entdeckung, Save/Fresh-process sowie vollständiges öffentliches
Entladen/Reload. Unterschiedliche generierte Arten werden als solche berichtet;
der Gleichartigkeits-/ID-Vergleich wird nicht daraus abgeleitet.

## Quellen und Ausführungen

Eingefrorene vollständige Scannermatrix: `f1e919c13f155a420f0338bbf41c070b3fdc66e7`,
Tree `ae7c5f189dfbc5f37c7a172b751364bbbc30fb25` (native TriangleMesh-BVH,
kein Occlusion-Querycache, passende Retikelpixel bei näherem Kontakt).
Die Matrix ist vollständig grün. Danach ergänzt ein eigenständiger gezielter
Native-Lauf die echte Rollenlabel-Korrektur; die Scanner-/Retikeldateien sind
bytegleich zur vollständig gerenderten Matrix, Nestlabel/Test/Helfer getrennt.
Die endgültige Lieferung ergänzt ausschließlich Originalbelege und Bericht.

Der additive, optionale Diagnoseworkflow liegt ausschließlich auf
`agent/r32-05-evidence-20261002`; er checkt den Fachkopf ausdrücklich aus und
verwendet voneinander unabhängige GitHub-Runner. [Aktueller Lauf](https://github.com/MajorDragonfly/voxelverse/actions/runs/36989818998).
`native-workflow-owner.patch` ist der gemeinsame CI-Anschluss an R32-01 und
lässt sich mit `git apply --check` prüfen. Er gehört nicht als direkte Änderung
an `.github` zum Fachbranch. Es ist kein Spieler-/Save-Produktpatch erforderlich.

Alle Aufnahmen verwenden isolierte Nutzerdaten und Godot 4.6.3. Ein Software-
Renderer ist kein Ziel-PC-GPU-/FPS-Beleg. Jede Aufnahme erfasst Befehl, Engine,
Renderer/Adapter, Start-/Endquellen, Log, Prozessstatus, Zeit und Bildzahl.
UI 150 % wird in der Fixture direkt gesetzt; die reguläre Einstellung benötigt
den DisplaySettings-Anschluss von R32-15/01.

## Erhaltene negative und frühere Nachweise

- `baseline-focused.json`: unveränderte Basis, Import/Quellen/Artquellen und
  vorhandene CreatureScan-/NestDiscovery-Tests positiv, Quellen wiederverwendbar.
- `first-fix-focused.json`: erster Kapsel-Fix, zwei Fachtests positiv, ausdrücklich
  nicht der endgültige Produktionsstand.
- `negative/foreign-capsule-before.log` und `hidden-nest-before.log`: tatsächlich
  ausgeführte ursprüngliche Fehler, nicht nur eine statische Vermutung.
- `negative/first-fix-functional-results.json` / `first-fix-dense-query.log`:
  projizierte erste Korrektur funktional positiv, aber dichter Fall erheblich
  negativ: kalte 12-Tier-Abfrage 791,461 ms, warm p50 940,445 / p95 1035,103 /
  Maximum 1182,773 ms. Der Stand wurde deshalb durch direkte lokale Mesh-Strahlen
  ersetzt. Die ursprünglichen Quellenhashes stehen in `first-fix-source-*.json`.
- `negative/engine-setup-failed.json`: fehlende ausführbare Enginekopie, keine
  bestandene Spielprüfung.
- `negative/import-uid-source-change.json`: Prozesse erfolgreich, aber während
  des importfreien Laufs entstanden UIDs; Gesamtnachweis daher nicht gültig.
- Mehrere Diagnosevorbereitungen wurden vor freien Runnern durch vervollständigte
  Prüfquellen ersetzt. Lauf 36974213967 wurde während Vorbereitung abgebrochen;
  sein Originalartefakt 11212549033 hat ZIP-SHA256
  `628fb1fb65a50f5741967126f60f0db012771656d86f1b0f1c3952c789c85dce`.
  Seine leeren/unvollständigen Aufnahmeordner belegen keine erfolgreichen Fälle.
  Der spätere Forward+-Versuch 36976434954 wird wegen fehlendem explizitem
  Fachressourcenimport ersetzt; daraus wird keine positive Freigabe abgeleitet.


## Vollständiger erster Native-Lauf: funktional positiv, Gesamtstatus negativ

Run [36977273789](https://github.com/MajorDragonfly/voxelverse/actions/runs/36977273789)
prüfte den früheren Kopf `97aac21e67875cb6454526aef48a83ea16012e4c` / Tree
`9f0b6990871d2e52ad5448255b4fa256cf2cb3d1` mit GDScript-Dreiecksstrahlen.
GL und echtes Vulkan Forward+ lieferten je 696 Frames für Basis/DE/EN-Bewegung,
176 Frames je DE/EN-Nestpaar, drei streng erwartete Basis-Sichtnegative und
fehlerfreie korrigierte Sichtfälle. Beide Paar-Neustarts Exit 0. Vier bestehende
Fachtests auf GL positiv. Alle abgeschlossenen SourceRuns stabil/reusable.

| Renderer | Basis dicht p50/p95 (ms) | Erste Ray-Korrektur p50/p95 (ms) | Kalte dichte Abfrage nachher (ms) |
|---|---:|---:|---:|
| GL | 34,849 / 36,173 | 238,586 / 787,451 | 685,122 |
| Forward+ | 35,046 / 36,319 | 235,376 / 788,576 | 664,370 |

Daher ausdrücklich keine Performancefreigabe dieses Zwischenstands. Die native
BVH ersetzt die GDScript-Dreieckstraversierung. Ihre Messung folgt unten;
der Funktionsfix allein erfüllt das Performancekriterium ausdrücklich nicht.

Die Kugel wurde in beiden Renderern regulär geladen, gescannt, gespeichert,
in einem frischen Prozess geprüft und öffentlich entladen/wieder geladen.
Die echten gezielten Zähler waren GL 3→3 und Forward+ 4→4, alle Mitglieder
kanonisch verifiziert. Gesamtstatus dennoch negativ: Der Helfer erwartete beim
allerersten Tick bereits einen Nestkontakt. Das Originalbild zeigt stattdessen
kein Ziel/kein Nestlabel, also kein nachgewiesenes Labelleck. Der korrigierte
Oracle prüft weiter jeden unbekannten sichtbaren Text und dessen Kopplung an
das tatsächliche Ziel; ein unbekannter gezielter Kontakt muss innerhalb der
begrenzten Aufnahme auftreten. Der erste korrigierte Lauf hatte 85 Schritte. Er protokolliert den ersten Tick und
Sichtverlust, statt die erste Blickphase mit bereits erfasstem Ziel gleichzusetzen.
Lade-/Prozessfristen, normaler Scanner, Population und Verdeckung bleiben erhalten.
Der finale Kampagnenhelfer erlaubt maximal 300 Schritte (zehn simulierte Sekunden)
bis zu einem wirklich abgeschlossenen, ununterbrochenen Scan. Echte Zielverluste
und Fortschrittsresets bleiben wirksam; Beobachtungen protokollieren die tatsächlich
benötigten Schritte und Verluste, statt nach 85 Schritten eine Entdeckung zu behaupten.

Originale unter `negative/gdscript-ray-{gl,forward}/`, einschließlich komprimierter
vollständiger Quellmanifeste und erster ungezielter Kugelbilder. ZIP-Digests:
GL Artefakt 11215090789 `15dc2ed798cf76f0c8e0c7a23b468539612ebb5eff12406be2b4345c8dab45bf`,
Forward+ Artefakt 11215380592 `0ed1f350a508dbb164e6b6c16cdf02b55e779933e2d7a9ee73f8b724d1249f69`.
174 bzw. 162 erhaltene Archiveinträge wurden vollständig hashgeprüft, ohne Abweichung.
Die gleichbleibende Basis wird auf den neuen Hosts nur für zeitlich gepaarte
Messwerte wiederholt. Die damaligen drei unveränderten negativen Sichtfälle bleiben aus
diesem Original; sie werden nicht durch nachträgliche Erfolgserwartungen ersetzt.
Der lokale Diagnoseversuch `flock -n` wurde abgewiesen (Exit 1, kein Godotstart).

## Verworfenes Cacheexperiment und verbleibende Kosten

Der erste native BVH-Stand `78619f042a3df2a4936bea652169bf0498cec31b` / Tree
`71796ff9a281dfa34e8457deb0f460021a3487d4` bestand den vollständigen nativen
[Run 36980248463](https://github.com/MajorDragonfly/voxelverse/actions/runs/36980248463):
beide Renderer, alle positiven Fälle, vier Fachtests, echte Kugelnester und
Fresh-process/Public reload. Echte Bewohner GL 3→3 / Forward+ 3→3.
Die nachfolgende Pixelkorrektur war hier noch nicht enthalten.

| Renderer | Basis dicht kalt / p50 / p95 / max (ms) | Native BVH dicht kalt / p50 / p95 / max (ms) |
|---|---:|---:|
| GL | 19,116 / 19,873 / 22,144 / 30,835 | 218,804 / 60,394 / 263,075 / 268,102 |
| Forward+ | 30,992 / 30,819 / 31,461 / 31,783 | 325,701 / 94,370 / 412,416 / 419,138 |

Ein Cache mit nächstem Mesh-Treffer innerhalb einer Query sollte wiederholte
Kontakte beschleunigen. Die notwendige Suche nach dem nächsten statt nur irgendeinem
Treffer machte ihn jedoch erheblich teurer. Auf `5340dd7e9c17b5c0cc37a35ac982aa973478488a`
/ Tree `796a251ae8ad73bc0b3c480275e3205469b05f5e` scheiterte
[Run 36983362849](https://github.com/MajorDragonfly/voxelverse/actions/runs/36983362849)
am Kampagnenhelfer nach Zielunterbrechungen (GL vier verlorene Schritte). Tier-
und Paarprüfungen sowie vier Fachtests bestanden, aber keine Gesamtfreigabe.
Nach nicht abgeschlossener Entdeckung sind die folgenden Save-/Reload-Negative
Folgefehler; sie belegen keinen unabhängig reproduzierten Produktions-Saveverlust.

| Renderer | Gepaarte Basis dicht kalt / p50 / p95 / max (ms) | Verworfenes Cacheexperiment dicht kalt / p50 / p95 / max (ms) |
|---|---:|---:|
| GL | 34,323 / 35,472 / 36,770 / 36,950 | 794,028 / 271,755 / 937,920 / 958,634 |
| Forward+ | 36,316 / 34,829 / 36,549 / 36,653 | 820,086 / 284,247 / 984,727 / 1001,232 |

Der Cache und seine Folgetests wurden vollständig zurückgenommen, einschließlich
einer erst lokal vorgenommenen Grenzkorrektur für identische geschlossene Strahlen.
Die Pixelkorrektur bleibt erhalten und wird final separat gegen die Basis geprüft.
Negative Originale unter `negative/rejected-cache-{gl,forward}/`; komplette
SourceRun-Manifeste komprimiert, erhaltene Archiveinträge unabhängig hashgeprüft
(GL174/F+162, null Abweichungen). ZIP-Digests: GL Artefakt11217216233
`2fd700c08f6334408732459b53630e90b6dc6e10cd21a96c420f571c78f64e73`, F+11217088187
`480efd5fd07c78b3da6279a11d47709969701fd1cf0af9a05112ff893ec43e88`.

Die originale BVH-Ausführung bleibt unter `negative/native-bvh-no-cache-{gl,forward}/`
erhalten. Ihr Gesamtstatus ist grün, die Kostenüberschreitung bleibt ein fachlicher
Negativbefund. Weder der funktionale Fix noch diese Softwaremessung erfüllen das
Issue-Kriterium „kein merklicher neuer Framezeitengpass“. Der Draft bleibt deshalb
auch fachlich wegen der dichten Abfragekosten offen; spätere Optimierung muss die
exakte sichtbare Geometrie, normale Reichweite und Verdeckung erhalten.

## Vollständige endgültige Scannermatrix

[Run 36989818998](https://github.com/MajorDragonfly/voxelverse/actions/runs/36989818998)
auf `f1e919c13f155a420f0338bbf41c070b3fdc66e7` / Tree
`ae7c5f189dfbc5f37c7a172b751364bbbc30fb25`: GL und Forward+ grün.
Vier Fachtests, Quellen/Import/Artquellen positiv. Beide Renderer reproduzieren
exakt die vier ursprünglichen Sichtnegative, nachher keine Sichtfehler.
DE/EN je696 Frames, beide Nestpaar-Neustarts Exit0, je76 echte Kugelscanschritte
mit einem Zielverlust, kanonisch3→3 Bewohner und Fresh-process/Public reload.
Die Karte bleibt auf eigene Heimat-/verbündete Orte beschränkt; vor und nach
Entdeckung keine fremden Nestnamen/Zähler/IDs.

| Renderer / Quelle | Dicht kalt ms | p50 ms | p95 ms | p99 / max ms | >100 ms von50 |
|---|---:|---:|---:|---:|---:|
| GL Basis | 35,739 | 34,921 | 36,373 | 36,847 | 0 |
| GL korrigierte Sicht | 377,719 | 112,254 | 472,278 | 479,270 | 36 |
| Forward+ Basis | 26,175 | 26,342 | 27,613 | 27,966 | 0 |
| Forward+ korrigierte Sicht | 283,853 | 82,827 | 354,903 | 365,721 | 6 |

Randfall: kalt GL29,733–65,477ms / F+21,234–45,827ms, schlechteste warme
p95 einer der18 Kombinationen GL1,449ms / F+1,057ms. Überlappung mindestens
0,5206604 physische Pixel. Pro Randfall30, dichter Fall50 Messungen. Ein kalter
Randquery verwendet jeweils ein neues Silhouette-Objekt einschließlich Geometrie-/
Instanz-BVH-Aufbau; dicht kalt umfasst alle12 Tiere. Diese Query-CPU-Werte
schließen PNG-Schreiben aus. p99 bei50 Werten entspricht hier dem Maximum.

Isolierte native Frameintervalle werden separat protokolliert (GL p50/p95
180,721/226,369→257,644/614,893ms, F+208,288/218,116→264,984/540,597ms).
Sie enthalten Software-Rendering und sind keine Gesamt-FPS oder Ziel-PC-Leistung.
Zwischen verschiedenen CI-Läufen wird kein Geschwindigkeitsgewinn behauptet.
Das Performancekriterium von #172 bleibt aufgrund dieser Verschlechterung offen.

Originale unter `native-{gl,forward}/`; `final-native-summary.json` bündelt
Messwerte, Schritte, Quellen und Archiveinträge. Start-/Endmanifeste vollständig
komprimiert erhalten; alle18 geänderten damaligen Runtime/Test/Helferdateien je
positivem Nativefall gegen den eingefrorenen Gitcommit byteweise überprüft.
Die Filme enthalten696 bzw.176 bzw.76 Frames, 30fps, fester1920×1080-Canvas;
`captured_frames:591` im geerbten Bewegungsbericht zählt nur die geteilten Fälle,
Wrapper und ffprobe zählen einschließlich neuer Artenprüfung korrekt696.
Original-PNGs bleiben800×600/1280×720/1920×1080, Kampagne tatsächlich1600×900.

ZIP-Digests: GL Artefakt11219906969
`9b51fb1d7250768914277113463361e779670ebfcb955646d0b07d271eb449b8`,
F+11219488950 `de25b2af5f1cb4aae9cdc383c294f9985e409c03787ed9b5508e0ceff74f4e7f`.
174/162 erhaltene Einträge hashgeprüft, null Abweichungen.

## Zusätzlich im echten Spiel belegter Nestlabel-Fehler

Der Matrixlauf zeigt nach Entdeckung tatsächlich `Nest: Nakasaur · Grazer · 3 Bewohner`
(GL) bzw. `Nest: Talotari · Predator · 3 Bewohner` (Forward+). Der vorhandene
Kolonienadapter erkannte nur Namen, die ausschließlich eine Rolle enthalten;
der Artennamengenerator hängt dieselbe Rolle jedoch auch an echte Artennamen an.
Diese Aufnahmen bleiben als ursprüngliche Negativbelege erhalten; der grüne
Matrix-Prozessstatus war keine Rollenlabel-Abnahme.

Die gezielte Nestpräsentation entfernt deshalb ausschließlich bekannte letzte
Rollensuffixe, behandelt alleinstehende Rollen als unbekannte Art und erhält
legitime zusammengesetzte Namen. Kolonie/Blueprint/Save werden nicht umgeschrieben.
Der registrierte Nesttest prüft neun Rollen, reine Rollennamen, legitimes
Mittelpunktszeichen sowie die Unveränderlichkeit der Quelldaten. Die native
Paarprobe verwendet nun ausdrücklich `Kieselrücken · Grazer` als Eingangswert;
sie erwartet gezielt `Kieselrücken`, prüft beide eigenständigen Entdeckungen,
aktuelle Zähler und beide echten Prozessneustarts. Keine zusätzliche Population.


Gezielter finaler [Run36991909239](https://github.com/MajorDragonfly/voxelverse/actions/runs/36991909239)
auf `7af1d96ca5d57caed8b27b85cefca243fd39f7b5` / Tree
`affe376cbc3a00de050bd43c59e10b2573506bf0` vollständig grün, beide Renderer:
vier Fachtests einschließlich erweiterter Rollenregression positiv; vor dem Fix
in der echten nativen Paarprobe genau drei erwartete Rollenlabel-Fehler, keine
weiteren Fehler/Parser/Leaks. Nachher DE/EN-Paare mit je176 Frames, beide
Fresh-process-Exits0; echte Kugel wieder76 Schritte/ein Zielverlust, GL3→3 bzw.
F+4→4 kanonische Bewohner, Fresh-process und öffentlicher Reload positiv.
Labels jetzt `Nest: Talovek · 3 Bewohner` bzw. `Nest: Orbidon · 4 Bewohner`.
Das zweite Nest bleibt unbekannt; weder Artenwissen noch erster Nestscan übertragen
Fortschritt oder Entdeckung. Weltkarte vor/nach wie zuvor ohne fremde Nestdaten.

Vorherquelle ist der unmittelbar vorher geprüfte Kopf `f1e919c...`, ausschließlich
der neue eigene Paaraufnahmehelfer wurde darübergelegt. Sein Start-/Endmanifest
meldet diesen festen Instrumentierungsanteil als tracked dirty; die ursprüngliche
Produktdatei ist separat gegen den alten Gitcommit hashgeprüft. Dies ist eine
belegte Vorherprobe mit dokumentiertem Overlay, kein behaupteter sauberer
Quellbaum. Alle positiven Läufe stammen dagegen vom sauberen eingefrorenen
Labelkopf; alle20 damaligen geänderten Runtime/Test/Helferdateien gegen Gitbytes
geprüft. Scanner/Retikel und Bewegungshelfer sind bytegleich zum Matrixkopf.
Die Matrix wird nach der isolierten Nesttextänderung nicht erneut als neue native
Ausführung ausgegeben. Die finalen vier Fachtests prüfen den gemeinsamen Stand.

Originale und Filme unter `labels-{gl,forward}/`; `final-label-summary.json`
fasst Identitäten/Zähler/Schritte/Quellen zusammen. 66/54 erhaltene Archiveinträge
hashgeprüft, null Abweichungen. GL Artefakt11220400715 ZIP-SHA256
`4b23850419de0f32d06c334d5c1506c6a587d5390e7074925b586208f09c54d1`,
F+11219938584 `4fd3cfb2e37db533eefbeec47ced38d065d59e1c4b97f7b2bf2c682788e29e5b`.
Source-/Archivmanifeste verlustfrei komprimiert, alle Rohlogs/JSON unverändert.

Zwei optionale R32-01-Rezepte: `native-workflow-owner.patch` reproduziert exakt
den Matrixkopf samt fester Ausgangsbasis; `native-label-workflow-owner.patch`
reproduziert den gezielten Rollenvergleich samt dokumentierter Instrumentierung.
Beide `git apply --check` positiv. Sie sind getrennte additive Workflows, keine
Änderungen bestehender CI-Dateien und keine bereits absolvierten Integrationsgates.
Spieler-/Save-/Populations-Produktanschlüsse sind nicht erforderlich; deren
Besitzerdateien bleiben bytegleich zur festen Ausgangsbasis.

Lesbare Kapitelbilder, Karte vor/nach, Nestpaar unbekannt/entdeckt und native
800×600 bis1080p-Randbilder wurden am Original geprüft. Die Filme sind feste
30fps-Aufnahmen von Testschritten, keine Aufnahme tatsächlich erzielter30fps.
Benachbarte nicht zum Scanner gehörende englische HUD-Texte enthalten weiterhin
deutsche Bestandteile; das ist keine vollständige HUD-Sprachabnahme dieses Pakets.

## Reproduktion und verbleibende Abnahme

Auf einem eigenen grafischen Rechner, mit isoliertem Ausgabeverzeichnis außerhalb
der Quelle:

```sh
python tools/validate_godot.py --godot GODOT --tests scan_circle_test creature_scan_test nest_discovery_test wildlife_colony_test --skip-main --output NEW_FOCUSED_DIR
python tools/review_r32_05_capture.py --godot GODOT --renderer gl_compatibility --case motion --language de --output NEW_NATIVE_DIR
```

Auf dem gemeinsamen Host muss der Aufrufer zuvor den in #137 vereinbarten
Heavy-Slot tatsächlich halten. Die CI-Läufe belegen keinen lokalen Lockbesitz.
Native Forward+-Vorbereitung braucht ihren eigenen Ressourcenimport. Weitere
Aufnahmefälle: `occlusion`, `nests`, `world`; DE/EN sind getrennte Runs.

Der konservative Änderungsplan wählt FULL 267/Main. Dies ist nur der Plan;
Gesamtintegration, Produktions-/Reisekette, vier Pflichtgates und native Exporte
gehören zu R32-01. Ziel-PC-Sichtbarkeit/Bedienung, spontane Kampagnenrandfälle,
echte GPU-/FPS-Kosten bleiben separat. #172/#173 und die #166-Checkbox werden
hier nicht geschlossen; der PR bleibt Draft ohne Auto-Merge.
