# Nächste Voxelverse-Arbeiten

Aktuelle Basis und Lieferstand: [PROJECT_STATUS.md](PROJECT_STATUS.md). Die Lieferungen #78–89 sind über PR #90 in `main` enthalten. Für neue Chats gelten [AGENTS.md](../AGENTS.md) und der [Arbeitsablauf](PARALLEL_WORKFLOW.md). Alte Integrationsberichte nur für einen konkreten Quell- oder Fehlernachweis öffnen; sie sind keine gemeinsame Pflichtlektüre.

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
| ARCH-28/29 | Explizite bestätigte Übergabe 0 → 1 und vollständige Testzuordnung; aktuelle Anzahl aus `tools/check_validation_contracts.py` |
| BP-COMMUNITY.1/.2 | Portables Kreaturenformat, lokale Bibliothek mit Import/Export und Vorschau, Editorübernahme und Startvorlagen |
| ARCH-30 | Geprüfter Schiffs-/Reise-Datenentwurf; kein spielbarer Schiffsflug |

ARCH-15 wurde in PR #68 und #73 doppelt bearbeitet. Die gemeinsame Laufzeit verwendet `VillageWork.snapshot(data, member)` aus #73. Der ergänzende Vergleich aus #68 bleibt als `village_work_observation_test` samt angepasster Messhilfe erhalten. Keine zweite Snapshot-Implementierung anlegen.

## Nächste begrenzte Arbeitspakete

**ARCH-14-Fachlieferung vom 15. September:** [Große Sammlungen im Entdeckungsbuch](WORK_ARCH14_JOURNAL_PAGING.md) verwenden begrenzte Arten-/Regionsseiten und gezielte Körperansichten. Über PR #90 in `main` integriert; diese Buchoptimierung nicht nochmals beginnen. Persistente Entdeckungs-/Begegnungsarchive und weitere Langzeitregister bleiben offen.

Die ausführbaren nächsten Teilaufträge stehen ausschließlich in
[`tools/workflow/packets.json`](../tools/workflow/packets.json). Der Katalog führt
keine Live-Reservierungen. Der Integrationschat vergibt die eindeutigen IDs und
gemeinsamen Schreibbereiche einmal je Runde.

```sh
python3 tools/work_packet.py list
python3 tools/work_packet.py show ARCH-17-PUBLISH
python3 tools/work_packet.py conflicts ARCH-17-PUBLISH ARCH-13-MANIFEST ARCH-24-TRUNK
```

Die ausführlichen ARCH-Ziele bleiben im [Architektur-Backlog](ARCHITECTURE_BACKLOG.md).
Weitere geplante Funktionen wie Online-Baupläne bleiben im [Feature-Backlog](FEATURE_BACKLOG.md).

**ARCH-24-Fachübergabe dieser Runde:** `agent/arch24-mouth-models-2026-09-10` liefert Hundeschnauze, Krokodilschnauze und Oktopusmund; [Bericht](WORK_ARCH24_MOUTH_MODELS.md). Diese drei Modelle nicht erneut beginnen. Rüssel bleibt ein eigenes Kopfmodul mit getrenntem Mundanschluss; weitere Schnauzen sowie gespeicherte Teilrevisionen und aktive Kiefer-/Greiferöffnung bleiben offen. Gemeinsame Änderungen: `ProgressionService` ergänzt normale Freischalteinträge für Modellalternativen; die Testregistry erhält genau einen Test. Die Fachpakete sind über PR #90 in `main` vereinigt.

## Regeln für Übergaben

Jedes Fachpaket nennt Basis, exakten Commit, Vertragsversionen, geänderte Dateien, tatsächlich ausgeführte Tests und verbleibende Grenzen. Neue Tests genau einmal in `tools/validation/contracts.json` eintragen. Die gemeinsame Integration prüft betroffene Verbraucher erneut; Einzelbranch-Ergebnisse ersetzen keine gemeinsame Abnahme.

Gemeinsame Dateien wie SaveGameService, `campaign_population.gd`, Weltkartenpanel und Sprachkatalog pro Runde einem Integrationsbesitzer zuordnen. Fremde unfertige Änderungen nicht übernehmen. Neue Ideen bleiben im [Feature-Backlog](FEATURE_BACKLOG.md); bestehende Wünsche und spätere Spielphasen werden durch technische Teilprüfungen nicht automatisch als fertig markiert.

Nur die eigene Spezies entwickelt Zivilisation. Epochenwechsel brauchen ausdrückliche Bestätigung; spätere unspielbare Phasen bleiben gesperrt. Gebäudeeditor erst im Mittelalter. Kurze Oberfläche-/Orbitübergänge sind zulässig. Entfernte eigene Orte arbeiten während laufender Kampagnenzeit; Pause, Editorpause und geschlossene Anwendung produzieren nichts. Selbstgestalten bleibt freiwillig: passende lokale Vorlagen müssen ohne eigene Editorarbeit nutzbar sein.
