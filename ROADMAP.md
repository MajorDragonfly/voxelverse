# Voxelverse – gemeinsame Entwicklungsroadmap

Stand: 9. September 2026 · M1e-Kampagnengrundlage nach der zweiten Integrationsrunde. Maßgeblich sind jetzt [Runde 2](docs/INTEGRATION_SPHERICAL_2026-09-09.md) und der [Kugelumzug](docs/SPHERICAL_CAMPAIGN_MIGRATION.md). Die folgende ältere Quellenliste dokumentiert Runde 1. Die konkreten Quellstände stehen in [Integrationsquellen](docs/integration-sources-2026-09-09.json), gemeinsame Prüfungen und Grenzen im [Integrationsbericht](docs/INTEGRATION_2026-09-09.md). Ältere Berichte beschreiben ihre damaligen Einzelstände; diese Roadmap ist die aktuelle Planung. Ein vorhandener Prototyp zählt nicht als abgeschlossene Spielphase.

**Planungsergänzungen vom 9. September 2026:** Eier liefernde Nutztiere, der erweiterte Körperteil-Baukasten, die Weltraumphase mit modularem Expeditionsschiff/Beibooten und eine gemeinsame Community-Designbibliothek sind aufgenommen. Konkrete To-dos und Abnahmen stehen im [Ideen- und Aufgabenbacklog](docs/FEATURE_BACKLOG.md), [Körperteilkatalog](docs/CREATURE_PARTS_CATALOG_PLAN.md), [Expeditionsplan](docs/SPACE_EXPEDITION_PLAN.md) und [Community-Designplan](docs/COMMUNITY_DESIGNS_PLAN.md). Alle Ergänzungen sind **geplant**; die nachfolgend dokumentierten Integrations- und Teststände bleiben davon getrennt.

## Verbindliches Zielbild

**Kreatur → Stammeszeitalter → Antike/Mittelalter → Neuzeit/Weltmacht → Weltraum.** Dieselbe selbst gestaltete Spezies entwickelt sich durch die gesamte Kampagne. Das Spiel orientiert sich funktional an Spore und behält seine feine Voxeloptik.

- **Nur die eigene Spezies steigt zur gesellschaftlichen Entwicklung auf.** Ein Phasenwechsel betrifft die Spielerzivilisation, nicht sämtliche Arten des Planeten. Wildarten werden weder durch Zeitablauf noch durch Zähmung zu Stämmen, Menschenersatz oder Kulturfraktionen. Verschiedene spätere Stämme/Reiche können zur eigenen Spezies gehören; Spezies und Fraktion sind getrennte Identitäten. Automatisch aufsteigende fremde Spezies sind kein Ziel dieser Roadmap.
- **Jeder Epochenwechsel wird ausdrücklich bestätigt.** Für den ersten Wechsel lautet die Aktion „Jetzt ins Stammeszeitalter fortschreiten“. Danach wird die Gruppe gesteuert. Nestgefährten bleiben davor Teil der Kreaturenphase. Öffnen eines Menüs oder Erreichen eines Punktestands darf keinen Wechsel auslösen.
- **Ab dem Stammeszeitalter werden andere Tierarten zähmbar.** Jeder Planet mit einer geeigneten Tierwelt stellt verlässlich Milchtiere, eierlegende Nutztiere, Zug-/Reittiere und hundeartige Begleiter bereit. Die Arten sehen pro Planet unterschiedlich aus und tragen ihre Eignung bereits in den Generatordaten. Lebenslose Körper, Sterne und Gasriesen bekommen keine künstliche Landtierpopulation; die Garantie gilt für belebte Spielplaneten.
- Die eigene Spezies, ihre ID, Entwürfe, Bewohner, Heimat, Besitz, Entdeckungen, gezähmten Tiere und Entscheidungen bleiben über Stamm, Mittelalter und Neuzeit erhalten. Kulturelle/technische Entwicklung ersetzt keinen Genom- oder Mutationssimulator. Umbauten der Kreatur nach dem Aufstieg benötigen später eine ausdrückliche Spielregel.
- Planeten sind kugelförmige Körper in realen Größen ihrer Körperklasse. Terra mit 12.742 km Durchmesser ist die große technische Referenz. Kleine Laborkörper bleiben schnelle Prüffälle. Nahterrain und Orbit verwenden dieselbe Weltquelle.
- Eine darstellbare und bereisbare Galaxie mit reproduzierbaren Sternsystemen, Planeten, Monden sowie Ein-/Doppelsternen bleibt Ziel der Weltraumphase. Katalog und Laborbesuche sind dafür Grundlagen, noch kein Raumflug.
- Kern der Weltraumphase ist ein großes, selbst gestaltetes und ausgerüstetes Expeditionsschiff als mobile Basis. Kleinere eigene Schiffe übernehmen planetaren Anflug, Landung, Ausstieg und Untersuchung. Forschung und wirtschaftlicher Fortschritt ermöglichen größere Rümpfe, mehr Ausrüstung, Waffen, Lagerraum und zusätzliche Bordschiffe; beide Schiffsebenen sind direkt steuerbar und dauerhaft gespeichert. Details: [SPACE_EXPEDITION_PLAN.md](docs/SPACE_EXPEDITION_PLAN.md).
- Der Kreatureneditor erhält einen erweiterbaren Baukasten erkennbarer, einzeln wählbarer Körperteile nach realen Tieren. Alle bestehenden Teile werden auf Überarbeitung oder kompatiblen Ersatz geprüft; Mund-/Kopfformen, Hände/Greifer und Füße bilden die erste Lieferung. Der [Katalogplan](docs/CREATURE_PARTS_CATALOG_PLAN.md) konkretisiert weitere Körper-/Sinnesformen, Flügel, Flossen, Tentakel, Schwänze, Schutzteile und Hautmuster in fünf Unteraufgaben; besondere Bewegung erfordert jeweils ein geprüftes Spielsystem. Unterschiedliche Tierformen bleiben frei kombinierbar, soweit ihre Anschlüsse passen; alte Entwürfe und Freischaltungen bleiben erhalten.
- Kreaturen-, Gebäude-, Fahrzeug- und Schiffeditor teilen ein Bauplanfundament und erhalten jeweils passende Regeln. Verhalten verdient getrennte soziale/aggressive Punkte; Technikforschung und Tierhaltung werden nicht ausschließlich durch Kampf freigeschaltet.
- Selbst gestalten ist freiwillig: Kreaturen, Gebäude, Fahrzeuge und Raumschiffe können aus passenden fertigen Vorlagen oder heruntergeladenen Community-Designs übernommen werden. Community-Mitglieder veröffentlichen ihre Baupläne für andere Voxelverse-Installationen und Spielstände. Ein gemeinsames portables Format, lokale Bibliothek, Vorschau und Typadapter erhalten normale Freischaltungen/Baukosten; verwendbare Startvorlagen ermöglichen den Einstieg ohne Editorarbeit. Siehe [BP-COMMUNITY](docs/COMMUNITY_DESIGNS_PLAN.md).
- Alte Spielstände und Entwürfe bleiben geschützt. Keine ungefragte Neugenerierung alter Landschaften oder Tierarten; Änderungen erhalten Versionen, Migration und Rückfallmöglichkeit.

