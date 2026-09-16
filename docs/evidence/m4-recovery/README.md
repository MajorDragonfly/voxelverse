# M4-RECOVERY: Fachnachweis

Godot 4.6.3, Linux, isolierte synthetische Benutzerdaten. Die geprüften lokalen
Quellcommits waren sauber; Zuordnung zu den veröffentlichten Commits über
identische Git-Trees in [source-mapping.json](source-mapping.json).

- [Vier Fachtests](suite/results.json): `player_recovery_test`,
  `player_recovery_world_test`, `creature_behavior_gameplay_test` und
  `spherical_creature_test`; außerdem Quellverträge und unveränderte Quellen.
- **Präzisierung des Welt-/Neustartnachweises:** Der allgemeine Runner meldete
  Exit-Code 0, doch das gespeicherte Log enthielt keine Abschlussmarkierung.
  Dieses einzelne Runner-Log wird daher nicht als vollständiger Nachweis genutzt.
  Ein gezielter Lauf mit vollständig aufgefangenem stdout/stderr prüfte am selben
  sauberen Quellcommit zusätzlich beide Abschlussmarkierungen ausdrücklich:
  [Ergebnis](restart/results.json), [vollständiges Protokoll](restart/world.log).
  Enthalten sind echte Kugelheimat, 220-m-Versetzung/Rebase, Pause, Bodenprüfung,
  erhaltene Heimat/Entwürfe/Fortschritt, absichtlicher Schreibfehler, anschließender
  erfolgreicher Save und Wiederaufnahme eines Null-Leben-Saves in frischem Prozess.
- [Letzter UI-Nachlauf](handoff/results.json): Nach dem kleinen Schutz gegen eine
  im Stammesmodus verbleibende Rückkehranzeige erneut echte Hindernisse, fehlender
  Boden, Pause/Laden/Abbau, Schutz und Angriff sowie DE/EN, 720p/1080p und
  100/150-%-Schrift geprüft. 32 UI-Zustände werden als Controls/layout geprüft.
  Die Rückkehr-/Kollisions-/Speicherlogik blieb seit der gemeinsamen Prüfung gleich.

Die im Neustartlog enthaltene Warnung für `blocked_recovery_save` ist der
absichtlich erzeugte Schreibfehler; der ursprüngliche Save bleibt bytegleich.
Kein unbekannter Fehler wurde ausgeblendet.

**Offen:** Eine echte Grafikaufnahme konnte hier nicht gestartet werden:
Xvfb konnte unter den Umgebungsbeschränkungen keinen lokalen Display-Socket
öffnen. Keine Screenshots oder visuelle Abnahme behauptet. Der mitgelieferte
`tools/review_player_recovery.py` ist für einen Host mit Display vorbereitet.
Native Windows-Abnahme, gemeinsamer Merge-Tree und Ziel-PC-Spieltest gehören
weiterhin zur Integration; keine FPS- oder Gesamtkampagnenfreigabe.
