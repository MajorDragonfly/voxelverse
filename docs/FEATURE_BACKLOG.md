# Voxelverse – Ideen und konkrete To-dos

Stand: 9. September 2026. Ergänzt die [gemeinsame Roadmap](../ROADMAP.md) um neue Nutzerwünsche. Diese Datei beschreibt geplante Arbeit, keine bereits implementierten Funktionen. Die [Arbeitsaufteilung](NEXT_PARALLEL_WORK.md) und bestehenden Fachverträge bleiben die Grundlage.

## Pflege und Status

- Neue Ideen nach Spielphase, bestehendem Meilenstein und Abhängigkeiten einordnen; bei Überschneidung den vorhandenen Eintrag erweitern.
- Status unterscheiden: **geplant → in Arbeit → geliefert → integriert → getestet**. Technische Prüfungen und Lars' Spieltest getrennt mit Version und Ergebnis dokumentieren.
- Dieser Roadmap-Chat pflegt aufgrund des Nutzerauftrags die Ideen und ihre Einordnung. Änderungen an Integrations- oder Teststatus benötigen weiterhin konkrete Nachweise des zuständigen Fach-/Integrationschats.
- Keine neuen Implementierungsaufträge allein durch einen Planungseintrag als gestartet melden. Bestehende Facharbeiten bleiben bei ihren Zuständigkeiten.

## Übersicht

| ID | Gewünschtes Ergebnis | Spielphase / Einordnung | Reihenfolge | Status |
|---|---|---|---|---|
| D1-EIER | Eine geeignete, erreichbare Eierlieferanten-Art je belebtem Spielplaneten | Artenkatalog; entdeckbar in der Kreaturenphase, nutzbar ab Stamm | Nach geprüftem D1-Grundvertrag; vor D3-EIER | Geplant |
| D3-EIER | Versorgung, Eierlegen, Sammeln, Transport und Nahrung aus eigenen Tieren | Tierhaltung und Dorfwirtschaft, D3/M6 | Nach D1-EIER, D2 und gemeinsamer D3-Haltungsbasis | Geplant |
| M3-TEILE | Alle Körperteile überarbeiten oder kompatibel ersetzen; erkennbare Einzelteile realer Tiere frei kombinieren | Kreatureneditor, M2B/M3 | Bestandsprüfung und Anschlussregeln zuerst; danach Modellpakete und UI | Geplant |
| M9-EXPEDITION | Modulares Expeditionsschiff, kleinere Landungsschiffe, Planetenuntersuchung und wachsender Schiffsausbau | Weltraumphase, M9.1–M9.6 | Nach M8 und vollständiger Kugelkampagne; Daten-/Editoranschlüsse früh vorbereiten | Geplant |

Die Reihenfolge ist technisch begründet. Der Kugelwelt-Umzug bleibt ein eigenes grundlegendes Paket. M9-EXPEDITION ist eine spätere Weltraumplanung; die laufenden Umzugsarbeiten behalten Vorrang. Datenkatalog und Modelle können unabhängig davon vorbereitet werden; finale Platzierung, Bodenkontakt, Legestellen und Transporte müssen die gemeinsame radiale Oberfläche nutzen.

## D1-EIER – Eierliefernde Nutztiere im Artenkatalog

**Nutzerwunsch:** Zusätzlich zu den bereits vorgesehenen Nutztieren und Milchlieferanten sollen Tiere Eier als Ressource liefern.

**Planungseinordnung:** Die bestehende Garantie wird um eine vierte geeignete Art je belebtem Spielplaneten ergänzt. Die drei bisherigen Arten für Milch, Zug/Reiten und Begleitung bleiben erhalten. Die neue Art darf pro Planet unterschiedlich aussehen; sie ist keine zwingend überall gleich aussehende Huhn-Kopie.

**Zuständigkeit:** D1/Artenkatalog; D2 besitzt weiterhin Zähmung und Individuen, D3 die Haltung/Wirtschaft, das Entdeckungsbuch liest deren Daten.

