# M6-STOCKPILE-VISUALS

Folgeauftrag des Stammes-Spieltests vom 16.09.2026; koordiniert in #137.
Aufbauend auf #153 / `0190ca599746ccf9984bb83deb0012459a9973f6`.
Branch: `agent/m6-stockpile-visuals-20260916`.

## Verhalten

Sieben eigene Lagerflächen am Dorfplatz zeigen tatsächlich freie Vorräte aus
`stock`. Holz, Stein, Fasern, Nahrung, Wasser, Milch und Eier besitzen eigene
Formen/Farben. Leere Flächen bleiben leer; die sichtbare Menge wächst in zwölf
Stufen bis zur Ressourcenkapazität. Vorhandene Rohstoffvorkommen bleiben Quellen.

Im Lager reservierte Bauware erscheint separat goldfarben. Transportierte Ware,
bereits angeliefertes Baumaterial und bereitliegende Abholmengen sind keine
freien Lagerbestände. Siedlungstransporte halten Lagerplätze frei; diese
Kapazitätsreservierung erzeugt ebenfalls keine sichtbaren Güter.
Mengen werden über dem gerade berührten Lagerplatz exakt erklärt; die bestehende
Ressourcenzeile erhält eine kompakte Übersicht als Tooltip. Keine neue
Dauerbeschriftung und kein zusätzliches großes Fenster.

Die Darstellung liest die vorhandenen Wirtschafts-/Baubücher. Sie schreibt keine
Speicherfelder und besitzt keine Waren. Pro Ressource existieren zwei feste
MultiMesh-Pools mit je zwölf Einheiten; freie und reservierte Einheiten teilen ein
Mesh. Veränderungen innerhalb derselben Mengenstufe aktualisieren nur Zahlen.
Lagerflächen haben keine Kollision und werden auf die echte Planetenoberfläche
ausgerichtet. Der bisherige Cache für andere Dorfobjekte bleibt erhalten.

## Gezielte Prüfung

- `tribal_stockpile_test`: reale Sammlung, Tragen, Ankunft, Essen, Save/Load;
  0/1/24/48 aller Ressourcen; wiederverwendete begrenzte Geometrie; DE/EN,
  tatsächlicher Mauszeiger, HUD-Abdeckung und Pause.
- `tribal_stockpile_world_test`: öffentlicher Stammes-Spieltest auf der Kugel,
  echte Terrainhöhe/Oberflächennormale, Bestandsanzeige und Hover ohne Speichereffekt.
- Bestehender `construction_runtime_test`: Anzeige zusätzlich bei
  Materialtransport, Pause, fehlgeschlagenem Speichern, physischer Rückgabe,
  Save/Load und erneutem Bauabschluss prüfen.
- Bestehender `body_travel_test`: Anzeige vor und nach realem A–B–A prüfen;
  der vorhandene Neustartnachweis prüft weiterhin die unveränderten Warenbücher.
- `tribal_order_latency_test` und `tribe_localization_test` schützen den
  bestehenden Cache und die kompakten Oberflächen.
- Eigener Workflow erzeugt sechs native OpenGL-Bilder mit Software-Rendering,
  Logs und Quell-Commit/-Tree. Er verlangt Erfolgsmarker, Exit 0 und keine
  Engine-/Skriptfehler.

Die lokale Ausführungsumgebung war während der Umsetzung nicht verfügbar.
Verbindliche Ausführung und Nachweise erfolgen deshalb über den PR-Workflow;
Ergebnisse werden im PR dokumentiert. Ziel-PC-Abnahme bleibt gesondert.
Dieses Paket hängt von #153 ab; die vier Integrationsgates und die aktuelle
Zielbasis bleiben Voraussetzungen für die spätere Integration.
