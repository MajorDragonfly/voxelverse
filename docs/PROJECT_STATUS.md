# Aktueller Projektstand

Stand: 15. September 2026. Diese Seite ist der kurze Einstieg für neue Fachchats.
Der Integrationschat aktualisiert sie nach einer gemeinsamen Lieferung.

## Gemeinsame Basis

- Veröffentlichtes `main`: `c8b83f4c8109219f340864a05b2673545d018521`, Merge von
  [PR #90](https://github.com/MajorDragonfly/voxelverse/pull/90).
- Enthaltener Spielcode: `59d73d7822b85445f48fbb9bb4fba738cfb3d5aa`.
  Git-Tree: `c95ac1638832dc413efca38310859fca90542c60`.
  Das ist die geprüfte Ausgangsbasis dieser Workflow-Überarbeitung, kein Alias für
  ein künftig bewegliches `main`. Zum Rundenstart einmal auf Änderungen prüfen.
- Godot **4.6.3**, Forward+, Jolt; Start über `ui/frontend/main_menu.tscn` in
  `main/spherical_campaign.tscn`. Die Flachwelt ist nur historische Prüfszene.
- Frühere Integrationsbranchnamen und „noch nicht angebunden“-Texte in datierten
  Berichten beschreiben deren damaligen Stand. Sie sind keine neuen Arbeitsaufträge.

## Enthalten und offen

| Bereich | Im gemeinsamen Quellstand | Nächste Grenze |
|---|---|---|
| Kugelkampagne | Kreatur, Heimat, Dorf, vier Nutztierspezies, Zähmung, Milch/Eier, radiale Orte und A–B–A-Anschlüsse | Langer begehbarer Ziel-PC-Test und Lade-/Darstellungsspitzen |
| Speicherung | Präzise Koordinaten, feste Speicherteilnehmer, Regions-/Kartenarchive und vollständige Benutzer-/Laborbackups | Globales Manifest, Aufbewahrung/Bereinigung und weitere Langzeitregister |
| Streaming | Vorausschau, gültige Jobgenerationen, radiale Stufenkollision, korrigierter Erstfokus | Kalte Mesh-/Kollisionspublikation messen und begrenzen |
| Kreaturen und UI | Zusätzliche Füße/Münder, Journal-Seiten, lokale Bauplanbibliothek, Fähigkeiten DE/EN | Rüssel und weitere Körperteile, restliche Übersetzungen und visuelle Abnahme |
| Spätere Systeme | Siedlungs-, Regionaltransport- und Schiffsverträge | Produktive Mehrsiedlungsabläufe, spätere Epochen, Schiffsspiel und Onlinekatalog |

**Enthaltener Code ist nicht automatisch vollständig abgenommen.** Bei der
Statusabfrage dieses Audits waren auf dem Spielcode-Commit unter anderem
Godot-Gesamtprüfung, Export und Rendering noch nicht abgeschlossen. Vor einer
Buildfreigabe prüft die Integration die aktuellen Läufe genau einmal. Ein alter
grüner Fachlauf ersetzt den neuen gemeinsamen Kandidaten nicht. Der 1080p60-
Nachweis auf benannter CPU/GPU/RAM-Konfiguration fehlt weiterhin.

## Referenzhardware für den Spieltest

Von Lars am 15. September 2026 angegeben:

| Komponente | Ausstattung |
|---|---|
| CPU | AMD Ryzen 7 9800X3D |
| GPU | NVIDIA GeForce RTX 4070 Ti |
| Arbeitsspeicher | 32 GB, 5200 MT/s |

Vorläufiges Leistungsziel bleibt 1920 × 1080 bei 60 FPS. Grafikpreset,
Treiberstand und tatsächliche Messwerte werden beim Test protokolliert.
Dieser Referenz-PC ist keine festgelegte Mindestanforderung für das Spiel.

## Nächste Arbeitsrunde

`python3 tools/work_packet.py list` zeigt sieben abgegrenzte Vorschläge.
Sie haben bewusst keine lokale „frei/reserviert“-Spalte: Eine Branchkopie könnte
die tatsächliche Belegung anderer Chats nicht zuverlässig kennen.

Empfohlener Anfang: `ARCH-17-PUBLISH`, `ARCH-13-MANIFEST`, `ARCH-24-TRUNK` plus
ein Integrationschat. `ARCH-14-ENCOUNTERS` folgt in den geteilten Speicherbereichen
nach ARCH-13; `ARCH-25-EDITOR` alternativ zum Kreatureneditorpaket.
`ARCH-26-SECOND-SITE` erst mit zugeordnetem Save-/Dorfbesitzer beginnen.
`ARCH-19-TARGET-PC` gehört zur gemeinsamen Abnahme auf der oben benannten Hardware.

Aufträge und Belegung: [Arbeitsablauf](PARALLEL_WORKFLOW.md). Technische Richtung:
[Godot und Skalierung](GODOT_TECHNICAL_DIRECTION.md). Vollständige Ziele bleiben
in [ROADMAP](../ROADMAP.md) und den jeweiligen ARCH-Abschnitten erhalten.
Quellhistorie bei Bedarf: [Integration 15.09.](INTEGRATION_2026-09-15.md).
