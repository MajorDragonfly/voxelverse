# ARCH-13 – Vollständige Benutzerdateien einschließlich Laborständen

Teilpaket vom 10. September 2026. Basis: veröffentlichter `main`
`bb2f83b56267964baa7037720c4daca26fe3d007`. Branch:
`agent/arch13-full-userdata-backups-2026-09-10`.

## Gelieferter Umfang

Der vorhandene `tools/region_backup.py` erhält `export-user-data` und
`verify-user-data`. Der vollständige Export erhält alle regulären Dateien und
leeren Verzeichnisse eines **beendeten** Spiels, einschließlich sämtlicher Slots,
Backups, Slothistorien, Kopien, Migrationsoriginale, D2-/D3-Laborstände,
Planeten-/Oberflächenlabore, Galaxieentdeckungen, Rückkehrorte, loser Entwürfe,
lokaler Vorlagen, Einstellungen und aller Regionsdateien. Auch sonstige
unbekannte Dateien, unterbrochene Schreibdateien und Logs werden erhalten.

Die bisherige Auswahl einzelner Slots über `export` bleibt unverändert; sie
prüft die bekannten Population-/Atlas-/Ortsreferenzen. Der neue Gesamtexport
interpretiert keine Spielstände: Auch ältere, beschädigte oder zukünftige
Formate bleiben bytegenau erhalten. Erfolgreiches `verify-user-data` bestätigt
die vollständige Dateikopie, **nicht die spielinterne Gültigkeit** beliebiger
Quelldaten. Beim Laden gelten die vorhandenen Fachvalidatoren und Versionssperren.

## Verwendung und Wiederherstellung

Python 3.10+, keine zusätzlichen Pakete. Spiel und Editor vor Beginn schließen;
auch andere Programme dürfen das ausgewählte Benutzerverzeichnis nicht ändern.
Die Eingaben sind Dateisystempfade, keine `user://`-Adressen.

```bash
python tools/region_backup.py export-user-data \
  --user-data /path/to/Voxelverse \
  --output /path/to/new-full-backup

python tools/region_backup.py verify-user-data /path/to/new-full-backup
```

| Inhalt im Export | Vertrag |
| --- | --- |
| `userdata/` | Unveränderte Quelldateien mit denselben relativen Namen, einschließlich aller Regionsdateien |
| `files.jsonl` | Dateiverzeichnis in deterministischer Tiefenreihenfolge; Dateien mit Länge und SHA-256, Verzeichnisse mit Typ und Pfad |
| `userdata-backup.json` | Format `voxelverse_userdata_backup_v1`, Schema 1, Prüfart `exact_file_bytes`, Anzahlen, Gesamtbytes und SHA-256 des Dateiverzeichnisses |

Zur Wiederherstellung zuerst das Archiv prüfen. Anschließend bei geschlossenem
Spiel den **Inhalt von `userdata/`** in ein neues, leeres Godot-Benutzerverzeichnis
kopieren und dieses starten. Das äußere Archivverzeichnis ist kein direktes
Godot-Benutzerverzeichnis. Keine Dateien in eine schon belegte Installation
hineinmischen. Quellinstallation und unverändertes Archiv aufbewahren.

Dateirechte, Zeitstempel und andere Betriebssystem-Metadaten werden nicht
archiviert. Symlinks, FIFOs und andere Spezialdateien sowie Dateinamen mit
Doppelpunkt oder Backslash werden ausdrücklich abgelehnt.

## Veröffentlichung, Schutz und Grenzen

Der Export reserviert einen neuen Zielnamen exklusiv und schreibt zunächst in
ein temporäres Geschwisterverzeichnis. Dateien werden in 1-MiB-Blöcken kopiert;
das JSONL-Verzeichnis wird fortlaufend geschrieben. Es gibt keine globale
Hashmenge aller Regionsdateien im Arbeitsspeicher. Je Verzeichnis werden die
Namen für die deterministische Reihenfolge sortiert.

Nach dem Schreiben werden sämtliche Zieldateien erneut gelesen und geprüft.
Danach wird der komplette Quellbaum erneut gegen dasselbe Dateiverzeichnis
verglichen. Erfasste Änderungen, Hinzufügungen und Löschungen verhindern die
Veröffentlichung. Änderungen während eines einzelnen Lesevorgangs werden
zusätzlich anhand Dateikennung, Größe und Änderungsdaten geprüft. Erst nach
beiden Prüfungen wird das Zielverzeichnis atomar umbenannt.

Die erneute Quellprüfung ersetzt keinen gemeinsamen Writer-Lock: Dieser Export
ist **kein Live-Snapshot**. Er garantiert keine atomare Aufnahme konkurrierender
Spielprozesse. Hartes Prozessende kann einen `.partial-…`-Ordner und die
Zielreservierung hinterlassen; diese sind keine fertige Sicherung. Die Tests
decken Schreib-/Veröffentlichungsfehler ab, keinen Stromausfallnachweis.

