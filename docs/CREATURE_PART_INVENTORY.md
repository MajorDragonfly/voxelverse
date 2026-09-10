# ARCH-24 – Bestandsinventar der Kreaturenteile

Stand: 10. September 2026 · Basis: `ea900f2e09946660694a9e59399b4680a5655a85`.

46 bestehende IDs: 5 Körper, 5 Bemalungen, 29 Anbauteile und 7 Endstücke.
Alle behalten ID, Reihenfolge, Werte und bisherige Form. **Kein Altteil wird ersetzt.**
„Revision 1“ bezeichnet hier den erhaltenen Auslieferungsstand. Nur der neue Fußkatalog
exponiert bereits eine explizite Geometrierevision; eine gespeicherte Teilrevision ist
noch kein Feld des bestehenden Kreaturenbauplans. Neue gespeicherte Revisionen benötigen
den ARCH-23-Vertrag. Der Baseline-Test hält alle bisherigen Definitionsfelder fest.

| Kategorie | Stabile ID | Revision / Erhalt | Kompatibler Ersatz |
|---|---|---|---|
| body | `body_balanced_core` | 1 / unverändert | dieselbe ID |
| body | `body_long_grazer` | 1 / unverändert | dieselbe ID |
| body | `body_heavy_shell` | 1 / unverändert | dieselbe ID |
| body | `body_insectoid` | 1 / unverändert | dieselbe ID |
| body | `body_serpent_base` | 1 / unverändert | dieselbe ID |
| mouth | `mouth_grazer` | 1 / unverändert | dieselbe ID |
| mouth | `mouth_broad_beak` | 1 / unverändert | dieselbe ID |
| mouth | `mouth_predator_jaws` | 1 / unverändert | dieselbe ID |
| mouth | `mouth_filter_snout` | 1 / unverändert | dieselbe ID |
| eyes | `eyes_beady` | 1 / unverändert | dieselbe ID |
| eyes | `eyes_wide` | 1 / unverändert | dieselbe ID |
| eyes | `eyes_stalks` | 1 / unverändert | dieselbe ID |
| eyes | `eyes_cluster` | 1 / unverändert | dieselbe ID |
| legs | `legs_stubby` | 1 / unverändert | dieselbe ID |
| legs | `legs_walker` | 1 / unverändert | dieselbe ID |
| legs | `legs_sprinter` | 1 / unverändert | dieselbe ID |
| legs | `legs_spider` | 1 / unverändert | dieselbe ID |
| legs | `legs_hoof` | 1 / unverändert | dieselbe ID |
| arms | `arms_grasping` | 1 / unverändert | dieselbe ID |
| arms | `arms_climber` | 1 / unverändert | dieselbe ID |
| arms | `arms_claws` | 1 / unverändert | dieselbe ID |
| tail | `tail_balance` | 1 / unverändert | dieselbe ID |
| tail | `tail_club` | 1 / unverändert | dieselbe ID |
| tail | `tail_fin` | 1 / unverändert | dieselbe ID |
| tail | `tail_stinger` | 1 / unverändert | dieselbe ID |
| horns | `horns_small` | 1 / unverändert | dieselbe ID |
| horns | `horns_crest` | 1 / unverändert | dieselbe ID |
| horns | `horns_antlers` | 1 / unverändert | dieselbe ID |
| plates | `plates_dorsal` | 1 / unverändert | dieselbe ID |
| plates | `plates_shell` | 1 / unverändert | dieselbe ID |
| spikes | `spikes_back` | 1 / unverändert | dieselbe ID |
| spikes | `spikes_side` | 1 / unverändert | dieselbe ID |
| decor | `decor_feathers` | 1 / unverändert | dieselbe ID |
| decor | `decor_crystals` | 1 / unverändert | dieselbe ID |
| paint | `paint_plain` | 1 / unverändert | dieselbe ID |
| paint | `paint_forest_spots` | 1 / unverändert | dieselbe ID |
| paint | `paint_sand_stripes` | 1 / unverändert | dieselbe ID |
| paint | `paint_warning_marks` | 1 / unverändert | dieselbe ID |
| paint | `paint_crystal_bloom` | 1 / unverändert | dieselbe ID |
| feet | `feet_pads` | 1 / unverändert | dieselbe ID |
| feet | `feet_claws` | 1 / unverändert | dieselbe ID |
| feet | `feet_hooves` | 1 / unverändert | dieselbe ID |
| feet | `feet_webbed` | 1 / unverändert | dieselbe ID |
| hands | `hands_grasp` | 1 / unverändert | dieselbe ID |
| hands | `hands_claws` | 1 / unverändert | dieselbe ID |
| hands | `hands_pincers` | 1 / unverändert | dieselbe ID |

## Zuständigkeiten und erster Referenzanschluss

