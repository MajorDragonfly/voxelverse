# ARCH-14: Dauerhaftes Kartenwissen

Stand: 10. September 2026. Branch `feature/arch-14-atlas-paging`, Basis
`ea900f2`, [PR #59](https://github.com/MajorDragonfly/voxelverse/pull/59).
Dieses Teilpaket liefert das Paging der Erkundungskacheln und das Inventar der
übrigen Registergrenzen. ARCH-14 insgesamt bleibt offen.

Fortsetzung: [PR #65 / dauerhaftes Ortsregister](WORK_ARCH14_PLACE_REGISTER.md)
ergänzt Schema 3 und ersetzt die unten noch für PR #59 beschriebene Ortsgrenze.

## Ergebnis und Speichervertrag

Die bisherige Grenze von 8.192 Kacheln beendet keine Erkundung mehr. Kleine Karten
behalten das bestehende Schema 1. Oberhalb von 96 Kacheln verwendet
[`exploration_atlas.gd`](../core/map/exploration_atlas.gd) Schema 2:

| Feld | Bedeutung |
| --- | --- |
| `body_id`, `mode`, `radius`, `divisions` | Unveränderte Körperidentität, Projektion und Auflösung |
| `storage` | Standardmanifest `{schema: 1, format: "sha256_trie_v1", root: SHA256}` des vorhandenen RegionStore |
| `tiles` | Höchstens 96 offene Kacheln; enthalten vollständig die jüngsten Änderungen und überlagern die gespeicherten Kacheln |
| `extent` | Vier Zahlen: globale minimale/maximale Kartenkoordinaten; leer bei einer vollständig unerforschten Karte |
| `places` | Bestehende Ortsmarker; weiterhin höchstens 2.048 |

Eine Kachel bleibt eine 32×32-Bitmaske mit dem bisherigen Schlüssel
`face:tile_x:tile_y`. Der Wert im RegionStore enthält eigenes Schema 1,
Körper-ID, Oberflächenmodus, Auflösung und 32 Zeilen. Inhaltshash und Trie-Verweis
werden vom bestehenden Store geprüft; der Atlas prüft beim Nachladen zusätzlich
Identität, Version und sämtliche Maskenzeilen. Unbekannte oder defekte Kacheln
werden nicht durch neue leere Kacheln ersetzt.

Der Spielstand ist zu jedem Zeitpunkt vollständig durch Manifest **und** offene
Kacheln beschrieben. Er braucht deshalb keinen weiteren Save-Abschluss und keine
Änderung an SaveGameService. Auch ein Körperwechsel oder das Freigeben des Trackers
kann den offenen Puffer nicht verlieren. Die vorhandenen Exportfunktionen kopieren
ihn mit dem Körperdatensatz.

Beim Erreichen des Puffers wird während normaler Erkundung eine alte Kachel
ausgelagert. Erst nach erfolgreichem Schreiben aller zugehörigen Blobs erhält der
Datensatz die neue Wurzel und verliert diese offene Kachel. Scheitert das Schreiben,
bleiben die bisherige Wurzel und der gesamte offene Puffer erhalten. Das Signal
`storage_failed` sperrt über den vorhandenen Speicherschutz das Überschreiben der
Kampagne beziehungsweise der Laborsicherung und zeigt den Fehler an.

Ein alter Schema-1-Datensatz mit mehr als 96 Kacheln wird beim Binden einmalig
vollständig ausgelagert. Seine bisher erlaubten maximal 8.192 Kacheln werden weder
gekürzt noch neu erkundet. Quell-/Backup-Dateien werden dabei nicht umgeschrieben.
`checkpoint()` erlaubt einen vollständigen Abschluss, ist für normales Speichern
aber nicht erforderlich. Ältere Wurzeln bleiben unverändert; der Atlas löscht
keine Blobs.

## Laufzeit und Kartenansicht

- Pro gebundenem Atlas höchstens 96 offene Kacheln, zusätzlich 96 geladene
  Store-Werte und 128 Trie-Seiten. Die einmalige Übernahme einer alten Karte darf
  ihren bisherigen Inline-Datensatz halten; danach gilt das neue Pufferbudget.
- Eine Kachelauslagerung pro neuem Kachelschlüssel im normalen Cachewechsel.
  Hash-Trie-Schreiben bleibt synchron. Dies ist kein Nachweis einer maximalen
  Framezeit auf dem Ziel-PC; eine Vollmigration läuft ebenfalls synchron.
- Öffnen eines gespeicherten Atlas liest dessen Wurzelseite, nicht alle besuchten
  Kacheln. Die Save-Validierung prüft ebenfalls nur das Manifest und die Wurzel;
  tiefe Blobs werden beim Zugriff geprüft.
- Die Ansicht „Erkundetes“ verwendet eine feste Ausdehnung statt sämtliche
  ausgelagerten Kacheln nachzuladen. Auf Kugeln speichert sie kanonische
  Längen-/Breitengrad-Bogenlängen; Erkundung beiderseits der Längengradnaht kann
  deshalb eine breite Gesamtansicht ergeben. Verschieben/Zoomen erkundet nichts.
- Die Grenze der Ortsliste wird bei einem weiteren Marker sichtbar gemeldet.
  Auch dann wird neue Landschaft weiterhin gespeichert. Das Paging der Marker
  ist weitere ARCH-14-Arbeit.

## Inventar der Registergrenzen

| Register auf Basis `ea900f2` | Grenze / bestehender Pfad | Einordnung und weitere Arbeit |
| --- | --- | --- |
| Erkundungskacheln | Bisher 8.192 insgesamt | Technische Grenze; in diesem PR durch Paging ersetzt |
| Bekannte Kartenorte | 2.048 pro Atlas | Technische Grenze; hier sichtbar gemacht, dauerhaftes Marker-Paging noch offen |
| Atlas-Sammlung im Planetenlabor | 256 Körper; Living-Labor 3 zugelassene Körper | Technisches Sammlungsbudget beziehungsweise verfügbare Laborkörper; keine Kampagnen-Erkundungsgrenze |
| `SurfaceEcosystem.animal_records` | 256 gespeicherte gegenüber 4 aktiven Tieren, 25 Patches | Laborregister und aktive Darstellung sind getrennt zu behandeln; dieses Teilpaket ändert sie nicht |
| Kampagnenpopulation | Bereits Schema 2 und RegionStore | Bestehendes Paging in `campaign_region_storage.gd`; aktive Aufbaugrenzen gehören auch zu ARCH-17 |
| Foraging | Alte Inline-Register: je 32.768 Tiere/Pflanzen | Keine Spielregel. Kugelkampagnen leiten vorhandene Identitäten bereits in regionale `foraging`-/`food`-Datensätze um; übrige Alt-/Laborpfade bleiben offen |
| Begegnungen | Altes `CreatureEncounters`-Register: 32.768 berührte Individuen | Einmaligkeits-/Beziehungswissen darf nicht verworfen werden. Kugelkampagne routet vorhandene Identitäten bereits über regionale `encounter`-Datensätze; übrige Pfade bleiben offen |

Quellen: [`surface_ecosystem.gd`](../world/surface/surface_ecosystem.gd),
[`campaign_region_storage.gd`](../world/surface/campaign_region_storage.gd),
[`foraging_state.gd`](../world/resources/plants/foraging_state.gd),
[`creature_encounters.gd`](../core/progression/creature_encounters.gd),
[`exploration_tracker.gd`](../ui/world_map/exploration_tracker.gd),
[`living_planet_store.gd`](../world/surface/living_planet_store.gd).

## Nachweise

Godot 4.6.3, Headless, jeweils eigene XDG-Datenverzeichnisse:

| Prüfung | Ergebnis |
| --- | --- |
| Editor-Import | Erfolgreich, keine Parse-/Scriptfehler |
| `tests/atlas_paging_test.gd` | 8.205 besuchte Kacheln; offene Kacheln 96, Store-Cache 96, Trie-Seiten 128; früher und neuer Kartenstand korrekt |
| Derselbe Test, Kindprozess | Echter SaveGameService-Spielstand; Neustart erhält frühe, späte und noch nicht ausgelagerte Änderungen |
| Migration / Kugelkarte | Volle alte 8.192-Kachelkarte einschließlich negativer Koordinaten und Bit 31; Ortsmarker, sechs Kugelflächen, Naht und Pol erhalten |
| Fehlerfälle | Fehlende Wurzel, defekte/leer gespeicherte Kachel, neuere Wurzel, nicht beschreibbares Verzeichnis und unterbrochener Teilabschluss; bisherige Save-Bytes unverändert |
| `tests/world_map_test.gd` | Karte, Bedienung, Layouts, Pause, Ortsfilter, echter Neustart und Schutz künftiger Versionen bestanden |
| `tests/living_planet_map_test.gd` | Labor-Kartenansicht, Körperwechsel und Neustart bestanden |
| `tests/region_store_test.gd` | Bestehende 1.200-Regionen-Prüfung einschließlich unveränderlicher Historie und beschädigter Dateien bestanden |

Aufrufmuster: `godot --headless --path . --script res://tests/atlas_paging_test.gd`.
Der Test startet selbst einen zweiten Godot-Prozess. Die negative Schreibprüfung
erwartet die Warnung des bestehenden Speicherschutzes; Assertions bleiben aktiv.

## Übergabe an parallele Pakete

- **ARCH-13:** Auch `exploration_atlas.storage`, archivierte
  `legacy_exploration_atlas.storage` und Labor-`map_atlases[*].storage` verwenden
  das Standardmanifest. Vollständige Umzugsarchive und spätere Bereinigung müssen
  diese Wurzeln aus Slots, Backups, Historie und Migrationsquellen mitnehmen.
  Das vorliegende Paket implementiert oder ändert keine Archiv-/Bereinigungslogik.
- **ARCH-29:** `tests/atlas_paging_test.gd` bei Integration in die gemeinsame
  Validierung aufnehmen. Deren Dateien bleiben im reservierten CI-Paket.
- **ARCH-01:** Atlas liest Schema 1 und 2; neue kleine Karten beginnen weiterhin
  bei Schema 1. Schema 2 umfasst Wurzel plus offenen Puffer, nicht nur die Wurzel.

Dieses Teilpaket erklärt weder das gesamte ARCH-14-Abnahmekriterium noch
Tier-/Foraging-/Begegnungs-Paging für abgeschlossen.
