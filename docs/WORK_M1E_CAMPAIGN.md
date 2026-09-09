# M1e: gemeinsamer Kampagnenkontext auf Kugelwelten

Stand: 9. September 2026. Baut auf dem zusammengeführten `main` aus PR #41 auf. **Die gemeinsame Speicher-/Startgrundlage und der Kopierweg für frühe Stände sind umgesetzt. Der vollständige Umzug entwickelter Kampagnen und die volle Kreaturen-/Stammesphase bleiben offen.** Die Abnahmekette in [SPHERICAL_CAMPAIGN_MIGRATION.md](SPHERICAL_CAMPAIGN_MIGRATION.md) wird dadurch nicht verkürzt.

## Bedienung und tatsächlicher Umfang

- Im normalen Neue-Spiel-Formular ist „Kugelwelt ausprobieren“ wählbar. Der gemeinsame Slot lädt `main/spherical_campaign.tscn`. Normale Bewegung, radiales Springen/Schwimmen, lokaler Ursprung, Terrain/Flora, Mini-/Weltkarte, Pause, Speichern, Wiederaufnahme und Rückkehr ins Menü sind angeschlossen.
- Spieleridentität, Entwurfssnapshot, Fortschritt, Zeit und Kartendaten gehören zu `GameState`/`SaveGameService`. Es gibt keinen weiteren Kampagnenspeicher. Die alten Laborstände bleiben eigenständige Prüfbereiche.
- Auch der erste Standardentwurf einer neuen Kugelkampagne wird einmal im Slot eingefroren. Sein Design-ID wechselt beim Neustart nicht; fremde lose Editordateien werden dabei nicht überschrieben. Bei frühen Kopien ohne aktuellen Entwurf wird der über den bestehenden Loader gewählte Entwurf vor dem ersten Auftritt im selben Slot gesichert. Unbekannte neuere V7-Entwurfsformate bleiben geschützt.
- Nahrung, Scanner, Begegnungen, Heimatgruppe und Stamm sind in diesem Einstieg noch nicht spielbar. Gespeicherte Bedürfnisse werden unverändert erhalten; die neue Laufzeit erfindet keine Belohnungen, Regeneration oder Individuen. Die automatische Flachwelt-Audioabtastung ist für diesen radialen Spieler gesperrt, bis M1h sie anschließt.
- Unter „Spielstände → Kugelumzug prüfen“ wird die Quelle vollständig geprüft. Erst der zweite Knopf legt die geprüfte Kopie an. Nicht unterstützte Zustände erscheinen als konkrete Hindernisse im scrollbaren Detailbereich. Original und Archive werden nicht verändert.
- Migrierte Slots bieten „Flachwelt aus Umzugsarchiv kopieren“. Damit bleiben ursprüngliche Orte und Karten auch dann wieder erreichbar, wenn die Originaldatei später fehlt. Diese Wiederherstellung erzeugt eine eigene Kampagnenkopie mit erhaltenen Objekt-/Arten-/Entwurfsidentitäten und Einmaligkeitsbelegen.

Der reguläre Start bleibt bis M1i planar. Ein geänderter Startknopf wäre kein Nachweis für die vollständige Spielschleife.

## Anschlussvertrag

| Bereich | Vertrag |
|---|---|
| Gesamtsave | Schema 8. Schema 1–7 bleibt lesbar; der bestehende Sicherungsweg schützt die erste Formataktualisierung. Ein Formatupdate ändert keine Oberfläche. |
| Kampagne | Schema 2; `surface_policy` bestimmt die Erzeugung weiterer Körper. Schema 1 wird mit planarem Standard importiert. `surface_migration` enthält optional das unveränderliche Umzugsmanifest. |
| Körper | Opaque bestehende `id`, `system_id` und `seed` bleiben bestehen. `surface_mode = cube_sphere_m1_v1`; `surface_context` Schema 1 bindet Radius, Schwerkraft, `living_planet_v1`, Terrainrevision 3 und Startadresse. Keine festen Labor-IDs oder drei Referenzseeds. Neue Kugeln starten mit Radius 6.371.000 m. |
| Spielerort | `player.surface_address = {mode, body_id, face, u, v, height}`. `surface_forward`, `surface_velocity` sind körperfeste Dreierarrays; `surface_pitch` ist die radiale Kameraneigung. Die Speicherannotation ersetzt diese Werte nicht durch lokale Szenenpositionen. |
| Laufzeit | `spherical_campaign_player.gd` benutzt vorhandenen `RadialWalker`, `radial_surface_adapter.gd` und `surface_terrain.gd`. Globale Meterwerte bleiben Doubles/Arrays; `Vector3` entsteht nach Abzug des Ursprungs. Die Szenenwurzel meldet `world_initialized` erst bei bereitstehender lokaler Kollision. |
| Karte | Dieselben `MinimapHUD`, `ExplorationTracker`, `WorldMapPanel` und `ExplorationAtlas`. Der normale Kampagnensource reicht kanonische Adressen durch. Pro Körper entsteht echte Erkundung. Alte Karten bleiben unverändert in `legacy_exploration_atlas` und im Quellarchiv. |
| Versionen | Unbekannte Oberflächen-, Generator-, Kampagnen-, Heimat-, Karten- und Manifestverträge blockieren den normalen Rückgriff auf ältere Backups. Körperfremde, nicht endliche und widersprüchliche Kugelorte werden abgelehnt. |

