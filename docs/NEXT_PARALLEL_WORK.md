# Nächste Voxelverse-Arbeiten

Stand: 15. September 2026. `agent/playtest-integration-2026-09-15` enthält sämtliche veröffentlichten Lieferungen #78–89 einschließlich der Integrationskorrekturen aus #84. [Aktueller Integrationsbericht](INTEGRATION_2026-09-15.md) und [Spieltest](WINDOWS_TEST_2026-09-15.md) benennen die neue Abnahme. Die folgenden Anschlüsse aus der Runde vom 10. September bleiben erhalten. [Integrationsbericht und Prüfgrenzen](INTEGRATION_2026-09-10.md), [exakte Quellen](integration-sources-2026-09-10.json), [Roadmap](../ROADMAP.md), [Architekturaufgaben](ARCHITECTURE_BACKLOG.md), [Modulanschlüsse](MODULE_CONTRACTS.md) und [Designvorgabe](VOXELVERSE_DESIGN.md) zuerst lesen. Der Bericht nennt den Veröffentlichungsstatus; ein lokaler Integrationsstand ist noch kein aktualisiertes `main`.

## Bereits zusammengeführt

Die reguläre Kampagne verwendet ausschließlich die Kugelwelt. Die vorhandenen Kreaturen-, Heimat-, Dorf-, Zähmungs-, Milch-, Fernsimulations- und Körperreiseanschlüsse bleiben die gemeinsame Grundlage. Alte Flachweltdaten werden als geschützte Quellen über die vorhandene Kopiermigration gelesen; sie sind kein alternativer regulärer Spielstart.

| Pakete | Vorhandener Anschluss |
|---|---|
| ARCH-01/03/04 | Dokumentierte Datenbesitzer, Körperfassade und eindeutige Körper-ID im Speicher |
| ARCH-02/05 | Kugelmessrouten, Speicherproben, zulässige Oberflächen und tatsächliche Kollisionsbereitschaft |
| ARCH-13/14 | Persistente Kartenkacheln und bekannte Orte; vollständige Population-/Atlas-/Ortsarchive mit Neustartprüfung |
| ARCH-15/16/18/20 | Gemeinsame Nah-/Fernarbeit, gezielte Vorher-Zustände, Ressourcenbatches und erhaltene Tierhaltung/Milchfracht bei Körperwechsel |
| ARCH-17/21 | Portionierter Pflanzenaufbau, begrenzte Spawnversuche, radiales Wasser-Audio und additive vierte Nutztierspezies für Eier |
| ARCH-23/24 | Zukunftsversionsschutz, gemeinsamer Fuß-/Handanbieter, Katzenpfoten, Bärentatzen, Pferdehufe und Krebsscheren |
| ARCH-25 | Nachbarstämme, Weltkarte, Heimat/Gruppe und eigene Tiere auf DE/EN; vorhandene Sitzung bleibt bei Sprachwechsel erhalten |
| ARCH-28/29 | Explizite bestätigte Übergabe 0 → 1 und vollständige Zuordnung der 151 Godot-Tests zu 17 Verträgen |
| BP-COMMUNITY.1/.2 | Portables Kreaturenformat, lokale Bibliothek mit Import/Export und Vorschau, Editorübernahme und Startvorlagen |
| ARCH-30 | Geprüfter Schiffs-/Reise-Datenentwurf; kein spielbarer Schiffsflug |

ARCH-15 wurde in PR #68 und #73 doppelt bearbeitet. Die gemeinsame Laufzeit verwendet `VillageWork.snapshot(data, member)` aus #73. Der ergänzende Vergleich aus #68 bleibt als `village_work_observation_test` samt angepasster Messhilfe erhalten. Keine zweite Snapshot-Implementierung anlegen.

## Nächste begrenzte Arbeitspakete

**ARCH-14-Fachlieferung vom 15. September:** [Große Sammlungen im Entdeckungsbuch](WORK_ARCH14_JOURNAL_PAGING.md) verwenden begrenzte Arten-/Regionsseiten und gezielte Körperansichten. Im gemeinsamen Spieltestbranch integriert; diese Buchoptimierung nicht nochmals beginnen. Persistente Entdeckungs-/Begegnungsarchive und weitere Langzeitregister bleiben offen.

Vor Beginn den aktuellen Branch-/PR-Stand prüfen und genau einen Teilauftrag reservieren. Die Tabelle ist eine Arbeitsreihenfolge, keine neue Reservierung.