## Vorrang: vollständiger Umzug auf Kugelwelten

Neue Weltentwicklung verwendet die vorhandene Cube-Sphere-Oberfläche, stabile Körper-/Objektadressen und begrenztes Streaming. Die Ebene bleibt ausschließlich kompatibler Kampagnenbetrieb bis zur geprüften Übergabe. **Die vollständige Kugelkampagne ist noch nicht umgesetzt.** Der gemeinsame Kugelstart, Save 8/Kampagne 2, radiale Spielerorte, gemeinsame Karten und eine geprüfte Kopiermigration für frühe Stände sind jetzt angebunden. Bestehende regionale Änderungen, Heimatgruppen, Pflichtartenkataloge und Siedlungen benötigen noch ihre Zieladapter und werden beim Umzug ausdrücklich gesperrt. Details: [M1e-Vertrag und Grenzen](docs/WORK_M1E_CAMPAIGN.md). Das Planetenlabor wird nicht durch Umbenennen oder einen Menüwechsel zur Kampagne. Der [Migrationsauftrag](docs/SPHERICAL_CAMPAIGN_MIGRATION.md) definiert Reihenfolge, Besitzer und Abschaltkriterien. Für sichtbare Elemente gilt die gemeinsame [Designvorgabe](docs/VOXELVERSE_DESIGN.md).

## Gemeinsamer Ist-Stand

Die folgenden Pakete sind im gemeinsamen Quellstand enthalten. „Enthalten“ ersetzt weder den gemeinsamen Prüfbericht noch Lars’ Spieltest.

