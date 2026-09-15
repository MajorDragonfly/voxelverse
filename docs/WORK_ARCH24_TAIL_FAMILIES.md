# ARCH-24-TAIL-FAMILIES

Basis: `9b502ef121a49bcdf2e7c0d0995b8075b61469c9`,
`agent/arch24-part-revisions-20260915` / PR #112. Fachbranch:
`agent/arch24-tail-families-20260915`. Dieses Paket setzt den Revisionsvertrag
aus #112 voraus und ist gegen dessen Branch zu integrieren.

## Lieferung

Vier neue wählbare Schwanzformen verwenden den gemeinsamen Katalog und
Geometrieanbieter in Editor, Entdeckungsbuch und bewegten Kreaturenkörpern.

| ID | Form | Bestehendes Werte-/Freischaltprofil | Meshes |
|---|---|---|---|
| `tail_stump` | kurzer runder Stummel | `tail_balance` | 2 |
| `tail_reptile` | kräftiger, gebogener Schwanz mit Rückenschuppen | `tail_balance` | 9 |
| `tail_beaver_paddle` | flaches Biberpaddel mit Schuppen | `tail_fin` | 11 |
| `tail_horizontal_fluke` | waagerechte Flosse mit zwei Lappen und Mittelkerbe | `tail_fin` | 8 |

Stummel und Reptilienschwanz sind über das bestehende Starterprofil verfügbar.
Paddel und horizontale Flosse folgen der Entdeckung/Freischaltung des bisherigen
Flossenschwanzes. Alte Fortschrittsstände ergänzen die daraus verdienten
Modellvarianten idempotent, ohne neue Entdeckungspunkte zu vergeben. Kosten,
Standardmaßstab und sämtliche Spielwerte werden vom jeweiligen Altprofil
kopiert. Die Formen gewähren keine zusätzlichen Aktionen oder Fähigkeiten.
Die vorhandenen Schwimmwerte des Flossenschwanzes bleiben dessen Profil.

Alle acht Schwanz-IDs lösen `part_revision = 1` über den neuen Anbieter auf.
Fehlende Revisionsfelder behalten wie in #112 die Bedeutung Revision 1;
unbekannte Schwanz-IDs und Revisionen erzeugen keine Ersatzgeometrie.
Die vier Altmodelle behalten ihre Meshes, Farben, Reihenfolge und Transformationen.
Alte Katalogdefinitionen einschließlich ihrer einfachen Legacy-Voxel bleiben
erhalten. Der V7-Wildartengenerator verwendet weiter seine vier ursprünglichen
Schwanz-IDs und dieselbe Zufallszahlenfolge.

Neue Modelle unterstützen die bestehenden XYZ-Formregler, Skalierung,
Rotation, Spiegelung, Körperanschlüsse und die gemeinsame Schwanzbewegung.
Namen und Beschreibungen sind DE/EN verfügbar. Portable Vorlagen und die lokale
Bibliothek nutzen die vorhandenen Serializer mit gespeicherten Teilrevisionen.

## Abnahme

`creature_tail_family_test` ist einmal im Vertrag `creature_body` registriert.
Er prüft 24 vor der Extraktion erfasste Altgeometrien, 24 eingefrorene neue
Revision-1-Geometrien, 30 historische Wildarten, Katalogkopien, Transformations-
und Spiegelungsverhalten, echte Editoraktionen mit Undo/Redo, Entdeckung und
Altstandmigration, Entdeckungsbuch-Silhouetten, DE/EN, Bibliotheksduplikate und
Neustart in einem neuen Godot-Prozess. Die gespeicherten IDs, UIDs, Revisionen,
Farben und Formen müssen identisch zurückkehren; ein neuerer Entwurf darf
eine vorhandene Datei nicht überschreiben. Die vier Testkörper werden in
gedrehten lokalen Koordinaten bei Idle/Walk/Run einschließlich Bodenfreiheit
geprüft. Das ist keine Kollisionsgarantie für beliebige Nutzergestaltungen.

Die zwei vorhandenen Katalogtests zählen die vier ausdrücklich hinzugefügten
IDs zusätzlich; ihre historischen Katalog-/Meshvergleiche bleiben bestehen.
`tools/capture_tail_baseline.gd` dient nur der ausdrücklichen Erfassung,
niemals dem automatischen Neuschreiben von Fixtures bei der Validierung.

`tools/export_tail_review.gd` exportiert echte Meshdreiecke des gemeinsamen
Providers und vier vollständiger Standardkörper. `tools/render_tail_review.py`
erzeugt daraus CPU-Ansichten für die Sichtprüfung. Keine Spielaufnahme oder
native Grafik-/FPS-Abnahme. Quellrevision, genauer Fachtestbefehl, vollständige
Logs und Sichtnachweise: `docs/evidence/arch24-tail-families/`.

## Integration

Gemeinsame Anschlüsse: `creature_part_library.gd`, `creature_part_geometry.gd`,
`creature_part_revisions.gd`, Modellfreischaltung in `progression_service.gd`,
V7-Wildartenauswahl, acht neue Übersetzungsschlüssel samt generierten PO-Dateien,
zwei angepasste Katalogzählungen und eine Testregistry-Ergänzung. Die alten
Mund-/Hand-/Fußmodelle verwenden weiter ihre Anbieter. Kein neuer Gelenk- oder
Kampfablauf. Zentrale Status-/Roadmap-Dateien bleiben beim Integrationschat.
