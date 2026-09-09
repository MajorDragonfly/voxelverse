# Nächste Voxelverse-Arbeiten: Umzug der Kampagne

Stand: 9. September 2026, nach der zweiten Integrationsrunde. Diese Aufträge ersetzen die frühere Runde „D1 neu entwickeln / D2 anbinden / D3 später“. Die fertigen D1–D3-, B1–B3-, Dorf-, Nachbar-, UI-, Karten-, Sprach- und Wartungspakete sind zusammengeführt. Ausgangspunkt ist der in [INTEGRATION_SPHERICAL_2026-09-09.md](INTEGRATION_SPHERICAL_2026-09-09.md) dokumentierte Integrationsstand.

**Zuerst lesen:** [ROADMAP.md](../ROADMAP.md), [SPHERICAL_CAMPAIGN_MIGRATION.md](SPHERICAL_CAMPAIGN_MIGRATION.md), [VOXELVERSE_DESIGN.md](VOXELVERSE_DESIGN.md). Der vollständige Kugelumzug hat Vorrang vor neuen Epochen. Die belebte Kugelszene bleibt bis zur tatsächlichen Kampagnenintegration ein eigener Bereich.

## 1. Gemeinsame Grundlage – erweiterten Umzug abschließen

**Bereits eingebaut:** Save 8/Kampagne 2, `surface_context.gd`, der gemeinsame Kugelstart, radiale Spielerorte, Karten, frühe Kopiermigration mit Quellarchiv und Rückweg. [WORK_M1E_CAMPAIGN.md](WORK_M1E_CAMPAIGN.md) ist der aktuelle Anschlussvertrag. Keine zweite Kampagne oder Speicherdienststruktur anlegen. Noch offen sind die Zielzuordnung und Laufzeitanbindung vorhandener Regions-, Heimat-, Pflichtarten-, Dorf- und Tierhaltungsdaten; ihre Sperren dürfen erst nach entsprechendem Erhaltungsnachweis entfallen.

„Vervollständige M1e auf dem bestehenden Vertrag: Verwende Cube-Sphere-Adressen und den bestehenden radialen Oberflächenadapter als Kampagnenkontext. Implementiere einen versionierten Start-/Lade-/Speicherweg für neue Kugelkampagnen. Erhalte den bisherigen Flachwelt-Lader und baue eine atomare Kopiermigration mit Manifest für vorhandene persistente Orte, Bewohner, Tiere, Vorräte und Fortschritt. Kein stilles Umdeuten alter XYZ-Werte, keine Neugenerierung bestehender Spezies. Liefere Vertrag, Implementierung, Schreibfehler-/Zukunftsversionstests und einen frischen Prozess als Nachweis. Änderungen an GameState und SaveGameService gehören zu diesem gemeinsamen Paket.“

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

Nach M1e können unabhängige Verbraucher an denselben veröffentlichten Vertrag anschließen. Der volle Neue-Spiel-Umschalter (M1i) kommt erst nach der Abnahmekette im Migrationsauftrag. D4, Mittelalter, Neuzeit und Raumfahrt folgen auf dieser Grundlage.
