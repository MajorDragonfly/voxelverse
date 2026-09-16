# ARCH-14-LAB-POPULATION – dauerhaftes Wildtierarchiv im Planetenlabor

Teilauftrag: `ARCH-14-LAB-POPULATION`
Basis: `d378ca0ecd7f03429a5150df6358e0646ec06689`
Branch: `agent/arch14-lab-population-20260915`

Das separate lebende Planetenlabor hat bisher nach 256 gespeicherten Wildtieren
keine weiteren Individuen erzeugt. Der normale Kugelkampagnenpfad benutzt bereits
CampaignPopulation; dieser Auftrag betrifft dessen Register nicht.

## Umsetzung und Speichervertrag

`LivingFaunaArchive` verwendet den bestehenden unveränderlichen RegionStore:
96 residente Individuen, 128 Trie-Seiten und vier durch aktive Tiere gepinnte
Datensätze. Körpergebundene `land1:…:animal`-IDs bleiben erhalten. Die Zahl jemals
gespeicherter Tiere begrenzt keine neue Begegnung. Verdrängte Zustände werden beim
nächsten Besuch geladen; ferne Tiere simulieren nicht. Flora und ihre Publikations-
budgets bleiben beim bisherigen Streamer, D1-Pflichtarten beim vorhandenen Katalog.

Header 4 schützt den neuen `fauna_archive`-Besitzer vor alten Lesern. Das Manifest
enthält Schema 1, Körper-ID, Anzahl und Trie-Wurzel. Alte Header 1–3 bleiben lesbar;
beim Öffnen eines Körpers wird dessen vollständiger Inline-Bestand zunächst
validiert, dann in Blobs geschrieben und erst nach erfolgreichem Checkpoint im
Arbeitsspeicher ersetzt. Noch ungeöffnete alte Körper dürfen weiterhin `fauna`
enthalten. Beide Besitzer zugleich sind ungültig. Das Öffnen verändert die alte
Save-Datei nicht. Die bestehende native Anatomiekodierung bleibt erhalten.

Blobs liegen separat unter `user://living_fauna/blobs`, damit die Lebensdauer dieser
Laborstände nicht vom Kampagnenmanifest abhängt. Ein vollständiges Laborbackup
braucht Save, `.bak`, diese Blobs und gegebenenfalls Kartenblobs. Der bestehende
`export-user-data`-/`verify-user-data`-Weg erfasst alle Dateien unverändert; ein
reiner Kampagnen-Slotexport enthält das Labor weiterhin nicht. Keine Bereinigung
oder Löschung wird eingeführt.

Erst vollständige Blob-Checkpoints veröffentlichen eine neue Wurzel im Laborsave.
Aktive Tiere werden auch nach einem vorherigen Save erneut als geändert markiert.
Alte Save-/Backup-Wurzeln behalten ihre unveränderlichen Zustände. Fehlende,
beschädigte, unbekannte oder ungültige geladene Tierdaten werden nicht durch neu
generierte Tiere ersetzt. Fehler sperren Speichern und verlustreiche Übergänge;
Primärdatei und Backup bleiben erhalten. Der Archivindex wird beim Öffnen nur an
der Wurzel geprüft, weitere Seiten und Zustände beim jeweiligen Zugriff.

## Abnahmeumfang

Der registrierte `living_fauna_archive_test` öffnet einen alten Laborstand mit
256 Datensätzen, erweitert ihn auf 384 historische Zustände und erzeugt danach
vier tatsächliche Creature-Nodes über den Streamer. Er prüft Verdrängung, frühe
Änderungen, Cache-/Nodegrenzen, einen neuen Godot-Prozess, native Vector3/Color-
Anatomie, Änderungen nach einem bereits erfolgten Checkpoint, alte Wurzeln,
Zukunftsmanifeste, fehlende/beschädigte/ungültige/leere Payloads sowie einen echten
Dateisystem-Schreibabbruch. JSON-Skalare werden nach der vorhandenen
`domestic_native_comparison`-Toleranz von höchstens 1e-12 verglichen; native
Vector3/Color-Werte und Identitäten exakt.

Direkte Regressionen: `living_planet_test`, `living_planet_map_test`,
`domestic_surface_runtime_test`, `surface_population_budget_test`.
`lab_fauna_backup_test.py` exportiert die neuen Laborblobs mit dem bestehenden
Benutzerdatenarchiv, entfernt das Originalverzeichnis aus dem Ladepfad und prüft
alle 388 Identitäten sowie vier echte Tiere in einer getrennten Wiederherstellung.
Die neue Godot-Prüfung steht genau einmal in `tools/validation/contracts.json`;
die native Backup-Prüfung läuft auch im bestehenden Backup-Workflow.

Dies ist keine Aussage über Bildrate, Windows-Export oder die gemeinsame
Produktions-/Reisekette. Körpermodelle, Editor, Siedlungen und HUD sind weiterhin
bei ihren eigenen Paketen. Messergebnisse und Quellzuordnung folgen in der
Paket-Evidenz und PR-Übergabe.
