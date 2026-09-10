# Voxelverse – Weltraumphase mit Expeditionsschiff und Beibooten

Stand: 10. September 2026 · **Status: Datenentwurf integriert, Spielphase geplant** · Konkretisierung von **M9** aus der [Roadmap](../ROADMAP.md). Die Aufgabenübersicht steht in [FEATURE_BACKLOG.md](FEATURE_BACKLOG.md).

Der [ARCH-30-Schiffs-/Reise-Datenentwurf](WORK_ARCH30_EXPEDITION_CONTRACT.md) ist mit Referenzprüfung im [gemeinsamen Stand](INTEGRATION_2026-09-10.md) enthalten. Er definiert Entwurf, individuelles Schiff, Oberfläche/Systemraum/Dock und begrenzte Übergaben. Laufzeit-/Save-Anschluss, große gespeicherte Double-Koordinaten, Schiffbau und der folgende Spielablauf bleiben offen.

## Ziel und Nutzerwunsch

Lars möchte mit einem großen, selbst gestalteten und ausgerüsteten Expeditionsschiff durch den Weltraum reisen. Ein Sternzerstörer aus Star Wars beschreibt dabei das gewünschte Gefühl von Größe und einer mächtigen mobilen Basis. Ein kleineres Schiff in der Größenrolle eines Starfighters übernimmt den Flug zur Oberfläche, die Landung und die planetare Expedition. Im Verlauf der Weltraumphase soll das Expeditionsschiff größer werden und mehr Waffen, Lagerraum, zusätzliche Schiffe und weitere Ausstattung aufnehmen können.

**Schon der Einstieg verwendet zwei Schiffsebenen:** Das erste Expeditionsschiff ist gegenüber seinem Beiboot groß. Spätere Fortschritte erweitern den möglichen Rumpfumfang und die Ausstattung weiter. Der Spieler kann die Schiffe aus einzelnen Teilen im gemeinsamen Bauplansystem gestalten oder eine passende fertige Vorlage wählen. Mitgelieferte und heruntergeladene Community-Entwürfe sind ohne eigene Editorarbeit verwendbar; beide Schiffe besitzen eigene gespeicherte Entwürfe und individuelle Zustände. Der gemeinsame [Community-Designplan](COMMUNITY_DESIGNS_PLAN.md) regelt Austausch und Versionen; Größe, Module, Baukosten und Hangareignung werden vor der Verwendung geprüft.

Die eigene Spezies, ihre Zivilisation, Heimat und bisherige Entdeckungen bleiben erhalten. Der ausdrücklich bestätigte Wechsel in die Weltraumphase schaltet ihre tatsächlich spielbaren Systeme frei. Das Steuern eines Beiboots oder eines Forschers auf einer Oberfläche ändert nicht die gespeicherte Epoche.

## 1. Der zentrale Spielablauf

1. **Expedition vorbereiten:** Passenden Expeditionsschiffentwurf aus Vorlagen wählen oder selbst gestalten, Schiff bauen/umbauen, Module ausrüsten, ein kleines Landungs-/Erkundungsschiff mitnehmen und benötigte Vorräte verladen.
2. **Mit dem großen Schiff reisen:** Schiff direkt steuern und über die passende Orbit-/System-/Galaxienkarte ein bekanntes oder erreichbares Ziel auswählen. Erste Reisen bleiben auf einen begrenzten, spielbaren Systembereich beschränkt.
3. **Planeten anfliegen und grob untersuchen:** Geeigneten Aufenthaltsort beim Planeten wählen und mit den tatsächlich verfügbaren Sensoren mögliche Expeditionsziele ermitteln.
4. **Ins Beiboot wechseln:** Ein konkretes Schiff aus dem Hangar auswählen, abdocken und selbst zur Oberfläche fliegen. Das Expeditionsschiff verbleibt als persistente mobile Basis im Weltraum.
5. **Landen und aussteigen:** Einen geeigneten Ort auf derselben Kugeloberfläche anfliegen, sicher landen und mit einer kontrollierten Figur der eigenen Spezies die Umgebung erkunden. Spätere Gruppenexpeditionen schließen an vorhandene Gruppensteuerung an.
6. **Untersuchen:** Terrain, Lebensräume, Arten und Ressourcen mit den vorhandenen Entdeckungs-/Scanregeln erfassen; geeignete Proben oder Fundstücke physisch im Beiboot verstauen.
7. **Zur Basis zurückkehren:** Zum eigenen Beiboot zurückgehen, starten, zum Expeditionsschiff fliegen und wieder andocken.
8. **Auswerten und erweitern:** Fracht kontrolliert übertragen, Forschungsergebnisse auswerten und daraus neue Möglichkeiten für Rumpf, Ausrüstung und weitere Schiffe erschließen.

