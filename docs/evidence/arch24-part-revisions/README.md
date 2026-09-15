# ARCH-24-PART-REVISIONS – Prüfnachweis

Quellcommit: `f68d50ada84aea4f5987a74afea5b0e177a87a83`.
Quelltree: `bafab2d9375972758e2fffad2864c8ace18e4961`.
Basis: `1d6573d9551c3f24bf1dd6fa64e5c301583a26c8` (PR #110).
Der Arbeitsstand war während der abschließenden Prüfung sauber. Dieser
Folgecommit ergänzt ausschließlich Dokumentation und Nachweise.

Godot `4.6.3.stable.official.7d41c59c4`, Linux Headless. Der vorhandene Runner
verwendete je Fachtest eigene synthetische Nutzerdaten. Keine Nutzerdateien
wurden übernommen. Die neuen Neustartprüfungen starten einen separaten
Godot-Prozess mit denselben isolierten Testdateien.

**Ergebnis: 16/16 Fachtests und 3/3 Quell-/Importgates bestanden.**
Der neue Revisionstest meldet 810 Prüfbedingungen im Hauptprozess und einen
erfolgreichen Neustart. Er umfasst ungültige und unbekannte Referenzen an
allen vier Stellen (Wurzel, Körper, Haut, Teil), Mund-/Endstückgeometrie,
Editor/Undo/Redo, lokale Bibliothek, fehlgeschlagenes atomisches Schreiben
sowie bytegleichen Original-/Backupschutz in Datei und Kampagne.
Die bestehenden 30 Wildart-Hashes und eingefrorenen Modellfälle bleiben geprüft.

```sh
python3 tools/validate_godot.py --godot /workspace/scratch/d2f8e8a15ebb/godot-toolchain/editor/Godot_v4.6.3-stable_linux.x86_64 --tests creature_part_revisions_test blueprint_contract_test community_blueprint_package_test creature_design_library_test creature_library_ui_test creature_mouth_provider_test creature_foot_provider_test creature_hand_provider_test creature_snout_family_test creature_trunk_provider_test creature_part_articulation_test creature_body_contract_test creature_editor_v7_runtime_test campaign_foundation_test save_slots_test frozen_body_serialization_test --skip-main --output /workspace/scratch/4d3ad58ddf53/qa-final
```

`results.json` enthält die vollständige Testauswahl und Laufzeiten;
`source-manifest.json` die Dateihashes aller 26 Quelländerungen. Die Logdateien
sind unveränderte Rohprotokolle. Keine volle Spiel-/Windows-/Export-/Grafik-
oder FPS-Freigabe. Der gemeinsame Diffplan verlangt wegen der Registry eine
volle Integrationsprüfung; der hier gewählte Fachumfang ist ausdrücklich
auf direkte Verbraucher begrenzt.

## Behobene Entwicklungsbefunde

Die früheren Läufe in `development/` waren schmutzige Entwicklungsstände und
sind keine Nachweise für den finalen Tree. Ihre ursprünglichen Fehler bleiben
zur Nachvollziehbarkeit erhalten:

- Ein Testaufruf kollidierte mit Godots nativem Script-`set_name`; der Test
  verwendet stattdessen die tatsächliche Körpergrößenmutation.
- Der äußerste Editor synchronisierte Fortschritt vor der Schutzprüfung.
  Der Schutz greift nun bereits vor diesem Schritt.
- Godots tiefer Dictionary-Vergleich unterscheidet Ganzzahl- und Floattypen.
  Bibliotheksreferenzen werden für den Vergleich kanonisiert, ohne andere
  Werte oder Originaldateien zu ändern.
- Ein Testkörper hatte zentrierte statt gespiegelter Beinanker; die Fixture
  verwendet nun den existierenden anatomischen Anschluss.
- Neustartorakel verglichen bisher nur die Teilprojektion ohne Revisionen.
  Sie prüfen nun den gespeicherten Vertrag einschließlich Referenzen. Beim
  Gelenktest waren die Dokumente semantisch gleich, aber `schema: 1` und
  `schema: 1.0` ergaben verschiedene Text-Hashes; beide Seiten werden als JSON
  kanonisiert. Historische Mesh-/Artenfixtures wurden nicht verändert.
