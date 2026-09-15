# ARCH-14 – dauerhafte Kampagnen-Tierregister

Stand: 10. September 2026. Basis: `bb2f83b56267964baa7037720c4daca26fe3d007`.
Branch: `agent/arch14-population-registers-2026-09-10`. Status: **geliefert auf eigenem Branch, Integration ausstehend**. ARCH-06/07/22/24/25 laufen in anderen Chats; deren Laufzeitdateien werden hier nicht geändert.

## Lieferung und Datenvertrag

Der reguläre Kugelstart verwendet bereits `CampaignPopulation` und regionale Individuen-, Begegnungs- und Nahrungsdatensätze. Es wird kein zweites Register eingeführt. Geprüft sind **384 veränderte Tiere und 384 Nahrungsquellen über mehr als 96 Regionen**, anschließend ein weiteres Tier, sowie Laden über den gemeinsamen SaveGameService in einem **frischen Godot-Prozess**.

Die Prüfung reproduziert auf unverändertem Basiscodestand verlorene Änderungen an aktiven Hungerreferenzen nach Checkpoint beziehungsweise Entladen und verlorene Bewegungen innerhalb derselben Region. Die korrigierte Fassung besteht dieselben Fälle.

- Aktive Regionen werden vor Checkpoint und vor Freigabe zur Cacheverdrängung wieder als verändert markiert. Die KI hält ihre vorhandenen veränderbaren Hunger-/Durstreferenzen zwischen Frames; deren Besitzer muss deshalb nach einem vorherigen Checkpoint erneut gesichert werden. Die Arbeit wächst nur mit den aktiven Regionen.
- Auch eine Bewegung innerhalb derselben Region greift jetzt auf den autoritativen, schreibend markierten Regionsdatensatz zu. Veraltete Tierabbilder werden abgelehnt.
- Während Einfügen und Regionswechsel bleiben die benötigten Regionen im Cache. Zuerst wird der Index vorbereitet, danach werden Datensatz und Quell-/Zielbestand verändert. Das Ziel eines aktiven Tiers bleibt bis zur nächsten Host-Aktualisierung geschützt. Der gemeinsame Save veröffentlicht weiterhin nur einen vollständigen Checkpoint.
- Hunger, Durst, Tod, aufgezehrte Kadaver, Vertrauen, abgeerntete Nahrung und Regenerationszeit bleiben über dieselben Objekt-/Nahrungsschlüssel erreichbar. Alte Speicherwurzeln bleiben unverändert. Bestehende Altformat-Übernahme und Schreibsperre werden verwendet.

**Unveränderte Verträge:** `surface_population` Schema 2, Regionspayload Schema 1, `sha256_trie_v1` Schema 1; Foraging, Drinking und Encounter Schema 1. D2 bleibt Besitzer gezähmter Tiere, ProgressionService Besitzer der Belohnungsregeln, SaveGameService alleiniger gemeinsamer Writer. Kein Eingriff in dessen parallele Modularisierung oder in die Double-Serialisierung.

## Registerinventar und Grenzen