Eine erste spielbare Lieferung muss den vollständigen Weg bis zur Rückkehr tragen. Kolonien und weitreichende Galaxienreisen bauen anschließend darauf auf. Erkundung und Forschung bleiben ein tragfähiger Fortschrittsweg.

## 2. Rollen der Schiffe

| Schiff | Hauptaufgabe | Geplante Fähigkeiten |
|---|---|---|
| Großes Expeditionsschiff | Mobile Basis und Reiseplattform | Direkte Steuerung im Weltraum, große Vorräte, Forschung, Hangars, Energie-/Antriebssysteme und später umfangreiche Bewaffnung |
| Landungs-/Erkundungsschiff | Verbindung zwischen Basis und Planetenoberfläche | Abdocken, planetarer Anflug, atmosphärischer Flug auf geeigneten Welten, Landen/Starten, Ausstieg, begrenzte Fracht, Rückkehr und Andocken |
| Zusätzliche Bordschiffe | Später unterschiedliche Expeditionsaufgaben übernehmen | Geplante Ausprägungen: schneller Aufklärer, Transporter, Forschungslander und bewaffnetes Begleitschiff; alle mit eigener Identität und Ausrüstung |

Landungsfähigkeit und Hangareignung sind geprüfte Fähigkeiten eines Entwurfs. Ein kleines Schiff erhält sie nicht allein durch seine Bezeichnung. Der Spieler kann das Aussehen innerhalb passender Anschlüsse und der freigeschalteten Baugrenzen selbst bestimmen.

## 3. Modularer Schiffbau und Ausrüstung

Beide Schiffsebenen verwenden das vorhandene gemeinsame Editor-/Bauplanfundament, stabile Teilekennungen und Entwurfsrevisionen. Ein kleines Schiff und ein großes Schiff benötigen dabei unterschiedliche Baugrenzen und Funktionsanforderungen.

| Modul-/Teilefamilie | Geplante Auswahl | Auswirkung / Prüfpunkt |
|---|---|---|
| Rumpf und Verbindungen | Rumpfsegmente, Verbindungsstücke, Bug-/Heckformen, Aufbauten und Außenverkleidung | Lesbare eigene Silhouette, verbundener Bauplan, Masse, Kollisionshülle und verfügbare Modulplätze |
| Steuerung | Brücke beim Expeditionsschiff, Cockpit beim Beiboot | Gültiger Steuerungspunkt und eindeutiger Wechsel des aktiv gesteuerten Schiffs |
| Antrieb | Haupttriebwerke, Manövertriebwerke und später Antriebe für größere Reisedistanzen | Tragfähige Bewegung, Energie-/Versorgungsbedarf und freigeschaltete Reichweite; keine unbelegte Reiseleistung durch Dekoration |
| Energie und Versorgung | Energieversorgung, Speicher und notwendige Wärme-/Betriebskapazität | Gemeinsames begrenztes Leistungsbudget; Antrieb, Scanner, Waffen und Schutz konkurrieren um verfügbare Leistung |
| Lager | Zusätzliche Frachträume, Probenbehälter und passende Versorgungslager | Tatsächliche Kapazität sowie klare Eigentümerschaft und Speicherung der transportierten Güter |
| Hangar und Dock | Einzelner Beibootplatz, größere Hangars, zusätzliche Plätze und Dockanschlüsse | Abmessungen, Ein-/Ausflug, Belegung und gespeicherte Bordschiffe müssen zusammenpassen |
| Forschung und Sensoren | Planetenscanner, Forschungsmodul, Probenlabor, später bessere Reichweite/Auswertung | Verfügbare Untersuchungstiefe und begründete Forschungsfortschritte; Scanner ersetzen keine unternommene Bodenerkundung |
| Waffen | Waffenaufnahmen, Geschütze und weitere abgestimmte Schiffwaffentypen | Energie-/Munitionsbedarf, Schussraum und vorhandene Kampfregeln; als eigenes Folgepaket spielbar machen |
| Schutz | Panzerung und später freigegebene Schutzsysteme | Masse, Versorgungsbedarf und tatsächlicher Schutz im Kampfsystem |
| Expeditionsunterstützung | Reparatur-/Werkstattmodul und Ausstattung für Oberflächenmissionen | Geplante Erweiterungen für Wartung und Rückkehrfähigkeit; Umfang nach dem ersten vollständigen Expeditionsablauf konkretisieren |
| Beibootausstattung | Landeelemente, Frachtmodule, Sensoren und gegebenenfalls Bewaffnung | Entwurf muss Landung, Bodenfreiheit, Ausstieg und Rückkehr mit seiner tatsächlichen Ausrüstung ermöglichen |

