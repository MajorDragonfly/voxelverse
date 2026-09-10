# Nächste Voxelverse-Arbeiten: Umzug der Kampagne

Stand: 9. September 2026, nach der zweiten Integrationsrunde. Diese Aufträge ersetzen die frühere Runde „D1 neu entwickeln / D2 anbinden / D3 später“. Die fertigen D1–D3-, B1–B3-, Dorf-, Nachbar-, UI-, Karten-, Sprach- und Wartungspakete sind zusammengeführt. Ausgangspunkt ist der in [INTEGRATION_SPHERICAL_2026-09-09.md](INTEGRATION_SPHERICAL_2026-09-09.md) dokumentierte Integrationsstand.

**Zuerst lesen:** [ROADMAP.md](../ROADMAP.md), [SPHERICAL_CAMPAIGN_MIGRATION.md](SPHERICAL_CAMPAIGN_MIGRATION.md), [VOXELVERSE_DESIGN.md](VOXELVERSE_DESIGN.md). Der vollständige Kugelumzug hat Vorrang vor neuen Epochen. Die belebte Kugelszene bleibt bis zur tatsächlichen Kampagnenintegration ein eigener Bereich.

## Aktueller gemeinsamer Arbeitsstand

**ARCH-01, Lieferung vom 10. September:** [Modulanschlüsse](MODULE_CONTRACTS.md) und [Übergabe](WORK_ARCH01_MODULE_CONTRACTS.md) auf `main` `ea900f2e09946660694a9e59399b4680a5655a85`; [PR #49](https://github.com/MajorDragonfly/voxelverse/pull/49), Integration offen. Das vollständige Besitzerinventar ist geliefert; ARCH-03/04 sind bereits zuvor integriert. Den historischen Auftrag „ARCH-01 und anschließend ARCH-03“ unten nicht erneut beginnen. ARCH-02/05/20/23/25/29 sind laut Arbeitsvergabe vom 10. September in anderen Chats; gemeinsame Dokumentänderungen beim Merge einzeln abgleichen.

M1f, die lokale M1g-Kette, entwickelte Kopiermigration und regionaler Population-Speicher sind über PR #45 integriert. Die anschließende Runde liefert Körper-ID-Speicherung, gemeinsame Dorfregeln, begrenzte Navigationsarbeit, Fernsimulation und sichere Körperwechsel. Vor weiterer Arbeit [WORK_CAMPAIGN_SCALING.md](WORK_CAMPAIGN_SCALING.md) lesen. ARCH-03/04 nicht erneut entwickeln. ARCH-13/14 (kleines globales Manifest, segmentierter Langzeitbestand), die umfassende Langzeit-/Ziel-PC-Messung und ARCH-19 bleiben die nächsten Skalierungsgrenzen. Die ursprünglichen Aufträge unten sind die Gesamtplanung; ihr früherer Status ist keine neue Arbeitsanweisung.

## Architekturprüfung: Aufträge vor dem Start konkret wählen

Ergänzung vom 9. September 2026 auf geprüftem `main` `d94d1e5f8a85b3e1a77d46984f381d14d84a8cf7`: [Architekturbefunde](ARCHITECTURE_SCALABILITY_AUDIT.md) und [30 ausführbare Teilaufträge](ARCHITECTURE_BACKLOG.md) sind die zusätzliche Arbeitsgrundlage. Die folgenden fünf Stränge bleiben zuständig; ARCH-IDs zerlegen ihre Arbeit und sind keine konkurrierenden Neuentwicklungen. Vor Arbeitsbeginn aktuellen gemeinsamen Commit und gelieferte Pakete abgleichen. M1f ist in einem anderen Arbeitsstand bereits in Bearbeitung; dieses Audit bewertet ausschließlich veröffentlichten Code und startet diesen Auftrag nicht erneut.

| Strang | Erster sinnvoller begrenzter Auftrag | Danach / Abhängigkeit |
|---|---|---|
| Integration / Datenkern | ARCH-01, dann ARCH-03: Datenbesitzer und Körperzugriff bündeln | ARCH-04/06/07; entwickelte Kopiermigration ARCH-12 erst mit fertigen Verbrauchern |
| Kreaturen auf Kugeln | Laufendes M1f gegen ARCH-08 abgleichen | ARCH-09 nach gemeinsamem Ortsvertrag; Langzeitregister ARCH-14 nach Regionsspeicher |
| Dorf auf Kugeln | ARCH-10: lokale Navigation/Fundamente radial | ARCH-11 mit ARCH-09; Controllerregeln ARCH-15 innerhalb derselben Zuständigkeit |
| Leistung / dauerhafte Welt | ARCH-02: Messroute und Budgetinventar | ARCH-05 mit Oberflächenbesitzer; ARCH-13 mit Save-Besitzer; ARCH-16/17/18 nach ihren Vertragsabhängigkeiten |
| UI / Inhalt / Verträge | ARCH-25 als ein klar begrenzter DE/EN-Bildschirm; ARCH-23 separat im Editorstrang | Eier über ARCH-20/21/22, Teile über ARCH-24; gemeinsame Kataloge nicht gleichzeitig unabhängig ändern |

**Jetzt direkt verwendbarer Auftrag für den Datenkern:**

„Übernimm ARCH-01 und anschließend nur ARCH-03 aus `docs/ARCHITECTURE_BACKLOG.md` am aktuellen gemeinsamen Voxelverse-main. Erfasse zuerst Datenbesitzer und Erweiterungsverträge. Bündele danach Körperzugriffe hinter dem vorhandenen Kampagnenmodell; Lesezugriff, Anlage und veränderbaren Zustand ausdrücklich trennen. Bestehende Speicherformate und IDs erhalten. Keine neue Save-Struktur, keine Seed-Neuvergabe und keine fremden unfertigen Änderungen übernehmen. Liefere genau diese Fassade mit Neu-/Altstandsnachweis und Übergabe für ARCH-04.“

**Parallel verwendbarer Messauftrag:**

„Übernimm ARCH-02. Messe den tatsächlichen gemeinsamen Stand mit reproduzierbarer Route und 1/10/100 Körpern für Speicherproben. Erfasse Frame-/Uploadzeiten, Queues, aktive Objekte und Speicherentwicklung. 1080p60 auf Gaming-PC ist das vorläufige Ziel; unbekannte Zielhardware und nicht messbare GPU-Werte offen kennzeichnen. Keine Grenzen ohne Messung erhöhen. Liefere Zahlen und konkrete Anschlussaufgaben für ARCH-13/17.“

Gemeinsame Dateien und Kataloge erhalten pro Runde einen Integrationsbesitzer. Die vollständigen Abhängigkeiten, Abnahmen und Übergaberegeln stehen beim jeweiligen ARCH-Auftrag. Größere Funktionspakete beginnen erst nach ihrem benötigten Vertrag, können aber vorbereitende Daten-/Modellarbeiten unabhängig liefern.

## 1. Gemeinsame Grundlage – erweiterten Umzug abschließen

**Bereits eingebaut:** Save 8/Kampagne 2, `surface_context.gd`, der gemeinsame Kugelstart, radiale Spielerorte, Karten, frühe Kopiermigration mit Quellarchiv und Rückweg. [WORK_M1E_CAMPAIGN.md](WORK_M1E_CAMPAIGN.md) ist der aktuelle Anschlussvertrag. Keine zweite Kampagne oder Speicherdienststruktur anlegen. Noch offen sind die Zielzuordnung und Laufzeitanbindung vorhandener Regions-, Heimat-, Pflichtarten-, Dorf- und Tierhaltungsdaten; ihre Sperren dürfen erst nach entsprechendem Erhaltungsnachweis entfallen.

„Vervollständige den noch offenen Teil von M1e gemäß ARCH-03/04/06/07/12. Der Start-/Lade-/Speicherweg und die frühe Kopiermigration existieren bereits. Bündele zuerst Körperzugriffe und sichere eindeutige Körperidentität, dann die versionierten Fachorte. Erweitere das vorhandene Manifest und den Kopierweg nach Fertigstellung der M1f-/M1g-Verbraucher auf tatsächlich entwickelte Stände mit Orten, Bewohnern, Tieren, Vorräten und laufender Fracht. Erhalte die Lesbarkeit der bisherigen Flachweltdaten ausschließlich für Kopiermigration und Wiederherstellung von Originalarchiven; kein stilles Umdeuten alter XYZ-Werte, keine Neugenerierung bestehender Spezies. Liefere Schreibfehler-/Zukunftsversionstests und einen frischen Prozess als Nachweis. Änderungen an GameState und SaveGameService gehören zu diesem gemeinsamen Paket.“

## 2. Kreaturenphase auf der Kugel

„Setze nach dem veröffentlichten M1e-Vertrag M1f um: Überführe Spielersteuerung, Kamera, Scanner, Sammeln/Essen, Wildtierverhalten, D1-Rollen und Heimatgruppe auf dieselbe radiale Oberfläche. Nutze bestehende Objekt-/Arten-IDs, Körperentwürfe, Fortschritt und Bücher. Prüfe echte Interaktionen, Flächenkanten, Ursprungswechsel, Pause und Neustart. Die neue Laufzeit muss die gemeinsame Kreaturenphase sein; eine zweite isolierte Demo erfüllt den Auftrag nicht.“

## 3. Dorf, Zähmung und Tierhaltung auf der Kugel

„Setze nach M1e den radialen Teil M1g um. Übernimm die vorhandene Dorfwirtschaft, Wachstum bis sechs Bewohner, Nachbarhilfe, D2-Besitz/Befehle und D3-Pflege/Milch. Ersetze planare Orte und Welt-Y-Annahmen über den gemeinsamen Kontext. Halte Gruppenbewegung und Baufundamente lokal begrenzt; stelle echte erreichbare Wege und Materialtransporte sicher. D2 und D3 verwenden den jetzt vorhandenen gemeinsamen Tierbestand. Abnahme: Aufstieg mit gleichen Bewohnern → zähmen → Tierplatz → versorgen → Milchtransport → Pause/Neustart. Keine neuen Bürger aus fremden Tierarten.“

## 4. Skalierung, Gewässer und Audio

„Übernimm M1h. Messe zuerst aktive Terrain-/Fauna-/Objektgrenzen und Reiseverhalten. Schließe Wasser, Unterwasseransicht und räumliches Audio an den gleichen Oberflächenkontext an. Implementiere anschließend eine explizite Übergabe zwischen Nah- und Fernsimulation sowie begrenztes Regionsladen. Vorräte, Tierpflege und Fracht haben genau einen Simulationsbesitzer; Pause und geschlossene Anwendung erzeugen keine Offline-Produktion. Liefere Messroute, Hardware/Renderer, Speicherentwicklung und Übergabetests statt einer unbelegten FPS-Zusage.“

## 5. Gemeinsame Oberfläche und Abnahme

„Erhalte das gemeinsame Buch, Mini-/Weltkarte und die Designvorgabe. Führe die vorhandene Deutsch-/Englisch-Verwaltung schrittweise durch HUD, Buch, Dorf und Editor; L1 deckt bisher nur einen Teil der Oberfläche ab. Karten folgen dem tatsächlichen Körper und Spielerwissen. Prüfe neue Kugelkampagne und migrierten Altstand bei 1920×1080, 1280×720, 2560×1080 und großer UI-Skalierung. Verwende dieselben Auswahl-, Pause-, Speicher- und Rückmeldedienste.“

## Übergabe und Zusammenführung

Alle Folgearbeiten starten vom veröffentlichten gemeinsamen Commit. Ein Fachpaket liefert exakten Commit, Vertragsversionen, veränderte Dateien, Tests und offene Grenzen. Die Integration prüft gegenseitige Abhängigkeiten erneut; Einzelbranch-Nachweise gelten nicht automatisch für den Gesamtstand. Gemeinsame Verträge und Roadmap werden durch die Integration gepflegt. Keine fremden unfertigen Arbeitsstände übernehmen.

Nach der bereits vorhandenen M1e-Grundlage können unabhängige Verbraucher an denselben veröffentlichten Vertrag anschließen. **Entscheidung vom 10. September:** Der Kugelstart ist ohne vorgeschaltete Ziel-PC-Abnahme der einzige reguläre Spielweg. Neue Spiele, Fortsetzen und Editor-/Laborrückwege dürfen keine Flachwelt aktivieren. [WORK_SPHERE_ONLY_ENTRY.md](WORK_SPHERE_ONLY_ENTRY.md) beschreibt die Umstellung. Die verbleibende M1i/ARCH-19-Abnahme und Fehlerbehebung erfolgen direkt auf der Kugelwelt. D4, Mittelalter, Neuzeit und Raumfahrt folgen auf dieser Grundlage. Kurze Oberfläche-/Orbitübergänge sind zulässig; entfernte eigene Siedlungen sollen während laufender Kampagnenzeit vereinfacht weiterarbeiten, nicht während Pause oder geschlossener Anwendung. Diese bestätigten Entscheidungen gehören zu ARCH-16/18/30.
