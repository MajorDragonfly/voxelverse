# Gemeinsame Kugelkampagne: Gameplay und Regionsspeicher

**Aktualisierung 10. September:** Lars hat den Kugelstart als einzigen regulären Spielweg vorgezogen. Die bisherige Startfreigabesperre und der optionale Auswahlhaken sind aufgehoben. [WORK_SPHERE_ONLY_ENTRY.md](WORK_SPHERE_ONLY_ENTRY.md) ist für Einstieg und Altstände maßgeblich; die folgenden Nachweise und offenen Abnahmen bleiben bestehen.

Stand: 9. September 2026. Integration auf `agent/spherical-gameplay-migration-2026-09-09`, einschließlich des Architektur-Audits aus `main` `7e402506f5944e1ac457673395f94627c7d314d5`. Dieser Stand führt M1f, den lokalen M1g-Ablauf und erste M1h-Anschlüsse zusammen. Die vollständige M1i-Abnahme und der reguläre Kugelstart bleiben offen.

Die anschließende Skalierungsrunde auf Basis von `main` `ca02572c199b1fe4b70174ac027359eaf2c588da` ist in [WORK_CAMPAIGN_SCALING.md](WORK_CAMPAIGN_SCALING.md) dokumentiert. Die untenstehenden ursprünglichen Laufberichte bleiben als Historie erhalten.

## Gemeinsame Datenbesitzer und Anschlüsse

| Bestand | Autoritativer Besitzer und Format | Laufzeit / Zugriff |
|---|---|---|
| Kampagne, Körper, Entwürfe | GameState / CampaignState; Save 9, Kampagne 3 | Ein SaveGameService mit gemeinsamem Commit. `get_current_body_record()` liefert den gemeinsamen aktuellen Datensatz; `get_current_body()` bleibt eine Kopie. Unveränderliche Körper-IDs besitzen die Datensätze; der Seedindex benötigt Systemkontext. |
| Oberflächenorte | `surface_context`, Cube-Sphere-Adresse mit Körper-ID; Oberflächenformat 1 | `gameplay_space.gd` vermittelt lokale Physik, Richtung, Wasser, Abtastung und Bindung an den Ursprung. Globale Meter bleiben Doubles bis nach Ursprungssubtraktion. |
| Heimat / Dorf / Nachbar | Heimat 2, Stamm 6, Nachbar 3 für Kugelorte | Dieselben Controller, Bewohner-IDs, Bauwerke, Aufträge und Wirtschaftsbelege. Planare Heimat 1 / Stamm bis 5 / Nachbar bis 2 bleiben gesondert lesbar. |
| D1 / D2 / D3 | Vorhandener Artenkatalog und D2-Registry; D3 liest denselben Besitz | Der Kampagnenhost erzeugt echte D1-Körper. Zähmung übernimmt deren ursprüngliche ID und eingefrorenen Entwurf. Fremde Tiere werden keine Bürger. Entwurfsrevision 0 ist wie im vorhandenen D1/D2-Vertrag gültig. |
| Wildtiere, Pflanzen, Bedürfnisse, Begegnungen | Regionaler Kampagnenbestand 2 mit `sha256_trie_v1`-Manifest | Ein `campaign_population`-Host, gemeinsame Foraging-/Drinking-/Progression-Dienste, keine parallele Labortier-Simulation. Individuen- und Nahrungsindizes verweisen auf dieselben regionalen Datensätze. |
| Ökologie | Regionale gespeicherte Aggregate | Vorhandene Ökologiegleichungen, höchstens zwei Regionsaufgaben pro Frame. Unbeladene Wildtierzustände bleiben eingefroren; die ergänzte Dorf-Fernsimulation besitzt einen eigenen Cursor in derselben Kampagnenzeit. |
| Wasser / Audio | Dieselbe versionierte Oberflächenquelle | Neue Körper verwenden `living_planet_v2`, Terrainrevision 4, mit Süßwasserbecken. V1/Revision 3 bleibt unverändert lesbar. Wassergeometrie, Trinken, Unterwasseransicht und Audio teilen die Wasserhöhe. |

Die gemeinsame Szene verwendet `player.tscn`, normalen Kreatureneditor, Scanner, Bedürfnisse, Nest, Heimatgruppe und Dorf. Tierregister und bestätigte Aktionsrückmeldungen sind an denselben D2-Kampagnencontroller gebunden; das gemeinsame Entdeckungsbuch zeigt ursprüngliche Tier-IDs und Kugelorte als Breite/Länge/Höhe. Eigenständige Labore bleiben Diagnosebereiche. Jeder gebundene physische Root wird bei einer Ursprungskorrektur genau einmal versetzt; lokale Routenziele und Fußkontakt-Caches werden mitgeführt.

## Regionsspeicherung und Kopiermigration

