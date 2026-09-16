# ARCH-13-RETENTION-LIFECYCLE — Prüfnachweise

Quellcommit lokal `98096573ab7b4a8d7de1c3d935652650abcaf1d4`, veröffentlicht
`d5610e24866c6b58e935b338ba41ca4b53ca26e7`; exakt gleicher Git-Tree
`91913241d5a61975db6feedaee881fd08d9e607a`. Basis ist der gemeinsame Kandidat
`1d6573d9551c3f24bf1dd6fa64e5c301583a26c8` von PR #110.

[Ergebnisse und Dateihashes](results.json) · [Unveränderte Rohprotokolle](logs.tar.gz)
· [Umsetzung und Grenzen](../../WORK_ARCH13_RETENTION_LIFECYCLE.md)

## Ergebnis

- **60 von 60 ausgeführten Python-Testfällen bestanden**; ein zusätzlicher,
  optionaler Vergleich mit einem externen historischen Schema-2-Atlasprojekt
  wurde mangels Projektpfad ausgelassen. 61 Fälle insgesamt, 124,474 Sekunden.
- Darin echter Godot-/Python-Zugriff mit laufender Sitzung, zwei Prozessen,
  hartem Prozessende, abgebrochener Veröffentlichung, Wiederaufnahme und
  kanonischem beziehungsweise per Symlink angebundenem Benutzerordner.
- Echte Wiederherstellung aus exportierten Dateien ohne den ursprünglichen
  Benutzerordner: 1.200 Regionen mit mehreren Snapshotständen, 1.202 Begegnungen,
  3.106 Orte mit historischen/ausstehenden Einträgen und 388 historische Labortiere.
  Aktive Labortiere und die unabhängigen `living_fauna/blobs` sind eingeschlossen.
- **Vier Godot-Fachtests bestanden:** `region_store_test`, `save_slots_test`,
  `save_participants_test`, `spherical_developed_migration_test`. Echte
  Save-/Copy-/History-/Migrations-/Neustartpfade, nicht nur Quelltextprüfungen.
- Import und Quell-/Ressourcenprüfungen bestanden. Godot 4.6.3, Linux/headless,
  isolierte synthetische Benutzerdaten. Kein Zugriff auf persönliche Spielstände.

Der abschließende Python-Lauf startete am sauberen lokalen Quellcommit.
Der erfolgreiche Godot-Fachlauf entstand unmittelbar zuvor auf dem veränderten
Arbeitsbaum; seine Rohberichte behalten `tracked_worktree_dirty=true` und die
ursprüngliche Basisreferenz. Die geprüften Laufzeitdateien wurden danach nicht
mehr geändert. `results.json` identifiziert die tatsächlich gelieferten Dateien;
später ergänzt wurde nur die Paketdokumentation.
Kein erneuter Volltest für reine Nachweisdokumentation.

## Befehle

Im Projektwurzelverzeichnis; `GODOT_BINARY` bezeichnet die installierte 4.6.3-Engine:

```sh
python3 tools/validate_godot.py --godot "$GODOT_BINARY" --skip-main --tests --output ../qa-import
python3 tools/validate_godot.py --godot "$GODOT_BINARY" --skip-import --skip-main --tests region_store_test save_slots_test save_participants_test spherical_developed_migration_test --output ../qa-runtime-fixed
```

Im Verzeichnis `tests/tooling`, mit `GODOT_BINARY` und
`PLACE_BACKUP_PROJECT` auf dieses Projekt gesetzt:

```sh
python3 -m unittest region_retention_test region_backup_test region_backup_places_test region_backup_userdata_test userdata_access_test lab_fauna_backup_test -v
```

Die zuvor importierten Ressourcen sind unverändert; neue GDScript-Proben werden
im echten Prozess geladen. CI behält ihren eigenen Import. Der Python-Lauf ist
unter `qa-tooling-final.log` enthalten; die Fachläufe samt ursprünglicher
Quellreferenz liegen unter `qa-runtime-fixed/`.

## Während der Umsetzung korrigierte Befunde

Die Rohprotokolle behalten auch die ersten fehlgeschlagenen Läufe:

1. Godots JSON-Parser liefert Zahlen als Float; Dictionary-Gleichheit unterscheidet
   sie von Integern. Die Besitzerprüfung normalisiert ausschließlich die geprüften
   numerischen Metadatenfelder vor dem Vergleich.
2. Ein bereits auf null Referenzen gesunkenes `RefCounted` darf in
   `NOTIFICATION_PREDELETE` keine Instanzmethode mehr aufrufen. Die Freigabe nutzt
   dort statische Bereinigung; normaler Ablauf hinterlässt keinen Token.
3. In dieser Umgebung fehlt die Hostname-Umgebungsvariable. Beide Sprachen lesen
   dann dieselbe reguläre Hostnamedatei. Unbekannte Hosts bleiben gesperrt.
4. Godots Unix-Prozessabfrage erkannte einen fremden Python-Prozess nicht sicher.
   Die Laufzeit übernimmt deshalb grundsätzlich keine bestehende Zugangssperre;
   ausschließlich Python prüft verwaiste Besitzer mit den Plattformfunktionen.
   Der native Gegenversuch beweist jetzt die Verweigerung aller Schreibwege.

Der erste fehlerhafte Regionslauf wurde nach dem Befund abgebrochen. Die vier
betroffenen Fachtests wurden nach der Korrektur vollständig erfolgreich ausgeführt.

Keine Gesamtintegrations-, Windows-, Spieleexport-, Grafik- oder Ziel-PC-Freigabe.
Die CI-Ergebnisse des veröffentlichten PR werden separat geführt; lokale
Quellprüfungen sind kein Beleg für einen späteren Merge-Tree.
