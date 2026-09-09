# Gemeinsame Kugelkampagne: Gameplay und Regionsspeicher

Stand: 9. September 2026. Integration auf `agent/spherical-gameplay-migration-2026-09-09`, einschließlich des Architektur-Audits aus `main` `7e402506f5944e1ac457673395f94627c7d314d5`. Dieser Stand führt M1f, den lokalen M1g-Ablauf und erste M1h-Anschlüsse zusammen. Die vollständige M1i-Abnahme und der reguläre Kugelstart bleiben offen.

## Gemeinsame Datenbesitzer und Anschlüsse

| Bestand | Autoritativer Besitzer und Format | Laufzeit / Zugriff |
|---|---|---|
| Kampagne, Körper, Entwürfe | GameState / CampaignState; Save 8, Kampagne 2 | Ein SaveGameService mit gemeinsamem Commit. `get_current_body_record()` liefert den gemeinsamen aktuellen Datensatz; `get_current_body()` bleibt eine Kopie. Der alte Seedindex ist noch vorhanden. |
| Oberflächenorte | `surface_context`, Cube-Sphere-Adresse mit Körper-ID; Oberflächenformat 1 | `gameplay_space.gd` vermittelt lokale Physik, Richtung, Wasser, Abtastung und Bindung an den Ursprung. Globale Meter bleiben Doubles bis nach Ursprungssubtraktion. |
| Heimat / Dorf / Nachbar | Heimat 2, Stamm 6, Nachbar 3 für Kugelorte | Dieselben Controller, Bewohner-IDs, Bauwerke, Aufträge und Wirtschaftsbelege. Planare Heimat 1 / Stamm bis 5 / Nachbar bis 2 bleiben gesondert lesbar. |
| D1 / D2 / D3 | Vorhandener Artenkatalog und D2-Registry; D3 liest denselben Besitz | Der Kampagnenhost erzeugt echte D1-Körper. Zähmung übernimmt deren ursprüngliche ID und eingefrorenen Entwurf. Fremde Tiere werden keine Bürger. Entwurfsrevision 0 ist wie im vorhandenen D1/D2-Vertrag gültig. |
| Wildtiere, Pflanzen, Bedürfnisse, Begegnungen | Regionaler Kampagnenbestand 2 mit `sha256_trie_v1`-Manifest | Ein `campaign_population`-Host, gemeinsame Foraging-/Drinking-/Progression-Dienste, keine parallele Labortier-Simulation. Individuen- und Nahrungsindizes verweisen auf dieselben regionalen Datensätze. |
| Ökologie | Regionale gespeicherte Aggregate | Vorhandene Ökologiegleichungen, höchstens zwei Regionsaufgaben pro Frame. Unbeladene individuelle Zustände bleiben derzeit eingefroren; entfernte Siedlungsproduktion ist noch nicht implementiert. |
| Wasser / Audio | Dieselbe versionierte Oberflächenquelle | Neue Körper verwenden `living_planet_v2`, Terrainrevision 4, mit Süßwasserbecken. V1/Revision 3 bleibt unverändert lesbar. Wassergeometrie, Trinken, Unterwasseransicht und Audio teilen die Wasserhöhe. |

Die gemeinsame Szene verwendet `player.tscn`, normalen Kreatureneditor, Scanner, Bedürfnisse, Nest, Heimatgruppe und Dorf. Eigenständige Labore bleiben Diagnosebereiche. Jeder gebundene physische Root wird bei einer Ursprungskorrektur genau einmal versetzt; lokale Routenziele und Fußkontakt-Caches werden mitgeführt.

## Regionsspeicherung und Kopiermigration

`region_store.gd` schreibt unveränderliche, SHA256-adressierte Inhalts- und Indexdateien. Ein Snapshot veröffentlicht erst nach erfolgreichem Schreiben einen neuen Indexwurzel-Hash. Frühere Spielstände, Backups und Kopien behalten ihre bisherigen Wurzeln. Cache-Eviction schreibt Änderungen vor dem Entfernen zurück. Hashfehler, fehlende Dateien und unbekannte Versionen blockieren den betroffenen Zustand; unbekannte Wurzelversionen verhindern den Rückfall auf eine ältere Slotsicherung.

Obergrenzen: 96 geladene Inhaltswerte, 128 Indexseiten, 32 Einträge je Indexblatt, 2 MiB je Datei; aktive Regionen werden gepinnt. Die physische Population ist auf zwölf Wildtiere und sechzehn Nahrungspflanzen begrenzt. Flora und Gelände behalten ihre eigenen vorhandenen Streamingbudgets. Diese Grenzen betreffen den aktiven Ausschnitt; der Regionsindex hat keine globale 256-Tier-Grenze.

Die einmalige Überführung alter Inline-Regionen kopiert Bedürfnisse und Begegnungen zunächst in neue Segmente. Erst nach deren erfolgreichem Checkpoint werden die bisherigen Einträge entfernt. Der gemeinsame SaveService bleibt für den abschließenden Slot-Commit zuständig.

Die Kopiermigration `campaign_places_copy_v2` inventarisiert Heimat, Dorf, Nachbarn, Katalog, Tierbesitz, Nahrung und angefangene Produktion/Fracht. Sie legt eine ausdrückliche Quell-/Zielzuordnung an, überprüft trockene sichere Plätze und erhält IDs, Körperentwürfe und nicht räumliche Inventare. Alte D1-Habitat-IDs bleiben über den archivierten Ursprungskatalog erhalten. Ein `legacy_population`-Datensatz ergänzt beim tatsächlichen Besuch alter Tiere deren vollständige Herkunft. Nicht mehr rekonstruierbare alte Individuen werden als konkreter offener Migrationsfall gemeldet. Quelle und Quellarchiv bleiben erhalten; die endlose alte Landschaft wird nicht als identische Kugellandschaft ausgegeben.

