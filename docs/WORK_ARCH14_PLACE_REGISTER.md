# ARCH-14: Dauerhaftes Ortsregister

Stand: 10. September 2026. Branch `feature/arch-14-place-register`,
[PR #65](https://github.com/MajorDragonfly/voxelverse/pull/65).
**Abhängigkeit:** [PR #59](https://github.com/MajorDragonfly/voxelverse/pull/59),
Dateibaum `5b57ee5c9905e236d035610bb6ae430fcfa4c2e5`.
Der PR richtet sich zunächst gegen dessen Branch und enthält nur dieses Folgepaket.

## Geliefert

Gespeicherte Nester, Heimatorte und bekannte Lebensräume wachsen über die bisherige
Grenze von 2.048 Einträgen hinaus. Ein neuer
[`AtlasPlaceStore`](../core/map/atlas_place_store.gd) verwendet den vorhandenen
RegionStore. Der Atlas bleibt der Besitzer des Kartenwissens; Freundschaft,
Tierleben und Besitz werden weiterhin bei ihren bestehenden Diensten abgefragt.

Die Weltkarte liest höchstens 64 Einträge pro Seite. Pfeiltasten als Buttons und
eine numerische Seitenanzeige machen weitere Orte erreichbar. Karte und Ortsliste
zeigen die ausgewählte Seite; es gibt keine gleichzeitige Darstellung sämtlicher
Marker eines Planeten. Die bestehende Sortierung nach eigenen Orten und Namen
gilt innerhalb der Seite. Seitenzugehörigkeit bleibt durch einen stabilen Index
erhalten, auch wenn ein Ort umbenannt oder versetzt wird.

Bei 800×600 mit 150 % Schriftgröße zeigt die kompakte Ortsansicht mindestens einen
vollständigen Ortsbutton und beide Blätterbuttons. Maßstab und Ortsdetails kehren
mit der Kartenansicht zurück. Die Änderungen enthalten keine neue Textübersetzung.

## Versionierter Speichervertrag

Kleine Karten bleiben Schema 1, Karten mit ausgelagerten Kacheln können weiterhin
Schema 2 sein. Ab mehr als 96 Orten wird die vorhandene Ortsliste vollständig
übernommen und der Atlas erhält Schema 3. Bereits vorhandene Schema-1/2-Karten
mit bis zu 2.048 Orten werden beim Binden verlustfrei übernommen.

Schema 3 enthält den vollständigen Kachelvertrag aus Schema 2 und zusätzlich:

| Feld | Vertrag |
| --- | --- |
| `place_storage` | Standardmanifest `{schema: 1, format: "sha256_trie_v1", root: SHA256}` |
| `place_count` | Zahl vergebener, stabiler Ortspositionen einschließlich offener neuer Einträge |
| `places` | Höchstens 96 offene vollständige Ortsdatensätze, nach Orts-ID |
| `place_ordinals` | Genau die IDs aus `places`, jeweils mit ihrer eindeutigen Position zwischen 0 und `place_count - 1` |

Die Wurzel enthält zwei Arten von Werten:

| Schlüssel | Wert innerhalb des vorhandenen RegionStore-Umschlags |
| --- | --- |
| `p:<Orts-ID>` | `{schema: 1, body_id, ordinal, place}`; `place` folgt dem bestehenden Ortsvertrag |
| `o:<Position>` | `{schema: 1, body_id, id}`; Verweis auf dieselbe Orts-ID |

Beide Indexarten gehören zu **derselben** Wurzel. Erst nach erfolgreichem Abschluss
aller geschriebenen Werte wird diese im Atlas veröffentlicht und der entsprechende
offene Eintrag entfernt. Bei Fehlern bleiben alte Wurzel, Anzahl und offene
Zuordnungen unverändert. Die erstmalige Übernahme veröffentlicht ebenfalls erst
nach vollständigem Schreiben; der ursprüngliche Inline-Datensatz bleibt bei einem
Abbruch erhalten. Kachelschreiben darf Schema 3 nicht auf Schema 2 zurücksetzen.

Änderungen eines bekannten Ortes behalten ID und Position. Leser erhalten Kopien,
damit sie keine nicht erfassten Änderungen an gemeinsamen Dictionary-Werten
auslösen. Die Einträge eines früheren Spielstands bleiben über dessen Wurzel und
offenen Puffer rekonstruierbar. Es gibt keine automatische Löschung alter Blobs.

## Anschlüsse und Budgets

[`ExplorationAtlas`](../core/map/exploration_atlas.gd) bietet:

- `remember(place)`: vorhandenen Ort aktualisieren oder neue ID speichern;
  unveränderte Einträge bleiben ein No-op.
- `get_place(id)`: genau einen gespeicherten Ort als Kopie lesen.
- `place_page(offset, limit)`: `{places, offset, next, total}`; die Ergebnismenge
  bleibt auch bei größerem angefordertem Limit auf 64 begrenzt.
- `checkpoint_places()`: offenen Ortspuffer vollständig schreiben; normales
  SaveGameService-Speichern benötigt diesen zusätzlichen Abschluss nicht.

Pro gebundenem Ortsregister: höchstens 96 offene Orte samt Zuordnungen,
96 geladene RegionStore-Werte und 128 Trie-Seiten. Die UI hält höchstens
64 Ortsdatensätze und erzeugt entsprechend höchstens 64 Ortsbuttons. Das separate
Kachelbudget aus PR #59 gilt zusätzlich. Während der einmaligen Übernahme darf
der alte, bereits auf 2.048 begrenzte Inline-Datensatz im Speicher liegen.

Das Schreiben bleibt synchron. Ein voller offener Puffer lagert bei einer neuen
Änderung einen alten Ort aus; jeder Ort benötigt seinen ID- und Positionsverweis.
Die Grenzen beschreiben Mengen, keine garantierte Framezeit auf dem Ziel-PC.
Die einzige Gesamtgrenze ist der exakt serialisierbare Zahlenraum des Indexes;
sein Erreichen löst einen Speicherfehler aus, keine stille Verwerfung.

[`WorldMapSource.visible_place_page`](../ui/world_map/world_map_source.gd)
prüft Freundschaft/Tod erst für die gelesene Seite. Es schreibt keine zweite
Beziehungslogik. Eine Seite kann durch diese Prüfung oder die UI-Filter leer
erscheinen; die Blättersteuerung bleibt anhand des gespeicherten Indexes verfügbar.
Ein schneller räumlicher Suchindex, globale Sortierung über alle Seiten und
Markergruppen bei großer Dichte sind nicht Teil dieser Lieferung.

Der aktive Kugelhost meldet weiterhin tatsächlich vorhandene/bekannte Orte aus
seinem begrenzten Nahbereich. Die historische planare Erfassung in
`WorldMapSource.known_places` besitzt weiterhin ihre bisherige 2.048er-Ausgabegrenze;
dieses Paket ersetzt die Speichergrenze und übernimmt alle bereits gespeicherten
Altorte, baut aber keinen neuen planaren Erfassungsdienst.

## Nachweise

Godot 4.6.3, Headless, getrennte XDG-Verzeichnisse:

| Prüfung | Nachweis |
| --- | --- |
| `tests/atlas_places_test.gd` | 3.105 Orte, alle Seiten ohne doppelte/verlorene ID erreichbar; 96 offene Orte, 96 Cache-Werte, 128 Trie-Seiten |
| Echter Folgeprozess desselben Tests | SaveGameService lädt frühe Orte, verlegte Heimat, letzten Ort und offene Änderungen; beim Binden nur die Ortswurzel gelesen, keine Ortswerte |
| Alte Versionen | Je 2.048 Orte aus Schema 1 und Schema 2 verlustfrei übernommen; neuer Ort danach möglich; Quellkopie unverändert |
| Körperwechsel | Orte auf allen sechs Kugelflächen und ein versetzter Polmarker bleiben erhalten; fremde Körper dürfen keine Orte übernehmen |
| Reale Weltkarte | 64 Buttons pro Seite, vor/zurück, spätere Ortsauswahl, Pausefreigabe und erreichbare Blätterbuttons bei 800×600/150 % |
| Beziehungen | Lebender Freund auf einer späteren Seite sichtbar; nach Tod ausgeblendet, gespeicherte Historie unverändert |
| Fehler | Unterbrochener Abschluss nach echtem Blobschreiben; fehlende/neue Speicherwurzel, neues Ortspayload und defekte offene Zuordnung; bestehende Save-Bytes bleiben geschützt |
| Regressionen | `atlas_paging_test.gd` mit 8.205 Kacheln, `world_map_test.gd` und `living_planet_map_test.gd` bestanden |

Aufruf: `godot --headless --path . --script res://tests/atlas_places_test.gd`.
Der Test startet den Neustartprozess selbst. `-- --places-ui` prüft nur die UI an
einem zuvor erzeugten Testspielstand. Die negative Speicherprüfung erwartet eine
Warnung des vorhandenen Save-Schutzes; unerwartete Scriptfehler bleiben Fehler.

## Integration mit parallelen Paketen

- **ARCH-25 / PR #60:** Die Formatierung von Namen und Details sowie bestehende
  Sprachwechsel-Callbacks beibehalten. In `_refresh_places` die bisherige
  Komplettabfrage durch `visible_place_page` ersetzen und die Blättersteuerung
  behalten. `_place_offset` bei Sprachwechsel nicht zurücksetzen. Die kompakte
  Ortsansicht muss neben dem Mindestplatz für Ortsbuttons auch die Blätterzeile
  berücksichtigen. `atlas.full` bleibt als kompatibler, falscher Wert bestehen.
- **ARCH-13:** Das geprüfte `tools/region_backup.py` erlaubt ausdrücklich nur
  Atlas-Schema 1/2. **Schema-3-Archive sind bis zur Adaptererweiterung gesperrt.**
  Vor gemeinsamer Freigabe sind Schema 3, `place_count`, `place_ordinals` und beide
  Wurzeln (`storage`, `place_storage`) aufzunehmen. Der Ortsadapter muss `p:`- und
  `o:`-Werte, Körperidentität, eindeutige Zuordnung und offene Überlagerung prüfen.
  Das gilt auch für archivierte Atlanten in Backups, Historie und Migrationsquellen.
  Ein reines Zulassen der Versionsnummer ohne Verfolgen der zweiten Wurzel reicht
  nicht. Dieser PR ändert keine parallel bearbeitete Archivdatei.
- **ARCH-29:** `tests/atlas_places_test.gd` im Kartenvertrag registrieren.
- **ARCH-01:** Atlas liest Schema 1/2/3; `places` ist in Schema 3 nur der offene
  Puffer. Verbraucher verwenden ID-/Seitenabfragen, keine vollständige Dictionary-
  Iteration. Keine fremden unfertigen Branches wurden integriert.

ARCH-14 insgesamt bleibt offen: Tier-, Foraging- und Begegnungsregister besitzen
weitere Aufgaben. Dieser PR wurde nicht nach `main` gemergt.
