# R32-11 / PT17-09 · Befreunden · #175

Zwei belegte Verhaltensfehler sind korrigiert: Laden, Neustart und Actor-Respawn
konnten die Reaktionspause umgehen; Nahrung teilen konnte bei Simulationstempo 0
Sättigung und Gesundheit verändern. Die drei vorhandenen Begegnungsschritte,
Temperamente, Vertrauensstufen 35/70/100 und begrenzten Belohnungen bleiben erhalten.

## Quelle und Zuständigkeit

- Feste Basis: `2a738a4891a8de11d682c469833ade4dc9b01dfb`, Tree
  `f2bda4f815df1c73b9d740ca5282917523faf618`.
- Geprüfter Produktions-/Reviewkopf: `85666bc9a46a646ab20ddb2caadb1d07a00db996`,
  Tree `83efbd6a22b3eb52ecf607348eef0d9ba0804dba`.
- Isolierter QA-Kopf einschließlich genau der beiden zentralen Testanschlüsse:
  `836c9801cc35571648278ad54173cbcf6b065bfb`, Tree
  `34be1c2893b650cbd3714d7dee3c20ce3fd4f6fd`.
- Nach diesen Läufen kommen ausschließlich diese Belegdateien hinzu. Der finale
  Lieferkopf/Tree steht im PR; Produktions-, Test- und Reviewquellen sind bytegleich.
- Produktion nur `creature_social_component.gd` und `creature_encounters.gd`.
  PlayerBehaviorController, HUD, SaveGameService, Population, Zeichen und Posen
  bleiben unverändert. R32-10/12 behalten ihre Dateien.

Die optionale `social_response_until_ms` liegt im vorhandenen Encounter-Datensatz.
Sie benutzt die persistierte Kampagnenzeit und ganzzahlige Millisekunden; Aufrunden
verlängert höchstens um 1 ms. Kein Wall-Clock-/Offlinefortschritt, keine zweite
Vertrauensverwaltung und keine Encounter-Schreibvorgänge pro Frame. Ablehnungen
bewahren ebenfalls ihre Ruhefrist; Freundschaft und Angriff entfernen die dann
unnötige Frist. Alte Einträge ohne das Feld bleiben gültig. Der Validator akzeptiert
nur endliche nichtnegative sichere JSON-Ganzzahlen; Actor-/Archivleser normalisieren
deren numerischen Typ. Die gemeinsame Erreichbarkeitsprüfung blockiert bei Tempo 0
auch das Helfen. Fehlgeschlagene Abschlüsse rollen Frist, Vertrauen und Punkte zurück.

## Reproduzierte Negative

[Baseline-Probe](baseline-response-pause.log): echter Player/Social/Save-Pfad an
der festen Basis, ergänzt ausschließlich um die eigene Prüfdatei. Der neue Prozess
und das Laden verlieren die 1,85-s-Reaktion, der nächste Schritt wird sofort angenommen,
und Actor-Respawn verliert die Frist erneut. Helfen bei Tempo 0 reduziert Sättigung
100→88 und erhöht Gesundheit 18,7199→28,9307.

Die erste Float-Frist scheiterte einmal im bestehenden **exakten** Streamingvergleich;
der negative Originallauf bleibt in `focused-originals.zip` unter `focused/` erhalten.
Ein anschließender Diagnoselauf war positiv. Der isolierte tatsächliche JSON-Leser
reproduziert [1430/10000 letzte-Bit-Abweichungen](precision.log) bei Float-Fristen
([unveränderte Diagnosequelle](precision.gd.txt)). Daraufhin wurde nur die neue
Frist auf Ganzzahl-Millisekunden umgestellt. Kein allgemeiner JSON-/Savefix und keine
abgeschwächte Vergleichsassertion. Der finale Streamingtest und der neue exakte
Encounter-JSON-Roundtrip bestehen.

## Fach- und Verbraucherprüfungen

Godot `4.6.3.stable.official.7d41c59c4`, Linux x86_64, Host `db514e109ac6`,
AMD EPYC 9V74 / neun sichtbare vCPUs. Isolierte Runner-Nutzerdaten; sechs tatsächliche
Tests, Import, Quell-/Katalog-/Artvertrag und SourceIntegrity bestanden.

