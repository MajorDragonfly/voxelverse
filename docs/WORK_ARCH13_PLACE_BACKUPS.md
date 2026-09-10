# ARCH-13 – Bekannte Orte vollständig mitsichern

Folgepaket vom 10. September 2026 auf dem eigenen
[Atlas-Export, PR #71](https://github.com/MajorDragonfly/voxelverse/pull/71).
Branch: `agent/arch13-place-backups-2026-09-10`.

## Auftrag und Zuordnung

[ROADMAP.md](../ROADMAP.md) ordnet ARCH-13/14 dem dauerhaften Langzeitbetrieb M1h
zu. [ARCH-13](ARCHITECTURE_BACKLOG.md#arch-13--regionsspeicherung-mit-gemeinsamem-commit)
verlangt vollständige Regionsreferenzen aus Slots, Sicherungen, Historie und
Migrationsquellen. [ARCH-14](ARCHITECTURE_BACKLOG.md#arch-14--langzeitregister-auslagern)
lagert Karten-/Ortswissen dauerhaft aus.

Das inzwischen fertig veröffentlichte Ortsregister
[PR #65](https://github.com/MajorDragonfly/voxelverse/pull/65), Commit
`75d4c4cf0d1868c8f8f8adf20b423ac745542579`, fordert in seiner
[ARCH-13-Übergabe](https://github.com/MajorDragonfly/voxelverse/blob/75d4c4cf0d1868c8f8f8adf20b423ac745542579/docs/WORK_ARCH14_PLACE_REGISTER.md)
genau diesen Anschluss: beide Wurzeln und die eindeutige Ortszuordnung prüfen.
Diese Lieferung setzt den Anschluss innerhalb unseres bisherigen Exporters um.
Gemeinsame Roadmap und Gesamtstatus bleiben gemäß der bestehenden
[Integrationsregel](NEXT_PARALLEL_WORK.md#übergabe-und-zusammenführung) beim
Integrationsbesitzer; ARCH-13/14 insgesamt bleiben offen.

## Verhalten

Die bisherigen `export`-/`verify`-Befehle unterstützen jetzt Atlas 1/2/3.
Atlas 3 erhält zusätzlich zur Kachelwurzel `storage` die Ortswurzel
`place_storage`, die Gesamtzahl `place_count` und bis zu 96 offene Orte samt
`place_ordinals`. Die Original-JSONs werden weiterhin bytegleich übernommen.
Ein zusätzlicher Checkpoint des laufenden Spiels ist nicht erforderlich.

Beide Wurzeln werden in aktuellen und archivierten Atlanten aller ausgewählten
Kampagnenslots verfolgt. Backups, Historie, ausgewählte Slotkopien und rekursive
Migrationsquellen verwenden denselben Anschluss. Nicht gespeicherte Laufzeitdaten
sind weiterhin außerhalb eines Exports gespeicherter Snapshots.

| Speicherstelle | Prüfung |
| --- | --- |
| `storage` | Bisherige vollständige Kachelprüfung aus PR #71 |
| `place_storage`, Schlüssel `p:<ID>` | Schema 1, Körper-ID, gültiger Ort und dessen stabile Position |
| Dieselbe Wurzel, Schlüssel `o:<Position>` | Schema 1, Körper-ID und Rückverweis auf dieselbe Orts-ID |
| `places` / `place_ordinals` | Gleiche IDs, höchstens 96 vollständige Orte und eindeutige Positionen innerhalb der Gesamtzahl |
| `place_count` | Exakte Ganzzahl bis zum veröffentlichten Maximum 9.007.199.254.740.991; vollständige Abdeckung aller Positionen |

Jedes gespeicherte ID-/Positionspaar wird in beiden Richtungen nachgeschlagen.
Dadurch werden fehlende Gegenstücke, widersprüchliche Zuordnungen, doppelt
vergebene Positionen und verwaiste Indexwerte erkannt. Eine gültige SHA-256 allein
genügt nicht. Offene Änderungen dürfen einen bestehenden Ort überlagern, behalten
aber ID und Position. Neue offene Orte dürfen keine bereits vergebene Position
belegen. Der alte gespeicherte Wert bleibt auch dann vollständig geprüft, wenn
ein offener Wert ihn überlagert.

Die Prüfung zählt eindeutige gespeicherte Paare und neue offene Orte. Da alle
Positionen innerhalb des deklarierten Bereichs liegen, die Zuordnungen eindeutig
sind und die Anzahl übereinstimmen muss, bleiben keine unbesetzten Positionen.
Sie iteriert nicht über eine möglicherweise riesige, fehlerhafte `place_count`.
Ein korrektes leeres Register oder ein ausschließlich offener Anfangsbestand ist
ebenfalls erlaubt.

Ortsnamen, bekannte Objekt-/Art-IDs, eigene/fremde Markierung und Adressen werden
gemäß dem vorhandenen Ortsvertrag erhalten. Unbekannte Atlas-/Ortspayloadversionen,
Speicherformate, Zusatzfelder in versionierten Indexwerten, beschädigte Daten und
ungültige Zuordnungen brechen vor der Veröffentlichung der Sicherung ab.
SaveGameService bleibt Besitzer der vollständigen Spielstandsvalidierung.

## Begrenzte Arbeitsspeichernutzung

Die bestehende Tiefensuche bleibt erhalten. Für Gegenprüfungen lädt `_lookup`
jeweils nur einen Trie-Pfad und einen Ortswert. Ein eigener LRU hält höchstens
128 Routingseiten, jeweils maximal 32 begrenzte Schlüssel und Hashverweise.
Ortswerte und zusätzliche JSON-Felder werden nicht in diesem Cache gesammelt.
Der offene Zuordnungssatz ist auf die vorhandenen 96 Einträge begrenzt.
Ein globaler Satz aller IDs oder Positionen entsteht nicht.

Die Laufzeit wächst mit den referenzierten Einträgen und ihren Gegenabfragen.
Ein größerer Bestand erfordert mehr Arbeit und Dateizugriffe. Die Grenzen sind
Speicherbudgets, keine zugesagte maximale Exportdauer. Bestehende Limits und
Veröffentlichungsregeln aus PR #62 bleiben erhalten: Snapshot/Blob-Budgets,
Ausgabesperre, temporäres Ziel, vollständige Zielprüfung und atomare Umbenennung.
Fehler löschen keine Quelle und überschreiben keine bestehende Sicherung.

Die Ausgabe enthält zusätzlich `place_records` (geprüfte gespeicherte Ortswerte,
einschließlich wiederholter Historien), `index_reads` und `peak_index_pages`.
Diese additiven Diagnosewerte ändern das Backupformat nicht.

## Prüfung und Wiederherstellung

`tests/tooling/region_backup_places_test.py` prüft beide Indexrichtungen,
mehrere Generationen, Backups, Historie, Slotkopien, Migrationsarchive,
leere/offene Register, Versionssperren, fehlerhafte Zuordnungen, Zähllücken,
Schreibfehler und den Wechsel beider Quellwurzeln während des Exports.
Die bisherigen Population-/Atlas-2-Fälle werden weiterhin ausgeführt.

`tools/place_backup_probe.gd` verwendet den echten Atlas/AtlasPlaceStore und
SaveGameService aus dem fertigen PR #65 in einem getrennten Referenz-Checkout.
Sie erzeugt 3.105 Orte über sechs Kugelflächen und 130 archivierte Flächenorte.
Die erste Generation ist vollständig gespeichert. Danach wird ein Ort dauerhaft
verlegt; eine weitere Verlegung und ein neuer Ort bleiben im offenen Puffer.
Die zweite Generation enthält dadurch 3.106 Orte. Eine echte gespeicherte
Kachelwurzel belegt gleichzeitig den Erhalt des Atlas-Kachelvertrags.

Nach Export und vollständiger Zielprüfung ist das Quell-Blobverzeichnis am alten
Pfad nicht mehr verfügbar. Ein frischer Prozess lädt alle Sicherungsstände,
blättert sämtliche Orte in Seiten von höchstens 64 Einträgen durch und prüft
ID, Reihenfolge, Name und Adresse. Direktabfragen liefern dieselben Orte; Änderungen
an einer gelesenen Kopie verändern den gespeicherten Bestand nicht.

| Lokale Abnahme mit Godot 4.6.3 | Ergebnis |
| --- | --- |
| Alle Sicherungsprüfungen einschließlich dreier nativer Neustarts | 25 bestanden, keine übersprungen |
| Exportierte Snapshots / nichtleere Wurzelverweise | 4 / 9 |
| Geprüfte Kugelorte nach Neustart über drei Stände | 9.316 |
| Geprüfte archivierte Flächenorte nach Neustart | 390 |
| Orte im aktuellen Stand / noch offene Änderungen | 3.106 / 2 |
| Höchste Seitengröße / Ortswerte im Godot-Cache / Trie-Seiten | 64 / 96 / 128 |
| Höchster Indexcache des Exporters / Tiefensuchstapel | 128 / 59 |
| Kopierte Blobs / Nutzbytes | 6.897 / 2.180.096 |
| Geprüfte Blobverweise / gespeicherte Ortswerte einschließlich Historien | 21.069 / 9.705 |

Projektimport und Art-Quellenprüfung auf dem Fachbranch und dem veröffentlichten
Ortsregister-Referenzstand bestanden ebenfalls. Die bestehende Atlas-2-Prüfung
läuft weiterhin gegen ihren unveränderten Referenzstand aus PR #59.

Die konkreten Ergebnisse, Quellenrevisionen und Rohprotokolle werden in
[ARCH13_PLACE_BACKUP_RESULTS.json](ARCH13_PLACE_BACKUP_RESULTS.json) und
[place-backup-tests.log](evidence/arch13/place-backup-tests.log) festgehalten.
Die erzeugten Adressen und Orte sind synthetische Speichertestdaten. Es werden
keine visuelle Spielroute, Ziel-PC-Leistung oder vollständige Integrationsabnahme
behauptet.

Nach Import der eigenen Quellen und der veröffentlichten Referenzstände:

```bash
GODOT_BINARY=/path/to/godot \
ATLAS_BACKUP_PROJECT=/path/to/checkout-of-57a330fc \
PLACE_BACKUP_PROJECT=/path/to/checkout-of-75d4c4cf \
python -m unittest discover -s tests/tooling -p 'region_backup*_test.py' -v
```

Die CI führt die Atlas-2- und Atlas-3-Prüfungen gegen ihre jeweils gepinnten
Referenzen aus. Ohne die entsprechenden Umgebungsvariablen werden native Tests
ausdrücklich übersprungen; das genügt nicht für eine Neustartabnahme.

## Übergabe

Der Folge-PR basiert ausschließlich auf unserem PR #71 und zeigt die zusätzliche
Ortsunterstützung. Der geprüfte Spielcode aus PR #65 wird als Referenz verwendet,
aber nicht in den Fachbranch übernommen. Zum Laden von Atlas-3-Sicherungen muss
das Ortsregister aus PR #65 samt seiner Abhängigkeit #59 integriert sein.
Nach Integration von #71 kann dieser PR auf main umgestellt werden.

Separate Labordateien, ein globales Speichermanifest, automatische Bereinigung
alter Regionsdateien und eine Backup-Menüoberfläche bleiben weitere Anschlüsse.
Die Arbeit ändert weder Weltkartenbedienung noch Freundschaft, Tierbesitz,
SaveGameService, Atlas-Spielcode oder andere parallel vergebene Spielsysteme.