- [ ] Eierlieferfähigkeit im vorhandenen Eignungsvertrag versioniert ergänzen. `eggs` ist hier ein vorgeschlagener Rollenname; die endgültige Kennung und Datenfelder legt der D1-Vertrag fest.
- [ ] Produktionsmenge, Intervall, Einheiten und Voraussetzungen für Versorgung/Legestelle eindeutig definieren; Aussehen, Art-Eignung, Zähmung und aktueller Produktionszustand bleiben getrennt.
- [ ] Deterministische, erreichbare Vorkommen mit passendem Habitat, Nahrung und Wasser vorsehen; eine Katalogzeile allein erfüllt die Garantie nicht.
- [ ] Bestehende Kataloge gezielt erweitern/migrieren, ohne ihre bisherigen Arten oder Individuen neu zu generieren. Eine zusätzliche Art erhält eine stabile Identität.
- [ ] Scan und Entdeckungsbuch zeigen die tatsächlich bekannte Eier-Eignung; das eigene Tierregister liest den gespeicherten individuellen Zustand.
- [ ] Mehrere Seeds, Besuchsreihenfolge, Wiederbesuch, Neustart und Altstände prüfen. Rollenverlust durch Ausrottung an die vorhandene Bestands-/Ersatzplanung anschließen.

**Abnahme:** Auf einem neuen belebten Spielplaneten sind alle vier Pflichtarten erreichbar. Ein migrierter Altstand behält seine bisherigen Arten, Entdeckungen und Tiere und erhält die neue Rolle über einen nachvollziehbaren Migrationsweg. Lebenslose Körper erhalten keine künstliche Fauna.

## D3-EIER – Eier als Nahrungskette im Stammesdorf

**Zuständigkeit:** D3/Dorfwirtschaft. Bestehende D2-Tiere, gemeinsame Vorräte und wiederaufnehmbare Aufträge verwenden.

- [ ] Ein tatsächlich gezähmtes, geeignetes Individuum einem Haltungsplatz mit Legestelle zuordnen.
- [ ] Futter, Wasser, Betreuung und Haltungskapazität in der gemeinsamen Haltungslogik berücksichtigen; fehlende Versorgung hat eine definierte Wirkung.
- [ ] Eier mit nachvollziehbarem Intervall und Menge an der Legestelle erzeugen. Genau ein zuständiger Dienst verbucht die Produktion in naher und vereinfachter Simulation.
- [ ] Bewohner sammeln fertige Eier, tragen sie tatsächlich und liefern sie ins gemeinsame Lager. Das Lager erhält die Ressource erst bei erfolgter Lieferung.
- [ ] Eier als Nahrung an die vorhandene Vorrats-/Verbrauchslogik anschließen; keinen zweiten Nahrungsvorrat oder Verbrauchsdienst einführen.
- [ ] Unterbrochene Sammel-/Transportaufträge wieder aufnehmen. Gespeicherter Ort und Besitzer der Ressource bleiben eindeutig: Legestelle, Transport oder Lager.
- [ ] Produktion, Lagerung, Pause, Nachladen, Neustart, Tierverlust und Epochenwechsel erhalten/prüfen. Keine doppelte Ernte und kein unbeschlossenes Offline-Wachstum.
- [ ] Erfolge an vorhandene Ereignisse anschließen; wiederholtes Eiersammeln erzeugt keine unbegrenzten Sozial-/Stammespunkte.

**Abnahme:** Ein Bewohner versorgt ein eigenes Tier, sammelt dessen Eier und liefert sie als nutzbare Nahrung ins Lager. Speichern und Laden vor dem Sammeln, unterwegs und nach Lieferung erhält genau denselben Bestand und Arbeitsfortschritt.

**Abgrenzung:** Essbare Eier sind ein Produktionsgut. Bebrüten, Nachwuchs und Vermehrung gehören zur gesonderten Bestandsplanung und werden durch diesen Wunsch nicht automatisch als fertige Zuchtmechanik vorausgesetzt. Für die erste Eierkette ist kein vollständiger neuer Körperteilkatalog notwendig.