Folgepakete erweitern diesen Vertrag und den bestehenden SaveGameService. Sie dürfen keine parallelen Wahrheiten für Arten, Bewohner, Tiere, Fracht, Belohnungen oder Kampagnenzeit anlegen.

## Kopiermigration und Schutzfälle

`SphericalMigration.plan()` arbeitet rein auf Daten. `SaveGameService.preview_spherical_migration()` validiert die ausgewählten Primärbytes vorher vollständig. `migrate_slot_to_sphere(path, expected_source_sha256)` prüft Quelle und Ziel nochmals und veröffentlicht erst nach vollständiger Rückleseprüfung. Die Quelle wird unmittelbar vor dem abschließenden Rename nochmals gehasht.

Das Manifest `early_campaign_copy_v1` enthält Quellpfad, SHA-256 der exakten Quelldatei, Quellversionen, Identität, Inventarbelege, explizite Körper-/Startzuordnungen, Hashes der Zielkontexte und den vollständigen Quelltext. Die Kopie erhält dasselbe Kampagnen-/Arten-/Objektinventar. Fortschritts- und Entwurfsdaten werden nicht neu berechnet. Prozedurale unbesuchte Ebene wird nicht vorgetäuscht.

Jeder Zielstart wird deterministisch in höchstens 486 Kandidaten über sechs Flächen gesucht. Ein 6 × 6 m großer Landebereich wird in neun Punkten auf Wasser, Sperren und Steilheit geprüft. Das ist eine Landestellenprüfung, keine Prüfung von Gebäudefundamenten, großen Siedlungen oder Verkehrsnetzen. Radiale Flora hält den vorhandenen Freiraum um den Start ein.

Zielpfade sind an das Manifest gebunden. Wiederholung liefert eine vorhandene kompatible Kopie zurück und setzt deren inzwischen gespielten Zustand nicht zurück. Neuere/defekte Zielstände und deren Backups bleiben geschützt. Staging-Dateien gehören nicht zur sichtbaren Slotliste. Erst ein vollständig geschriebenes, zurückgelesenes, schema- und inventargeprüftes Ziel wird atomar zum neuen Slot umbenannt. Original und Ziel sind separate Dateien.

**Aktuell übertragbar:** frühe Kreaturenstände mit Entwürfen, Fortschritts-/Ereigniswissen, Spielerwerten und Karten, solange noch keine persistenten Regionsdaten, Heimatgruppen, Pflichtartenkataloge, lebenden Verbündeten oder Siedlungs-/Besitzdaten existieren. Auch ältere Schema-3–7-Stände sind möglich. Schema 1/2 benötigt zuerst die vorhandene normale Formataktualisierung, um Identitäten und Entwürfe einzubetten. Das Quellarchiv ist auf 16 MiB begrenzt.

**Weiter offen:** Nach dem normalen Betreten einer Flachwelt sind in der Regel bereits Regions- und Pflichtartendaten vorhanden; solche real entwickelten Spielstände werden derzeit ausdrücklich blockiert. M1f/M1g müssen diese Daten samt Zielorten und laufenden Verbrauchern übernehmen. Unbekannte Körpererweiterungen werden ebenfalls gesperrt. Keine Daten werden abgeschnitten, kein Befreundeter verschwindet und kein Tier wird durch Neugenerierung ersetzt. Diese Einschränkung bedeutet, dass der vollständige M1e-Umzugsauftrag für entwickelte Kampagnen noch nicht abgeschlossen ist.

## Prüfungen

- `spherical_campaign_contract_test.gd`: Schema-7-Quelle, unveränderte Quelldatei, Identitäts-/Fortschritts-/Entwurfs-/Bedürfniserhalt, unerforschte neue Karte, altes Kartenarchiv, Rückweg, wiederholbarer Kopieraufruf, geänderte Quelle, Schreibfehler sowie beschädigte, körperfremde und zukünftige Daten.
- `spherical_campaign_runtime_test.gd` führt denselben `spherical_campaign_probe.gd` aus wie `--sphere-smoke` im exportierten Spiel: echte Kugelszene, ursprünglicher Entwurf, gebundene Bewegung durch Physik, Ursprungswechsel, gemeinsame Karte, Pause/Speichern, neuer Prozess, Rückkehr und echter optionaler Neue-Spiel-Einstieg.
- `tools/validate_export.py` führt diesen vollständigen Kugelablauf auch im nativen Linux-/Windows-Paket außerhalb des Quellprojekts aus.
- Bestehende Kampagnen-, Kopier-, Frontend-, Onboarding-, Karten-, Heimat-, D2-, Nachbar-, Oberflächen- und Audioprüfungen sichern die gemeinsamen Anschlüsse. Die CI-Prüfungen gelten jeweils für den veröffentlichten Commit.

Headless-Prüfungen belegen Verhalten und Datenübergabe, keine Ziel-PC-Framerate oder fertige Galaxienskalierung. Segmentierte Speicherung, atomare Nah-/Fernübergaben und die vollständige M1f–M1i-Abnahme bleiben separate offene Arbeiten.
