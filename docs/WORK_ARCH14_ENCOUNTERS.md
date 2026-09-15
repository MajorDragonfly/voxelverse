# ARCH-14-ENCOUNTERS — Dauerhafte Begegnungen auslagern

Basis: `d378ca0ecd7f03429a5150df6358e0646ec06689` (main nach PR #92).
Fachbranch: `agent/arch14-encounters-20260915`. Keine Gesamtfreigabe von ARCH-14.

## Ergebnis und Datenvertrag

Regional verwaltete Tiere speichern Begegnungen bereits in ihren Regionsdaten.
Der verbleibende globale Bestand lag bisher als vollständige Tabelle im RAM und
im Fortschrittssnapshot; bei 32.768 Einträgen scheiterten weitere neue Einträge.
Die reguläre Kugelkampagne verwendet dafür jetzt denselben unveränderlichen
Regionsspeicher mit einer eigenen Wurzel. Ein zusätzlicher Begegnungsbestand
ist nicht eingeführt; `ProgressionService` bleibt der Fachzugriff.

| Bestandteil | Vertrag |
| --- | --- |
| Altes Inlineformat | `{schema: 1, entries: {...}}`; unverändert lesbar, historische Flachweltwerkzeuge bleiben in diesem Format. |
| Kugelarchiv | `{schema: 2, storage: {schema: 1, format: "sha256_trie_v1", root: "..."}}`; keine Eintragsliste im Snapshot. |
| Schlüssel / Nutzdaten | Bestehende `object_id`; Payload `{schema: 1, entry: {...}}`, geprüft gegen den bestehenden Begegnungsvalidator und die Indexidentität. |
| Aktiver Speicher | Höchstens 96 Datensätze und 128 Indexseiten im globalen Archiv; unabhängig von der Zahl besuchter Körper. Regionscaches haben weiterhin ihr eigenes Budget. |
| Erstübernahme | Vollständiger Checkpoint vor Freigabe der Inline-Tabelle. Ein fehlgeschlagener Umbau behält das Original. Die bisherige Save-Datei bleibt bis zum gemeinsamen Commit erhalten. |
| Regionale Übernahme | Bereits archivierte Begegnung übernehmen; erst nach regionalem Checkpoint den globalen Datensatz durch einen Tombstone ersetzen. Historische Wurzeln bleiben unverändert lesbar. |
| Sofortige Aktionen | Beziehung, Gesundheit, Verhaltensbeleg und Punktestand gemeinsam speichern; betroffenen Cacheeintrag bis Commit/Rollback halten. Schreibfehler geben keinen Erfolg frei. |
| Laden / Reset | Ein Wurzelzugriff beim Laden, Begegnungen erst bei Bedarf. Neuer Spielstand verwirft den vorherigen Archivbesitzer. Habitat-Seeds werden am gemeinsamen Leseanschluss wieder Ganzzahlen. |
| Fehler / neuere Formate | Fehlende oder beschädigte Daten erzeugen keinen frischen Standardkontakt. Writer blockieren; verwaltete Spielsitzung nutzt die bestehende Fehleransicht. Neuere Hüllen, Wurzeln und unbekannte Hüllenfelder dürfen nicht über ein altes Backup überschrieben werden. |

Gesundheit, Tod, verzehrte Kadaver, Vertrauen, Feindschaftsursachen und Habitat-
Identitäten bleiben erhalten. Belohnungssperren und Entdeckungen liegen weiter in
ihren bisherigen Fortschrittsmodellen; dieses Paket ändert weder Belohnungsregeln
noch deren Speicherverträge. Karten und Tierkatalog verwenden in der Kugellaufzeit
den bestehenden gezielten Leseanschluss. Historische Flachweltleser bleiben bei
Schema 1; ein bereits segmentierter Quellstand wird nicht irrtümlich als leere
Begegnungstabelle in eine erneute Flachweltmigration geschickt.

## Prüfungen

Godot 4.6.3, Linux/headless, isolierte synthetische Benutzerdaten. Befehle,
Quellcommit/Tree, ursprüngliche Diagnoseläufe und Ergebnisse werden in
`docs/evidence/arch14-encounters/results.json` nachgewiesen.

- `encounter_archive_test`: 1.202 Begegnungen, Cachefreigabe, unveränderliche
  Lesekopien und ältere Wurzeln, echtes altes Inline-Save mit unveränderter
  Backup-Datei, regionale Übernahme samt Neustart, unabhängige Kontakte auf zwei
  Planeten mit gleichem Seed (logischer A–B–A-Wechsel), Scan und einmalige Belohnung.
  Zusätzlich tatsächlicher Save-/Blob-Schreibfehler mit Rollback, fehlgeschlagene
  Migration, Datenkorruption und Schutz neuerer Formate.
- Bestehende Fachtests prüfen regionale Tiere, spielbare Sozial-/Kampfaktionen
  und die Übernahme entwickelter alter Spielstände. Kein neuer Vollsuite-Lauf.
- Backup-Tests prüfen Archivwurzel, historische Generationen, Tombstones,
  fehlende Dateien sowie semantisch falsche Daten trotz gültiger Prüfsumme.
  Der native Backuplauf exportiert die echten Kampagnendateien und startet Godot
  mit einem neuen Benutzerverzeichnis, nachdem das Originalarchiv unerreichbar
  gemacht wurde. Dort bleiben beide Körper, Kontakte, Scan und Belohnung erhalten.

```sh
python3 tools/validate_godot.py --godot GODOT --skip-main --tests encounter_archive_test population_register_test creature_behavior_gameplay_test spherical_developed_migration_test
GODOT_BINARY=GODOT python3 -m unittest discover -s tests/tooling -p region_backup_test.py -v
```

## Integration und Grenzen

Schreibbereiche: Begegnungsmodell/-fassade, regionaler Übernahmeadapter,
Fehlerbehandlung des Sozialbausteins, Backup-Adapter, gezielte Prüfungen und
Vertragsdokumentation. Kein HUD-, Editor-, Terrain- oder Dorfumbau.

PR #93 (ARCH-13-MANIFEST) ergänzt andere Abschnitte von `tools/region_backup.py`
und Workflow-Pfaden; beide Ergänzungen bei der Integration erhalten. Der dortige
Aufbewahrungsplan erkennt das Archiv auch als generischen Trie und erhält alle
Dateien. Seine Fachkennzeichnung für Begegnungsarchive bleibt eine mögliche
spätere Ergänzung. Der hier erweiterte Backup-Leser prüft die Begegnungspayloads.
`encounter_archive_test` ist genau einmal bei `regions_simulation` registriert.
Die zentrale Rundenbelegung und Status-/Backlogseiten aktualisiert die Integration.

Die einmalige Übernahme alter Tabellen und einzelne synchrone Dateizugriffe sind
noch kein garantiertes Framezeitbudget. Der globale Archivbestand wächst auf dem
Datenträger weiter; automatische Löschung ist nicht enthalten. Entdeckungslisten,
Verhaltensbelege und sonstige Langzeitregister sind eigene Folgeschritte. Kein
Windows-Export, grafischer Langzeittest, produktiver Reiseablauf oder Ziel-PC-/FPS-
Nachweis; die gemeinsame Integration prüft ihren tatsächlichen Merge-Stand.