| Bereich | Zusammengeführt | Noch offen |
|---|---|---|
| Kugelwelt | M1d-Oberflächenadapter, Erdgröße, belebtes Gelände, radiale Flora-/Faunakollision, überarbeiteter Boden und Wasser, Wiederbesuch | Vollständige Kampagne, Dorf, lokale Flüsse/Seen und räumliches Audio auf Kugeln |
| Arten | D1, D1.1 Körpernachweise/Habitaterholung, D1.2 Pflichtarten auf Kugeln; bestehende IDs erhalten | Größere Suchräume und populationsbasierte Fernsimulation; begrenzte Habitatsuche bleibt begrenzt |
| Tierhaltung | D2 mit echten Betreuern und gemeinsamem Save; D3 Tierplätze/Pflege/Milchtransport; lesender D2→D3-Anschluss | Radiale Tierhaltung; Reiten/Pflügen D4; geplante Eierrolle/-produktion D1-EIER/D3-EIER |
| Dorf | Erneuerbare Quellen/Wasser, Berufe, gespeicherte Aufträge, feste Hütten/Zelte und Wachstum bis sechs Bewohner | Kugelorte, regionale Navigation, weitere Siedlungen; Gebäudeeditor erst Mittelalter |
| Fortschritt | Eigene Stammespunkte aus realen Arbeiten/Versorgung, eigene Nachbarfraktion mit Hilfstransport | Vollständige Folgeepochen bleiben gesperrt; kein Aufstieg fremder Tiere |
| Kreaturen | B1 Anschlüsse, B2 Passprüfung/Korrekturen, B3 Sattelauflage/Reitermaße und Bewegungsnachweise | Echte Reitsteuerung, Lastsimulation, Ziel-PC-Abnahme; geplanter Körperteilkatalog M3-TEILE |
| Oberfläche | Ein Buch mit D1-Eignung/D2-Tierregister, Körperteilvorschauen/Silhouetten, überarbeitete Skills/HUD, Gruppen-/Tierfeedback | Gemeinsame visuelle Ziel-PC-Abnahme; vollständige Übersetzung der Spielinhalte |
| Karten | Phasenskalierte Minimap, große Karte mit dauerhafter Erkundung, eigene/befreundete bekannte Orte; gleiche Karten auch im belebten Kugelbereich | Produktionskampagne auf Kugeln, später Galaxiennavigation |
| Sprache | Zentraler Dienst für Deutsch/Englisch, 221 Vorlagen, gespeicherte Menüauswahl | HUD/Buch/Dorf/Editor vollständig übersetzen; L1 ist keine Vollübersetzung |
| Wartung/Audio | Entfernte unreferenzierte Prototypen, isolierte Prüfungen, Streamingdiagnose, frühe Audiofreigabe und reale Mixerfrist | Windows-Gesamtpaket, Ziel-PC-Framezeiten; keine FPS-Zusage |
| Speicherung | Gemeinsames Save 8/Kampagne 2, körperfeste Kugelorte, atomare Kopie früher Stände mit Manifest und Quellarchiv; alte Verträge bleiben lesbar | Zielzuordnung und Übernahme besiedelter/veränderter Regionen, Gefährten, Pflichtarten und Wirtschaft |


`Antike/Mittelalter` und `Neuzeit/Weltmacht` verwenden zunächst die bestehenden Phasen-IDs 2 und 3; gespeicherte Enum-Werte werden nicht umnummeriert. `MULTIVERSE` bleibt nur kompatibler Altwert, ohne spielbaren Kernumfang. Ein HUD-Phasentext ist keine Freigabe dieser Epochen.

## Architektur und Zuständigkeiten

### Welt und Simulation

Universum → Galaxie → Sektor → System → Himmelskörper → Oberflächenregion → Objekt. IDs sind stabil und werden nicht aus der Reihenfolge von Listen abgeleitet. Die Cube-Sphere-Adresse mit kleinem lokalem Ursprung ist die Grundlage für große Kugeln. Höhe, Wasserspiegel, Biom, Bodennormale und Routen greifen auf dieselbe Oberflächenquelle zu.

Die bisherige Kampagne bleibt `legacy_plane_v9`, bis ein eigener Migrations-/Neuweltablauf geprüft ist. Fauna, Häuser, Audio, Reiter und Pflüge dürfen beim Kugelausbau nicht dauerhaft Welt-Y als „oben“ voraussetzen. Ein begrenzter Weltadapter muss das gemeinsam lösen. Die gesamte alte Ebene lässt sich nicht verlustfrei auf einen endlichen Planeten übertragen; dafür wird kein stilles Versprechen gegeben.

Nahe Objekte verwenden Physik/Animation, entfernte Gruppen vereinfachte Zustände, entfernte Regionen Vorräte/Populationen. Es gibt genau einen zuständigen Simulationsbesitzer; sichtbare Jagd, Milch-/Eierproduktion oder Transport werden nicht noch einmal abstrakt abgerechnet. Die Zahl aktiver Objekte bleibt begrenzt. Kampagnenzeit zählt bei Pause und geschlossenem Spiel nicht weiter, sofern später keine ausdrückliche Offline-Regel beschlossen wird.

### Phasenwechsel und eigene Spezies

Voraussetzungen prüfen → Folgen anzeigen → bestätigen → vollständigen Zustand atomar sichern → Kameras/Steuerung umstellen → am gleichen Ort fortsetzen. Schreibfehler, doppelter Klick und Neustart dürfen weder Bewohner verlieren noch Vermächtnis doppelt vergeben. Die Spezies-ID bleibt erhalten; nur Epoche, Organisation, Ausrüstung und freigegebene Systeme ändern sich.

`species_id` kennzeichnet die Art, `faction_id` die Gesellschaft und `object_id` das Individuum. Ein gezähmtes Tier erhält Besitzer/Bindung, aber weder die Spezies-ID des Spielers noch Bürgerstatus. Wildarten besitzen keine automatisch fortschreitende Zivilisation. Nachbarstämme der eigenen Spezies brauchen eigene Fraktions-/Technikstände statt einer globalen Umwandlung der gesamten Fauna.

### Punkte, Technik und Belohnungen