`region_store.gd` schreibt unveränderliche, SHA256-adressierte Inhalts- und Indexdateien. Ein Snapshot veröffentlicht erst nach erfolgreichem Schreiben einen neuen Indexwurzel-Hash. Frühere Spielstände, Backups und Kopien behalten ihre bisherigen Wurzeln. Cache-Eviction schreibt Änderungen vor dem Entfernen zurück. Hashfehler, fehlende Dateien und unbekannte Versionen blockieren den betroffenen Zustand; unbekannte Wurzelversionen verhindern den Rückfall auf eine ältere Slotsicherung.

Obergrenzen: 96 geladene Inhaltswerte, 128 Indexseiten, 32 Einträge je Indexblatt, 2 MiB je Datei; aktive Regionen werden gepinnt. Die physische Population ist auf zwölf Wildtiere und sechzehn Nahrungspflanzen begrenzt. Flora und Gelände behalten ihre eigenen vorhandenen Streamingbudgets. Diese Grenzen betreffen den aktiven Ausschnitt; der Regionsindex hat keine globale 256-Tier-Grenze.

Die einmalige Überführung alter Inline-Regionen kopiert Bedürfnisse und Begegnungen zunächst in neue Segmente. Erst nach deren erfolgreichem Checkpoint werden die bisherigen Einträge entfernt. Der gemeinsame SaveService bleibt für den abschließenden Slot-Commit zuständig.

Die Kopiermigration `campaign_places_copy_v2` inventarisiert Heimat, Dorf, Nachbarn, Katalog, Tierbesitz, Nahrung und angefangene Produktion/Fracht. Sie legt eine ausdrückliche Quell-/Zielzuordnung an, überprüft trockene sichere Plätze und erhält IDs, Körperentwürfe und nicht räumliche Inventare. Alte D1-Habitat-IDs bleiben über den archivierten Ursprungskatalog erhalten. Ein `legacy_population`-Datensatz ergänzt beim tatsächlichen Besuch alter Tiere deren vollständige Herkunft. Nicht mehr rekonstruierbare alte Individuen werden als konkreter offener Migrationsfall gemeldet. Quelle und Quellarchiv bleiben erhalten; die endlose alte Landschaft wird nicht als identische Kugellandschaft ausgegeben.

## Erneut ausgeführte Prüfungen

