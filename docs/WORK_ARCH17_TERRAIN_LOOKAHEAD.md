# ARCH-17 – Bewegungsabsicht und gültige Terrainaufträge

Basis: veröffentlichtes `main` `bb2f83b56267964baa7037720c4daca26fe3d007` (PR #77).
Branch: `agent/arch17-terrain-lookahead-2026-09-10`.
Auftrag: begrenzte Fortsetzung von ARCH-17 / M1h; Terrainvorausschau, sichere
Bewegung und Untersuchung des dokumentierten ARCH-02-Rückwegstillstands.

## Vertrag und Änderungen

Der bestehende `AdaptiveSphereTiles` bleibt Besitzer eines vollständigen
Terrain-Covers pro Weltinstanz. `PlanetPatchJob` berechnet weiterhin ausschließlich
CPU-Daten. Szene, Mesh-Upload und Kollision bleiben auf dem Hauptthread.
Kampagnen-, Speicher-, Regions-, Arten- und Objektformate ändern sich nicht.
ARCH-06/07/13/14/22/24/25 werden nicht übernommen.

- Der gemeinsame Spieler berechnet die tatsächliche, kamerabezogene
  Bewegungsabsicht genau einmal. Ein kleiner Oberflächenanschluss erhält sie
  unmittelbar vor der Kollisionsfreigabe. Die Kugelspezialisierung verwendet
  diese Absicht auch bei Stillstand, Gegensteuern oder fehlendem Boden.
  `waiting_for_terrain` beschreibt nun dieselbe Prüfung wie die Bewegung.
- Kampagne und bestehender Labor-Walker verwenden denselben
  `set_motion_hint`-Anschluss. Der Vorlauf bleibt geschwindigkeitsabhängig:
  letzte Workerzeit + 0,25 s, begrenzt auf 0,75–2,5 s und 32 m.
  Das erhöht keine erlaubte Spielgeschwindigkeit. Erzwungene Platzierung
  setzt einen alten Vorlauf zurück.
- Eine Verschiebung des Beobachters oder Vorlaufs um 8 m merkt den neuesten
  Fokus auch während laufender Arbeit vor. Gleichgerichteter Fortschritt
  lässt noch nutzbare Arbeit fertig werden; Gegensteuern oder große
  Ortswechsel invalidieren deren Laufzeitgeneration. Jeder neue Auftrag
  erhält eine eigene Generation. Nur die jüngste Absicht bleibt vorgemerkt;
  es entsteht keine wachsende Queue.
- Jobtickets binden Ergebnis und unfertigen Cover an Generation und Weltkörper.
  A → B → A übernimmt keine alte A-Generation. Veraltete Auswahljobs starten
  keine zusätzlichen Meshbatches. Bereits laufende Worker werden erst nach
  ihrer Fertigmeldung eingesammelt, ohne im normalen Frame auf sie zu warten.
- Unfertige Veröffentlichungen bleiben unsichtbar und werden bei veralteter
  Generation samt ihren neuen Nodes verworfen. Der bisherige vollständige
  Cover und sein physischer Boden bleiben erhalten. Neu aufgebaut wird um
  die letzte vorgemerkte Position; der bestehende Feinheitscheck vor dem
  Austausch gilt weiter. Ursprungskorrektur invalidiert keinen körperfesten Ort.
- `streaming_diagnostics()` und die bestehende ARCH-02-Messroute melden
  Generationen, verworfene Jobs/Publikationen, Uploadbestand, Worker und Vorlauf.

Es bleibt bei einem Terrainjob mit höchstens vier Meshworkern, zwei Uploads
pro Frame, kooperativ 4 ms, 768 Blättern, 24 Kollisionen und 1.536 residenten
Terrainteilen. Erzwungener Weltaufbau und endgültiger Baumabbau dürfen weiterhin
synchron abschließen. Ein Weltenwechsel verwendet den vorhandenen Hostabbau;
dieser Auftrag führt keine Wiederverwendung eines konfigurierten Terrainhosts
für einen anderen Körper ein.

## Nachweise

`tests/terrain_lookahead_test.gd` lädt eine echte neue Kugelkampagne über
SessionFlow und verwendet deren tatsächlichen Spieler, Adapter, Terrain,
Worker, Meshes und Shapes. Der anschließende isolierte Lebenszyklusteil läuft
nahe einer Cube-Flächenkante auf einem Planeten mit 6.371 km Radius.

Geprüft werden Gegensteuern gegen die bisherige Geschwindigkeit, begrenzter
Vorlauf, Stillstand, Bewegungsstopp bei deaktiviertem realem Bodenshape und
Freigabe nach dessen Wiederherstellung. Hinzu kommen A → B → A vor dem
Einsammeln eines Workers, echte Baumpause, Abbruch nach dem ersten unsichtbaren
Upload, Ursprungskorrektur während des Aufbaus, erhaltene Bodenkollision über
die Veröffentlichung sowie Weltabbau mit ausstehendem Worker.

Der Test ist genau einmal im bestehenden Vertrag `surface` unter
`tools/validation/contracts.json` registriert. Der erste Testentwurf rief
`new_game` ohne vorheriges Titelmenü auf und wurde von SessionFlow korrekt
abgewiesen. Der abgeschlossene Test verwendet den regulären Menüweg.

Die abschließenden Ergebnisse und Quellenprüfsummen stehen in
`docs/evidence/arch17-terrain/results.json`. Headless-Nachweise sind keine
Grafik-, GPU-, FPS- oder Ziel-PC-Abnahme.

Implementierungscommit: `500d18b585b96c26414a11896e79ff6a577bc9b8`.
Die Fachtests liefen auf dessen noch nicht committeten Änderungen; die
abschließende Kampagnenroute protokolliert diesen Commit mit sauberem
Arbeitsverzeichnis. Anschließend wurden ausschließlich diese Übergabe und
Prüfnachweise ergänzt.

| Prüfung | Ergebnis |
|---|---|
| Quellen-/Testzuordnung | bestanden |
| Terrain-Lebenszyklus | bestanden, 34,071 s; 429 Blätter, 24 Kollisionen, Spitzenbestand 888; je ein veralteter Job und eine Teilpublikation verworfen |
| Großplaneten | bestanden, 48,306 s; Terra / 100-km- / 1.000-km-Körper mit 167,12 / 167,36 / 167,24 m Weg, jeweils zwei Flächen und vier Veröffentlichungen |
| Physische Nahtprüfungen auf diesen Körpern | 1.566 / 1.197 / 1.194 Strahlen; alle treffen den Boden |
| Gespeicherte Kampagnenroute auf finalem Code | bestanden; zwei Besuche mit 23,24 / 23,05 m Hinweg und 0,574 / 0,578 m Rückkehrabweichung innerhalb der unveränderten 0,65-m-Toleranz |
| Kreaturenablauf auf voriger Entwicklungsrevision | bestanden, 37,365 s; echter Scan, einmalige Belohnung, Editor-Rückkehr, Heimat und Wasser |

Der Großplanetentest erkannte während der Entwicklung außerdem zu häufige
Invalidierung bei normalem Vorwärtsgehen: Der Boden blieb erhalten, aber Terra
erreichte nur zwei Veröffentlichungen und verfehlte die bestehende Grenze von
mindestens drei. Die letzte Korrektur lässt gleichgerichtete Arbeit fertig
werden. Danach bestanden der unveränderte Großplanetentest, der Terrainfachtest
und die Kampagnenroute auf dem finalen Code. Der frühere Kreaturenlauf wird
ausdrücklich nicht als erneuter Lauf dieser letzten Revision ausgegeben.

Die kurze Kampagnenroute startet einen neuen Prozess aus dem bereits vorhandenen
Referenzspielstand, geht tatsächlich zurück und lädt denselben Slot für einen
zweiten Besuch erneut. Der Menüwechsel beendet auch einen noch ausstehenden
Terrainworker. Sie ist weiterhin kein zehnminütiger Routenbeleg. Alle Läufe:
Linux, Godot 4.6.3, AMD EPYC 9V74, Headless, gemeinsame Entwicklungsmaschine.

## Reproduzierter Rückwegstillstand

Der unveränderte gemeinsame Stand wurde mit dem bereits archivierten
`docs/evidence/arch02/blocked-route-replay.zip` wiederholt: 30 Sekunden Hinweg,
45 Sekunden Stufenfrist und bestehende Rückwegfrist von 105 Sekunden.
Der Hinweg erreichte 117,01 m. Der Rückweg blieb erneut stehen.

Diesmal benennt die bestehende Kollisionsdiagnose den tatsächlichen
Terrainteiler `Patch_0_19_262148_31458` als Kollisionspartner. Die Figur lebt,
steht auf dem Boden, wartet nicht auf Terrain; Worker und Uploadqueue sind
leer. Der nächste aufgezeichnete Zielpunkt liegt rund 0,96 m über der
aktuellen Adresse, während die automatische Schrittgrenze 0,58 m beträgt.
Das belegt den physischen Blocker und passt zu einer zu hohen Rückwegkante;
die Höhendifferenz der Adressen ist keine separate Vermessung der ganzen Wand.

Die automatische Messroute kann ausschließlich gehen. Sie plant weder Sprünge
noch Umwege. Ihr Fehlschlag bleibt als solcher erhalten; weder Teleportation,
eine erhöhte Schrittgrenze noch ein geänderter Spielstand kaschieren ihn.
Für die lange Abnahme braucht ARCH-02 eine körperlich begehbare Rückroute oder
eine ausdrücklich protokollierte Bedienfolge mit normalen Sprung-/Umwegeingaben.

## Integration und offene Grenzen

Geliefert wird dieses Terrain-Teilpaket auf einem eigenen Branch. Der
`main`-Merge und Lars' Spieltest sind separate Schritte. Beim Zusammenführen
den kleinen Bewegungsanschluss in `player_controller.gd` mit etwaigen
Sprachänderungen aus ARCH-25 erhalten und den neuen Testeintrag vereinigen.

ARCH-17 bleibt insgesamt offen: kalte Einzeluploads, stufenweiser individueller
Kreaturenmeshaufbau, weitere synchrone Habitat-/Kollisionsarbeit und die lange
Ziel-PC-Route sind nicht durch diesen Teilabschluss abgenommen. Die bestehenden
Bewegungs- und Objektgrenzen bleiben unverändert. Die Rückwegdiagnose ersetzt
keinen erfolgreichen zehnminütigen Rundlauf.

## Wiederholen

```sh
python tools/validate_godot.py --godot /pfad/zu/godot --skip-import --skip-main --tests terrain_lookahead_test spherical_creature_test large_planet_runtime_test
python tools/profile_performance.py --godot /pfad/zu/godot --replay /pfad/zum/entpackten/verified-route-replay --walk-seconds 6 --stage-timeout 45 --output /neuer/ausgabeordner
```
