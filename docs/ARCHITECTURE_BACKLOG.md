# Voxelverse – ausführbare Architekturaufgaben

Stand: 9. September 2026. Grundlage der Codeprüfung: `d94d1e5f8a85b3e1a77d46984f381d14d84a8cf7` auf veröffentlichtem `main`. [Befunde und Grenzen](ARCHITECTURE_SCALABILITY_AUDIT.md), [Roadmap](../ROADMAP.md), [Kugelumzug](SPHERICAL_CAMPAIGN_MIGRATION.md) und [Arbeitsverteilung](NEXT_PARALLEL_WORK.md) zusammen lesen.

**Das ursprüngliche Audit plante die ARCH-Aufgaben; aktuelle Lieferstände stehen bei den jeweiligen Aufträgen und in der Zuordnung unten.** ARCH-IDs zerlegen bestehende M1–M9-/D-Aufträge; sie sind keine zusätzlichen Spielphasen. Vor Arbeitsbeginn den aktuellen veröffentlichten Stand vergleichen: Bereits durch einen Fachchat gelieferte Arbeit mit Commit und Nachweis zuordnen, nicht nochmals implementieren. Laufende Änderungen in fremden Checkouts bleiben unangetastet.

## Aktueller Integrationsstand vom 10. September

28 Übergaben sind in diesem Stand zusammengeführt. [Bericht, Prüfungen und Veröffentlichung](INTEGRATION_2026-09-10.md), [Quellcommits](integration-sources-2026-09-10.json) und [nächste Teilaufträge](NEXT_PARALLEL_WORK.md) gelten vor den historischen Startaufträgen. ARCH-01/05/20/21/23 sind geliefert; ARCH-02/13/14/17/24/25/28/29/30 enthalten die unten genannten Teilabschlüsse. Die noch offenen Punkte bleiben offen.

## Zuordnung der laufenden Implementierung

[WORK_SPHERICAL_GAMEPLAY.md](WORK_SPHERICAL_GAMEPLAY.md) dokumentiert PR #45. [WORK_CAMPAIGN_SCALING.md](WORK_CAMPAIGN_SCALING.md) ergänzt auf dessen `main`-Basis ARCH-03/04, den gemeinsamen Arbeitskern aus ARCH-15, die erste Fernsimulation aus ARCH-16, Navigationsbudgets aus ARCH-17 und Körperreisen aus ARCH-18. Die folgenden Häkchen beschreiben gelieferte Teilpunkte; sie ersetzen keine vollständige M1i-/Ziel-PC-Abnahme. ARCH-13/14, weitere Langzeitbudgets und ARCH-19 bleiben offen.

## Beschlossene Leitplanken

- Lars hat in dieser Architekturprüfung bestätigt: **kurze Übergänge zwischen Oberfläche und Orbit sind zulässig**. Start, Landung und beide Schiffstypen bleiben spielbare Ziele; lückenloser Boden-Orbit-Flug ist keine Pflicht.
- **Entfernte eigene Siedlungen arbeiten während des laufenden Spiels vereinfacht weiter.** Versorgung, Aufträge und Fracht bleiben wirksam; es braucht keinen dargestellten Bewohner für jeden entfernten Arbeitsschritt. Pause, Editorpause und geschlossene Anwendung erzeugen weiterhin keine Produktion.
- Vorläufiges Leistungsziel: **Gaming-PC, 1920 × 1080, 60 FPS**. CPU, GPU, RAM und Grafikpreset sind noch offen. Das ist ein Entwicklungsziel, kein gemessenes Ergebnis und keine Mindesthardware-Zusage.
- Weiter gültig: zunächst Singleplayer; feste Geländeoberfläche mit abbaubaren Einzelobjekten, kein allgemeines Graben/Tunnelsystem; nur eigene Spezies entwickelt Zivilisation; ausdrückliche Epochenbestätigung; Gebäudeeditor erst Mittelalter. Frei begehbare Innenräume eines bewegten Schiffs sind kein verpflichtender Erstumfang.
- Vorhandene IDs, Save-/Körper-/Ereignisverträge und gemeinsame UI weiterverwenden. Kein Totalumbau, kein zusätzlicher SaveService, kein vorsorgliches ECS-/Plugin-Großsystem. Eine Abstraktion zuerst mit einem vorhandenen realen Ablauf beweisen, dann den zweiten Verbraucher ergänzen.

## Reihenfolge und Zuständigkeit

| Etappe | Aufgaben | Ergebnis / Tor |
|---|---|---|
| Jetzt neben laufendem Umzug | ARCH-01, 02, 05, 29 | Zuständigkeiten, gemessene Ausgangslage, belastbare Oberflächengrenzen und Prüfkatalog |
| Gemeinsame Verträge | ARCH-03 → 04, ARCH-06 → 07 | Eindeutige Körper und versionierte Ortsdaten; atomarer gemeinsamer Save bleibt erhalten |
| Spielbarer Kugelumfang | ARCH-08 → 09; ARCH-10 → 11; ARCH-12 mit beiden Zweigen | Kreaturenphase und Stamm am selben Ort samt entwickelten Altständen |
| Langzeitbetrieb | ARCH-13 → 14 → 16, ARCH-15; ARCH-17, 18 | Dauerhafte Regionen, ein Simulationsbesitzer, begrenzte Arbeit und Körperwechsel |
| Regulärer Kugelstart | ARCH-19 | Kugelstart bereits freigegeben; verbleibende M1i-Abnahme auf der Kugelwelt |
| Günstigerer Funktionsausbau | ARCH-20 → 21 → 22; ARCH-23, 24, 25 | Gemeinsame Produktionskette, Eier, versionierte Körperteile/Baupläne und Darstellung |
| Mehr Siedlungen / weitere Epochen | ARCH-26, 27, 28 | Mehrere Orte und Verkehrsverbindungen; Übergaben nur für spielbare Epochen |
| Weltraum | ARCH-30 → bestehende M9.1–M9.6 | Expeditionsbasis, individuelles Beiboot, Landung, Rückkehr, Ausbau |

Die Tabelle ist eine Übersicht. Die Abhängigkeiten im jeweiligen Auftrag sind verbindlich; unabhängige Daten-/Modellarbeit darf früher beginnen. Inhalte wie Eier dürfen nach der geprüften radialen Dorfkette geliefert werden, ohne auf sämtliche spätere Städtesysteme zu warten. Fernsimulation muss vor einer Spielschleife stehen, die entfernte eigene Orte voraussetzt.

**Gemeinsame Schreibbereiche mit einem Besitzer je Integrationsrunde:** `autoload/game_state.gd`, `autoload/save_game_service.gd`, `core/campaign/*`, `world/tribe/tribe_controller.gd`, `project.godot`, gemeinsame Kataloge sowie Roadmap/Arbeitsverteilung. ARCH-03/04/06/07/12/13/18/28 ändern teils dieselben Dateien und werden darin nacheinander integriert. ARCH-10/11/20/21/26/27 teilen Dorfanschlüsse. Vorab Vertrag liefern; Verbraucher ändern keine konkurrierenden Versionen.