| Tatsächlich ausgeführter Test | Ergebnis / Umfang |
|---|---|
| `r32_11_friendship_test` | 201 Kontrollen; separat vier im echten Neustartkind |
| `creature_behavior_gameplay_test` | Befreunden/Hilfe/Kampf, atomarer Rollback, echte Streamer-ID, Neustart, Phasen-/Zukunftsschutz |
| `wildlife_social_play_test` | Reale Paarbildung, drittes Tier, Sichtblockade, Bedürfnisse/Gefahr, Pause, Unload/Load/Neustart, endliche Kandidatenarbeit |
| `creature_expression_test` | Direkter Ausdrucksverbraucher einschließlich gespeicherter Sozialbeziehung |
| `encounter_archive_test` | Kanonisches Encounter-Archiv und Persistenz |
| `behavior_progression_test` | Begrenzte Sozialbelohnung und Fortschrittsverbraucher |

`focused-originals.zip` enthält vollständige ursprüngliche Logs, Ergebnisse und
Source-Start/End-Manifeste: `baseline-tests/`, negativer `focused/`, positiver
`focused-final/` und separater Diagnoselauf. [Quell- und Ergebnisdaten](verification.json).

Der neue Test umfasst drei Temperamente, Erfolg, Ablehnung, Ruhe/Retry, echtes
externes Schadensereignis, feindliche Rolle, zwei nahe IDs/Zielwechsel, 16 schnelle
Wiederholungen je Schritt, genau eine Beziehung/Belohnung, Entfernung, beide Pausearten,
Laden/Respawn/frischen Prozess, Fristablauf, alte/ungültige Metadaten und echte I/O-Fehler.
Die isolierten Actor-Fälle frieren Bewegung ein bzw. schreiten explizit die Simulation
fort; die untenstehenden lebenden Videos prüfen zusätzlich die natürliche KI-Reaktion.

Reproduktion mit den ausdrücklich gelieferten zentralen Testanschlüssen:

```sh
python3 tools/review_r32_11_friendship.py \
  --checkout /tmp/r32-11-qa --output /tmp/r32-11-checks --godot /path/to/godot
```

Der Helfer verlangt einen sauberen Quellcheckout, wendet Anhänge ausschließlich in
einer eigenen Kopie an und benutzt den vorhandenen strengen Runner. Keine Vollsuite.
Auf dem gemeinsamen Work-Host den vollständigen Aufruf mit dessen gemeinsamer
`/tmp/voxelverse-r32-db514e109ac6-heavy.lock` serialisieren.

## Gerenderte Begegnungen

[Compatibility-Video](encounters-gl.mp4) und [Forward+-Video](encounters-forward.mp4):
je **635 native gerenderte Frames**, 32 protokollierte Sozialaktionen, keine Assertions-,
Runtime- oder Shutdown-Leakfehler. Gleiche Seed-/Körper-/Kamera-/Lichtbedingungen und
Aktionsfolge. Beide sind ausdrücklich **Live-Produktions-KI in einer Kollisionsfixture**,
keine reguläre Kugelkampagnenansicht. Der Beobachterspieler ist eine Reviewfigur;
die drei Tierformen verwenden den bestehenden Produktions-/Posepfad.

| Videoposition bei 15 Capture-FPS | Reproduzierter Ablauf |
|---|---|
| 0–20,8 s | Drei Temperamente; 35→70→100, Pause, erneuter Versuch am bereits befreundeten Tier ohne Gewinn |
| 20,8–28,1 s | Vorsichtiges Tier; unpassende Spielgeste, wirkliche Flucht/Beruhigung, erfolgreicher ruhiger Retry |
| 28,1–36,3 s | Wirklicher Fremdangriff; Unterbrechung, normale Bedrohungszeit, Wiederaufnahme ohne Vertrauensverlust |
| 36,3–38,7 s | Zwei nahe Tier-IDs; jeweils nur das angesprochene Tier erhält 35 Vertrauen |
| 38,7–41,1 s | Feindliche Rolle weist Befreunden ab; Vertrauen bleibt 0 |
| 41,1–42,3 s | Wirkliches Save/Load bewahrt laufende Reaktion; sofortiger zweiter Schritt abgewiesen |