Punkte kommen aus abgeschlossenen, identifizierbaren Spielereignissen. Käufe, Vermächtnis und Wirkungen bleiben nach Laden einmalig. Alte Kreaturenpunkte bleiben im Kreaturenbaum, Stammespunkte im Stammesbaum. Wiederholtes Füttern/Melken/Eiersammeln/Pflügen darf keine endlose Sozialpunktmaschine werden. Neue gesellschaftliche Meilensteine und echte Kooperation sind bessere Punktequellen als einzelne Produktionsklicks. Körperwerte, Ausrüstung, Technik und Vermächtnis werden begrenzt und nachvollziehbar kombiniert.

## Neu: planetare Tierrollen und Zähmung

**Status: D1–D3 sind zusammengeführt; die Kampagne auf der Ebene und der begrenzte Kugelbereich bleiben getrennte Laufzeiten.** Vorhandenes Befreunden und Heimgefährten sind nicht mit Tierhaltung gleichzusetzen.

| Rolle | Mindestfunktion | Erforderliche Artmerkmale | Spielbarer Nachweis |
|---|---|---|---|
| Milchtier | Regelmäßig Milch als nutzbare Nahrung liefern | `milk`, zähmbar, Nahrung/Wasser, Produktionsintervall und -menge, geeigneter Körperplan | Tier zähmen, halten und versorgen; Milch zum Lager bringen; Pause/Laden erzeugt keine Doppelernte |
| Eierlieferndes Nutztier | Regelmäßig sammelbare Eier als Nahrung liefern | Geplante Rolle `eggs`, zähmbar, Nahrung/Wasser, Legestelle, Produktionsintervall/-menge; endgültige Feldnamen und Einheiten durch D1-EIER | Tier zähmen und versorgen → Eier an Legestelle erzeugen → sammeln → zum gemeinsamen Lager transportieren → verbrauchen; Pause/Laden/Nachladen erzeugen keine Doppelernte |
| Zugtier | Mit Geschirr/Pflug einen Acker bearbeiten | `draught`, Zugkraft, Ausdauer, Größe, Bodenbewegung, Geschirr-Anbindung | Tier und Arbeitsgerät gemeinsam zum Feld führen; tatsächlich gepflügte Fläche verbessert Landwirtschaft |
| Reittier | Bewohner auf dem Rücken tragen und bewegen | `riding`, Traglast, Reittempo, Ausdauer, passender Rücken-/Sattelsitz | Auf-/Absteigen, verständliche Reitersteuerung, sichere Bewegung/Kollision, Laden ohne verschwundenen Reiter |
| Hundeartiger Begleiter | Folgen, Warten, Heimkehren und später Wachen/Hüten | `companion`, Lernfähigkeit, Bindung, Wahrnehmung, Sozialverträglichkeit | Ein gezähmtes Individuum folgt zuverlässig, bleibt zu Hause und erhält seine Befehle über einen Neustart |

Das erweiterte Planungsziel umfasst mindestens **vier unterschiedliche geeignete Arten je belebtem Spielplaneten**: eine Milchtierart, eine eierliefernde Nutztierart, eine robuste Zug-/Reittierart und eine hundeartige Begleiterart. Die vierte Art ist die Einordnung des neuen Eierwunschs in die bestehende Planetengarantie. Zug- und Reitfähigkeit können bei derselben Art liegen; zusätzliche Spezialisten sind möglich. Fünf Fähigkeiten verlangen nicht fünf getrennte Arten. Ein Artprofil kann mehrere passende Rollen tragen, aber nicht jedes Tier bekommt alle Fähigkeiten.

Der zusammengeführte D1-Grundvertrag mit drei Pflichtarten bleibt als eigene Lieferung dokumentiert. **D1-EIER** erweitert ihn versioniert; vorhandene Arten-IDs, Tiere, Kataloge und Spielstände werden nicht neu ausgewürfelt. Eine Drei-Arten-Prüfung belegt noch nicht das geplante Vier-Arten-Ziel.

### Datenvertrag vor der Umsetzung