**Editorbedienung:** Teile platzieren, drehen, skalieren innerhalb zulässiger Grenzen, spiegeln und zu einem zusammenhängenden Schiff kombinieren. Sichtbare Baugrenzen wachsen mit dem Fortschritt. Vorschau zeigt Größe, Masse, Energie, Fracht, Hangarplätze und tatsächlich verfügbare Funktionen über gemeinsame Symbole. Unfertige zukünftige Funktionen erscheinen nicht als einsatzbereit.

Ein Hangarplatz ist durch Platz, erlaubte Schiffabmessungen und Versorgung begrenzt. Größere Außenverkleidung erzeugt keine zusätzliche Lager- oder Hangarkapazität ohne passende funktionale Module. Umbauten erhalten Schiffidentität, Bordschiffe, Fracht und Forschung; inkompatible Belegung wird vor dem Umbau nachvollziehbar aufgelöst.

## 4. Fortschritt innerhalb der Weltraumphase

Die folgenden Ausbaustufen sind eine Planung für die Reihenfolge, keine festen Meterzahlen, Punktkosten oder vorgeschriebenen Schiffsformen.

| Ausbaustufe | Erkennbarer Fortschritt | Voraussetzungen |
|---|---|---|
| Einstiegsexpedition | Großes Basisschiff mit einem kleinen Landungs-/Erkundungsschiff, Grundlager und einfacher Untersuchungsausrüstung | Bestätigter Weltraumaufstieg, Bau-/Versorgungsgrundlage und vollständiger erster Expeditionsablauf |
| Forschungsträger | Größerer Baubereich, mehr Lager, bessere Sensoren und Forschung, zusätzliche frei wählbare Module | Echte Entdeckungen, ausgewertete Forschung, passende Technologien, Material und Ausbaukapazität |
| Erweiterte Expedition | Weitere Hangarplätze, verschiedene Bordschiffe, mehr Reichweite, stärkere Schutz- und Waffenoptionen | Geprüfter Mehrschiffbetrieb, höheres Energie-/Versorgungsbudget und freigegebene Technik |
| Großes Expeditionsflaggschiff | Deutlich größerer frei gestaltbarer Rumpf und Kombination mehrerer Forschungs-, Fracht-, Hangar- und Waffensysteme | Tragfähige Wirtschaft, nachgewiesene Leistungsgrenzen und passende fortgeschrittene Technik |

- Fortschritte erhöhen die zulässigen Rumpf-/Baumaße und nutzbaren Kapazitäten; das Schiff wird tatsächlich aus-/umgebaut.
- Ein Punktestand allein verwandelt den Rumpf nicht automatisch. Forschung, Ressourcen und ein geeigneter Bau-/Umbauort werden geprüft.
- Forschungs-, Handels-/Versorgungs- und kampforientierte Ausrüstung sollen unterschiedliche Schwerpunkte erlauben. Friedliche Expeditionen können größere Schiffe erschließen.
- Ein größeres Schiff benötigt passende Energie, Antrieb und Versorgung. Mehr Waffen, mehr Fracht und mehr Bordschiffe erzeugen nachvollziehbare Abwägungen.
- Genaue Größenklassen, Ressourcenpreise, Reichweiten und Flottengrenzen werden erst mit belastbarer Technik- und Balanceprüfung festgelegt.

## 5. Planeten erkunden und untersuchen

