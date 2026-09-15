# ARCH-17-PUBLISH – begrenzte Terrainpublikation

Teilauftrag vom 15.09.2026; Basis `d378ca0ecd7f03429a5150df6358e0646ec06689`
(nach PR #92), Branch `agent/arch-17-publish-2026-09-15`.
Schreibbereich: Terrain. ARCH-13 und ARCH-24 bleiben bei ihren Besitzern.

## Lieferung

Der bestehende Streamer bereitet Landmesh, Wassermesh, Szenenknoten,
Kollisionsform und physikalischen Körper in getrennten Schritten vor.
Pro Frame bleiben höchstens zwei Vorbereitungsschritte und kooperativ 4 ms.
Ein einzelner Engineaufruf ist nicht unterbrechbar; dies ist keine harte
4-ms-Garantie für den gesamten Frame oder die vollständige Übergabe.

Die CPU-Dreiecke für Kollisionen entstehen im vorhandenen Meshworker. Die
bisherigen Nahtüberlappungen bleiben geometrisch erhalten. Renderpuffer werden
dafür nicht mehr auf dem Hauptthread ausgelesen. Meshes, Shapes und Nodes
entstehen weiterhin ausschließlich auf dem Hauptthread.

Kollisionskörper werden schrittweise mit Layer und Maske 0 registriert.
Erst der vollständige Terraincover aktiviert sie. Bei Bewegung während des
Aufbaus wird die tatsächlich benötigte Nachbarschaft vor der Übergabe erneut
vorbereitet. Auch ein Nachbarschaftswechsel im bestehenden Cover verwendet
das gemeinsame Budget; der bisherige physische Boden bleibt bis dahin erhalten.

Unveränderte Grenzen: ein Terrainjob, höchstens vier Meshworker, 768 Blätter,
24 aktive Bodenkollisionen, 256 Cacheeinträge und 1.536 residente Terrainteile.
Zusätzlich sind maximal 24 inaktive Körper je vorbereiteter Nachbarschaft
möglich: aktuelle Blätter und künftiger Cover. Sie tragen keine aktive
Kollisionsschicht. Die aktuelle Kollisionsqueue enthält höchstens 24 IDs;
es gibt weiterhin nur einen vorgemerkten Terrainfokus.
CPU-Kollisionsdaten bleiben mit ihren begrenzt residenten Meshes erhalten,
bis eine Shape sie übernimmt; Cache und Abbruch räumen sie mit auf.

Kalte erzwungene Platzierung und endgültiger Weltabbau dürfen weiterhin
synchron abschließen. Bestehende Generationstickets, Pause, Ursprungskorrektur
und die Prüfung des tatsächlichen Bodens bleiben erhalten.

## Fachnachweise

Die bestehenden Tests `terrain_lookahead_test`, `adaptive_planet_test` und
`large_planet_runtime_test` bestehen auf dem Implementierungsstand aus
`evidence/arch17-publication/results.json`. Der Lebenszyklustest prüft jetzt
auch einen bereits registrierten, inaktiven Kollisionskörper: Boden bleibt
erhalten, Ursprungskorrektur stimmt, Abbruch entfernt Node und Körper vollständig.
Die Großplanetentests gehen auf drei Körpergrößen jeweils über 167 m und eine
Cube-Flächenkante; alle Bodenstrahlen treffen. Keine zweite Testregistrierung.

Die vorhandene Messroute erhält den Aufruf
`--script res://tools/benchmark_surface_publication.gd -- --terrain`.
Sie verwendet echte Revision-4-Terrainworker, Meshes, Bodies, kalten Aufbau,
Richtungswechsel, Teilabbruch und Abbau. Der Vorlauf ist für den Vergleich
auf dieselben 32 m festgelegt. Derselbe unveränderte Messcode läuft auf Basis
und Kandidat, in getrennten Prozessen mit isolierten Benutzerdaten.

Rohmessungen, Befehle, Quellstände und gezielte Prüflogs stehen in
`evidence/arch17-publication/`. Die ersten Diagnosemessungen mit zeitabhängigem
Vorlauf werden nicht als endgültiger Vorher-nachher-Vergleich verwendet.

| Identische CPU-Messroute | Basis | Kandidat |
|---|---:|---:|
| Größter Upload-/Vorbereitungsblock | 19,589 ms | 2,933 ms |
| Größte vollständige Übergabe | 11,141 ms | 4,676 ms |
| Größter Terrain-Prozessschritt insgesamt | 19,622 ms | 10,575 ms |
| 95. Perzentil der Terrain-Prozessschritte | 0,821 ms | 0,766 ms |
| Kalter schrittweiser Aufbau, Wandzeit | 10,928 s | 14,927 s |
| Residente Terrainteile, Spitze | 651 | 651 |
| Vorbereitungsqueue, Spitze | 412 | 414 |
| Aktive Bodenkollisionen nach Abschluss | 24 | 24 |

Die Uploadqueue zählt im Kandidaten auch wiederverwendete Blätter, die noch
physikalisch vorbereitet werden müssen. Die höhere Kaltaufbauzeit wird bewusst
mit ausgewiesen; der reguläre erzwungene Erstaufbau ist ein anderer Ablauf.
Auf den drei Großplaneten bestanden 2.020 / 1.419 / 1.570 tatsächliche Bodenstrahlen.

## Grenzen und Integration

Die Messungen stammen von Linux, Godot 4.6.3, AMD EPYC 9V74, Headless auf einer
geteilten Entwicklungsmaschine. Einzelmessungen sind kein statistischer
Leistungsnachweis. Feinere Schritte können mehr Frames bis zur Fertigstellung
benötigen. Vollständiger Coverwechsel, Materialübergang, Abbau und einzelne
Engineaufrufe bleiben mögliche Spitzen.

Kein Windows-Export, GPU-/FPS-Nachweis oder Ziel-PC-Spieltest ist Bestandteil
dieser Fachabnahme. ARCH-17 insgesamt bleibt offen. Die Integration übernimmt
den PR, prüft den gemeinsamen Merge-Tree und führt die Abnahme auf Lars' PC aus.
Zentrale Statusdateien und die laufenden Pakete anderer Chats werden hier
nicht zusätzlich umgeschrieben.