## Erneut ausgeführte Prüfungen

Die Ergebnisse werden während dieser Integrationsrunde ergänzt. Ein bestandener Teiltest ersetzt weder die Gesamtprüfung des finalen Commits noch die Ziel-PC-Abnahme.

| Prüfung | Bisheriger Nachweis |
|---|---|
| `region_store_test` | 1.200 Regionen mit Änderung, Eviction und erneutem Lesen; begrenzte Caches, eine Root-Leseoperation beim Öffnen, unveränderte alte Wurzel, Korruptions- und Zukunftsschutz einschließlich Save-Loader. |
| `spherical_developed_migration_test` | Entwickelter Vertragsstand mit ursprünglicher Heimat, drei Bewohnern, Hütte, Nachbar, besessenem D1-Milchtier, Tierplatz, Teilzyklus, ausstehender Milch, pausierter Holzfracht und Ökologie; Inventarvergleich, reale Aktivierung und frischer Godot-Prozess bestanden. Die Quelle ist ein aufgebauter Vertragsstand, kein Nachweis für jeden historischen Spielstand. |
| `spherical_campaign_runtime_test` | Normaler Start/Kopierweg, ursprünglicher Entwurf, echte Bewegung, Ursprungskorrektur, Karte, Bedürfnisse, Pause, Speichern, frischer Prozess und Rückkehr zum Menü bestanden. |
| `spherical_creature_test` | Tatsächlicher Kamerascan mit einmaliger Belohnung; normaler F2-Editor und Rückkehr mit gleicher Kampagne/Heimat; erreichbares Süßwasser, Unterwassertiefe und radiales Audio bestanden. |
| `spherical_gameplay_test` | Zusammenhängender realer Ablauf mit Heimat → Stamm → Holzfracht/Laden → Nachbar → D1-Zähmung → Tierplatz → Pflege → Milchtransport einmal bestanden. Die erweiterte Kette mit blockierter Milchfracht und separatem Neustart erreichte ebenfalls das Lager; die strenge Logprüfung fand dabei einen Scanner-Audio-Zugriff nach Szenenabbau. Ein Lebenszyklusschutz ist ergänzt; die endgültige gemeinsame Wiederholungsprüfung steht aus. |
| `surface_scale_contract_test` | Kleine Kugel, Terra und obere begehbare Radiusgrenze erreichen den erforderlichen Bodendetailgrad innerhalb des Blattbudgets; zu große Körper bleiben geschützt statt endlos zu laden. |
| Gemeinsame Regression | Heimat, Stamm, Wirtschafts-/Wachstums-/Haltungsverträge, D2, D1-Oberflächenkatalog, KI, Foraging, Drinking, Unterwasser und Audio geprüft. Zwei Erwartungen auf die bisher höchste planare Version wurden ausdrücklich von den neuen Kugelformaten getrennt. |

Das erste native Linux-Paket bestand 29 Export-/Paketprüfungen außerhalb des Quellprojekts, einschließlich Kugelstart, Migration und frischem Prozess. Die danach ergänzte erweiterte Milchprüfung und Grafikaufnahmen werden zusätzlich in der gemeinsamen CI ausgeführt. Lokale Grafikaufnahme war durch einen nicht verfügbaren X-Server-Socket blockiert; keine Grafikabnahme oder Ziel-PC-Leistung daraus ableiten.

## Verbleibende Abnahmen und Architekturaufgaben

- M1g: fehlerfreie Wiederholung der erweiterten Milchfrachtprüfung am finalen Stand; reale historische Dörfer einschließlich ungünstiger Fundamente und Zielkapazität weiter prüfen.
- M1f/M1h: längere tatsächliche Reise, Flächenkante auf kleinem Körper, Körperwechsel/Rückkehr und vollständige Verbrauchs-/Todes-/Wissensbilanz im Kampagnenhost.
- ARCH-03/04: stabile Körper-ID als primärer Lookup; gleiche Weltseeds in verschiedenen Systemen dürfen keine Körper zusammenlegen. Der neue direkte aktuelle Datensatz beseitigt tiefe Kopien im Hotpath, ersetzt diese Migration aber nicht.
- ARCH-13/14: segmentierte Karten-/Fortschrittsregister und sichere Bereinigung unreferenzierter Regionsdateien unter Berücksichtigung sämtlicher Historien/Kopien. Der derzeitige Store löscht keine historischen Blobs.
- ARCH-15/16: entfernte eigene Siedlungen während aktiver Spielzeit vereinfacht weiterbetreiben, mit eindeutiger Übergabe von Auftrag, Ladung, Reservierung und Zeitcursor. Pause, Editorpause und geschlossene Anwendung erzeugen keine Produktion. Der aktuelle lokale Ablauf beweist diese Fernübergabe noch nicht.
- ARCH-10/17: teure Navigations-/Fundamentaufbereitung zeitlich aufteilen, lange Messroute und CPU-/GPU-/RAM-/VRAM-Budgets dokumentieren.
- M1i/ARCH-19: finalen gemeinsamen Commit und native Linux-/Windows-Pakete prüfen; anschließend Darstellung und Bedienung auf definierter Zielhardware abnehmen. Erst dann den regulären Neue-Spiel-Start umstellen. 1080p60 bleibt ein Entwicklungsziel.

Nachfolgearbeit verwendet [ARCHITECTURE_BACKLOG.md](ARCHITECTURE_BACKLOG.md) und die vorhandenen Dienste. Die hier gelieferten Anschlüsse nicht nochmals als separaten M1f-/M1g-Zweig aufbauen. Der offene Entwurfs-PR #42 bleibt die gesonderte Planung für spätere Inhalte.