Die Ergebnisse werden während dieser Integrationsrunde ergänzt; die abschließenden CI-Ergebnisse und der veröffentlichte Commit werden in [PR #45](https://github.com/MajorDragonfly/voxelverse/pull/45) festgehalten. Ein bestandener Teiltest ersetzt weder die Gesamtprüfung des finalen Commits noch die Ziel-PC-Abnahme.

| Prüfung | Bisheriger Nachweis |
|---|---|
| `region_store_test` | 1.200 Regionen mit Änderung, Eviction und erneutem Lesen; begrenzte Caches, eine Root-Leseoperation beim Öffnen, unveränderte alte Wurzel, Korruptions- und Zukunftsschutz einschließlich Save-Loader. |
| `spherical_developed_migration_test` | Entwickelter Vertragsstand mit ursprünglicher Heimat, drei Bewohnern, Hütte, Nachbar, besessenem D1-Milchtier, Tierplatz, Teilzyklus, ausstehender Milch, pausierter Holzfracht und Ökologie; Inventarvergleich, reale Aktivierung und frischer Godot-Prozess bestanden. Die Quelle ist ein aufgebauter Vertragsstand, kein Nachweis für jeden historischen Spielstand. |
| `spherical_campaign_runtime_test` | Normaler Start/Kopierweg, ursprünglicher Entwurf, echte Bewegung, Ursprungskorrektur, Karte, Bedürfnisse, Pause, Speichern, frischer Prozess und Rückkehr zum Menü bestanden. |
| `spherical_creature_test` | Tatsächlicher Kamerascan mit einmaliger Belohnung; normaler F2-Editor und Rückkehr mit gleicher Kampagne/Heimat; erreichbares Süßwasser, Unterwassertiefe und radiales Audio bestanden. |
| `spherical_gameplay_test` | Zusammenhängender realer Ablauf mit Heimat → Stamm → Holzfracht/Laden → Nachbar → D1-Zähmung → Tierplatz → Pflege → Milchtransport einmal bestanden. Die erweiterte Kette mit blockierter Milchfracht und separatem Neustart erreichte ebenfalls das Lager; die strenge Logprüfung fand dabei einen Scanner-Audio-Zugriff nach Szenenabbau. Der ergänzte Lebenszyklusschutz bestand die strenge vollständige Kette im nativen Linux-Paket. Die CI fand anschließend eine zu früh beendete Revierrückkehr und einen gelegentlich stockenden Bauweg; Rückkehr bis zum Heimatpunkt und einheitliche Terrain-/Hinderniskollision für alle Dorfbewohner sind korrigiert. Die anschließenden Quelltests und beide nativen PR-Exporte einschließlich Tierbuch bestanden. Parallele Läufe zeigten noch einen Audiozugriff während des Herunterfahrens und zu geringe Annäherung an wandernde Tiere; auch diese Ursachen sind korrigiert. Den endgültigen gemeinsamen CI-Nachweis führt PR #45. |
| `surface_scale_contract_test` | Kleine Kugel, Terra und obere begehbare Radiusgrenze erreichen den erforderlichen Bodendetailgrad innerhalb des Blattbudgets; zu große Körper bleiben geschützt statt endlos zu laden. |
| Gemeinsame Regression | Heimat, Stamm, Wirtschafts-/Wachstums-/Haltungsverträge, D2, D1-Oberflächenkatalog, KI, Foraging, Drinking, Unterwasser und Audio geprüft. Zwei Erwartungen auf die bisher höchste planare Version wurden ausdrücklich von den neuen Kugelformaten getrennt. |

Das erste native Linux-Paket bestand 29 Export-/Paketprüfungen außerhalb des Quellprojekts, einschließlich Kugelstart, Migration und frischem Prozess. Der veröffentlichte Erststand `c3e92e2d5a082f67c0e873c1d936d5d177852b0a` bestand anschließend 32 native Linux-Prüfungen einschließlich erweiterter Milchfracht/Neustart. Alle sechs Grafikjobs für Planeten, Umgebung und gemeinsame Kugelkampagne bestanden mit Forward+ und Compatibility. Die Grafikartefakte sind im [CI-Lauf](https://github.com/MajorDragonfly/voxelverse/actions/runs/34392459316) hinterlegt; ihr Download in diese Arbeitsumgebung scheiterte mit HTTP 403, deshalb wurden die Bilder hier nicht visuell abgenommen. Lokale Grafikaufnahme war durch einen nicht verfügbaren X-Server-Socket blockiert. Keine Ziel-PC-Leistung aus diesen Prüfungen ableiten.

Die abschließende Stabilisierung stoppt und entfernt Tierlaut-Emitter bereits vor dem Abbau des AudioManagers; verbleibende Rückrufe prüfen ihre Besitzer. Der Betreuer sucht einen erreichbaren Platz deutlich innerhalb der Futterreichweite und prüft die Wegkandidaten nach Entfernung, statt an deren äußerem Rand stehenzubleiben. Der komplette reale Spielablauf protokolliert nun seine Phasen. Sein Prozesslimit beträgt 600 Sekunden, weil bereits erfolgreiche native Läufe einschließlich kalter Terrainladungen und separatem Neustart rund 395 Sekunden benötigen; die einzelnen Bau-, Pflege- und Transportfristen bleiben begrenzt.

## Verbleibende Abnahmen und Architekturaufgaben

- M1g: fehlerfreie CI-Wiederholung einschließlich Tierbuch, normaler Tier-Rückmeldung und aller Plattformen am finalen Stand; reale historische Dörfer einschließlich ungünstiger Fundamente und Zielkapazität weiter prüfen.
- M1f/M1h: längere tatsächliche Reise, Flächenkante auf kleinem Körper, Körperwechsel/Rückkehr und vollständige Verbrauchs-/Todes-/Wissensbilanz im Kampagnenhost.
- ARCH-03/04: inzwischen geliefert; Details und Migrationsnachweise in [WORK_CAMPAIGN_SCALING.md](WORK_CAMPAIGN_SCALING.md).
- ARCH-13/14: segmentierte Karten-/Fortschrittsregister und sichere Bereinigung unreferenzierter Regionsdateien unter Berücksichtigung sämtlicher Historien/Kopien. Der derzeitige Store löscht keine historischen Blobs.
- ARCH-15/16/18: gemeinsamer Arbeitskern, Fernsimulation und sichere Körperreise inzwischen ergänzt; Umfang und verbleibende Abnahmen in [WORK_CAMPAIGN_SCALING.md](WORK_CAMPAIGN_SCALING.md).
- ARCH-10/17: teure Navigations-/Fundamentaufbereitung zeitlich aufteilen, lange Messroute und CPU-/GPU-/RAM-/VRAM-Budgets dokumentieren.
- M1i/ARCH-19: finalen gemeinsamen Commit und native Linux-/Windows-Pakete prüfen; anschließend Darstellung und Bedienung auf definierter Zielhardware abnehmen. Erst dann den regulären Neue-Spiel-Start umstellen. 1080p60 bleibt ein Entwicklungsziel.

Nachfolgearbeit verwendet [ARCHITECTURE_BACKLOG.md](ARCHITECTURE_BACKLOG.md) und die vorhandenen Dienste. Die hier gelieferten Anschlüsse nicht nochmals als separaten M1f-/M1g-Zweig aufbauen. Der offene Entwurfs-PR #42 bleibt die gesonderte Planung für spätere Inhalte.