1. Versionierter, deterministischer Artenkatalog pro Himmelskörper. Dieselbe Körper-ID, Generatorversion und Seedfolge ergeben dieselben Arten samt Rollen, unabhängig von Besuchsreihenfolge oder Chunk-Neuladen. Bestehende Kataloge werden gespeichert/migriert und nicht bei jedem Start neu ausgewürfelt.
2. Geplante Rollenfelder: `domestication.roles`, `tameable`, `temperament`, `trainability`, `diet`, `water_need`, `strength`, `stamina`, `carry_capacity`, `milk_yield`, `milk_interval` sowie geeignete Reit-/Geschirr-Anschlüsse. Exakte Einheiten und Grenzen legt das Datenpaket D1 fest. D1-EIER ergänzt die Eierrolle und Produktionsdaten in einer abgestimmten Vertragsrevision; Feldnamen, Intervalle, Mengen und Legestellenanforderungen sind bis dahin Planungsdaten. Ökologischer Typ wie Pflanzenfresser bleibt von der Nutzungsrolle getrennt.
3. Planetare Garantie plus Habitatbezug: Ein Katalogeintrag allein genügt nicht. Mindestens eine Population jeder Pflichtrolle lebt in einem erreichbaren geeigneten Lebensraum. Spawnbegrenzung, Wiederbesuch, Wasser/Nahrung und Erhalt nach Jagd müssen einbezogen werden. Kein wissenschaftlicher Auftrag verlangt eine am Ort unmögliche Art.
4. Individueller Haltungszustand: `object_id`, `species_id`, Körper/Ort, Besitzerfraktion, Vertrauen/Zähmfortschritt, Gesundheit, Hunger/Durst, Auftrag, Ausrüstung und produzierte/transportierte Ressourcen. Art-Eignung ist nicht dasselbe wie bereits gezähmt sein. Das Entdeckungsbuch zeigt zunächst Eignung; eigene Haltung zeigt das konkrete Tier.
5. Zähmung beginnt erst in Phase 1 und prüft sichere Reichweite, Sicht, passende Nahrung, Kosten und Eignung. Unterbrechung, Flucht, Misserfolg, Tod und voller Stall/Bestand haben definierte Folgen. Nach Laden wird fortgesetzt; Befreunden in Phase 0 kann einen Vorteil geben, erzeugt jedoch noch kein Arbeitstier.
6. Rollen folgen nachvollziehbarer Morphologie: geeignete Standbeine, Rückenfläche und Tragfähigkeit bei Reittieren; starkes Landtier beim Pflügen. Keine sofort reitbaren Fische oder schwebenden Sättel. Prozedurales Aussehen darf bei gleichen Rollen stark variieren.
7. Tierhaltung ist ein Ressourcenablauf mit Futter/Wasser, Haltungskapazität, Betreuung, Produktion und Transport. Vermehrung/Bestandserholung, Tierverlust und Ersatz werden vor langfristiger Wirtschaft ergänzt. Dafür ist kein Genommodell notwendig.
8. Bestände und Tierbindungen überstehen Mittelalter/Neuzeit. Verbesserte Geschirre, Pflüge, Zuchtwahl als Spielbonus und später Maschinen erweitern/ersetzen Tätigkeiten; bestehende Tiere werden nicht beim Epochenwechsel gelöscht.

## Bedienoberfläche – Ergänzung aus dem Spieltest vom 9. September 2026

- **Visuelle Überarbeitung als eigenes Paket:** Entdeckungs- und Entwicklungsbuch mit klarer Auswahl/Detailansicht, echten Körperteilvorschauen und Silhouetten bei gesperrten Teilen/Fähigkeiten; kompakte Überlebensanzeige oben links. Übergabe und Prüflimits: [WORK_UI_VISUAL_REFRESH.md](docs/WORK_UI_VISUAL_REFRESH.md). Das Paket ist in der zweiten Integrationsrunde übernommen.
- **Minimap als geprüftes Fachpaket:** unten rechts, gemeinsames Gelände-/Wasserraster, Blickrichtung, Heimat und eigene Gruppenmitglieder. Der bestätigte Phasenwechsel erweitert den Maßstab automatisch; manuell +/− und Rückkehr zum Phasenmaßstab. Körpergebundene Projektion für V9 und Kugelplaneten, Save/Load sowie getrennte Dorfbedienung bei 1280 × 720 und 800 × 600 geprüft. Details und Grenzen: [WORK_MINIMAP.md](docs/WORK_MINIMAP.md). In der zweiten Integrationsrunde samt dauerhafter Weltkarte übernommen. Offen bleiben gespeicherte Wegpunkte, eigene gezähmte Tiere aus D2 und später passende Orbit-/Systemkarten; unbekannte Arten und Rohstoffe werden nicht verraten.
- **Abnahme auf dem Ziel-PC:** Lesbarkeit der Bücher und Silhouetten, neue Beerenstrauchform, E als einziger Art-/Wertezugriff und passende Drehrichtung im Editor. Die lokale automatische Funktionsprüfung ersetzt die optische Abnahme nicht.

## Weltraumphase – mobile Expeditionsbasis

Das erste Expeditionsschiff ist bereits deutlich größer als sein Landungs-/Erkundungsschiff. Die Basis bleibt beim Planeten im Weltraum, während der Spieler mit einem konkreten Beiboot landet, aussteigt und die Oberfläche untersucht. Schiffwechsel sind Kontroll-/Ortswechsel innerhalb derselben Kampagne und Epoche.

Rumpfteile, Brücke/Cockpit, Antrieb, Energie, Lager, Hangars, Forschung, Waffen und Schutz verwenden das gemeinsame Bauplanfundament. Forschung und Ressourcen schalten größere Baubereiche und Ausrüstung frei; der tatsächliche Umbau erhält Identität, Fracht und Bordschiffe. Hangarkapazität berücksichtigt auch die Abmessungen der Schiffe.

Schiffe, angedockte Beiboote, Fracht und Proben besitzen eindeutige Eigentümer und Orte. Andocken, Umladen und Umbau werden atomar gespeichert. Detailansicht, Hangarinhalte und entfernte Systeme verwenden begrenzte Darstellung/Simulation. Der erste komplette Expeditionsablauf kommt vor umfangreicher Flotte, Sektorreisen und Kolonien; Bewaffnung ist kein zwingendes Tor für friedlichen Fortschritt.

