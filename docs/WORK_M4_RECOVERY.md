# M4-RECOVERY — Tod und sichere Rückkehr

Basis: `d57b1ef385728728b132518a1ea05683888dcae0` aus Spieltest-PR #125.
Eigenständige Lieferung auf `agent/m4-recovery-20260916`.

## Verhalten

- Tod beendet Scan und Bewegung. Ein pro Spielzeit fortgeschriebener Countdown
  ersetzt den bisherigen, auch in Pause laufenden SceneTree-Timer. Pause, Laden
  und deaktivierte Spielersteuerung verbrauchen weder Countdown noch Schutzzeit.
- Die Kugelkampagne verwendet die gespeicherte Heimatadresse des aktuellen
  Körpers, vor einer Heimatgründung dessen Startort. Nach Rebase werden normal
  budgetierte Terrainaufträge angefordert; keine synchrone vollständige Neubildung.
- Höchstens drei Kandidaten je Frame prüfen tatsächlichen Boden, Neigung,
  Trockenheit und Platz für den echten Spielerkollider. 25 Positionen bis sechs
  Meter um die Heimat stehen zur Verfügung. Bei vollständig blockierter Heimat
  wird der bestehende Startort geprüft. Bleibt auch dieser blockiert, wartet die
  Kreatur tot und versucht es erneut; Escape bleibt erreichbar.
- Erst nach Kollisionsbereitschaft und erfolgreicher Platzprüfung werden Leben,
  Nahrung, Wasser und Ausdauer aufgefüllt. Radiale Orientierung und
  Animationshistorie folgen der tatsächlichen Versetzung.
- Fünf aktive Spielsekunden schützen vor erneutem Schaden. Ein erfolgreicher
  eigener Biss beendet diesen Schutz. Entdeckungen, Punkte, Entwurf und
  Gefährtenidentitäten werden durch die Rückkehr nicht verändert.
- DE/EN-Anzeige für Countdown, Vorbereitung, blockierten Ort und Schutz;
  vorhandene Schriftgröße 100–150 %. Menüs behalten die Eingabehoheit.

## Speicher- und Lebenszyklusvertrag

Es gibt keinen neuen Speicherbesitzer und kein zusätzliches Save-Schema.
`player.health_ratio == 0` ist bereits Teil des gemeinsamen, validierten
Snapshots und bedeutet beim Laden jetzt eine ausstehende Rückkehr. Auch ältere
Null-Leben-Stände werden so übernommen. Import verwirft den bisherigen
Laufzeitversuch; ein gesunder geladener Spieler kann nicht später durch einen
alten Timer versetzt werden. Szenenabbau entfernt den Versuch vollständig.

Die erfolgreiche Rückkehr merkt den vorhandenen Autosave vor. Erst dessen
Erfolg ist ein dauerhafter Abschluss. Bei einem Schreibfehler bleibt der vorige
Spielstand lesbar; ein dort gespeicherter Tod wird beim nächsten Laden wieder
sicher fortgesetzt. Schutzzeit ist bewusst nur vorübergehender Laufzeitzustand
und wird weder bei einer Pause verbraucht noch nach einem gesunden Save neu
gewährt. Ein erneutes Laden erzeugt keine Punkte oder Belohnungen.

## Zuständigkeit und Prüfung

Schreibbereich: Spieler-/Rückkehrablauf, kleiner F2-Todschutz, eigene HUD-Datei,
acht neue Katalogschlüssel, zwei unter `spherical_gameplay` registrierte Tests
und zugehöriger Grafikrunner. Zentrale Status-/Roadmapdateien bleiben bei der
Integration. Kein Eingriff in Tier-KI, Körperteile, Terrainaufbau, Schiffe oder
Siedlungswirtschaft.

```sh
python3 tools/validate_godot.py --godot GODOT --skip-main \
  --tests player_recovery_test player_recovery_world_test \
  creature_behavior_gameplay_test spherical_creature_test
xvfb-run -a python3 tools/review_player_recovery.py --godot GODOT --output OUT
```

`--skip-import` nur bei bereits importiertem Ressourcenstand verwenden.
Prüfnachweise, Quellstand und genaue Grenzen werden in der PR-Übergabe erfasst.
Die Fachprüfung ist keine Gesamtspiel-, Windows-Export- oder Ziel-PC-Freigabe.
