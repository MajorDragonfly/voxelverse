# ARCH-13 – Vollständige Regionssicherungen

Abgegrenztes Teilpaket vom 10. September 2026. Basis: veröffentlichter `main`
`ea900f2e09946660694a9e59399b4680a5655a85`. Branch:
`agent/arch13-region-backups-2026-09-10`.

Die [Atlas-Fortsetzung](WORK_ARCH13_ATLAS_BACKUPS.md) ergänzt auf dieser Lieferung
die vollständigen Wurzeln aktueller und archivierter Kampagnenkarten gemäß dem
veröffentlichten ARCH-14-Vertrag aus PR #59. Die zwölf Prüfungen und Messwerte
unten dokumentieren die ursprüngliche Population-Lieferung; die Fortsetzung
enthält den zusätzlichen Karten-/Neustartnachweis.

## Zweck und Zuständigkeit

Ein Save-JSON verweist bei `surface_population.schema = 2` auf den vorhandenen
`sha256_trie_v1`-Regionsspeicher. Die JSON-Datei allein enthält dann nicht mehr
alle gespeicherten Änderungen. `tools/region_backup.py` exportiert ausgewählte
Slots und ihre vollständigen Regionsabhängigkeiten in ein neues Verzeichnis.
Es verarbeitet gespeicherte Snapshots; ungespeicherte Laufzeitänderungen werden
nicht erfasst. Der bestehende `SaveGameService` bleibt alleiniger Besitzer des
laufenden Kampagnenabschlusses.

Dieses Paket betrifft den Export, die Referenzprüfung und den Wiederanlauf aus
einer vollständigen Sicherung. Es ergänzt **keine automatische Bereinigung**
alter Regionsdateien und stellt weder das globale Save-Manifest noch Atlas-/Tier-
Register auf neue Formate um. Die übrigen ARCH-13/14-Punkte bleiben offen.
ARCH-17, ARCH-18, ARCH-20/21/22, ARCH-24/25 und ARCH-28 bleiben bei ihren
Fachpaketen. Gemeinsame Roadmap, SaveGameService, GameState, Surface-Population,
RegionStore und SlotHistory werden nicht verändert.

## Verwendung

Python 3.10 oder neuer; keine zusätzlichen Python-Pakete und kein Godot-Prozess
für den Export erforderlich. Die Eingaben sind Dateisystempfade:

```bash
python tools/region_backup.py export \
  --slot /path/to/Voxelverse/saves/slot_example.json \
  --regions-dir /path/to/Voxelverse/regions/blobs \
  --output /path/to/new-backup

python tools/region_backup.py verify /path/to/new-backup
```

`--slot` kann für mehrere Slots wiederholt werden. Der Export nimmt automatisch
die vorhandene Hauptdatei, `.bak` und alle `snapshot_*.json`-Dateien in deren
`.history` mit. Auch ein Slot, von dem nur Backup/Historie vorhanden ist, kann
gesichert werden. Gleiche Slot-Dateinamen aus verschiedenen Quellverzeichnissen
werden ausdrücklich abgelehnt, um gegenseitiges Überschreiben zu verhindern.

Das Ergebnis besitzt direkt die bestehende Godot-Benutzerdatenstruktur:

| Inhalt | Zielpfad / Bedeutung |
| --- | --- |
| Ausgewählte Slots | `saves/slot_….json`, unveränderte Quelldateibytes |
| Backup und Historie | Ursprüngliche `.bak`- und `.history`-Pfade neben dem Slot |
| Alter Standardslot | `voxelverse_save.json` samt vorhandenem Backup/Historie |
| Benötigte Regionsdateien | `regions/blobs/<2 Hexzeichen>/<SHA-256>.json` |
| Abschlussrecord | `region-backup.json`, Exportformat 1, Snapshotpfade und Prüfsummen |