Die sechs Unterpakete, Modulgruppen, Fortschrittsstufen und Abnahmen stehen im [Expeditionsplan](docs/SPACE_EXPEDITION_PLAN.md). Diese Ergänzung plant die spätere Phase und startet keine konkurrierende Weltraumimplementierung während des Kugelumzugs.

## Meilensteine mit tatsächlichem Status

| ID | Status und nächstes Ergebnis | Voraussetzung | Abnahme |
|---|---|---|---|
| M0 | Gemeinsame Grundlage integriert und automatisch geprüft; Veröffentlichung und Übernahme nach main von Lars freigegeben | Bisherige Basis | Alle sieben Stränge mit denselben Spielständen, keine verlorenen IDs, doppelte Boni oder getrennten Buchinstanzen; manueller Windows-Spieltest bleibt offen |
| M1/M1b/M1c | Planetenlabor, reale Größen, Streaming und Katalogbesuche vorhanden | M0 | Technische Kugel-/Ortsprüfung erhalten; Ziel-PC-Framezeiten und Besuch/Laden abnehmen |
| M1d | **Teilweise:** belebte Kugelwelt, Boden/Wasser und D1.2; volle Kugelkampagne offen | M1b/M1c, gemeinsamer Oberflächenadapter | Spieler, Flora, Fauna, Haus, Wasser und Audio auf derselben radialen Oberfläche; Wiederbesuch; expliziter Altstandschutz |
| M1e | **Grundlage umgesetzt; erweiterter Umzug offen:** gemeinsamer Kugelstart, versionierte Orte, frühe Kopiermigration, Rückweg und Neustart | M1d und Integration | [Vertrag, Nachweise und verbleibende Migrationsfälle](docs/WORK_M1E_CAMPAIGN.md); vollständige Ortsübernahme mit M1f/M1g weiterführen |
| M2A | Verhaltenspunkte, Käufe und Vermächtnis vorhanden | M0 | Erfolgreiche Aktionen geben einmal Punkte, Effekte wirken; gemischte Spielweisen bleiben erreichbar |
| M2B | B1/B2/B3 zusammengeführt; gemeinsame Editor-/Anatomieverträge | M1-Adressen, vorhandene Kreaturenwerkstatt | Stabile Revisionen, Anschlussdaten, Vorschau/Laufzeit; neue Rollen können Körperfähigkeiten auslesen |
| BP-COMMUNITY | **Geplant:** gemeinsames Bauplanformat, lokale Vorlagenbibliothek und Community-Upload/Download | M2B, Vorschau, lokale Speicherung; je Typ spielbarer Verwendungsweg | Nutzer A veröffentlicht → Nutzer B findet/lädt → verwendet ohne Editorarbeit → Save/Load/offline; fünf Unterpakete im [Community-Designplan](docs/COMMUNITY_DESIGNS_PLAN.md) |
| M3 | Kreaturenwerkstatt ausgebaut | M2B | Zwei-/Vierbeiner und mehrere Beinpaare belastbar; Extremformen, Fußkontakt, Wasser/Flug bleiben weitere Arbeit |
| M3-TEILE | **Geplant:** alle Körperteile prüfen und überarbeiten/kompatibel ersetzen; zuerst Mund-/Kopfformen, Hände/Greifer und Tierfüße | M2B-Anschlüsse, vorhandener Teilekatalog, gemeinsame Designvorgabe | Einzeloptionen und Kombinationen aus dem [Backlog](docs/FEATURE_BACKLOG.md) in Vorschau/Laufzeit erkennbar; Symmetrie, Drehung, Fußkontakt und alte Entwürfe erhalten |
| M4 | Kreaturenspiel mit Scan, Forschung, Sozialspiel und Bedürfnis-KI vorhanden | M2/M3 | Zusammenhängender Ablauf; offene Tierjagd/Navigation/Ökologie und Tod/Erholung ergänzen |
| M5 | Bestätigter Stammesbeginn und erster Dorfablauf vorhanden | Heimatgruppe, begehbarer Ort | Gleiche Spezies und drei Bewohner, sichere Übergabe, Transport/Werkzeug/Hütten/Garten; Speichern und Neustart |
| D1 | D1/D1.1/D1.2 zusammengeführt: Art-Eignung, Körpernachweise und begrenzte planare/radiale Habitate | Stabile Spezies-/Körper-IDs | Milch-, Zug-/Reit- und Begleiterart deterministisch vorhanden und erreichbar; alte Arten behalten Identität |
| D1-EIER | **Geplant:** Eierrolle als Erweiterung der planetaren Garantie | Geprüfter D1-Grundvertrag und versionierte Katalogmigration | Vierte geeignete Art deterministisch und erreichbar; bestehende Arten/Individuen bleiben erhalten; Mehr-Seed-/Neustartprüfung |
| D2 | Kampagnenzähmung und dauerhafte Befehle zusammengeführt; radialer Host offen | D1, M5 | Eignung/Kosten/Phase prüfen; Tier folgt/wartet/kehrt zurück; Unterbrechung, Tod, Laden und Besitz geprüft |
| D3 | Tierpflege, Milch und Transport zusammengeführt; produktiver D2-Leseanschluss ergänzt | D2, gemeinsame Dorfvorräte | Betreuung → Produktion → Transport → Verbrauch, keine Doppelernte; Futter/Wasser/Haltungskosten wirken |
| D3-EIER | **Geplant:** Eier sammeln, transportieren und als Nahrung nutzen | D1-EIER, D2, gemeinsame D3-Haltungs-/Produktionsbasis und Dorfaufträge | Versorgung → Legestelle → Sammelauftrag → Lager → Verbrauch; genau ein Produktionsbesitzer, Save/Load und unterbrochener Transport ohne Verlust/Dopplung |
| D4 | **Neu:** Reiten und Pflügen | D2, M2B, Feld-/Routenmodell | Passender Reitsitz, sichere Auf-/Abstiege; Zugtier mit Pflug bearbeitet reale Felder, Arbeitsfortschritt speicherbar |
| M6 | Erneuerbare Wirtschaft, Berufe, Hütten/Zelte, sechs Bewohner, Tierhaltung und erste Nachbarhilfe; radiale Migration offen | M5, D1–D4 schrittweise | Erneuerbare Versorgung, Wasser, weitere Rohstoffe, Berufe, Wachstum, frei gebaute Häuser, Tiere und Nachbargruppen |
| M7 | **Geplant:** Antike/Mittelalter | Belastbares M6 | Landwirtschaft, Handwerk, Lager/Transport/Handel, Wege und mehrere Siedlungen; eigene Spezies bleibt Träger aller Fraktionen; bestätigter Wechsel |
| M8 | **Geplant:** Neuzeit/Weltmacht | M7, globale Orte/Simulation | Industrie/Energie, Ressourcenketten, Staaten, Diplomatie/Armeen, globale Karte; Tiere/Bestände werden übernommen; bestätigter Wechsel |
| M9 | **Geplant:** Weltraum mit modularer Expeditionsbasis und Beibooten | M8, vollständige Kugelkampagne auf M1b/M1c/M1d und Folgeadaptern | Großes Schiff steuern → Beiboot abdocken → Planetenanflug/Landung/Ausstieg → untersuchen → zurückkehren/andocken → Schiff ausbauen; danach weitere Systeme und versorgte Kolonien |
| M9.1 | **Geplant:** Schiffvertrag und erster modularer Editor für Expeditionsschiff/Beiboot | Bauplanfundament, Weltadressen, M8-Wirtschaft | Zwei eigene Entwürfe mit wirkenden Modulen, Größen-/Kapazitätsprüfung, Hangareignung und Save/Load |
| M9.2 | **Geplant:** vollständige erste Expedition in einem System | M9.1, Flug/Kollision/Übergaben, Kugelkampagne | Beide Schiffe direkt steuern; abdocken, landen, aussteigen, untersuchen und zur mobilen Basis zurückkehren |
| M9.3 | **Geplant:** Forschung, Proben und planetare Untersuchung | M9.2, vorhandene Entdeckungs-/Kartendienste | Erkenntnisse erhalten, Proben transportieren und einmalig auswerten |
| M9.4 | **Geplant:** größere Rümpfe, Ausstattung und Fracht-/Modulkapazität | M9.3, Technologie, Ressourcen, Bau-/Leistungsbudget | Größeren Baubereich erschließen und tatsächlich umbauen; Schiffe/Fracht bleiben erhalten |
| M9.5 | **Geplant:** weitere Bordschiffe, Hangars und Bewaffnung | M9.2/M9.4, Flottenzustand, passende Kampf-/KI-Grundlage | Individuelle Bordschiffe verwalten, Hangarbelegung/Rückkehr prüfen und bewaffnete Ausrüstung spielbar machen |
| M9.6 | **Geplant:** System-/Sektorreise, Galaxienkarte und versorgte Kolonien | M9.2–M9.4, Galaxiekatalog, begrenzte Fernsimulation, Siedlungswirtschaft | Zu weiterem System reisen, Expedition/Kolonie versorgen und zu erhaltener Heimat zurückkehren |
| M10 | **Geplant:** Inhalt, Balancing und Veröffentlichung | Wiederholt spielbare Epochenkette | Verständlicher Einstieg, Niederlage/Erholung, Langzeitstände, Bedienbarkeit, Leistung und Ton auf Zielgerät abgenommen |

