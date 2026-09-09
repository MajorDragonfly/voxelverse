# M1d – begrenzter Oberflächenadapter

Stand: 9. September 2026. Auftrag 1 aus `docs/NEXT_PARALLEL_WORK.md`.

- Ausgangsbasis: integrierter `main`, `3a3e0272375e556f3ff65b7370582af79a9d48b5` (PR #28), beim Start auch gegen GitHub geprüft.
- Eigener Branch: `agent/m1d-surface-adapter`.
- Implementierung, Prüfungen und Messartefakte: **`318fd8bff3fefef9990d52c3c83048bf0d7df9f8`**. Dieser Bericht wird in einem anschließenden Dokumentationscommit ergänzt.
- Abgeschlossen: erster überprüfbarer M1d-Teilauftrag. **M1d als vollständige Kugelkampagne bleibt offen.** Kein Merge nach `main`, kein fremder Fachbranch übernommen. `ROADMAP.md` und `NEXT_PARALLEL_WORK.md` bleiben beim Integrationschat.
- Veröffentlichungsstatus: lokal committed. Die automatische Freigabeprüfung hat den GitHub-Push wegen fehlender ausdrücklicher Freigabe für diesen neuen öffentlichen Upload abgelehnt. Die überprüfte frühere Zustimmung betraf den Integrationsstand. Veröffentlichung dieses Fachbranches und ein Übergabe-PR stehen bis zur erneuten Uploadfreigabe aus.

## Ausprobieren

Im vorhandenen Planetenlabor den neuen Knopf **„M1d · Spieler, Baum, Kreatur“** wählen. Alternativ `world/planet_lab/surface_adapter_lab.tscn` mit F6 starten oder:

```sh
godot --path . res://world/planet_lab/surface_adapter_lab.tscn
```

Gestartet wird auf Terra mit **6.371.000 m Radius / 12.742 km Durchmesser**. Die Oberfläche, Gravitation und Terrain-Revision stammen aus dem vorhandenen realen Referenzsystem. Neris (100 km Durchmesser) und Orin (1.000 km) sind die weiteren technischen Reiseziele; sie ersetzen Terra nicht.

WASD bewegt, Maus dreht, Leertaste springt. Esc hält beide Körper an und gibt die Maus frei. F5 sichert, F9 lädt, M wechselt den Himmelskörper, R kehrt zum jeweiligen Startort zurück. Der Knopf „Planetenlabor“ führt mit Sicherung zurück. Bei einer geschützten/unlesbaren Datei gibt es ausdrücklich „Ohne M1d-Sicherung zurück“.

Das HUD zeigt tatsächliche Laufstrecken, Bodenkontakt, Terrainkacheln, aktive Kollisionskacheln, Ursprungswechsel, geladene/entladene Objekte und gemessene Aufbauzeiten.

## Änderungen und Anschlüsse

| Datei/Modul | Aufgabe |
|---|---|
| `world/surface/radial_surface_adapter.gd` | Gemeinsame Abfrage von Höhe/Normalen/Wasser, radiales Oben und Orientierung, präzise Ortskonvertierung, Tangentenversatz, Objektbindung und gemeinsame Ursprungsverschiebung; physische Schrittproben |
| `world/surface/surface_terrain.gd` | Dünne Ableitung des vorhandenen adaptiven Terrains; meldet Ursprungswechsel an alle gebundenen Körper |
| `world/surface/surface_tree.gd` | Vorhandene `ancient_oak_v2` aus dem Assetkatalog einschließlich der dort definierten Stammkollision, radial aufgestellt |
| `world/surface/surface_creature.gd` | Eine physisch bewegte Standardkreatur mit vorhandener V7-Laufzeitdarstellung, Hin-/Rückweg, radialer Gravitation, Bodenkontakt und Kollision |
| `world/surface/surface_lab_store.gd` | Eigene atomare Sicherung mit Backup und strikter Validierung von Oberfläche, Körper, Ortsdaten, Objekt-IDs und Generatorwerten |
| `world/planet_lab/surface_adapter_lab.gd`, `.tscn` | Begrenzte spielbare Prüfszene, vorhandener `RadialWalker`, Objektstreaming, Reise/Rückkehr, Bedienung und Messanzeigen |
| `world/planet_lab/planet_lab.gd` | Einziger geänderter Bestands-Code: vier Zeilen für den Einstiegsknopf nach erfolgreicher Laborsicherung |
| `tests/surface_adapter*_test.gd` | Koordinatenvertrag, Physik-/Wiederbesuchstest und tatsächlicher Menü-Einstieg/Rückkehr |
| `tools/inspect_surface_adapter.gd` | Reproduzierbare Grafikaufnahme mit tatsächlichem Bodenkontakt beider Kreaturkörper |
| `art/review/m1d_surface/` | `validation.json` mit Messwerten/Prüfergebnissen und `surface.png` |

Zu den neuen Skripten gehören ihre Godot-UID-Dateien. Keine Änderung an V9-Generator, Autoload-Code, `project.godot`, produktivem Spieler-/Wildtiercode oder globalen Speicherschemata. Keine eigene Speziesdatenbank, Zähmung oder Stammeslogik.

Die örtlichen Node-Positionen bleiben kleine `Vector3`-Werte. Absolute Körperpositionen werden mit den bestehenden skalaren Double-Arrays von `CubeSphere` berechnet und erst nach Ursprungsabzug umgewandelt. Spieler, Baum und Kreatur werden gemeinsam verschoben; Geschwindigkeit und Orientierung bleiben im körperfesten Koordinatensystem. Gebundene Nodes sind unskalierte Geschwister der Terrain-Node; transformierte übergeordnete Räume sind noch kein Bestandteil dieses Vertrags.

## Streaming und Speicherung

Pro geöffnetem Körper gibt es genau einen Spieler, einen Baum und eine Kreatur. Baum/Kreatur werden innerhalb von 96 m bei fertiger Nahkollision geladen und ab über 128 m mit erhaltenem Zustand entfernt. Die Kreatur darf kein eigenes Terrainbudget auslösen und wartet vor unvorbereiteter Kollision. Entfernte Tiere simulieren nicht weiter. Die vorhandenen Terrainlimits bleiben: höchstens 24 aktive Kollisionskacheln, zwei Uploads je Frame, 1.536 residente Terrainmeshes. Die Laufzeitprüfung erzwingt zusätzlich höchstens 768 sichtbare Kacheln.

Neue Datei: **`user://surface_adapter_m1d.json`**, Schema 1, Fixture-Revision 1, Oberfläche `cube_sphere_m1_v1`. Pro Referenzkörper gespeichert: Radius/Seed/Terrain-Revision 3, Startort, Spielerpose mit Geschwindigkeit und Laufstrecke, feste Objekt-IDs, Baum-Asset und Pose, Kreaturpose mit Geschwindigkeit/Laufstrecke sowie Heimat, Ziel und Laufrichtung des Pendelwegs. IDs haben das Muster `<body_id>:m1d:tree` bzw. `:creature`. Der Kreaturkörper ist die vorhandene V7-Standardform als Laborfixture (`default_v7_fixture1`), keine neu erzeugte produktive Tierart oder Übernahme des Kampagnencharakters. Änderungen an dieser Fixture benötigen eine bewusste neue Fixture-Revision.

`legacy_plane_v9` wird nicht konvertiert. Radius-/Seed-Abweichungen, ungültige Körperadressen, nicht endliche Zahlen, unbekannte Revisionen und zukünftige Schemata werden abgewiesen. Ein beschädigtes JSON kann aus dem gültigen Backup gelesen werden; ein erkennbar inkompatibles Schema wird auch bei vorhandener alter Sicherung geschützt. In der Szene sind automatische **und manuelle** Kampagnensicherungen inaktiv; die vorherigen Sessionwerte werden beim Verlassen wiederhergestellt. Die M1/M1b/M1c-Laborsicherung bleibt eine eigene Datei. Gleichzeitige Schreiber auf die neue M1d-Datei sind noch kein unterstützter Betriebsmodus.

## Gemessener Abschluss

Godot **4.6.3.stable.official.7d41c59c4**, Jolt, Linux-Container. Werte aus der erfolgreichen abschließenden Headless-Physikrunde; Zeitmessungen auf geteilter CPU sind Diagnosen und keine Ziel-PC-Abnahme.

| Prüfung/Messung | Ergebnis |
|---|---:|
| Terra-Lauf über eine echte Cube-Sphere-Grenze | 180,278 m, zwei Flächen |
| Bodenkontakt beim gemessenen Lauf | 595 / 595 Physikticks |
| Physisch gemeldete Spieler-/Baumkontakte | 115 |
| Physisch gemeldete Spieler-/Kreaturkontakte | 73 |
| Physisch gemeldete Kreatur-/Baumkontakte | 76 |
| Eigene Kreaturbewegung vor Kollisionsprüfung | 2,213 m |
| Ursprungswechsel | 4 |
| Baum und Kreatur entladen | beide, danach nur Spieler gebunden |
| Größter Ortsfehler bei Ursprungswechsel | 0,005395 mm |
| Baum-Ortsabweichung nach Entladen/Rückkehr | 0,0000361 mm |
| Koordinatenvertrag über alle Flächen/Pole/Ecken | 18 Fälle × 3 Objekte, max. 0,002417 mm |
| Sichtbare Kacheln / residente Terrainmeshes, Maximum | 684 / 1.219 |
| Terrain-Veröffentlichungen während Lauf | 7 |
| Erstaufbau der Szene | 3.106,671 ms |
| Größte gemessene Objektaufbauzeit | 173,235 ms |
| Größtes Upload-Framebudget, tatsächlich verbraucht | 20,300 ms |
| Größter Terrain-Workerauftrag | 2.764,100 ms, asynchron |
| Frischer Prozess lädt Körper, Orte und Kreaturauftrag | bestanden, Exit 0 |
| Kampagne, Design und altes Laborsave unverändert | 3 Pfade auf identische Bytes bzw. unveränderte Abwesenheit geprüft |

Alle sechs gezielten Tests bestanden: `surface_adapter_contract_test`, `surface_adapter_test`, `surface_adapter_entry_test`, `campaign_foundation_test`, `galaxy_visits_test`, `planet_transition_runtime_test`. Import und Prüfung der vorhandenen Kunstquellen ebenfalls erfolgreich. Der Eingangstest klickt den gerenderten M1d-Knopf, sichert/lädt bei pausierten Akteuren, besucht Neris und kehrt in das alte Labor zurück. Der Physiktest prüft Terra → Orin → Terra und startet einen zusätzlichen Godot-Prozess zum Laden derselben Sicherung.

Grafikprüfung: 1280 × 720, Compatibility mit Mesa llvmpipe. Spieler und Kreatur haben tatsächlichen Bodenkontakt; Baum, Körper und Bedienfelder sichtbar. Keine Behauptung einer Windows-, EXE-, Forward+- oder Ziel-GPU-Abnahme. Keine vollständige Wiederholung aller projektweiten Tests.

```sh
python3 tools/validate_godot.py --godot /pfad/zu/Godot_4.6.3 \
  --tests surface_adapter_contract_test surface_adapter_test surface_adapter_entry_test \
  campaign_foundation_test galaxy_visits_test planet_transition_runtime_test --skip-main

# Mit Grafikdisplay; Screenshot unter user://m1d_surface.png
godot --path . --script res://tools/inspect_surface_adapter.gd
```

## Grenzen und nächster abgegrenzter Schritt

Dieses Paket stellt die Oberfläche für eine kleine, überprüfbare Objektgruppe bereit. Die synchronen Körper-/Erstladungen und der bis zu 173-ms-Aufbau eines Exemplars sind noch sichtbar messbare Spitzen. Eine niedrige Framezeit beim Laden vieler Objekte ist damit nicht nachgewiesen. Als nächstes sollten Objektvorbereitung/Instanziierung über mehrere Frames verteilt, die Nahkollision für mehrere unabhängig entfernte Akteure geplant und auf dem Ziel-PC gemessen werden.

Danach jeweils eigene, koordinierte Anschlüsse für produktive Wildtierbewegung/Habitate, Gebäude, örtliches Wasser und räumliches Audio. Anatomischer Fußkontakt für beliebige Zwei-/Vier-/Mehrbeiner bleibt beim Kreaturenauftrag; hier trägt eine einheitliche physische Kapsel die vorhandene V7-Standarddarstellung. Globale Fauna, Navigation über den ganzen Planeten, Tierrollen, Ressourcenabbau und kontinuierlicher Raumflug sind nicht enthalten. Neuwelt-/Kampagnenmigration bleibt eine gesonderte, ausdrücklich zu bestätigende Arbeit. Die ganze M1d-Roadmap-Zeile darf durch diese Übergabe noch nicht auf „fertig“ gesetzt werden.
