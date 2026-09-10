# Kreaturenanimation: flüssige Übergänge

Arbeitszweig `agent/creature-animation-fluidity`, Ausgangspunkt `main`
`ca02572c199b1fe4b70174ac027359eaf2c588da` vom 9. September 2026.
Eigenes abgeschlossenes Animationspaket zur Integration. Andere Fachzweige
wurden nicht übernommen. Die gemeinsame Designvorgabe bleibt maßgeblich;
Voxelgeometrie und Körperteilkennungen bleiben erhalten.

## Behobene Ursachen

- `set_motion()` baute beim Wechsel von Stehen, Gehen und Rennen die Bindung
  erneut auf und setzte die Zeit auf null. Die Live-Vorschau behält jetzt Rig,
  Uhr und Schrittphase. Tempo und Bewegungsstärke werden weich eingeblendet.
- Beim Spieler wurden nicht ganzzahlige Sinusschwingungen aus einer bei TAU
  zurückgesetzten Schrittphase berechnet. Kopf, Schwanz und Atmung haben jetzt
  eine unabhängige Uhr; ihre Pose springt nicht mehr am Zyklusende zurück.
- Die Gangparameter wechselten bei 75 % Geschwindigkeit schlagartig. Standzeit,
  Schrittlänge und Hub werden jetzt kontinuierlich zwischen Gehen und Rennen
  gemischt. Das Körperwippen hat keine scharfen Spitzen mehr.
- Fußkurven haben eine gemeinsame Geschwindigkeit vor und nach dem Kontakt;
  der vertikale Hub beginnt und endet mit Geschwindigkeit null. Der Spieler
  löst den Fuß vom tatsächlich gespeicherten Kontakt und gleicht die Abweichung
  während der Schwungphase aus. Überdehnte Kontakte werden weich nachgeführt.
- Körperneigung folgt der lokalen Bewegungsrichtung und dem radialen Oben der
  Kugelkampagne. Richtungswechsel und Bodennachführung verwenden zeitbasierte
  exponentielle Dämpfung.
- Wildtiere und gezähmte Kampagnentiere liefern ihr tatsächliches Bewegungstempo
  an denselben Vorschauanimator. Ein blockiertes Tier läuft dadurch nicht mit
  voller Schrittstärke auf der Stelle weiter.

## Anschlussregeln

`set_motion("idle" | "walk" | "run")` ist ein Zustandswechsel, kein Neustart.
Wiederholte identische Anforderungen verändern weder Pose noch Uhr.
`set_motion("edit")` beendet die Animation und stellt die Autorenpose wieder her.
Ein neu aufgebauter Körper bindet sein Rig weiterhin über `rebuild()` neu.
Manuell ergänzte Prüfknoten müssen vor der Bindung eingefügt werden; deshalb
kehrt die bestehende dynamische Sattel-Testfigur vor dem Einfügen ihrer
Kollisionsprobe ausdrücklich in den Editiermodus zurück.

`set_locomotion_speed(speed, reference_speed)` ist ein optionaler visueller
Eingang für Laufzeitakteure. Die normalen Vorschau-Modi funktionieren ohne ihn.
Speicherung, KI-Befehle, Artenwerte und Simulationsgeschwindigkeiten ändern sich
nicht. Heimatgefährten und Stammesbewohner verwenden weiterhin den gemeinsamen
adaptiven Spieleranimator.

`Motion.sample(mode, time)` bleibt eine deterministische Einzelpose für
Passprüfung und Messparcours. `Motion.advance(...)` spielt die Live-Übergänge ab.
Die Editorparcours für Steigungen/Stufen behalten ihre reproduzierbare Route
und ihren ausdrücklichen Neustart; Pause und „Neu starten“ bleiben bedienbar.
Der lokale Ursprung verschiebt gespeicherte Weltkontakte einmal; der relative
Abstand während der Fußablösung benötigt keine zusätzliche Verschiebung.

## Prüfung

Godot 4.6.3, isolierte Spielstände. Elf relevante Laufzeitprüfungen bestanden:
`creature_animation_continuity_test`, `creature_studio_test`,
`creature_joint_studio_test`, `creature_parts_studio_test`,
`creature_body_contract_test`, `creature_body_fit_test`,
`creature_seat_fit_test`, `spherical_creature_test`,
`creature_behavior_gameplay_test`, `domestication_campaign_test`,
`home_group_world_test`. Projektimport und Art-Quellenprüfung ebenfalls bestanden.

Die neue Kontinuitätsprüfung misst reale Gelenk-/Fußpositionen bei zwei, vier
und sechs Beinen sowie 30/60/144 Hz. Zustandsanforderungen verursachen keine
sofortige Positionsänderung. Zusätzlich werden Kontaktgeschwindigkeiten,
Stillstand, unveränderte Baupläne, eine gedrehte Physikfläche und ein
Ursprungswechsel während der Bewegung geprüft. Messwerte und Ergebnisse:
[creature-animation-continuity.json](../validation/creature-animation-continuity.json).

210 Bilder einer echten Godot-Vorschau mit Gehen/Rennen/Stoppen und Drehen wurden
mit OpenGL Compatibility / Mesa llvmpipe gerendert. Aufruf:

```sh
godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --script res://tools/capture_creature_animation.gd -- /tmp/creature-animation
```

[Video der Live-Übergänge](../art/review/creature_animation/live_transitions.mp4).
Das Video zeigt die echten Kreaturen im Diagnoseaufbau. Es ist kein Nachweis
für die Leistung auf Zielhardware. Spielerfeedback im eigentlichen Spiel,
insbesondere zu sehr schnellen Kreaturen und schwierigem Gelände, bleibt die
abschließende gestalterische Abnahme. Die bestehenden maximalen Schrittweiten,
Kontakt-Reichweitengrenzen und anatomischen Grenzen bleiben bestehen; es wird
keine vollständige physikalische Gangsimulation behauptet.
