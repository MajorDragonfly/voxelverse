# PT17-05 · Kameraführung an Voxelstufen

Integrationsbasis `acec60d` (19 veröffentlichte Fachlieferungen), lokaler Fachcommit `7f82e04`. Die früher gemeldete lokale Fachbranch war hier nicht verfügbar; dies ist eine neue Umsetzung auf dem gemeinsamen Preview. Refs #171, #199.

Die Spielfigur steigt mit unveränderter Kollision sofort auf die Stufe. Nur das Kameraziel nimmt die kurze Höhenkorrektur über die nächsten Bildframes auf. Sprünge, Fallen, Teleport/Platzieren und Recovery behalten keinen Stufenversatz. Die Korrektur ist auf die maximale Stufenhöhe begrenzt und zerfällt zeitbasiert, unabhängig von der Bildrate.

`tests/step_camera_test.gd` fährt einen realen 0,5-m-Absatz mit normaler und geneigter Aufwärtsrichtung. Godot 4.6.3, Linux/headless: Der Kollisionskörper bewegte sich in beiden Fällen maximal 0,580 m in einem Frame. Das Kameraziel erreichte vor der Korrektur 0,580 m/Frame, danach 0,098 beziehungsweise 0,082 m/Frame. In beiden Fällen wurde der Absatz auf dem Boden erreicht; nach 40 Frames war die Kameraposition wieder am Spieler. `radial_step_test` und `player_recovery_test` bestanden als direkte Verbraucher.

Der Bildvergleich derselben Treppe als Video, unterschiedliche reale Bildraten/Körpergrößen sowie der Ziel-PC-Spieltest stehen aus. Diese Messung ist keine grafische oder Ziel-PC-Abnahme.
