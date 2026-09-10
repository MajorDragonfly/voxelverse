# ARCH-13 – Kartenwissen vollständig mitsichern

Folgepaket vom 10. September 2026 auf dem eigenen
[Regionssicherungsexport, PR #62](https://github.com/MajorDragonfly/voxelverse/pull/62).
Branch: `agent/arch13-atlas-backups-2026-09-10`.

## Auftrag und bestehende Roadmap

Lars hat die Umsetzung bestätigt, sofern sie in den bestehenden Arbeitspaketen
und der Roadmap vorgesehen ist. Diese Zuordnung wurde vor der Umsetzung geprüft:

| Planungsquelle | Verbindlicher Anschluss dieser Lieferung |
| --- | --- |
| [ROADMAP.md](../ROADMAP.md), Architekturprüfung / Langzeitbetrieb | ARCH-13–18 gehören zu M1h: dauerhafte Regionen und Register |
| [ARCH-13](ARCHITECTURE_BACKLOG.md#arch-13--regionsspeicherung-mit-gemeinsamem-commit) | Sicherungen, Historie, Slotkopien und Umzugsarchive erhalten sämtliche referenzierten Segmente |
| [ARCH-14](ARCHITECTURE_BACKLOG.md#arch-14--langzeitregister-auslagern) | Erkundetes Kartenwissen bleibt trotz ausgelagerter Kacheln und Neustart erhalten |
| [Atlas-Übergabe aus PR #59](https://github.com/MajorDragonfly/voxelverse/blob/57a330fc5e064ea0cda221e2f8e86140e8685f8f/docs/WORK_ARCH14_ATLAS_PAGING.md) | ARCH-13 verfolgt zusätzliche aktuelle und archivierte Atlas-Wurzeln |

Das ist eine Umsetzung des bestehenden ARCH-13-Anschlusses an ARCH-14.
Die gemeinsamen Statusdateien bleiben gemäß
[Integrationsregel](NEXT_PARALLEL_WORK.md#übergabe-und-zusammenführung) beim
Integrationsbesitzer. Weder ARCH-13 insgesamt noch das gesamte M1h wird hier
abgeschlossen.

## Verhalten und Speichervertrag

Die vorhandenen `export`-/`verify`-Befehle benötigen keine neuen Argumente.
Für jeden ausgewählten Kampagnenslot werden zusätzlich diese Stellen geprüft:

- `game_state.campaign.bodies[*].exploration_atlas`
- `game_state.campaign.bodies[*].legacy_exploration_atlas`
- Beide Felder in den rekursiv erfassten, checksumgeprüften
  `surface_migration.source_text`-Originalarchiven.

Hauptdatei, `.bak`, Historie und separat ausgewählte Slotkopien durchlaufen
denselben Anschluss. Auch Körper ohne Population oder mit Inline-Population
werden berücksichtigt. Körper-IDs, gespeicherte Heimatmarker, Ausdehnung und
offene Erkundungsbits bleiben in den bytegleichen Snapshotdateien erhalten.

Atlas 1 bleibt inline. Atlas 2 enthält das vorhandene Schema-1-Manifest des
`sha256_trie_v1`-RegionStore und bis zu 96 offene Kacheln. Die Sicherung verfolgt
alle vom Manifest erreichbaren Dateien, einschließlich überlagerter früherer
Kachelwerte; ein noch offener neuer Wert versteckt keine beschädigte alte Datei.
Sie übernimmt den offenen Puffer ohne einen zusätzlichen Spiel-Save oder
Checkpoint. Alte und neue Wurzeln bleiben unveränderlich und können Blobs teilen.

Neben den vorhandenen Hash-, Trie- und Pfadprüfungen validiert der Export die
Atlas-Version, Körperzuordnung, Projektion, Auflösung, Kachelschlüssel und die
32 vorzeichenlosen 32-Bit-Maskenzeilen jeder referenzierten Kachel. Das umfasst
auch negative alte Flächenkoordinaten und Bit 31. Unbekannte Atlas-/Kachelversionen,
zusätzliche nicht unterstützte Atlas-/Kachelfelder und künftige Speicherformate
werden ausdrücklich abgelehnt. Fehlende oder defekte tiefe Kacheln führen ebenfalls
zum Abbruch, bevor eine vollständige Sicherung veröffentlicht wird.

Der gemeinsame Regionswalker hält weiterhin einen begrenzten Tiefensuchstapel
und keinen weltweiten Kachelsatz. Die Budgets aus PR #62 gelten unverändert:
2 MiB pro Blob, 64 MiB pro Snapshot, 16 MiB pro Migrationsquelle, Archivtiefe 8 und
höchstens 4.096 ausgewählte Snapshotdateien. Originale und frühere Sicherungen
werden nicht geändert. Der normale SaveGameService prüft beim Laden weiterhin
die vollständigen Spiel-Fachregeln einschließlich der Ortsmarker.

## Nachweis mit dem veröffentlichten Atlas-Code

`tools/atlas_backup_probe.gd` läuft in einem getrennten Checkout von
`57a330fc5e064ea0cda221e2f8e86140e8685f8f` (fertiges Atlas-Teilpaket #59).
Der neue Exporter und die Probe stammen aus dieser Lieferung. Der Referenzcode
wird für die Prüfung benutzt und nicht in diesen Fachbranch übernommen.

Die Probe erstellt über den echten Atlas und SaveGameService eine Kugelkampagne
mit 1.200 erkundeten Kacheln auf sechs Flächen und einer alten Flächenkarte mit
130 Kacheln. Sie speichert zwei Generationen, einen Heimatmarker und zuletzt
acht offene Kacheln, darunter zusätzliche Bits einer bereits gespeicherten
Kachel sowie Wissen an Flächennaht und Pol. Die CLI exportiert vier Stände mit
den vollständigen Dateien. Danach ist das ursprüngliche Blobverzeichnis am
Quellpfad nicht mehr verfügbar. Ein frischer Godot-Prozess lädt das exportierte
Datenverzeichnis und prüft jede Kachel der drei nichtleeren Atlasstände.

| Prüfung | Ergebnis |
| --- | --- |
| Werkzeugtests einschließlich zweier nativer Neustartprüfungen | 18 bestanden, keine übersprungen |
| Native Atlasprüfung: exportierte Snapshots / Wurzelverweise | 4 / 6 |
| Wiederhergestellte Kugelkachel-Abfragen | 3.600 |
| Wiederhergestellte historische Flächenkachel-Abfragen | 390 |
| Offene Kacheln im aktuellen Snapshot | 8, einschließlich Änderung an bestehender Kachel |
| Höchster Atlas-Cache / residente Trie-Seiten | 96 / 128 |
| Kopierte Dateien / Blob-Nutzbytes | 1.622 / 436.917 |
| Geprüfte Blobverweise / höchster Suchstapel | 4.854 / 38 |
| Kampagne, Körper, Heimatmarker, alte/neue Bits und unerforschte Gebiete | korrekt erhalten |
| Bestehende Population-Neustartprüfung | weiterhin 3.600 Regionsabfragen, Cache höchstens 96 |

Die Python-Fälle prüfen außerdem mehrere Körper und Slots, Historie und
Migrationsquellen, beschädigte tiefe Kacheln trotz gültiger Hashes, Zukunftsverträge
an allen Archivstellen, Inline-/leere Karten, überschrittene Pufferbudgets sowie
den Wechsel der Quellwurzel während des Exports. Bereits erzeugte Sicherungen,
denen die Atlasdateien fehlen, fallen in `verify` auf.

Import und Art-Quellenprüfung bestehen sowohl auf diesem Fachbranch als auch
auf dem veröffentlichten Atlas-Referenzstand. Die eigene CI richtet denselben
gepinnten Referenz-Checkout ein. Lokal nach den beiden Projektimporten:

```bash
GODOT_BINARY=/path/to/godot \
ATLAS_BACKUP_PROJECT=/path/to/checkout-of-57a330fc \
python -m unittest discover -s tests/tooling -p 'region_backup_test.py' -v
```

Ohne die beiden Umgebungsvariablen ist die native Atlasprüfung ausdrücklich
übersprungen. Für die dokumentierte Abnahme waren beide gesetzt. Die Tests
erzeugen echte Speicherdateien mit synthetischen Erkundungsadressen; sie sind
keine visuelle Spielroute und kein Ziel-PC-/FPS-Nachweis.

## Integration und verbleibende Grenzen

- Der PR baut auf dem eigenen PR #62 auf und zeigt nur diese Fortsetzung.
  Zum Laden paginierter Karten wird zusätzlich der Atlas-Code aus PR #59
  benötigt. Die gepinnte Prüfung ersetzt keine gemeinsame Integrationsabnahme.
- Das neue Ortsregister aus PR #65 war bei Übernahme noch in Arbeit. Sein
  künftiger veröffentlichter Vertrag benötigt einen eigenen Anschluss. Neuere
  Atlasversionen oder unbekannte Zusatzfelder werden bis dahin blockiert.
- Separate Labor-Dateien mit `map_atlases` sind keine Kampagnenslots und werden
  von der bisherigen `--slot`-CLI nicht angenommen. Ihr Dateiformat und ihre
  Auswahl gehören zu einem weiteren Sicherungsanschluss.
- Weiterhin kein globales Save-Manifest, keine automatische Bereinigung, kein
  Backup-Menü und kein Überschreiben belegter Wiederherstellungsverzeichnisse.
  Save-/Atlasformate, ID-Vergabe und laufende Spielsysteme bleiben bei ihren
  bestehenden Besitzern.

Die konkreten Quellenrevisionen und Rohwerte stehen in
[ARCH13_ATLAS_BACKUP_RESULTS.json](ARCH13_ATLAS_BACKUP_RESULTS.json) und dem
[Prüfprotokoll](evidence/arch13/atlas-backup-tests.log).