| Gegenstand | Autoritative Quelle / Zugriff |
|---|---|
| Katalog aller bestehenden Teile, Reihenfolge, Werte | `creature_part_library.gd`; `get_part` / `get_parts_for_category` / `get_terminal_parts` |
| Fußidentität, Anschluss, anatomische Merkmale | `creatures/catalog/creature_foot_catalog.gd`; `get_profile` / `supports` |
| Fußgeometrie Revision 1 | `creature_foot_geometry.gd`; `recipe` für die bestehende Voxeloberfläche, `legacy_voxels` ausschließlich für den erhaltenen älteren Blockadapter |
| Geometrie übriger Anbauteile | `creature_part_geometry.gd`; alter Blockadapter liest weiterhin die Katalogvoxel |
| Körper und Bemalung | `creature_sculpt_surface.gd` / `creature_skin_style.gd`, vorhandener Körper-/Bemalungskatalog |
| Transformieren und Spiegeln | bestehende `_piece` / `_cone` im gemeinsamen Geometriebauer |
| Tatsächlicher Sohlenkontakt | `creature_limb_rig.gd`: untere Grenze der transformierten sichtbaren Meshes → `RuntimeFootContact`; kein zweiter konstanter Sohlenwert |
| Editor, Wildtiere, Spieler | vorhandener gemeinsamer Kreaturenrenderer und Bewegungsrig |
| Freie Vorschau und gesperrte Silhouette | vorhandenes `journal_preview.gd` → derselbe Geometriebauer; Silhouette tauscht nur Materialien |
| D1-Standfähigkeit | `planet_fauna_catalog.gd` liest `domestic_support`; Körpernachweis, Rollen und Besitz bleiben in ihren Fachsystemen |

## Fußmerkmale ohne zusätzliche Spielfreigaben

| ID | Anatomischer Bodenkontakt | D1-Standfuß | Bestehende Beinaktionen |
|---|---|---|---|
| `feet_pads` | ja | ja | Gehen / Laufen |
| `feet_claws` | ja | nein, bisher nicht D1-zugelassen | Gehen / Laufen |
| `feet_hooves` | ja | ja | Gehen / Laufen |
| `feet_webbed` | ja | nein, bisher nicht D1-zugelassen | Gehen / Laufen |

`domestic_support` erhält ausdrücklich die bisherige D1-Zulassung. Es ist weder eine
automatische Reit-/Zugeignung noch eine Tierrolle. Die vollständige D1-Prüfung verlangt
weiter mindestens vier geeignete Beine und ihre übrigen Körper-/Artnachweise.
Ein passendes Endstück benötigt ein angeschlossenes Bein und den bestehenden Bewegungsrig.
Schwimmhaut schaltet kein Schwimmen frei; Krallen geben kein Klettern frei.
Unbekannte IDs und explizit angefragte unbekannte Revisionen liefern kein Profil und
keine Ersatzgeometrie. Getter liefern unabhängige Lesekopien.

## Anschluss weiterer Modelle

1. Eine neue Fußform erhält eine eigene stabile ID; bestehende Revision-1-Rezepte bleiben erhalten.
2. Name/Anschluss/Merkmale im Fußkatalog, Geometrie im Anbieter, tatsächlichen Kontakt im bestehenden Rig ergänzen.
3. D1-Eignung erst nach passendem Körpernachweis setzen. Stats und Bewegungsaktionen nicht aus dem Namen ableiten.
4. Entdeckung, Sprache und prozedurale Vergabe mit den jeweiligen Besitzern anbinden; neue IDs werden durch den Baseline-Test als absichtliche Katalogerweiterung sichtbar.
5. Nicht kompatible Änderungen an einer bestehenden ID benötigen explizite gespeicherte Revisionen nach ARCH-23 und einen Erhaltungs-/Migrationsnachweis.

Offene Modelle aus M3-TEILE.2: neue Pfoten/Tatzen, weitere Tierfüße, Rüssel, Schnauzen,
Oktopusmund und Krebsscheren. Dieses Paket liefert die erste gemeinsame Referenzfamilie
mit den vier vorhandenen Fußformen; es behauptet diese zusätzlichen Modelle nicht.

Prüfumfang und Übergabe: [WORK_ARCH24_PARTS.md](WORK_ARCH24_PARTS.md).

## Additives Modellpaket vom 10. September 2026

Die historische Liste oben bleibt die Erhaltungsgrundlage. Der Katalog ergänzt
die folgenden drei eigenen IDs und umfasst damit jetzt 49 Teile / 10 Endstücke:

| Kategorie | Neue ID | Revision | Ersatz alter Formen |
|---|---|---|---|
| feet | `feet_feline_paws` | 1 | keiner |
| feet | `feet_bear_paws` | 1 | keiner |
| feet | `feet_horse_hooves` | 1 | keiner |

Eigene IDs passen in das bestehende `end_part_id`-Feld und brauchen keine
Schemaänderung. Die alten Revision-1-Formen bleiben erhalten. Neue gespeicherte
Versionsfelder oder das Ersetzen alter Formen bleiben von ARCH-23 abhängig.
Alle drei Formen unterstützen den vorhandenen Beinrig; ihre D1-Zulassung
und prozedurale Verteilung werden nicht allein durch die neue Optik freigegeben.

Modelle, Bedienung und Nachweise: [WORK_ARCH24_ANIMAL_FEET.md](WORK_ARCH24_ANIMAL_FEET.md).

## Additiver Handanschluss vom 10. September 2026

`hands_crab_claws` ergänzt die drei alten Hände als **Krebsscheren**, Revision 1.
Damit gibt es 50 Teile und elf Endstücke. Kein bisheriges Teil wird ersetzt.
Die drei alten Handrezepte sind jetzt im eigenen `creature_hand_geometry.gd`;
Identität/Anatomie liegen in `creature_hand_catalog.gd`. Die neue Hand verwendet
das vorhandene `end_part_id` und einen Armanschluss, keine neuen Fähigkeiten.

Geometrieerhalt, Editor, Spiegelung und Neustart:
[WORK_ARCH24_CRAB_CLAWS.md](WORK_ARCH24_CRAB_CLAWS.md).
