# ARCH-24 – Körperteilkatalog und Fuß-Geometrie

Status: **erstes Teilpaket lokal fertig und geprüft**, reserviert am 10. September 2026.
Basis: `ea900f2` (gemeinsamer veröffentlichter `main`).
Branch: `agent/arch24-part-geometry-2026-09-10`.
Lokaler Implementierungscommit: `d6761d3f0cd9b0b166b384a12d7f7dbe763d3655`.

Die Veröffentlichung dieses fertigen Branches als Entwurfs-PR wurde von Lars
am 10. September 2026 ausdrücklich freigegeben. Die Bereitstellung erfolgt über
die verbundene GitHub-App; die Dateien werden gegen den lokalen Git-Baum geprüft.
Die Integration nach `main` bleibt offen.

## Abgegrenzter Auftrag

ARCH-24 / M3-TEILE.1 und erster Referenzanschluss für M3-TEILE.2:
vorhandene Körperteil-IDs inventarisieren; die vier bestehenden Fußtypen
über getrennte Katalogdaten und Geometrie anbinden; D1-Standfähigkeit über
Katalogmerkmale prüfen. Bestehende Formen, IDs, Stats, Speicherformate und
Freischaltungen erhalten. Neue Formen erhalten später eigene IDs bzw.
ausdrücklich gespeicherte Revisionen nach ARCH-23.

Schreibbereiche: neue Fußkatalog-/Geometriedateien, Fußabschnitt in
`creature_part_library.gd` und `creature_part_geometry.gd`, D1-Standprüfung
in `planet_fauna_catalog.gd`, eigene Tests und diese Übergabe.
Die bestehenden Editor-/Buch-/Weltverbraucher verwenden denselben Renderer.
Gemeinsame Roadmap, Save, Bauplannormalisierung, Sprachkataloge, UI und
laufende Fremdbranches gehören nicht zu diesem Paket.

ARCH-01, -02, -05, -20, -23, -25 und -29 sind in anderen Chats reserviert.
ARCH-24 bleibt insgesamt offen: weitere Tierformen und ihre Animationen
sowie die vollständige Spielerabnahme folgen in einzelnen Modellpaketen.

## Geliefert

- [Bestandsinventar](CREATURE_PART_INVENTORY.md) mit allen 46 bestehenden IDs,
  ihren Besitzern, Erhaltungsregeln und dem Anschluss für zusätzliche Modelle.
- Reiner Fußkatalog: die bestehenden Ballen-, Krallen-, Spalthuf- und Schwimmfüße
  mit explizitem Revision-1-Geometrieverweis und unabhängigen Lesekopien.
- Separater Geometrieanbieter: gemeinsame Rezepte für den vorhandenen
  Kreaturenrenderer sowie erhaltene Voxeldefinitionen für den älteren Blockadapter.
  Namen, IDs, Zahlenwerte, Farben, Reihenfolge und gespeicherte Formen bleiben erhalten.
- D1 liest jetzt das Merkmal `domestic_support`; dieselben bisherigen Füße
  bestehen die Prüfung. Rollen, Besitz, gespeicherte Arten und ihre Körpernachweise
  behalten die bisherigen Fachbesitzer.
- Keine Schemaänderung: neue gespeicherte Teilrevisionen warten auf ARCH-23.
  Unbekannte direkt angefragte Geometrie-/Katalogrevisionen liefern keinen Ersatz.

## Nachweise

Godot `4.6.3.stable.official.7d41c59c4`, echte Headless-Szenenläufe;
[maschinenlesbares Ergebnis](../validation/arch24-parts.json).
Die geprüften Laufzeitdateien entsprechen dem oben genannten Implementierungscommit.

| Prüfung | Ergebnis | Aussage |
|---|---|---|
| `creature_foot_provider_test` | bestanden | Alle 46 Altdefinitionen und Reihenfolge, 24 unveränderte Geometriefälle, getrennte Lesekopien, unbekannte Revisionen, tatsächliche Buch-/Silhouettenmeshes, vier Fußtypen mit sechs Beinen auf geneigtem Bezugssystem, D1-Zulassung und serialisierter Bestand |
| `creature_parts_studio_test` | bestanden | Bestehender kompletter Teilepfad: Editorsteuerung, Undo, Drehung, Symmetrie, unterschiedliche Endstücke, 2/4/6 Beine, Gelände, Wildtiere und Speichern/Laden |
| `creature_body_contract_test` | bestanden | Radialer Stand/Gang und Körperanschlüsse, Editor sowie eigener frischer Neustartprozess |
| `domestic_surface_catalog_test` | bestanden | D1 auf sechs Würfelseiten, Radien 50 km / 500 km / 6.371 km, Kantenwechsel und realen Referenzkörpern |

Die Geometriefixture wurde vor dem Umbau aus `ea900f2` erzeugt, jeweils mit
einem bzw. anderem Spiegelvorzeichen und drei Maßverhältnissen. Sie hält
Mesh-Vertex-Fingerabdrücke, Bounds, Teiltransformationen, Knotennamen und Farben fest.
Die Katalogfixture stammt aus der unveränderten Bibliotheksdatei dieses Basiskommits.
JSON-Zahlen werden auf beiden Vergleichsseiten gleich dekodiert, damit der
Integer-/Float-Typwechsel beim Einlesen keinen falschen Unterschied erzeugt.

Die gemeinsame Vorschau und Silhouette wurden als echte Szenen-/Meshdaten geprüft.
Eine neue Bildschirmaufnahme konnte hier nicht entstehen: Xvfb konnte keine lokalen
Sockets öffnen. `tools/capture_foot_family.gd` ist als geparster Aufnahmehelfer für
einen Desktop mit Renderer enthalten. Kein visueller Ziel-PC-, FPS- oder Exportnachweis.

Wiederholung im vorhandenen Validator:

```sh
python tools/validate_godot.py --godot /pfad/zu/godot --skip-main --tests creature_foot_provider_test creature_parts_studio_test creature_body_contract_test domestic_surface_catalog_test
```

## Integration und nächste Schritte

1. Dieses begrenzte Teilpaket nach Freigabe veröffentlichen und getrennt integrieren.
   Die drei bestehenden Laufzeitdateien sind `creature_part_library.gd`,
   `creature_part_geometry.gd` und `planet_fauna_catalog.gd`; die übrigen Änderungen
   sind eigene neue Dateien und Dokumentation.
2. ARCH-24 in der gemeinsamen Roadmap nur als **teilweise geliefert** markieren.
   Der Integrationsbesitzer pflegt die gemeinsame Roadmap/Arbeitsverteilung.
3. Nach ARCH-23 neue Pfoten-/Tatzenformen und weitere Tierfüße mit eigenen IDs
   bzw. ausdrücklich gespeicherten Revisionen liefern; Entdeckung/Übersetzung
   mit ihren Besitzern koordinieren. Die weiteren Mund-/Greiferfamilien bleiben offen.
4. Alte Revision-1-Geometrie erhalten; das D1-Merkmal einer neuen Form erst nach
   passendem Stand-/Körpernachweis vergeben. Schwimmhaut oder Krallen allein
   schalten keine zusätzliche Bewegungsart frei.