- Orbit-/Anflugscan liefert nur die durch Sensoren erkennbaren Informationen. Er deckt weder alle Arten noch automatisch die gesamte Oberfläche auf.
- Landefähige Ziele verwenden die vorhandene Körper-ID und dieselbe Oberflächenquelle wie die Kampagne. Es gibt keine kleine Ersatzkopie des Planeten für die Landung.
- Landung prüft Gelände, Gefälle, Wasser, Hindernisse, Schiffmaße und Ausstieg. Ein Wiedereinstieg bleibt erreichbar.
- Nach dem Ausstieg gelten bestehende Scan-/Entdeckungsregeln, gemeinsame Karten und Spielerwissen. Bereits bekannte Arten bleiben bekannt; erneuter Scan vergibt keine doppelte Erstentdeckung.
- Geplante wissenschaftliche Inhalte sind Lebensräume/Arten, Rohstoffvorkommen, Umweltbedingungen und auswertbare Proben. Tiefe und Gerätevoraussetzungen werden pro Inhalt festgelegt.
- Digitale Entdeckungen und physische Proben werden getrennt behandelt: Wissen liegt im gemeinsamen Forschungsstand; Proben brauchen einen tatsächlichen Frachtplatz und einen nachvollziehbaren Transport.
- Laborauswertung nutzt eindeutige Entdeckungs-/Auftragskennungen. Wiederholtes Laden, Andocken oder Übertragen erzeugt keine doppelte Forschungsbelohnung.
- Die vorhandene Oberfläche, Unterwassergrundlage, Tierwelt, Heimatorte und später Kolonien bleiben Teil derselben Welt.

## 6. Speicherung, Maßstab und Übergaben

Diese Anschlüsse müssen schon bei Welt-, Editor- und Speichergrundlagen mitgedacht werden. Die vollständige Raumfahrt wird erst nach ihren spielbaren Vorgängerphasen umgesetzt.

| Zustand / Übergang | Geplante Anforderung |
|---|---|
| Schiffidentität | Stabile individuelle ID, Besitzerfraktion, Entwurfsrevision, Module, Gesundheit, Fracht und Aufträge; ein Bauplan kann mehrere unterschiedliche Individuen erzeugen |
| Hierarchie und Orte | Sektor-/System-/Körperadresse im Weltraum, relative Lage im Hangar/Dock, Körper-/Oberflächenadresse nach Landung; vorhandene Weltadressen erweitern statt galaktische Entfernungen in einem einzigen lokalen Positionsvektor abzulegen |
| Andocken / Abdocken | Eindeutiger Zustandswechsel zwischen Hangarbesitz und aktivem Beiboot; ein Beiboot existiert genau einmal, auch bei Prozessabbruch |
| Kontrolle / Ausstieg | Aktiv gesteuertes Expeditionsschiff, Beiboot oder Figur eindeutig speichern; Figur und Schiff behalten Identität und Ort |
| Frachttransfer | Quelle und Ziel atomar verbuchen, Kapazität prüfen und Unterbrechungen behandeln; keine Vervielfachung und kein stiller Verlust |
| Umbau | Vorhandene Schiffe und Fracht beim Rumpf-/Hangarwechsel erhalten; Kosten und Änderung als bestätigten, wiederherstellbaren Vorgang behandeln |
| Nah-/Fernbetrieb | Aktuelle Umgebung detailliert laden; entfernte Expeditionsschiffe, Systeme und Hangarinhalte begrenzt simulieren; genau ein Simulationsbesitzer je Schiff/Ressourcenbestand |
| Pause / Neustart | Gemeinsame Pause- und Zeitregeln gelten auch für Forschung, Schiffe und Transporte; kein unbeschlossener Offline-Fortschritt |
| Ausfall / Verlust | Gestrandetes Beiboot, blockierter Hangar und Verlust der Basis erhalten definierte Wiederaufnahme-/Ersatzregeln; keine unrettbare Kampagne durch verschwundene Referenzen |
| Rückkehr | Nach Systemwechsel/Planetenausflug eigene Schiffe, Bauzustände, Heimat und bekannte Orte unverändert wiederfinden |

Der detaillierte Rumpf, alle Innenräume, sämtliche entfernten Schiffe und der ganze Planet werden nicht zugleich in voller Auflösung simuliert. Außengröße, Darstellung und zugelassene Baukomplexität erhalten gemeinsam geprüfte Budgets. Ein begehbarer Schiffsinnenraum kann später separat geplant werden; für den hier geforderten Ablauf genügt zunächst ein klarer Wechsel über Brücke/Hangar.

## 7. Konkrete To-dos nach Meilenstein

Alle Unterpakete stehen auf **geplant**. Sie zerlegen M9 und ändern keine bestehenden Phasen-IDs.