Für eine Wiederherstellung zuerst `verify` ausführen und das vollständige
Verzeichnis in einem **frischen** Godot-Benutzerdatenverzeichnis verwenden.
Slots und `regions/blobs` gehören zusammen. Der Test dieses Pakets verwendet
genau diesen Weg mit dem unveränderten SaveGameService in einem neuen Prozess.
Ein Menüknopf für Export/Wiederherstellung und das Zusammenlegen mit einem
bereits belegten Benutzerdatenverzeichnis sind nicht Bestandteil dieses Pakets.

## Vollständigkeit, Originale und Grenzen

- Bekannte Save-Versionen 3–9, GameState 1–4 und Kampagne 1–3 werden ausschließlich
  gelesen. Integrierte Entwürfe, Fortschritt, Fracht, Karten und IDs bleiben in
  ihren unveränderten JSON-Dateien. Alte Saves 1/2 werden ausdrücklich abgelehnt,
  weil sie noch lose Editor-Dateien benötigen können; dafür zuerst die bestehende
  Spielmigration verwenden.
- Monolithische Population 1 bleibt unverändert in der JSON-Datei. Population 2
  wird über ihr vorhandenes Schema-1-Regionsmanifest vollständig verfolgt.
  Die Atlas-Fortsetzung verfolgt außerdem `exploration_atlas.storage` und
  `legacy_exploration_atlas.storage` (Atlas 2); offene Kacheln und bestehende
  Inline-Atlanten bleiben vollständig in den unveränderten Snapshotbytes.
  Bekannte Umzugsarchive in `surface_migration.source_text` werden rekursiv
  berücksichtigt und gegen `source_sha256` geprüft. Ihre Originaltexte werden
  nicht neu serialisiert. Unbekannte Speicher-/Kampagnen-/Archivversionen brechen
  den Export ab; es erfolgt kein stiller Rückfall auf `.bak`.
- Jede Regionsdatei muss ihren SHA-256 erfüllen. Branch-/Leaf-Struktur, bestehende
  16-/32-Eintragsgrenzen, maximale SHA-256-Tiefe, Indexpfad und der zur Indexadresse
  passende Payload-Schlüssel werden geprüft. Ein gültiger Hash allein genügt
  nicht. Das Tool prüft Speicherstruktur und Referenzen; sämtliche spielinternen
  Fachregeln bleiben zusätzlich Aufgabe des normalen Ladevalidators.
- Tiefensuche verarbeitet Dateien einzeln, jede mit maximal 2 MiB, und hält einen
  begrenzten Stapel offener Verweise. Es gibt keinen mit allen Regionen wachsenden Cache oder globalen
  Hash-Mengenindex. Der Stapel ist durch 64 Trie-Ebenen, höchstens 15 offene
  Geschwister je Ebene und 32 Leaf-Werte begrenzt. Bereits kopierte Blobs werden
  über ihre Inhaltsadresse geteilt; gemeinsame Historien werden erneut geprüft.
- Pro Snapshot gilt ein explizites 64-MiB-Eingabebudget; Quellarchive behalten das
  vorhandene 16-MiB-Limit. Der Snapshotplan ist auf 4.096 Dateien und Archivtiefe 8
  begrenzt. Überschreitung ist ein Fehler und verwirft keine Quelldaten. Diese
  Exportgrenzen sind keine neuen Kampagnen- oder Spielregeln.
- Der Export schreibt in ein eigenes temporäres Geschwisterverzeichnis. Alle
  Snapshot- und Blobdateien werden nach dem Schreiben gegengelesen. Anschließend
  prüft `verify` das gesamte **Ziel**, bevor das Verzeichnis atomar unter seinem
  endgültigen Namen veröffentlicht wird. Bereits bestehende Ziele werden nicht
  überschrieben. Ein exklusiver Lock verhindert konkurrierende Exporte desselben
  Ziels. Ein hart abgebrochener Prozess kann ein `.partial-…`-Verzeichnis und einen
  Lock hinterlassen; das ist keine veröffentlichte Sicherung. Nach Prüfung, dass
  der Prozess beendet ist, kann ein neuer Zielname verwendet werden.