Der Verifizierer läuft den tatsächlichen Zielbaum ab und vergleicht die
Manifestzeilen in derselben Reihenfolge. Manifestpfade werden nicht zum Öffnen
von Dateien verwendet. Fehlende/zusätzliche Dateien, doppelte oder fremde Pfade,
Prüfsummenänderungen und unbekannte Archivversionen werden abgelehnt. SHA-256
prüft die Integrität; das Archiv ist nicht signiert.

Budgets: maximal 1.000.000 Dateien/Verzeichnisse, 16.384 Einträge je Verzeichnis,
64 verschachtelte Verzeichnisebenen und 64 KiB je Manifestzeile. Überschreitung
bricht ab und kürzt keine Quelldaten. Das sind Exportbudgets, keine Spielgrenzen.
Alle Blobs bleiben erhalten; der Gesamtexport kann daher deutlich größer sein
als ein Export ausgewählter Slots.

## Tatsächlich ausgeführte Abnahme

Godot 4.6.3 Stable, Linux, Headless; ausschließlich isolierte Testdaten.
[Maschinenlesbare Ergebnisse](ARCH13_USERDATA_BACKUP_RESULTS.json).

| Prüfung | Ergebnis |
| --- | --- |
| Neuer Gesamtexport samt nativer Wiederherstellung | 10 Tests bestanden, nichts übersprungen |
| Bisherige Population-/Atlas-/Orts-Fehlerprüfungen | 22 Tests bestanden, nichts übersprungen |
| Godot-Import, Quellenverträge und Art-Quellenprüfung | bestanden |
| Dateien / Verzeichnisse im nativen Export | 9.668 / 265 |
| Kopierte Nutzbytes | 7.258.902 |
| Regionszugriffe nach Neustart | 3.600, Cache maximal 96 Einträge |
| Labor-Atlas nach Neustart | 130 besuchte Kacheln aus externen Blobs erhalten |
| D2-Labor | aktueller Bestand 8, vorheriger Bestand 12, Freundschaft erhalten |
| Weitere Verbraucher | D3-Snapshot über SaveGameService, Galaxieentdeckung und lokale Kreaturenvorlage gelesen |
| Zukünftiger D2-Stand mit älterem Backup | Original erhalten, Laden/Schreiben weiterhin gesperrt |

Der native Nachweis erzeugt zuerst 1.200 Regionsdatensätze in mehreren
Generationen mit dem bestehenden RegionStore und SaveGameService. Ein zweiter
Prozess schreibt die zusätzlichen Labor-/Vorlagendaten mit deren bestehenden
Schreibern. Nach Export und Verifikation wird das ursprüngliche vollständige
Benutzerverzeichnis umbenannt. Ausschließlich die wiederhergestellte Kopie wird
in frischen Prozessen geprüft. Die Archive werden nicht als aktive
Spielverzeichnisse verwendet.

```bash
GODOT_BINARY=/path/to/godot python -m unittest discover \
  -s tests/tooling -p 'region_backup_userdata_test.py' -v

cd tests/tooling
python -m unittest region_backup_test.RegionBackupTest \
  region_backup_places_test.PlaceBackupTest -v
```

Der neue `userdata_backup_probe.gd` ist ein vom Python-Test gestarteter
Schreiber/Leser, kein eigenständiger `*_test.gd`. Er läuft genau einmal in der
erweiterten `region-backup-validate.yml`; das GDScript-Vertragsregister erhält
keinen doppelten Testeintrag. Der vorhandene Regionsprobe erkennt nun neben
Slots liegende Migrationsoriginale und wählt diese nicht versehentlich als
aktiven Spielstand.

## Übergabe und offene ARCH-13-Arbeiten

Geändert: bestehendes Export-CLI, neuer Gesamtexport-Adapter, Python-Abnahme,
neuer Godot-Probe, begrenzter Auswahlfix im bestehenden Regionsprobe und
die vorhandene Backup-CI. Gemeinsamer SaveGameService, RegionStore,
Fachregister, Spielschemata, Sprachkatalog und Szenen bleiben unverändert.
ARCH-06/-07/-14/-22/-24/-25 werden nicht vorweggenommen.

Damit ist der Teilauftrag **vollständige Benutzerdateien/Laborarchive**
abgeschlossen. Kleines globales Kampagnenmanifest, GC/Bereinigung alter Blobs,
Writer-Koordination für Live-Sicherungen und Backup-Menü bleiben eigene offene
ARCH-13-Anschlüsse. Dieser Gesamtexport liefert **keinen Beleg zum Löschen**
alter Blobs. Die gemeinsame Integration soll diesen Bericht bei ARCH-13 in
`NEXT_PARALLEL_WORK.md`/`ARCHITECTURE_BACKLOG.md` ergänzen; die parallel
bearbeiteten Sammeldokumente werden in diesem Fachbranch nicht überschrieben.