| ID | Arbeitspaket | Voraussetzung | Abnahme |
|---|---|---|---|
| M9.1 | Schiffdaten, Größen-/Kapazitätsregeln und erster modularer Editor für Expeditionsschiff und Beiboot | Gemeinsames Bauplanfundament, stabile Weltorte/IDs, M8-Bau-/Versorgungsgrundlage | Zwei eigene Entwürfe mit tatsächlichen Modulen bauen, speichern und erneut öffnen; Beiboot passt zum Hangar |
| M9.2 | Erste vollständige Expedition in einem System | M9.1, vollständige Kugelkampagne, passende Flug-/Kollisions-/Übergabesteuerung | Großes Schiff steuern → Beiboot abdocken → zur Oberfläche fliegen → landen/aussteigen → einfache Untersuchung → starten → zurückfliegen/andocken |
| M9.3 | Wissenschaftliche Expedition und Forschungsfortschritt | M9.2, gemeinsames Entdeckungsbuch/Karten/Forschung | Daten erfassen, Probe verladen, zurückbringen und einmalig auswerten; Wissen und physische Fracht bleiben konsistent |
| M9.4 | Größere Rümpfe, mehr Ausrüstung und wirkende Kapazitäten | M9.3, Forschung, Wirtschaft und geprüfte Bau-/Leistungsbudgets | Größeren Baubereich erschließen und Schiff umbauen; neue Lager-/Modulkapazität wirkt; bisherige Schiffe/Fracht bleiben erhalten |
| M9.5 | Zusätzliche Bordschiffe, Befehle und Bewaffnung | M9.2/M9.4, gespeicherte Flottenzuordnung, passende Kampf-/KI-Grundlage | Mehrere individuelle Bordschiffe verwalten; reale Hangarbelegung, zuverlässige Auswahl/Rückkehr; bewaffnete Ausrüstung wirkt im geprüften Kampfablauf |
| M9.6 | System-/Sektorreise, Galaxienkarte und versorgte Kolonien | M9.2–M9.4, bestehender Galaxiekatalog, begrenzte Fernsimulation und Siedlungswirtschaft | Reise in ein anderes System → Expedition/Kolonie versorgen → zur ursprünglichen Basis/Heimat zurückkehren; alte Orte erhalten |

M9.5 ist kein zwingendes Kampftor vor friedlicher Systemreise oder Kolonisation. Zusätzliche Schiffe dürfen in Teilpaketen vor dem vollständigen Waffenausbau geliefert werden.

## 8. Gemeinsame Abnahme

- [ ] Neue Weltraumkampagne bzw. bestätigter Epochenwechsel erhält eigene Spezies, Fraktion, Heimat und bisherige Entdeckungen.
- [ ] Expeditionsschiff und Beiboot sind tatsächlich unterschiedlich große Schiffe mit passenden Modulen; eigene Gestaltung und die Übernahme fertiger Vorlagen sind beide geprüft.
- [ ] Vollständige Expedition inklusive Steuern beider Schiffe, Aussteigen und Rückkehr am selben Kugelplaneten gelingt.
- [ ] Speichern/Neustart im Hangar, während des Beibootflugs, gelandet, ausgestiegen und nach Rückkehr stellt den richtigen Zustand wieder her.
- [ ] Unterbrochenes Andocken, Frachtumladen und Umbauen verliert oder dupliziert weder Schiffe noch Güter.
- [ ] Ein passendes Expeditionsschiff und Beiboot lassen sich aus mitgelieferten oder Community-Vorlagen ohne eigene Editorarbeit bauen und verwenden; Besitz und individuelle Schiffzustände stammen aus dem Zielspielstand.
- [ ] Der erste Größen-/Ausrüstungsfortschritt ist durch echte Forschung und Ressourcen erreichbar; neue Kapazität funktioniert.
- [ ] Weitere Bordschiffe behalten individuelle Ausrüstung/Belegung und können eindeutig gewählt bzw. zurückgerufen werden.
- [ ] Wechsel zwischen Nah-/Fernsimulation und Systemen erhält Zustände bei begrenztem Speicher-/Rechenaufwand.
- [ ] Altstände und Zukunftsversionen werden gemäß gemeinsamem Migrationsvertrag behandelt.
- [ ] Technische Messungen und Lars' visuelle/spielerische Abnahme werden getrennt dokumentiert.