Die GUI-/Diagnosebeschriftung gehört ausschließlich zur Probe. Produktlabels wurden
nicht ergänzt. [GL-Aktionen/Framebelege](gl-metrics.json), [Forward+-Aktionen](forward-metrics.json).
Aufnahmen: 960×540, DE, Scale 100 %, feste 15 Capture-FPS, Seed 15838; vorhandene
Shapes/Skalen 0,65/1/1,45. Orthokamera 7 m (zwei Tiere 9 m), Zieloffset (4,3;3,5;7,2),
Fixture-Sonne (-55°,-35°), Ambiente 0,7; Bodenhöhe 100 m, geladenes reales Fixture-Collider.
Die native KI-Fristen werden nicht für Beruhigung zurückgesetzt.

[Regulärer Tastatur-/HUD-Pfad](physical-input-gl.mp4): bestehender
`review_behavior_gameplay.gd`, regulärer PlayerController/BehaviorController/HUD
in dessen gekennzeichneter flacher Fixture, 1600×900, 216 Frames / 14,4 s. Körperliches
F/H/K/Shift+F, gehaltenes F (bleibt bei 35), Pause/Fortsetzen, Ablehnung, verdiente
Skillpunkte und Phasenvorschau bestehen mit `BEHAVIOR_GUI_OK` im [Original](input-render.log).

Reproduzieren mit funktionierender nativer Anzeige und separatem Ausgabeverzeichnis:

```sh
godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --fixed-fps 15 --script res://tools/review_r32_11_encounters.gd \
  -- /tmp/r32-11-native encounters
```

Für Forward+ dieselbe Quelle und `--rendering-method forward_plus` verwenden.
Alle drei nativen Abschnitte hielten die gemeinsame flock-Sperre über den vollständigen
Lauf. Mesa/llvmpipe: GL 45,21 s, Forward+ 72,41 s, Input 20,47 s **Laufprovenienz**.
Diese festen Capture-FPS, Readback-/Encoding- und Softwarezeiten sind keine
Spiel-FPS-/Ziel-PC- oder isolierte Kostenabnahme. Die frühen Headless-Zeitwerte enthalten
mögliche Fremdlast; der versehentlich ungesperrte letzte fokussierte Lauf ist in #137
gemeldet. Keine kontrollierte Vorher/Nachher-Leistungsbehauptung.

## Zentrale Anschlüsse und verbleibende Abnahme

R32-01 übernimmt einmal [registry.append.json](registry.append.json) in den Vertrag
`wildlife` sowie [gameplay-test-owner.patch](gameplay-test-owner.patch). Letzterer lässt
im vorhandenen simulierten Beruhigungsfall auch die jetzt persistierte Ablehnungsruhe
ablaufen; sämtliche bisherigen Assertions bleiben bestehen. Die Fachdateien dieser
gemeinsamen Anschlüsse sind im Branch unangetastet. Kein Produktions-HUD-/Savepatch nötig.

Die konservative QA-Planung fordert 268/268 plus Main/Runtime; Vollsuite, gemeinsame
Produktions-/Reisekette, vier Pflichtgates und native Exporte bleiben R32-01. Der reine
Fachbranch hat den neuen Test bewusst noch nicht zentral registriert; dessen Plan/CI
kann bis Anwendung des Registry-Anhangs `Unregistered test` melden. Das ist keine
behauptete Merge-Freigabe.

**Offen:** regulärer kombinierter Kugel-Spielweg auf dem finalen R32-Merge-Tree mit
R32-10/12, Verständlichkeit und Balance auf Lars' PC sowie Ziel-PC-Leistung. #175 und
die Checkbox in #166 bleiben offen. Draft nicht automatisch mergen.

Artefakt-SHA256: [media.json](media.json). Die finalen PR-IDs ersetzen keine der
ausdrücklich getrennten Quell-/QA-/Fixture-/Ziel-PC-Angaben.