## M3-TEILE – Baukasten aus erkennbaren Tierkörperteilen

**Nutzerwunsch:** Die vorhandenen Körperteile insgesamt erneut prüfen und überarbeiten oder ersetzen. Reale Tierformen sollen als einzelne Optionen erkennbar sein, damit daraus ein eigenes Wunschtier gebaut werden kann. Genannt wurden Rüssel, Schnauze, Oktopusmund, Pfoten, Tatzen, Krallen, Krebsscheren und verschiedene Tierfüße.

**Zuständigkeit:** Kreaturen/Editor für Teile, Anschlüsse, Renderer und Bewegung; D1 liest Körperfähigkeiten. Gemeinsame Designvorgabe, Symbole und Freischaltungen verwenden. Das bestehende Umwelt-Artprogramm in [FINAL_PRODUCTION_ROADMAP.md](../art/FINAL_PRODUCTION_ROADMAP.md) bleibt ein eigener Arbeitsbereich.

### 1. Bestand und Vertrag

- [ ] Alle vorhandenen Teile und Kategorien erfassen, auch außerhalb der ersten Mund-/Hand-/Fußlieferung. Pro bestehender Teile-ID dokumentieren: überarbeiten, kompatibel ersetzen oder bereits passend; keine Kategorie ungeprüft auslassen.
- [ ] Einen erweiterbaren Katalog nach Teilefamilien führen. Unterschiedliche Formen sind einzeln auswählbare Einträge, keine bloßen Farbstufen desselben Modells.
- [ ] Stabile IDs/Revisionen, Befestigung, Drehung, Größe, Symmetrie, Kontaktpunkte, Animationsanschlüsse und ausgewiesene Fähigkeiten festlegen.
- [ ] Bestehende IDs, Freischaltungen, Entwürfe und prozedurale Arten schützen. Visueller Ersatz erhält eine dokumentierte Revision/Migration oder die bisherige Darstellung; alte Designs dürfen keine fehlenden Teile bekommen.
- [ ] Kompatibilitätsregeln lassen Kombinationen verschiedener Tiere zu. Einschränkungen ergeben sich aus verständlichen Anschluss-/Bewegungsregeln, nicht aus festen Kompletttier-Presets.

### 2. Erste Teilefamilien und Ausbauvorschläge

**Ausgeschmückter Gesamtkatalog:** [CREATURE_PARTS_CATALOG_PLAN.md](CREATURE_PARTS_CATALOG_PLAN.md) beschreibt zusätzlich Köpfe/Kiefer/Zähne/Zungen, Augen/Ohren/Fühler, Rumpf/Hals, Beine/Arme, Flügel/Flossen/Tentakel, Schwänze, Hörner/Geweihe/Panzer und Haut-/Farbmuster. Er enthält konkrete Tierformen, Kombinationsbeispiele und fünf Unteraufgaben M3-TEILE.1–.5. Die folgende Tabelle hält den ursprünglichen ersten Lieferumfang fest.

Die ausdrücklich genannten Beispiele sind Pflichtumfang der ersten Lieferung. Weitere Beispiele unten sind konkrete Ausbauvorschläge; sie bedeuten keinen abgeschlossenen Anspruch auf jede existierende Tierform.

| Familie | Pflichtbeispiele des Nutzerwunschs | Vorgeschlagene weitere Einzeloptionen |
|---|---|---|
| Mund/Kopf | Schnauze, Rüssel als eigenes Kopfmodul, Oktopusmund als eigenständige sichtbare Form | Kurze/lange Schnauze, schmale/breite Kiefer, verschiedene Schnäbel und Mundöffnungen |
| Hände/Greifer | Pfote, breite Tatze, Krallen, Krebsschere | Greifhand, Varianten mit unterschiedlicher Zehen-/Fingerform |
| Füße | Verschiedene erkennbare Tierfüße; Pfoten/Tatzen und Krallenfüße als eigene Optionen | Einzelhuf, Spalthuf, Vogelfuß, Schwimmfuß, breiter Standfuß, Haft-/Kletterfuß |

