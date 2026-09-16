# ARCH-13-MANIFEST — Generationen und Aufbewahrungsplanung

Teilauftrag vom 15. September 2026. Basis:
`d378ca0ecd7f03429a5150df6358e0646ec06689` (PR #92).
Branch: `agent/arch13-global-manifest-2026-09-15`.
Schreibbereiche: bestehendes Backup-Werkzeug, zugehörige Python-Prüfungen und CI.
ARCH-24 und die Spielspeicher-Schreiber werden nicht verändert.

## Lieferung

`tools/region_backup.py plan-retention` erstellt für ein **geschlossenes Spiel**
ein gemeinsames Generationenmanifest aller Dateien im ausgewählten
Benutzerverzeichnis. Die Generation ist der SHA-256 des kanonischen
Dateiverzeichnisses einschließlich Inhaltshashes und leerer Verzeichnisse.
Identische Daten an einem anderen Pfad ergeben dieselbe Generation.

Alle JSON-Objekte werden unabhängig von Slotnamen nach bestehenden
Regionsmanifesten untersucht. Dazu gehören aktuelle Spielstände, `.bak`,
Slothistorien, Kopien, eigene Speicherpfade, Laboratlanten sowie in
`source_text` und `legacy_save_text` eingebettete Migrationsoriginale. Erkannt
werden Population, Kartenkacheln, Ortsindex und generische `sha256_trie_v1`-Wurzeln.
Auch vollständige temporäre JSON-Schreibstände bleiben als eigene Quellen erfasst.

Die vorhandenen Save-/Atlas-/Trie-Prüfer des Backup-Werkzeugs kontrollieren
bekannte Verträge einschließlich Inhaltshashes, Triepfaden, Atlasprojektion,
gegenseitiger Ortsindizierung und noch nicht ausgelagerten Ortseinträgen.
Fehlende Dateien, beschädigte benannte JSON-Quellen, neuere bekannte
Speicherverträge oder ein unvollständiger Graph verhindern die Veröffentlichung.
Ein gesundes Backup verdeckt dabei keinen fehlerhaften aktuellen Stand.

## Verwendung

Python 3.10+ mit Standardbibliothek einschließlich SQLite. Spiel und Editor
schließen; auch andere Programme dürfen den Quellbaum währenddessen nicht ändern.
Dateisystempfade angeben, keine `user://`-Adressen. Ziel muss neu sein und außerhalb
des Benutzerverzeichnisses und Projekts liegen.

```bash
python tools/region_backup.py plan-retention \
  --user-data /path/to/Voxelverse --output /path/to/new-retention-plan

python tools/region_backup.py verify-retention /path/to/new-retention-plan \
  --user-data /path/to/Voxelverse
```

Die zweite Operation berechnet den Bericht aus den tatsächlichen Quelldaten
erneut. Sie erkennt geänderte, hinzugefügte und entfernte Dateien sowie manipulierte
Berichte, auch wenn deren mitgelieferte Prüfsummen neu berechnet wurden.
Ein früherer Bericht bleibt historischer Nachweis seines unveränderten Bestands;
nach einer Änderung ist ein neuer Bericht unter einem neuen Zielnamen erforderlich.

| Datei | Inhalt |
| --- | --- |
| `region-retention.json` | Format `voxelverse_region_retention_v1`, Schema 1, Generation, Zähler, Berichtshashes und ausdrückliche Aufbewahrungspolitik |
| `files.jsonl` | Vollständiges Dateiverzeichnis mit Pfad, Typ, Länge und SHA-256; keine kopierten Nutzdaten |
| `owners.jsonl` | Alle Dateien außerhalb des kanonischen Blobbestands, ihr Inhaltshash, JSON-/Opaque-Status und Anzahl erkannter Wurzeln |
| `roots.jsonl` | Quelldatei, Quellhash, JSON-Pointer, Wurzelhash und Prüfvertrag; `/@json` kennzeichnet eingebetteten Quelltext |
| `blobs.jsonl` | Jede vorhandene kanonische Blobdatei einmal, Bytezahl, Erreichbarkeit über bekannte Wurzeln und Aktion `retain` |

Wurzelzähler enthalten auch leere Manifeste. Die bekannte Erreichbarkeit wird
global dedupliziert; gemeinsam genutzte Blobs zählen bei Byte-/Dateisummen nur
einmal. Eine temporäre SQLite-Datei mit 2-MiB-Seitencache hält den Index auf Platte.
JSONL-Berichte werden fortlaufend geschrieben. Die vorhandenen Grenzen für
Quellbaum, JSON, Blobgröße und Trie gelten weiter; zusätzlich höchstens
100.000 Wurzelverweise und 128 JSON-Verschachtelungsebenen. Budgetüberschreitungen
brechen ab und kürzen keine Quelle.

## Veröffentlichung und Grenzen

Ein exklusiver Ziel-Lock verhindert konkurrierende Veröffentlichungen desselben
Namens. Das Werkzeug schreibt in einen temporären Geschwisterordner, prüft die
Berichtsbytes und liest danach den vollständigen Quellbaum erneut gegen das
Inventar. Erst dann wird der Ordner umbenannt. Schreib-/Prüf-/Umbenennungsfehler
lassen frühere Berichte und Quelldaten unverändert. Nach hartem Prozessende können
Lock und `.partial-…` verbleiben; diese sind keine veröffentlichte Generation.
Der Nachweis umfasst injizierte Fehler, keinen Stromausfall oder feindliche
Dateisystemrennen. Es gibt weiterhin keinen gemeinsamen Writer-Lock für Live-Daten.

**Das Ergebnis ist eine Aufbewahrungsplanung ohne Löschung.** `policy=retain_all`
und `deletion_allowed=false` sind Bestandteil des überprüften Formats.
`not_referenced_by_known_roots` bedeutet nur, dass die bekannten Adapter keinen
Verweis fanden. Unbekannte JSON-Felder, binäre Daten, spätere externe Verweise
und noch nicht koordinierte Schreiber erlauben daraus keinen Löschschluss.
Auch solche Dateien und alle nicht referenzierten Blobs erhalten `retain`.
Ein erfolgreich gescanntes JSON ist keine umfassende Spielstandsvalidierung.

Der Bericht enthält keine Blobs und ist kein portables Backup. Für Sicherung und
Wiederherstellung bleibt `export-user-data` mit `verify-user-data` zuständig.
Es gibt keinen neuen Laufzeit-Save, keine Save-Schemaänderung und keine Arbeit
pro Spielframe. Automatische Bereinigung, Live-Writer-Koordination und Menüanschluss
bleiben nachfolgende Teilaufträge.

## Prüfung und Übergabe

Der neue Python-Test läuft einmal in `region-backup-validate.yml`.
Der vorhandene native Gesamtexport-/Neustarttest prüft zusätzlich die Generation
vor Export und nach Wiederherstellung an einem anderen Pfad. Derselbe bestehende
Godot-Probe liest danach Regionen und Labordaten; kein zusätzlicher Godot-Test
wird erfunden oder doppelt im Vertragsregister eingetragen.

Gezielter Fachlauf aus `tests/tooling`:

```bash
python -m unittest region_retention_test.RegionRetentionTest \
  region_backup_test.RegionBackupTest \
  region_backup_places_test.PlaceBackupTest \
  region_backup_userdata_test.UserdataBackupTest -v

GODOT_BINARY=/path/to/godot python -m unittest \
  region_backup_userdata_test.NativeUserdataBackupTest -v
```

Godot 4.6.3, Linux Headless, ausschließlich isolierte Benutzerdaten des vorhandenen
Runners. Import und Quellenverträge werden einmal vor dem nativen Lauf geprüft.
Quellcommit, ausgeführte Ergebnisse und Grenzen stehen in der PR-Übergabe.
Kein Gesamtspiel-, Export-, Rendering- oder Ziel-PC-FPS-Nachweis. Zentrale
Statusdokumente aktualisiert der Integrationschat nach Übernahme dieses Teilpakets.