- Fehlende/defekte Dateien und Schreib-/Veröffentlichungsfehler erzeugen kein
  vollständig markiertes Ziel. Quellen und frühere Sicherungen bleiben erhalten.
  Hashdateien ohne Verweis aus den ausgewählten Snapshots werden nicht kopiert
  und auch nicht gelöscht. Der Exportbestand ist deshalb **kein GC-Beleg** für
  andere Slots, Kopien, Archive oder gerade erst erzeugte Laufzeitgenerationen.

## Abnahme

`tests/tooling/region_backup_test.py` prüft Export/Verifikation, aktuelle und alte
Wurzeln, Historie, Umzugsarchive, mehrere Slots, Inline- und leere Speicher,
unreferenzierte Dateien, falsche Payload-Zuordnung trotz gültiger Prüfsumme,
korrupten/fehlenden Inhalt, Zukunftsversionen, Pfade/Symlinks, Budgets,
Schreibunterbrechung, Veröffentlichung und unveränderte frühere Sicherungen.
Ein Quell-Slot darf nach seiner Erfassung auf eine neue Wurzel wechseln: Das
Exportziel enthält weiterhin exakt die erfassten Bytes und deren Generation.

Der tatsächliche Godot-Nachweis läuft über `tools/region_backup_probe.gd`: Der
unveränderte RegionStore schreibt 1.200 Datensätze mit Bestand/Fracht in zwei
Generationen; SaveGameService erzeugt Hauptdatei, Backup und Historie. Die CLI
exportiert und verifiziert sie. Anschließend ist das ursprüngliche Blobverzeichnis
nicht mehr am Quellpfad vorhanden. Ein frischer Godot-Prozess lädt den Export
über SaveGameService und prüft alle referenzierten Generationen mit begrenztem
RegionStore-Cache. Dies sind synthetische Regionsdaten, kein zusätzlicher
Darstellungs-/Tierhaltungs- oder Ziel-PC-Leistungsnachweis.

```bash
python tools/validate_godot.py --godot /path/to/godot \
  --skip-main --tests region_store_test
GODOT_BINARY=/path/to/godot python -m unittest discover \
  -s tests/tooling -p 'region_backup_test.py' -v
```

Die eigene `region-backup-validate.yml` führt Import und diesen gezielten
Godot-/CLI-Nachweis aus. Das allgemeine Vertragsregister von ARCH-29 bleibt beim
dortigen Besitzer; der neue GDScript-Probe wird vom Python-Test gestartet und
ist kein zweiter eigenständig auszuführender `*_test.gd`-Test.

Die zwölf lokalen Prüfungen bestanden ohne übersprungene Tests. Import,
Art-Quellenprüfung und der bestehende `region_store_test` bestanden ebenfalls.
[Ergebnisse](ARCH13_REGION_BACKUP_RESULTS.json) und
[Rohprotokoll](evidence/arch13/region-backup-tests.log) halten den Nachweis fest.

| Tatsächlicher Godot-/CLI-Probe | Ergebnis |
| --- | --- |
| Verschiedene Regionen pro Generation | 1.200 |
| Exportierte Haupt-/Backup-/Historien-Dateien | 4 |
| Referenzierte nichtleere Roots | 3 |
| Geprüfte Blobverweise / tatsächlich kopierte Dateien | 4.416 / 2.944 |
| Kopierte Blob-Nutzbytes | 467.860 |
| Höchster Stapel offener Verweise | 35 |
| Regionszugriffe nach frischem Prozessstart | 3.600 |
| Höchster Godot-Regionscache | 96 Einträge |
| Körper-/Kampagnenidentität und Bestand/Fracht | erhalten |
Bei weiteren segmentierten Fachregistern muss `_roots` um deren veröffentlichten
Speichervertrag erweitert werden. Erst nach dem vollständigen globalen
Referenzinventar darf ARCH-13 eine Bereinigung historischer Blobs anschließen.