| Register | Art der Grenze / Anschluss | Status dieses Pakets |
|---|---|---|
| Reguläre Kampagnenpopulation | 12 physische Tiere, 16 Pflanzen; bis 128 Tiere bzw. Pflanzen pro Regionspayload. Keine globale 256-Tier-Grenze. | Vorhandene Trennung von aktiven Nodes und dauerhaften Datensätzen erhalten; 385 registrierte Tiere geprüft. |
| Regionscache / Indexseiten | 96 Datensätze und 128 Indexseiten; technische Cachegrenzen, keine Wissensgrenzen. | Spitzen bleiben innerhalb der Grenzen; Eviction und Neustart geprüft. |
| Hunger / Durst / Nahrung | Regionale Erweiterungen am Tier/Pflanzendatensatz; alte Inline-Tabellen haben je 32.768 Einträge. | Aktive Referenzen abgesichert. Vorhandene Migration verschiebt alte Daten erst nach erfolgreichem regionalem Checkpoint. |
| Begegnungen | Regional am Individuum; alter globaler Fallback maximal 32.768 Einträge. | 384 geänderte Beziehungen/Todesstände bleiben regional; globaler Fallback wächst dabei nicht. Nicht zuordenbare Alt-/Laboreinträge bleiben erhalten. |
| Verhaltensbelohnungen | Zwei Spielregel-Konten à 24 Punkte; bezahlte Ziele bleiben gespeichert, keine Verdrängung. | Kein neuer Belohnungspfad und keine Änderung an Einmaligkeitsbelegen. |
| Karten / bekannte Orte | Schema 3 mit ausgelagerten Kacheln/Orten und begrenzten offenen Puffern. | Bereits integrierte ARCH-14-Teilpakete, unverändert. |
| Separates Planetlabor | `SurfaceEcosystem.animal_records`, maximal 256 Datensätze; eigener Laborspeicher. | **Offen.** Im regulären Kugelstart ist dessen Wildlife deaktiviert (`main/spherical_campaign.gd`); dort übernimmt CampaignPopulation. |
| Entdeckungsbuch / weitere Langzeitlisten | Weitere UI-/Paging-Inventarisierung nötig. | **Offen**, keine behauptete vollständige ARCH-14-Abnahme. |

## Nachweis

`tests/population_register_test.gd` benutzt den echten Populationshost, Regionsadapter, Foraging-/Drinking- und ProgressionService-Anschluss sowie SaveGameService. Seine schmale Fixture lässt Terrain und gerenderte Akteure weg und zeigt Speicherfehler ohne SessionFlow-Bildschirm an. Der Test ist genau einmal im Vertrag `regions_simulation` registriert; das Szenario `over_256_animals` verweist auf ihn.

Geprüft: neue Einträge nach 384 Tieren, geänderte Bedürfnisse/Vertrauen/Todesstände, kein Wiedererscheinen aufgezehrter Kadaver, Entnahmen/Regenerationszeit, aktive Referenzen nach Checkpoint, Freigabe und Eviction, Bewegung innerhalb einer Region und Wechsel auf eine andere Würfelfläche, unveränderliche alte Wurzel, Übernahme von Inline-/Legacy-Registern, blockierter tatsächlicher Blob-Schreibpfad, unveränderter letzter Kampagnensave und Neustart mit nur einer initial gelesenen Indexseite. Alle 384 geänderten Einträge werden nach Cachewechsel und im Kindprozess nachgeprüft.

Ergebnisse und Quellhashes: [ARCH14_POPULATION_RESULTS.json](ARCH14_POPULATION_RESULTS.json).

```sh
python3 tools/validate_godot.py --godot "$GODOT" --skip-main --tests population_register_test region_store_test surface_population_budget_test wildlife_foraging_test wildlife_drinking_test spherical_creature_test
```

Headless-Fachtests sind keine gerenderte Langzeitreise und kein Ziel-PC-/FPS-Nachweis. Keine Aussage über unbegrenzt viele gleichzeitig sichtbare Tiere, alle Labordaten, vollständige D2-Größenabnahme oder eine abgeschlossene Gesamtphase. Die neue Speicherprüfung ist bewusst auf die regionalen Kampagnenregister begrenzt.

## Integration

Laufzeitänderung ausschließlich in `world/surface/campaign_region_storage.gd`; keine Änderung an `campaign_population.gd`, den Autoloads, gemeinsamen Ressourcenkatalogen oder `project.godot`. Die neuen Testdateien, ein Testkatalogeintrag und die abgegrenzten Dokumentationshinweise gehören dazu. Gleichzeitige Änderungen am Testkatalog und an der Roadmap additiv vereinigen, ohne Einträge anderer Fachpakete zu ersetzen. Beim späteren Merge den tatsächlichen gemeinsamen Stand erneut prüfen.