Ein Rüssel wird im Editor bei Mund/Kopf auffindbar, erhält aber eine passende eigene Befestigung und ersetzt den Mund funktional nicht automatisch. Der Oktopusmund braucht eine eigenständige erkennbare Modellform; ein vorhandener allgemeiner Schnabel wird nicht nur umbenannt. Krallen können passende Pfoten/Füße ergänzen; eine Schere ist ein eigener Greifer mit beweglicher Öffnung. Der Vertrag verhindert dabei doppelte oder schwebende Anbauteile.

### 3. Modelle, Bearbeitung und Bewegung

- [ ] Den [Gesamtkatalog](CREATURE_PARTS_CATALOG_PLAN.md) familienweise ausarbeiten und jede Form mit Status/Revision führen. Körpergrundformen, einzelne Teile, Materialmuster und besondere Bewegungsfunktionen eindeutig auseinanderhalten.
- [ ] Zuerst je Familie ein Referenzmodell als sichtbaren Qualitätsmaßstab erstellen; anschließend die weiteren Varianten im selben feinen Voxelstil ausarbeiten.
- [ ] Formen müssen bereits über Umriss und Bauform unterscheidbar sein. Farbe/Hautmuster bleiben kombinierbar; Detailgrad und Proportionen sollen zum bestehenden Körper passen.
- [ ] Drehung, Größe, Position, Mittelachse und gespiegeltes Anbringen für jede passende Option prüfen.
- [ ] Mund-/Greiferöffnung und bewegliche Module an das vorhandene Animationssystem anschließen; Vorschau und Laufzeit nutzen dieselbe Geometrie/Anschlussdefinition.
- [ ] Fußformen erhalten tatsächliche Stand-/Kontaktpunkte. Zwei Beine, vier Beine und mehrere Beinpaare müssen nach Formwechsel belastbar den Boden erreichen; die lokale Oberflächennormale gilt auch auf Kugelplaneten.
- [ ] Neue Form allein schaltet keine unimplementierte Funktion frei. Wasser-/Flugbewegung, Klettern, Zugkraft oder neue Kampfaktionen benötigen die jeweiligen Spielsysteme. Werte stammen aus bestehenden, begrenzten Körperfähigkeiten; zusätzliche Anbauteile vervielfachen sie nicht unbegrenzt.

### 4. Auswahl, Entdeckung und Erhalt

- [ ] Teile nach klaren Familien anzeigen; freigeschaltete Optionen mit echter Vorschau, gesperrte mit Silhouette entsprechend der gemeinsamen Designvorgabe.
- [ ] Benennung, Symbole und Übersetzungen zentral verwenden. Scanner, Entdeckungsbuch und Editor zeigen dieselbe Teileidentität und dieselben belegten Fähigkeiten.
- [ ] Neue prozedurale Arten können passende Kombinationen aus dem gemeinsamen Katalog verwenden, ohne gespeicherte Altarten still umzubauen.
- [ ] Vorschau-, Modell- und Laufzeitkosten für viele Kreaturen berücksichtigen; kleine Teile benötigen keine unbegrenzt teure Geometrie.

**Abnahme:** Rüssel, Schnauze, Oktopusmund, Pfote/Tatze, Krallen und Krebsschere sind einzeln auffindbar und visuell unterscheidbar. Mehrere unterschiedliche Tierfußformen lassen sich anbringen. Eine Kreatur kombiniert Teile verschiedener Vorbilder und behält Bearbeitung, Spiegelung, Bodenstand und Darstellung nach Save/Load. Alle alten Teile wurden mit einer nachvollziehbaren Entscheidung erfasst; Altentwürfe und Freischaltungen bleiben nutzbar. Technische Abnahme und Lars' visuelle Bewertung werden getrennt dokumentiert.

## M9-EXPEDITION – Mobile Basis, Beiboote und wachsender Schiffsausbau