D1–D4 einschließlich D1-EIER/D3-EIER sind Teil des Stammesausbaus, keine zusätzlichen Spielzeitalter. M3-TEILE gehört zur Kreaturenphase und baut auf den gemeinsamen M2B-Anschlüssen auf; die Erstlieferung setzt weder Mittelalter noch Reiten/Pflügen voraus. Eierproduktion wartet nicht auf den vollständigen neuen Körperteilkatalog. M9.1–M9.6 konkretisieren die Weltraumphase; Daten-/Editoranschlüsse können früh berücksichtigt werden, die Spielschleife folgt nach M8 und vollständiger Kugelkampagne. Die Weltraumphase bleibt Ziel; sie wird nicht parallel zu einer noch unvollständigen Dorfwirtschaft als halbfertige Spielschleife begonnen.

BP-COMMUNITY ist ein phasenübergreifender Ausbau: Format und lokale Vorlagen früh an M2B/M3 anschließen, den Online-Ablauf zuerst für eine spielbare Bauplanart liefern und weitere Arten mit ihren Fachsystemen ergänzen. Er ist keine zusätzliche Epoche und setzt weder vollständige Raumfahrt noch Multiplayer-Spielsimulation voraus.

## Fehlende Querschnittspunkte

| Thema | Nächste konkrete Aufgabe | Zeitpunkt |
|---|---|---|
| Gemeinsame Designs | Portables Paket, Vorlagenwahl ohne Editorpflicht, Online-Katalog, geprüfte Typadapter und versionierte Downloads; Bauplan und individuelle Weltobjekte trennen | BP-COMMUNITY.1–.5; Kreaturen zuerst, weitere Typen mit ihren Phasen |
| Gemeinsame Basis | Automatische Integrationstests und Windows-Testpaket vorhanden; Windows-Spieltest durchführen; jede neue Arbeit vom gleichen zusammengeführten main beginnen | Jetzt |
| Fauna im Stammeszeitalter | D2 aktiviert Bedürfnis-/KI-Logik in Phase 1 und erhält die Angriffssperre; diese Trennung auf Kugeln übernehmen | Kugel-D2 |
| Gruppenkampf | Alle Gruppenmitglieder als gültige Ziele, Gesundheit/Tod/Abwehr und eindeutige Besitzregeln | Vor Verteidigungsvermächtnis/Nachbarkonflikten |
| Tierverlust/Bestand | Ersatz, Fortpflanzung oder begrenzte Bestandserholung; keine softlocks durch Ausrottung einer Pflichtrolle | D1/D3, vor Langzeitkampagne |
| Nahrungsketten | Gemeinsame Vorräte statt paralleler Doppelverbraucher; Jagen/Fressen/Milch/Eier/Abstraktion einmal abrechnen; Eierproduktion und Fortpflanzung getrennt führen | M4/M6, D3-EIER |
| Navigation | Wege um neue Hindernisse wieder aufnehmen; geladene Grenzen, Wasser, Reiterhöhe und Pflugbreite berücksichtigen | M6/D4 |
| Bauen | Editorentwurf mit Revision, Kosten, Baustelle, Eingang, Kollision und freiem Bauplatz verbinden | M6 |
| Bevölkerung | Wohnraum, Versorgung, neue Bewohner/Arbeitskräfte, Namen und Rollen, ohne Neustart aus sichtbaren Nodes abzuleiten | M6 |
| Epochenziele | Reale Versorgung/Produktion/Organisation als Voraussetzungen; friedlicher und aggressiver Weg | M6–M8 |
| Kulturentwicklung | Eigene Spezies bleibt dieselbe; Fraktionen können unterschiedliche Technikstände besitzen | Vor Nachbarstämmen/M7 |
| Bedienung | Scan/Forschung in Kreaturenphase, Tierregister/Gruppenaufträge im Stamm; keine überlappenden Pausen und HUDs | D2/M6 |
| Audio | Erfolgsereignisse aus abgeschlossenen Aktionen, keine Klänge für gescheiterte Käufe/Produktion; unterschiedliche Epochenatmosphäre | Fortlaufend |
| Welt-/Spielstandmigration | Versionen von Artenrollen, Haltung und Phasen prüfen; Zukunftsstände nicht mit altem Backup überschreiben | Vor jedem neuen Zustand |
| Leistung | Referenz-PC erfassen; Framezeit, Speicher, aktive Tiere, Draw Calls und Nachladezeiten pro Messszene | Vor größerem Dorf und M1d |
| Niederlage | Einzelkreatur/Tier/Bewohner/ganzer Stamm: Fortsetzung und Wiederaufbau eindeutig machen | M4/M6, jede Folgephase |
| Umfang | Keine automatische Zusage für Multiplayer, Multiversum, tiefe Höhlen oder physikalische Vollsimulation | Außerhalb Kernumfang |

## Nächste parallele Arbeitsrunde

Die priorisierten Umzugsaufträge stehen in [NEXT_PARALLEL_WORK.md](docs/NEXT_PARALLEL_WORK.md). Alle Chats starten vom selben integrierten Stand. D1–D3 sind bereits übernommen. Zuerst wird M1e als gemeinsamer Orts-/Kampagnenvertrag abgeschlossen; danach folgen Kreaturenphase, Dorf/Tierhaltung und Fernsimulation auf derselben Kugelgrundlage. Kein Chat führt fremde unfertige Branches zusammen.

Roadmap und gemeinsame Kerndateien haben pro Runde genau einen Integrationsverantwortlichen. Jeder Fachchat liefert einen eigenen Branch, exakten Commit, geänderte Dateien, Ergebnisse und Restgrenzen in seinem Übergabebericht. Erst danach folgt eine erneute gemeinsame Abnahme. Empfehlungen zum Ziel-PC gelten als offene Messung; bisherige Software-Renderer-Nachweise sind keine belegten 60 FPS auf Lars’ Rechner.
