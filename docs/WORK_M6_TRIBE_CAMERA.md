# M6-TRIBE-CAMERA

Basis: `e7d6ec7e612fc84d75586995dcd0815e61b653d9` aus PR #156.
Branch: `agent/m6-tribe-camera-20260917`. Zuteilung in Issue #137.

## Bedienung

- WASD bewegt die Ansicht in Blickrichtung, bis 128 m vom Dorfplatz.
- Linke/rechte Pfeiltaste drehen; Bild auf/ab neigen zwischen 30° und 80°.
- Mittlere Maustaste ziehen dreht und neigt; bestehende Empfindlichkeit und
  invertierte Y-Achse gelten auch hier. Das Mausrad zoomt weich zwischen 12 und 72.
- Pos1 zeigt den Dorfplatz; Ende die ausgewählten Bewohner. Das kleine Menü
  „Ansicht“ bietet dieselben Ziele, Zurücksetzen und die vorhandenen Esc-Einstellungen.
- Kamerageschwindigkeit (50–300 %) und Startneigung werden mit den bestehenden
  Steuerungsoptionen atomar lokal gespeichert. Alle sieben neuen Aktionen sind
  neu belegbar. Alte Profile behalten ihre bestehenden Pfeil-/Maustasten.
- Pause, Fensterfokusverlust, Menü und Ladewechsel beenden gehaltene Eingaben.
  Scrollen über Bedienelementen zoomt die Welt nicht. Bauen verwendet weiterhin
  denselben Strahl und dieselbe Platzierungsprüfung wie die Vorschau.

## Zuständigkeiten und Grenzen

Die Kamera erhält einen oberflächengebundenen Fokus und eine zweite rein visuelle
Geländeauswahl. Physischer Streaming-Besitzer bleibt der Dorfplatz. Bestehende
Budgets (768 Blätter, 24 aktive Geländekollider, 1536 residente Gelände-Meshes,
2 Uploadschritte je Frame) bleiben erhalten. Ruhende Ansichten berechnen ihre
Geländehöhe nicht jedes Frame neu. Ein Ursprungwechsel verschiebt den Fokus
und die Kamera jeweils einmal; ein neuer Körper/Ladestand erhält einen neuen Rig.

Die Kamera ist kein Erkunder, Bewohner oder Simulationsbesitzer. Arbeits- und
Baugrenzen, Navigation, Waren, Bevölkerung, Karte und Speicherformat ändern sich
nicht. Vegetations-/Tierstreaming und vollständige Planetenübersicht bleiben eigene
Arbeit. Die 128 m sind eine bewusste Grenze dieser Dorfkamera.

## Gezielter Nachweis

Workflow `.github/workflows/tribal-camera-validate.yml` prüft die drei neuen Tests,
beide Bauvorschau-Verbraucher, Lokalisierung, adaptive Kugeldeckung, Streaming,
Terrainübergaben und den vorhandenen A–B–A-Reisetest. Die zusätzliche Layoutprüfung
umfasst Pol, Würfelkante und -ecke auf kleinen und erdgroßen Kugeln mit zwei Foki.

`tools/review_tribal_camera.py` führt Eingaben und den öffentlichen Kugel-Spieltest
zusätzlich mit OpenGL aus und schreibt sechs native PNGs. Der Welt-Test schwenkt
mit echten WASD-Ereignissen über 100 m, prüft Detailgelände, Bodenkollision,
Erkundungs-/Arbeitsbesitzer, Ursprungwechsel, Zoom/Neigung und Live-Laden.

Exakte Head-/Tree-Werte, Ergebnisse und Bildprüfung stehen in der PR-Übergabe.
Gezielte Fachabnahme ersetzt weder vollständige Integrationsgates noch Ziel-PC-
oder Exportabnahme. Integration hängt von #153 und #156 ab.