## Jetzt und gemeinsamer Datenkern

### ARCH-01 – Datenbesitzer und Modulvertrag erfassen

**Integration 10. September:** Im gemeinsamen Integrationsstand enthalten (PR #49); Besitzerinventar mit den neueren Verträgen aktualisiert.

- **Lieferung vom 10. September 2026:** `feature/arch-01-module-contracts`, Basis `ea900f2e09946660694a9e59399b4680a5655a85`; Status **im gemeinsamen Integrationsstand enthalten** ([PR #49](https://github.com/MajorDragonfly/voxelverse/pull/49)). [Datenbesitzer und Modulanschlüsse](MODULE_CONTRACTS.md), [Übergabe und Prüfumfang](WORK_ARCH01_MODULE_CONTRACTS.md). Reines Codeinventar; ARCH-02/05/20/23/25/29 bleiben getrennt.
- **Zuordnung:** M0, M1e. **Vorher:** aktueller gemeinsamer Commit. **Bereich:** `core/campaign`, Speicher-/Fachverträge; zunächst Dokumentation.
- [x] Kampagne, Körper, Regionen, Entwürfe, Heimat, D1, D2, Dorf, Nachbarn, Karte und Fortschritt mit genau einem autoritativen Besitzer erfassen.
- [x] Pro Modul ID, Schema, Lesezugriff, Befehle, Validator/Migration, Speicherteilnahme, Lebenszyklus und benötigte atomare Verbuchungen dokumentieren.
- [x] Lesekopie, veränderbaren Zustand, Szenenabbild und Cache unterscheiden; Sprache/Icons gehören zur Präsentation, Besitz nicht zur UI.
- **Fertig:** Ein neuer Verbraucher kann anhand der Tabelle seinen Anschluss finden; kein Modul besitzt dieselben Tiere/Vorräte ein zweites Mal. Keine neue Dienststruktur allein für die Dokumentation bauen.

### ARCH-02 – Messroute und vorläufige Budgets

**Integration 10. September:** Kugelmessroute, Teilzeit-/Objekt-/Speicherdiagnostik und 1/10/100-Körperproben integriert (#58). Lange physische Rückroute, entwickelte Reiseprofile und Zielhardware bleiben offen.

- **Zuordnung:** M1h/M10. **Vorher:** keiner; parallel zum Umzug. **Bereich:** vorhandene Diagnostik und `tools`.
- [ ] Kaltstart, 10 Minuten Gehen mit Richtungswechseln, Rückkehr, Speichern/Laden und später Dorf/Reise als wiederholbare Routen mit Seed und Zustand festhalten.
- [ ] CPU-/GPU-Framezeit getrennt, Median/p95/p99, Uploadspitzen, aktive Nodes/Kollisionen/Tiere, Worker/Queues, RAM und soweit messbar VRAM erfassen. Fehlende Messwerte ausdrücklich kennzeichnen.
- [ ] Save-Kosten mit 1/10/100 besuchten Körpern und wachsendem geändertem Regionsbestand messen; Zeit für Kopie, Validierung, Serialisierung und I/O sowie Dateigröße ausweisen.
- [ ] Für 1080p60 beträgt das Frameziel 16,67 ms. Teilbudgets und tolerierbare Ladespitzen erst mit genauer Hardware, Renderer und Preset festlegen; Headless-Werte getrennt halten.
- **Fertig:** Reproduzierbarer Bericht mit Rohwerten und Versionsangabe; keine FPS-Zusage aus Import-/Headless-Prüfungen. Ohne Zielhardware bleibt deren Abnahme offen, die Instrumentierung kann abgeschlossen werden.

### ARCH-03 – Körperzugriff bündeln

- **Zuordnung:** M1e, Vorbereitung M9. **Vorher:** ARCH-01. **Bereich:** Kampagne und bisherige Seed-Verbraucher; ein Integrationsbesitzer.
- [x] Eine kleine gemeinsame Fassade für `get_body_by_id`, aktiven Körper und ausdrückliche Anlage einführen; zunächst vorhandenes Speicherlayout erhalten.
- [x] `body_for_seed`-Zugriffe aus Save, Dorf, D2, Fortschritt und Karten über diese Fassade führen. Leseanfragen erzeugen keine neuen Körper.
- [x] Legacy-Lookup braucht Systemkontext; Mehrdeutigkeit wird gemeldet, nicht durch den ersten gefundenen Seed aufgelöst.
- **Fertig:** Bestehende Kampagnen behalten IDs und Inhalt; neue und alte Verbraucher benutzen denselben Körper. Keine heimliche Save-Migration in diesem Schritt.

### ARCH-04 – Körper-ID als Speicherschlüssel

- **Zuordnung:** M1e, vor mehreren Systemen. **Vorher:** ARCH-03. **Bereich:** Kampagnenschema, Save-Adapter und Körper-/Regionsreferenzen.
- [x] `bodies` nach unveränderlicher `body_id` indizieren; Seed bleibt Generatorparameter. Alt-Seed-Schlüssel über versionierte Zuordnung migrieren.
- [x] Regionen, Heimat, Tiere, Besitz, Atlas und Fortschrittsverweise gegen die Zuordnung prüfen; alte IDs niemals aus neuer Listenreihenfolge ableiten.
- [x] Bereits mehrdeutige Altinformationen nicht erraten: Kopie/Quelle schützen und konkreten Konflikt ausgeben.
- **Fertig:** Zwei Systeme mit identischem Weltseed enthalten zwei getrennte Körper; A → B → A und frischer Prozess erhalten getrennte Arten, Vorräte und Entdeckungen. Ein alter Ein-System-Stand behält alle Identitäten.

### ARCH-05 – Spielbare Oberflächenklassen und Abfragen

**Integration 10. September:** Oberflächenklassen, tatsächliche Kollisionsbereitschaft und präzise Zellgeometrie integriert (#54); Größen-/Naht-/Neustartnachweise in WORK_ARCH05_SURFACE_SUPPORT.md.

- **Zuordnung:** M1e/M1h. **Vorher:** vorhandener `surface_context`/radialer Adapter. **Bereich:** `core/campaign/surface_context.gd`, `world/surface`, `world/space`.
- [x] Zulässige Radius-/Terrainauflösung mit maximaler LOD-Tiefe und `ground_ready` abgleichen. Katalogkörper und begehbare Körper unterscheiden.
- [x] Bestehende Abfragen für Ort, Höhe, Wasser, Normale, Tangentialrahmen, Kollision und Ursprung als gemeinsamen Anschluss dokumentieren; fehlende Fähigkeit liefert einen definierten Fehler.
- [x] Unterstützte kleine Testkörper, Terra sowie obere/unzulässige Grenzfälle prüfen; keine neue Welt-Y-Abfrage in Fachsystemen.
- **Fertig:** Jeder als begehbar akzeptierte Körper erreicht die benötigte lokale Bodenkollision; nicht unterstützte Größen werden vor dem Start verständlich zurückgewiesen. Kein stilles Verkleinern des Planeten.

### ARCH-06 – Persistente Orte je Fachmodul

- **Zuordnung:** M1e/M1f/M1g. **Vorher:** ARCH-01, 05; ARCH-03 für Körperzugriff. **Bereich:** Heimat-, Tier-, Dorf-, Arbeits-/Frachtverträge.
- [ ] Körpergebundene Oberflächenadresse für jedes dauerhafte Individuum, Heimziel, Bauwerk, Arbeitsplatz und Frachtziel definieren; `Vector3` bleibt lokales Laufzeitabbild.
- [ ] Alte planare und neue radiale Formate ausdrücklich validieren/migrieren. Versionsänderungen je Modul koordinieren, bestehende Schutzsperren zunächst erhalten.
- [ ] Abbruch/Ankunft, Lage/Ausrichtung und Ursprungskorrektur über Adapter führen; fachliche IDs/Bindungen von der Szene lösen.
- **Fertig:** Datenverträge überstehen Flächenkante, Ursprungskorrektur und Neustart; eine ortsfremde oder unbekannte Adresse wird abgelehnt. Spielbarkeit wird erst in ARCH-08 bis 11 abgenommen.

### ARCH-07 – Speicherteilnahme modularisieren

**Fachlieferung 10. September:** Statische Registrierung für sieben Snapshot-Teilnehmer und 14 körpergebundene Speicherbausteine umgesetzt. [Vertrag, Prüfbasis und Integrationsgrenzen](WORK_ARCH07_SAVE_PARTICIPANTS.md). Eigener Branch auf `bb2f83b`; noch nicht in `main` integriert. ARCH-06 beim gemeinsamen Save-Service anschließend sequenziell abgleichen.

- **Zuordnung:** M0/M1e. **Vorher:** ARCH-01; mit ARCH-04/06 sequenziell integrieren. **Bereich:** SaveService, vorhandene Validatoren/Migratoren.
- [x] Vorhandene Module in einer statischen, expliziten Liste mit Schema-, Validierungs-, Migrations- und Snapshot-Anschluss erfassen; keine beliebig geladenen Plugins.
- [x] Vorhandene Validierungszweige schrittweise hinter diese Anschlüsse verschieben. Slotverwaltung, Writer und gemeinsamer Transaktionsabschluss bleiben zentral.
- [x] Neue Top-Level-Felder brauchen einen Import-/Exportanschluss. Unbekannte Pflichtversionen blockieren weiterhin Backup-Rückfall und Schreiben.
- **Fertig:** Heimat, D2, Dorf, Atlas und Fortschritt werden unverändert gespeichert; fehlende Registrierung fällt bei der Prüfung auf. Alte Save-, Zukunftsversion- und Schreibfehlertests bleiben erfolgreich.

## Vollständige Spielschleife auf Kugeln

### ARCH-08 – Gemeinsame Kreatureninteraktionen radial ausführen

- **Zuordnung:** M1f. **Vorher:** ARCH-05/06. **Bereich:** bestehender Spieler, Scanner, Bedürfnisse, Nahrung und Verhaltensanschlüsse.
- [ ] Spieler-/Kamerabewegung des Kugelstarts mit den bestehenden Aktionen verbinden: Ansehen/Scannen, Sammeln/Essen/Trinken, Sozialkontakt und vorhandene Körperfähigkeiten.
- [ ] Reichweite, Sicht und „oben“ über den Oberflächenadapter prüfen. Gemeinsame Entdeckung, Punkte, Audioereignisse und Pause nutzen.
- **Fertig:** Neue gestaltete Spezies durchläuft die echte Kreaturenkette auf der Kugel; Scannen belohnt genau einmal. Flächenkante, Ursprung, Pause und frischer Prozess erhalten Bedürfnisse und Fortschritt.

### ARCH-09 – Pflichtarten, Wildtiere und Heimat anbinden

- **Zuordnung:** M1f/D1. **Vorher:** ARCH-06/08. **Bereich:** D1-Katalog, Wildtier-Host, Heimgruppe; keine zweite Zähmung.
- [ ] Vorhandene D1.2-Vorkommen und gespeicherte Art-/Objektidentitäten in den Kampagnenhost übernehmen; dieselben Bedürfnis-/Verhaltensbausteine nutzen.
- [ ] Eigene Gefährten, Heimatort, Folgen/Warten/Heimkehr radial ausführen. Befreunden bleibt von D2-Besitz getrennt.
- [ ] Fehlende Ortsadapter gezielt schließen; nur die dafür nachgewiesenen Validierungssperren entfernen.
- **Fertig:** Bekannte Arten, veränderte Wildtiere und dieselben Gefährten erscheinen nach Neustart korrekt; lange Besuchsfolgen werden zusätzlich in ARCH-14 abgenommen.

### ARCH-10 – Radiale Dorfbewegung und Fundamente

- **Zuordnung:** M1g. **Vorher:** ARCH-05/06. **Bereich:** Dorfkamera, Auswahl, Navigation, Arbeitsorte, Hütten/Zelte.
- [ ] Bestehendes lokales Navigationsraster in einen begrenzten Tangentialrahmen verlegen; Welt-Y-Rays/Höhentests ersetzen.
- [ ] Wege-/Fundamentprüfung in zeitlich begrenzte Aufgaben aufteilen; mit blockiertem Ziel stoppen und verständlich zurückmelden.
- [ ] Hütten, Arbeitsplätze und Bewohner an denselben Körper binden; zunächst sechs Bewohner und vorhandenen lokalen Umfang behalten.
- **Fertig:** Dorfablauf auf mindestens zwei Kugelflächen sowie nahe einer Flächenkante funktioniert; Ursprungskorrektur verschiebt weder Häuser noch Ziele. Ein blockierter Materialweg liefert keine unsichtbare Ware.

### ARCH-11 – Aufstieg, Zähmung und Milch radial verbinden

- **Zuordnung:** M1g/D2/D3. **Vorher:** ARCH-09/10. **Bereich:** Phasenübergabe und vorhandene D2-/D3-Verbraucher; gemeinsame Save-Änderung beim Integrationsbesitzer.
- [ ] Bestätigten 0 → 1-Wechsel mit denselben Gefährten und derselben Spezies auf der Kugel ausführen.
- [ ] Echten Betreuer, Tierannäherung, D2-Besitz/Befehle, Haltungsplatz und D3-Pflege/Produktion auf die radialen Wege anschließen.
- [ ] Vorhandene gemeinsame Futter-/Wasser-/Milchbestände und physische Anlieferung erhalten; Phase-1-Fauna berücksichtigt weiter die vereinbarten Angriffsregeln.
- **Fertig:** Aufstieg → zähmen → halten → versorgen → Milch erzeugen → tragen → einlagern besteht mit Neustart während der Fracht, blockiertem Weg und Schreibfehler ohne Verlust/Doppelung.

### ARCH-12 – Entwickelte Altstände kopieren

- **Zuordnung:** Rest M1e. **Vorher:** ARCH-04/06/07 und lieferfähige Verbraucher aus 09/11; nicht als zweiter Migrationsdienst implementieren.
- [ ] Vorhandenes Manifest um persistente Regionen, Artkataloge, Heimat, Bewohner, Tierbesitz, Dörfer, Nachbarn, Arbeitsplätze und laufende Ladungen erweitern.
- [ ] Tatsächliche Zielkapazität, Wasser, Fundamente und erreichbare Verbindungen prüfen; Quell-/Zielzuordnung samt nicht übertragbaren Fällen anzeigen.
- [ ] Jeden unterstützten Fall einzeln freigeben. Große/mehrdeutige Altdaten erhalten Original, Archiv und konkreten Fehlerbericht.
- **Fertig:** Ein wirklich gespielter Altstand mit Heimat/Dorf/Tierhaltung wird als neue Kopie im frischen Prozess spielbar; Inventar, Identitäten und Einmaligkeitsbelege stimmen mit dem Manifest überein. Wiederholung verdoppelt nichts.

## Dauerhafte Welt und begrenzte Laufzeit

### ARCH-13 – Regionsspeicherung mit gemeinsamem Commit

**Integration 10. September:** Population-, Atlas- und Ortsarchive mit vollständiger Referenzprüfung und frischen Prozessen integriert (#62/#71/#74). Kleines globales Manifest, Aufbewahrung/Bereinigung, Labordateien und Backup-Menü bleiben offen.

- **Zuordnung:** M1h. **Vorher:** ARCH-02/04/06/07. **Bereich:** vorhandene Persistenz, neue begrenzte Regionsablage; Muster aus `galaxy_journal.gd` prüfen.
- [ ] Stabile Regionsschlüssel nach Körper-ID und versionierter Cube-Sphere-Zelle festlegen; Regionen speichern Änderungen/Identitäten, unveränderte Landschaft bleibt prozedural.
- [ ] Erst Speicherinterface und Rückschreiben vor Eviction umsetzen. Atomaren Kampagnenabschluss über versioniertes Manifest und unveränderliche Generationen von Segmenten erhalten.
- [ ] Neue Segmente zuerst vollständig schreiben/validieren, erst dann Manifest atomar veröffentlichen. Cross-Region-Fracht/Besitz muss derselben Commit-Generation angehören. Bereinigung berücksichtigt alle erhaltenen Manifeste inklusive Backup, Slothistorie, Slotkopien und Migrationsrückweg; nur nirgends mehr referenzierte Segmente löschen.
- [ ] Bisherige monolithische Saves verlustfrei lesen/migrieren. Slotkopie, Historienwiederherstellung und Umzugsarchiv müssen ihre referenzierten Segmente vollständig erhalten.
- [ ] Cache-Obergrenzen und Dirty-Zustände messen; fehlgeschlagenes Rückschreiben darf keinen autoritativen Zustand verwerfen. Menü/Slotübersicht lädt nur nötige Metadaten.
- **Fertig:** Abbruch zwischen Segmenten/Manifest führt zum letzten vollständigen Zustand; keine halbe Lieferung. Änderungsregion → mehr als 96 weitere Regionen → Rückkehr/Neustart erhält Population und Ressourcen bei begrenztem RAM.

### ARCH-14 – Langzeitregister auslagern

**Fachlieferung 10. September (eigener Branch, noch nicht integriert):** [Kampagnen-Tierregister](WORK_ARCH14_POPULATION_REGISTERS.md) mit 384 dauerhaft veränderten Tieren/Nahrungsquellen und einem weiteren Tier. Aktive Bedürfnisreferenzen und Ortsänderungen bleiben nach Checkpoint/Eviction erhalten; Altformat, Schreibfehler und frischer Prozess geprüft. Das separate Planetlabor mit 256 `animal_records` sowie große Entdeckungsbücher bleiben offen.

**Integration 10. September:** Kartenkacheln und bekannte Orte über RegionStore mit begrenztem Cache/Paging integriert (#59/#65); übrige Langzeitregister und die >256-Tier-Abnahme bleiben offen.

- **Ortsregister-Teilpaket geliefert am 10. September 2026:** `feature/arch-14-place-register`, [PR #65](https://github.com/MajorDragonfly/voxelverse/pull/65), aufbauend auf PR #59. 3.105 Orte einschließlich Änderungen/Neustart geprüft; 96 offene Orte und 64 Einträge je UI-Seite. Schema 1/2 wird verlustfrei übernommen. [Vertrag und Integrationshinweise](WORK_ARCH14_PLACE_REGISTER.md), insbesondere zusätzlicher ARCH-13-Archivadapter für Schema 3 vor gemeinsamer Freigabe. Weitere Register bleiben offen.
- **Atlas-Teilpaket geliefert am 10. September 2026:** `feature/arch-14-atlas-paging`, Basis `ea900f2`, [PR #59](https://github.com/MajorDragonfly/voxelverse/pull/59). Kartenwissen wächst über 8.192 Kacheln hinaus; höchstens 96 offene Kacheln plus begrenzter RegionStore-Cache. Vollständige Schema-1-Übernahme, unveränderliche alte Wurzeln und echte Neustart-/Fehlerprüfungen. [Vertrag, Registerinventar und Übergabe](WORK_ARCH14_ATLAS_PAGING.md). Gesamtpaket und übrige Register bleiben offen.
- **Zuordnung:** M1h/M1f, Karten/D1. **Vorher:** ARCH-13, für Tierlaufzeit ARCH-09. **Bereich:** Ecosystem, Begegnungen, Nahrung, Atlas.
- [ ] Die 256 `animal_records` von der Zahl aktiver Tiere trennen und regionsweise auslagern. Geänderte, gezähmte und anderweitig referenzierte Individuen behalten Identität.
- [ ] Karten-/Orts-, Foraging- und Begegnungsgrenzen inventarisieren: Spielregel mit sichtbarer Grenze oder technischer Cache mit Paging. Kein stilles Verwerfen von Wissen oder Belohnungssperren.
- [ ] Unveränderte prozedurale Objekte dürfen deterministisch rekonstruiert werden; Tod, Entnahme und Besitz bleiben als Deltas erhalten.
- **Fertig:** Mehr als 256 unterschiedliche Wildtieridentitäten können nacheinander besucht werden; neue Tiere erscheinen weiter. Frühe geänderte Tiere und Kartenkenntnisse bleiben nach Cachewechsel/Neustart korrekt; Nahobjektzahl bleibt begrenzt.

### ARCH-15 – Dorfregeln aus dem Szenencontroller lösen

**Integration 10. September:** Gezielte Vorher-Zustände je angekommenem Bewohner integriert (#68/#73); ein gemeinsamer Dictionary-Anschluss und beide Vergleichssuiten. Echte Save-/Rollback-Snapshots bleiben vollständig.

- **Zuordnung:** M1g/M1h/M6. **Vorher:** ARCH-01/06; Integration mit ARCH-11 koordinieren. **Bereich:** `tribe_controller.gd`, vorhandene Wirtschafts-/Auftragsdaten.
- [x] Zuerst einen bestehenden Auftrag als Datenablauf abgrenzen: Befehl → Reservierung → bestätigte Ankunft → Arbeit → Ladung → bestätigte Lieferung → Beleg.
- [x] Controller behält Darstellung, Eingabe und Navigation; Zustandsregeln können ohne geladene Figuren ausgewertet werden. Nahe Arbeit startet weiterhin erst nach tatsächlicher Ankunft.
- [x] Gesamtdorfkopien pro Bewohner/Tick durch gezielte Transaktionen ersetzen, ohne gemeinsamen Save-/Rollback-Schutz zu verlieren.
- **Fertig:** Derselbe Auftrag behält seine Mengenbilanz und Unterbrechbarkeit. Pause sowie 1-/2-/4-fache Simulationsgeschwindigkeit funktionieren; wiederholte Ankunft/Bestätigung verbucht keine zusätzliche Ware.

### ARCH-16 – Nah-/Fernsimulation mit eindeutiger Übergabe

- **Zuordnung:** M1h; Nutzerentscheidung in dieser Prüfung. **Vorher:** ARCH-13/14/15, vorhandene radiale Produktionskette ARCH-11.
- [x] Pro Region/Auftrag genau einen Besitzer und gespeicherten Zeitcursor führen. Gemeinsame Kampagnenzeit von Wandzeit/Physikzeit trennen.
- [x] Bei Übergabe Nah → Fern bisherigen Besitzer am Tickende anhalten; Zustand, Ladung, Reservierungen, begonnenen Zyklus und Zeitcursor gemeinsam sichern; danach den neuen Besitzer aktivieren. Bei Schreibfehler bisherigen Besitzer mit unverändertem Zustand fortsetzen. Auch bei asynchronem Schreiben darf die Momentaufnahme nicht überholt werden.
- [x] Ferne eigene Orte in begrenzten Zeitschritten vereinfacht versorgen/produzieren. Fehlende Nahrung, Kapazität, Transportzeit und bekannte Wegsperren gelten weiter; keine fiktiven Sofortlieferungen.
- [x] Fern → Nah rekonstruiert denselben Zustand ohne erneutes Durchlaufen bereits verbuchter Zyklen. Unbesuchte Galaxienkörper erhalten keine vollständige Einzelsimulation.
- **Fertig:** Milch-/Materialfracht während Nah → Fern → Nah, Pause und Neustart existiert genau einmal. Die vorhandene eigene Siedlung arbeitet entfernt weiter; eine zweite isolierte Daten-Prüfinstanz belegt unabhängige Besitzer/Zeitcursor ohne zweites spielbares Dorf vorwegzunehmen. Zwei spielbare eigene Siedlungen folgen in ARCH-26. Geschlossene App und Menüs produzieren nichts; das Tickbudget begrenzt Nachholarbeit.

### ARCH-17 – Streamingaufträge, Gewässer und Audio begrenzen

**Integration 10. September:** Portionierter Pflanzenaufbau, begrenzte Tierplatzierung und radiales Wasser-/Unterwasseraudio integriert (#56); kalte Einzeluploads, Vorausschau und Ziel-PC-Messung bleiben offen.

**Teilpaket 10. September 2026:** Pflanzenpublikation, Jobgültigkeit und begrenzte Tierplatzierungsversuche auf `agent/arch-17-fauna-budget`; Umfang, Messwerte und Nachweise in [WORK_ARCH17_POPULATION_BUDGET.md](WORK_ARCH17_POPULATION_BUDGET.md). Der anschließende [Wasser-/Audioteil](WORK_ARCH17_WATER_AUDIO.md) liefert begrenzte Uferabfragen und gemeinsame Unterwassergrenzen. Terrainvorausschau und Ziel-PC-Abnahme bleiben offen.

- **Zuordnung:** M1h. **Vorher:** ARCH-02/05; Integration mit M1f/g. **Bereich:** Terrain-/Populationjobs, Wasser, Audio.
- [ ] Gemessene teure Einzelpublikationen aufteilen; Queues, laufende Jobs, Meshes und Pflanzen-/Tieraufbau getrennt begrenzen. Ein weiches 4-ms-Limit ist keine Garantie für einen einzelnen Upload.
- [ ] Jobs mit Körper-/Regions-/Laufzeitgeneration versehen; veraltete Ergebnisse nach Richtungs-/Körperwechsel verwerfen, ohne fremden Zustand zu verändern.
- [x] Wasser/Unterwasser und räumliches Audio an dieselbe Oberflächenquelle/Normale anschließen; keine aktive planare Umgebungsabtastung für den Kugelspieler. Quellenwechsel, Pause, Ursprung und Abfragegrenzen durch den Wasser-/Audio-Fachtest nachgewiesen; Ziel-PC-Hör-/Sichtprüfung bleibt separat.
- [ ] Vorausschau an zugelassene Bewegungsgeschwindigkeit binden. Bei fehlender Kollision sicher warten; Fahrzeug-/Fluggeschwindigkeit erst nach eigener Messroute erhöhen.
- **Fertig:** Lange Reise, Richtungswechsel, Pause und Verlassen während laufender Jobs halten die Budgets ein; keine fremden Sounds, veralteten Meshes oder verbleibenden Worker. Ziel-PC-Messung bleibt eigener Nachweis.

### ARCH-18 – Körperwechsel als Kampagnenübergabe

**Integration 10. September:** Reale Tierhaltung samt begonnenem Milchzyklus und geladener Fracht für A–B–A/Neustart ergänzt (#69); Kollision bis zum abgeschlossenen Quellsave erhalten.

- **Zuordnung:** M1h, Vorbereitung M9. **Vorher:** ARCH-04/13/16/17. **Bereich:** SessionFlow, Oberflächenhost und vorhandener Save-Abschluss.
- [x] Abreise vorbereiten → Nahzustand/Fracht sichern → alten Host abmelden → Zielkontext aufbauen → erst bei Kollision/Hostbereitschaft Steuerung übergeben.
- [x] Bei Lade-/Schreibfehlern im alten gültigen Zustand bleiben; Listener, Audio, Kamera, Player und Jobs besitzen klaren Lebenszyklus.
- [x] Kurzen Lade-/Flugübergang zulassen. Noch keinen Schiffsflug vorziehen; vorhandenen Körperwechsel als Prüfeinstieg verwenden.
- **Fertig:** A → B → A mit Heimat, Tier und laufendem Auftrag sowie Neustart erhält Identitäten und Bilanz; zu keinem Zeitpunkt simulieren zwei Hosts dasselbe Individuum.

### ARCH-19 – M1i als zusammenhängende Abnahme

- **Zuordnung:** M1i/M10. **Vorher:** 08–14 und 16–18 geliefert; 15 ist Voraussetzung von 16. **Bereich:** Integration, Frontend und Export.
- [ ] Vollständige Kette aus dem Migrationsauftrag mit neuer Kugelkampagne und entwickeltem Altstand am gleichen Commit durchführen.
- [ ] Echte Szenen, frischen Prozess, Pause/Schreibfehler, Flächenkante/Ursprung und Reise/Rückkehr prüfen; Linux-/Windows-Paket außerhalb des Projekts starten.
- [ ] Ziel-PC-Spieltest, Sichtbarkeit/Bedienung und Leistungsbericht separat dokumentieren. Der reguläre Neue-Spiel-Start wurde auf Lars’ ausdrückliche Entscheidung vom 10. September vorgezogen; kein Rückfall auf Flachwelt bei offenen Befunden.
- **Fertig:** Ein gemeinsamer spielbarer Kugelstand ist nachgewiesen. Alte Flachweltdaten bleiben für Kopiermigration und Originalarchive lesbar; sie sind kein regulärer Spielweg. Historische Regressionen dürfen ihre ausdrücklich planaren Prüfszenen weiter verwenden; gemeinsam genutzte Generator-/Assetdienste nicht blind löschen.

## Funktionsausbau auf gemeinsamen Bausteinen

### ARCH-20 – Ressourcen und Produktion vereinheitlichen

**Integration 10. September:** Ressourcen-/Rezeptkatalog und Ressourcenbatch 2 mit Alt-Milchadapter integriert (#52). Noch keine Eierproduktion.

- **Zuordnung:** D3/M6, Voraussetzung D3-EIER. **Vorher:** ARCH-01/15; Ortsanschluss mit 11 koordinieren. **Bereich:** `village_economy`, `village_husbandry`, bestehender D2-Leseanschluss.
- [x] Kleine feste Kataloge für `resource_id`, `recipe_id`, Einheit, Nährwert, Anzeige-/Icon-Schlüssel und Produktionsbedingungen anlegen; zunächst bestehende Werte übernehmen.
- [x] Bestehende Milchbuchung als allgemeinen Ressourcenbatch mit Quelle, Menge, Revision und Einmaligkeitsbeleg ausführen. Milch-Altadapter und Migration erhalten.
- [x] Resource-basierte Ausgabe/Tragen/Annahme/Verbrauch statt zusätzlicher Milch-/Eier-Sonderzweige nutzen; keine neue Tierbesitzlogik.
- **Lieferung auf Fachbranch (10. September):** [WORK_RESOURCE_PRODUCTION.md](WORK_RESOURCE_PRODUCTION.md). Ressourcen-/Rezeptkatalog, Ressourcenbatch 2, reiner Milch-Altadapter, gemeinsamer Abhol-/Verbrauchsweg und Schutz unbekannter Revisionen. Hauptzweig-Integration erfolgt über den zugehörigen PR.
- **Fertig:** Alte Milchstände behalten Bruchteile, begonnene Zyklen, Vorräte und Lieferbelege; Abbruch/Neustart erzeugt keine Doppelware. Noch keine Eier allein durch diesen Umbau erzeugen.

### ARCH-21 – D1-EIER und rollenspezifische Körperfähigkeiten

**Integration 10. September:** Vierte Nutztierspezies mit Eierrolle, rollenspezifischen Körperfähigkeiten und additiver Kampagnenmigration integriert (#63). Fußanbieter aus ARCH-24 und Spawnbudget aus ARCH-17 gemeinsam erhalten.

- **Zuordnung:** bestehender Fachauftrag D1-EIER; kein zweiter Artenkatalog. **Vorher:** ARCH-01/06, vorhandenes D1; Produktionseinheiten mit ARCH-20 abstimmen.
- [x] Pflichtrollenpolitik versionieren: drei bestehende Arten erhalten, vierte eigenständige Eierart additiv ergänzen. Alte Art-/Individuen-/Entdeckungs-IDs nicht neu erzeugen.
- [x] Fähigkeit pro Rolle prüfen: Eierlieferant darf z. B. zweibeinig sein; Reit-/Zugsicherheit bleibt über tatsächlich geeignete Kontakte, Stand und Körperanschlüsse abgesichert.
- [x] Neue Art deterministisch in erreichbarem radialem Habitat mit Wasser/Nahrung ansiedeln; Katalogeintrag ohne Vorkommen zählt nicht.
- **Fertig:** Neue und migrierte belebte Körper besitzen die vier geeigneten Arten; alte drei bleiben identisch. Mehrfachmigration, Seed-/Besuchsreihenfolge, Wiederbesuch und Neustart bestehen.

### ARCH-22 – D3-EIER als zweite Produktionskette

**Fachbranch geliefert, 10. September:** Legestellen, Pflege, Eierbatches, echte Transporte und Mahlzeiten auf den bestehenden Verträgen. Alt-Milchdaten bleiben erhalten; Integration und Prüfgrenzen siehe [ARCH-22-Übergabe](WORK_ARCH22_EGG_PRODUCTION.md).

- **Zuordnung:** bestehender Fachauftrag D3-EIER. **Vorher:** ARCH-11/20/21; Fernübergabe zusätzlich mit ARCH-16 abnehmen.
- [x] Eigenes geeignetes Tier, Versorgung und Legestelle an bestehende Haltung anschließen; Eier über den gemeinsamen Produktions-/Ressourcenvertrag erzeugen.
- [x] Sammeln, tatsächliches Tragen, Einlagern und Essen über dieselben Aufträge wie andere Ressourcen ausführen.
- [x] Essbare Eier bleiben von Nachwuchs/Bebrütung getrennt; Belohnungen verwenden bestehende begrenzte Erfolgsregeln.
- **Fertig:** Jedes Ei liegt genau einmal an Legestelle, in Fracht oder im Lager; Pause, Unterbrechung, Tierverlust und Neustart erhalten Mengen. Eier benötigen nicht den Abschluss aller neuen Körpermodelle.

### ARCH-23 – Bauplanversionen vor neuen Editoren absichern

**Integration 10. September:** Versions-/Originalschutz für bestehende Kreaturen-/Gebäudeverbraucher integriert (#50). Portabler Kreaturenvertrag und lokale Vorlagenbibliothek ebenfalls integriert (#61/#75).

- **Zuordnung:** M2B/M3/BP-COMMUNITY.1, Vorbereitung M7/M9. **Vorher:** ARCH-01. **Bereich:** `assembly/core`, DesignStore und bestehende Adapter.
- [x] Validierung/Migration von Normalisierung trennen; unbekannte zukünftige Bauplanschemata nicht auf Schema 1 umschreiben.
- [x] Parts-Erweiterungen, Entwurfsrevisionen, maximale Komplexität und Originalerhalt definieren. Bauplan-ID und konkrete Gebäude-/Fahrzeug-/Schiffinstanz bleiben getrennt.
- [x] Den geplanten portablen Bauplanvertrag für BP-COMMUNITY.1 berücksichtigen: deklarative Daten/Vorschau, begrenzte Größe/Teilezahl, lokale Prüfung der Fähigkeiten/Kosten, keine Skripte oder Kampagnen-/Besitzdaten. Downloadrevisionen lokal erhalten; ein Online-Update verändert vorhandene Objekte nicht automatisch.
- [x] Vorhandene Kreaturen-/Gebäudeverbraucher behalten; generischer Kreaturenadapter ist noch kein vollständiger Rückimport und braucht einen eigenen nachgewiesenen Anschluss.
- **Fertig:** Bestehende Entwürfe laden identisch; unbekannte neuere Daten bleiben unverändert geschützt; Revision, Undo/Redo, Vorschau und gespeicherte Instanz bleiben nachvollziehbar. Formatanschluss für BP-COMMUNITY ist beschrieben; Online-Dienst/Galerie gehören zu dessen eigenen fünf Fachaufträgen, nicht in diesen Umbau.

**Fachlieferung 10. September:** umgesetzt und lokal geprüft auf `agent/arch23-blueprint-contract-2026-09-10`; Integration nach main separat. [Vertrag](BLUEPRINT_CONTRACT.md) und [Übergabe/Nachweise](WORK_ARCH23_BLUEPRINTS.md). Onlineaustausch und ein vollständiger Kreaturen-Rückimport bleiben BP-COMMUNITY.

### ARCH-24 – M3-TEILE über Katalog und Geometrieanbieter

**Integration 10. September:** Altteilinventar, Fuß-/Handanbieter, Katzenpfoten, Bärentatzen, Pferdehufe und Krebsscheren integriert (#55/#66/#70). Rüssel, weitere Schnauzen, Oktopusmund, gespeicherte Teilrevisionen und aktive Greiferöffnung bleiben eigene Arbeit.

**Weiteres Fachpaket 10. September:** [Hundeschnauze, Krokodilschnauze und Oktopusmund](WORK_ARCH24_MOUTH_MODELS.md) über gemeinsame Geometrie, Editor und Buch. Die Modelle teilen Werte/Freischaltung der bestehenden Raubkiefer; 24 alte Geometriefälle und 30 Altarten bleiben exakt erhalten. Lieferung auf eigenem Branch, Integration separat. Rüssel, weitere Modelle und bewegliche Kiefer bleiben offen.

- **Zuordnung:** bestehende M3-TEILE.1–.5. **Vorher:** ARCH-23 für Schemaänderungen; Bestandsinventar darf sofort beginnen.
- [ ] Alle alten Teil-IDs erfassen und je Teil Revision/Erhalt/kompatiblen Ersatz bestimmen. Katalogdaten von Geometrie, Kontaktpunkten und unterstützten Aktionen trennen.
- [ ] Eine Referenzfamilie durch den vorhandenen Renderer/Editor/Buchanschluss führen; danach Rüssel, Schnauze, Oktopusmund, Pfoten/Tatzen, Krallen, Scheren und Tierfüße in kleinen Modellpaketen liefern.
- [ ] Gemeinsame Vorschau/Silhouette, Drehung, Symmetrie, mehrere Beinpaare und radialen Bodenkontakt abnehmen. D1 liest Fähigkeiten statt fester Fuß-IDs.
- **Fertig:** Neue Formen sind sichtbar unterscheidbar und in alten/neuen Entwürfen stabil. Darstellung von Flügel/Flosse/Kletterfuß allein gibt keine unimplementierte Bewegung frei. Detailumfang bleibt in M3-TEILE geführt.

### ARCH-25 – Fachresultate und Darstellung trennen

**Integration 10. September:** Nachbarstämme, Weltkarte, Heimat/Gruppe und eigene Tiere DE/EN integriert (#51/#60/#64/#72); zusätzliche Bibliotheksoberfläche ebenfalls DE/EN. Restliches HUD/Buch, Dorf und Editor bleiben teilweise offen.

- **Zuordnung:** UI/L1/M10. **Vorher:** vorhandene Designvorgabe; ARCH-01. **Bereich:** LocaleManager, gemeinsame UI und Fachresultate.
- [ ] Neue Fachbefehle liefern stabile Ergebniskennung und Parameter; lokalisierter Text und einheitliche Stat-/Ressourcensymbole entstehen in der Darstellung.
- [ ] Vorhandene deutsche Fachstrings schrittweise umstellen; DE/EN-Pakete getrennt für HUD/Buch, Dorf und Editor abarbeiten. Keine zweite Buch-/Pauseinstanz.
- [ ] Auswahl, Scrollposition, Editorentwurf und benannte Objekte beim Sprachwechsel erhalten; neue Referenzen aus realen Fachkatalogen lesen.
- **Fertig:** Beide Sprachen decken den jeweiligen abgegrenzten Bildschirm vollständig ab; lange Texte/Skalierung bei 1280×720 und 800×600 sowie Normalauflösung sichtbar geprüft. „221 Vorlagen“ bedeutet weiterhin nicht Vollübersetzung.

## Mehr Siedlungen, Epochen und Raumfahrt

### ARCH-26 – Siedlungen und Arbeitsplätze als Instanzen

- **Zuordnung:** M6 → M7. **Vorher:** ARCH-04/06/13/15/16/20. **Bereich:** Dorfzustand, Arbeitsplätze und Auftragsregister.
- [ ] Bestehendes `body.tribe` verlustfrei als erste Siedlung mit stabiler `settlement_id` migrieren. Fraktion, Spezies, Ort und aktuell ausgewählter Ort getrennt halten.
- [ ] Zwei eigene Siedlungen mit getrennten Vorräten/Aufträgen als erste Größenstufe liefern; Nachbarfraktionen bleiben eigenständige Gesellschaften derselben Spezies.
- [ ] Zwei gleichartige Arbeitsplätze bzw. zwei Baustellen mit eigenen IDs, Wegen, Reservierungen und Arbeitsfortschritten unterstützen. Bewohner-/Baugrenzen erst nach ARCH-02 erhöhen.
- **Fertig:** Zwei Orte arbeiten unabhängig nah/fern weiter; Speichern während gleichzeitig laufender Arbeiten bewahrt jede Ladung und Reservierung genau einmal.

### ARCH-27 – Regionale Wege und Transport

- **Zuordnung:** M6/M7/M8; D4 nutzt zuvor die lokalen radialen Wege aus ARCH-10. **Vorher:** ARCH-10/16/26.
- [ ] Lokale Navigationsnetze durch gespeicherte regionale Verbindungen/Übergänge verbinden; kein planetengroßes 0,5-m-Raster.
- [ ] Route, Verkehrsmittel, Lade-/Empfangsort, Reisezeit, Kapazität und Blockaden als Transportauftrag speichern. Sichtbare Träger bleiben physisch, entfernte Transporte zeitlich vereinfacht.
- [ ] Verlust/Abbruch, Rückgabe von Reservierung und sichere Wiederaufnahme definieren; fremde Fraktionslager nur nach erlaubter Interaktion verändern.
- **Fertig:** Ware von Siedlung A nach B wird erst bei tatsächlicher/zeitlich simulierter Ankunft gutgeschrieben; Wegsperre, Regionseviction und Neustart liefern weder Sofortware noch Duplikate.

### ARCH-28 – Epochenübergaben abgrenzen

**Integration 10. September:** Expliziter bestätigter 0→1-Adapter mit atomarem Save und Rollback integriert (#57). Weitere unspielbare Epochen bleiben gesperrt.

- **Zuordnung:** M5 → M7 → M8 → M9. **Vorher:** ARCH-01/07; ersten 0 → 1-Ablauf aus ARCH-11 verwenden.
- [x] Bestehenden bestätigten Phasenwechsel hinter einem kleinen Übergabeanschluss für Voraussetzungen, Folgen, Commit und Kamera-/Steuerungswechsel kapseln.
- [x] Erst den bestehenden 0 → 1-Wechsel unverändert beweisen. Neue Zieladapter werden erst nach ihrer vollständigen spielbaren Phase registriert/freigegeben.
- [ ] Spezies, Bewohner, Tiere, Entwürfe, Fraktionen, Bestände und Einmaligkeitsbelege erhalten; gespeicherte Phasen-IDs nicht umnummerieren.
- **Fertig:** Doppelklick, Schreibfehler und Neustart führen zu genau einem Übergang oder vollständigem Rollback. Mittelalter/Neuzeit/Weltraum bleiben ohne eigene Spielschleife gesperrt.

### ARCH-29 – Verträge und relevante Prüfungen integrieren

**Integration 10. September:** Vertrags-/Sprachgate integriert (#53) und auf alle 151 Godot-Tests in 17 Verträgen erweitert. >256 Tiere, native Pakete und Ziel-PC bleiben eigenständige Nachweise.

- **Zuordnung:** M0/M10, kontinuierlich. **Vorher:** keiner. **Bereich:** vorhandene Tests, `tools`, CI.
- [x] Vorhandene Tests den Fachverträgen und gemeinsamen Spielketten zuordnen; Quellenprüfung, echte Runtime, Paket und Ziel-PC-Nachweis getrennt halten.
- [x] Bestehendes `tools/localization/catalog.py --check` in die integrierte Prüfung aufnehmen; generierte Übersetzungen müssen zur Quelle passen.
- [ ] Relevante Fälle für gleiche Seeds in verschiedenen Systemen, >96 Regionen, >256 Tieridentitäten, zukünftige Bauplanschemata und Nah-/Fernfracht mit ihren Implementierungen ergänzen.
- [ ] Erweiterungen brauchen Neu-/Altstand und die betroffenen Unterbrechungsfälle; keine rein spiegelnden Tests und keine redundante Vollprüfung für Textänderungen.
- **Fertig:** Neuer Modulanschluss wird in der gemeinsamen CI geprüft; Fachnachweise nennen exakten Commit, Route, Ergebnisse und verbleibende Grenzen. Grüne Einzeltests gelten nicht als fertige Gesamtphase.

### ARCH-30 – Reise-/Schiffsvertrag vor M9.1–M9.6

**Integration 10. September:** Schiffs-/Reise-Datenentwurf mit Referenzprüfung integriert (#67). Große gespeicherte Double-Koordinaten, Flug, Laufzeit-/Save-Anschluss und M9-Spielabnahme bleiben offen.

- **Zuordnung:** bestehendes M9-EXPEDITION. **Vorher:** Datenentwurf nach ARCH-04/06/23; Implementierung erst nach M8 und ARCH-16/18/27/28.
- [ ] Bauplan und individuelles Schiff unterscheiden; Platzformen Oberfläche, Systemraum und Dock/Hangar mit Host-ID definieren. Ein Beiboot besitzt genau einen Aufenthaltsort.
- [ ] Große ausrüstbare Expeditionsbasis plus eigenes direkt steuerbares Landungsschiff als erste Schleife vorsehen; eigene Gestaltung oder passende mitgelieferte/Community-Vorlage sind zulässige Wege. Editorarbeit ist freiwillig. Brücke/Hangar-Umschaltung genügt zunächst für Innenräume.
- [ ] Kontrolle, Ladung, Proben, Passagiere, Energie und Hangarbelegung atomar übergeben. Kurze Oberfläche-/Orbit-Flugsequenz ist ausdrücklich erlaubt; beide lokalen Flugabschnitte bleiben steuerbar.
- [ ] Bestehende M9.1–M9.6 weiterverwenden: M9.1 Schiffdaten/Editor → M9.2 vollständige erste Expedition mit Rückkehr → M9.3 Proben/Forschung → M9.4 Rumpf-/Kapazitätsausbau; anschließend M9.5 zusätzliche Bordschiffe/Bewaffnung und M9.6 System-/Sektorreise/Kolonien gemäß Fachplan. M9.5 ist kein zwingendes Kampftor für M9.6. Keine neue konkurrierende M9-Nummerierung erstellen.
- **Fertig:** Vertragsprüfung verhindert doppelt angedockte Schiffe/mehrfach vorhandene Fracht. Die spätere M9-Abnahme verlangt wirkliche Landung, Untersuchung, Rückflug und einen wirksamen Ausbau nach Neustart; ein Schiffeditor allein erfüllt sie nicht.

## Übergabeformat für jeden Folgechat

1. **Auftrag:** ARCH-ID plus bestehende Fach-ID; Basiskommit und bereits integrierte Vorarbeiten nennen.
2. **Umfang:** konkret übernommene Dateien/Schnittstellen, Vertragsversionen, Datenbesitzer und Abhängigkeiten angeben. Gemeinsame Schreibbereiche vorher der Integration zuordnen.
3. **Lieferung:** zuerst benötigten Vertrag, dann einen kleinen vollständigen Ablauf implementieren. Vorhandene Spielregeln/IDs erhalten; benachbarte Features nicht beiläufig neu erfinden.
4. **Nachweis:** exakter Commit, betroffene Neu-/Altstände, relevante Fehler-/Neustartfälle und Messwerte. Optik/FPS nur mit tatsächlichem Zielgerätebeleg behaupten.
5. **Status:** geplant → in Arbeit → geliefert → integriert; technische Abnahme und Lars' Spieltest separat. Eine Checkbox nur mit dazugehörigem Ergebnis schließen. Integration übernimmt ausschließlich abgegrenzte fertige Pakete.

Die detaillierten Wünsche für Eier, Tierkörperteile, Expeditionsschiffe und Community-Baupläne wurden zusätzlich in der separaten Planungsquelle [`61ccebb2c6eec5d6f5826867cc91205265dd7667`](https://github.com/MajorDragonfly/voxelverse/tree/61ccebb2c6eec5d6f5826867cc91205265dd7667/docs) gelesen. Dort liegen `FEATURE_BACKLOG.md`, `CREATURE_PARTS_CATALOG_PLAN.md`, `SPACE_EXPEDITION_PLAN.md` und `COMMUNITY_DESIGNS_PLAN.md`. BP-COMMUNITY.1–.5 umfasst portablen Vertrag → lokale Bibliothek/Startvorlagen → Dienst → Galerie/Verwendung → weitere Typen. Erster Typ ist die Kreatur; Selbstgestalten ist freiwillig, heruntergeladene Vorlagen bleiben offline nutzbar. Online-Bauplanaustausch setzt keine Multiplayer-Spielsimulation voraus. Das ursprüngliche Audit übernahm Zielrichtung und Fach-IDs ohne Implementierung. Die Planungsquelle ist mit PR #42 integriert; die lokalen Detaildateien und ihre aktualisierten Lieferstände gelten.