**Nutzerwunsch:** Ein großes selbst gestaltetes und ausgerüstetes Expeditionsschiff im Größen-/Spielgefühl eines Sternzerstörers bereist den Weltraum. Kleinere Schiffe übernehmen Landung, Ausstieg und Untersuchung der Planeten. Fortschritt in der Weltraumphase ermöglicht größere Expeditionsschiffe, Waffen, Lagerraum, zusätzliche Bordschiffe und weitere Module.

**Einordnung:** Konkretisierung des vorhandenen M9, nach der vollständigen Kugelkampagne und M8. Der [Expeditionsplan](SPACE_EXPEDITION_PLAN.md) ist die gemeinsame Detailquelle für Rollen, Module, Fortschritt, Zustandsübergaben und die Unterpakete M9.1–M9.6.

- [ ] Gemeinsames Bauplanfundament für beide Schiffsebenen erweitern: Rumpfmodule, Cockpit/Brücke, Antriebe, Energie, Fracht, Hangar und passende Ausrüstung.
- [ ] Bereits den Einstieg mit großem Expeditionsschiff plus einem kleinen Landungs-/Erkundungsschiff planen; beide direkt steuerbar und individuell gespeichert.
- [ ] Vollständigen Ablauf liefern: Reise → Hangar/Abdocken → planetarer Anflug → Landung/Ausstieg → Untersuchung → Rückflug/Andocken.
- [ ] Vorhandene Körperadressen, radiale Oberfläche, Karten, Arten und Entdeckungen verwenden; physische Proben tatsächlich transportieren.
- [ ] Größere Baubereiche, Lager-/Modulkapazität und neue Ausrüstung über Forschung, Ressourcen und tatsächlichen Umbau freischalten.
- [ ] Zusätzliche eigene Bordschiffe, passende Hangarbelegung und später wirkende Bewaffnung als klar abgegrenzte Erweiterungen liefern.
- [ ] Schiffwechsel, Fracht, Umbau, Pause/Neustart, Verlust-/Ersatzfälle und Nah-/Fernsimulation ohne Duplikate oder verlorene Zustände prüfen.
- [ ] Bestehendes Ziel System-/Sektorreise, Galaxienkarte und versorgte Kolonien auf den vollständigen Expeditionsablauf aufbauen.

**Abnahme:** Ein selbst gestaltetes Expeditionsschiff bringt ein individuelles Beiboot zu einem echten Kugelplaneten. Der Spieler fliegt hinunter, landet, steigt aus, untersucht die Umgebung und kehrt zur Basis zurück. Forschung erlaubt einen ersten wirksamen Schiffsausbau. Alle Schiffe, Güter, Entdeckungen und Orte überstehen Speichern/Neustart. Waffenfortschritt ist kein zwingendes Tor für friedliche Forschung oder Kolonisation.

## Umsetzung und Übergabe

1. D1-EIER als Vertrags-/Katalogerweiterung vorbereiten; M3-TEILE mit Bestandsprüfung und Anschlussvertrag beginnen.
2. M3-TEILE gemäß [Katalogplan](CREATURE_PARTS_CATALOG_PLAN.md) in fünf Unteraufgaben liefern: Bestand/Vertrag → erste Mund-/Hand-/Fußmodelle → breiter Landtierkatalog → bewegliche Spezialteile → gemeinsame Abnahme. Neue Flug-/Wasser-/Kletterfunktionen werden jeweils separat angeschlossen.
3. D3-EIER auf den geprüften D1-/D2-/D3-Verträgen anschließen, unabhängig vom Abschluss aller neuen Modelle.
4. Entdeckungsbuch, Vorschauen und Übersetzungen an die tatsächlichen Fachlieferungen anschließen.
5. Je Teilpaket Branch, exakten Commit, geänderte Dateien, Vertragsrevisionen, Prüfungen und Grenzen liefern; erst danach Integrations-/Teststatus aktualisieren.

Die neuen Wünsche sind damit erfasst und zerlegt. Laufende Fachbranches werden für diesen Planungseintrag nicht zusammengeführt.
