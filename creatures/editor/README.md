# Creature Editor V3 – Interaction Polish und High Detail Voxels

Diese Dateien gehören in:

res://creatures/editor/

Starte zum Testen die Szene:

res://creatures/editor/creature_editor.tscn

## V3-Schwerpunkte

- luftigere Editor-Oberfläche mit mehr Platz für die Kreatur
- zuverlässigere Bauteil-Auswahl über größere Part-Collider
- linke Maustaste auf freier Vorschaufläche dreht die Kreatur
- rechte Maustaste auf Bauteil dreht das Bauteil
- Mausrad skaliert das ausgewählte Bauteil
- Körper und Bauteile werden feiner voxelisiert
- globale Y-Axis-Symmetry bleibt erhalten und spiegelt über X = 0

## Mausbedienung

- Leere mittlere Fläche mit linker Maustaste ziehen:
  Kreatur drehen.
- Shift + leere Fläche mit linker Maustaste ziehen:
  Kreatur zusätzlich leicht nach oben/unten kippen.
- Bauteil anklicken:
  Bauteil auswählen.
- Bauteil mit linker Maustaste ziehen:
  Bauteil auf dem Körper verschieben.
- Shift + linke Maustaste ziehen:
  Bauteil hoch/runter verschieben.
- Bauteil mit rechter Maustaste ziehen:
  Bauteil um Y drehen.
- Shift + rechte Maustaste ziehen:
  Bauteil um X drehen.
- Ctrl + rechte Maustaste ziehen:
  Bauteil um Z drehen.
- Mausrad:
  ausgewähltes Bauteil skalieren.
  Ohne ausgewähltes Bauteil zoomt die Kamera.

## Tastatur

- Tab: Kategorie wechseln
- Q/E: vorheriges/nächstes Teil
- Pfeiltasten / PageUp / PageDown: Körperform oder ausgewähltes Teil bewegen
- , / .: skalieren
- R: rotieren
- Ctrl + D: ausgewähltes Teil duplizieren
- Entf: ausgewähltes Teil löschen
- M: Spiegelung des ausgewählten Bauteils ein/aus
- Y: globale Symmetry ein/aus
- Ctrl + S: speichern
- Ctrl + L: laden
- Ctrl + R: neue Kreatur

## Nächster Schritt

V4 soll echte Körper-/Wirbelsäulen-Handles bekommen:
einzelne Body-Segmente anklicken, dicker/dünner machen, hochziehen,
runterziehen und die Körperkurve verändern.
