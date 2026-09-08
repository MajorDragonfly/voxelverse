# Kreatureneditor – Einstieg und historisches Bedienkonzept

Standhinweis vom 8. September 2026: Die aktive Szene lädt
`creature_editor_runtime.gd` auf Basis des V7-Editors. Wirbelsäulenbearbeitung,
Anatomieanker, Oberflächenbindung, Symmetrie und Undo/Redo sind bereits vorhanden.
Der Runtime-Editor verbindet den Teilekatalog mit den Entdeckungsfreischaltungen.
Die geplante Überarbeitung und ihre Abnahme stehen in [ROADMAP.md](../../ROADMAP.md).
Die V3-Beschreibung unten dokumentiert die frühere Bedienbasis, nicht den gesamten
heutigen Funktionsumfang.

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

Die bereits vorhandene Körper-/Wirbelsäulenbearbeitung wird gemäß M3 der zentralen
Roadmap verständlicher und robuster gemacht. Dazu gehören passende Anatomie,
Animation und tatsächlich wirksame Fähigkeiten für verschiedene Körperformen.
Vorher werden die dort beschriebenen Kampagnen- und Planetenverträge geprüft.