| Paket | Konkreter nächster Umfang | Abhängigkeit / Grenze |
|---|---|---|
| ARCH-06 | Präziser gemeinsamer JSON-/Regionsschreiber und Fachinventar integriert; neue Fachorte weiter anbinden | Bestehende eingefrorene Körpernachweise und Altstände erhalten |
| ARCH-07 | Feste Speicherteilnehmer integriert; neue Teilnehmer über vorhandene Adapter ergänzen | Gemeinsamer SaveService bleibt alleiniger Writer |
| ARCH-13 | Globales Manifest, Aufbewahrung/Bereinigung und Backup-Menü | Vollständige Benutzer-/Laborarchive aus #89 sind integriert |
| ARCH-14 | Separate Laborpopulation und dauerhafte Begegnungsarchive weiter auslagern | Tierzustandsschutz #79 und Journal-Seiten #88 sind integriert |
| ARCH-17 / ARCH-02 | Kalte Terrain-/Kreaturenpublikation und längere physische Rückroute untersuchen | [Vorausschau-/Jobfortsetzung](WORK_ARCH17_TERRAIN_LOOKAHEAD.md) integriert; radiale Stufenkollision aus PR #84 erhalten. Lange Ziel-PC-Route bleibt offen. |
| ARCH-19 | Gemeinsamen Stand grafisch und als native Pakete abnehmen; Ziel-PC und lange Reise messen | Einheitlicher Commit, echte Neustarts und vorhandene Integrationsprüfungen; Kugelstart bleibt aktiv |
| ARCH-22 / D3-EIER | Eierkette integriert: Legestelle, Versorgung, Produktion, Transport und Mahlzeit | Milchdaten und eindeutige Nah-/Fernzuständigkeit bleiben erhalten |
| ARCH-24 / M3-TEILE | Rüssel, weitere Formen, gespeicherte Teilrevisionen und aktive Greifer/Kiefer | Hundeschnauze, Krokodilschnauze und Oktopusmund integriert |
| ARCH-25 | Einen weiteren HUD-, Journal-, Dorf- oder Editorbereich auf DE/EN anschließen | Fähigkeitenbereich #82 zusätzlich integriert; 566 Nachrichten je Sprache |
| ARCH-26/27 | Vorhandene Siedlungs-/Transportverträge produktiv an Speicher, Vorräte und physische Träger anschließen | #85/#86 sind integrierte vorbereitende Modelle; noch keine spielbare Siedlungsgründung |
| BP-COMMUNITY.3 | Dienst-/Uploadumfang für den Community-Katalog festlegen und danach umsetzen | Lokale Bibliothek ist vorhanden; Onlineveröffentlichung, Galerie und weitere Bauplanarten bleiben offen |

**ARCH-24-Fachübergabe dieser Runde:** `agent/arch24-mouth-models-2026-09-10` liefert Hundeschnauze, Krokodilschnauze und Oktopusmund; [Bericht](WORK_ARCH24_MOUTH_MODELS.md). Diese drei Modelle nicht erneut beginnen. Rüssel bleibt ein eigenes Kopfmodul mit getrenntem Mundanschluss; weitere Schnauzen sowie gespeicherte Teilrevisionen und aktive Kiefer-/Greiferöffnung bleiben offen. Gemeinsame Änderungen: `ProgressionService` ergänzt normale Freischalteinträge für Modellalternativen; die Testregistry erhält genau einen Test. Die Fachpakete sind jetzt im gemeinsamen Testbranch vereinigt.

## Regeln für Übergaben

Jedes Fachpaket nennt Basis, exakten Commit, Vertragsversionen, geänderte Dateien, tatsächlich ausgeführte Tests und verbleibende Grenzen. Neue Tests genau einmal in `tools/validation/contracts.json` eintragen. Die gemeinsame Integration prüft betroffene Verbraucher erneut; Einzelbranch-Ergebnisse ersetzen keine gemeinsame Abnahme.

Gemeinsame Dateien wie SaveGameService, `campaign_population.gd`, Weltkartenpanel und Sprachkatalog pro Runde einem Integrationsbesitzer zuordnen. Fremde unfertige Änderungen nicht übernehmen. Neue Ideen bleiben im [Feature-Backlog](FEATURE_BACKLOG.md); bestehende Wünsche und spätere Spielphasen werden durch technische Teilprüfungen nicht automatisch als fertig markiert.

Nur die eigene Spezies entwickelt Zivilisation. Epochenwechsel brauchen ausdrückliche Bestätigung; spätere unspielbare Phasen bleiben gesperrt. Gebäudeeditor erst im Mittelalter. Kurze Oberfläche-/Orbitübergänge sind zulässig. Entfernte eigene Orte arbeiten während laufender Kampagnenzeit; Pause, Editorpause und geschlossene Anwendung produzieren nichts. Selbstgestalten bleibt freiwillig: passende lokale Vorlagen müssen ohne eigene Editorarbeit nutzbar sein.
