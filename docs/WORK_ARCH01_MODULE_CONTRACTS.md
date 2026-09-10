# Übergabe ARCH-01 – Datenbesitzer und Modulverträge

Stand: 10. September 2026. Auftrag **ARCH-01**, Zuordnung M0/M1e. Status **geliefert, Integration offen**. Branch `feature/arch-01-module-contracts`, [PR #49](https://github.com/MajorDragonfly/voxelverse/pull/49) nach `main`.

## Grundlage und Umfang

Geprüfter Quellcommit: **`ea900f2e09946660694a9e59399b4680a5655a85`**, veröffentlichter `main` nach PR #48. Eigene Arbeitskopie; kein fremder unfertiger Branch übernommen. ARCH-02/05/20/23/25/29 waren laut aktueller Aufgabenvergabe bereits besetzt. Die Reservierung wurde vor der Facharbeit im Backlog und im eigenen Entwurfs-PR veröffentlicht.

[MODULE_CONTRACTS.md](MODULE_CONTRACTS.md) liefert:

- Besitzerinventar für Kampagne, Körper, Oberfläche, Regionen/Ökologie, Entwürfe, Heimat, D1, D2, Dorf, Vorräte/Fracht, D3, Nachbarn, Karte, Fortschritt/Begegnungen und Simulationsübergabe.
- Konkrete vorhandene Funktionen für Lesen, Schreiben, Validierung und Migration; Versionsmatrix und Speicherorte statt eines neuen Dienstentwurfs.
- Unterscheidung zwischen Lesekopie, geteiltem Datensatz, aktivem Fachregister, Szenenabbild und Cache; Quellenverweise für die tatsächlichen Kopiergrenzen.
- Gemeinsamer Save-/Ladeablauf, Regions-Flush, Körperwechsel, Pause, Aktivierung/Abbau der Fachhosts und die Transaktionsgrenzen der bestehenden Spielketten.
- Anschlussgrenzen für die nächsten ARCH-Pakete; spätere Ressourcen-, Bauplan-, Siedlungs- und Epochenverträge sind weiterhin deren eigene Aufgaben.

Die einzigen Änderungen betreffen sechs Markdown-Dateien: das neue Inventar und diese Übergabe sowie [Roadmap](../ROADMAP.md), [Architektur-Backlog](ARCHITECTURE_BACKLOG.md), [Arbeitsverteilung](NEXT_PARALLEL_WORK.md) und die Kennzeichnung des historischen [M0-Vertrags](CAMPAIGN_CONTRACTS.md). Keine Laufzeitdatei, kein Saveformat, kein Test, keine CI-Datei und kein gemeinsamer Fachkatalog wurde geändert.

## Fachlich wichtige Ergebnisse

| Befund | Konsequenz für Folgearbeiten |
|---|---|
| Save 9 / GameState 4 / Kampagne 3; Körper nach ID statt Seed indiziert | Historische M0-/M1e-Versionsangaben nicht als aktuelle Importvorgabe verwenden. |
| D2 besitzt während aktiver Haltung eine kontrollierte Arbeitskopie | D3 muss `CampaignDomestication.current_registry()` lesen; der gespeicherte Body-Lookup ersetzt nicht das aktive Register. |
| Wildtier-Begegnungen können bereits in Regionspayloads liegen | `ProgressionService.get_saved_creature_encounter()`/`store_creature_encounter()` nutzen; die alte zentrale Begegnungstabelle allein ist unvollständig. |
| `RegionStore.get_value(..., false)` ist keine Lesekopie | Änderungen ausdrücklich als schreibend markieren; UI darf den geteilten Cache nicht bearbeiten. |
| Regionale Speicherung ist bereits teilweise segmentiert | ARCH-13/14 auf dem vorhandenen Store aufbauen. Save-JSON benötigt die referenzierten Blobs; noch keine sichere automatische Blobbereinigung. |
| Dorfarbeit läuft nah und fern am gleichen Datensatz | Kein zweites Dorf-/Milchmodell; Besitzer und Zeitcursor zusammen mit Fracht erhalten. |
| Generische Bauplannormalisierung hat noch keinen vollständigen Zukunftsversionsschutz | ARCH-23 bleibt zuständig; das Inventar behauptet dessen Ergebnis nicht vorab. |

## Nachweis und Grenzen

Geprüft wurden die Implementierungen und ihre direkten Aufrufer für Kopier-/Bindeverhalten, Schemawerte, Import/Export, Save-Flush, Fachtransaktionen und Lebenszyklen. Die Abschlussprüfung ergab **137 gültige lokale Dateiverweise**, **7 konsistente Tabellen** in Inventar/Übergabe und **131 vorhandene Funktionsanschlüsse in 27 Quelldateien**. Diese 27 Quelldateien entsprechen bytegenau dem geprüften Basiskommit. Die Prüfung benutzt einen temporären Quellen-/Linkabgleich, keine neue Spiel-Testsuite. `git diff --check` ist fehlerfrei; die Lieferung umfasst ausschließlich die sechs vorgesehenen Markdown-Dateien.

Dies ist eine Quellen-/Dokumentationsprüfung. Für das Paket wurden keine Laufzeittests neu ausgeführt und keine neue CI-Suite angelegt. Die im Inventar verlinkten bestehenden Regressionen dienen als Nachweisquellen für ihre jeweiligen Implementierungsstände. Spieltest, Darstellung, Windows-Paket und Ziel-PC-FPS werden durch diese Lieferung nicht abgenommen. Ein neuer allgemeiner Speichermodulmechanismus gehört weiterhin zu ARCH-07.

Der exakte veröffentlichte Dokumentationscommit und die Ergebnisse der Abschlussprüfung stehen in der PR-Beschreibung. Nach dem Merge den Integrationsstatus in Roadmap/Backlog/Arbeitsverteilung aktualisieren; parallele Dokumentergänzungen übernehmen, keine Gesamtdatei durch einen älteren Stand ersetzen. Änderungen aus ARCH-05/20/23/25 können die hier erfassten API-/Schemawerte verändern und benötigen dann eine gezielte Aktualisierung des Inventars.
