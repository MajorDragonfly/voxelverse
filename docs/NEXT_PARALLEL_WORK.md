# Nächste Voxelverse-Arbeiten

Stand: 10. September 2026, gemeinsamer Integrationsstand aus 28 abgeschlossenen Übergaben. [Integrationsbericht und Prüfgrenzen](INTEGRATION_2026-09-10.md), [exakte Quellen](integration-sources-2026-09-10.json), [Roadmap](../ROADMAP.md), [Architekturaufgaben](ARCHITECTURE_BACKLOG.md), [Modulanschlüsse](MODULE_CONTRACTS.md) und [Designvorgabe](VOXELVERSE_DESIGN.md) zuerst lesen. Der Bericht nennt den Veröffentlichungsstatus; ein lokaler Integrationsstand ist noch kein aktualisiertes `main`.

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

Vor Beginn den aktuellen Branch-/PR-Stand prüfen und genau einen Teilauftrag reservieren. Die Tabelle ist eine Arbeitsreihenfolge, keine neue Reservierung.

| Paket | Konkreter nächster Umfang | Abhängigkeit / Grenze |
|---|---|---|
| ARCH-06 | Große gespeicherte Double-Koordinaten verlustfrei serialisieren und Fachorte vollständig inventarisieren | Der ARCH-30-Präzisionsnachweis bleibt offen; keine unveröffentlichten lokalen Entwürfe als geliefert zählen |
| ARCH-07 | Fachlieferung: feste Speicherregistrierung und bestehende Teilnehmer angeschlossen; [Übergabe](WORK_ARCH07_SAVE_PARTICIPANTS.md) | Eigener Branch, Integration offen. SaveService mit ARCH-06 sequenziell zusammenführen; keinen zweiten Registeransatz beginnen |
| ARCH-13 | Kleines globales Manifest, vollständige Referenzaufbewahrung und sichere Bereinigung | Archive für Population/Atlas/Orte existieren bereits; Backup-Menü und Labordateien sind weitere abgegrenzte Anschlüsse |
| ARCH-14 | Verbleibende Tier-, Begegnungs- und Nahrungslangzeitregister prüfen/auslagern | Karten-/Ortspaging nicht erneut entwickeln; mehr als 256 dauerhaft veränderte Tiere gesondert nachweisen |
| ARCH-17 / ARCH-02 | Kalte Terrain-/Kreaturenpublikation, Vorausschau und längere physische Rückroute untersuchen | Gemeldeten Rückwegstillstand reproduzieren; keine FPS-Zusage aus Headless-Werten |
| ARCH-19 | Gemeinsamen Stand grafisch und als native Pakete abnehmen; Ziel-PC und lange Reise messen | Einheitlicher Commit, echte Neustarts und vorhandene Integrationsprüfungen; Kugelstart bleibt aktiv |
| ARCH-22 / D3-EIER | **Fachbranch geliefert:** Legestelle → Versorgung → Produktion → Transport → Mahlzeit; [Übergabe](WORK_ARCH22_EGG_PRODUCTION.md) | Nicht erneut reservieren. Separat integrieren; D2 bleibt Tierbesitzer, Milchdaten und alleinige Nah-/Fernzuständigkeit erhalten |
| ARCH-24 / M3-TEILE | Rüssel, zusätzliche Schnauzen und Oktopusmund als nächstes Modellpaket | Gemeinsame Kataloge/Renderer verwenden; gespeicherte Teilrevisionen und aktive Greiferöffnung sind noch eigene Anschlüsse |
| ARCH-25 | Einen weiteren HUD-, Journal-, Dorf- oder Editorbereich vollständig DE/EN anschließen | Bestehende vier Teilbereiche erhalten; Katalogschlüssel vereinigen und PO-Dateien generieren |
| ARCH-26/27 | Mehrere eigene Siedlungen und tatsächliche Transporte | Erst benötigte Regions-/Ortsverträge liefern; keine zweiten Vorrats- oder Tierdienste |
| BP-COMMUNITY.3 | Dienst-/Uploadumfang für den Community-Katalog festlegen und danach umsetzen | Lokale Bibliothek ist vorhanden; Onlineveröffentlichung, Galerie und weitere Bauplanarten bleiben offen |

## Regeln für Übergaben

Jedes Fachpaket nennt Basis, exakten Commit, Vertragsversionen, geänderte Dateien, tatsächlich ausgeführte Tests und verbleibende Grenzen. Neue Tests genau einmal in `tools/validation/contracts.json` eintragen. Die gemeinsame Integration prüft betroffene Verbraucher erneut; Einzelbranch-Ergebnisse ersetzen keine gemeinsame Abnahme.

Gemeinsame Dateien wie SaveGameService, `campaign_population.gd`, Weltkartenpanel und Sprachkatalog pro Runde einem Integrationsbesitzer zuordnen. Fremde unfertige Änderungen nicht übernehmen. Neue Ideen bleiben im [Feature-Backlog](FEATURE_BACKLOG.md); bestehende Wünsche und spätere Spielphasen werden durch technische Teilprüfungen nicht automatisch als fertig markiert.

Nur die eigene Spezies entwickelt Zivilisation. Epochenwechsel brauchen ausdrückliche Bestätigung; spätere unspielbare Phasen bleiben gesperrt. Gebäudeeditor erst im Mittelalter. Kurze Oberfläche-/Orbitübergänge sind zulässig. Entfernte eigene Orte arbeiten während laufender Kampagnenzeit; Pause, Editorpause und geschlossene Anwendung produzieren nichts. Selbstgestalten bleibt freiwillig: passende lokale Vorlagen müssen ohne eigene Editorarbeit nutzbar sein.
